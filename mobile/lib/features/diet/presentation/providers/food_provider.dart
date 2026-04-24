import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_provider.dart';
import '../../data/datasources/food_remote_data_source.dart';
import '../../data/models/food_models.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

final foodRemoteDataSourceProvider = Provider<FoodRemoteDataSource>((ref) {
  return FoodRemoteDataSourceImpl(dio: ref.watch(dioProvider));
});

// ── Food diary (today) ────────────────────────────────────────────────────────

final foodDiaryProvider = FutureProvider.family<FoodDiary, String>((ref, date) async {
  final ds = ref.watch(foodRemoteDataSourceProvider);
  return ds.getDiary(date);
});

// ── Search ────────────────────────────────────────────────────────────────────

class FoodSearchState {
  final List<FoodSearchResult> results;
  final bool isLoading;
  final String? error;
  final String query;

  const FoodSearchState({
    this.results = const [],
    this.isLoading = false,
    this.error,
    this.query = '',
  });

  FoodSearchState copyWith({
    List<FoodSearchResult>? results,
    bool? isLoading,
    String? error,
    String? query,
  }) =>
      FoodSearchState(
        results: results ?? this.results,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        query: query ?? this.query,
      );
}

class FoodSearchNotifier extends StateNotifier<FoodSearchState> {
  final FoodRemoteDataSource _ds;

  FoodSearchNotifier(this._ds) : super(const FoodSearchState());

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = const FoodSearchState();
      return;
    }
    state = state.copyWith(isLoading: true, error: null, query: query);
    try {
      final results = await _ds.searchFood(query.trim());
      if (!mounted) return;
      state = state.copyWith(results: results, isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString(), results: []);
    }
  }

  Future<FoodSearchResult?> lookupBarcode(String barcode) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _ds.lookupBarcode(barcode);
      if (!mounted) return null;
      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      if (!mounted) return null;
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  void clear() => state = const FoodSearchState();
}

final foodSearchProvider = StateNotifierProvider.autoDispose<FoodSearchNotifier, FoodSearchState>((ref) {
  return FoodSearchNotifier(ref.watch(foodRemoteDataSourceProvider));
});

// ── Log action ────────────────────────────────────────────────────────────────

class FoodLogNotifier extends StateNotifier<AsyncValue<void>> {
  final FoodRemoteDataSource _ds;
  final Ref _ref;

  FoodLogNotifier(this._ds, this._ref) : super(const AsyncData(null));

  Future<bool> logFood({
    required FoodSearchResult food,
    required String mealType,
    required double grams,
    required String diaryDate,
  }) async {
    state = const AsyncLoading();
    try {
      await _ds.logFood(
        foodItemId: food.id,
        externalFood: food.id == null
            ? {
                'name': food.name,
                'calories': food.calories,
                'protein': food.protein,
                'carbs': food.carbs,
                'fats': food.fats,
                'source': food.source ?? 'SEARCH',
              }
            : null,
        mealType: mealType,
        grams: grams,
      );
      if (!mounted) return false;
      state = const AsyncData(null);
      _ref.invalidate(foodDiaryProvider(diaryDate));
      return true;
    } catch (e) {
      if (!mounted) return false;
      debugPrint('[Food] logFood error: $e');
      state = AsyncError(e, StackTrace.current);
      return false;
    }
  }

  Future<bool> deleteLog(String logId, String diaryDate) async {
    try {
      await _ds.deleteLog(logId);
      if (!mounted) return false;
      _ref.invalidate(foodDiaryProvider(diaryDate));
      return true;
    } catch (e) {
      debugPrint('[Food] deleteLog error: $e');
      return false;
    }
  }
}

final foodLogProvider = StateNotifierProvider.autoDispose<FoodLogNotifier, AsyncValue<void>>((ref) {
  return FoodLogNotifier(ref.watch(foodRemoteDataSourceProvider), ref);
});
