import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/workout_plan_storage_service.dart';
import '../../core/services/diet_plan_storage_service.dart';
import 'tier_limits_provider.dart';

/// Pre-warms all critical local caches so pages show data instantly on first
/// render rather than flashing a loading spinner.
///
/// Runs in parallel during the splash screen before the router redirects the
/// user to their destination. A 3-second safety timeout prevents a broken
/// storage layer from blocking startup indefinitely.
final appBootProvider = FutureProvider<void>((ref) async {
  Future<void> safely(Future<Object?> f) => f.then((_) {}).catchError((_) {});

  await Future.wait<void>([
    // Hive workout plan — workout page reads this first
    safely(ref.read(savedWorkoutPlanProvider.future)),
    // Hive diet plan — diet page reads this first
    safely(ref.read(savedDietPlanProvider.future)),
    // Tier limits — AI buttons need this to enforce guards
    safely(ref.read(tierLimitsProvider.future)),
  ]).timeout(
    const Duration(seconds: 3),
    onTimeout: () => <void>[], // Never block boot on storage failure
  );
});
