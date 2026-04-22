import 'package:hive_flutter/hive_flutter.dart';
import '../../../auth/data/models/user_model.dart';

abstract class ProfileLocalDataSource {
  Future<void> saveProfile(UserModel user);
  Future<UserModel?> getProfile();
  Future<void> clearProfile();
}

class ProfileLocalDataSourceImpl implements ProfileLocalDataSource {
  final Box<UserModel> profileBox;

  ProfileLocalDataSourceImpl({required this.profileBox});

  @override
  Future<void> saveProfile(UserModel user) async {
    await profileBox.put('current_user', user);
  }

  @override
  Future<UserModel?> getProfile() async {
    return profileBox.get('current_user');
  }

  @override
  Future<void> clearProfile() async {
    await profileBox.delete('current_user');
  }
}
