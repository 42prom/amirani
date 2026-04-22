import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../models/workout_plan_model.dart';

abstract class WorkoutRemoteDataSource {
  /// Fetch the user's currently active workout plan.
  Future<WorkoutPlanModel?> getActiveWorkoutPlan();

  /// Enqueue an AI workout plan generation job on the backend.
  /// Returns a [jobId] that can be polled via [getJobStatus].
  Future<String> generateAIPlan({
    required String goals,
    required String level,
    int daysPerWeek = 4,
    List<String>? targetMuscles,
    List<String>? restrictions,
  });

  /// Poll the status of an AI generation job.
  /// Returns one of: QUEUED | PROCESSING | COMPLETED | FAILED
  Future<Map<String, dynamic>> getJobStatus(String jobId);
}

class WorkoutRemoteDataSourceImpl implements WorkoutRemoteDataSource {
  final Dio dio;

  WorkoutRemoteDataSourceImpl({required this.dio});

  @override
  Future<WorkoutPlanModel?> getActiveWorkoutPlan() async {
    try {
      final response = await dio.get('/sync/workout/plan');

      if (response.statusCode == 200 && response.data['data'] != null) {
        return WorkoutPlanModel.fromJson(response.data['data']);
      }
      return null;
    } on DioException catch (e) {
      throw ServerException(e.response?.data?['error']?['message'] ?? 'Server error');
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<String> generateAIPlan({
    required String goals,
    required String level,
    int daysPerWeek = 4,
    List<String>? targetMuscles,
    List<String>? restrictions,
  }) async {
    try {
      // Backend route: POST /sync/ai/generate-plan (returns HTTP 222 Accepted)
      final response = await dio.post('/sync/ai/generate-plan', data: {
        'type': 'WORKOUT',
        'preferences': {
          'goals': goals,
          'goal': goals,
          'fitnessLevel': level.toUpperCase(),
          'fitness_level': level,
          'daysPerWeek': daysPerWeek,
          'days_per_week': daysPerWeek,
          if (targetMuscles != null) 'target_muscles': targetMuscles,
          if (restrictions != null) 'restrictions': restrictions,
        },
      });

      // Backend sends 222 (Accepted) for async job enqueue
      final statusCode = response.statusCode ?? 0;
      if (statusCode >= 200 && statusCode < 300 && response.data['data'] != null) {
        final jobId = response.data['data']['jobId']?.toString();
        if (jobId != null && jobId.isNotEmpty) return jobId;
      }
      throw ServerException('Unexpected response from workout plan generator');
    } on DioException catch (e) {
      throw ServerException(e.response?.data?['error']?['message'] ?? 'Server error');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> getJobStatus(String jobId) async {
    try {
      // Backend route: GET /sync/ai/status/:jobId
      final response = await dio.get(
        '/sync/ai/status/$jobId',
        queryParameters: {'type': 'WORKOUT'},
      );
      if (response.statusCode == 200 && response.data['data'] != null) {
        return Map<String, dynamic>.from(response.data['data']);
      }
      throw ServerException('Could not retrieve job status');
    } on DioException catch (e) {
      throw ServerException(e.response?.data?['error']?['message'] ?? 'Server error');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }
}
