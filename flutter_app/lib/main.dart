import 'package:flutter/material.dart';

import 'app/app.dart';
import 'backend/http_task_backend_client.dart';

export 'app/app.dart';
export 'backend/http_task_backend_client.dart';
export 'backend/local_dev_backend_client.dart';

void main() {
  const baseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'http://127.0.0.1:8080',
  );

  runApp(
    TaskwarriorFrontendApp(
      backend: HttpTaskBackendClient(baseUrl: baseUrl),
    ),
  );
}
