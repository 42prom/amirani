// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'meal_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$MealEntity {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  int get calories => throw _privateConstructorUsedError;
  int get protein => throw _privateConstructorUsedError;
  int get carbs => throw _privateConstructorUsedError;
  int get fats => throw _privateConstructorUsedError;
  DateTime? get scheduledDate => throw _privateConstructorUsedError;
  String? get type => throw _privateConstructorUsedError;
  String? get timeOfDay => throw _privateConstructorUsedError;
  String? get instructions => throw _privateConstructorUsedError;
  List<MealIngredientEntity>? get ingredients =>
      throw _privateConstructorUsedError;
  String? get heroIngredient => throw _privateConstructorUsedError;
  String? get ingredientSummary => throw _privateConstructorUsedError;
  int? get orderIndex => throw _privateConstructorUsedError;
  String? get mediaUrl => throw _privateConstructorUsedError;
  DateTime get timestamp =>
      throw _privateConstructorUsedError; // P1-D: per-rotation-day macro targets (null = use plan-level average)
  int? get dayTargetCalories => throw _privateConstructorUsedError;
  int? get dayTargetProtein => throw _privateConstructorUsedError;
  int? get dayTargetCarbs => throw _privateConstructorUsedError;
  int? get dayTargetFats => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $MealEntityCopyWith<MealEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MealEntityCopyWith<$Res> {
  factory $MealEntityCopyWith(
          MealEntity value, $Res Function(MealEntity) then) =
      _$MealEntityCopyWithImpl<$Res, MealEntity>;
  @useResult
  $Res call(
      {String id,
      String name,
      int calories,
      int protein,
      int carbs,
      int fats,
      DateTime? scheduledDate,
      String? type,
      String? timeOfDay,
      String? instructions,
      List<MealIngredientEntity>? ingredients,
      String? heroIngredient,
      String? ingredientSummary,
      int? orderIndex,
      String? mediaUrl,
      DateTime timestamp,
      int? dayTargetCalories,
      int? dayTargetProtein,
      int? dayTargetCarbs,
      int? dayTargetFats});
}

