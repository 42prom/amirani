import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/trainer_entity.dart';
import '../../../../core/config/app_config.dart';

part 'trainer_model.freezed.dart';
part 'trainer_model.g.dart';

@freezed
class TrainerModel with _$TrainerModel {
  const factory TrainerModel({
    required String id,
    required String fullName,
    String? specialization,
    String? bio,
    String? avatarUrl,
    @Default(true) bool isAvailable,
  }) = _TrainerModel;

  factory TrainerModel.fromJson(Map<String, dynamic> json) =>
      _$TrainerModelFromJson(json);
}

extension TrainerModelX on TrainerModel {
  TrainerEntity toEntity() {
    return TrainerEntity(
      id: id,
      fullName: fullName,
      specialization: specialization,
      bio: bio,
      avatarUrl: AppConfig.resolveMediaUrl(avatarUrl),
      isAvailable: isAvailable,
    );
  }
}
