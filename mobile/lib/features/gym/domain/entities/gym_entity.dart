import 'package:freezed_annotation/freezed_annotation.dart';
import 'registration_requirements_entity.dart';
import 'trainer_entity.dart';

part 'gym_entity.freezed.dart';

@freezed
class GymEntity with _$GymEntity {
  const factory GymEntity({
    required String id,
    required String name,
    required String address,
    required int currentOccupancy,
    required int maxCapacity,
    @Default([]) List<TrainerEntity> trainers,
    RegistrationRequirementsEntity? registrationRequirements,
  }) = _GymEntity;
}
