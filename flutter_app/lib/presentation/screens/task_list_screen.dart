import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/shell_controller.dart';
import '../../models/shell_models.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({
    super.key,
    required this.controller,
    required this.onOpenTask,
  });

  final ShellController controller;
  final ValueChanged<String> onOpenTask;

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  late final TextEditingController _createController;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _createController = TextEditingController();
  }

  @override
  void dispose() {
    _createController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.controller.listTasks;
    final activeTasks =
        tasks.where((task) => task.status != TaskStatus.completed).toList();
    final completedTasks =
        tasks.where((task) => task.status == TaskStatus.completed).toList();

    return Column(
      key: const Key('task-list-screen'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Server-authoritative task list',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Quick create',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Focus(
                        onKeyEvent: _handleCreateKey,
                        child: TextField(
                          key: const Key('create-task-field'),
                          controller: _createController,
                          decoration: const InputDecoration(
                            hintText: 'Describe a task',
                          ),
                          textInputAction: TextInputAction.done,
                          onEditingComplete: _createTask,
                          onSubmitted: (_) => _createTask(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed:
                          widget.controller.isSaving ? null : _createTask,
                      child: const Text('Create'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TaskListMode.values.map((mode) {
            return ChoiceChip(
              key: Key('task-list-mode-${mode.name}'),
              label: Text(mode.label),
              selected: widget.controller.listMode == mode,
              onSelected: (_) => widget.controller.setListMode(mode),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: tasks.isEmpty
              ? const Center(
                  child: Text('No tasks for the current server filter.'),
                )
              : ListView(
                  children: <Widget>[
                    if (activeTasks.isNotEmpty)
                      _TaskListSection(
                        title: 'To do',
                        tasks: activeTasks,
                        controller: widget.controller,
                        onOpenTask: widget.onOpenTask,
                      ),
                    if (activeTasks.isNotEmpty && completedTasks.isNotEmpty)
                      const SizedBox(height: 20),
                    if (completedTasks.isNotEmpty)
                      _TaskListSection(
                        title: 'Completed',
                        tasks: completedTasks,
                        controller: widget.controller,
                        onOpenTask: widget.onOpenTask,
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _createTask() async {
    if (_isCreating || widget.controller.isSaving) {
      return;
    }

    final text = _createController.text.trim();
    if (text.isEmpty) {
      return;
    }

    _isCreating = true;
    try {
      await widget.controller.createTask(text);
      if (mounted) {
        _createController.clear();
      }
    } finally {
      _isCreating = false;
    }
  }

  KeyEventResult _handleCreateKey(
    FocusNode node,
    KeyEvent event,
  ) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.enter &&
        key != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }

    _createTask();
    return KeyEventResult.handled;
  }
}

class _TaskListSection extends StatelessWidget {
  const _TaskListSection({
    required this.title,
    required this.tasks,
    required this.controller,
    required this.onOpenTask,
  });

  final String title;
  final List<TaskItem> tasks;
  final ShellController controller;
  final ValueChanged<String> onOpenTask;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        for (final task in tasks)
          _TaskListCard(
            task: task,
            controller: controller,
            onOpenTask: onOpenTask,
          ),
      ],
    );
  }
}

class _TaskListCard extends StatelessWidget {
  const _TaskListCard({
    required this.task,
    required this.controller,
    required this.onOpenTask,
  });

  final TaskItem task;
  final ShellController controller;
  final ValueChanged<String> onOpenTask;

  @override
  Widget build(BuildContext context) {
    final completed = task.status == TaskStatus.completed;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: ExpansionTile(
        key: Key('task-expand-${task.id}'),
        dense: true,
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        childrenPadding: const EdgeInsets.fromLTRB(56, 0, 16, 12),
        leading: Checkbox(
          key: Key('task-complete-${task.id}'),
          value: completed,
          onChanged:
              controller.isSaving ? null : (_) => _setCompleted(!completed),
        ),
        title: _TaskListRowTitle(task: task),
        children: <Widget>[
          _ExpandedTaskDetails(
            task: task,
            onOpenTask: onOpenTask,
          ),
        ],
      ),
    );
  }

  Future<void> _setCompleted(bool completed) async {
    await controller.transitionTask(
      task,
      completed ? TaskStatus.completed : TaskStatus.pending,
    );
  }
}

class _ExpandedTaskDetails extends StatelessWidget {
  const _ExpandedTaskDetails({
    required this.task,
    required this.onOpenTask,
  });

  final TaskItem task;
  final ValueChanged<String> onOpenTask;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(task.summary),
          Chip(label: Text(task.status.label)),
          Chip(label: Text(task.dueLabel)),
          Chip(label: Text(task.project ?? 'No project')),
          for (final tag in task.tags) Chip(label: Text(tag)),
          TextButton(
            key: Key('task-open-${task.id}'),
            onPressed: () => onOpenTask(task.id),
            child: const Text('Open details'),
          ),
        ],
      ),
    );
  }
}

class _TaskListRowTitle extends StatelessWidget {
  const _TaskListRowTitle({
    required this.task,
  });

  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    final completed = task.status == TaskStatus.completed;
    final titleStyle = Theme.of(context).textTheme.bodyLarge;
    final fadedStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final showDue = constraints.maxWidth >= 360;
        final showProject = constraints.maxWidth >= 540;
        final showTags = constraints.maxWidth >= 760;

        return Row(
          children: <Widget>[
            Expanded(
              child: Text(
                task.title,
                overflow: TextOverflow.ellipsis,
                style: completed
                    ? titleStyle?.copyWith(
                        decoration: TextDecoration.lineThrough,
                      )
                    : titleStyle,
              ),
            ),
            if (showDue)
              _TaskListMetaColumn(
                key: Key('task-row-due-${task.id}'),
                width: 112,
                child: Text(
                  task.dueLabel,
                  overflow: TextOverflow.ellipsis,
                  style: fadedStyle,
                  textAlign: TextAlign.right,
                ),
              ),
            if (showProject)
              _TaskListMetaColumn(
                key: Key('task-row-project-${task.id}'),
                width: 140,
                child: task.project == null
                    ? const SizedBox.shrink()
                    : _ProjectBadge(
                        key: Key('task-project-badge-${task.id}'),
                        label: task.project!,
                      ),
              ),
            if (showTags)
              _TaskListMetaColumn(
                key: Key('task-row-tags-${task.id}'),
                width: 180,
                child: task.tags.isEmpty
                    ? const SizedBox.shrink()
                    : _TagBadges(
                        taskId: task.id,
                        tags: task.tags,
                      ),
              ),
          ],
        );
      },
    );
  }
}

