import '../models/shell_models.dart';
import 'task_backend_client.dart';

class LocalDevelopmentBackendClient implements TaskBackendClient {
  LocalDevelopmentBackendClient({
    Duration latency = const Duration(milliseconds: 120),
  }) : _latency = latency;

  final Duration _latency;

  @override
  Future<BackendHealth> healthcheck() async {
    await Future<void>.delayed(_latency);

    return const BackendHealth(
      label: 'Local development adapter ready',
      environment: 'Backend scaffold mirror',
    );
  }

  @override
  Future<List<TaskItem>> queryTasks(TaskQuery query) async {
    await Future<void>.delayed(_latency);

    return _sampleTasks.where((task) => query.matches(task)).toList();
  }
}

final List<TaskItem> _sampleTasks = <TaskItem>[
  TaskItem(
    id: 'task-1',
    title: 'Review inbox and shape the week',
    summary: 'Acts as the dashboard anchor for list and board previews.',
    project: 'Planning',
    status: TaskStatus.pending,
    tags: <String>['gtd', 'weekly'],
    due: DateTime.utc(2026, 4, 13, 16),
  ),
  TaskItem(
    id: 'task-2',
    title: 'Refine backend query envelope',
    summary: 'Represents a focused list item coming from query results.',
    project: 'Backend',
    status: TaskStatus.pending,
    tags: <String>['api', 'frontend'],
    due: DateTime.utc(2026, 4, 12, 18),
  ),
  TaskItem(
    id: 'task-3',
    title: 'Sketch dashboard widget layout',
    summary: 'Shows how dashboard cards can be driven by one task list.',
    project: 'Flutter',
    status: TaskStatus.recurring,
    tags: <String>['dashboard'],
    due: DateTime.utc(2026, 4, 14, 9),
  ),
  TaskItem(
    id: 'task-4',
    title: 'Waiting on sync design note',
    summary: 'Used to prove waiting-state handling in the shell.',
    project: 'Architecture',
    status: TaskStatus.pending,
    tags: <String>['waiting'],
    waitUntil: DateTime.utc(2026, 4, 15, 8),
  ),
  TaskItem(
    id: 'task-5',
    title: 'Close Milestone 2 API scaffold',
    summary: 'A completed task for board and detail placeholders.',
    project: 'Backend',
    status: TaskStatus.completed,
    tags: <String>['milestone'],
    due: DateTime.utc(2026, 4, 11, 12),
  ),
];
