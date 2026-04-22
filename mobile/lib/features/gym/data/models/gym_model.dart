import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/gym_entity.dart';
import '../../domain/entities/registration_requirements_entity.dart';
import 'trainer_model.dart';

part 'gym_model.freezed.dart';
part 'gym_model.g.dart';

@freezed
class GymModel with _$GymModel {
  const factory GymModel({
    required String id,
    required String name,
    required String address,
    required int currentOccupancy,
    required int maxCapacity,
    @Default([]) List<TrainerModel> trainers,
    RegistrationRequirementsEntity? registrationRequirements,
  }) = _GymModel;

  factory GymModel.fromJson(Map<String, dynamic> json) =>
      _$GymModelFromJson(json);
}

extension GymModelX on GymModel {
  GymEntity toEntity() {
    return GymEntity(
      id: id,
      name: name,
      address: address,
      currentOccupancy: currentOccupancy,
      maxCapacity: maxCapacity,
      trainers: trainers.map((t) => t.toEntity()).toList(),
      registrationRequirements: registrationRequirements,
    );
  }
}
