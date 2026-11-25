import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/api_client.dart';
import '../domain/workspace_repository.dart';

class WorkspaceController extends ChangeNotifier {
  WorkspaceController(this._repository);

  final WorkspaceRepository _repository;
  Session? session;
  List<Assignment> items = const [];
  String? nextAfter;
  String? error;
  bool busy = false;
  bool _disposed = false;
  Timer? _expiry;

  bool get offline => _repository is OfflineWorkspace && (_repository as OfflineWorkspace).offline;

  Future<void> initialize() async {
    final repository = _repository;
    if (repository is! OfflineWorkspace) return;
    await _perform(() async {
      final restored = await (repository as OfflineWorkspace).restoreSession();
      if (_disposed || restored == null) return;
      _setSession(restored);
    });
    if (session != null && !_disposed) await refresh();
  }

  void _setSession(Session authenticated) {
    _expiry?.cancel();
    session = authenticated;
    final duration = authenticated.expiresAt.difference(DateTime.now());
    if (duration <= Duration.zero) {
      _clearSession();
      throw const ApiFailure('Сессия истекла. Войдите заново.');
    }
    _expiry = Timer(duration, () {
      if (_disposed) return;
      _clearSession();
      error = 'Сессия истекла. Войдите заново.';
      notifyListeners();
    });
  }

  Future<void> login(String username, String password) async {
    if (busy) return;
    await _perform(() async {
      final authenticated = await _repository.login(username, password);
      if (_disposed) return;
      _setSession(authenticated);
    });
    if (session != null && !_disposed) await refresh();
  }

  Future<void> refresh({bool more = false}) async {
    if (busy || session == null || (more && nextAfter == null)) return;
    final current = session!;
    await _perform(() async {
      final page = await _repository.assignments(current.token,
        after: more ? nextAfter : null);
      if (session != current) return;
      final combined = more ? [...items, ...page.items] : page.items;
      items = List.unmodifiable({for (final item in combined) item.id: item}.values);
      nextAfter = page.nextAfter;
    });
  }

  Future<DocumentDetails> details(Assignment assignment) async {
    final current = session;
    if (current == null) throw const ApiFailure('Войдите заново.');
    try {
      final result = await _repository.details(current.token, assignment);
      if (current != session) throw const ApiFailure('Сессия истекла.');
      if (!_disposed) notifyListeners();
      return result;
    } on ApiFailure catch (failure) {
      if (failure.status == 401 && !_disposed) {
        _clearSession();
        error = 'Сессия истекла. Войдите заново.';
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    if (busy || session == null) return;
    await _perform(() async {
      await _repository.logout(session!.token);
      _clearSession();
    });
  }

  Future<String> preparePdf(Assignment assignment, DocumentDetails details,
      void Function(int) onProgress) async {
    final current = session;
    final repository = _repository;
    if (current == null) throw const ApiFailure('Войдите заново.');
    if (repository is! OfflineWorkspace) throw const ApiFailure('Просмотр PDF недоступен.');
    try {
      final path = await (repository as OfflineWorkspace).preparePdf(
        current.token, assignment, details, onProgress);
      if (_disposed || current != session) throw const ApiFailure('Сессия истекла.');
      if (!_disposed) notifyListeners();
      return path;
    } on ApiFailure catch (failure) {
      if (failure.status == 401 && !_disposed) {
        _clearSession();
        error = failure.message;
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_disposed) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } on ApiFailure catch (failure) {
      if (failure.status == 401) _clearSession();
      error = failure.message;
    } catch (_) {
      error = 'Не удалось обработать ответ. Повторите запрос.';
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _clearSession() {
    _expiry?.cancel();
    session = null;
    items = const [];
    nextAfter = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _expiry?.cancel();
    _repository.close();
    super.dispose();
  }
}
