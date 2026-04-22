import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/models/user_body_metrics.dart';
import '../models/daily_macro_model.dart';
import '../models/diet_plan_model.dart';
import '../../domain/entities/meal_entity.dart';
import '../../domain/entities/diet_preferences_entity.dart';

abstract class DietRemoteDataSource {
  /// Fetch today's macro progress from the backend.
  Future<DailyMacroModel> getDailyMacros(DateTime date);

  /// Log a meal to the backend food log.
  Future<void> logMeal(MealEntity meal);

  /// Enqueue an AI diet plan generation job on the backend.
  /// Sends the full [DietPreferencesEntity] so the AI receives every user
  /// preference collected during onboarding (allergies, dietary style, budget,
  /// meal times, liked/disliked foods, cooking skill, and body metrics).
  /// Returns a [jobId] that can be polled via [getJobStatus].
  Future<String> generateAIDietPlan({
    required DietPreferencesEntity prefs,
    UserBodyMetrics? userMetrics,
  });

  /// Poll the status of an AI generation job.
  /// Returns one of: QUEUED | PROCESSING | COMPLETED | FAILED
  Future<Map<String, dynamic>> getJobStatus(String jobId);

  /// Fetch the currently active diet plan (Trainer or AI).
  Future<DietPlanModel?> getActiveDietPlan();
}

class DietRemoteDataSourceImpl implements DietRemoteDataSource {
  final Dio dio;

  DietRemoteDataSourceImpl({required this.dio});

  @override
  Future<DailyMacroModel> getDailyMacros(DateTime date) async {
    try {
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final response = await dio
          .get('/sync/diet/macros', queryParameters: {'date': dateStr});

      if (response.statusCode == 200 && response.data['data'] != null) {
        return DailyMacroModel.fromJson(response.data['data']);
      }
      throw ServerException('No nutrition data found for $dateStr');
    } on DioException catch (e) {
      throw ServerException(e.response?.data?['error']?['message'] ??
          'Could not fetch daily macros');
    } catch (e) {
      throw ServerException('Could not fetch daily macros: $e');
    }
  }

  @override
  Future<void> logMeal(MealEntity meal) async {
    try {
      // Backend expects externalFood object matching Nutritionix schema.
      await dio.post('/food/log', data: {
        'externalFood': {
          'name': meal.name,
          'calories': meal.calories,
          'protein': meal.protein,
          'carbs': meal.carbs,
          'fats': meal.fats,
          'source': 'USER',
        },
        'mealType': meal.type?.toUpperCase() ?? 'SNACK',
        'grams': 100, // Default or derived
      });
    } on DioException catch (e) {
      throw ServerException(
          e.response?.data?['error']?['message'] ?? 'Failed to log meal');
    } catch (e) {
      throw ServerException('Failed to log meal: $e');
    }
  }

  @override
  Future<String> generateAIDietPlan({
    required DietPreferencesEntity prefs,
    UserBodyMetrics? userMetrics,
  }) async {
    try {
      // Build meal times map — only include times the user actually set.
      final mealTimes = <String, String>{};
      if (prefs.breakfastTime != null) mealTimes['breakfast'] = prefs.breakfastTime!;
      if (prefs.morningSnackTime != null) mealTimes['morning_snack'] = prefs.morningSnackTime!;
      if (prefs.lunchTime != null) mealTimes['lunch'] = prefs.lunchTime!;
      if (prefs.afternoonSnackTime != null) mealTimes['afternoon_snack'] = prefs.afternoonSnackTime!;
      if (prefs.dinnerTime != null) mealTimes['dinner'] = prefs.dinnerTime!;

      // Backend route: POST /sync/ai/generate-plan (returns HTTP 222 Accepted).
      // Payload matches ApiGenerationStrategy.fetchDietPlanFromApi exactly so
      // both the onboarding path and the regenerate path send identical data.
      final response = await dio.post('/sync/ai/generate-plan', data: {
        'type': 'DIET',
        'preferences': {
          'goals': prefs.goal.name,
          'dietary_style': prefs.dietaryStyle.name,
          'restrictions': prefs.allergies.map((a) => a.type.name).toList(),
          'allergies_structured': prefs.allergies.map((a) => {
            'type': a.type.name,
            'severity': a.severity.name,
            if (a.customName != null) 'name': a.customName,
          }).toList(),
          'meals_per_day': prefs.mealsPerDay,
          'cooking_skill': prefs.cookingSkill.name,
          'likes': prefs.likedFoods,
          'disliked_foods': prefs.dislikedFoods,
          'max_prep_minutes': prefs.maxPrepTimeMinutes,
          'budget': prefs.budget.name,
          if (mealTimes.isNotEmpty) 'meal_times': mealTimes,
          if (userMetrics != null)
            'userMetrics': {
              'weightKg': userMetrics.weightKg,
              'heightCm': userMetrics.heightCm,
              'age': userMetrics.age,
              'gender': userMetrics.isMale ? 'MALE' : 'FEMALE',
              'targetWeightKg': userMetrics.targetWeightKg,
              'medicalConditions': userMetrics.medicalConditions,
            },
          if (userMetrics?.tdee != null) 'tdee': userMetrics!.tdee,
          if (userMetrics?.targetCalories != null) 'target_calories': userMetrics!.targetCalories,
          if (userMetrics?.targetProteinG != null) 'target_protein_g': userMetrics!.targetProteinG,
        },
      });

      // Backend returns 202 Accepted for async job enqueue (was 222 — now fixed).
      final statusCode = response.statusCode ?? 0;
      if (statusCode >= 200 && statusCode < 300 && response.data['data'] != null) {
        final jobId = response.data['data']['jobId']?.toString();
        if (jobId != null && jobId.isNotEmpty) return jobId;
      }
      throw ServerException('Unexpected response from diet plan generator');
    } on DioException catch (e) {
      throw ServerException(
          e.response?.data?['error']?['message'] ?? 'Server error');
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
        queryParameters: {'type': 'DIET'},
      );
      if (response.statusCode == 200 && response.data['data'] != null) {
        return Map<String, dynamic>.from(response.data['data']);
      }
      throw ServerException('Could not retrieve job status');
    } on DioException catch (e) {
      throw ServerException(
          e.response?.data?['error']?['message'] ?? 'Server error');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<DietPlanModel?> getActiveDietPlan() async {
    try {
      final response = await dio.get('/sync/diet/plan');
      if (response.statusCode == 200 && response.data['data'] != null) {
        return DietPlanModel.fromJson(response.data['data']);
      }
      return null;
    } on DioException catch (e) {
      throw ServerException(
          e.response?.data?['error']?['message'] ?? 'Server error');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }
}
