import 'dart:async';

import 'package:edm/core/api_client.dart';
import 'package:edm/features/workspace/application/workspace_controller.dart';
import 'package:edm/features/workspace/domain/workspace_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository implements WorkspaceRepository {
  final pendingLogin = Completer<Session>();
  final requestedCursors = <String?>[];
  Object? failure;
  AssignmentPage page = const AssignmentPage([], null);

  @override
  Future<Session> login(String username, String password) => pendingLogin.future;

  @override
  Future<AssignmentPage> assignments(String token, {String? after}) async {
    requestedCursors.add(after);
    if (failure != null) throw failure!;
    return page;
  }

  @override
  Future<void> logout(String token) async {
    if (failure != null) throw failure!;
  }

  @override
  Future<DocumentDetails> details(String token, Assignment assignment) async =>
    const DocumentDetails(title: 'Документ', version: 1, sizeBytes: 128, checksum: 'hash');

  @override
  void close() {}
}

Assignment _assignment(String id) => Assignment(
  id: id, documentId: 'document', versionId: 'version', revision: 1,
  createdAt: DateTime.utc(2026),
);

void main() {
  late _Repository repository;
  late WorkspaceController controller;

  setUp(() {
    repository = _Repository();
    controller = WorkspaceController(repository);
  });
  tearDown(() => controller.dispose());

  Future<void> login() async {
    final operation = controller.login('user', 'password');
    repository.pendingLogin.complete(Session(
      token: 'token', username: 'user',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    ));
    await operation;
  }

  test('repeated submit while login is pending does not start another flow', () async {
    final first = controller.login('user', 'password');
    await controller.login('other', 'other-password');
    expect(controller.busy, isTrue);
    expect(repository.requestedCursors, isEmpty);
    repository.pendingLogin.complete(Session(
      token: 'token', username: 'user',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    ));
    await first;
    expect(repository.requestedCursors, [null]);
  });

  test('pagination uses cursor and refresh replaces revoked entries', () async {
    repository.page = AssignmentPage([_assignment('a')], 'a');
    await login();
    repository.page = AssignmentPage([_assignment('a'), _assignment('b')], null);
    await controller.refresh(more: true);
    expect(repository.requestedCursors, [null, 'a']);
    expect(controller.items.map((item) => item.id), ['a', 'b']);
    repository.page = AssignmentPage([_assignment('b')], null);
    await controller.refresh();
    expect(controller.items.map((item) => item.id), ['b']);
  });

  test('401 clears session and assignment metadata', () async {
    repository.page = AssignmentPage([_assignment('a')], null);
    await login();
    repository.failure = const ApiFailure('Session expired', status: 401);
    await controller.refresh();
    expect(controller.session, isNull);
    expect(controller.items, isEmpty);
    expect(controller.error, isNotNull);
  });

  test('lost logout response keeps session until revocation can be retried', () async {
    await login();
    repository.failure = const ApiFailure('Network unavailable');
    await controller.logout();
    expect(controller.session, isNotNull);
    expect(controller.error, isNotNull);
    repository.failure = null;
    await controller.logout();
    expect(controller.session, isNull);
    expect(controller.items, isEmpty);
  });
}
