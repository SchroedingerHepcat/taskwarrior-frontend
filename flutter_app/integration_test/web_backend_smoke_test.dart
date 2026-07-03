import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_app/main.dart';
import 'package:flutter_app/models/shell_models.dart';

const String _backendUrl = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'http://127.0.0.1:38182',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('web client reaches live backend and round-trips a task',
      (tester) async {
    final backend = HttpTaskBackendClient(baseUrl: _backendUrl);
    final health = await backend.healthcheck();
    expect(health.environment, 'ok');

    final description = 'Web backend smoke '
        '${DateTime.now().microsecondsSinceEpoch}';
    final created = await backend.createTask(
      CreateTaskInput(description: description),
    );
    expect(created.title, description);

    final tasks = await backend.queryTasks(
      TaskQuery.all(
        referenceTime: DateTime.now().toUtc(),
      ),
    );

    expect(
      tasks.map((task) => task.id),
      contains(created.id),
    );
  });
}
