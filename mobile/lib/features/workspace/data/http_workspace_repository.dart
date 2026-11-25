import '../../../core/api_client.dart';
import '../domain/workspace_repository.dart';

class HttpWorkspaceRepository implements WorkspaceRepository {
  HttpWorkspaceRepository(this._api);

  final ApiClient _api;

  @override
  Future<Session> login(String username, String password) async {
    final json = await _api.request('POST', '/api/v1/auth/login', body: {
      'username': username.trim(),
      'password': password,
    });
    final user = json['user'] as Map<String, dynamic>;
    return Session(
      token: json['access_token'] as String,
      username: user['username'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  @override
  Future<void> logout(String token) async {
    await _api.request('POST', '/api/v1/auth/logout', token: token);
  }

  @override
  Future<AssignmentPage> assignments(String token, {String? after}) async {
    final json = await _api.request('GET', '/api/v1/assignments', token: token,
      query: {'limit': '30', if (after != null) 'after': after});
    return AssignmentPage(
      (json['items'] as List<dynamic>).map((value) {
        final item = value as Map<String, dynamic>;
        return Assignment(
          id: item['id'] as String,
          documentId: item['document_id'] as String,
          versionId: item['version_id'] as String,
          revision: item['revision'] as int,
          createdAt: DateTime.parse(item['created_at'] as String),
        );
      }).toList(growable: false),
      json['next_after'] as String?,
    );
  }

  @override
  Future<DocumentDetails> details(String token, Assignment assignment) async {
    final documentPath = '/api/v1/documents/${Uri.encodeComponent(assignment.documentId)}';
    final document = await _api.request('GET', documentPath, token: token);
    final version = await _api.request('GET',
      '$documentPath/versions/${Uri.encodeComponent(assignment.versionId)}', token: token);
    return DocumentDetails(
      title: document['title'] as String,
      version: version['number'] as int,
      sizeBytes: version['size_bytes'] as int,
      checksum: version['checksum'] as String,
    );
  }

  @override
  void close() => _api.close();
}
