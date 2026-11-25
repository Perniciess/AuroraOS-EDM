import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'core/api_client.dart';
import 'features/workspace/application/workspace_controller.dart';
import 'features/workspace/data/http_workspace_repository.dart';
import 'features/workspace/data/local_workspace_store.dart';
import 'features/workspace/data/offline_workspace_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const endpoint = String.fromEnvironment('EDM_API_URL');
  final api = ApiClient(endpoint);
  final controller = WorkspaceController(OfflineWorkspaceRepository(
    HttpWorkspaceRepository(api), api, LocalWorkspaceStore(endpoint)));
  runApp(EdmApp(
    controller: controller,
    configured: endpoint.isNotEmpty,
  ));
  if (endpoint.isNotEmpty) await controller.initialize();
}
