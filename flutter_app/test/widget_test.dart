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
    expect(backend.queryCalls, greaterThanOrEqualTo(3));
    expect(find.text('Local development adapter ready'), findsOneWidget);
  });
}

class _FakeBackendClient implements TaskBackendClient {
  int healthChecks = 0;
  int queryCalls = 0;
  final List<TaskItem> _tasks = <TaskItem>[
    TaskItem(
      id: 'task-1',
      title: 'Task shell',
      project: 'Flutter',
      status: TaskStatus.pending,
      tags: const <String>['frontend'],
      annotations: <TaskAnnotation>[
        TaskAnnotation(
          entry: DateTime.utc(2026, 4, 12),
          description: 'Loaded through the backend client boundary.',
        ),
      ],
      due: DateTime.utc(2026, 4, 13),
    ),
    const TaskItem(
      id: 'task-2',
      title: 'Recurring review',
      project: 'Planning',
      status: TaskStatus.recurring,
      tags: <String>['dashboard'],
      annotations: <TaskAnnotation>[],
    ),
  ];

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

    return _tasks.where(query.matches).toList();
  }

  @override
  Future<TaskItem> createTask(CreateTaskInput input) async {
    final task = TaskItem(
      id: 'task-${_tasks.length + 1}',
      title: input.description,
      project: null,
      status: TaskStatus.pending,
      tags: const <String>[],
      annotations: const <TaskAnnotation>[],
    );
    _tasks.add(task);
    return task;
  }

  @override
  Future<TaskItem> getTask(String taskId) async {
    return _tasks.firstWhere((task) => task.id == taskId);
  }

  @override
  Future<TaskItem> transitionTask(
    String taskId,
    TaskTransitionInput input,
  ) async {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    final current = _tasks[index];
    final updated = TaskItem(
      id: current.id,
      title: current.title,
      project: current.project,
      status: input.status,
      tags: current.tags,
      annotations: current.annotations,
      due: current.due,
      waitUntil: current.waitUntil,
      entry: current.entry,
      modified: DateTime.utc(2026, 4, 12),
      end: input.status == TaskStatus.completed
          ? DateTime.utc(2026, 4, 12)
          : null,
    );
    _tasks[index] = updated;
    return updated;
  }

  @override
  Future<TaskItem> updateTask(
    String taskId,
    UpdateTaskInput input,
  ) async {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    final current = _tasks[index];
    final updated = TaskItem(
      id: current.id,
      title: input.description ?? current.title,
      project: input.clearProject ? null : input.project ?? current.project,
      status: current.status,
      tags: input.tags ?? current.tags,
      annotations: current.annotations,
      due: input.clearDue ? null : input.due ?? current.due,
      waitUntil: input.clearWait ? null : input.waitUntil ?? current.waitUntil,
      entry: current.entry,
      modified: DateTime.utc(2026, 4, 12),
      end: current.end,
    );
    _tasks[index] = updated;
    return updated;
  }
}
