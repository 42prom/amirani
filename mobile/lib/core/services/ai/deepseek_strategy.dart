import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../../features/workout/domain/entities/workout_preferences_entity.dart';
import '../../../../features/diet/domain/entities/diet_preferences_entity.dart';
import '../../models/user_body_metrics.dart';

class DeepSeekGenerationStrategy {
  final String apiBaseUrl;
  final String apiKey;
  final String model;
  final Duration timeout;
  final Dio _dio;

  DeepSeekGenerationStrategy({
    required this.apiBaseUrl,
    required this.apiKey,
    required this.model,
    required this.timeout,
    required Dio dio,
  }) : _dio = dio;

  Future<Map<String, dynamic>> getRecommendations(
    WorkoutPreferencesEntity prefs, {
    UserBodyMetrics? userMetrics,
    List<String> targetMuscles = const [],
    Map<int, List<String>> dayMuscleAssignments = const {},
  }) async {
    final prompt = _buildWorkoutPrompt(
        prefs, userMetrics, targetMuscles, dayMuscleAssignments);

    final response = await _dio.post(
      '$apiBaseUrl/chat/completions',
      data: {
        'model': model,
        'messages': [
          {
            'role': 'system',
            'content':
                'You are an expert bodybuilding coach. Respond with valid JSON only. Never add explanations or text outside the JSON object.'
          },
          {'role': 'user', 'content': prompt},
        ],
        'response_format': {'type': 'json_object'},
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        sendTimeout: timeout,
        receiveTimeout: timeout,
      ),
    );

    final content = response.data['choices'][0]['message']['content'];
    final usage = response.data['usage'] as Map<String, dynamic>?;
    return {
      'recommendations': jsonDecode(content?.toString() ?? '{}') as Map<String, dynamic>,
      'usage': usage,
    };
  }

  Future<Map<String, dynamic>> getDietRecommendations(
    DietPreferencesEntity prefs, {
    UserBodyMetrics? userMetrics,
  }) async {
    final prompt = _buildDietPrompt(prefs, userMetrics);

    final response = await _dio.post(
      '$apiBaseUrl/chat/completions',
      data: {
        'model': model,
        'messages': [
          {
            'role': 'system',
            'content':
                'You are an expert nutritionist. Your task is to provide high-level diet recommendations in JSON format.'
          },
          {'role': 'user', 'content': prompt},
        ],
        'response_format': {'type': 'json_object'},
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        sendTimeout: timeout,
        receiveTimeout: timeout,
      ),
    );

    final content = response.data['choices'][0]['message']['content'];
    final usage = response.data['usage'] as Map<String, dynamic>?;
    return {
      'recommendations': jsonDecode(content?.toString() ?? '{}') as Map<String, dynamic>,
      'usage': usage,
    };
  }

  // ─────────────────────────────────────────────────────────────
  // OPTIMIZED WORKOUT PROMPT (Best for your existing system)
  // ─────────────────────────────────────────────────────────────
  String _buildWorkoutPrompt(
    WorkoutPreferencesEntity prefs,
    UserBodyMetrics? metrics,
    List<String> targetMuscles,
    Map<int, List<String>> dayMuscleAssignments,
  ) {
    const dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];

    String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

    final muscleBlock = targetMuscles.isNotEmpty
        ? 'TARGET MUSCLES (PRIORITIZE HEAVILY): ${targetMuscles.map(cap).join(', ')}'
        : 'No specific target muscles — create balanced bro-style plan';

    String dayBlock = '';
    if (dayMuscleAssignments.isNotEmpty) {
      final sorted = dayMuscleAssignments.keys.toList()..sort();
      dayBlock = '\nUSER SELECTED DAY-BY-DAY MUSCLE FOCUS (FOLLOW CLOSELY):\n';
      for (final day in sorted) {
        final muscles = dayMuscleAssignments[day]!.map(cap).join(' + ');
        dayBlock += '  - ${dayNames[day]}: $muscles\n';
      }
    }

    final injuryBlock = prefs.injuries.isNotEmpty
        ? 'INJURIES/LIMITATIONS: ${prefs.injuries.map((i) => "${i.type.name} (${i.severity.name})").join(", ")}'
        : 'No injuries reported';

    final metricsBlock =
        metrics != null ? metrics.toPromptString() : 'No body metrics provided';

    return '''
You are an ELITE bodybuilding coach specializing in classic bro-splits.

**Signature Split Style (Users Love This):**
- Monday:     Chest + Triceps
- Wednesday:  Back + Biceps
- Friday:     Legs + Shoulders

**Rules:**
1. If user chose Monday, Wednesday, Friday + muscles including Chest, Triceps, Back, Biceps, Legs, Shoulders → use this exact split.
2. For other combinations → create balanced bro-style pairings (Chest+Triceps, Back+Biceps, Legs+Shoulders).
3. Distribute muscles across the exact days the user selected.
4. Prioritize safety and recovery.

User Data:
- Goal: ${prefs.goal.name}
- Equipment: ${prefs.availableEquipment.map((e) => e.name).join(', ')}
- Session Duration: ${prefs.sessionDurationMinutes} minutes
- $injuryBlock
- Body Metrics: $metricsBlock
- $muscleBlock
$dayBlock

**Return ONLY this JSON:**

{
  "exercisePriority": ["Bench Press", "Incline Dumbbell Press", "Rope Pushdown", "Lat Pulldown", "Seated Row", "T-Bar Row", "Squats", "Leg Press", "Overhead Press", "Face Pulls", ...],
  "weeklyProgression": {
    "week1": {"repsMultiplier": 1.0, "setsMultiplier": 1.0},
    "week2": {"repsMultiplier": 1.08, "setsMultiplier": 1.0},
    "week3": {"repsMultiplier": 1.15, "setsMultiplier": 1.08},
    "week4": {"repsMultiplier": 0.95, "setsMultiplier": 1.0}
  },
  "restBetweenSets": 75,
  "dayPlans": {
    "Monday": "Chest + Triceps",
    "Wednesday": "Back + Biceps",
    "Friday": "Legs + Shoulders"
  },
  "splitNotes": "Classic bro-split optimized for user"
}

Think step-by-step and generate the plan.
''';
  }

  String _buildDietPrompt(
      DietPreferencesEntity prefs, UserBodyMetrics? metrics) {
    return '''
Generate a 4-week diet plan structure based on:
- Goal: ${prefs.goal.name}
- Dietary Style: ${prefs.dietaryStyle.name}
- Allergies: ${prefs.allergies.map((a) => a.type.name).join(', ')}
- Preferred Foods (Likes): ${prefs.likedFoods.isEmpty ? 'No preferences' : prefs.likedFoods.join(', ')}
- Avoid (Dislikes): ${prefs.dislikedFoods.isEmpty ? 'None' : prefs.dislikedFoods.join(', ')}
- Meals per day: ${prefs.mealsPerDay}
${metrics != null ? '- Metrics:\n${metrics.toPromptString()}' : ''}

Respond with a JSON object containing:
1. "weeklyPlans": A list of 4 objects, each with:
   - "weekNumber": int (1-4)
   - "dailySuggestions": A list of 7 objects (day index 0-6), each with:
     - "dayOfWeek": int
     - "meals": A list of objects, each with: "type" (BREAKFAST, LUNCH, SNACK, DINNER), "name", "description", "ingredients" (list of {name, amount, unit, calories, protein, carbs, fat}), "instructions", "prepTime" (int).
2. "macroRatios": An object with "protein", "carbs", "fat" as decimals summing to 1.0.
''';
  }
}
