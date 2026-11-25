import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/workspace_repository.dart';

/// The database contains metadata only. Bearer tokens live in OS secure storage.
class LocalWorkspaceStore {
  LocalWorkspaceStore(this.endpoint);

  final String endpoint;
  final _secrets = const FlutterSecureStorage();
  Database? _db;
  late Directory _root;
  Future<void>? _opening;

  String get _server => sha256.convert(utf8.encode(endpoint)).toString();
  String get _sessionKey => 'edm.session.$_server';

  Future<void> _open() async {
    try {
      await (_opening ??= _initialize());
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<void> _initialize() async {
    final support = await getApplicationSupportDirectory();
    _root = Directory(p.join(support.path, 'workspace', _server));
    await _root.create(recursive: true);
    _db = await openDatabase(p.join(_root.path, 'workspace.sqlite'), version: 1,
      onCreate: (db, _) async {
        await db.execute('''CREATE TABLE assignments (
          owner TEXT NOT NULL, id TEXT NOT NULL, document_id TEXT NOT NULL,
          version_id TEXT NOT NULL, revision INTEGER NOT NULL, created_at TEXT NOT NULL,
          PRIMARY KEY(owner, id))''');
        await db.execute('''CREATE TABLE versions (
          owner TEXT NOT NULL, document_id TEXT NOT NULL, version_id TEXT NOT NULL,
          title TEXT NOT NULL, number INTEGER NOT NULL, size_bytes INTEGER NOT NULL,
          checksum TEXT NOT NULL, PRIMARY KEY(owner, document_id, version_id))''');
      });
    // A crash before rename leaves only a temporary file. A crash after rename
    // is safe: every open revalidates size and digest against SQLite metadata.
    await for (final entry in _root.list(recursive: true, followLinks: false)) {
      if (entry is File && entry.path.endsWith('.part')) await entry.delete();
    }
  }

  Future<Session?> restoreSession() async {
    final raw = await _secrets.read(key: _sessionKey);
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw) as Map<String, dynamic>;
      final session = Session(token: value['token'] as String,
        username: value['username'] as String, userId: value['user_id'] as String,
        expiresAt: DateTime.parse(value['expires_at'] as String));
      if (session.expiresAt.isAfter(DateTime.now())) return session;
    } on FormatException {
      // Remove incomplete or obsolete persisted credentials.
    } on TypeError {
      // Remove incomplete or obsolete persisted credentials.
    }
    await clearSession();
    return null;
  }

  Future<void> saveSession(Session session) => _secrets.write(key: _sessionKey,
    value: jsonEncode({'token': session.token, 'username': session.username,
      'user_id': session.userId, 'expires_at': session.expiresAt.toUtc().toIso8601String()}));

  Future<void> clearSession() => _secrets.delete(key: _sessionKey);

  Future<void> saveAssignments(String owner, AssignmentPage page, {required bool replace}) async {
    await _open();
    await _db!.transaction((txn) async {
      if (replace) await txn.delete('assignments', where: 'owner = ?', whereArgs: [owner]);
      for (final a in page.items) {
        await txn.insert('assignments', {'owner': owner, 'id': a.id,
          'document_id': a.documentId, 'version_id': a.versionId,
          'revision': a.revision, 'created_at': a.createdAt.toUtc().toIso8601String()},
          conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<AssignmentPage> assignments(String owner) async {
    await _open();
    final rows = await _db!.query('assignments', where: 'owner = ?', whereArgs: [owner],
      orderBy: 'created_at DESC, id DESC');
    return AssignmentPage(rows.map((r) => Assignment(id: r['id'] as String,
      documentId: r['document_id'] as String, versionId: r['version_id'] as String,
      revision: r['revision'] as int, createdAt: DateTime.parse(r['created_at'] as String)))
      .toList(growable: false), null);
  }

  Future<void> saveDetails(String owner, Assignment a, DocumentDetails d) async {
    await _open();
    await _db!.insert('versions', {'owner': owner, 'document_id': a.documentId,
      'version_id': a.versionId, 'title': d.title, 'number': d.version,
      'size_bytes': d.sizeBytes, 'checksum': d.checksum},
      conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<DocumentDetails?> details(String owner, Assignment a) async {
    await _open();
    final rows = await _db!.query('versions',
      where: 'owner = ? AND document_id = ? AND version_id = ?',
      whereArgs: [owner, a.documentId, a.versionId]);
    if (rows.isEmpty) return null;
    final r = rows.single;
    return DocumentDetails(title: r['title'] as String, version: r['number'] as int,
      sizeBytes: r['size_bytes'] as int, checksum: r['checksum'] as String);
  }

  Future<File> file(String owner, Assignment a) async {
    await _open();
    // No server-controlled identifiers become filesystem paths.
    final account = sha256.convert(utf8.encode(owner)).toString();
    final id = sha256.convert(utf8.encode(jsonEncode([a.documentId, a.versionId]))).toString();
    final directory = Directory(p.join(_root.path, account));
    await directory.create(recursive: true);
    return File(p.join(directory.path, '$id.pdf'));
  }

  static Future<bool> valid(File file, DocumentDetails details) async {
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(details.checksum) ||
        details.sizeBytes <= 0 || details.sizeBytes > 100 * 1024 * 1024 ||
        !await file.exists() || await file.length() != details.sizeBytes) return false;
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString() == details.checksum.toLowerCase();
  }

  Future<void> revoke(String owner, Assignment a) async {
    final cached = await file(owner, a);
    if (await cached.exists()) await cached.delete();
    await _db!.delete('versions', where: 'owner = ? AND document_id = ? AND version_id = ?',
      whereArgs: [owner, a.documentId, a.versionId]);
    await _db!.delete('assignments', where: 'owner = ? AND id = ?', whereArgs: [owner, a.id]);
  }

  Future<void> close() async {
    if (_opening != null) await _opening;
    await _db?.close();
  }
}