/// @nodoc
class _$MealEntityCopyWithImpl<$Res, $Val extends MealEntity>
    implements $MealEntityCopyWith<$Res> {
  _$MealEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? calories = null,
    Object? protein = null,
    Object? carbs = null,
    Object? fats = null,
    Object? scheduledDate = freezed,
    Object? type = freezed,
    Object? timeOfDay = freezed,
    Object? instructions = freezed,
    Object? ingredients = freezed,
    Object? heroIngredient = freezed,
    Object? ingredientSummary = freezed,
    Object? orderIndex = freezed,
    Object? mediaUrl = freezed,
    Object? timestamp = null,
    Object? dayTargetCalories = freezed,
    Object? dayTargetProtein = freezed,
    Object? dayTargetCarbs = freezed,
    Object? dayTargetFats = freezed,
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
      calories: null == calories
          ? _value.calories
          : calories // ignore: cast_nullable_to_non_nullable
              as int,
      protein: null == protein
          ? _value.protein
          : protein // ignore: cast_nullable_to_non_nullable
              as int,
      carbs: null == carbs
          ? _value.carbs
          : carbs // ignore: cast_nullable_to_non_nullable
              as int,
      fats: null == fats
          ? _value.fats
          : fats // ignore: cast_nullable_to_non_nullable
              as int,
      scheduledDate: freezed == scheduledDate
          ? _value.scheduledDate
          : scheduledDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      type: freezed == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String?,
      timeOfDay: freezed == timeOfDay
          ? _value.timeOfDay
          : timeOfDay // ignore: cast_nullable_to_non_nullable
              as String?,
      instructions: freezed == instructions
          ? _value.instructions
          : instructions // ignore: cast_nullable_to_non_nullable
              as String?,
      ingredients: freezed == ingredients
          ? _value.ingredients
          : ingredients // ignore: cast_nullable_to_non_nullable
              as List<MealIngredientEntity>?,
      heroIngredient: freezed == heroIngredient
          ? _value.heroIngredient
          : heroIngredient // ignore: cast_nullable_to_non_nullable
              as String?,
      ingredientSummary: freezed == ingredientSummary
          ? _value.ingredientSummary
          : ingredientSummary // ignore: cast_nullable_to_non_nullable
              as String?,
      orderIndex: freezed == orderIndex
          ? _value.orderIndex
          : orderIndex // ignore: cast_nullable_to_non_nullable
              as int?,
      mediaUrl: freezed == mediaUrl
          ? _value.mediaUrl
          : mediaUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dayTargetCalories: freezed == dayTargetCalories
          ? _value.dayTargetCalories
          : dayTargetCalories // ignore: cast_nullable_to_non_nullable
              as int?,
      dayTargetProtein: freezed == dayTargetProtein
          ? _value.dayTargetProtein
          : dayTargetProtein // ignore: cast_nullable_to_non_nullable
              as int?,
      dayTargetCarbs: freezed == dayTargetCarbs
          ? _value.dayTargetCarbs
          : dayTargetCarbs // ignore: cast_nullable_to_non_nullable
              as int?,
      dayTargetFats: freezed == dayTargetFats
          ? _value.dayTargetFats
          : dayTargetFats // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MealEntityImplCopyWith<$Res>
    implements $MealEntityCopyWith<$Res> {
  factory _$$MealEntityImplCopyWith(
          _$MealEntityImpl value, $Res Function(_$MealEntityImpl) then) =
      __$$MealEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      int calories,
      int protein,
      int carbs,
      int fats,
      DateTime? scheduledDate,
      String? type,
      String? timeOfDay,
      String? instructions,
      List<MealIngredientEntity>? ingredients,
      String? heroIngredient,
      String? ingredientSummary,
      int? orderIndex,
      String? mediaUrl,
      DateTime timestamp,
      int? dayTargetCalories,
      int? dayTargetProtein,
      int? dayTargetCarbs,
      int? dayTargetFats});
}

