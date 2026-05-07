import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../backend/task_backend_client.dart';
import '../models/shell_models.dart';
import 'app_theme.dart';

class ShellController extends ChangeNotifier {
  ShellController({
    TaskBackendClient? backend,
    String? backendUrl,
    TaskBackendClient Function(String baseUrl)? backendFactory,
    Future<void> Function(String baseUrl)? saveBackendUrl,
    AppThemePreference themePreference = AppThemePreference.dark,
    Future<void> Function(AppThemePreference preference)? saveThemePreference,
    List<SavedTaskView> savedViews = const <SavedTaskView>[],
    Future<void> Function(List<SavedTaskView> views)? saveSavedViews,
    DateTime Function()? clock,
  })  : _backend = backend,
        _backendUrl = backendUrl,
        _backendFactory = backendFactory,
        _saveBackendUrl = saveBackendUrl,
        _themePreference = themePreference,
        _saveThemePreference = saveThemePreference,
        _savedViews = List<SavedTaskView>.from(savedViews),
        _saveSavedViews = saveSavedViews,
        _clock = clock ?? DateTime.now;

  TaskBackendClient? _backend;
  String? _backendUrl;
  final TaskBackendClient Function(String baseUrl)? _backendFactory;
  final Future<void> Function(String baseUrl)? _saveBackendUrl;
  final Future<void> Function(AppThemePreference preference)?
      _saveThemePreference;
  final Future<void> Function(List<SavedTaskView> views)? _saveSavedViews;
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
  TaskListFilter _listFilter = const TaskListFilter();
  List<SavedTaskView> _savedViews;
  List<SavedTaskView> _backendSavedViews = const <SavedTaskView>[];
  String? _selectedSavedViewId;
  AppThemePreference _themePreference;
  String? _selectedTaskId;
  String? _boardIntent;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  BackendHealth? get health => _health;
  List<TaskItem> get allTasks => List.unmodifiable(_allTasks);
  List<TaskItem> get listTasks => List.unmodifiable(_listTasks);
  TaskListMode get listMode => _listMode;
  TaskListFilter get listFilter => _listFilter;
  List<SavedTaskView> get savedViews => List.unmodifiable(_savedViews);
  List<SavedTaskView> get backendSavedViews {
    return List.unmodifiable(_backendSavedViews);
  }

