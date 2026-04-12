import 'package:flutter/material.dart';

import '../../models/shell_models.dart';

class BoardScreen extends StatelessWidget {
  const BoardScreen({
    super.key,
    required this.tasks,
    required this.onOpenTask,
    required this.onQueueMove,
  });

  final List<TaskItem> tasks;
  final ValueChanged<String> onOpenTask;
  final void Function({
    required TaskItem task,
    required BoardLane lane,
  }) onQueueMove;

  @override
  Widget build(BuildContext context) {
    final referenceTime = DateTime.now();

    return Column(
      key: const Key('board-screen'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Kanban-style board placeholder',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Drag cards between lanes to prove the UI shape. '
          'Persisted transitions stay server-owned in later milestones.',
        ),
        const SizedBox(height: 20),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 860;
              final children = BoardLane.values
                  .map(
                    (lane) => _BoardColumn(
                      lane: lane,
                      tasks: tasks
                          .where(
                            (task) => task.laneFor(referenceTime) == lane,
                          )
                          .toList(),
                      onOpenTask: onOpenTask,
                      onQueueMove: onQueueMove,
                    ),
                  )
                  .toList();

              if (wide) {
                return Row(
                  children: children
                      .expand(
                        (child) => <Widget>[
                          Expanded(child: child),
                          const SizedBox(width: 12),
                        ],
                      )
                      .toList()
                    ..removeLast(),
                );
              }

              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: children.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) => SizedBox(
                  width: 300,
                  child: children[index],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BoardColumn extends StatefulWidget {
  const _BoardColumn({
    required this.lane,
    required this.tasks,
    required this.onOpenTask,
    required this.onQueueMove,
  });

  final BoardLane lane;
  final List<TaskItem> tasks;
  final ValueChanged<String> onOpenTask;
  final void Function({
    required TaskItem task,
    required BoardLane lane,
  }) onQueueMove;

  @override
  State<_BoardColumn> createState() => _BoardColumnState();
}

class _BoardColumnState extends State<_BoardColumn> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return DragTarget<TaskItem>(
      onWillAcceptWithDetails: (_) {
        setState(() {
          _isHovering = true;
        });
        return true;
      },
      onLeave: (_) {
        setState(() {
          _isHovering = false;
        });
      },
      onAcceptWithDetails: (details) {
        setState(() {
          _isHovering = false;
        });
        widget.onQueueMove(
          task: details.data,
          lane: widget.lane,
        );
      },
      builder: (context, candidates, rejected) {
        return Card(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _isHovering
                    ? Theme.of(context).colorScheme.secondary
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.lane.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: widget.tasks.isEmpty
                      ? Center(
                          child: Text(
                            'Drop a card here',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : ListView.separated(
                          itemCount: widget.tasks.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final task = widget.tasks[index];

                            return LongPressDraggable<TaskItem>(
                              data: task,
                              feedback: Material(
                                color: Colors.transparent,
                                child: _BoardCard(
                                  task: task,
                                  compact: true,
                                  onTap: null,
                                ),
                              ),
                              child: _BoardCard(
                                task: task,
                                compact: false,
                                onTap: () => widget.onOpenTask(task.id),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BoardCard extends StatelessWidget {
  const _BoardCard({
    required this.task,
    required this.compact,
    required this.onTap,
  });

  final TaskItem task;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                task.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                task.project,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
