import 'package:freezed_annotation/freezed_annotation.dart';

part 'trainer_entity.freezed.dart';

@freezed
class TrainerEntity with _$TrainerEntity {
  const factory TrainerEntity({
    required String id,
    required String fullName,
    String? specialization,
    String? bio,
    String? avatarUrl,
    @Default(true) bool isAvailable,
  }) = _TrainerEntity;
}
