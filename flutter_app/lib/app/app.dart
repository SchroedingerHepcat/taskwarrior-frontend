import 'package:flutter/material.dart';

import '../backend/task_backend_client.dart';
import '../models/shell_models.dart';
import '../presentation/taskwarrior_shell.dart';
import 'app_theme.dart';
import 'routes.dart';
import 'shell_controller.dart';

class TaskwarriorFrontendApp extends StatefulWidget {
  const TaskwarriorFrontendApp({
    super.key,
    this.backend,
    this.initialBackendUrl,
    this.backendFactory,
    this.saveBackendUrl,
    this.initialThemePreference = AppThemePreference.dark,
    this.saveThemePreference,
    this.initialSavedViews = const <SavedTaskView>[],
    this.saveSavedViews,
    this.initialDashboardLayout,
    this.saveDashboardLayout,
  });

  final TaskBackendClient? backend;
  final String? initialBackendUrl;
  final TaskBackendClient Function(String baseUrl)? backendFactory;
  final Future<void> Function(String baseUrl)? saveBackendUrl;
  final AppThemePreference initialThemePreference;
  final Future<void> Function(AppThemePreference preference)?
      saveThemePreference;
  final List<SavedTaskView> initialSavedViews;
  final Future<void> Function(List<SavedTaskView> views)? saveSavedViews;
  final DashboardLayout? initialDashboardLayout;
  final Future<void> Function(DashboardLayout layout)? saveDashboardLayout;

  @override
  State<TaskwarriorFrontendApp> createState() => _TaskwarriorFrontendAppState();
}

class _TaskwarriorFrontendAppState extends State<TaskwarriorFrontendApp> {
  late final ShellController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ShellController(
      backend: widget.backend,
      backendUrl: widget.initialBackendUrl,
      backendFactory: widget.backendFactory,
      saveBackendUrl: widget.saveBackendUrl,
      themePreference: widget.initialThemePreference,
      saveThemePreference: widget.saveThemePreference,
      savedViews: widget.initialSavedViews,
      saveSavedViews: widget.saveSavedViews,
      dashboardLayout: widget.initialDashboardLayout,
      saveDashboardLayout: widget.saveDashboardLayout,
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'Taskwarrior Frontend',
          debugShowCheckedModeBanner: false,
          theme: buildLightAppTheme(),
          darkTheme: buildDarkAppTheme(),
          themeMode: _controller.themePreference.themeMode,
          initialRoute:
              widget.backend == null ? AppRoutes.settings : AppRoutes.dashboard,
          onGenerateRoute: (settings) {
            final section = AppRoutes.sectionFor(settings.name);

            return PageRouteBuilder<void>(
              settings: settings,
              transitionDuration: const Duration(milliseconds: 220),
              reverseTransitionDuration: const Duration(milliseconds: 180),
              pageBuilder: (context, animation, secondaryAnimation) {
                return FadeTransition(
                  opacity: animation,
                  child: TaskwarriorShell(
                    controller: _controller,
                    currentSection: section,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
