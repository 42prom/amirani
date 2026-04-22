import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../models/dashboard_model.dart';

abstract class DashboardRemoteDataSource {
  Future<DashboardModel> getDashboardMetrics();
}

class DashboardRemoteDataSourceImpl implements DashboardRemoteDataSource {
  final Dio dio;

  DashboardRemoteDataSourceImpl({required this.dio});

  @override
  Future<DashboardModel> getDashboardMetrics() async {
    try {
      final response = await dio.get('/user/dashboard/metrics');
      return DashboardModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(e.response?.data['error'] ?? 'Server error');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }
}
