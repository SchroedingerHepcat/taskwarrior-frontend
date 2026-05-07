import '../models/shell_models.dart';

abstract interface class TaskBackendClient {
  Future<BackendHealth> healthcheck();

  Future<List<TaskItem>> queryTasks(TaskQuery query);

  Future<TaskItem> getTask(String taskId);

  Future<TaskItem> createTask(CreateTaskInput input);

  Future<TaskItem> updateTask(
    String taskId,
    UpdateTaskInput input,
  );

  Future<TaskItem> transitionTask(
    String taskId,
    TaskTransitionInput input,
  );

  Future<TaskItem> transitionBoardLane(
    String taskId,
    BoardTransitionInput input,
  );
}
