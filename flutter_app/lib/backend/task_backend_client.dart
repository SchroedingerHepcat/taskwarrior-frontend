import '../models/shell_models.dart';

abstract interface class TaskBackendClient {
  Future<BackendHealth> healthcheck();

  Future<List<TaskItem>> queryTasks(TaskQuery query);
}
