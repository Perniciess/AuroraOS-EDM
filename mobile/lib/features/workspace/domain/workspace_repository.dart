class Session {
  const Session({required this.token, required this.username, required this.expiresAt});

  final String token;
  final String username;
  final DateTime expiresAt;
}

class Assignment {
  const Assignment({
    required this.id,
    required this.documentId,
    required this.versionId,
    required this.revision,
    required this.createdAt,
  });

  final String id;
  final String documentId;
  final String versionId;
  final int revision;
  final DateTime createdAt;
}

class AssignmentPage {
  const AssignmentPage(this.items, this.nextAfter);

  final List<Assignment> items;
  final String? nextAfter;
}

class DocumentDetails {
  const DocumentDetails({
    required this.title,
    required this.version,
    required this.sizeBytes,
    required this.checksum,
  });

  final String title;
  final int version;
  final int sizeBytes;
  final String checksum;
}

abstract interface class WorkspaceRepository {
  Future<Session> login(String username, String password);
  Future<void> logout(String token);
  Future<AssignmentPage> assignments(String token, {String? after});
  Future<DocumentDetails> details(String token, Assignment assignment);
  void close();
}
