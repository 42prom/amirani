import 'package:dio/dio.dart';
import '../../domain/entities/task_entity.dart';

class TaskRemoteDataSource {
  final Dio _dio;
  TaskRemoteDataSource(this._dio);

  TaskEntity _parse(Map<String, dynamic> j) {
    TaskType parseType(String? raw) {
      switch (raw) {
        case 'WORKOUT_SESSION': return TaskType.workoutSession;
        case 'MEAL':            return TaskType.meal;
        default:                return TaskType.custom;
      }
    }

    return TaskEntity(
      id:          j['id']?.toString() ?? '',
      title:       j['title']?.toString() ?? '',
      description: j['description'] as String?,
      type:        parseType(j['taskType'] as String?),
      points:      (j['points'] as num?)?.toInt() ?? 10,
      isCompleted: j['isCompleted'] as bool? ?? false,
      completedAt: j['completedAt'] != null
          ? DateTime.tryParse(j['completedAt'].toString())
          : null,
      planId: j['planId'] as String?,
    );
  }

  Future<List<TaskEntity>> getTodayTasks() async {
    final res  = await _dio.get('/tasks/today');
    final list = (res.data['data'] as List?) ?? [];
    return list.map((e) => _parse(e as Map<String, dynamic>)).toList();
  }

  Future<TaskEntity> completeTask(String taskId) async {
    final res = await _dio.patch('/tasks/$taskId/complete');
    return _parse(res.data['data'] as Map<String, dynamic>);
  }
}
