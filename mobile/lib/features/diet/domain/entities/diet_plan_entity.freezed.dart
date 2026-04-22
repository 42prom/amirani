// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'diet_plan_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$DietPlanEntity {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  bool get isAIGenerated => throw _privateConstructorUsedError;
  bool get isActive => throw _privateConstructorUsedError;
  int get targetCalories => throw _privateConstructorUsedError;
  int get targetProtein => throw _privateConstructorUsedError;
  int get targetCarbs => throw _privateConstructorUsedError;
  int get targetFats => throw _privateConstructorUsedError;
  double get targetWater => throw _privateConstructorUsedError;
  int get numWeeks => throw _privateConstructorUsedError;
  DateTime? get startDate => throw _privateConstructorUsedError;
  List<MealEntity> get meals => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Typed goal from the backend. Null when backend hasn't sent it yet —
  /// [toMonthlyEntity] falls back to name-based inference only in that case.
  DietGoal? get goal => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $DietPlanEntityCopyWith<DietPlanEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DietPlanEntityCopyWith<$Res> {
  factory $DietPlanEntityCopyWith(
          DietPlanEntity value, $Res Function(DietPlanEntity) then) =
      _$DietPlanEntityCopyWithImpl<$Res, DietPlanEntity>;
  @useResult
  $Res call(
      {String id,
      String name,
      bool isAIGenerated,
      bool isActive,
      int targetCalories,
      int targetProtein,
      int targetCarbs,
      int targetFats,
      double targetWater,
      int numWeeks,
      DateTime? startDate,
      List<MealEntity> meals,
      DateTime createdAt,
      DietGoal? goal});
}

/// @nodoc
class _$DietPlanEntityCopyWithImpl<$Res, $Val extends DietPlanEntity>
    implements $DietPlanEntityCopyWith<$Res> {
  _$DietPlanEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? isAIGenerated = null,
    Object? isActive = null,
    Object? targetCalories = null,
    Object? targetProtein = null,
    Object? targetCarbs = null,
    Object? targetFats = null,
    Object? targetWater = null,
    Object? numWeeks = null,
    Object? startDate = freezed,
    Object? meals = null,
    Object? createdAt = null,
    Object? goal = freezed,
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
      isAIGenerated: null == isAIGenerated
          ? _value.isAIGenerated
          : isAIGenerated // ignore: cast_nullable_to_non_nullable
              as bool,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      targetCalories: null == targetCalories
          ? _value.targetCalories
          : targetCalories // ignore: cast_nullable_to_non_nullable
              as int,
      targetProtein: null == targetProtein
          ? _value.targetProtein
          : targetProtein // ignore: cast_nullable_to_non_nullable
              as int,
      targetCarbs: null == targetCarbs
          ? _value.targetCarbs
          : targetCarbs // ignore: cast_nullable_to_non_nullable
              as int,
      targetFats: null == targetFats
          ? _value.targetFats
          : targetFats // ignore: cast_nullable_to_non_nullable
              as int,
      targetWater: null == targetWater
          ? _value.targetWater
          : targetWater // ignore: cast_nullable_to_non_nullable
              as double,
      numWeeks: null == numWeeks
          ? _value.numWeeks
          : numWeeks // ignore: cast_nullable_to_non_nullable
              as int,
      startDate: freezed == startDate
          ? _value.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      meals: null == meals
          ? _value.meals
          : meals // ignore: cast_nullable_to_non_nullable
              as List<MealEntity>,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      goal: freezed == goal
          ? _value.goal
          : goal // ignore: cast_nullable_to_non_nullable
              as DietGoal?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DietPlanEntityImplCopyWith<$Res>
    implements $DietPlanEntityCopyWith<$Res> {
  factory _$$DietPlanEntityImplCopyWith(_$DietPlanEntityImpl value,
          $Res Function(_$DietPlanEntityImpl) then) =
      __$$DietPlanEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      bool isAIGenerated,
      bool isActive,
      int targetCalories,
      int targetProtein,
      int targetCarbs,
      int targetFats,
      double targetWater,
      int numWeeks,
      DateTime? startDate,
      List<MealEntity> meals,
      DateTime createdAt,
      DietGoal? goal});
}

/// @nodoc
class __$$DietPlanEntityImplCopyWithImpl<$Res>
    extends _$DietPlanEntityCopyWithImpl<$Res, _$DietPlanEntityImpl>
    implements _$$DietPlanEntityImplCopyWith<$Res> {
  __$$DietPlanEntityImplCopyWithImpl(
      _$DietPlanEntityImpl _value, $Res Function(_$DietPlanEntityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? isAIGenerated = null,
    Object? isActive = null,
    Object? targetCalories = null,
    Object? targetProtein = null,
    Object? targetCarbs = null,
    Object? targetFats = null,
    Object? targetWater = null,
    Object? numWeeks = null,
    Object? startDate = freezed,
    Object? meals = null,
    Object? createdAt = null,
    Object? goal = freezed,
  }) {
    return _then(_$DietPlanEntityImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      isAIGenerated: null == isAIGenerated
          ? _value.isAIGenerated
          : isAIGenerated // ignore: cast_nullable_to_non_nullable
              as bool,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      targetCalories: null == targetCalories
          ? _value.targetCalories
          : targetCalories // ignore: cast_nullable_to_non_nullable
              as int,
      targetProtein: null == targetProtein
          ? _value.targetProtein
          : targetProtein // ignore: cast_nullable_to_non_nullable
              as int,
      targetCarbs: null == targetCarbs
          ? _value.targetCarbs
          : targetCarbs // ignore: cast_nullable_to_non_nullable
              as int,
      targetFats: null == targetFats
          ? _value.targetFats
          : targetFats // ignore: cast_nullable_to_non_nullable
              as int,
      targetWater: null == targetWater
          ? _value.targetWater
          : targetWater // ignore: cast_nullable_to_non_nullable
              as double,
      numWeeks: null == numWeeks
          ? _value.numWeeks
          : numWeeks // ignore: cast_nullable_to_non_nullable
              as int,
      startDate: freezed == startDate
          ? _value.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      meals: null == meals
          ? _value._meals
          : meals // ignore: cast_nullable_to_non_nullable
              as List<MealEntity>,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      goal: freezed == goal
          ? _value.goal
          : goal // ignore: cast_nullable_to_non_nullable
              as DietGoal?,
    ));
  }
}

