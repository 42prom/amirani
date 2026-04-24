import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../models/food_models.dart';

abstract class FoodRemoteDataSource {
  Future<List<FoodSearchResult>> searchFood(String query, {int limit = 20});
  Future<FoodSearchResult?> lookupBarcode(String barcode);
  Future<FoodLogEntry> logFood({
    String? foodItemId,
    Map<String, dynamic>? externalFood,
    required String mealType,
    required double grams,
  });
  Future<FoodDiary> getDiary(String date);
  Future<void> deleteLog(String logId);
}

class FoodRemoteDataSourceImpl implements FoodRemoteDataSource {
  final Dio dio;
  FoodRemoteDataSourceImpl({required this.dio});

  @override
  Future<List<FoodSearchResult>> searchFood(String query, {int limit = 20}) async {
    try {
      final res = await dio.get('/food/search', queryParameters: {'q': query, 'limit': limit});
      if (res.statusCode == 200 && res.data['data'] != null) {
        final raw = res.data['data'] as List<dynamic>;
        return raw.map((e) => FoodSearchResult.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw ServerException(e.response?.data?['error']?['message'] ?? 'Search failed');
    }
  }

  @override
  Future<FoodSearchResult?> lookupBarcode(String barcode) async {
    try {
      final res = await dio.get('/food/barcode/$barcode');
      if (res.statusCode == 200 && res.data['data'] != null) {
        return FoodSearchResult.fromJson(res.data['data'] as Map<String, dynamic>);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw ServerException(e.response?.data?['error']?['message'] ?? 'Barcode lookup failed');
    }
  }

  @override
  Future<FoodLogEntry> logFood({
    String? foodItemId,
    Map<String, dynamic>? externalFood,
    required String mealType,
    required double grams,
  }) async {
    try {
      final body = <String, dynamic>{
        'mealType': mealType,
        'grams': grams,
      };
      if (foodItemId != null) body['foodItemId'] = foodItemId;
      if (externalFood != null) body['externalFood'] = externalFood;

      final res = await dio.post('/food/log', data: body);
      if ((res.statusCode == 200 || res.statusCode == 201) && res.data['data'] != null) {
        return FoodLogEntry.fromJson(res.data['data'] as Map<String, dynamic>);
      }
      throw ServerException('Unexpected response from food log');
    } on DioException catch (e) {
      throw ServerException(e.response?.data?['error']?['message'] ?? 'Failed to log food');
    }
  }

  @override
  Future<FoodDiary> getDiary(String date) async {
    try {
      final res = await dio.get('/food/diary', queryParameters: {'date': date});
      if (res.statusCode == 200 && res.data['data'] != null) {
        return FoodDiary.fromJson(res.data['data'] as Map<String, dynamic>);
      }
      return FoodDiary(date: date, meals: [], totalCalories: 0, totalProtein: 0, totalCarbs: 0, totalFats: 0);
    } on DioException catch (e) {
      throw ServerException(e.response?.data?['error']?['message'] ?? 'Failed to load diary');
    }
  }

  @override
  Future<void> deleteLog(String logId) async {
    try {
      await dio.delete('/food/log/$logId');
    } on DioException catch (e) {
      throw ServerException(e.response?.data?['error']?['message'] ?? 'Failed to delete entry');
    }
  }
}
