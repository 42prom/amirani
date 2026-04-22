import 'package:dartz/dartz.dart';
import '../entities/task_entity.dart';

abstract class TaskRepository {
  Future<Either<String, List<TaskEntity>>> getTodayTasks();
  Future<Either<String, TaskEntity>> completeTask(String taskId);
}
