import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:edm/core/api_client.dart';
import 'package:edm/features/workspace/data/local_workspace_store.dart';
import 'package:edm/features/workspace/data/offline_workspace_repository.dart';
import 'package:edm/features/workspace/domain/workspace_repository.dart';
import 'package:flutter_test/flutter_test.dart';

final _bytes = utf8.encode('%PDF-1.7\nTest document\n%%EOF\n');
final _details = DocumentDetails(title: 'Документ', version: 1,
  sizeBytes: _bytes.length, checksum: sha256.convert(_bytes).toString());
final _assignment = Assignment(id: 'a', documentId: 'd', versionId: 'v',
  revision: 1, createdAt: DateTime.utc(2026));

class _Store implements LocalWorkspaceStore {
  _Store(this.directory);
  final Directory directory;
  Session? session;
  DocumentDetails? savedDetails;
  AssignmentPage page = const AssignmentPage([], null);
  bool revoked = false;
  String? lastOwner;

  @override
  Future<Session?> restoreSession() async => session;
  @override
  Future<void> saveSession(Session value) async { session = value; }
  @override
  Future<void> clearSession() async { session = null; }
  @override
  Future<void> saveAssignments(String owner, AssignmentPage value, {required bool replace}) async {
    lastOwner = owner;
    page = value;
  }
  @override
  Future<AssignmentPage> assignments(String owner) async { lastOwner = owner; return page; }
  @override
  Future<void> saveDetails(String owner, Assignment a, DocumentDetails d) async { savedDetails = d; }
  @override
  Future<DocumentDetails?> details(String owner, Assignment a) async => savedDetails;
  @override
  Future<File> file(String owner, Assignment a) async {
    lastOwner = owner;
    return File('${directory.path}/document.pdf');
  }
  @override
  Future<void> revoke(String owner, Assignment a) async {
    revoked = true;
    savedDetails = null;
    final cached = await file(owner, a);
    if (await cached.exists()) await cached.delete();
  }
  @override
  Future<void> close() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Remote implements WorkspaceRepository {
  Object? failure;
  @override
  Future<Session> login(String username, String password) async => Session(
    token: 'token', userId: 'owner-id', username: username,
    expiresAt: DateTime.now().add(const Duration(hours: 1)));
  @override
  Future<AssignmentPage> assignments(String token, {String? after}) async {
    if (failure != null) throw failure!;
    return AssignmentPage([_assignment], null);
  }
  @override
  Future<DocumentDetails> details(String token, Assignment a) async {
    if (failure != null) throw failure!;
    return _details;
  }
  @override
  Future<void> logout(String token) async {}
  @override
  void close() {}
}

class _Api implements ApiClient {
  ApiFailure? failure;
  bool interrupted = false;
  bool corrupt = false;
  int downloads = 0;
  int revision = 1;
  @override
  Future<Map<String, dynamic>> request(String method, String path, {
    String? token, Map<String, String>? body, Map<String, String>? query,
  }) async {
    if (failure != null) throw failure!;
    return {'id': 'a', 'document_id': 'd', 'version_id': 'v',
      'revision': revision, 'status': 'pending'};
  }
  @override
  Future<void> download(String path, String token, File destination,
      int expectedSize, void Function(int) onProgress) async {
    downloads++;
    if (interrupted) {
      await destination.writeAsBytes(_bytes.take(4).toList());
      throw const ApiFailure('Обрыв', network: true);
    }
    await destination.writeAsBytes(corrupt ? List.filled(_bytes.length, 0) : _bytes);
    onProgress(_bytes.length);
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory directory;
  late _Store store;
  late _Api api;
  late _Remote remote;
  late OfflineWorkspaceRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('edm-cache-test-');
    store = _Store(directory);
    api = _Api();
    remote = _Remote();
    repository = OfflineWorkspaceRepository(remote, api, store);
    await repository.login('user', 'password');
  });
  tearDown(() async { await directory.delete(recursive: true); });

  Future<String> open() => repository.preparePdf('token', _assignment, _details, (_) {});

  test('verified download is reusable offline after repository restart', () async {
    await repository.assignments('token');
    final path = await open();
    final restored = OfflineWorkspaceRepository(remote, api, store);
    expect((await restored.restoreSession())!.userId, 'owner-id');
    remote.failure = const ApiFailure('Нет сети', network: true);
    api.failure = const ApiFailure('Нет сети', network: true);
    expect((await restored.assignments('token')).items.single.id, 'a');
    expect(await restored.preparePdf('token', _assignment, _details, (_) {}), path);
    expect(restored.offline, isTrue);
    expect(api.downloads, 1);
    expect(store.lastOwner, 'owner-id');
  });

  test('interrupted download leaves no ready or temporary file and retry succeeds', () async {
    api.interrupted = true;
    await expectLater(open(), throwsA(isA<ApiFailure>()));
    expect(await directory.list().toList(), isEmpty);
    api.interrupted = false;
    final path = await open();
    expect(await File(path).readAsBytes(), _bytes);
    expect(api.downloads, 2);
  });

  test('same-size corrupt content is rejected and cannot enter the cache', () async {
    api.corrupt = true;
    await expectLater(open(), throwsA(isA<ApiFailure>()));
    expect(await directory.list().toList(), isEmpty);
    api.corrupt = false;
    expect(await File(await open()).readAsBytes(), _bytes);
  });

  test('corrupt cached file is re-downloaded instead of opened', () async {
    final file = File(await open());
    await file.writeAsBytes(List.filled(_bytes.length, 0));
    expect(await File(await open()).readAsBytes(), _bytes);
    expect(api.downloads, 2);
  });

  test('404 removes cached content; HTTP errors never enable offline fallback', () async {
    final file = File(await open());
    api.failure = const ApiFailure('Отозвано', status: 404);
    await expectLater(open(), throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 404)));
    expect(await file.exists(), isFalse);
    expect(store.revoked, isTrue);
    expect(api.downloads, 1);
  });

  test('changed assignment revision prevents cached-file access', () async {
    await open();
    api.revision = 2;
    await expectLater(open(), throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 409)));
    expect(store.revoked, isTrue);
  });

  test('401 discards persisted credentials instead of using cached metadata', () async {
    await open();
    api.failure = const ApiFailure('Сессия отозвана', status: 401);
    await expectLater(open(), throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 401)));
    expect(store.session, isNull);
    await expectLater(open(), throwsA(isA<ApiFailure>()));
  });

  test('expired restored session cannot open a saved PDF', () async {
    await open();
    store.session = Session(token: 'token', username: 'user', userId: 'owner-id',
      expiresAt: DateTime.now().subtract(const Duration(seconds: 1)));
    final restored = OfflineWorkspaceRepository(remote, api, store);
    await restored.restoreSession();
    await expectLater(restored.preparePdf('token', _assignment, _details, (_) {}),
      throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 401)));
  });
}
