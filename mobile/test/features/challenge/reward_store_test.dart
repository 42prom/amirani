import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:amirani_app/core/providers/points_provider.dart';
import 'package:amirani_app/core/network/dio_provider.dart';
import 'package:amirani_app/core/providers/storage_providers.dart';
import 'package:amirani_app/features/challenge/data/datasources/gamification_data_source.dart';
import 'package:amirani_app/features/challenge/data/models/reward_model.dart';
import 'package:amirani_app/features/challenge/presentation/providers/reward_provider.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockGamificationDataSource extends Mock implements GamificationDataSource {}

class MockDio extends Mock implements Dio {}

// ─────────────────────────────────────────────────────────────────────────────

const _reward = RewardModel(
  id: 'reward-1',
  name: 'Water Bottle',
  pointsCost: 100,
  isActive: true,
);

void main() {
  late MockGamificationDataSource mockDs;
  late MockDio mockDio;
  late SharedPreferences prefs;

  setUp(() async {
    mockDs  = MockGamificationDataSource();
    mockDio = MockDio();
    SharedPreferences.setMockInitialValues({'user_points_total': 500, 'user_streak_days': 3});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer makeContainer() => ProviderContainer(
        overrides: [
          gamificationDataSourceProvider.overrideWithValue(mockDs),
          dioProvider.overrideWithValue(mockDio),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

  group('RewardStoreNotifier.redeem() — balance updates', () {
    test('decrements totalPoints in RewardStoreState on successful redemption', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      // Seed the store with a known balance and the reward
      when(() => mockDs.getRewards()).thenAnswer(
        (_) async => (totalPoints: 500, rewards: [_reward]),
      );
      await container.read(rewardStoreProvider.notifier).load();
      expect(container.read(rewardStoreProvider).totalPoints, 500);

      final redemption = RedemptionModel(
        id: 'r1', rewardId: 'reward-1', pointsSpent: 100,
        status: 'COMPLETED', redeemedAt: DateTime.now(), rewardName: 'Water Bottle',
      );
      when(() => mockDs.redeemReward('reward-1')).thenAnswer((_) async => redemption);

      // syncFromBackend will call backend to get updated balance
      when(() => mockDio.get('/gamification/profile')).thenAnswer(
        (_) async => Response(
          data: {'data': {'totalPoints': 400, 'streakDays': 3}},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/gamification/profile'),
        ),
      );

      await container.read(rewardStoreProvider.notifier).redeem('reward-1');

      // RewardStoreState reflects the deduction immediately (optimistic)
      expect(container.read(rewardStoreProvider).totalPoints, 400);
      expect(container.read(rewardStoreProvider).successMessage, contains('Water Bottle'));
    });

    test('syncs pointsProvider after successful redemption', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      when(() => mockDs.getRewards()).thenAnswer(
        (_) async => (totalPoints: 500, rewards: [_reward]),
      );
      await container.read(rewardStoreProvider.notifier).load();

      final redemption = RedemptionModel(
        id: 'r2', rewardId: 'reward-1', pointsSpent: 100,
        status: 'COMPLETED', redeemedAt: DateTime.now(),
      );
      when(() => mockDs.redeemReward('reward-1')).thenAnswer((_) async => redemption);

      when(() => mockDio.get('/gamification/profile')).thenAnswer(
        (_) async => Response(
          data: {'data': {'totalPoints': 400, 'streakDays': 3}},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/gamification/profile'),
        ),
      );

      await container.read(rewardStoreProvider.notifier).redeem('reward-1');

      // Allow the fire-and-forget syncFromBackend to complete
      await Future.delayed(Duration.zero);

      // pointsProvider is also updated to authoritative backend value
      expect(container.read(pointsProvider).totalPoints, 400);
    });

    test('sets error state and does not update balance on redemption failure', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      when(() => mockDs.getRewards()).thenAnswer(
        (_) async => (totalPoints: 50, rewards: [_reward]),
      );
      await container.read(rewardStoreProvider.notifier).load();

      when(() => mockDs.redeemReward('reward-1'))
          .thenThrow(DioException(requestOptions: RequestOptions(path: '/gamification/redeem')));

      await container.read(rewardStoreProvider.notifier).redeem('reward-1');

      final state = container.read(rewardStoreProvider);
      expect(state.totalPoints, 50); // unchanged
      expect(state.error, isNotNull);
      expect(state.redeemingId, isNull);
    });

    test('prevents concurrent redemptions (double-tap guard)', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      when(() => mockDs.getRewards()).thenAnswer(
        (_) async => (totalPoints: 500, rewards: [_reward]),
      );
      await container.read(rewardStoreProvider.notifier).load();

      final redemption = RedemptionModel(
        id: 'r3', rewardId: 'reward-1', pointsSpent: 100,
        status: 'COMPLETED', redeemedAt: DateTime.now(),
      );
      when(() => mockDs.redeemReward('reward-1')).thenAnswer(
        (_) async {
          await Future.delayed(const Duration(milliseconds: 50));
          return redemption;
        },
      );
      when(() => mockDio.get('/gamification/profile')).thenAnswer(
        (_) async => Response(
          data: {'data': {'totalPoints': 400, 'streakDays': 3}},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/gamification/profile'),
        ),
      );

      // Fire two redemptions simultaneously
      final f1 = container.read(rewardStoreProvider.notifier).redeem('reward-1');
      final f2 = container.read(rewardStoreProvider.notifier).redeem('reward-1');
      await Future.wait([f1, f2]);

      // Backend called only once (second call was blocked by redeemingId guard)
      verify(() => mockDs.redeemReward('reward-1')).called(1);
    });
  });
}
