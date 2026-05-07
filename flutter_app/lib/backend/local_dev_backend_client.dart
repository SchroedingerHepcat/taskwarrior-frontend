import '../models/shell_models.dart';
import 'task_backend_client.dart';

class LocalDevelopmentBackendClient implements TaskBackendClient {
  LocalDevelopmentBackendClient({
    Duration latency = const Duration(milliseconds: 40),
  })  : _latency = latency,
        _tasks = List<TaskItem>.from(_sampleTasks);

  final Duration _latency;
  final List<TaskItem> _tasks;

  @override
  Future<BackendHealth> healthcheck() async {
    await Future<void>.delayed(_latency);

    return const BackendHealth(
      label: 'Local development adapter ready',
      environment: 'Backend scaffold mirror',
    );
  }

  @override
  Future<TaskItem> createTask(CreateTaskInput input) async {
    await Future<void>.delayed(_latency);

    final task = TaskItem(
      id: 'task-${_tasks.length + 1}',
      title: input.description,
      project: null,
      status: TaskStatus.pending,
      tags: const <String>[],
      annotations: const <TaskAnnotation>[],
      entry: DateTime.now().toUtc(),
      modified: DateTime.now().toUtc(),
    );
    _tasks.add(task);
    return task;
  }

  @override
  Future<TaskItem> getTask(String taskId) async {
    await Future<void>.delayed(_latency);
    return _tasks.firstWhere((task) => task.id == taskId);
  }

  @override
  Future<List<TaskItem>> queryTasks(TaskQuery query) async {
    await Future<void>.delayed(_latency);

    final tasks = _tasks.where((task) => query.matches(task)).toList();
    tasks.sort((left, right) => left.title.compareTo(right.title));
    return tasks;
  }

  @override
  Future<TaskItem> transitionTask(
    String taskId,
    TaskTransitionInput input,
  ) async {
    await Future<void>.delayed(_latency);

    final index = _tasks.indexWhere((task) => task.id == taskId);
    final current = _tasks[index];
    final updated = TaskItem(
      id: current.id,
      title: current.title,
      project: current.project,
      status: input.status,
      tags: current.tags,
      annotations: current.annotations,
      entry: current.entry,
      modified: DateTime.now().toUtc(),
      due: current.due,
      scheduled: current.scheduled,
      waitUntil: current.waitUntil,
      end: input.status == TaskStatus.completed ? DateTime.now().toUtc() : null,
    );
    _tasks[index] = updated;
    return updated;
  }

  @override
  Future<TaskItem> updateTask(
    String taskId,
    UpdateTaskInput input,
  ) async {
    await Future<void>.delayed(_latency);

    final index = _tasks.indexWhere((task) => task.id == taskId);
    final current = _tasks[index];
    final annotations = List<TaskAnnotation>.from(current.annotations);
    if (input.addAnnotation != null && input.addAnnotation!.trim().isNotEmpty) {
      annotations.add(
        TaskAnnotation(
          entry: DateTime.now().toUtc(),
          description: input.addAnnotation!.trim(),
        ),
      );
    }

    final updated = TaskItem(
      id: current.id,
      title: input.description ?? current.title,
      project: input.clearProject ? null : input.project ?? current.project,
      status: current.status,
      tags: input.tags ?? current.tags,
      annotations: annotations,
      entry: current.entry,
      modified: DateTime.now().toUtc(),
      due: input.clearDue ? null : input.due ?? current.due,
      scheduled:
          input.clearScheduled ? null : input.scheduled ?? current.scheduled,
      waitUntil: input.clearWait ? null : input.waitUntil ?? current.waitUntil,
      end: current.end,
    );
    _tasks[index] = updated;
    return updated;
  }

  @override
  Future<TaskItem> transitionBoardLane(
    String taskId,
    BoardTransitionInput input,
  ) async {
    await Future<void>.delayed(_latency);

    final index = _tasks.indexWhere((task) => task.id == taskId);
    final current = _tasks[index];
    final status = input.lane == BoardLane.completed
        ? TaskStatus.completed
        : current.status;
    final updated = TaskItem(
      id: current.id,
      title: current.title,
      project: current.project,
      status: status,
      tags: current.tags,
      annotations: current.annotations,
      entry: current.entry,
      modified: DateTime.now().toUtc(),
      due: current.due,
      scheduled: current.scheduled,
      waitUntil: input.lane == BoardLane.waiting ? input.waitUntil : null,
      end: status == TaskStatus.completed ? DateTime.now().toUtc() : null,
    );
    _tasks[index] = updated;
    return updated;
  }
}

final List<TaskItem> _sampleTasks = <TaskItem>[
  TaskItem(
    id: 'task-1',
    title: 'Review inbox and shape the week',
    project: 'Planning',
    status: TaskStatus.pending,
    tags: <String>['gtd', 'weekly'],
    annotations: <TaskAnnotation>[
      TaskAnnotation(
        entry: DateTime.utc(2026, 4, 11, 9),
        description:
            'Acts as the dashboard anchor for list and board previews.',
      ),
    ],
    due: DateTime.utc(2026, 4, 13, 16),
  ),
  TaskItem(
    id: 'task-2',
    title: 'Refine backend query envelope',
    project: 'Backend',
    status: TaskStatus.pending,
    tags: <String>['api', 'frontend'],
    annotations: const <TaskAnnotation>[],
    due: DateTime.utc(2026, 4, 12, 18),
  ),
];
