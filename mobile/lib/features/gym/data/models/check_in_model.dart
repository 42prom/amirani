import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/check_in_entity.dart';

part 'check_in_model.freezed.dart';
part 'check_in_model.g.dart';

@freezed
class CheckInModel with _$CheckInModel {
  const factory CheckInModel({
    required String id,
    required String gymId,
    required DateTime timestamp,
    required bool isSuccess,
    required String message,
  }) = _CheckInModel;

  factory CheckInModel.fromJson(Map<String, dynamic> json) =>
      _$CheckInModelFromJson(json);
}

extension CheckInModelX on CheckInModel {
  CheckInEntity toEntity() {
    return CheckInEntity(
      id: id,
      gymId: gymId,
      timestamp: timestamp,
      isSuccess: isSuccess,
      message: message,
    );
  }
}
