import '../models/shell_models.dart';

abstract final class AppRoutes {
  static const dashboard = '/dashboard';
  static const tasks = '/tasks';
  static const board = '/board';
  static const detail = '/detail';

  static String pathFor(ShellSection section) {
    switch (section) {
      case ShellSection.dashboard:
        return dashboard;
      case ShellSection.tasks:
        return tasks;
      case ShellSection.board:
        return board;
      case ShellSection.detail:
        return detail;
    }
  }

  static ShellSection sectionFor(String? routeName) {
    switch (routeName) {
      case tasks:
        return ShellSection.tasks;
      case board:
        return ShellSection.board;
      case detail:
        return ShellSection.detail;
      case dashboard:
      default:
        return ShellSection.dashboard;
    }
  }
}
