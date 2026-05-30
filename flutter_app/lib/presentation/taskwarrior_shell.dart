import 'package:flutter/material.dart';

import '../app/routes.dart';
import '../app/shell_controller.dart';
import '../models/shell_models.dart';
import 'screens/board_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/settings_screen.dart';
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final contextWidth =
            expanded ? (constraints.maxWidth * 0.26).clamp(320.0, 400.0) : 0.0;
        final railWidth = expanded ? 176.0 : 104.0;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              key: const Key('desktop-rail-column'),
              width: railWidth,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _DesktopNavigationRail(
                  currentSection: currentSection,
                  expanded: expanded,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  0,
                  16,
                  expanded ? 0 : 16,
                  16,
                ),
                child: _MainShellColumn(
                  controller: controller,
                  currentSection: currentSection,
                  showContext: expanded,
                ),
              ),
            ),
            if (expanded) ...<Widget>[
              const SizedBox(width: 16),
              SizedBox(
                key: const Key('desktop-context-column'),
                width: contextWidth,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
                  child: _ContextPanel(controller: controller),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _DesktopNavigationRail extends StatelessWidget {
  const _DesktopNavigationRail({
    required this.currentSection,
    required this.expanded,
  });

  final ShellSection currentSection;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final navigation = Column(
      key: const Key('desktop-navigation'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Align(
          alignment: expanded ? Alignment.centerLeft : Alignment.center,
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
        const SizedBox(height: 20),
        for (final section in ShellSection.values)
          _DesktopNavigationItem(
            section: section,
            selected: section == currentSection,
            expanded: expanded,
          ),
      ],
    );

    return SingleChildScrollView(
      child: navigation,
    );
  }
}

class _DesktopNavigationItem extends StatelessWidget {
  const _DesktopNavigationItem({
    required this.section,
    required this.selected,
    required this.expanded,
  });

  final ShellSection section;
  final bool selected;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = selected ? colorScheme.onSecondaryContainer : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: selected
            ? colorScheme.secondaryContainer.withValues(alpha: 0.44)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () {
            Navigator.of(context).pushReplacementNamed(
              AppRoutes.pathFor(section),
            );
          },
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? 12 : 0,
              vertical: 10,
            ),
            child: Row(
              mainAxisAlignment:
                  expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  section.icon,
                  color: foreground,
                ),
                if (expanded) ...<Widget>[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      section.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: foreground,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MainShellColumn extends StatelessWidget {
  const _MainShellColumn({
    required this.controller,
    required this.currentSection,
    required this.showContext,
  });

  final ShellController controller;
  final ShellSection currentSection;
  final bool showContext;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('desktop-main-column'),
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
            showContext: showContext,
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
            _SyncStatusButton(
              controller: controller,
              key: const Key('connection-pill'),
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
    if (currentSection == ShellSection.settings) {
      return SettingsScreen(controller: controller);
    }

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
          onQueueMove: controller.moveTaskToBoardLane,
        );
      case ShellSection.detail:
        return TaskDetailScreen(
          controller: controller,
          showContextHeader: !showContext,
        );
      case ShellSection.settings:
        return SettingsScreen(controller: controller);
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
      margin: EdgeInsets.zero,
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
            Row(
              children: <Widget>[
                _SyncStatusButton(controller: controller),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(controller.connectionLabel),
                ),
              ],
            ),
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

class _SyncStatusButton extends StatelessWidget {
  const _SyncStatusButton({
    super.key,
    required this.controller,
  });

  final ShellController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = controller.syncStatus;
    final backendConnected = controller.health != null;
    final icon = _syncIcon(
      status.state,
      backendConnected: backendConnected,
    );
    final color = _syncColor(
      theme,
      status.state,
      backendConnected: backendConnected,
    );
    final tooltip = '${controller.connectionLabel}. '
        '${controller.syncStatusLabel}.';

    return IconButton.filledTonal(
      key: const Key('sync-status-button'),
      tooltip: tooltip,
      onPressed: () => _showSyncDetails(context),
      color: color,
      icon: Icon(icon),
    );
  }

  IconData _syncIcon(
    BackendSyncState state, {
    required bool backendConnected,
  }) {
    if (!backendConnected) {
      return Icons.cloud_off_outlined;
    }

    return switch (state) {
      BackendSyncState.disabled => Icons.cloud_queue_outlined,
      BackendSyncState.configured => Icons.cloud_sync_outlined,
      BackendSyncState.syncing => Icons.sync_outlined,
      BackendSyncState.succeeded => Icons.cloud_done_outlined,
      BackendSyncState.failed => Icons.cloud_off_outlined,
    };
  }

  Color _syncColor(
    ThemeData theme,
    BackendSyncState state, {
    required bool backendConnected,
  }) {
    if (!backendConnected) {
      return theme.colorScheme.error;
    }

    return switch (state) {
      BackendSyncState.disabled => theme.colorScheme.onSurfaceVariant,
      BackendSyncState.configured => theme.colorScheme.primary,
      BackendSyncState.syncing => theme.colorScheme.primary,
      BackendSyncState.succeeded => Colors.green,
      BackendSyncState.failed => theme.colorScheme.error,
    };
  }

  Future<void> _showSyncDetails(BuildContext context) {
    final status = controller.syncStatus;

    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Connection status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Backend: ${controller.connectionLabel}'),
              const SizedBox(height: 8),
              Text('Task sync: ${status.label}'),
              if (status.lastAttemptAt != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  'Last attempt: '
                  '${status.lastAttemptAt!.toLocal()}',
                ),
              ],
              if (status.errorSummary != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(status.errorSummary!),
              ],
            ],
          ),
          actions: <Widget>[
            if (status.retryAvailable)
              TextButton(
                key: const Key('sync-retry-button'),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await controller.retrySync();
                },
                child: const Text('Retry sync'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