/// @nodoc

class _$DietPlanEntityImpl extends _DietPlanEntity {
  const _$DietPlanEntityImpl(
      {required this.id,
      required this.name,
      required this.isAIGenerated,
      required this.isActive,
      required this.targetCalories,
      required this.targetProtein,
      required this.targetCarbs,
      required this.targetFats,
      required this.targetWater,
      required this.numWeeks,
      this.startDate,
      required final List<MealEntity> meals,
      required this.createdAt,
      this.goal})
      : _meals = meals,
        super._();

  @override
  final String id;
  @override
  final String name;
  @override
  final bool isAIGenerated;
  @override
  final bool isActive;
  @override
  final int targetCalories;
  @override
  final int targetProtein;
  @override
  final int targetCarbs;
  @override
  final int targetFats;
  @override
  final double targetWater;
  @override
  final int numWeeks;
  @override
  final DateTime? startDate;
  final List<MealEntity> _meals;
  @override
  List<MealEntity> get meals {
    if (_meals is EqualUnmodifiableListView) return _meals;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_meals);
  }

  @override
  final DateTime createdAt;

  /// Typed goal from the backend. Null when backend hasn't sent it yet —
  /// [toMonthlyEntity] falls back to name-based inference only in that case.
  @override
  final DietGoal? goal;

  @override
  String toString() {
    return 'DietPlanEntity(id: $id, name: $name, isAIGenerated: $isAIGenerated, isActive: $isActive, targetCalories: $targetCalories, targetProtein: $targetProtein, targetCarbs: $targetCarbs, targetFats: $targetFats, targetWater: $targetWater, numWeeks: $numWeeks, startDate: $startDate, meals: $meals, createdAt: $createdAt, goal: $goal)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DietPlanEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.isAIGenerated, isAIGenerated) ||
                other.isAIGenerated == isAIGenerated) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.targetCalories, targetCalories) ||
                other.targetCalories == targetCalories) &&
            (identical(other.targetProtein, targetProtein) ||
                other.targetProtein == targetProtein) &&
            (identical(other.targetCarbs, targetCarbs) ||
                other.targetCarbs == targetCarbs) &&
            (identical(other.targetFats, targetFats) ||
                other.targetFats == targetFats) &&
            (identical(other.targetWater, targetWater) ||
                other.targetWater == targetWater) &&
            (identical(other.numWeeks, numWeeks) ||
                other.numWeeks == numWeeks) &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            const DeepCollectionEquality().equals(other._meals, _meals) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.goal, goal) || other.goal == goal));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      isAIGenerated,
      isActive,
      targetCalories,
      targetProtein,
      targetCarbs,
      targetFats,
      targetWater,
      numWeeks,
      startDate,
      const DeepCollectionEquality().hash(_meals),
      createdAt,
      goal);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$DietPlanEntityImplCopyWith<_$DietPlanEntityImpl> get copyWith =>
      __$$DietPlanEntityImplCopyWithImpl<_$DietPlanEntityImpl>(
          this, _$identity);
}

abstract class _DietPlanEntity extends DietPlanEntity {
  const factory _DietPlanEntity(
      {required final String id,
      required final String name,
      required final bool isAIGenerated,
      required final bool isActive,
      required final int targetCalories,
      required final int targetProtein,
      required final int targetCarbs,
      required final int targetFats,
      required final double targetWater,
      required final int numWeeks,
      final DateTime? startDate,
      required final List<MealEntity> meals,
      required final DateTime createdAt,
      final DietGoal? goal}) = _$DietPlanEntityImpl;
  const _DietPlanEntity._() : super._();

  @override
  String get id;
  @override
  String get name;
  @override
  bool get isAIGenerated;
  @override
  bool get isActive;
  @override
  int get targetCalories;
  @override
  int get targetProtein;
  @override
  int get targetCarbs;
  @override
  int get targetFats;
  @override
  double get targetWater;
  @override
  int get numWeeks;
  @override
  DateTime? get startDate;
  @override
  List<MealEntity> get meals;
  @override
  DateTime get createdAt;
  @override

  /// Typed goal from the backend. Null when backend hasn't sent it yet —
  /// [toMonthlyEntity] falls back to name-based inference only in that case.
  DietGoal? get goal;
  @override
  @JsonKey(ignore: true)
  _$$DietPlanEntityImplCopyWith<_$DietPlanEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
