import 'package:flutter/foundation.dart';

import '../backend/task_backend_client.dart';
import '../models/shell_models.dart';

class ShellController extends ChangeNotifier {
  ShellController({
    TaskBackendClient? backend,
    String? backendUrl,
    TaskBackendClient Function(String baseUrl)? backendFactory,
    Future<void> Function(String baseUrl)? saveBackendUrl,
    DateTime Function()? clock,
  })  : _backend = backend,
        _backendUrl = backendUrl,
        _backendFactory = backendFactory,
        _saveBackendUrl = saveBackendUrl,
        _clock = clock ?? DateTime.now;

  TaskBackendClient? _backend;
  String? _backendUrl;
  final TaskBackendClient Function(String baseUrl)? _backendFactory;
  final Future<void> Function(String baseUrl)? _saveBackendUrl;
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
  String? get backendUrl => _backendUrl;
  Set<DashboardWidgetType> get enabledWidgets => Set.of(_enabledWidgets);
  String? get boardIntent => _boardIntent;

  String get connectionLabel {
    if (_backend == null) {
      return 'Backend not configured';
    }

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
    if (_backend == null) {
      _isLoading = false;
      _errorMessage = 'Enter the backend API URL in Settings to connect.';
      notifyListeners();
      return;
    }

    await _refresh();
  }

  Future<void> createTask(String description) async {
    await _runMutation(() async {
      final backend = _backend;
      if (backend == null) {
        _errorMessage = 'Enter the backend API URL in Settings to connect.';
        return;
      }

      final task = await backend.createTask(
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
      final backend = _backend;
      if (backend == null) {
        _errorMessage = 'Enter the backend API URL in Settings to connect.';
        return;
      }

      final updated = await backend.updateTask(task.id, input);
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
      final backend = _backend;
      if (backend == null) {
        _errorMessage = 'Enter the backend API URL in Settings to connect.';
        return;
      }

      final updated = await backend.transitionTask(
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

  Future<void> configureBackendUrl(String baseUrl) async {
    final normalized = baseUrl.trim();
    if (normalized.isEmpty) {
      _errorMessage = 'Backend URL is required.';
      notifyListeners();
      return;
    }

    final factory = _backendFactory;
    if (factory == null) {
      _errorMessage = 'This build does not support backend URL changes.';
      notifyListeners();
      return;
    }

    _backend = factory(normalized);
    _backendUrl = normalized;
    await _saveBackendUrl?.call(normalized);
    await _refresh();
  }

  void selectTask(String taskId) {
    _selectedTaskId = taskId;
    notifyListeners();
  }

  Future<void> moveTaskToBoardLane({
    required TaskItem task,
    required BoardLane lane,
  }) async {
    await _runMutation(() async {
      final backend = _backend;
      if (backend == null) {
        _errorMessage = 'Enter the backend API URL in Settings to connect.';
        return;
      }

      final updated = await backend.transitionBoardLane(
        task.id,
        BoardTransitionInput(
          lane: lane,
          waitUntil: lane == BoardLane.waiting
              ? _clock().toUtc().add(const Duration(days: 1))
              : null,
        ),
      );
      _selectedTaskId = updated.id;
      _boardIntent = 'Moved "${task.title}" to ${lane.title}.';
      await _refresh();
    });
  }

  Future<void> _refresh() async {
    final backend = _backend;
    if (backend == null) {
      _isLoading = false;
      _errorMessage = 'Enter the backend API URL in Settings to connect.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _health = await backend.healthcheck();
      await _refreshTaskViews();
      await _refreshDashboardWidgets();
    } catch (error) {
      _errorMessage = _humanReadableError(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _refreshTaskViews() async {
    final referenceTime = _clock().toUtc();
    final backend = _backend;
    if (backend == null) {
      _allTasks = const <TaskItem>[];
      _listTasks = const <TaskItem>[];
      return;
    }

    _allTasks = await backend.queryTasks(
      TaskQuery.all(referenceTime: referenceTime),
    );
    _listTasks = await backend.queryTasks(
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
      final backend = _backend;
      if (backend == null) {
        return;
      }

      final tasks = await backend.queryTasks(
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
      _errorMessage = _humanReadableError(error);
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  String _humanReadableError(Object error) {
    final backend = _backendUrl ?? 'the configured backend';
    final message = error.toString();

    if (message.contains('Connection refused') ||
        message.contains('SocketException') ||
        message.contains('ClientException')) {
      return 'Could not connect to $backend. Make sure the Rust backend is '
          'running, or open Settings and enter the correct backend API URL.';
    }

    if (message.contains('Failed host lookup')) {
      return 'Could not find the backend host for $backend. Check the backend '
          'API URL in Settings.';
    }

    if (message.contains('HTTP 404')) {
      return 'The backend at $backend responded, but it does not look like the '
          'expected Taskwarrior Frontend API.';
    }

    return 'Backend request failed: $message';
  }
}