/// @nodoc
class __$$MealEntityImplCopyWithImpl<$Res>
    extends _$MealEntityCopyWithImpl<$Res, _$MealEntityImpl>
    implements _$$MealEntityImplCopyWith<$Res> {
  __$$MealEntityImplCopyWithImpl(
      _$MealEntityImpl _value, $Res Function(_$MealEntityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? calories = null,
    Object? protein = null,
    Object? carbs = null,
    Object? fats = null,
    Object? scheduledDate = freezed,
    Object? type = freezed,
    Object? timeOfDay = freezed,
    Object? instructions = freezed,
    Object? ingredients = freezed,
    Object? heroIngredient = freezed,
    Object? ingredientSummary = freezed,
    Object? orderIndex = freezed,
    Object? mediaUrl = freezed,
    Object? timestamp = null,
    Object? dayTargetCalories = freezed,
    Object? dayTargetProtein = freezed,
    Object? dayTargetCarbs = freezed,
    Object? dayTargetFats = freezed,
  }) {
    return _then(_$MealEntityImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      calories: null == calories
          ? _value.calories
          : calories // ignore: cast_nullable_to_non_nullable
              as int,
      protein: null == protein
          ? _value.protein
          : protein // ignore: cast_nullable_to_non_nullable
              as int,
      carbs: null == carbs
          ? _value.carbs
          : carbs // ignore: cast_nullable_to_non_nullable
              as int,
      fats: null == fats
          ? _value.fats
          : fats // ignore: cast_nullable_to_non_nullable
              as int,
      scheduledDate: freezed == scheduledDate
          ? _value.scheduledDate
          : scheduledDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      type: freezed == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String?,
      timeOfDay: freezed == timeOfDay
          ? _value.timeOfDay
          : timeOfDay // ignore: cast_nullable_to_non_nullable
              as String?,
      instructions: freezed == instructions
          ? _value.instructions
          : instructions // ignore: cast_nullable_to_non_nullable
              as String?,
      ingredients: freezed == ingredients
          ? _value._ingredients
          : ingredients // ignore: cast_nullable_to_non_nullable
              as List<MealIngredientEntity>?,
      heroIngredient: freezed == heroIngredient
          ? _value.heroIngredient
          : heroIngredient // ignore: cast_nullable_to_non_nullable
              as String?,
      ingredientSummary: freezed == ingredientSummary
          ? _value.ingredientSummary
          : ingredientSummary // ignore: cast_nullable_to_non_nullable
              as String?,
      orderIndex: freezed == orderIndex
          ? _value.orderIndex
          : orderIndex // ignore: cast_nullable_to_non_nullable
              as int?,
      mediaUrl: freezed == mediaUrl
          ? _value.mediaUrl
          : mediaUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      dayTargetCalories: freezed == dayTargetCalories
          ? _value.dayTargetCalories
          : dayTargetCalories // ignore: cast_nullable_to_non_nullable
              as int?,
      dayTargetProtein: freezed == dayTargetProtein
          ? _value.dayTargetProtein
          : dayTargetProtein // ignore: cast_nullable_to_non_nullable
              as int?,
      dayTargetCarbs: freezed == dayTargetCarbs
          ? _value.dayTargetCarbs
          : dayTargetCarbs // ignore: cast_nullable_to_non_nullable
              as int?,
      dayTargetFats: freezed == dayTargetFats
          ? _value.dayTargetFats
          : dayTargetFats // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc

class _$MealEntityImpl implements _MealEntity {
  const _$MealEntityImpl(
      {required this.id,
      required this.name,
      required this.calories,
      required this.protein,
      required this.carbs,
      required this.fats,
      this.scheduledDate,
      this.type,
      this.timeOfDay,
      this.instructions,
      final List<MealIngredientEntity>? ingredients,
      this.heroIngredient,
      this.ingredientSummary,
      this.orderIndex,
      this.mediaUrl,
      required this.timestamp,
      this.dayTargetCalories,
      this.dayTargetProtein,
      this.dayTargetCarbs,
      this.dayTargetFats})
      : _ingredients = ingredients;

  @override
  final String id;
  @override
  final String name;
  @override
  final int calories;
  @override
  final int protein;
  @override
  final int carbs;
  @override
  final int fats;
  @override
  final DateTime? scheduledDate;
  @override
  final String? type;
  @override
  final String? timeOfDay;
  @override
  final String? instructions;
  final List<MealIngredientEntity>? _ingredients;
  @override
  List<MealIngredientEntity>? get ingredients {
    final value = _ingredients;
    if (value == null) return null;
    if (_ingredients is EqualUnmodifiableListView) return _ingredients;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final String? heroIngredient;
  @override
  final String? ingredientSummary;
  @override
  final int? orderIndex;
  @override
  final String? mediaUrl;
  @override
  final DateTime timestamp;
// P1-D: per-rotation-day macro targets (null = use plan-level average)
  @override
  final int? dayTargetCalories;
  @override
  final int? dayTargetProtein;
  @override
  final int? dayTargetCarbs;
  @override
  final int? dayTargetFats;

  @override
  String toString() {
    return 'MealEntity(id: $id, name: $name, calories: $calories, protein: $protein, carbs: $carbs, fats: $fats, scheduledDate: $scheduledDate, type: $type, timeOfDay: $timeOfDay, instructions: $instructions, ingredients: $ingredients, heroIngredient: $heroIngredient, ingredientSummary: $ingredientSummary, orderIndex: $orderIndex, mediaUrl: $mediaUrl, timestamp: $timestamp, dayTargetCalories: $dayTargetCalories, dayTargetProtein: $dayTargetProtein, dayTargetCarbs: $dayTargetCarbs, dayTargetFats: $dayTargetFats)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MealEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.calories, calories) ||
                other.calories == calories) &&
            (identical(other.protein, protein) || other.protein == protein) &&
            (identical(other.carbs, carbs) || other.carbs == carbs) &&
            (identical(other.fats, fats) || other.fats == fats) &&
            (identical(other.scheduledDate, scheduledDate) ||
                other.scheduledDate == scheduledDate) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.timeOfDay, timeOfDay) ||
                other.timeOfDay == timeOfDay) &&
            (identical(other.instructions, instructions) ||
                other.instructions == instructions) &&
            const DeepCollectionEquality()
                .equals(other._ingredients, _ingredients) &&
            (identical(other.heroIngredient, heroIngredient) ||
                other.heroIngredient == heroIngredient) &&
            (identical(other.ingredientSummary, ingredientSummary) ||
                other.ingredientSummary == ingredientSummary) &&
            (identical(other.orderIndex, orderIndex) ||
                other.orderIndex == orderIndex) &&
            (identical(other.mediaUrl, mediaUrl) ||
                other.mediaUrl == mediaUrl) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.dayTargetCalories, dayTargetCalories) ||
                other.dayTargetCalories == dayTargetCalories) &&
            (identical(other.dayTargetProtein, dayTargetProtein) ||
                other.dayTargetProtein == dayTargetProtein) &&
            (identical(other.dayTargetCarbs, dayTargetCarbs) ||
                other.dayTargetCarbs == dayTargetCarbs) &&
            (identical(other.dayTargetFats, dayTargetFats) ||
                other.dayTargetFats == dayTargetFats));
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        name,
        calories,
        protein,
        carbs,
        fats,
        scheduledDate,
        type,
        timeOfDay,
        instructions,
        const DeepCollectionEquality().hash(_ingredients),
        heroIngredient,
        ingredientSummary,
        orderIndex,
        mediaUrl,
        timestamp,
        dayTargetCalories,
        dayTargetProtein,
        dayTargetCarbs,
        dayTargetFats
      ]);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$MealEntityImplCopyWith<_$MealEntityImpl> get copyWith =>
      __$$MealEntityImplCopyWithImpl<_$MealEntityImpl>(this, _$identity);
}

