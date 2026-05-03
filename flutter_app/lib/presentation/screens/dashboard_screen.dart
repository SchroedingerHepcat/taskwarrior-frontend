import 'package:flutter/material.dart';

import '../../app/shell_controller.dart';
import '../../models/shell_models.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.controller,
    required this.onOpenTask,
  });

  final ShellController controller;
  final ValueChanged<String> onOpenTask;

  @override
  Widget build(BuildContext context) {
    final widgets = controller.enabledWidgets.toList()
      ..sort((left, right) => left.index.compareTo(right.index));

    return ListView(
      key: const Key('dashboard-screen'),
      children: <Widget>[
        Text(
          'Configurable dashboard',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Each widget is backed by a real server query, not a local filter.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: DashboardWidgetType.values.map((widget) {
            final selected = controller.enabledWidgets.contains(widget);

            return FilterChip(
              label: Text(widget.title),
              selected: selected,
              onSelected: (_) => controller.toggleWidget(widget),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 920
                ? 3
                : constraints.maxWidth >= 620
                    ? 2
                    : 1;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: columns == 1 ? 2.0 : 1.2,
              ),
              itemCount: widgets.length,
              itemBuilder: (context, index) {
                final widgetType = widgets[index];
                final widgetData = controller.widgetDataFor(widgetType);

                return _DashboardWidgetCard(
                  data: widgetData,
                  onOpenTask: onOpenTask,
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _DashboardWidgetCard extends StatelessWidget {
  const _DashboardWidgetCard({
    required this.data,
    required this.onOpenTask,
  });

  final DashboardWidgetData? data;
  final ValueChanged<String> onOpenTask;

  @override
  Widget build(BuildContext context) {
    final widgetData = data;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widgetData?.widget.title ?? 'Loading',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('${widgetData?.tasks.length ?? 0} tasks'),
            const SizedBox(height: 16),
            if (widgetData == null || widgetData.tasks.isEmpty)
              const Text('No tasks matched this server query.')
            else
              for (final task in widgetData.tasks.take(3))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(task.title),
                  subtitle: Text(task.project ?? 'No project'),
                  onTap: () => onOpenTask(task.id),
                ),
          ],
        ),
      ),
    );
  }
}
