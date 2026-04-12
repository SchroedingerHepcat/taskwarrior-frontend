import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/main.dart';
import 'package:flutter_app/models/shell_models.dart';
import 'package:flutter_app/backend/task_backend_client.dart';

void main() {
  testWidgets('renders dashboard and navigates between shell sections',
      (tester) async {
    await tester.pumpWidget(
      TaskwarriorFrontendApp(
        backend: _FakeBackendClient(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard-screen')), findsOneWidget);

    await tester.tap(find.byIcon(ShellSection.tasks.icon));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('task-list-screen')), findsOneWidget);

    await tester.tap(find.byIcon(ShellSection.board.icon));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('board-screen')), findsOneWidget);

    await tester.tap(find.byIcon(ShellSection.detail.icon));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('task-detail-screen')), findsOneWidget);
  });

  testWidgets('wide layout shows rail and context panel', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      TaskwarriorFrontendApp(
        backend: _FakeBackendClient(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byKey(const Key('desktop-context-panel')), findsOneWidget);
  });

  testWidgets('backend wiring loads health and task query data',
      (tester) async {
    final backend = _FakeBackendClient();

    await tester.pumpWidget(
      TaskwarriorFrontendApp(
        backend: backend,
      ),
    );
    await tester.pumpAndSettle();

    expect(backend.healthChecks, 1);
    expect(backend.queryCalls, 1);
    expect(find.text('Local development adapter ready'), findsOneWidget);
  });
}

class _FakeBackendClient implements TaskBackendClient {
  int healthChecks = 0;
  int queryCalls = 0;

  @override
  Future<BackendHealth> healthcheck() async {
    healthChecks += 1;

    return const BackendHealth(
      label: 'Local development adapter ready',
      environment: 'Backend scaffold mirror',
    );
  }

  @override
  Future<List<TaskItem>> queryTasks(TaskQuery query) async {
    queryCalls += 1;

    return <TaskItem>[
      TaskItem(
        id: 'task-1',
        title: 'Task shell',
        summary: 'Loaded through the backend client boundary.',
        project: 'Flutter',
        status: TaskStatus.pending,
        tags: const <String>['frontend'],
        due: DateTime.utc(2026, 4, 13),
      ),
      const TaskItem(
        id: 'task-2',
        title: 'Recurring review',
        summary: 'Used to keep the board and detail views populated.',
        project: 'Planning',
        status: TaskStatus.recurring,
        tags: const <String>['dashboard'],
      ),
    ].where(query.matches).toList();
  }
}
