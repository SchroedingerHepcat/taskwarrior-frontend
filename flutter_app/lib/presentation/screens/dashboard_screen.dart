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
    final fixedWidgets = controller.enabledWidgets.toList()
      ..sort((left, right) => left.index.compareTo(right.index));
    final savedViewWidgets = controller.dashboardSavedViewData;
    final panelCount = fixedWidgets.length + savedViewWidgets.length;

    return ListView(
      key: const Key('dashboard-screen'),
      children: <Widget>[
        Text(
          'Dashboard',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Panels are configured from Settings and backed by server queries.',
        ),
        const SizedBox(height: 20),
        if (panelCount == 0)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No dashboard panels are enabled.'),
            ),
          ),
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
              itemCount: panelCount,
              itemBuilder: (context, index) {
                if (index < fixedWidgets.length) {
                  final widgetType = fixedWidgets[index];
                  final widgetData = controller.widgetDataFor(widgetType);

                  return _DashboardWidgetCard(
                    controller: controller,
                    title: widgetData?.widget.title ?? 'Loading',
                    keySeed: widgetData?.widget.name ?? 'loading',
                    tasks: widgetData?.tasks,
                    onOpenTask: onOpenTask,
                  );
                }

                final savedData = savedViewWidgets[index - fixedWidgets.length];

                return _DashboardWidgetCard(
                  controller: controller,
                  title: savedData.widget.title,
                  keySeed: savedData.widget.id,
                  tasks: savedData.tasks,
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
    required this.title,
    required this.keySeed,
    required this.tasks,
    required this.onOpenTask,
  });

  final ShellController controller;
  final String title;
  final String keySeed;
  final List<TaskItem>? tasks;
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
    final tasks = widget.tasks;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('${tasks?.length ?? 0} tasks'),
            const SizedBox(height: 16),
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: tasks == null || tasks.isEmpty
                      ? const Text('No tasks matched this server query.')
                      : Column(
                          children: <Widget>[
                            for (final task in tasks.take(3))
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Checkbox(
                                  key: Key(
                                    'dashboard-complete-'
                                    '${widget.keySeed}-${task.id}',
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
