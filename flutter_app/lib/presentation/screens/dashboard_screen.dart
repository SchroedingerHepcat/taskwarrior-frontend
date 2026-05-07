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
                  controller: controller,
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

class _DashboardWidgetCard extends StatefulWidget {
  const _DashboardWidgetCard({
    required this.controller,
    required this.data,
    required this.onOpenTask,
  });

  final ShellController controller;
  final DashboardWidgetData? data;
  final ValueChanged<String> onOpenTask;

  @override
  State<_DashboardWidgetCard> createState() => _DashboardWidgetCardState();
}

class _DashboardWidgetCardState extends State<_DashboardWidgetCard> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final widgetData = widget.data;

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
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: widgetData == null || widgetData.tasks.isEmpty
                      ? const Text('No tasks matched this server query.')
                      : Column(
                          children: <Widget>[
                            for (final task in widgetData.tasks.take(3))
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Checkbox(
                                  key: Key(
                                    'dashboard-complete-'
                                    '${widgetData.widget.name}-${task.id}',
                                  ),
                                  value: task.status == TaskStatus.completed,
                                  onChanged: widget.controller.isSaving
                                      ? null
                                      : (_) => _setCompleted(task),
                                ),
                                title: Text(task.title),
                                subtitle: Text(task.project ?? 'No project'),
                                onTap: () => widget.onOpenTask(task.id),
                              ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setCompleted(TaskItem task) async {
    final completed = task.status == TaskStatus.completed;
    await widget.controller.transitionTask(
      task,
      completed ? TaskStatus.pending : TaskStatus.completed,
    );
  }
}
