import 'package:flutter/material.dart';

import '../../models/shell_models.dart';

class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.health,
    required this.boardIntent,
    required this.showContextHeader,
  });

  final TaskItem? task;
  final BackendHealth? health;
  final String? boardIntent;
  final bool showContextHeader;

  @override
  Widget build(BuildContext context) {
    final currentTask = task;

    return ListView(
      key: const Key('task-detail-screen'),
      children: <Widget>[
        if (showContextHeader) ...<Widget>[
          Text(
            'Task detail placeholder',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
        ],
        if (currentTask == null)
          const Text('Select a task from the dashboard or list.')
        else ...<Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    currentTask.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(currentTask.summary),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      Chip(label: Text(currentTask.project)),
                      Chip(label: Text(currentTask.status.label)),
                      Chip(label: Text(currentTask.dueLabel)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Backend integration points',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(health?.environment ?? 'Connecting'),
                  const SizedBox(height: 16),
                  Text(
                    boardIntent ??
                        'Board moves stay as queued UI intent until '
                            'Milestone 4 wires persisted transitions.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
