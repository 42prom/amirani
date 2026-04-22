// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'meal_reminder_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$MealReminderEntity {
  String get id => throw _privateConstructorUsedError;
  String get odUserId => throw _privateConstructorUsedError;
  MealType get mealType => throw _privateConstructorUsedError;
  String get mealName => throw _privateConstructorUsedError;
  DateTime get scheduledTime => throw _privateConstructorUsedError;
  int get calories => throw _privateConstructorUsedError;
  ReminderStatus get status => throw _privateConstructorUsedError;
  int? get notificationId =>
      throw _privateConstructorUsedError; // For canceling
  String? get mealId => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $MealReminderEntityCopyWith<MealReminderEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MealReminderEntityCopyWith<$Res> {
  factory $MealReminderEntityCopyWith(
          MealReminderEntity value, $Res Function(MealReminderEntity) then) =
      _$MealReminderEntityCopyWithImpl<$Res, MealReminderEntity>;
  @useResult
  $Res call(
      {String id,
      String odUserId,
      MealType mealType,
      String mealName,
      DateTime scheduledTime,
      int calories,
      ReminderStatus status,
      int? notificationId,
      String? mealId});
}

/// @nodoc
class _$MealReminderEntityCopyWithImpl<$Res, $Val extends MealReminderEntity>
    implements $MealReminderEntityCopyWith<$Res> {
  _$MealReminderEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? odUserId = null,
    Object? mealType = null,
    Object? mealName = null,
    Object? scheduledTime = null,
    Object? calories = null,
    Object? status = null,
    Object? notificationId = freezed,
    Object? mealId = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      odUserId: null == odUserId
          ? _value.odUserId
          : odUserId // ignore: cast_nullable_to_non_nullable
              as String,
      mealType: null == mealType
          ? _value.mealType
          : mealType // ignore: cast_nullable_to_non_nullable
              as MealType,
      mealName: null == mealName
          ? _value.mealName
          : mealName // ignore: cast_nullable_to_non_nullable
              as String,
      scheduledTime: null == scheduledTime
          ? _value.scheduledTime
          : scheduledTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      calories: null == calories
          ? _value.calories
          : calories // ignore: cast_nullable_to_non_nullable
              as int,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as ReminderStatus,
      notificationId: freezed == notificationId
          ? _value.notificationId
          : notificationId // ignore: cast_nullable_to_non_nullable
              as int?,
      mealId: freezed == mealId
          ? _value.mealId
          : mealId // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MealReminderEntityImplCopyWith<$Res>
    implements $MealReminderEntityCopyWith<$Res> {
  factory _$$MealReminderEntityImplCopyWith(_$MealReminderEntityImpl value,
          $Res Function(_$MealReminderEntityImpl) then) =
      __$$MealReminderEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String odUserId,
      MealType mealType,
      String mealName,
      DateTime scheduledTime,
      int calories,
      ReminderStatus status,
      int? notificationId,
      String? mealId});
}

