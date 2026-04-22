// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'routine_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$RoutineEntity {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  int get orderIndex => throw _privateConstructorUsedError;
  int get estimatedMinutes => throw _privateConstructorUsedError;
  int? get estimatedCaloriesBurned => throw _privateConstructorUsedError;
  DateTime? get scheduledDate => throw _privateConstructorUsedError;
  List<ExerciseEntity> get exercises => throw _privateConstructorUsedError;
  List<String> get targetMuscleGroups => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $RoutineEntityCopyWith<RoutineEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RoutineEntityCopyWith<$Res> {
  factory $RoutineEntityCopyWith(
          RoutineEntity value, $Res Function(RoutineEntity) then) =
      _$RoutineEntityCopyWithImpl<$Res, RoutineEntity>;
  @useResult
  $Res call(
      {String id,
      String name,
      int orderIndex,
      int estimatedMinutes,
      int? estimatedCaloriesBurned,
      DateTime? scheduledDate,
      List<ExerciseEntity> exercises,
      List<String> targetMuscleGroups});
}

/// @nodoc
class _$RoutineEntityCopyWithImpl<$Res, $Val extends RoutineEntity>
    implements $RoutineEntityCopyWith<$Res> {
  _$RoutineEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? orderIndex = null,
    Object? estimatedMinutes = null,
    Object? estimatedCaloriesBurned = freezed,
    Object? scheduledDate = freezed,
    Object? exercises = null,
    Object? targetMuscleGroups = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      orderIndex: null == orderIndex
          ? _value.orderIndex
          : orderIndex // ignore: cast_nullable_to_non_nullable
              as int,
      estimatedMinutes: null == estimatedMinutes
          ? _value.estimatedMinutes
          : estimatedMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      estimatedCaloriesBurned: freezed == estimatedCaloriesBurned
          ? _value.estimatedCaloriesBurned
          : estimatedCaloriesBurned // ignore: cast_nullable_to_non_nullable
              as int?,
      scheduledDate: freezed == scheduledDate
          ? _value.scheduledDate
          : scheduledDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      exercises: null == exercises
          ? _value.exercises
          : exercises // ignore: cast_nullable_to_non_nullable
              as List<ExerciseEntity>,
      targetMuscleGroups: null == targetMuscleGroups
          ? _value.targetMuscleGroups
          : targetMuscleGroups // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RoutineEntityImplCopyWith<$Res>
    implements $RoutineEntityCopyWith<$Res> {
  factory _$$RoutineEntityImplCopyWith(
          _$RoutineEntityImpl value, $Res Function(_$RoutineEntityImpl) then) =
      __$$RoutineEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      int orderIndex,
      int estimatedMinutes,
      int? estimatedCaloriesBurned,
      DateTime? scheduledDate,
      List<ExerciseEntity> exercises,
      List<String> targetMuscleGroups});
}

