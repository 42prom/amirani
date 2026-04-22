import 'package:dio/dio.dart';
import '../../../../features/workout/domain/entities/workout_preferences_entity.dart';
import '../../../../features/diet/domain/entities/diet_preferences_entity.dart';
import '../../models/user_body_metrics.dart';

class ApiGenerationStrategy {
  final Dio dio;
  final Duration timeout;

  ApiGenerationStrategy({
    required this.dio,
    required this.timeout,
  });

  Future<Map<String, dynamic>?> fetchPlanFromApi(
    WorkoutPreferencesEntity prefs,
    String odUserId, {
    UserBodyMetrics? userMetrics,
    List<String> targetMuscleNames = const [],
    String languageCode = 'en',
  }) async {
    final musclesSuffix = targetMuscleNames.isNotEmpty
        ? ' targeting: ${targetMuscleNames.join(', ')}'
        : '';
    final goalsString = '${prefs.goal.name}$musclesSuffix';

    try {
      final response = await dio.post(
        '/sync/ai/generate-plan',
        data: {
          'user_id': odUserId,
          'preferences': {
            'goals': goalsString,
            'goal': prefs.goal.name,
            'target_muscles': targetMuscleNames,
            'fitness_level': prefs.fitnessLevel.name,
            'fitnessLevel': prefs.fitnessLevel.name.toUpperCase(),
            'location': prefs.location.name,
            'training_split': prefs.trainingSplit.name,
            'days_per_week': prefs.daysPerWeek,
            'daysPerWeek': prefs.daysPerWeek,
            'preferred_days': prefs.preferredDays,
            'session_duration_minutes': prefs.sessionDurationMinutes,
            'available_equipment':
                prefs.availableEquipment.map((e) => e.name).toList(),
            'liked_exercises': prefs.likedExercises,
            'disliked_exercises': prefs.dislikedExercises,
            'injuries': prefs.injuries
                .map((i) => {
                      'type': i.type.name,
                      'severity': i.severity.name,
                      'notes': i.notes,
                    })
                .toList(),
            if (userMetrics != null)
              'userMetrics': {
                'weightKg': userMetrics.weightKg,
                'heightCm': userMetrics.heightCm,
                'age': userMetrics.age,
                'gender': userMetrics.isMale ? 'MALE' : 'FEMALE',
                'targetWeightKg': userMetrics.targetWeightKg,
                'medicalConditions': userMetrics.medicalConditions,
              },
            'language_code': languageCode,
          },
        },
        options: Options(receiveTimeout: timeout, sendTimeout: timeout),
      );

      // Backend returns 202 Accepted for async job enqueue
      if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
        return response.data as Map<String, dynamic>;
      }
    } catch (e) {
      // 409 DIET_PLAN_REQUIRED must propagate — do not fall back to offline.
      if (e is DioException && e.response?.statusCode == 409) rethrow;
      return null;
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchDietPlanFromApi(
    DietPreferencesEntity prefs,
    String odUserId, {
    UserBodyMetrics? userMetrics,
    String languageCode = 'en',
  }) async {
    // Build meal times map — only include times the user actually set,
    // AND filter based on the actual mealsPerDay to prevent AI from seeing extra slots.
    final mealTimes = <String, String>{};
    final count = prefs.mealsPerDay;

    // Mapping slots based on backend naming convention in getMealNameSet:
    // 2: B/D | 3: B/L/D | 4: B/L/S/D | 5: B/S1/L/S2/D
    if (prefs.breakfastTime != null) mealTimes['breakfast'] = prefs.breakfastTime!;
    
    if (count >= 5 && prefs.morningSnackTime != null) {
      mealTimes['morning_snack'] = prefs.morningSnackTime!;
    }
    
    if (count >= 3 && prefs.lunchTime != null) {
      mealTimes['lunch'] = prefs.lunchTime!;
    }
    
    if (count >= 4 && prefs.afternoonSnackTime != null) {
      mealTimes['afternoon_snack'] = prefs.afternoonSnackTime!;
    }
    
    if (prefs.dinnerTime != null) mealTimes['dinner'] = prefs.dinnerTime!;

    try {
      final response = await dio.post(
        '/sync/ai/generate-plan',
        data: {
          'user_id': odUserId,
          'type': 'DIET',
          'preferences': {
            'goals': prefs.goal.name,
            'dietary_style': prefs.dietaryStyle.name,
            // Flat allergy type names kept for backward-compat guardrail filter
            'restrictions': prefs.allergies.map((a) => a.type.name).toList(),
            // Structured allergies with severity for AI prompt quality
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
            'language_code': languageCode,
          },
        },
        options: Options(receiveTimeout: timeout, sendTimeout: timeout),
      );

      // Backend returns 202 Accepted for async job enqueue
      if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
        return response.data as Map<String, dynamic>;
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getJobStatus(String jobId, String type) async {
    try {
      final response = await dio.get(
        '/sync/ai/status/$jobId',
        queryParameters: {'type': type},
        options: Options(receiveTimeout: timeout, sendTimeout: timeout),
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<List<dynamic>?> fetchSwappedExercisesFromApi(
    String workoutName,
    List<String> currentExerciseNames,
    List<String> currentTargetMuscles,
    WorkoutPreferencesEntity preferences,
    int count, {
    String languageCode = 'en',
  }) async {
    try {
      final response = await dio.post(
        '/sync/ai/swap-exercises',
        data: {
          'current_workout': {
            'name': workoutName,
            'exercises': currentExerciseNames,
            'target_muscles': currentTargetMuscles,
          },
          'preferences': {
            'location': preferences.location.name,
            'available_equipment':
                preferences.availableEquipment.map((e) => e.name).toList(),
            'disliked_exercises': preferences.dislikedExercises,
            'language_code': languageCode,
          },
          'count': count,
        },
        options: Options(receiveTimeout: timeout, sendTimeout: timeout),
      );

      if (response.statusCode == 200) {
        return response.data['exercises'] as List?;
      }
    } catch (e) {
      return null;
    }
    return null;
  }
}