/// @nodoc
class __$$MealReminderEntityImplCopyWithImpl<$Res>
    extends _$MealReminderEntityCopyWithImpl<$Res, _$MealReminderEntityImpl>
    implements _$$MealReminderEntityImplCopyWith<$Res> {
  __$$MealReminderEntityImplCopyWithImpl(_$MealReminderEntityImpl _value,
      $Res Function(_$MealReminderEntityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? odUserId = null,
    Object? mealType = null,
    Object? mealName = null,
    Object? scheduledTime = null,
    Object? calories = null,
    Object? status = null,
    Object? notificationId = freezed,
    Object? mealId = freezed,
  }) {
    return _then(_$MealReminderEntityImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      odUserId: null == odUserId
          ? _value.odUserId
          : odUserId // ignore: cast_nullable_to_non_nullable
              as String,
      mealType: null == mealType
          ? _value.mealType
          : mealType // ignore: cast_nullable_to_non_nullable
              as MealType,
      mealName: null == mealName
          ? _value.mealName
          : mealName // ignore: cast_nullable_to_non_nullable
              as String,
      scheduledTime: null == scheduledTime
          ? _value.scheduledTime
          : scheduledTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      calories: null == calories
          ? _value.calories
          : calories // ignore: cast_nullable_to_non_nullable
              as int,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as ReminderStatus,
      notificationId: freezed == notificationId
          ? _value.notificationId
          : notificationId // ignore: cast_nullable_to_non_nullable
              as int?,
      mealId: freezed == mealId
          ? _value.mealId
          : mealId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$MealReminderEntityImpl implements _MealReminderEntity {
  const _$MealReminderEntityImpl(
      {required this.id,
      required this.odUserId,
      required this.mealType,
      required this.mealName,
      required this.scheduledTime,
      required this.calories,
      this.status = ReminderStatus.scheduled,
      this.notificationId,
      this.mealId});

  @override
  final String id;
  @override
  final String odUserId;
  @override
  final MealType mealType;
  @override
  final String mealName;
  @override
  final DateTime scheduledTime;
  @override
  final int calories;
  @override
  @JsonKey()
  final ReminderStatus status;
  @override
  final int? notificationId;
// For canceling
  @override
  final String? mealId;

  @override
  String toString() {
    return 'MealReminderEntity(id: $id, odUserId: $odUserId, mealType: $mealType, mealName: $mealName, scheduledTime: $scheduledTime, calories: $calories, status: $status, notificationId: $notificationId, mealId: $mealId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MealReminderEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.odUserId, odUserId) ||
                other.odUserId == odUserId) &&
            (identical(other.mealType, mealType) ||
                other.mealType == mealType) &&
            (identical(other.mealName, mealName) ||
                other.mealName == mealName) &&
            (identical(other.scheduledTime, scheduledTime) ||
                other.scheduledTime == scheduledTime) &&
            (identical(other.calories, calories) ||
                other.calories == calories) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.notificationId, notificationId) ||
                other.notificationId == notificationId) &&
            (identical(other.mealId, mealId) || other.mealId == mealId));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, odUserId, mealType, mealName,
      scheduledTime, calories, status, notificationId, mealId);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$MealReminderEntityImplCopyWith<_$MealReminderEntityImpl> get copyWith =>
      __$$MealReminderEntityImplCopyWithImpl<_$MealReminderEntityImpl>(
          this, _$identity);
}

abstract class _MealReminderEntity implements MealReminderEntity {
  const factory _MealReminderEntity(
      {required final String id,
      required final String odUserId,
      required final MealType mealType,
      required final String mealName,
      required final DateTime scheduledTime,
      required final int calories,
      final ReminderStatus status,
      final int? notificationId,
      final String? mealId}) = _$MealReminderEntityImpl;

