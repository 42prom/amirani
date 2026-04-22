import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';
import '../../domain/entities/user_entity.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
@HiveType(typeId: 40)
class UserModel with _$UserModel {
  const factory UserModel({
    @HiveField(0) required String id,
    @HiveField(1) required String email,
    @HiveField(2) required String role,
    @HiveField(3) String? managedGymId,
    @HiveField(4) String? phoneNumber,
    @HiveField(5) String? fullName,
    @HiveField(6) String? firstName,
    @HiveField(7) String? lastName,
    @HiveField(8) String? gender,
    @HiveField(9) String? dob,
    @HiveField(10) String? weight,
    @HiveField(11) String? height,
    @HiveField(12) String? medicalConditions,
    @HiveField(13) @Default(false) bool noMedicalConditions,
    @HiveField(14) String? personalNumber,
    @HiveField(15) String? address,
    @HiveField(16) String? avatarUrl,
    @HiveField(17) String? idPhotoUrl,
    @HiveField(18) double? targetWeightKg,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);
}

extension UserModelX on UserModel {
  UserEntity toEntity() {
    return UserEntity(
      id: id,
      email: email,
      role: role,
      managedGymId: managedGymId,
      phoneNumber: phoneNumber,
      fullName: fullName,
      firstName: firstName,
      lastName: lastName,
      gender: gender,
      dob: dob,
      weight: weight,
      height: height,
      medicalConditions: medicalConditions,
      noMedicalConditions: noMedicalConditions,
      personalNumber: personalNumber,
      address: address,
      avatarUrl: avatarUrl,
      idPhotoUrl: idPhotoUrl,
      targetWeightKg: targetWeightKg,
    );
  }
}
