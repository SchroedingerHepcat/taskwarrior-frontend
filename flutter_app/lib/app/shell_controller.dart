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
  String? _errorMessage;
  BackendHealth? _health;
  List<TaskItem> _tasks = const [];
  String? _selectedTaskId;
  String? _boardIntent;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  BackendHealth? get health => _health;
  List<TaskItem> get tasks => List.unmodifiable(_tasks);
  String? get boardIntent => _boardIntent;

  String get connectionLabel {
    if (_isLoading) {
      return 'Connecting to local development adapter';
    }

    if (_errorMessage != null) {
      return 'Backend unavailable';
    }

    return _health?.label ?? 'Backend ready';
  }

  TaskItem? get selectedTask {
    final selectedId = _selectedTaskId;
    if (selectedId == null && _tasks.isNotEmpty) {
      return _tasks.first;
    }

    return _tasks.where((task) => task.id == selectedId).firstOrNull;
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final health = await _backend.healthcheck();
      final query = TaskQuery.all(referenceTime: _clock());
      final tasks = await _backend.queryTasks(query);

      _health = health;
      _tasks = tasks;
      _selectedTaskId = tasks.isEmpty ? null : tasks.first.id;
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
        'server transitions are wired end-to-end.';
    notifyListeners();
  }
}
