import 'package:freezed_annotation/freezed_annotation.dart';

part 'registration_requirements_entity.freezed.dart';
part 'registration_requirements_entity.g.dart';

@freezed
class RegistrationRequirementsEntity with _$RegistrationRequirementsEntity {
  const factory RegistrationRequirementsEntity({
    @Default(true) bool fullName,
    @Default(false) bool dateOfBirth,
    @Default(false) bool personalNumber,
    @Default(false) bool phoneNumber,
    @Default(false) bool address,
    @Default(false) bool selfiePhoto,
    @Default(false) bool idPhoto,
    @Default(false) bool healthInfo,
  }) = _RegistrationRequirementsEntity;

  factory RegistrationRequirementsEntity.fromJson(Map<String, dynamic> json) =>
      _$RegistrationRequirementsEntityFromJson(json);
}
