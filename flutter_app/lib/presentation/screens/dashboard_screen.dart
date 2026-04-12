import 'package:flutter/material.dart';

import '../../models/shell_models.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.tasks,
    required this.health,
    required this.onOpenTask,
  });

  final List<TaskItem> tasks;
  final BackendHealth? health;
  final ValueChanged<String> onOpenTask;

  @override
  Widget build(BuildContext context) {
    final referenceTime = DateTime.now();
    final pending =
        tasks.where((task) => task.status == TaskStatus.pending).length;
    final waiting =
        tasks.where((task) => task.isWaitingAt(referenceTime)).length;
    final recurring =
        tasks.where((task) => task.status == TaskStatus.recurring).length;
    final completed =
        tasks.where((task) => task.status == TaskStatus.completed).length;

    final cards = <_MetricCardData>[
      _MetricCardData(
        title: 'Ready now',
        value: pending - waiting,
        detail: 'Tasks visible in the main lists',
        tint: const Color(0xFF16343F),
      ),
      _MetricCardData(
        title: 'Waiting',
        value: waiting,
        detail: 'Tasks hidden until wait expires',
        tint: const Color(0xFF6E7D3C),
      ),
      _MetricCardData(
        title: 'Recurring',
        value: recurring,
        detail: 'Recurring placeholders using shared task queries',
        tint: const Color(0xFFCB5D39),
      ),
      _MetricCardData(
        title: 'Completed',
        value: completed,
        detail: 'Terminal tasks for review views',
        tint: const Color(0xFF4C6A8A),
      ),
    ];

    return ListView(
      key: const Key('dashboard-screen'),
      children: <Widget>[
        Text(
          'Configurable dashboard placeholder',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'One shared task query can power summary cards, '
          'lists, and detail entry points.',
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth >= 960
                ? 4
                : constraints.maxWidth >= 620
                    ? 2
                    : 1;

            final childAspectRatio = crossAxisCount == 1
                ? 2.4
                : crossAxisCount == 2
                    ? 1.25
                    : 1.0;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: childAspectRatio,
              ),
              itemCount: cards.length,
              itemBuilder: (context, index) {
                final card = cards[index];

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: card.tint.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Text(card.title),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${card.value}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(card.detail),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Backend scaffold',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(health?.environment ?? 'Connecting'),
                const SizedBox(height: 16),
                for (final task in tasks.take(3))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(task.title),
                    subtitle: Text(task.project),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_outlined,
                      size: 18,
                    ),
                    onTap: () => onOpenTask(task.id),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricCardData {
  const _MetricCardData({
    required this.title,
    required this.value,
    required this.detail,
    required this.tint,
  });

  final String title;
  final int value;
  final String detail;
  final Color tint;
}
