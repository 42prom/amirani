import 'package:freezed_annotation/freezed_annotation.dart';

part 'check_in_entity.freezed.dart';

@freezed
class CheckInEntity with _$CheckInEntity {
  const factory CheckInEntity({
    required String id,
    required String gymId,
    required DateTime timestamp,
    required bool isSuccess,
    required String message,
  }) = _CheckInEntity;
}
