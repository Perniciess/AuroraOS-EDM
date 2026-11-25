import 'dart:async';
import 'dart:io';

import '../../../core/api_client.dart';
import '../domain/workspace_repository.dart';
import 'local_workspace_store.dart';

/// Network-first reads; only connection failures permit a local fallback.
class OfflineWorkspaceRepository implements WorkspaceRepository, OfflineWorkspace {
  OfflineWorkspaceRepository(this._remote, this._api, this._local);

  final WorkspaceRepository _remote;
  final ApiClient _api;
  final LocalWorkspaceStore _local;
  Session? _session;
  bool _downloading = false;
  @override
  bool offline = false;

  Session _current(String token) {
    final session = _session;
    if (session == null || session.token != token ||
        !session.expiresAt.isAfter(DateTime.now())) {
      throw const ApiFailure('Сессия истекла. Войдите заново.', status: 401);
    }
    return session;
  }

  String _owner(Session session) => session.userId.isEmpty ? session.username : session.userId;

  @override
  Future<Session?> restoreSession() async => _session = await _local.restoreSession();

  @override
  Future<Session> login(String username, String password) async {
    final session = await _remote.login(username, password);
    await _local.saveSession(session);
    _session = session;
    return session;
  }

  @override
  Future<void> logout(String token) async {
    await _remote.logout(token);
    _session = null;
    await _local.clearSession();
  }

  Future<T> _read<T>(String token, Future<T> Function(String owner) online,
      Future<T> Function(String owner) fromCache) async {
    final session = _current(token);
    final owner = _owner(session);
    try {
      final result = await online(owner);
      _current(token);
      offline = false;
      return result;
    } on ApiFailure catch (failure) {
      if (failure.status == 401) {
        _session = null;
        await _local.clearSession();
      }
      if (!failure.network) rethrow;
      _current(token);
      offline = true;
      return fromCache(owner);
    }
  }

  @override
  Future<AssignmentPage> assignments(String token, {String? after}) => _read(token, (owner) async {
    final page = await _remote.assignments(token, after: after);
    await _local.saveAssignments(owner, page, replace: after == null);
    return page;
  }, (owner) async {
    if (after != null) throw const ApiFailure('Для загрузки следующих заданий требуется сеть.');
    return _local.assignments(owner);
  });

  @override
  Future<DocumentDetails> details(String token, Assignment assignment) => _read(token, (owner) async {
    try {
      // A version may still be accessible through another assignment. Verify
      // the exact assignment, rather than inferring its validity from file access.
      final current = await _api.request('GET',
        '/api/v1/assignments/${Uri.encodeComponent(assignment.id)}', token: token);
      if (current['id'] != assignment.id || current['document_id'] != assignment.documentId ||
          current['version_id'] != assignment.versionId || current['revision'] != assignment.revision ||
          current['status'] != 'pending') {
        await _local.revoke(owner, assignment);
        throw const ApiFailure('Задание изменилось. Обновите список.', status: 409);
      }
      final details = await _remote.details(token, assignment);
      await _local.saveDetails(owner, assignment, details);
      return details;
    } on ApiFailure catch (failure) {
      if (failure.status == 404) await _local.revoke(owner, assignment);
      rethrow;
    }
  }, (owner) async {
    final details = await _local.details(owner, assignment);
    if (details == null) throw const ApiFailure('Карточка ещё не сохранена. Подключитесь к сети.');
    return details;
  });

  @override
  Future<String> preparePdf(String token, Assignment assignment,
      DocumentDetails expected, void Function(int) onProgress) async {
    if (_downloading) throw const ApiFailure('Дождитесь завершения скачивания.');
    _downloading = true;
    File? partial;
    try {
      final owner = _owner(_current(token));
      // Check access on every open when online, including a previously cached PDF.
      final currentDetails = await details(token, assignment);
      if (currentDetails.sizeBytes != expected.sizeBytes || currentDetails.checksum != expected.checksum) {
        throw const ApiFailure('Метаданные версии изменились. Откройте карточку заново.');
      }
      final file = await _local.file(owner, assignment);
      if (await LocalWorkspaceStore.valid(file, expected)) {
        _current(token);
        return file.path;
      }
      if (await file.exists()) await file.delete();
      partial = File('${file.path}.part');
      final path = '/api/v1/documents/${Uri.encodeComponent(assignment.documentId)}'
          '/versions/${Uri.encodeComponent(assignment.versionId)}/content';
      await _api.download(path, token, partial, expected.sizeBytes, onProgress);
      if (!await LocalWorkspaceStore.valid(partial, expected)) {
        throw const ApiFailure('Контрольная сумма PDF не совпала. Повторите скачивание.');
      }
      _current(token);
      await partial.rename(file.path);
      return file.path;
    } on ApiFailure catch (failure) {
      if (failure.status == 401) {
        _session = null;
        await _local.clearSession();
      } else if (failure.status == 404) {
        final session = _session;
        if (session != null) await _local.revoke(_owner(session), assignment);
      }
      rethrow;
    } on FileSystemException {
      throw const ApiFailure('Не удалось прочитать или сохранить PDF. Проверьте свободное место.');
    } finally {
      try {
        if (partial != null && await partial.exists()) await partial.delete();
      } finally {
        _downloading = false;
      }
    }
  }

  @override
  void close() {
    _session = null;
    _remote.close();
    // Let an in-flight download unwind before closing the metadata connection.
    unawaited(_closeLocal());
  }

  Future<void> _closeLocal() async {
    while (_downloading) { await Future<void>.delayed(const Duration(milliseconds: 20)); }
    await _local.close();
  }
}
