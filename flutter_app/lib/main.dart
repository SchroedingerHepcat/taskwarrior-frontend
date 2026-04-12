import 'package:flutter/material.dart';

import 'app/app.dart';
import 'backend/local_dev_backend_client.dart';

export 'app/app.dart';
export 'backend/local_dev_backend_client.dart';

void main() {
  runApp(
    TaskwarriorFrontendApp(
      backend: LocalDevelopmentBackendClient(),
    ),
  );
}
