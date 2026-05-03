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

enum TaskListMode {
  all('All'),
  ready('Ready'),
  completed('Completed');

  const TaskListMode(this.label);

  final String label;
}

enum DashboardWidgetType {
  readyNow('Ready now'),
  dueSoon('Due soon'),
  completedRecently('Completed');

  const DashboardWidgetType(this.title);

  final String title;
}

enum BoardLane {
  pending('Pending'),
  recurring('Recurring'),
  waiting('Waiting'),
  completed('Completed');

  const BoardLane(this.title);

  final String title;
}

class BackendHealth {
  const BackendHealth({
    required this.label,
    required this.environment,
  });

  final String label;
  final String environment;
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
    required this.statuses,
    required this.requiredTag,
    required this.dueBefore,
    required this.includeWaiting,
    required this.referenceTime,
    required this.sort,
  });

  final List<TaskStatus> statuses;
  final String? requiredTag;
  final DateTime? dueBefore;
  final bool includeWaiting;
  final DateTime referenceTime;
  final TaskSort sort;

  factory TaskQuery.all({
    required DateTime referenceTime,
  }) {
    return TaskQuery(
      statuses: const <TaskStatus>[],
      requiredTag: null,
      dueBefore: null,
      includeWaiting: true,
      referenceTime: referenceTime,
      sort: TaskSort.dueAsc,
    );
  }

  factory TaskQuery.forListMode({
    required TaskListMode mode,
    required DateTime referenceTime,
  }) {
    switch (mode) {
      case TaskListMode.completed:
        return TaskQuery(
          statuses: const <TaskStatus>[TaskStatus.completed],
          requiredTag: null,
          dueBefore: null,
          includeWaiting: true,
          referenceTime: referenceTime,
          sort: TaskSort.modifiedDesc,
        );
      case TaskListMode.ready:
        return TaskQuery(
          statuses: const <TaskStatus>[TaskStatus.pending],
          requiredTag: null,
          dueBefore: null,
          includeWaiting: false,
          referenceTime: referenceTime,
          sort: TaskSort.dueAsc,
        );
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
        return TaskQuery(
          statuses: const <TaskStatus>[TaskStatus.pending],
          requiredTag: null,
          dueBefore: null,
          includeWaiting: false,
          referenceTime: referenceTime,
          sort: TaskSort.dueAsc,
        );
      case DashboardWidgetType.dueSoon:
        return TaskQuery(
          statuses: const <TaskStatus>[TaskStatus.pending],
          requiredTag: null,
          dueBefore: referenceTime.add(const Duration(days: 7)),
          includeWaiting: false,
          referenceTime: referenceTime,
          sort: TaskSort.dueAsc,
        );
      case DashboardWidgetType.completedRecently:
        return TaskQuery(
          statuses: const <TaskStatus>[TaskStatus.completed],
          requiredTag: null,
          dueBefore: null,
          includeWaiting: true,
          referenceTime: referenceTime,
          sort: TaskSort.modifiedDesc,
        );
    }
  }

  bool matches(TaskItem task) {
    final statusMatches = statuses.isEmpty || statuses.contains(task.status);
    final tagMatches =
        requiredTag == null || task.tags.contains(requiredTag!.trim());
    final dueMatches =
        dueBefore == null || task.due != null && !task.due!.isAfter(dueBefore!);
    final waitingMatches = includeWaiting || !task.isWaitingAt(referenceTime);

    return statusMatches && tagMatches && dueMatches && waitingMatches;
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
    this.waitUntil,
    this.clearWait = false,
    this.addAnnotation,
  });

  final String? description;
  final String? project;
  final bool clearProject;
  final List<String>? tags;
  final DateTime? due;
  final bool clearDue;
  final DateTime? waitUntil;
  final bool clearWait;
  final String? addAnnotation;
}

class TaskTransitionInput {
  const TaskTransitionInput({
    required this.status,
  });

  final TaskStatus status;
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
    this.waitUntil,
    this.end,
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
  final DateTime? waitUntil;
  final DateTime? end;

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
