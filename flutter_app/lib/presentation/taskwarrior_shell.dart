import 'package:flutter/material.dart';

import '../app/routes.dart';
import '../app/shell_controller.dart';
import '../models/shell_models.dart';
import 'screens/board_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/task_detail_screen.dart';
import 'screens/task_list_screen.dart';

class TaskwarriorShell extends StatelessWidget {
  const TaskwarriorShell({
    super.key,
    required this.controller,
    required this.currentSection,
  });

  final ShellController controller;
  final ShellSection currentSection;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final width = MediaQuery.sizeOf(context).width;
        final compact = width < 900;
        final expanded = width >= 1240;

        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFFF5F1E8),
                Color(0xFFE9F2EF),
              ],
            ),
          ),
          child: Scaffold(
            body: SafeArea(
              child: compact
                  ? _CompactShell(
                      controller: controller,
                      currentSection: currentSection,
                    )
                  : _WideShell(
                      controller: controller,
                      currentSection: currentSection,
                      expanded: expanded,
                    ),
            ),
            bottomNavigationBar: compact
                ? NavigationBar(
                    selectedIndex: ShellSection.values.indexOf(currentSection),
                    onDestinationSelected: (index) {
                      _goToSection(
                        context,
                        ShellSection.values[index],
                      );
                    },
                    destinations: ShellSection.values
                        .map(
                          (section) => NavigationDestination(
                            icon: Icon(section.icon),
                            label: section.label,
                          ),
                        )
                        .toList(),
                  )
                : null,
          ),
        );
      },
    );
  }

  void _goToSection(
    BuildContext context,
    ShellSection section,
  ) {
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.pathFor(section),
    );
  }
}

class _CompactShell extends StatelessWidget {
  const _CompactShell({
    required this.controller,
    required this.currentSection,
  });

  final ShellController controller;
  final ShellSection currentSection;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _ShellHeader(
            controller: controller,
            title: currentSection.label,
            subtitle: 'Responsive local-development shell',
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _SectionContent(
              controller: controller,
              currentSection: currentSection,
              showContext: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _WideShell extends StatelessWidget {
  const _WideShell({
    required this.controller,
    required this.currentSection,
    required this.expanded,
  });

  final ShellController controller;
  final ShellSection currentSection;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(16),
          child: NavigationRail(
            selectedIndex: ShellSection.values.indexOf(currentSection),
            extended: expanded,
            destinations: ShellSection.values
                .map(
                  (section) => NavigationRailDestination(
                    icon: Icon(section.icon),
                    label: Text(section.label),
                  ),
                )
                .toList(),
            onDestinationSelected: (index) {
              Navigator.of(context).pushReplacementNamed(
                AppRoutes.pathFor(ShellSection.values[index]),
              );
            },
            leading: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .secondary
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Icon(Icons.track_changes_outlined),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: Column(
                    children: <Widget>[
                      _ShellHeader(
                        controller: controller,
                        title: currentSection.label,
                        subtitle: 'Landscape and portrait aware shell',
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _SectionContent(
                          controller: controller,
                          currentSection: currentSection,
                          showContext: expanded,
                        ),
                      ),
                    ],
                  ),
                ),
                if (expanded) ...<Widget>[
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ContextPanel(controller: controller),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ShellHeader extends StatelessWidget {
  const _ShellHeader({
    required this.controller,
    required this.title,
    required this.subtitle,
  });

  final ShellController controller;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(subtitle),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Text(
                  controller.connectionLabel,
                  key: const Key('connection-pill'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionContent extends StatelessWidget {
  const _SectionContent({
    required this.controller,
    required this.currentSection,
    required this.showContext,
  });

  final ShellController controller;
  final ShellSection currentSection;
  final bool showContext;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.errorMessage != null) {
      return Center(
        child: Text(controller.errorMessage!),
      );
    }

    switch (currentSection) {
      case ShellSection.dashboard:
        return DashboardScreen(
          controller: controller,
          onOpenTask: (taskId) {
            controller.selectTask(taskId);
            Navigator.of(context).pushReplacementNamed(
              AppRoutes.detail,
            );
          },
        );
      case ShellSection.tasks:
        return TaskListScreen(
          controller: controller,
          onOpenTask: (taskId) {
            controller.selectTask(taskId);
            Navigator.of(context).pushReplacementNamed(
              AppRoutes.detail,
            );
          },
        );
      case ShellSection.board:
        return BoardScreen(
          tasks: controller.allTasks,
          onOpenTask: controller.selectTask,
          onQueueMove: controller.recordBoardIntent,
        );
      case ShellSection.detail:
        return TaskDetailScreen(
          controller: controller,
          showContextHeader: !showContext,
        );
    }
  }
}

class _ContextPanel extends StatelessWidget {
  const _ContextPanel({
    required this.controller,
  });

  final ShellController controller;

  @override
  Widget build(BuildContext context) {
    final task = controller.selectedTask;

    return Card(
      key: const Key('desktop-context-panel'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Shell context',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text(controller.connectionLabel),
            const SizedBox(height: 24),
            if (task != null) ...<Widget>[
              Text(
                task.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(task.summary),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    task.tags.map((tag) => Chip(label: Text(tag))).toList(),
              ),
            ],
            if (controller.boardIntent != null) ...<Widget>[
              const SizedBox(height: 24),
              Text(
                controller.boardIntent!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