abstract class _MealEntity implements MealEntity {
  const factory _MealEntity(
      {required final String id,
      required final String name,
      required final int calories,
      required final int protein,
      required final int carbs,
      required final int fats,
      final DateTime? scheduledDate,
      final String? type,
      final String? timeOfDay,
      final String? instructions,
      final List<MealIngredientEntity>? ingredients,
      final String? heroIngredient,
      final String? ingredientSummary,
      final int? orderIndex,
      final String? mediaUrl,
      required final DateTime timestamp,
      final int? dayTargetCalories,
      final int? dayTargetProtein,
      final int? dayTargetCarbs,
      final int? dayTargetFats}) = _$MealEntityImpl;

  @override
  String get id;
  @override
  String get name;
  @override
  int get calories;
  @override
  int get protein;
  @override
  int get carbs;
  @override
  int get fats;
  @override
  DateTime? get scheduledDate;
  @override
  String? get type;
  @override
  String? get timeOfDay;
  @override
  String? get instructions;
  @override
  List<MealIngredientEntity>? get ingredients;
  @override
  String? get heroIngredient;
  @override
  String? get ingredientSummary;
  @override
  int? get orderIndex;
  @override
  String? get mediaUrl;
  @override
  DateTime get timestamp;
  @override // P1-D: per-rotation-day macro targets (null = use plan-level average)
  int? get dayTargetCalories;
  @override
  int? get dayTargetProtein;
  @override
  int? get dayTargetCarbs;
  @override
  int? get dayTargetFats;
  @override
  @JsonKey(ignore: true)
  _$$MealEntityImplCopyWith<_$MealEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
