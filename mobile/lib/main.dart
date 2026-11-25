import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'core/api_client.dart';
import 'features/workspace/application/workspace_controller.dart';
import 'features/workspace/data/http_workspace_repository.dart';

void main() {
  const endpoint = String.fromEnvironment('EDM_API_URL');
  runApp(EdmApp(
    controller: WorkspaceController(
      HttpWorkspaceRepository(ApiClient(endpoint)),
    ),
    configured: endpoint.isNotEmpty,
  ));
}