  @override
  String get id;
  @override
  String get odUserId;
  @override
  MealType get mealType;
  @override
  String get mealName;
  @override
  DateTime get scheduledTime;
  @override
  int get calories;
  @override
  ReminderStatus get status;
  @override
  int? get notificationId;
  @override // For canceling
  String? get mealId;
  @override
  @JsonKey(ignore: true)
  _$$MealReminderEntityImplCopyWith<_$MealReminderEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$MealReminderSettingsEntity {
  bool get enabled => throw _privateConstructorUsedError;
  int get minutesBefore =>
      throw _privateConstructorUsedError; // Remind X minutes before meal time
  bool get breakfastReminder => throw _privateConstructorUsedError;
  bool get lunchReminder => throw _privateConstructorUsedError;
  bool get dinnerReminder => throw _privateConstructorUsedError;
  bool get morningSnackReminder => throw _privateConstructorUsedError;
  bool get afternoonSnackReminder => throw _privateConstructorUsedError;
  String? get breakfastTime => throw _privateConstructorUsedError; // "08:00"
  String? get lunchTime => throw _privateConstructorUsedError; // "12:30"
  String? get dinnerTime => throw _privateConstructorUsedError; // "19:00"
  String? get morningSnackTime => throw _privateConstructorUsedError; // "10:30"
  String? get afternoonSnackTime => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $MealReminderSettingsEntityCopyWith<MealReminderSettingsEntity>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MealReminderSettingsEntityCopyWith<$Res> {
  factory $MealReminderSettingsEntityCopyWith(MealReminderSettingsEntity value,
          $Res Function(MealReminderSettingsEntity) then) =
      _$MealReminderSettingsEntityCopyWithImpl<$Res,
          MealReminderSettingsEntity>;
  @useResult
  $Res call(
      {bool enabled,
      int minutesBefore,
      bool breakfastReminder,
      bool lunchReminder,
      bool dinnerReminder,
      bool morningSnackReminder,
      bool afternoonSnackReminder,
      String? breakfastTime,
      String? lunchTime,
      String? dinnerTime,
      String? morningSnackTime,
      String? afternoonSnackTime});
}

/// @nodoc
class _$MealReminderSettingsEntityCopyWithImpl<$Res,
        $Val extends MealReminderSettingsEntity>
    implements $MealReminderSettingsEntityCopyWith<$Res> {
  _$MealReminderSettingsEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? enabled = null,
    Object? minutesBefore = null,
    Object? breakfastReminder = null,
    Object? lunchReminder = null,
    Object? dinnerReminder = null,
    Object? morningSnackReminder = null,
    Object? afternoonSnackReminder = null,
    Object? breakfastTime = freezed,
    Object? lunchTime = freezed,
    Object? dinnerTime = freezed,
    Object? morningSnackTime = freezed,
    Object? afternoonSnackTime = freezed,
  }) {
    return _then(_value.copyWith(
      enabled: null == enabled
          ? _value.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      minutesBefore: null == minutesBefore
          ? _value.minutesBefore
          : minutesBefore // ignore: cast_nullable_to_non_nullable
              as int,
      breakfastReminder: null == breakfastReminder
          ? _value.breakfastReminder
          : breakfastReminder // ignore: cast_nullable_to_non_nullable
              as bool,
      lunchReminder: null == lunchReminder
          ? _value.lunchReminder
          : lunchReminder // ignore: cast_nullable_to_non_nullable
              as bool,
      dinnerReminder: null == dinnerReminder
          ? _value.dinnerReminder
          : dinnerReminder // ignore: cast_nullable_to_non_nullable
              as bool,
      morningSnackReminder: null == morningSnackReminder
          ? _value.morningSnackReminder
          : morningSnackReminder // ignore: cast_nullable_to_non_nullable
              as bool,
      afternoonSnackReminder: null == afternoonSnackReminder
          ? _value.afternoonSnackReminder
          : afternoonSnackReminder // ignore: cast_nullable_to_non_nullable
              as bool,
      breakfastTime: freezed == breakfastTime
          ? _value.breakfastTime
          : breakfastTime // ignore: cast_nullable_to_non_nullable
              as String?,
      lunchTime: freezed == lunchTime
          ? _value.lunchTime
          : lunchTime // ignore: cast_nullable_to_non_nullable
              as String?,
      dinnerTime: freezed == dinnerTime
          ? _value.dinnerTime
          : dinnerTime // ignore: cast_nullable_to_non_nullable
              as String?,
      morningSnackTime: freezed == morningSnackTime
          ? _value.morningSnackTime
          : morningSnackTime // ignore: cast_nullable_to_non_nullable
              as String?,
      afternoonSnackTime: freezed == afternoonSnackTime
          ? _value.afternoonSnackTime
          : afternoonSnackTime // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MealReminderSettingsEntityImplCopyWith<$Res>
    implements $MealReminderSettingsEntityCopyWith<$Res> {
  factory _$$MealReminderSettingsEntityImplCopyWith(
          _$MealReminderSettingsEntityImpl value,
          $Res Function(_$MealReminderSettingsEntityImpl) then) =
      __$$MealReminderSettingsEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool enabled,
      int minutesBefore,
      bool breakfastReminder,
      bool lunchReminder,
      bool dinnerReminder,
      bool morningSnackReminder,
      bool afternoonSnackReminder,
      String? breakfastTime,
      String? lunchTime,
      String? dinnerTime,
      String? morningSnackTime,
      String? afternoonSnackTime});
}

/// @nodoc
class __$$MealReminderSettingsEntityImplCopyWithImpl<$Res>
    extends _$MealReminderSettingsEntityCopyWithImpl<$Res,
        _$MealReminderSettingsEntityImpl>
    implements _$$MealReminderSettingsEntityImplCopyWith<$Res> {
  __$$MealReminderSettingsEntityImplCopyWithImpl(
      _$MealReminderSettingsEntityImpl _value,
      $Res Function(_$MealReminderSettingsEntityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? enabled = null,
    Object? minutesBefore = null,
    Object? breakfastReminder = null,
    Object? lunchReminder = null,
    Object? dinnerReminder = null,
    Object? morningSnackReminder = null,
    Object? afternoonSnackReminder = null,
    Object? breakfastTime = freezed,
    Object? lunchTime = freezed,
    Object? dinnerTime = freezed,
    Object? morningSnackTime = freezed,
    Object? afternoonSnackTime = freezed,
  }) {
    return _then(_$MealReminderSettingsEntityImpl(
      enabled: null == enabled
          ? _value.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      minutesBefore: null == minutesBefore
          ? _value.minutesBefore
          : minutesBefore // ignore: cast_nullable_to_non_nullable
              as int,
      breakfastReminder: null == breakfastReminder
          ? _value.breakfastReminder
          : breakfastReminder // ignore: cast_nullable_to_non_nullable
              as bool,
      lunchReminder: null == lunchReminder
          ? _value.lunchReminder
          : lunchReminder // ignore: cast_nullable_to_non_nullable
              as bool,
      dinnerReminder: null == dinnerReminder
          ? _value.dinnerReminder
          : dinnerReminder // ignore: cast_nullable_to_non_nullable
              as bool,
      morningSnackReminder: null == morningSnackReminder
          ? _value.morningSnackReminder
          : morningSnackReminder // ignore: cast_nullable_to_non_nullable
              as bool,
      afternoonSnackReminder: null == afternoonSnackReminder
          ? _value.afternoonSnackReminder
          : afternoonSnackReminder // ignore: cast_nullable_to_non_nullable
              as bool,
      breakfastTime: freezed == breakfastTime
          ? _value.breakfastTime
          : breakfastTime // ignore: cast_nullable_to_non_nullable
              as String?,
      lunchTime: freezed == lunchTime
          ? _value.lunchTime
          : lunchTime // ignore: cast_nullable_to_non_nullable
              as String?,
      dinnerTime: freezed == dinnerTime
          ? _value.dinnerTime
          : dinnerTime // ignore: cast_nullable_to_non_nullable
              as String?,
      morningSnackTime: freezed == morningSnackTime
          ? _value.morningSnackTime
          : morningSnackTime // ignore: cast_nullable_to_non_nullable
              as String?,
      afternoonSnackTime: freezed == afternoonSnackTime
          ? _value.afternoonSnackTime
          : afternoonSnackTime // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$MealReminderSettingsEntityImpl extends _MealReminderSettingsEntity {
  const _$MealReminderSettingsEntityImpl(
      {this.enabled = true,
      this.minutesBefore = 15,
      this.breakfastReminder = true,
      this.lunchReminder = true,
      this.dinnerReminder = true,
      this.morningSnackReminder = false,
      this.afternoonSnackReminder = false,
      this.breakfastTime,
      this.lunchTime,
      this.dinnerTime,
      this.morningSnackTime,
      this.afternoonSnackTime})
      : super._();

  @override
  @JsonKey()
  final bool enabled;
  @override
  @JsonKey()
  final int minutesBefore;
// Remind X minutes before meal time
  @override
  @JsonKey()
  final bool breakfastReminder;
  @override
  @JsonKey()
  final bool lunchReminder;
  @override
  @JsonKey()
  final bool dinnerReminder;
  @override
  @JsonKey()
  final bool morningSnackReminder;
  @override
  @JsonKey()
  final bool afternoonSnackReminder;
  @override
  final String? breakfastTime;
// "08:00"
  @override
  final String? lunchTime;
// "12:30"
  @override
  final String? dinnerTime;
// "19:00"
  @override
  final String? morningSnackTime;
// "10:30"
  @override
  final String? afternoonSnackTime;

  @override
  String toString() {
    return 'MealReminderSettingsEntity(enabled: $enabled, minutesBefore: $minutesBefore, breakfastReminder: $breakfastReminder, lunchReminder: $lunchReminder, dinnerReminder: $dinnerReminder, morningSnackReminder: $morningSnackReminder, afternoonSnackReminder: $afternoonSnackReminder, breakfastTime: $breakfastTime, lunchTime: $lunchTime, dinnerTime: $dinnerTime, morningSnackTime: $morningSnackTime, afternoonSnackTime: $afternoonSnackTime)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MealReminderSettingsEntityImpl &&
            (identical(other.enabled, enabled) || other.enabled == enabled) &&
            (identical(other.minutesBefore, minutesBefore) ||
                other.minutesBefore == minutesBefore) &&
            (identical(other.breakfastReminder, breakfastReminder) ||
                other.breakfastReminder == breakfastReminder) &&
            (identical(other.lunchReminder, lunchReminder) ||
                other.lunchReminder == lunchReminder) &&
            (identical(other.dinnerReminder, dinnerReminder) ||
                other.dinnerReminder == dinnerReminder) &&
            (identical(other.morningSnackReminder, morningSnackReminder) ||
                other.morningSnackReminder == morningSnackReminder) &&
            (identical(other.afternoonSnackReminder, afternoonSnackReminder) ||
                other.afternoonSnackReminder == afternoonSnackReminder) &&
            (identical(other.breakfastTime, breakfastTime) ||
                other.breakfastTime == breakfastTime) &&
            (identical(other.lunchTime, lunchTime) ||
                other.lunchTime == lunchTime) &&
            (identical(other.dinnerTime, dinnerTime) ||
                other.dinnerTime == dinnerTime) &&
            (identical(other.morningSnackTime, morningSnackTime) ||
                other.morningSnackTime == morningSnackTime) &&
            (identical(other.afternoonSnackTime, afternoonSnackTime) ||
                other.afternoonSnackTime == afternoonSnackTime));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      enabled,
      minutesBefore,
      breakfastReminder,
      lunchReminder,
      dinnerReminder,
      morningSnackReminder,
      afternoonSnackReminder,
      breakfastTime,
      lunchTime,
      dinnerTime,
      morningSnackTime,
      afternoonSnackTime);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$MealReminderSettingsEntityImplCopyWith<_$MealReminderSettingsEntityImpl>
      get copyWith => __$$MealReminderSettingsEntityImplCopyWithImpl<
          _$MealReminderSettingsEntityImpl>(this, _$identity);
}

abstract class _MealReminderSettingsEntity extends MealReminderSettingsEntity {
  const factory _MealReminderSettingsEntity(
      {final bool enabled,
      final int minutesBefore,
      final bool breakfastReminder,
      final bool lunchReminder,
      final bool dinnerReminder,
      final bool morningSnackReminder,
      final bool afternoonSnackReminder,
      final String? breakfastTime,
      final String? lunchTime,
      final String? dinnerTime,
      final String? morningSnackTime,
      final String? afternoonSnackTime}) = _$MealReminderSettingsEntityImpl;
  const _MealReminderSettingsEntity._() : super._();

  @override
  bool get enabled;
  @override
  int get minutesBefore;
  @override // Remind X minutes before meal time
  bool get breakfastReminder;
  @override
  bool get lunchReminder;
  @override
  bool get dinnerReminder;
  @override
  bool get morningSnackReminder;
  @override
  bool get afternoonSnackReminder;
  @override
  String? get breakfastTime;
  @override // "08:00"
  String? get lunchTime;
  @override // "12:30"
  String? get dinnerTime;
  @override // "19:00"
  String? get morningSnackTime;
  @override // "10:30"
  String? get afternoonSnackTime;
  @override
  @JsonKey(ignore: true)
  _$$MealReminderSettingsEntityImplCopyWith<_$MealReminderSettingsEntityImpl>
      get copyWith => throw _privateConstructorUsedError;
}
