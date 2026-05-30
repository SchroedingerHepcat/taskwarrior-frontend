import 'package:flutter/material.dart';

enum ShellSection {
  dashboard(
    label: 'Dashboard',
    icon: Icons.space_dashboard_outlined,
  ),
  tasks(
    label: 'Tasks',
    icon: Icons.checklist_rtl_outlined,
  ),
  board(
    label: 'Board',
    icon: Icons.view_kanban_outlined,
  ),
  detail(
    label: 'Detail',
    icon: Icons.notes_outlined,
  ),
  settings(
    label: 'Settings',
    icon: Icons.tune_outlined,
  );

  const ShellSection({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;
}

enum TaskStatus {
  pending('Pending'),
  recurring('Recurring'),
  completed('Completed'),
  deleted('Deleted');

  const TaskStatus(this.label);

  final String label;

  String get apiValue => name;

  static TaskStatus fromApi(String raw) {
    return TaskStatus.values.firstWhere(
      (status) => status.apiValue == raw,
      orElse: () => TaskStatus.pending,
    );
  }
}

enum TaskSort {
  dueAsc('due_asc'),
  modifiedDesc('modified_desc'),
  descriptionAsc('description_asc');

  const TaskSort(this.apiValue);

  final String apiValue;
}

enum TaskQueryPreset {
  custom('custom'),
  inbox('inbox'),
  nextActions('next_actions'),
  waiting('waiting'),
  review('review');

  const TaskQueryPreset(this.apiValue);

  final String apiValue;
}

TaskQueryPreset _presetFromApi(String raw) {
  return TaskQueryPreset.values.firstWhere(
    (preset) => preset.apiValue == raw,
    orElse: () => TaskQueryPreset.custom,
  );
}

TaskSort _sortFromApi(String raw) {
  return TaskSort.values.firstWhere(
    (sort) => sort.apiValue == raw,
    orElse: () => TaskSort.dueAsc,
  );
}

enum TaskListMode {
  all('All'),
  inbox('Inbox'),
  ready('Ready'),
  waiting('Waiting'),
  review('Review'),
  completed('Completed');

  const TaskListMode(this.label);

  final String label;
}

class TaskListFilter {
  const TaskListFilter({
    this.preset = TaskQueryPreset.custom,
    this.statuses = const <TaskStatus>[],
    this.project,
    this.noProject = false,
    this.requiredTag,
    this.noTags = false,
    this.dueAfter,
    this.dueBefore,
    this.scheduledAfter,
    this.scheduledBefore,
    this.waitAfter,
    this.waitBefore,
    this.includeWaiting = true,
    this.includeScheduled = true,
    this.includeBlocked = true,
    this.sort = TaskSort.dueAsc,
  });

  final TaskQueryPreset preset;
  final List<TaskStatus> statuses;
  final String? project;
  final bool noProject;
  final String? requiredTag;
  final bool noTags;
  final DateTime? dueAfter;
  final DateTime? dueBefore;
  final DateTime? scheduledAfter;
  final DateTime? scheduledBefore;
  final DateTime? waitAfter;
  final DateTime? waitBefore;
  final bool includeWaiting;
  final bool includeScheduled;
  final bool includeBlocked;
  final TaskSort sort;

  bool get isDefault {
    return preset == TaskQueryPreset.custom &&
        statuses.isEmpty &&
        project == null &&
        !noProject &&
        requiredTag == null &&
        !noTags &&
        dueAfter == null &&
        dueBefore == null &&
        scheduledAfter == null &&
        scheduledBefore == null &&
        waitAfter == null &&
        waitBefore == null &&
        includeWaiting &&
        includeScheduled &&
        includeBlocked &&
        sort == TaskSort.dueAsc;
  }

  TaskListFilter copyWith({
    TaskQueryPreset? preset,
    List<TaskStatus>? statuses,
    String? project,
    bool clearProject = false,
    bool? noProject,
    String? requiredTag,
    bool clearRequiredTag = false,
    bool? noTags,
    DateTime? dueAfter,
    bool clearDueAfter = false,
    DateTime? dueBefore,
    bool clearDueBefore = false,
    DateTime? scheduledAfter,
    bool clearScheduledAfter = false,
    DateTime? scheduledBefore,
    bool clearScheduledBefore = false,
    DateTime? waitAfter,
    bool clearWaitAfter = false,
    DateTime? waitBefore,
    bool clearWaitBefore = false,
    bool? includeWaiting,
    bool? includeScheduled,
    bool? includeBlocked,
    TaskSort? sort,
  }) {
    return TaskListFilter(
      preset: preset ?? this.preset,
      statuses: statuses ?? this.statuses,
      project: clearProject ? null : project ?? this.project,
      noProject: noProject ?? this.noProject,
      requiredTag: clearRequiredTag ? null : requiredTag ?? this.requiredTag,
      noTags: noTags ?? this.noTags,
      dueAfter: clearDueAfter ? null : dueAfter ?? this.dueAfter,
      dueBefore: clearDueBefore ? null : dueBefore ?? this.dueBefore,
      scheduledAfter:
          clearScheduledAfter ? null : scheduledAfter ?? this.scheduledAfter,
      scheduledBefore:
          clearScheduledBefore ? null : scheduledBefore ?? this.scheduledBefore,
      waitAfter: clearWaitAfter ? null : waitAfter ?? this.waitAfter,
      waitBefore: clearWaitBefore ? null : waitBefore ?? this.waitBefore,
      includeWaiting: includeWaiting ?? this.includeWaiting,
      includeScheduled: includeScheduled ?? this.includeScheduled,
      includeBlocked: includeBlocked ?? this.includeBlocked,
      sort: sort ?? this.sort,
    );
  }

  TaskQuery toQuery({
    required DateTime referenceTime,
  }) {
    if (preset != TaskQueryPreset.custom) {
      return TaskQuery(
        preset: preset,
        statuses: const <TaskStatus>[],
        project: null,
        noProject: false,
        requiredTag: null,
        noTags: false,
        dueAfter: null,
        dueBefore: null,
        scheduledAfter: null,
        scheduledBefore: null,
        waitAfter: null,
        waitBefore: null,
        includeWaiting: true,
        includeScheduled: true,
        includeBlocked: true,
        referenceTime: referenceTime,
        sort: sort,
      );
    }

    return TaskQuery(
      preset: TaskQueryPreset.custom,
      statuses: statuses,
      project: project,
      noProject: noProject,
      requiredTag: requiredTag,
      noTags: noTags,
      dueAfter: dueAfter,
      dueBefore: dueBefore,
      scheduledAfter: scheduledAfter,
      scheduledBefore: scheduledBefore,
      waitAfter: waitAfter,
      waitBefore: waitBefore,
      includeWaiting: includeWaiting,
      includeScheduled: includeScheduled,
      includeBlocked: includeBlocked,
      referenceTime: referenceTime,
      sort: sort,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'preset': preset.apiValue,
      'statuses': statuses.map((status) => status.apiValue).toList(),
      'project': project,
      'no_project': noProject,
      'required_tag': requiredTag,
      'no_tags': noTags,
      'due_after': _dateToJson(dueAfter),
      'due_before': _dateToJson(dueBefore),
      'scheduled_after': _dateToJson(scheduledAfter),
      'scheduled_before': _dateToJson(scheduledBefore),
      'wait_after': _dateToJson(waitAfter),
      'wait_before': _dateToJson(waitBefore),
      'include_waiting': includeWaiting,
      'include_scheduled': includeScheduled,
      'include_blocked': includeBlocked,
      'sort': sort.apiValue,
    };
  }

  factory TaskListFilter.fromJson(Map<String, dynamic> json) {
    final statuses = json['statuses'] as List<dynamic>? ?? <dynamic>[];

    return TaskListFilter(
      preset: _presetFromApi(json['preset'] as String? ?? 'custom'),
      statuses: statuses.cast<String>().map(TaskStatus.fromApi).toList(),
      project: json['project'] as String?,
      noProject: json['no_project'] as bool? ?? false,
      requiredTag: json['required_tag'] as String?,
      noTags: json['no_tags'] as bool? ?? false,
      dueAfter: _dateFromJson(json['due_after']),
      dueBefore: _dateFromJson(json['due_before']),
      scheduledAfter: _dateFromJson(json['scheduled_after']),
      scheduledBefore: _dateFromJson(json['scheduled_before']),
      waitAfter: _dateFromJson(json['wait_after']),
      waitBefore: _dateFromJson(json['wait_before']),
      includeWaiting: json['include_waiting'] as bool? ?? true,
      includeScheduled: json['include_scheduled'] as bool? ?? true,
      includeBlocked: json['include_blocked'] as bool? ?? true,
      sort: _sortFromApi(json['sort'] as String? ?? TaskSort.dueAsc.apiValue),
    );
  }
}

class SavedTaskView {
  const SavedTaskView({
    required this.id,
    required this.name,
    required this.filter,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final TaskListFilter filter;
  final DateTime updatedAt;

  SavedTaskView copyWith({
    String? name,
    TaskListFilter? filter,
    DateTime? updatedAt,
  }) {
    return SavedTaskView(
      id: id,
      name: name ?? this.name,
      filter: filter ?? this.filter,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'filter': filter.toJson(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory SavedTaskView.fromJson(Map<String, dynamic> json) {
    return SavedTaskView(
      id: json['id'] as String,
      name: json['name'] as String,
      filter: TaskListFilter.fromJson(
        (json['filter'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      updatedAt: _dateFromJson(json['updated_at']) ?? DateTime.now().toUtc(),
    );
  }
}

enum DashboardWidgetType {
  readyNow('Ready now'),
  dueSoon('Due soon'),
  completedRecently('Completed');

  const DashboardWidgetType(this.title);

  final String title;
}

DashboardWidgetType _dashboardWidgetFromJson(String raw) {
  return DashboardWidgetType.values.firstWhere(
    (widget) => widget.name == raw,
    orElse: () => DashboardWidgetType.readyNow,
  );
}

class DashboardSavedViewWidget {
  const DashboardSavedViewWidget({
    required this.id,
    required this.title,
    required this.viewId,
    required this.filter,
  });

  final String id;
  final String title;
  final String viewId;
  final TaskListFilter filter;

  DashboardSavedViewWidget copyWith({
    String? title,
    TaskListFilter? filter,
  }) {
    return DashboardSavedViewWidget(
      id: id,
      title: title ?? this.title,
      viewId: viewId,
      filter: filter ?? this.filter,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'view_id': viewId,
      'filter': filter.toJson(),
    };
  }

  factory DashboardSavedViewWidget.fromJson(Map<String, dynamic> json) {
    return DashboardSavedViewWidget(
      id: json['id'] as String,
      title: json['title'] as String,
      viewId: json['view_id'] as String,
      filter: TaskListFilter.fromJson(
        (json['filter'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
    );
  }
}

class DashboardLayout {
  const DashboardLayout({
    required this.id,
    required this.name,
    required this.enabledWidgets,
    required this.savedViewWidgets,
    required this.updatedAt,
  });

  factory DashboardLayout.defaultLayout({
    required DateTime updatedAt,
  }) {
    return DashboardLayout(
      id: 'local-dashboard',
      name: 'Local dashboard',
      enabledWidgets: DashboardWidgetType.values.toSet(),
      savedViewWidgets: const <DashboardSavedViewWidget>[],
      updatedAt: updatedAt.toUtc(),
    );
  }

  final String id;
  final String name;
  final Set<DashboardWidgetType> enabledWidgets;
  final List<DashboardSavedViewWidget> savedViewWidgets;
  final DateTime updatedAt;

  DashboardLayout copyWith({
    String? name,
    Set<DashboardWidgetType>? enabledWidgets,
    List<DashboardSavedViewWidget>? savedViewWidgets,
    DateTime? updatedAt,
  }) {
    return DashboardLayout(
      id: id,
      name: name ?? this.name,
      enabledWidgets: enabledWidgets ?? this.enabledWidgets,
      savedViewWidgets: savedViewWidgets ?? this.savedViewWidgets,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    final widgets = enabledWidgets.toList()
      ..sort((left, right) => left.index.compareTo(right.index));

    return <String, dynamic>{
      'id': id,
      'name': name,
      'enabled_widgets': widgets.map((widget) => widget.name).toList(),
      'saved_view_widgets':
          savedViewWidgets.map((widget) => widget.toJson()).toList(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory DashboardLayout.fromJson(Map<String, dynamic> json) {
    final enabledWidgets =
        json['enabled_widgets'] as List<dynamic>? ?? <dynamic>[];
    final savedViewWidgets =
        json['saved_view_widgets'] as List<dynamic>? ?? <dynamic>[];

    return DashboardLayout(
      id: json['id'] as String,
      name: json['name'] as String,
      enabledWidgets:
          enabledWidgets.cast<String>().map(_dashboardWidgetFromJson).toSet(),
      savedViewWidgets: savedViewWidgets
          .map((widget) => DashboardSavedViewWidget.fromJson(
                widget as Map<String, dynamic>,
              ))
          .toList(),
      updatedAt: _dateFromJson(json['updated_at']) ?? DateTime.now().toUtc(),
    );
  }
}

enum BoardLane {
  pending('Pending', 'pending'),
  recurring('Recurring', 'recurring'),
  waiting('Waiting', 'waiting'),
  completed('Completed', 'completed');

  const BoardLane(this.title, this.apiValue);

  final String title;
  final String apiValue;
}

class BackendHealth {
  const BackendHealth({
    required this.label,
    required this.environment,
  });

  final String label;
  final String environment;
}

enum BackendSyncState {
  disabled,
  configured,
  syncing,
  succeeded,
  failed;

  static BackendSyncState fromApi(String raw) {
    return BackendSyncState.values.firstWhere(
      (state) => state.name == raw,
      orElse: () => BackendSyncState.failed,
    );
  }
}

class BackendSyncStatus {
  const BackendSyncStatus({
    required this.state,
    required this.retryAvailable,
    this.lastAttemptAt,
    this.errorSummary,
  });

  const BackendSyncStatus.disabled()
      : state = BackendSyncState.disabled,
        retryAvailable = false,
        lastAttemptAt = null,
        errorSummary = null;

  const BackendSyncStatus.configured()
      : state = BackendSyncState.configured,
        retryAvailable = true,
        lastAttemptAt = null,
        errorSummary = null;

  final BackendSyncState state;
  final DateTime? lastAttemptAt;
  final String? errorSummary;
  final bool retryAvailable;

  String get label {
    return switch (state) {
      BackendSyncState.disabled => 'Sync disabled',
      BackendSyncState.configured => 'Sync configured',
      BackendSyncState.syncing => 'Syncing tasks',
      BackendSyncState.succeeded => 'Tasks synced',
      BackendSyncState.failed => 'Task sync failed',
    };
  }
}

class TaskAnnotation {
  const TaskAnnotation({
    required this.entry,
    required this.description,
  });

  final DateTime entry;
  final String description;
}

class TaskQuery {
  const TaskQuery({
    required this.preset,
    required this.statuses,
    required this.project,
    required this.noProject,
    required this.requiredTag,
    required this.noTags,
    required this.dueAfter,
    required this.dueBefore,
    required this.scheduledAfter,
    required this.scheduledBefore,
    required this.waitAfter,
    required this.waitBefore,
    required this.includeWaiting,
    required this.includeScheduled,
    required this.includeBlocked,
    required this.referenceTime,
    required this.sort,
  });

  final TaskQueryPreset preset;
  final List<TaskStatus> statuses;
  final String? project;
  final bool noProject;
  final String? requiredTag;
  final bool noTags;
  final DateTime? dueAfter;
  final DateTime? dueBefore;
  final DateTime? scheduledAfter;
  final DateTime? scheduledBefore;
  final DateTime? waitAfter;
  final DateTime? waitBefore;
  final bool includeWaiting;
  final bool includeScheduled;
  final bool includeBlocked;
  final DateTime referenceTime;
  final TaskSort sort;

  factory TaskQuery.all({
    required DateTime referenceTime,
  }) {
    return TaskQuery(
      preset: TaskQueryPreset.custom,
      statuses: const <TaskStatus>[],
      project: null,
      noProject: false,
      requiredTag: null,
      noTags: false,
      dueAfter: null,
      dueBefore: null,
      scheduledAfter: null,
      scheduledBefore: null,
      waitAfter: null,
      waitBefore: null,
      includeWaiting: true,
      includeScheduled: true,
      includeBlocked: true,
      referenceTime: referenceTime,
      sort: TaskSort.dueAsc,
    );
  }

  factory TaskQuery.forListMode({
    required TaskListMode mode,
    required DateTime referenceTime,
  }) {
    switch (mode) {
      case TaskListMode.inbox:
        return TaskQuery.inbox(referenceTime: referenceTime);
      case TaskListMode.completed:
        return TaskQuery(
          preset: TaskQueryPreset.custom,
          statuses: const <TaskStatus>[TaskStatus.completed],
          project: null,
          noProject: false,
          requiredTag: null,
          noTags: false,
          dueAfter: null,
          dueBefore: null,
          scheduledAfter: null,
          scheduledBefore: null,
          waitAfter: null,
          waitBefore: null,
          includeWaiting: true,
          includeScheduled: true,
          includeBlocked: true,
          referenceTime: referenceTime,
          sort: TaskSort.modifiedDesc,
        );
      case TaskListMode.ready:
        return TaskQuery.nextActions(referenceTime: referenceTime);
      case TaskListMode.waiting:
        return TaskQuery.waiting(referenceTime: referenceTime);
      case TaskListMode.review:
        return TaskQuery.review(referenceTime: referenceTime);
      case TaskListMode.all:
        return TaskQuery.all(referenceTime: referenceTime);
    }
  }

  factory TaskQuery.forDashboardWidget({
    required DashboardWidgetType widget,
    required DateTime referenceTime,
  }) {
    switch (widget) {
      case DashboardWidgetType.readyNow:
        return TaskQuery.nextActions(referenceTime: referenceTime);
      case DashboardWidgetType.dueSoon:
        return TaskQuery(
          preset: TaskQueryPreset.custom,
          statuses: const <TaskStatus>[TaskStatus.pending],
          project: null,
          noProject: false,
          requiredTag: null,
          noTags: false,
          dueAfter: null,
          dueBefore: referenceTime.add(const Duration(days: 7)),
          scheduledAfter: null,
          scheduledBefore: null,
          waitAfter: null,
          waitBefore: null,
          includeWaiting: false,
          includeScheduled: false,
          includeBlocked: false,
          referenceTime: referenceTime,
          sort: TaskSort.dueAsc,
        );
      case DashboardWidgetType.completedRecently:
        return TaskQuery(
          preset: TaskQueryPreset.custom,
          statuses: const <TaskStatus>[TaskStatus.completed],
          project: null,
          noProject: false,
          requiredTag: null,
          noTags: false,
          dueAfter: null,
          dueBefore: null,
          scheduledAfter: null,
          scheduledBefore: null,
          waitAfter: null,
          waitBefore: null,
          includeWaiting: true,
          includeScheduled: true,
          includeBlocked: true,
          referenceTime: referenceTime,
          sort: TaskSort.modifiedDesc,
        );
    }
  }

  factory TaskQuery.nextActions({
    required DateTime referenceTime,
  }) {
    return TaskQuery(
      preset: TaskQueryPreset.nextActions,
      statuses: const <TaskStatus>[TaskStatus.pending],
      project: null,
      noProject: false,
      requiredTag: null,
      noTags: false,
      dueAfter: null,
      dueBefore: null,
      scheduledAfter: null,
      scheduledBefore: null,
      waitAfter: null,
      waitBefore: null,
      includeWaiting: false,
      includeScheduled: false,
      includeBlocked: false,
      referenceTime: referenceTime,
      sort: TaskSort.dueAsc,
    );
  }

  factory TaskQuery.inbox({
    required DateTime referenceTime,
  }) {
    return TaskQuery(
      preset: TaskQueryPreset.inbox,
      statuses: const <TaskStatus>[TaskStatus.pending],
      project: null,
      noProject: true,
      requiredTag: null,
      noTags: false,
      dueAfter: null,
      dueBefore: null,
      scheduledAfter: null,
      scheduledBefore: null,
      waitAfter: null,
      waitBefore: null,
      includeWaiting: false,
      includeScheduled: false,
      includeBlocked: true,
      referenceTime: referenceTime,
      sort: TaskSort.modifiedDesc,
    );
  }

  factory TaskQuery.waiting({
    required DateTime referenceTime,
  }) {
    return TaskQuery(
      preset: TaskQueryPreset.waiting,
      statuses: const <TaskStatus>[TaskStatus.pending],
      project: null,
      noProject: false,
      requiredTag: null,
      noTags: false,
      dueAfter: null,
      dueBefore: null,
      scheduledAfter: null,
      scheduledBefore: null,
      waitAfter: null,
      waitBefore: null,
      includeWaiting: true,
      includeScheduled: true,
      includeBlocked: true,
      referenceTime: referenceTime,
      sort: TaskSort.dueAsc,
    );
  }

  factory TaskQuery.review({
    required DateTime referenceTime,
  }) {
    return TaskQuery(
      preset: TaskQueryPreset.review,
      statuses: const <TaskStatus>[TaskStatus.pending],
      project: null,
      noProject: false,
      requiredTag: null,
      noTags: false,
      dueAfter: null,
      dueBefore: null,
      scheduledAfter: null,
      scheduledBefore: null,
      waitAfter: null,
      waitBefore: null,
      includeWaiting: true,
      includeScheduled: true,
      includeBlocked: true,
      referenceTime: referenceTime,
      sort: TaskSort.modifiedDesc,
    );
  }

  bool matches(TaskItem task) {
    final statusMatches = statuses.isEmpty || statuses.contains(task.status);
    final projectMatches = project == null || task.project == project!.trim();
    final noProjectMatches = !noProject || task.project == null;
    final tagMatches =
        requiredTag == null || task.tags.contains(requiredTag!.trim());
    final noTagsMatches = !noTags || task.tags.isEmpty;
    final dueAfterMatches =
        dueAfter == null || task.due != null && !task.due!.isBefore(dueAfter!);
    final dueBeforeMatches =
        dueBefore == null || task.due != null && !task.due!.isAfter(dueBefore!);
    final scheduledAfterMatches = scheduledAfter == null ||
        task.scheduled != null && !task.scheduled!.isBefore(scheduledAfter!);
    final scheduledBeforeMatches = scheduledBefore == null ||
        task.scheduled != null && !task.scheduled!.isAfter(scheduledBefore!);
    final waitAfterMatches = waitAfter == null ||
        task.waitUntil != null && !task.waitUntil!.isBefore(waitAfter!);
    final waitBeforeMatches = waitBefore == null ||
        task.waitUntil != null && !task.waitUntil!.isAfter(waitBefore!);
    final waitingMatches = includeWaiting || !task.isWaitingAt(referenceTime);
    final scheduledMatches =
        includeScheduled || !task.isScheduledAfter(referenceTime);

    return statusMatches &&
        projectMatches &&
        noProjectMatches &&
        tagMatches &&
        noTagsMatches &&
        dueAfterMatches &&
        dueBeforeMatches &&
        scheduledAfterMatches &&
        scheduledBeforeMatches &&
        waitAfterMatches &&
        waitBeforeMatches &&
        waitingMatches &&
        scheduledMatches;
  }
}

class DashboardWidgetData {
  const DashboardWidgetData({
    required this.widget,
    required this.tasks,
  });

  final DashboardWidgetType widget;
  final List<TaskItem> tasks;
}

class DashboardSavedViewData {
  const DashboardSavedViewData({
    required this.widget,
    required this.tasks,
  });

  final DashboardSavedViewWidget widget;
  final List<TaskItem> tasks;
}

class CreateTaskInput {
  const CreateTaskInput({
    required this.description,
  });

  final String description;
}

class UpdateTaskInput {
  const UpdateTaskInput({
    this.description,
    this.project,
    this.clearProject = false,
    this.tags,
    this.due,
    this.clearDue = false,
    this.scheduled,
    this.clearScheduled = false,
    this.waitUntil,
    this.clearWait = false,
    this.recurrence,
    this.clearRecurrence = false,
    this.addAnnotation,
  });

  final String? description;
  final String? project;
  final bool clearProject;
  final List<String>? tags;
  final DateTime? due;
  final bool clearDue;
  final DateTime? scheduled;
  final bool clearScheduled;
  final DateTime? waitUntil;
  final bool clearWait;
  final TaskRecurrence? recurrence;
  final bool clearRecurrence;
  final String? addAnnotation;
}

class TaskTransitionInput {
  const TaskTransitionInput({
    required this.status,
  });

  final TaskStatus status;
}

class BoardTransitionInput {
  const BoardTransitionInput({
    required this.lane,
    this.waitUntil,
  });

  final BoardLane lane;
  final DateTime? waitUntil;
}

class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.project,
    required this.status,
    required this.tags,
    required this.annotations,
    this.entry,
    this.modified,
    this.due,
    this.scheduled,
    this.waitUntil,
    this.end,
    this.recurrence,
  });

  final String id;
  final String title;
  final String? project;
  final TaskStatus status;
  final List<String> tags;
  final List<TaskAnnotation> annotations;
  final DateTime? entry;
  final DateTime? modified;
  final DateTime? due;
  final DateTime? scheduled;
  final DateTime? waitUntil;
  final DateTime? end;
  final TaskRecurrence? recurrence;

  String get summary {
    if (annotations.isNotEmpty) {
      return annotations.last.description;
    }

    if (project != null && project!.isNotEmpty) {
      return project!;
    }

    return 'No annotation yet';
  }

  bool isWaitingAt(DateTime referenceTime) {
    return waitUntil != null && waitUntil!.isAfter(referenceTime);
  }

  bool isScheduledAfter(DateTime referenceTime) {
    return scheduled != null && scheduled!.isAfter(referenceTime);
  }

  BoardLane laneFor(DateTime referenceTime) {
    if (status == TaskStatus.completed) {
      return BoardLane.completed;
    }

    if (isWaitingAt(referenceTime)) {
      return BoardLane.waiting;
    }

    if (status == TaskStatus.recurring) {
      return BoardLane.recurring;
    }

    return BoardLane.pending;
  }

  String get dueLabel {
    final date = due;
    if (date == null) {
      return 'No due date';
    }

    return '${date.month}/${date.day}/${date.year}';
  }
}

class TaskRecurrence {
  const TaskRecurrence({
    required this.recur,
    this.rtype,
    this.until,
    this.parent,
    this.mask,
    this.imask,
  });

  final String recur;
  final String? rtype;
  final DateTime? until;
  final String? parent;
  final String? mask;
  final String? imask;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'recur': recur,
      'rtype': rtype,
      'until': _dateToJson(until),
      'parent': parent,
      'mask': mask,
      'imask': imask,
    };
  }

  factory TaskRecurrence.fromJson(Map<String, dynamic> json) {
    return TaskRecurrence(
      recur: json['recur'] as String,
      rtype: json['rtype'] as String?,
      until: _dateFromJson(json['until']),
      parent: json['parent'] as String?,
      mask: json['mask'] as String?,
      imask: json['imask'] as String?,
    );
  }
}

String? _dateToJson(DateTime? value) {
  return value?.toUtc().toIso8601String();
}

DateTime? _dateFromJson(Object? value) {
  if (value == null) {
    return null;
  }

  return DateTime.parse(value as String).toUtc();
}
