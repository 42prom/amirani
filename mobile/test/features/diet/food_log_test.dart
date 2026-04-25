import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:amirani_app/features/diet/data/datasources/food_remote_data_source.dart';
import 'package:amirani_app/features/diet/data/models/food_models.dart';
import 'package:amirani_app/features/diet/presentation/providers/food_provider.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockFoodRemoteDataSource extends Mock implements FoodRemoteDataSource {}

// ─── Fixtures ─────────────────────────────────────────────────────────────────

const _chicken = FoodSearchResult(
  id: 'food-1',
  name: 'Chicken Breast',
  calories: 165,
  protein: 31,
  carbs: 0,
  fats: 3.6,
  servingGrams: 100,
  source: 'DB',
);

FoodLogEntry _logEntry() => FoodLogEntry(
      id: 'log-1',
      foodName: 'Chicken Breast',
      grams: 150,
      calories: 247.5,
      protein: 46.5,
      carbs: 0,
      fats: 5.4,
      mealType: 'LUNCH',
      loggedAt: DateTime.now(),
    );

FoodDiary _diaryWithEntry(String date) => FoodDiary(
      date: date,
      meals: [
        FoodDiaryMealGroup(
          mealType: 'LUNCH',
          entries: [_logEntry()],
          totalCalories: 247.5,
          totalProtein: 46.5,
          totalCarbs: 0,
          totalFats: 5.4,
        ),
      ],
      totalCalories: 247.5,
      totalProtein: 46.5,
      totalCarbs: 0,
      totalFats: 5.4,
    );

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  late MockFoodRemoteDataSource mockDs;

  setUp(() => mockDs = MockFoodRemoteDataSource());

  // Override both the data source and foodSearchProvider (which internally
  // reads userGymStateProvider → Hive, which is unavailable in unit tests).
  ProviderContainer makeContainer() => ProviderContainer(
        overrides: [
          foodRemoteDataSourceProvider.overrideWithValue(mockDs),
          foodSearchProvider.overrideWith(
            (ref) => FoodSearchNotifier(mockDs),
          ),
        ],
      );

  group('FoodLogNotifier.logFood()', () {
    const date = '2026-04-25';

    test('returns true on success and triggers diary invalidation', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      when(() => mockDs.logFood(
            foodItemId: any(named: 'foodItemId'),
            externalFood: any(named: 'externalFood'),
            mealType: any(named: 'mealType'),
            grams: any(named: 'grams'),
          )).thenAnswer((_) async => _logEntry());

      when(() => mockDs.getDiary(date))
          .thenAnswer((_) async => _diaryWithEntry(date));

      final result = await container.read(foodLogProvider.notifier).logFood(
            food: _chicken,
            mealType: 'LUNCH',
            grams: 150,
            diaryDate: date,
          );

      expect(result, isTrue);
    });

    test('state is AsyncData after a successful log', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      when(() => mockDs.logFood(
            foodItemId: any(named: 'foodItemId'),
            externalFood: any(named: 'externalFood'),
            mealType: any(named: 'mealType'),
            grams: any(named: 'grams'),
          )).thenAnswer((_) async => _logEntry());

      when(() => mockDs.getDiary(date))
          .thenAnswer((_) async => _diaryWithEntry(date));

      await container.read(foodLogProvider.notifier).logFood(
            food: _chicken,
            mealType: 'LUNCH',
            grams: 150,
            diaryDate: date,
          );

      expect(container.read(foodLogProvider), isA<AsyncData<void>>());
    });

    test('returns false and sets AsyncError on network failure', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      when(() => mockDs.logFood(
            foodItemId: any(named: 'foodItemId'),
            externalFood: any(named: 'externalFood'),
            mealType: any(named: 'mealType'),
            grams: any(named: 'grams'),
          )).thenThrow(Exception('network error'));

      final result = await container.read(foodLogProvider.notifier).logFood(
            food: _chicken,
            mealType: 'LUNCH',
            grams: 150,
            diaryDate: date,
          );

      expect(result, isFalse);
      expect(container.read(foodLogProvider), isA<AsyncError<void>>());
    });

    test('sends foodItemId (not externalFood) when food has a DB id', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      when(() => mockDs.logFood(
            foodItemId: 'food-1',
            externalFood: null,
            mealType: 'BREAKFAST',
            grams: 200,
          )).thenAnswer((_) async => _logEntry());

      when(() => mockDs.getDiary(date))
          .thenAnswer((_) async => _diaryWithEntry(date));

      await container.read(foodLogProvider.notifier).logFood(
            food: _chicken,
            mealType: 'BREAKFAST',
            grams: 200,
            diaryDate: date,
          );

      verify(() => mockDs.logFood(
            foodItemId: 'food-1',
            externalFood: null,
            mealType: 'BREAKFAST',
            grams: 200,
          )).called(1);
    });

    test('sends externalFood map when food has no DB id', () async {
      const external = FoodSearchResult(
        id: null,
        name: 'Custom Protein Bar',
        calories: 200,
        protein: 20,
        carbs: 25,
        fats: 5,
        servingGrams: 100,
        source: 'SEARCH',
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      when(() => mockDs.logFood(
            foodItemId: null,
            externalFood: any(named: 'externalFood'),
            mealType: 'SNACK',
            grams: 50,
          )).thenAnswer((_) async => _logEntry());

      when(() => mockDs.getDiary(date))
          .thenAnswer((_) async => _diaryWithEntry(date));

      await container.read(foodLogProvider.notifier).logFood(
            food: external,
            mealType: 'SNACK',
            grams: 50,
            diaryDate: date,
          );

      final captured = verify(() => mockDs.logFood(
            foodItemId: null,
            externalFood: captureAny(named: 'externalFood'),
            mealType: 'SNACK',
            grams: 50,
          )).captured;

      final map = captured.first as Map<String, dynamic>?;
      expect(map?['name'], 'Custom Protein Bar');
    });
  });

  group('FoodSearchNotifier.search()', () {
    test('clears results when query is empty', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(foodSearchProvider.notifier).search('');

      expect(container.read(foodSearchProvider).results, isEmpty);
      verifyNever(() => mockDs.searchFood(any(), country: any(named: 'country')));
    });

    test('populates results on successful search', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      when(() => mockDs.searchFood('chicken', country: any(named: 'country')))
          .thenAnswer((_) async => [_chicken]);

      await container.read(foodSearchProvider.notifier).search('chicken');

      expect(container.read(foodSearchProvider).results, hasLength(1));
      expect(container.read(foodSearchProvider).results.first.name, 'Chicken Breast');
    });

    test('sets error state on search failure', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      when(() => mockDs.searchFood('bad', country: any(named: 'country')))
          .thenThrow(Exception('timeout'));

      await container.read(foodSearchProvider.notifier).search('bad');

      expect(container.read(foodSearchProvider).error, isNotNull);
      expect(container.read(foodSearchProvider).results, isEmpty);
    });
  });
}
