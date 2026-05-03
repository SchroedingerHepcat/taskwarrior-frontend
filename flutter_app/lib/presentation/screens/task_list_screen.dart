import 'package:flutter/material.dart';

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
                      child: TextField(
                        key: const Key('create-task-field'),
                        controller: _createController,
                        decoration: const InputDecoration(
                          hintText: 'Describe a task',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: widget.controller.isSaving
                          ? null
                          : () async {
                              final text = _createController.text.trim();
                              if (text.isEmpty) {
                                return;
                              }

                              await widget.controller.createTask(text);
                              if (mounted) {
                                _createController.clear();
                              }
                            },
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
              : ListView.separated(
                  itemCount: tasks.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final task = tasks[index];

                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => widget.onOpenTask(task.id),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      task.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ),
                                  Chip(label: Text(task.status.label)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(task.summary),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: <Widget>[
                                  Chip(
                                    label: Text(
                                      task.project ?? 'No project',
                                    ),
                                  ),
                                  Chip(label: Text(task.dueLabel)),
                                  for (final tag in task.tags)
                                    Chip(label: Text(tag)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
