// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workout_plan_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

WorkoutPlanModel _$WorkoutPlanModelFromJson(Map<String, dynamic> json) {
  return _WorkoutPlanModel.fromJson(json);
}

/// @nodoc
mixin _$WorkoutPlanModel {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String get difficulty => throw _privateConstructorUsedError;
  bool get isAIGenerated => throw _privateConstructorUsedError;
  bool get isActive => throw _privateConstructorUsedError;
  List<RoutineModel> get routines => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $WorkoutPlanModelCopyWith<WorkoutPlanModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WorkoutPlanModelCopyWith<$Res> {
  factory $WorkoutPlanModelCopyWith(
          WorkoutPlanModel value, $Res Function(WorkoutPlanModel) then) =
      _$WorkoutPlanModelCopyWithImpl<$Res, WorkoutPlanModel>;
  @useResult
  $Res call(
      {String id,
      String name,
      String? description,
      String difficulty,
      bool isAIGenerated,
      bool isActive,
      List<RoutineModel> routines,
      DateTime createdAt});
}

/// @nodoc
class _$WorkoutPlanModelCopyWithImpl<$Res, $Val extends WorkoutPlanModel>
    implements $WorkoutPlanModelCopyWith<$Res> {
  _$WorkoutPlanModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = freezed,
    Object? difficulty = null,
    Object? isAIGenerated = null,
    Object? isActive = null,
    Object? routines = null,
    Object? createdAt = null,
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
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      difficulty: null == difficulty
          ? _value.difficulty
          : difficulty // ignore: cast_nullable_to_non_nullable
              as String,
      isAIGenerated: null == isAIGenerated
          ? _value.isAIGenerated
          : isAIGenerated // ignore: cast_nullable_to_non_nullable
              as bool,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      routines: null == routines
          ? _value.routines
          : routines // ignore: cast_nullable_to_non_nullable
              as List<RoutineModel>,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$WorkoutPlanModelImplCopyWith<$Res>
    implements $WorkoutPlanModelCopyWith<$Res> {
  factory _$$WorkoutPlanModelImplCopyWith(_$WorkoutPlanModelImpl value,
          $Res Function(_$WorkoutPlanModelImpl) then) =
      __$$WorkoutPlanModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String? description,
      String difficulty,
      bool isAIGenerated,
      bool isActive,
      List<RoutineModel> routines,
      DateTime createdAt});
}

/// @nodoc
class __$$WorkoutPlanModelImplCopyWithImpl<$Res>
    extends _$WorkoutPlanModelCopyWithImpl<$Res, _$WorkoutPlanModelImpl>
    implements _$$WorkoutPlanModelImplCopyWith<$Res> {
  __$$WorkoutPlanModelImplCopyWithImpl(_$WorkoutPlanModelImpl _value,
      $Res Function(_$WorkoutPlanModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = freezed,
    Object? difficulty = null,
    Object? isAIGenerated = null,
    Object? isActive = null,
    Object? routines = null,
    Object? createdAt = null,
  }) {
    return _then(_$WorkoutPlanModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      difficulty: null == difficulty
          ? _value.difficulty
          : difficulty // ignore: cast_nullable_to_non_nullable
              as String,
      isAIGenerated: null == isAIGenerated
          ? _value.isAIGenerated
          : isAIGenerated // ignore: cast_nullable_to_non_nullable
              as bool,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      routines: null == routines
          ? _value._routines
          : routines // ignore: cast_nullable_to_non_nullable
              as List<RoutineModel>,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$WorkoutPlanModelImpl implements _WorkoutPlanModel {
  const _$WorkoutPlanModelImpl(
      {required this.id,
      required this.name,
      this.description,
      required this.difficulty,
      required this.isAIGenerated,
      required this.isActive,
      final List<RoutineModel> routines = const [],
      required this.createdAt})
      : _routines = routines;

  factory _$WorkoutPlanModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$WorkoutPlanModelImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String? description;
  @override
  final String difficulty;
  @override
  final bool isAIGenerated;
  @override
  final bool isActive;
  final List<RoutineModel> _routines;
  @override
  @JsonKey()
  List<RoutineModel> get routines {
    if (_routines is EqualUnmodifiableListView) return _routines;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_routines);
  }

  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'WorkoutPlanModel(id: $id, name: $name, description: $description, difficulty: $difficulty, isAIGenerated: $isAIGenerated, isActive: $isActive, routines: $routines, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WorkoutPlanModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.difficulty, difficulty) ||
                other.difficulty == difficulty) &&
            (identical(other.isAIGenerated, isAIGenerated) ||
                other.isAIGenerated == isAIGenerated) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            const DeepCollectionEquality().equals(other._routines, _routines) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      description,
      difficulty,
      isAIGenerated,
      isActive,
      const DeepCollectionEquality().hash(_routines),
      createdAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$WorkoutPlanModelImplCopyWith<_$WorkoutPlanModelImpl> get copyWith =>
      __$$WorkoutPlanModelImplCopyWithImpl<_$WorkoutPlanModelImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WorkoutPlanModelImplToJson(
      this,
    );
  }
}

abstract class _WorkoutPlanModel implements WorkoutPlanModel {
  const factory _WorkoutPlanModel(
      {required final String id,
      required final String name,
      final String? description,
      required final String difficulty,
      required final bool isAIGenerated,
      required final bool isActive,
      final List<RoutineModel> routines,
      required final DateTime createdAt}) = _$WorkoutPlanModelImpl;

  factory _WorkoutPlanModel.fromJson(Map<String, dynamic> json) =
      _$WorkoutPlanModelImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String? get description;
  @override
  String get difficulty;
  @override
  bool get isAIGenerated;
  @override
  bool get isActive;
  @override
  List<RoutineModel> get routines;
  @override
  DateTime get createdAt;
  @override
  @JsonKey(ignore: true)
  _$$WorkoutPlanModelImplCopyWith<_$WorkoutPlanModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
