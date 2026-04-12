import 'package:flutter/material.dart';

import '../../models/shell_models.dart';

class TaskListScreen extends StatelessWidget {
  const TaskListScreen({
    super.key,
    required this.tasks,
    required this.onOpenTask,
  });

  final List<TaskItem> tasks;
  final ValueChanged<String> onOpenTask;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('task-list-screen'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Server-authoritative task list',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const <Widget>[
            Chip(label: Text('Query: statuses')),
            Chip(label: Text('Query: required tag')),
            Chip(label: Text('Query: due cutoff')),
            Chip(label: Text('Query: include waiting')),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: tasks.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final task = tasks[index];

              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => onOpenTask(task.id),
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
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                child: Text(task.status.label),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(task.summary),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            Chip(label: Text(task.project)),
                            Chip(label: Text(task.dueLabel)),
                            for (final tag in task.tags) Chip(label: Text(tag)),
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
