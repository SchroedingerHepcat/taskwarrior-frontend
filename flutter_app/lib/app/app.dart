import 'package:flutter/material.dart';

import '../backend/task_backend_client.dart';
import '../presentation/taskwarrior_shell.dart';
import 'app_theme.dart';
import 'routes.dart';
import 'shell_controller.dart';

class TaskwarriorFrontendApp extends StatefulWidget {
  const TaskwarriorFrontendApp({
    super.key,
    required this.backend,
  });

  final TaskBackendClient backend;

  @override
  State<TaskwarriorFrontendApp> createState() => _TaskwarriorFrontendAppState();
}

class _TaskwarriorFrontendAppState extends State<TaskwarriorFrontendApp> {
  late final ShellController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ShellController(backend: widget.backend)..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taskwarrior Frontend',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      initialRoute: AppRoutes.dashboard,
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
  }
}
