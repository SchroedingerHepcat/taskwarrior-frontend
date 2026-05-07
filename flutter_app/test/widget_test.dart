import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/app/app_theme.dart';
import 'package:flutter_app/app/shell_controller.dart';
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

    await tester.tap(find.byIcon(ShellSection.settings.icon));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-screen')), findsOneWidget);
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

  testWidgets('quick create submits with enter', (tester) async {
    final backend = _FakeBackendClient();

    await tester.pumpWidget(
      TaskwarriorFrontendApp(
        backend: backend,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(ShellSection.tasks.icon));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-task-field')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('create-task-field')),
      'Created with enter',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(backend.createdDescriptions, contains('Created with enter'));
    final field = tester.widget<TextField>(
      find.byKey(const Key('create-task-field')),
    );

    expect(field.controller?.text, isEmpty);
  });

  testWidgets('task list groups active and completed tasks', (tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      TaskwarriorFrontendApp(
        backend: _FakeBackendClient(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(ShellSection.tasks.icon));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('task-list-section-To do')), findsOneWidget);
    expect(
      find.byKey(const Key('task-list-section-Completed')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('task-complete-task-1')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('task-complete-task-3')),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.byKey(const Key('task-complete-task-3')), findsOneWidget);
  });

  testWidgets('task list rows are compact until expanded', (tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      TaskwarriorFrontendApp(
        backend: _FakeBackendClient(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(ShellSection.tasks.icon));
    await tester.pumpAndSettle();

    expect(
      find.text('Loaded through the backend client boundary.'),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('task-expand-task-1')));
    await tester.pumpAndSettle();

    expect(
      find.text('Loaded through the backend client boundary.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('task-open-task-1')), findsOneWidget);
  });

  testWidgets('task list prioritizes due date metadata', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      TaskwarriorFrontendApp(
        backend: _FakeBackendClient(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(ShellSection.tasks.icon));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('task-row-due-task-1')), findsOneWidget);
    expect(find.byKey(const Key('task-row-project-task-1')), findsOneWidget);
    expect(find.byKey(const Key('task-row-tags-task-1')), findsOneWidget);
    expect(find.byKey(const Key('task-row-due-task-4')), findsOneWidget);
    expect(find.byKey(const Key('task-row-project-task-4')), findsOneWidget);
    expect(find.byKey(const Key('task-row-tags-task-4')), findsOneWidget);
    expect(find.byKey(const Key('task-tag-badge-task-4')), findsNothing);
    expect(find.byKey(const Key('task-project-badge-task-4')), findsNothing);

    final flutterProjectDecoration = tester
        .widget<Container>(
          find.descendant(
            of: find.byKey(const Key('task-project-badge-task-1')),
            matching: find.byType(Container),
          ),
        )
        .decoration as BoxDecoration;
    final planningProjectDecoration = tester
        .widget<Container>(
          find.descendant(
            of: find.byKey(const Key('task-project-badge-task-2')),
            matching: find.byType(Container),
          ),
        )
        .decoration as BoxDecoration;
    final frontendTagDecoration = tester
        .widget<Container>(
          find.byKey(const Key('task-tag-badge-task-1-frontend')),
        )
        .decoration as BoxDecoration;
    final dashboardTagDecoration = tester
        .widget<Container>(
          find.byKey(const Key('task-tag-badge-task-2-dashboard')),
        )
        .decoration as BoxDecoration;

    expect(flutterProjectDecoration.color, isNotNull);
    expect(frontendTagDecoration.color, isNotNull);
    expect(
      flutterProjectDecoration.color,
      isNot(planningProjectDecoration.color),
    );
    expect(
      frontendTagDecoration.color,
      isNot(dashboardTagDecoration.color),
    );
  });

  testWidgets('task list advanced filters shape backend query', (tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = _FakeBackendClient();

    await tester.pumpWidget(
      TaskwarriorFrontendApp(
        backend: backend,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(ShellSection.tasks.icon));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('advanced-filter-panel')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('filter-project-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flutter').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('filter-tag-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('frontend').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('filter-due-after-text-field')),
    );
    await tester.enterText(
      find.byKey(const Key('filter-due-after-text-field')),
      '2026-4-13',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final query = backend.queries.last;
    expect(query.preset, TaskQueryPreset.custom);
    expect(query.project, 'Flutter');
    expect(query.requiredTag, 'frontend');
    expect(query.noProject, isFalse);
    expect(query.noTags, isFalse);
    expect(query.dueAfter, DateTime.utc(2026, 4, 13));
    expect(query.includeWaiting, isTrue);
    expect(find.byKey(const Key('filter-apply-button')), findsNothing);
    expect(
      find.byKey(const Key('filter-due-before-date-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('filter-due-before-time-button')),
      findsOneWidget,
    );
    expect(find.text('Task shell'), findsOneWidget);
    expect(find.text('Recurring review'), findsNothing);

    await tester.tap(find.byKey(const Key('filter-clear-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('filter-project-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No project').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('filter-tag-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No tags').last);
    await tester.pumpAndSettle();

    final emptyMetadataQuery = backend.queries.last;
    expect(emptyMetadataQuery.noProject, isTrue);
    expect(emptyMetadataQuery.project, isNull);
    expect(emptyMetadataQuery.noTags, isTrue);
    expect(emptyMetadataQuery.requiredTag, isNull);
    expect(find.text('No metadata task'), findsOneWidget);
    expect(find.text('Task shell'), findsNothing);
  });

  test('saved views persist import export and share with backend', () async {
    final backend = _FakeBackendClient();
    final persistedViews = <SavedTaskView>[];
    final controller = ShellController(
      backend: backend,
      saveSavedViews: (views) async {
        persistedViews
          ..clear()
          ..addAll(views);
      },
      clock: () => DateTime.utc(2026, 4, 12, 10),
    );
    addTearDown(controller.dispose);

    await controller.load();
    await controller.setListFilter(
      const TaskListFilter(
        project: 'Flutter',
      ),
    );
    await controller.saveCurrentView('Frontend work');

    expect(persistedViews, hasLength(1));
    expect(persistedViews.single.name, 'Frontend work');
    expect(persistedViews.single.filter.project, 'Flutter');

    final exported = controller.exportSavedViewsJson();
    await controller.saveViewToBackend(persistedViews.single.id);
    expect(backend.savedViews, hasLength(1));

    await controller.deleteSavedView(persistedViews.single.id);
    expect(persistedViews, isEmpty);

    await controller.importSavedViewsJson(exported);
    expect(persistedViews, hasLength(1));

    await controller.deleteSavedView(persistedViews.single.id);
    await controller.refreshBackendSavedViews();
    await controller.retrieveBackendSavedView(backend.savedViews.single.id);
    expect(persistedViews, hasLength(1));
    expect(controller.listTasks.map((task) => task.title), ['Task shell']);
  });

  testWidgets('task list checkbox transitions completion', (tester) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = _FakeBackendClient();

    await tester.pumpWidget(
      TaskwarriorFrontendApp(
        backend: backend,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(ShellSection.tasks.icon));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-complete-task-1')));
    await tester.pumpAndSettle();

    expect(
      backend.transitionedStatuses,
      contains(TaskStatus.completed),
    );
  });

  testWidgets('dashboard task checkbox transitions completion', (tester) async {
    final backend = _FakeBackendClient();

    await tester.pumpWidget(
      TaskwarriorFrontendApp(
        backend: backend,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('dashboard-complete-readyNow-task-1')),
    );
    await tester.pumpAndSettle();

    expect(
      backend.transitionedStatuses,
      contains(TaskStatus.completed),
    );
  });

  testWidgets('dashboard cards scroll instead of overflowing', (tester) async {
    tester.view.physicalSize = const Size(900, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      TaskwarriorFrontendApp(
        backend: _FakeBackendClient(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard-screen')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.byType(SingleChildScrollView).first);
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      Offset.zero,
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('settings can replace the backend server URL', (tester) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final initial = _FakeBackendClient(label: 'Initial backend');
    final replacement = _FakeBackendClient(label: 'Replacement backend');
    String? savedUrl;

    await tester.pumpWidget(
      TaskwarriorFrontendApp(
        backend: initial,
        initialBackendUrl: 'http://127.0.0.1:8080',
        backendFactory: (_) => replacement,
        saveBackendUrl: (baseUrl) async {
          savedUrl = baseUrl;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(ShellSection.settings.icon));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('backend-url-field')),
      'http://127.0.0.1:9090',
    );
    await tester.tap(find.byKey(const Key('backend-url-save')));
    await tester.pumpAndSettle();

    expect(initial.healthChecks, 1);
    expect(replacement.healthChecks, 1);
    expect(savedUrl, 'http://127.0.0.1:9090');
    final label = tester.widget<Text>(
      find.byKey(const Key('settings-connection-label')),
    );

    expect(label.data, 'Replacement backend');
  });

  testWidgets('settings can change theme preference', (tester) async {
    AppThemePreference? savedTheme;

    await tester.pumpWidget(
      TaskwarriorFrontendApp(
        backend: _FakeBackendClient(),
        saveThemePreference: (preference) async {
          savedTheme = preference;
        },
      ),
    );
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.dark);

    await tester.tap(find.byIcon(ShellSection.settings.icon));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    final updatedApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(updatedApp.themeMode, ThemeMode.light);
    expect(savedTheme, AppThemePreference.light);
  });

  testWidgets('app starts at settings when no backend is configured',
      (tester) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      TaskwarriorFrontendApp(
        backendFactory: (_) => _FakeBackendClient(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-screen')), findsOneWidget);
    expect(find.byKey(const Key('backend-url-field')), findsOneWidget);
    final label = tester.widget<Text>(
      find.byKey(const Key('settings-connection-label')),
    );

    expect(label.data, 'Backend not configured');
  });

  testWidgets('settings remains available when backend is unavailable',
      (tester) async {
    await tester.pumpWidget(
      TaskwarriorFrontendApp(
        backend: _FailingBackendClient(),
        initialBackendUrl: 'http://127.0.0.1:8080',
        backendFactory: (_) => _FakeBackendClient(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Could not connect to http://127.0.0.1:8080'),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(ShellSection.settings.icon));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-screen')), findsOneWidget);
    expect(find.byKey(const Key('backend-url-field')), findsOneWidget);
  });

  testWidgets('task detail auto-saves edits and supports undo', (tester) async {
    final backend = _FakeBackendClient();

    await tester.pumpWidget(
      TaskwarriorFrontendApp(
        backend: backend,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(ShellSection.detail.icon));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('detail-description-field')),
      'Task shell updated',
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(backend.updatedDescriptions, contains('Task shell updated'));
    expect(find.byKey(const Key('detail-save-button')), findsNothing);

    await tester.tap(find.byKey(const Key('detail-undo-button')));
    await tester.pumpAndSettle();

    expect(backend.updatedDescriptions, contains('Task shell'));
  });

  testWidgets('task detail autosave keeps editor visible', (tester) async {
    final backend = _FakeBackendClient();

    await tester.pumpWidget(
      TaskwarriorFrontendApp(
        backend: backend,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(ShellSection.detail.icon));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('detail-description-field')),
      'Task shell still focused',
    );
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byKey(const Key('detail-description-field')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('task detail waits for complete date before autosave',
      (tester) async {
    final backend = _FakeBackendClient();

    await tester.pumpWidget(
      TaskwarriorFrontendApp(
        backend: backend,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(ShellSection.detail.icon));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('detail-due-field')),
      '2026-',
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(backend.updatedDueDates, isEmpty);
    expect(find.textContaining('Backend request failed'), findsNothing);
  });

  testWidgets('task detail accepts flexible date input', (tester) async {
    final backend = _FakeBackendClient();

    await tester.pumpWidget(
      TaskwarriorFrontendApp(
        backend: backend,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(ShellSection.detail.icon));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('detail-due-field')),
      '2026-5-8',
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(
      backend.updatedDueDates,
      contains(DateTime.utc(2026, 5, 8)),
    );
  });

  testWidgets('date picker opens only from calendar button', (tester) async {
    await tester.pumpWidget(
      TaskwarriorFrontendApp(
        backend: _FakeBackendClient(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(ShellSection.detail.icon));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-due-field')));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsNothing);
    expect(find.byKey(const Key('detail-due-picker-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('detail-due-picker-button')));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  test('ready list mode uses backend next-actions query preset', () {
    final query = TaskQuery.forListMode(
      mode: TaskListMode.ready,
      referenceTime: DateTime.utc(2026, 4, 12),
    );

    expect(query.preset, TaskQueryPreset.nextActions);
    expect(query.statuses, const <TaskStatus>[TaskStatus.pending]);
    expect(query.includeWaiting, isFalse);
    expect(query.includeBlocked, isFalse);
  });
}

class _FailingBackendClient implements TaskBackendClient {
  @override
  Future<BackendHealth> healthcheck() {
    throw Exception('ClientException with SocketException: Connection refused');
  }

  @override
  Future<TaskItem> createTask(CreateTaskInput input) {
    throw UnimplementedError();
  }

  @override
  Future<TaskItem> getTask(String taskId) {
    throw UnimplementedError();
  }

  @override
  Future<List<TaskItem>> queryTasks(TaskQuery query) {
    throw UnimplementedError();
  }

  @override
  Future<TaskItem> transitionBoardLane(
    String taskId,
    BoardTransitionInput input,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<TaskItem> transitionTask(
    String taskId,
    TaskTransitionInput input,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<TaskItem> updateTask(
    String taskId,
    UpdateTaskInput input,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<List<SavedTaskView>> listSavedViews() {
    throw UnimplementedError();
  }

  @override
  Future<void> saveSavedView(SavedTaskView view) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteSavedView(String viewId) {
    throw UnimplementedError();
  }
}

class _FakeBackendClient implements TaskBackendClient {
  _FakeBackendClient({
    this.label = 'Local development adapter ready',
  });

  final String label;
  int healthChecks = 0;
  int queryCalls = 0;
  final List<TaskQuery> queries = <TaskQuery>[];
  final List<String> createdDescriptions = <String>[];
  final List<TaskStatus> transitionedStatuses = <TaskStatus>[];
  final List<String> updatedDescriptions = <String>[];
  final List<DateTime?> updatedDueDates = <DateTime?>[];
  final List<SavedTaskView> savedViews = <SavedTaskView>[];
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
    const TaskItem(
      id: 'task-4',
      title: 'No metadata task',
      project: null,
      status: TaskStatus.pending,
      tags: <String>[],
      annotations: <TaskAnnotation>[],
    ),
    const TaskItem(
      id: 'task-3',
      title: 'Completed task',
      project: 'Archive',
      status: TaskStatus.completed,
      tags: <String>['done'],
      annotations: <TaskAnnotation>[],
    ),
  ];

  @override
  Future<BackendHealth> healthcheck() async {
    healthChecks += 1;

    return BackendHealth(
      label: label,
      environment: 'Backend scaffold mirror',
    );
  }

  @override
  Future<List<SavedTaskView>> listSavedViews() async {
    return List<SavedTaskView>.unmodifiable(savedViews);
  }

  @override
  Future<void> saveSavedView(SavedTaskView view) async {
    final index = savedViews.indexWhere((item) => item.id == view.id);
    if (index == -1) {
      savedViews.add(view);
    } else {
      savedViews[index] = view;
    }
  }

  @override
  Future<void> deleteSavedView(String viewId) async {
    savedViews.removeWhere((view) => view.id == viewId);
  }

  @override
  Future<List<TaskItem>> queryTasks(TaskQuery query) async {
    queryCalls += 1;
    queries.add(query);

    return _tasks.where(query.matches).toList();
  }

  @override
  Future<TaskItem> createTask(CreateTaskInput input) async {
    createdDescriptions.add(input.description);
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
    transitionedStatuses.add(input.status);
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
      scheduled: current.scheduled,
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
      scheduled:
          input.clearScheduled ? null : input.scheduled ?? current.scheduled,
      waitUntil: input.clearWait ? null : input.waitUntil ?? current.waitUntil,
      entry: current.entry,
      modified: DateTime.utc(2026, 4, 12),
      end: current.end,
    );
    _tasks[index] = updated;
    if (input.description != null) {
      updatedDescriptions.add(input.description!);
    }
    if (input.due != null || input.clearDue) {
      updatedDueDates.add(input.due);
    }
    return updated;
  }

  @override
  Future<TaskItem> transitionBoardLane(
    String taskId,
    BoardTransitionInput input,
  ) async {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    final current = _tasks[index];
    final updated = TaskItem(
      id: current.id,
      title: current.title,
      project: current.project,
      status: input.lane == BoardLane.completed
          ? TaskStatus.completed
          : current.status,
      tags: current.tags,
      annotations: current.annotations,
      due: current.due,
      scheduled: current.scheduled,
      waitUntil: input.lane == BoardLane.waiting ? input.waitUntil : null,
      entry: current.entry,
      modified: DateTime.utc(2026, 4, 12),
      end: input.lane == BoardLane.completed ? DateTime.utc(2026, 4, 12) : null,
    );
    _tasks[index] = updated;
    return updated;
  }
}
