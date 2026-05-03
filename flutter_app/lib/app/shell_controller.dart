import 'package:flutter/foundation.dart';

import '../backend/task_backend_client.dart';
import '../models/shell_models.dart';

class ShellController extends ChangeNotifier {
  ShellController({
    required TaskBackendClient backend,
    DateTime Function()? clock,
  })  : _backend = backend,
        _clock = clock ?? DateTime.now;

  final TaskBackendClient _backend;
  final DateTime Function() _clock;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  BackendHealth? _health;
  List<TaskItem> _allTasks = const <TaskItem>[];
  List<TaskItem> _listTasks = const <TaskItem>[];
  final Set<DashboardWidgetType> _enabledWidgets =
      DashboardWidgetType.values.toSet();
  final Map<DashboardWidgetType, DashboardWidgetData> _dashboardWidgets =
      <DashboardWidgetType, DashboardWidgetData>{};
  TaskListMode _listMode = TaskListMode.all;
  String? _selectedTaskId;
  String? _boardIntent;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  BackendHealth? get health => _health;
  List<TaskItem> get allTasks => List.unmodifiable(_allTasks);
  List<TaskItem> get listTasks => List.unmodifiable(_listTasks);
  TaskListMode get listMode => _listMode;
  Set<DashboardWidgetType> get enabledWidgets => Set.of(_enabledWidgets);
  String? get boardIntent => _boardIntent;

  String get connectionLabel {
    if (_isLoading) {
      return 'Connecting to HTTP backend';
    }

    if (_errorMessage != null) {
      return 'Backend unavailable';
    }

    return _health?.label ?? 'Backend ready';
  }

  TaskItem? get selectedTask {
    final selectedId = _selectedTaskId;
    if (selectedId == null && _allTasks.isNotEmpty) {
      return _allTasks.first;
    }

    return _allTasks.where((task) => task.id == selectedId).firstOrNull;
  }

  DashboardWidgetData? widgetDataFor(DashboardWidgetType widget) {
    return _dashboardWidgets[widget];
  }

  Future<void> load() async {
    await _refresh();
  }

  Future<void> createTask(String description) async {
    await _runMutation(() async {
      final task = await _backend.createTask(
        CreateTaskInput(description: description.trim()),
      );
      _selectedTaskId = task.id;
      await _refresh();
    });
  }

  Future<void> updateSelectedTask(UpdateTaskInput input) async {
    final task = selectedTask;
    if (task == null) {
      return;
    }

    await _runMutation(() async {
      final updated = await _backend.updateTask(task.id, input);
      _selectedTaskId = updated.id;
      await _refresh();
    });
  }

  Future<void> transitionSelectedTask(TaskStatus status) async {
    final task = selectedTask;
    if (task == null) {
      return;
    }

    await _runMutation(() async {
      final updated = await _backend.transitionTask(
        task.id,
        TaskTransitionInput(status: status),
      );
      _selectedTaskId = updated.id;
      await _refresh();
    });
  }

  Future<void> setListMode(TaskListMode mode) async {
    _listMode = mode;
    await _refreshTaskViews();
    notifyListeners();
  }

  Future<void> toggleWidget(DashboardWidgetType widget) async {
    if (_enabledWidgets.contains(widget)) {
      _enabledWidgets.remove(widget);
      _dashboardWidgets.remove(widget);
    } else {
      _enabledWidgets.add(widget);
    }

    await _refreshDashboardWidgets();
    notifyListeners();
  }

  void selectTask(String taskId) {
    _selectedTaskId = taskId;
    notifyListeners();
  }

  void recordBoardIntent({
    required TaskItem task,
    required BoardLane lane,
  }) {
    _selectedTaskId = task.id;
    _boardIntent = 'Queue "${task.title}" for ${lane.title} once '
        'server transitions expand beyond list/detail flows.';
    notifyListeners();
  }

  Future<void> _refresh() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _health = await _backend.healthcheck();
      await _refreshTaskViews();
      await _refreshDashboardWidgets();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _refreshTaskViews() async {
    final referenceTime = _clock().toUtc();
    _allTasks = await _backend.queryTasks(
      TaskQuery.all(referenceTime: referenceTime),
    );
    _listTasks = await _backend.queryTasks(
      TaskQuery.forListMode(
        mode: _listMode,
        referenceTime: referenceTime,
      ),
    );

    final selectedId = _selectedTaskId;
    if (selectedId != null && _allTasks.any((task) => task.id == selectedId)) {
      _selectedTaskId = selectedId;
    } else {
      _selectedTaskId = _allTasks.isEmpty ? null : _allTasks.first.id;
    }
  }

  Future<void> _refreshDashboardWidgets() async {
    final referenceTime = _clock().toUtc();
    _dashboardWidgets.clear();

    for (final widget in _enabledWidgets) {
      final tasks = await _backend.queryTasks(
        TaskQuery.forDashboardWidget(
          widget: widget,
          referenceTime: referenceTime,
        ),
      );
      _dashboardWidgets[widget] = DashboardWidgetData(
        widget: widget,
        tasks: tasks,
      );
    }
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await action();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
