import 'package:flutter/material.dart';

import 'app/backend_configuration_store.dart';
import 'app/app.dart';
import 'backend/http_task_backend_client.dart';

export 'app/app.dart';
export 'backend/http_task_backend_client.dart';
export 'backend/local_dev_backend_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const compileTimeBaseUrl = String.fromEnvironment('BACKEND_BASE_URL');
  final store = BackendConfigurationStore();
  final savedBaseUrl = await store.loadBackendUrl();
  final baseUrl = compileTimeBaseUrl.trim().isNotEmpty
      ? compileTimeBaseUrl.trim()
      : savedBaseUrl;

  runApp(
    TaskwarriorFrontendApp(
      backend: baseUrl == null ? null : HttpTaskBackendClient(baseUrl: baseUrl),
      initialBackendUrl: baseUrl,
      backendFactory: (baseUrl) => HttpTaskBackendClient(baseUrl: baseUrl),
      saveBackendUrl: store.saveBackendUrl,
    ),
  );
}