class _TaskListMetaColumn extends StatelessWidget {
  const _TaskListMetaColumn({
    super.key,
    required this.width,
    required this.child,
  });

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Align(
        alignment: Alignment.centerRight,
        child: child,
      ),
    );
  }
}

class _ProjectBadge extends StatelessWidget {
  const _ProjectBadge({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = _BadgeColors.forLabel(label);

    return Container(
      constraints: const BoxConstraints(maxWidth: 128),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.foreground,
            ),
      ),
    );
  }
}

class _TagBadges extends StatelessWidget {
  const _TagBadges({
    required this.taskId,
    required this.tags,
  });

  final String taskId;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final visibleTags = tags.take(2).toList();

    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 4,
      runSpacing: 4,
      children: <Widget>[
        for (final tag in visibleTags) _TagBadge(taskId: taskId, tag: tag),
      ],
    );
  }
}

class _TagBadge extends StatelessWidget {
  const _TagBadge({
    required this.taskId,
    required this.tag,
  });

  final String taskId;
  final String tag;

  @override
  Widget build(BuildContext context) {
    final colors = _BadgeColors.forLabel(tag);

    return Container(
      key: Key('task-tag-badge-$taskId-$tag'),
      constraints: const BoxConstraints(maxWidth: 78),
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        tag,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.foreground,
            ),
      ),
    );
  }
}

class _BadgeColors {
  const _BadgeColors({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;

  static const List<Color> _palette = <Color>[
    Color(0xFFB7E4C7),
    Color(0xFFFFD6A5),
    Color(0xFFA0C4FF),
    Color(0xFFFFADAD),
    Color(0xFFCAFFBF),
    Color(0xFFBDB2FF),
    Color(0xFFFDFFB6),
    Color(0xFF9BF6FF),
  ];

  static _BadgeColors forLabel(String label) {
    final background = _palette[_hash(label) % _palette.length];
    final foreground = background.computeLuminance() > 0.55
        ? const Color(0xFF1F2933)
        : const Color(0xFFFFFFFF);

    return _BadgeColors(
      background: background,
      foreground: foreground,
    );
  }

  static int _hash(String value) {
    var hash = 0;
    for (final codeUnit in value.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }

    return hash;
  }
}
