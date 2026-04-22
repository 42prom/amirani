import 'package:dartz/dartz.dart';
import '../../domain/entities/task_entity.dart';
import '../../domain/repositories/task_repository.dart';
import '../datasources/task_remote_data_source.dart';

class TaskRepositoryImpl implements TaskRepository {
  final TaskRemoteDataSource _ds;
  TaskRepositoryImpl(this._ds);

  @override
  Future<Either<String, List<TaskEntity>>> getTodayTasks() async {
    try {
      return Right(await _ds.getTodayTasks());
    } catch (e) {
      return Left(e.toString());
    }
  }

  @override
  Future<Either<String, TaskEntity>> completeTask(String taskId) async {
    try {
      return Right(await _ds.completeTask(taskId));
    } catch (e) {
      return Left(e.toString());
    }
  }
}