/// @nodoc
class __$$RoutineEntityImplCopyWithImpl<$Res>
    extends _$RoutineEntityCopyWithImpl<$Res, _$RoutineEntityImpl>
    implements _$$RoutineEntityImplCopyWith<$Res> {
  __$$RoutineEntityImplCopyWithImpl(
      _$RoutineEntityImpl _value, $Res Function(_$RoutineEntityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? orderIndex = null,
    Object? estimatedMinutes = null,
    Object? estimatedCaloriesBurned = freezed,
    Object? scheduledDate = freezed,
    Object? exercises = null,
    Object? targetMuscleGroups = null,
  }) {
    return _then(_$RoutineEntityImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      orderIndex: null == orderIndex
          ? _value.orderIndex
          : orderIndex // ignore: cast_nullable_to_non_nullable
              as int,
      estimatedMinutes: null == estimatedMinutes
          ? _value.estimatedMinutes
          : estimatedMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      estimatedCaloriesBurned: freezed == estimatedCaloriesBurned
          ? _value.estimatedCaloriesBurned
          : estimatedCaloriesBurned // ignore: cast_nullable_to_non_nullable
              as int?,
      scheduledDate: freezed == scheduledDate
          ? _value.scheduledDate
          : scheduledDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      exercises: null == exercises
          ? _value._exercises
          : exercises // ignore: cast_nullable_to_non_nullable
              as List<ExerciseEntity>,
      targetMuscleGroups: null == targetMuscleGroups
          ? _value._targetMuscleGroups
          : targetMuscleGroups // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc

class _$RoutineEntityImpl implements _RoutineEntity {
  const _$RoutineEntityImpl(
      {required this.id,
      required this.name,
      required this.orderIndex,
      required this.estimatedMinutes,
      this.estimatedCaloriesBurned,
      this.scheduledDate,
      required final List<ExerciseEntity> exercises,
      final List<String> targetMuscleGroups = const []})
      : _exercises = exercises,
        _targetMuscleGroups = targetMuscleGroups;

  @override
  final String id;
  @override
  final String name;
  @override
  final int orderIndex;
  @override
  final int estimatedMinutes;
  @override
  final int? estimatedCaloriesBurned;
  @override
  final DateTime? scheduledDate;
  final List<ExerciseEntity> _exercises;
  @override
  List<ExerciseEntity> get exercises {
    if (_exercises is EqualUnmodifiableListView) return _exercises;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_exercises);
  }

  final List<String> _targetMuscleGroups;
  @override
  @JsonKey()
  List<String> get targetMuscleGroups {
    if (_targetMuscleGroups is EqualUnmodifiableListView)
      return _targetMuscleGroups;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_targetMuscleGroups);
  }

  @override
  String toString() {
    return 'RoutineEntity(id: $id, name: $name, orderIndex: $orderIndex, estimatedMinutes: $estimatedMinutes, estimatedCaloriesBurned: $estimatedCaloriesBurned, scheduledDate: $scheduledDate, exercises: $exercises, targetMuscleGroups: $targetMuscleGroups)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RoutineEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.orderIndex, orderIndex) ||
                other.orderIndex == orderIndex) &&
            (identical(other.estimatedMinutes, estimatedMinutes) ||
                other.estimatedMinutes == estimatedMinutes) &&
            (identical(
                    other.estimatedCaloriesBurned, estimatedCaloriesBurned) ||
                other.estimatedCaloriesBurned == estimatedCaloriesBurned) &&
            (identical(other.scheduledDate, scheduledDate) ||
                other.scheduledDate == scheduledDate) &&
            const DeepCollectionEquality()
                .equals(other._exercises, _exercises) &&
            const DeepCollectionEquality()
                .equals(other._targetMuscleGroups, _targetMuscleGroups));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      orderIndex,
      estimatedMinutes,
      estimatedCaloriesBurned,
      scheduledDate,
      const DeepCollectionEquality().hash(_exercises),
      const DeepCollectionEquality().hash(_targetMuscleGroups));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$RoutineEntityImplCopyWith<_$RoutineEntityImpl> get copyWith =>
      __$$RoutineEntityImplCopyWithImpl<_$RoutineEntityImpl>(this, _$identity);
}

abstract class _RoutineEntity implements RoutineEntity {
  const factory _RoutineEntity(
      {required final String id,
      required final String name,
      required final int orderIndex,
      required final int estimatedMinutes,
      final int? estimatedCaloriesBurned,
      final DateTime? scheduledDate,
      required final List<ExerciseEntity> exercises,
      final List<String> targetMuscleGroups}) = _$RoutineEntityImpl;

  @override
  String get id;
  @override
  String get name;
  @override
  int get orderIndex;
  @override
  int get estimatedMinutes;
  @override
  int? get estimatedCaloriesBurned;
  @override
  DateTime? get scheduledDate;
  @override
  List<ExerciseEntity> get exercises;
  @override
  List<String> get targetMuscleGroups;
  @override
  @JsonKey(ignore: true)
  _$$RoutineEntityImplCopyWith<_$RoutineEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
