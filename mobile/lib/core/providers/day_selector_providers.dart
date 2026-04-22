import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Manages the selected day in the Workout tab day selector.
/// Defaults to the current weekday (0-6).
final workoutDaySelectorProvider = StateProvider<int>((ref) {
  return DateTime.now().weekday - 1;
});

/// Manages the selected day in the Diet tab day selector.
/// Defaults to the current weekday (0-6).
final dietDaySelectorProvider = StateProvider<int>((ref) {
  return DateTime.now().weekday - 1;
});

/// Shared selected day for Dashboard and Gym tabs (0 = Monday … 6 = Sunday).
/// Both pages read/write this so navigating between them keeps the selection in sync.
final activityDaySelectorProvider = StateProvider<int>((ref) {
  return DateTime.now().weekday - 1;
});
