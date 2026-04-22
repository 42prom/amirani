import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_entity.freezed.dart';
part 'user_entity.g.dart';

@freezed
class UserEntity with _$UserEntity {
  const factory UserEntity({
    required String id,
    required String email,
    required String role,
    String? managedGymId,
    String? phoneNumber,
    String? fullName,
    String? firstName,
    String? lastName,
    String? gender,
    String? dob,
    String? weight,
    String? height,
    String? medicalConditions,
    @Default(false) bool noMedicalConditions,
    String? personalNumber,
    String? address,
    String? avatarUrl,
    String? idPhotoUrl,
    double? targetWeightKg,
  }) = _UserEntity;

  factory UserEntity.fromJson(Map<String, dynamic> json) => _$UserEntityFromJson(json);
}
