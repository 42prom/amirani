import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:amirani_app/core/providers/points_provider.dart';
import 'package:amirani_app/core/network/dio_provider.dart';
import 'package:amirani_app/core/providers/storage_providers.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockDio extends Mock implements Dio {}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  late MockDio mockDio;
  late SharedPreferences prefs;

  setUp(() async {
    mockDio = MockDio();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer makeContainer() => ProviderContainer(
        overrides: [
          dioProvider.overrideWithValue(mockDio),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

  group('PointsNotifier.syncFromBackend()', () {
    test('updates totalPoints and streakDays from backend response', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      when(() => mockDio.get('/gamification/profile')).thenAnswer(
        (_) async => Response(
          data: {'data': {'totalPoints': 350, 'streakDays': 7}},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/gamification/profile'),
        ),
      );

      await container.read(pointsProvider.notifier).syncFromBackend();

      final state = container.read(pointsProvider);
      expect(state.totalPoints, 350);
      expect(state.streakDays, 7);
    });

    test('persists updated values to SharedPreferences', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      when(() => mockDio.get('/gamification/profile')).thenAnswer(
        (_) async => Response(
          data: {'data': {'totalPoints': 500, 'streakDays': 14}},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/gamification/profile'),
        ),
      );

      await container.read(pointsProvider.notifier).syncFromBackend();

      expect(prefs.getInt('user_points_total'), 500);
      expect(prefs.getInt('user_streak_days'), 14);
    });

    test('keeps cached values when backend call fails', () async {
      SharedPreferences.setMockInitialValues({
        'user_points_total': 100,
        'user_streak_days': 3,
      });
      prefs = await SharedPreferences.getInstance();
      final container = makeContainer();
      addTearDown(container.dispose);

      when(() => mockDio.get('/gamification/profile'))
          .thenThrow(DioException(requestOptions: RequestOptions(path: '/gamification/profile')));

      await container.read(pointsProvider.notifier).syncFromBackend();

      final state = container.read(pointsProvider);
      expect(state.totalPoints, 100);
      expect(state.streakDays, 3);
    });

    test('does not update state when values are unchanged', () async {
      SharedPreferences.setMockInitialValues({
        'user_points_total': 200,
        'user_streak_days': 5,
      });
      prefs = await SharedPreferences.getInstance();
      final container = makeContainer();
      addTearDown(container.dispose);

      when(() => mockDio.get('/gamification/profile')).thenAnswer(
        (_) async => Response(
          data: {'data': {'totalPoints': 200, 'streakDays': 5}},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/gamification/profile'),
        ),
      );

      var stateChanges = 0;
      container.listen(pointsProvider, (_, __) => stateChanges++);

      await container.read(pointsProvider.notifier).syncFromBackend();

      // State unchanged — listener should not have fired after initial load
      expect(stateChanges, 0);
    });
  });

  group('PointsState.levelLabel', () {
    test('returns Beginner below 100 points', () {
      const s = PointsState(totalPoints: 50);
      expect(s.levelLabel, 'Beginner');
    });

    test('returns Active for 100–499 points', () {
      const s = PointsState(totalPoints: 300);
      expect(s.levelLabel, 'Active');
    });

    test('returns Champion at 4000+ points', () {
      const s = PointsState(totalPoints: 5000);
      expect(s.levelLabel, 'Champion');
    });
  });
}
