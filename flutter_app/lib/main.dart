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
  final themePreference = await store.loadThemePreference();
  final savedViews = await store.loadSavedViews();
  final dashboardLayout = await store.loadDashboardLayout();
  final baseUrl = compileTimeBaseUrl.trim().isNotEmpty
      ? compileTimeBaseUrl.trim()
      : savedBaseUrl;

  runApp(
    TaskwarriorFrontendApp(
      backend: baseUrl == null ? null : HttpTaskBackendClient(baseUrl: baseUrl),
      initialBackendUrl: baseUrl,
      backendFactory: (baseUrl) => HttpTaskBackendClient(baseUrl: baseUrl),
      saveBackendUrl: store.saveBackendUrl,
      initialThemePreference: themePreference,
      saveThemePreference: store.saveThemePreference,
      initialSavedViews: savedViews,
      saveSavedViews: store.saveSavedViews,
      initialDashboardLayout: dashboardLayout,
      saveDashboardLayout: store.saveDashboardLayout,
    ),
  );
}