  String? get selectedSavedViewId => _selectedSavedViewId;
  AppThemePreference get themePreference => _themePreference;
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
      await _refresh(showLoading: false);
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
      await _refresh(showLoading: false);
    });
  }

  Future<void> transitionSelectedTask(TaskStatus status) async {
    final task = selectedTask;
    if (task == null) {
      return;
    }

    await transitionTask(task, status);
  }

  Future<void> transitionTask(
    TaskItem task,
    TaskStatus status,
  ) async {
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
      await _refresh(showLoading: false);
    });
  }

  Future<void> setListMode(TaskListMode mode) async {
    _listMode = mode;
    _listFilter = const TaskListFilter();
    _selectedSavedViewId = null;
    await _refreshTaskViews();
    notifyListeners();
  }

  Future<void> setListFilter(TaskListFilter filter) async {
    _listFilter = filter;
    _listMode = TaskListMode.all;
    _selectedSavedViewId = null;
    await _refreshTaskViews();
    notifyListeners();
  }

  Future<void> clearListFilter() async {
    _listFilter = const TaskListFilter();
    _listMode = TaskListMode.all;
    _selectedSavedViewId = null;
    await _refreshTaskViews();
    notifyListeners();
  }

  Future<void> selectSavedView(String viewId) async {
    final view = _savedViews.firstWhere((view) => view.id == viewId);
    _selectedSavedViewId = view.id;
    _listFilter = view.filter;
    _listMode = TaskListMode.all;
    await _refreshTaskViews();
    notifyListeners();
  }

  Future<void> saveCurrentView(
    String name, {
    String? viewId,
  }) async {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      _errorMessage = 'Saved view name is required.';
      notifyListeners();
      return;
    }

    final now = _clock().toUtc();
    final id = viewId ?? _newSavedViewId(now);
    final view = SavedTaskView(
      id: id,
      name: normalized,
      filter: _listFilter,
      updatedAt: now,
    );
    _upsertSavedView(view);
    _selectedSavedViewId = view.id;
    await _persistSavedViews();
    notifyListeners();
  }

  Future<void> deleteSavedView(String viewId) async {
    _savedViews = _savedViews.where((view) => view.id != viewId).toList();
    if (_selectedSavedViewId == viewId) {
      _selectedSavedViewId = null;
    }
    await _persistSavedViews();
    notifyListeners();
  }

  String exportSavedViewsJson({
    Iterable<String>? viewIds,
  }) {
    final ids = viewIds?.toSet();
    final views = ids == null
        ? _savedViews
        : _savedViews.where((view) => ids.contains(view.id)).toList();

    return const JsonEncoder.withIndent('  ').convert(
      <String, dynamic>{
        'version': 1,
        'views': views.map((view) => view.toJson()).toList(),
      },
    );
  }

  Future<void> importSavedViewsJson(String raw) async {
    try {
      final views = _decodeSavedViews(raw);
      for (final view in views) {
        _upsertSavedView(view);
      }
      await _persistSavedViews();
      notifyListeners();
    } catch (error) {
      _errorMessage = 'Could not import saved views: $error';
      notifyListeners();
    }
  }

  Future<void> refreshBackendSavedViews() async {
    final backend = _backend;
    if (backend == null) {
      _errorMessage = 'Enter the backend API URL in Settings to connect.';
      notifyListeners();
      return;
    }

    try {
      _backendSavedViews = await backend.listSavedViews();
      notifyListeners();
    } catch (error) {
      _errorMessage = _humanReadableError(error);
      notifyListeners();
    }
  }

  Future<void> saveViewToBackend(String viewId) async {
    final backend = _backend;
    if (backend == null) {
      _errorMessage = 'Enter the backend API URL in Settings to connect.';
      notifyListeners();
      return;
    }

    final view = _savedViews.firstWhere((view) => view.id == viewId);
    await backend.saveSavedView(view);
    await refreshBackendSavedViews();
  }

  Future<void> retrieveBackendSavedView(String viewId) async {
    final view = _backendSavedViews.firstWhere((view) => view.id == viewId);
    _upsertSavedView(view);
    await _persistSavedViews();
    await selectSavedView(view.id);
  }

  Future<void> deleteBackendSavedView(String viewId) async {
    final backend = _backend;
    if (backend == null) {
      _errorMessage = 'Enter the backend API URL in Settings to connect.';
      notifyListeners();
      return;
    }

    await backend.deleteSavedView(viewId);
    await refreshBackendSavedViews();
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

  Future<void> setThemePreference(AppThemePreference preference) async {
    _themePreference = preference;
    notifyListeners();
    await _saveThemePreference?.call(preference);
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
      await _refresh(showLoading: false);
    });
  }

  Future<void> _refresh({
    bool showLoading = true,
  }) async {
    final backend = _backend;
    if (backend == null) {
      _isLoading = false;
      _errorMessage = 'Enter the backend API URL in Settings to connect.';
      notifyListeners();
      return;
    }

    if (showLoading) {
      _isLoading = true;
    }
    _errorMessage = null;
    notifyListeners();

    try {
      _health = await backend.healthcheck();
      _backendSavedViews = await backend.listSavedViews();
      await _refreshTaskViews();
      await _refreshDashboardWidgets();
    } catch (error) {
      _errorMessage = _humanReadableError(error);
    } finally {
      if (showLoading) {
        _isLoading = false;
      }
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
      _listFilter.isDefault
          ? TaskQuery.forListMode(
              mode: _listMode,
              referenceTime: referenceTime,
            )
          : _listFilter.toQuery(referenceTime: referenceTime),
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

  void _upsertSavedView(SavedTaskView view) {
    final index = _savedViews.indexWhere((item) => item.id == view.id);
    if (index == -1) {
      _savedViews = <SavedTaskView>[..._savedViews, view];
    } else {
      _savedViews = <SavedTaskView>[..._savedViews]..[index] = view;
    }
    _savedViews.sort((left, right) => left.name.compareTo(right.name));
  }

  Future<void> _persistSavedViews() async {
    await _saveSavedViews?.call(List<SavedTaskView>.unmodifiable(_savedViews));
  }

  String _newSavedViewId(DateTime now) {
    return 'view-${now.microsecondsSinceEpoch}';
  }

  List<SavedTaskView> _decodeSavedViews(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      final views = decoded['views'];
      if (views is List<dynamic>) {
        return views
            .map((view) => SavedTaskView.fromJson(
                  view as Map<String, dynamic>,
                ))
            .toList();
      }

      return <SavedTaskView>[SavedTaskView.fromJson(decoded)];
    }

    if (decoded is List<dynamic>) {
      return decoded
          .map((view) => SavedTaskView.fromJson(
                view as Map<String, dynamic>,
              ))
          .toList();
    }

    throw const FormatException('expected a saved view or saved view list');
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
