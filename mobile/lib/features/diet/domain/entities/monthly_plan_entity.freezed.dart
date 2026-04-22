// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'monthly_plan_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$IngredientEntity {
  String get name =>
      throw _privateConstructorUsedError; // Canonical identifier for shopping-list deduplication.
// e.g. "chicken_breast_raw" so "Diced Chicken" and "Grilled Chicken"
// collapse into a single shopping list line item.
  String? get canonicalName => throw _privateConstructorUsedError;
  String get amount => throw _privateConstructorUsedError;
  String get unit =>
      throw _privateConstructorUsedError; // Non-optional with safe defaults so the shopping list never shows blank.
  int get calories => throw _privateConstructorUsedError;
  int get protein => throw _privateConstructorUsedError;
  int get carbs => throw _privateConstructorUsedError;
  int get fats => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $IngredientEntityCopyWith<IngredientEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $IngredientEntityCopyWith<$Res> {
  factory $IngredientEntityCopyWith(
          IngredientEntity value, $Res Function(IngredientEntity) then) =
      _$IngredientEntityCopyWithImpl<$Res, IngredientEntity>;
  @useResult
  $Res call(
      {String name,
      String? canonicalName,
      String amount,
      String unit,
      int calories,
      int protein,
      int carbs,
      int fats});
}

/// @nodoc
class _$IngredientEntityCopyWithImpl<$Res, $Val extends IngredientEntity>
    implements $IngredientEntityCopyWith<$Res> {
  _$IngredientEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? canonicalName = freezed,
    Object? amount = null,
    Object? unit = null,
    Object? calories = null,
    Object? protein = null,
    Object? carbs = null,
    Object? fats = null,
  }) {
    return _then(_value.copyWith(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      canonicalName: freezed == canonicalName
          ? _value.canonicalName
          : canonicalName // ignore: cast_nullable_to_non_nullable
              as String?,
      amount: null == amount
          ? _value.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as String,
      unit: null == unit
          ? _value.unit
          : unit // ignore: cast_nullable_to_non_nullable
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
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$IngredientEntityImplCopyWith<$Res>
    implements $IngredientEntityCopyWith<$Res> {
  factory _$$IngredientEntityImplCopyWith(_$IngredientEntityImpl value,
          $Res Function(_$IngredientEntityImpl) then) =
      __$$IngredientEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String name,
      String? canonicalName,
      String amount,
      String unit,
      int calories,
      int protein,
      int carbs,
      int fats});
}

/// @nodoc
class __$$IngredientEntityImplCopyWithImpl<$Res>
    extends _$IngredientEntityCopyWithImpl<$Res, _$IngredientEntityImpl>
    implements _$$IngredientEntityImplCopyWith<$Res> {
  __$$IngredientEntityImplCopyWithImpl(_$IngredientEntityImpl _value,
      $Res Function(_$IngredientEntityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? canonicalName = freezed,
    Object? amount = null,
    Object? unit = null,
    Object? calories = null,
    Object? protein = null,
    Object? carbs = null,
    Object? fats = null,
  }) {
    return _then(_$IngredientEntityImpl(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      canonicalName: freezed == canonicalName
          ? _value.canonicalName
          : canonicalName // ignore: cast_nullable_to_non_nullable
              as String?,
      amount: null == amount
          ? _value.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as String,
      unit: null == unit
          ? _value.unit
          : unit // ignore: cast_nullable_to_non_nullable
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
    ));
  }
}

/// @nodoc

class _$IngredientEntityImpl implements _IngredientEntity {
  const _$IngredientEntityImpl(
      {required this.name,
      this.canonicalName,
      required this.amount,
      required this.unit,
      this.calories = 0,
      this.protein = 0,
      this.carbs = 0,
      this.fats = 0});

  @override
  final String name;
// Canonical identifier for shopping-list deduplication.
// e.g. "chicken_breast_raw" so "Diced Chicken" and "Grilled Chicken"
// collapse into a single shopping list line item.
  @override
  final String? canonicalName;
  @override
  final String amount;
  @override
  final String unit;
// Non-optional with safe defaults so the shopping list never shows blank.
  @override
  @JsonKey()
  final int calories;
  @override
  @JsonKey()
  final int protein;
  @override
  @JsonKey()
  final int carbs;
  @override
  @JsonKey()
  final int fats;

  @override
  String toString() {
    return 'IngredientEntity(name: $name, canonicalName: $canonicalName, amount: $amount, unit: $unit, calories: $calories, protein: $protein, carbs: $carbs, fats: $fats)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$IngredientEntityImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.canonicalName, canonicalName) ||
                other.canonicalName == canonicalName) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.unit, unit) || other.unit == unit) &&
            (identical(other.calories, calories) ||
                other.calories == calories) &&
            (identical(other.protein, protein) || other.protein == protein) &&
            (identical(other.carbs, carbs) || other.carbs == carbs) &&
            (identical(other.fats, fats) || other.fats == fats));
  }

  @override
  int get hashCode => Object.hash(runtimeType, name, canonicalName, amount,
      unit, calories, protein, carbs, fats);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$IngredientEntityImplCopyWith<_$IngredientEntityImpl> get copyWith =>
      __$$IngredientEntityImplCopyWithImpl<_$IngredientEntityImpl>(
          this, _$identity);
}

abstract class _IngredientEntity implements IngredientEntity {
  const factory _IngredientEntity(
      {required final String name,
      final String? canonicalName,
      required final String amount,
      required final String unit,
      final int calories,
      final int protein,
      final int carbs,
      final int fats}) = _$IngredientEntityImpl;

  @override
  String get name;
  @override // Canonical identifier for shopping-list deduplication.
// e.g. "chicken_breast_raw" so "Diced Chicken" and "Grilled Chicken"
// collapse into a single shopping list line item.
  String? get canonicalName;
  @override
  String get amount;
  @override
  String get unit;
  @override // Non-optional with safe defaults so the shopping list never shows blank.
  int get calories;
  @override
  int get protein;
  @override
  int get carbs;
  @override
  int get fats;
  @override
  @JsonKey(ignore: true)
  _$$IngredientEntityImplCopyWith<_$IngredientEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$NutritionInfoEntity {
  int get calories => throw _privateConstructorUsedError;
  int get protein => throw _privateConstructorUsedError;
  int get carbs => throw _privateConstructorUsedError;
  int get fats => throw _privateConstructorUsedError;
  int? get fiber => throw _privateConstructorUsedError;
  int? get sugar => throw _privateConstructorUsedError;
  int? get sodium => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $NutritionInfoEntityCopyWith<NutritionInfoEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NutritionInfoEntityCopyWith<$Res> {
  factory $NutritionInfoEntityCopyWith(
          NutritionInfoEntity value, $Res Function(NutritionInfoEntity) then) =
      _$NutritionInfoEntityCopyWithImpl<$Res, NutritionInfoEntity>;
  @useResult
  $Res call(
      {int calories,
      int protein,
      int carbs,
      int fats,
      int? fiber,
      int? sugar,
      int? sodium});
}

/// @nodoc
class _$NutritionInfoEntityCopyWithImpl<$Res, $Val extends NutritionInfoEntity>
    implements $NutritionInfoEntityCopyWith<$Res> {
  _$NutritionInfoEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? calories = null,
    Object? protein = null,
    Object? carbs = null,
    Object? fats = null,
    Object? fiber = freezed,
    Object? sugar = freezed,
    Object? sodium = freezed,
  }) {
    return _then(_value.copyWith(
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
      fiber: freezed == fiber
          ? _value.fiber
          : fiber // ignore: cast_nullable_to_non_nullable
              as int?,
      sugar: freezed == sugar
          ? _value.sugar
          : sugar // ignore: cast_nullable_to_non_nullable
              as int?,
      sodium: freezed == sodium
          ? _value.sodium
          : sodium // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$NutritionInfoEntityImplCopyWith<$Res>
    implements $NutritionInfoEntityCopyWith<$Res> {
  factory _$$NutritionInfoEntityImplCopyWith(_$NutritionInfoEntityImpl value,
          $Res Function(_$NutritionInfoEntityImpl) then) =
      __$$NutritionInfoEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int calories,
      int protein,
      int carbs,
      int fats,
      int? fiber,
      int? sugar,
      int? sodium});
}

/// @nodoc
class __$$NutritionInfoEntityImplCopyWithImpl<$Res>
    extends _$NutritionInfoEntityCopyWithImpl<$Res, _$NutritionInfoEntityImpl>
    implements _$$NutritionInfoEntityImplCopyWith<$Res> {
  __$$NutritionInfoEntityImplCopyWithImpl(_$NutritionInfoEntityImpl _value,
      $Res Function(_$NutritionInfoEntityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? calories = null,
    Object? protein = null,
    Object? carbs = null,
    Object? fats = null,
    Object? fiber = freezed,
    Object? sugar = freezed,
    Object? sodium = freezed,
  }) {
    return _then(_$NutritionInfoEntityImpl(
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
      fiber: freezed == fiber
          ? _value.fiber
          : fiber // ignore: cast_nullable_to_non_nullable
              as int?,
      sugar: freezed == sugar
          ? _value.sugar
          : sugar // ignore: cast_nullable_to_non_nullable
              as int?,
      sodium: freezed == sodium
          ? _value.sodium
          : sodium // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc

class _$NutritionInfoEntityImpl implements _NutritionInfoEntity {
  const _$NutritionInfoEntityImpl(
      {required this.calories,
      required this.protein,
      required this.carbs,
      required this.fats,
      this.fiber,
      this.sugar,
      this.sodium});

  @override
  final int calories;
  @override
  final int protein;
  @override
  final int carbs;
  @override
  final int fats;
  @override
  final int? fiber;
  @override
  final int? sugar;
  @override
  final int? sodium;

  @override
  String toString() {
    return 'NutritionInfoEntity(calories: $calories, protein: $protein, carbs: $carbs, fats: $fats, fiber: $fiber, sugar: $sugar, sodium: $sodium)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NutritionInfoEntityImpl &&
            (identical(other.calories, calories) ||
                other.calories == calories) &&
            (identical(other.protein, protein) || other.protein == protein) &&
            (identical(other.carbs, carbs) || other.carbs == carbs) &&
            (identical(other.fats, fats) || other.fats == fats) &&
            (identical(other.fiber, fiber) || other.fiber == fiber) &&
            (identical(other.sugar, sugar) || other.sugar == sugar) &&
            (identical(other.sodium, sodium) || other.sodium == sodium));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, calories, protein, carbs, fats, fiber, sugar, sodium);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$NutritionInfoEntityImplCopyWith<_$NutritionInfoEntityImpl> get copyWith =>
      __$$NutritionInfoEntityImplCopyWithImpl<_$NutritionInfoEntityImpl>(
          this, _$identity);
}

abstract class _NutritionInfoEntity implements NutritionInfoEntity {
  const factory _NutritionInfoEntity(
      {required final int calories,
      required final int protein,
      required final int carbs,
      required final int fats,
      final int? fiber,
      final int? sugar,
      final int? sodium}) = _$NutritionInfoEntityImpl;

  @override
  int get calories;
  @override
  int get protein;
  @override
  int get carbs;
  @override
  int get fats;
  @override
  int? get fiber;
  @override
  int? get sugar;
  @override
  int? get sodium;
  @override
  @JsonKey(ignore: true)
  _$$NutritionInfoEntityImplCopyWith<_$NutritionInfoEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$PlannedMealEntity {
  String get id => throw _privateConstructorUsedError;
  MealType get type => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  List<IngredientEntity> get ingredients => throw _privateConstructorUsedError;
  String get instructions => throw _privateConstructorUsedError;
  int get prepTimeMinutes => throw _privateConstructorUsedError;
  NutritionInfoEntity get nutrition => throw _privateConstructorUsedError;
  String? get imageUrl => throw _privateConstructorUsedError;
  String? get scheduledTime =>
      throw _privateConstructorUsedError; // "08:00" for reminders
  String? get heroIngredient => throw _privateConstructorUsedError;
  String? get ingredientSummary => throw _privateConstructorUsedError;
  bool get isCompleted => throw _privateConstructorUsedError;
  bool get isSwapped => throw _privateConstructorUsedError;
  bool get isSkipped => throw _privateConstructorUsedError;
  DateTime? get completedAt => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $PlannedMealEntityCopyWith<PlannedMealEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlannedMealEntityCopyWith<$Res> {
  factory $PlannedMealEntityCopyWith(
          PlannedMealEntity value, $Res Function(PlannedMealEntity) then) =
      _$PlannedMealEntityCopyWithImpl<$Res, PlannedMealEntity>;
  @useResult
  $Res call(
      {String id,
      MealType type,
      String name,
      String description,
      List<IngredientEntity> ingredients,
      String instructions,
      int prepTimeMinutes,
      NutritionInfoEntity nutrition,
      String? imageUrl,
      String? scheduledTime,
      String? heroIngredient,
      String? ingredientSummary,
      bool isCompleted,
      bool isSwapped,
      bool isSkipped,
      DateTime? completedAt});

  $NutritionInfoEntityCopyWith<$Res> get nutrition;
}

/// @nodoc
class _$PlannedMealEntityCopyWithImpl<$Res, $Val extends PlannedMealEntity>
    implements $PlannedMealEntityCopyWith<$Res> {
  _$PlannedMealEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? name = null,
    Object? description = null,
    Object? ingredients = null,
    Object? instructions = null,
    Object? prepTimeMinutes = null,
    Object? nutrition = null,
    Object? imageUrl = freezed,
    Object? scheduledTime = freezed,
    Object? heroIngredient = freezed,
    Object? ingredientSummary = freezed,
    Object? isCompleted = null,
    Object? isSwapped = null,
    Object? isSkipped = null,
    Object? completedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as MealType,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      ingredients: null == ingredients
          ? _value.ingredients
          : ingredients // ignore: cast_nullable_to_non_nullable
              as List<IngredientEntity>,
      instructions: null == instructions
          ? _value.instructions
          : instructions // ignore: cast_nullable_to_non_nullable
              as String,
      prepTimeMinutes: null == prepTimeMinutes
          ? _value.prepTimeMinutes
          : prepTimeMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      nutrition: null == nutrition
          ? _value.nutrition
          : nutrition // ignore: cast_nullable_to_non_nullable
              as NutritionInfoEntity,
      imageUrl: freezed == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      scheduledTime: freezed == scheduledTime
          ? _value.scheduledTime
          : scheduledTime // ignore: cast_nullable_to_non_nullable
              as String?,
      heroIngredient: freezed == heroIngredient
          ? _value.heroIngredient
          : heroIngredient // ignore: cast_nullable_to_non_nullable
              as String?,
      ingredientSummary: freezed == ingredientSummary
          ? _value.ingredientSummary
          : ingredientSummary // ignore: cast_nullable_to_non_nullable
              as String?,
      isCompleted: null == isCompleted
          ? _value.isCompleted
          : isCompleted // ignore: cast_nullable_to_non_nullable
              as bool,
      isSwapped: null == isSwapped
          ? _value.isSwapped
          : isSwapped // ignore: cast_nullable_to_non_nullable
              as bool,
      isSkipped: null == isSkipped
          ? _value.isSkipped
          : isSkipped // ignore: cast_nullable_to_non_nullable
              as bool,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $NutritionInfoEntityCopyWith<$Res> get nutrition {
    return $NutritionInfoEntityCopyWith<$Res>(_value.nutrition, (value) {
      return _then(_value.copyWith(nutrition: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$PlannedMealEntityImplCopyWith<$Res>
    implements $PlannedMealEntityCopyWith<$Res> {
  factory _$$PlannedMealEntityImplCopyWith(_$PlannedMealEntityImpl value,
          $Res Function(_$PlannedMealEntityImpl) then) =
      __$$PlannedMealEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      MealType type,
      String name,
      String description,
      List<IngredientEntity> ingredients,
      String instructions,
      int prepTimeMinutes,
      NutritionInfoEntity nutrition,
      String? imageUrl,
      String? scheduledTime,
      String? heroIngredient,
      String? ingredientSummary,
      bool isCompleted,
      bool isSwapped,
      bool isSkipped,
      DateTime? completedAt});

  @override
  $NutritionInfoEntityCopyWith<$Res> get nutrition;
}

/// @nodoc
class __$$PlannedMealEntityImplCopyWithImpl<$Res>
    extends _$PlannedMealEntityCopyWithImpl<$Res, _$PlannedMealEntityImpl>
    implements _$$PlannedMealEntityImplCopyWith<$Res> {
  __$$PlannedMealEntityImplCopyWithImpl(_$PlannedMealEntityImpl _value,
      $Res Function(_$PlannedMealEntityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? name = null,
    Object? description = null,
    Object? ingredients = null,
    Object? instructions = null,
    Object? prepTimeMinutes = null,
    Object? nutrition = null,
    Object? imageUrl = freezed,
    Object? scheduledTime = freezed,
    Object? heroIngredient = freezed,
    Object? ingredientSummary = freezed,
    Object? isCompleted = null,
    Object? isSwapped = null,
    Object? isSkipped = null,
    Object? completedAt = freezed,
  }) {
    return _then(_$PlannedMealEntityImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as MealType,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      ingredients: null == ingredients
          ? _value._ingredients
          : ingredients // ignore: cast_nullable_to_non_nullable
              as List<IngredientEntity>,
      instructions: null == instructions
          ? _value.instructions
          : instructions // ignore: cast_nullable_to_non_nullable
              as String,
      prepTimeMinutes: null == prepTimeMinutes
          ? _value.prepTimeMinutes
          : prepTimeMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      nutrition: null == nutrition
          ? _value.nutrition
          : nutrition // ignore: cast_nullable_to_non_nullable
              as NutritionInfoEntity,
      imageUrl: freezed == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      scheduledTime: freezed == scheduledTime
          ? _value.scheduledTime
          : scheduledTime // ignore: cast_nullable_to_non_nullable
              as String?,
      heroIngredient: freezed == heroIngredient
          ? _value.heroIngredient
          : heroIngredient // ignore: cast_nullable_to_non_nullable
              as String?,
      ingredientSummary: freezed == ingredientSummary
          ? _value.ingredientSummary
          : ingredientSummary // ignore: cast_nullable_to_non_nullable
              as String?,
      isCompleted: null == isCompleted
          ? _value.isCompleted
          : isCompleted // ignore: cast_nullable_to_non_nullable
              as bool,
      isSwapped: null == isSwapped
          ? _value.isSwapped
          : isSwapped // ignore: cast_nullable_to_non_nullable
              as bool,
      isSkipped: null == isSkipped
          ? _value.isSkipped
          : isSkipped // ignore: cast_nullable_to_non_nullable
              as bool,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc

class _$PlannedMealEntityImpl implements _PlannedMealEntity {
  const _$PlannedMealEntityImpl(
      {required this.id,
      required this.type,
      required this.name,
      required this.description,
      required final List<IngredientEntity> ingredients,
      required this.instructions,
      required this.prepTimeMinutes,
      required this.nutrition,
      this.imageUrl,
      this.scheduledTime,
      this.heroIngredient,
      this.ingredientSummary,
      this.isCompleted = false,
      this.isSwapped = false,
      this.isSkipped = false,
      this.completedAt})
      : _ingredients = ingredients;

  @override
  final String id;
  @override
  final MealType type;
  @override
  final String name;
  @override
  final String description;
  final List<IngredientEntity> _ingredients;
  @override
  List<IngredientEntity> get ingredients {
    if (_ingredients is EqualUnmodifiableListView) return _ingredients;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_ingredients);
  }

  @override
  final String instructions;
  @override
  final int prepTimeMinutes;
  @override
  final NutritionInfoEntity nutrition;
  @override
  final String? imageUrl;
  @override
  final String? scheduledTime;
// "08:00" for reminders
  @override
  final String? heroIngredient;
  @override
  final String? ingredientSummary;
  @override
  @JsonKey()
  final bool isCompleted;
  @override
  @JsonKey()
  final bool isSwapped;
  @override
  @JsonKey()
  final bool isSkipped;
  @override
  final DateTime? completedAt;

  @override
  String toString() {
    return 'PlannedMealEntity(id: $id, type: $type, name: $name, description: $description, ingredients: $ingredients, instructions: $instructions, prepTimeMinutes: $prepTimeMinutes, nutrition: $nutrition, imageUrl: $imageUrl, scheduledTime: $scheduledTime, heroIngredient: $heroIngredient, ingredientSummary: $ingredientSummary, isCompleted: $isCompleted, isSwapped: $isSwapped, isSkipped: $isSkipped, completedAt: $completedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlannedMealEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality()
                .equals(other._ingredients, _ingredients) &&
            (identical(other.instructions, instructions) ||
                other.instructions == instructions) &&
            (identical(other.prepTimeMinutes, prepTimeMinutes) ||
                other.prepTimeMinutes == prepTimeMinutes) &&
            (identical(other.nutrition, nutrition) ||
                other.nutrition == nutrition) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.scheduledTime, scheduledTime) ||
                other.scheduledTime == scheduledTime) &&
            (identical(other.heroIngredient, heroIngredient) ||
                other.heroIngredient == heroIngredient) &&
            (identical(other.ingredientSummary, ingredientSummary) ||
                other.ingredientSummary == ingredientSummary) &&
            (identical(other.isCompleted, isCompleted) ||
                other.isCompleted == isCompleted) &&
            (identical(other.isSwapped, isSwapped) ||
                other.isSwapped == isSwapped) &&
            (identical(other.isSkipped, isSkipped) ||
                other.isSkipped == isSkipped) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      type,
      name,
      description,
      const DeepCollectionEquality().hash(_ingredients),
      instructions,
      prepTimeMinutes,
      nutrition,
      imageUrl,
      scheduledTime,
      heroIngredient,
      ingredientSummary,
      isCompleted,
      isSwapped,
      isSkipped,
      completedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PlannedMealEntityImplCopyWith<_$PlannedMealEntityImpl> get copyWith =>
      __$$PlannedMealEntityImplCopyWithImpl<_$PlannedMealEntityImpl>(
          this, _$identity);
}

abstract class _PlannedMealEntity implements PlannedMealEntity {
  const factory _PlannedMealEntity(
      {required final String id,
      required final MealType type,
      required final String name,
      required final String description,
      required final List<IngredientEntity> ingredients,
      required final String instructions,
      required final int prepTimeMinutes,
      required final NutritionInfoEntity nutrition,
      final String? imageUrl,
      final String? scheduledTime,
      final String? heroIngredient,
      final String? ingredientSummary,
      final bool isCompleted,
      final bool isSwapped,
      final bool isSkipped,
      final DateTime? completedAt}) = _$PlannedMealEntityImpl;

  @override
  String get id;
  @override
  MealType get type;
  @override
  String get name;
  @override
  String get description;
  @override
  List<IngredientEntity> get ingredients;
  @override
  String get instructions;
  @override
  int get prepTimeMinutes;
  @override
  NutritionInfoEntity get nutrition;
  @override
  String? get imageUrl;
  @override
  String? get scheduledTime;
  @override // "08:00" for reminders
  String? get heroIngredient;
  @override
  String? get ingredientSummary;
  @override
  bool get isCompleted;
  @override
  bool get isSwapped;
  @override
  bool get isSkipped;
  @override
  DateTime? get completedAt;
  @override
  @JsonKey(ignore: true)
  _$$PlannedMealEntityImplCopyWith<_$PlannedMealEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$SmartBagEntryEntity {
  String get name => throw _privateConstructorUsedError;
  double get qty => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $SmartBagEntryEntityCopyWith<SmartBagEntryEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SmartBagEntryEntityCopyWith<$Res> {
  factory $SmartBagEntryEntityCopyWith(
          SmartBagEntryEntity value, $Res Function(SmartBagEntryEntity) then) =
      _$SmartBagEntryEntityCopyWithImpl<$Res, SmartBagEntryEntity>;
  @useResult
  $Res call({String name, double qty});
}

/// @nodoc
class _$SmartBagEntryEntityCopyWithImpl<$Res, $Val extends SmartBagEntryEntity>
    implements $SmartBagEntryEntityCopyWith<$Res> {
  _$SmartBagEntryEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? qty = null,
  }) {
    return _then(_value.copyWith(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      qty: null == qty
          ? _value.qty
          : qty // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SmartBagEntryEntityImplCopyWith<$Res>
    implements $SmartBagEntryEntityCopyWith<$Res> {
  factory _$$SmartBagEntryEntityImplCopyWith(_$SmartBagEntryEntityImpl value,
          $Res Function(_$SmartBagEntryEntityImpl) then) =
      __$$SmartBagEntryEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String name, double qty});
}

/// @nodoc
class __$$SmartBagEntryEntityImplCopyWithImpl<$Res>
    extends _$SmartBagEntryEntityCopyWithImpl<$Res, _$SmartBagEntryEntityImpl>
    implements _$$SmartBagEntryEntityImplCopyWith<$Res> {
  __$$SmartBagEntryEntityImplCopyWithImpl(_$SmartBagEntryEntityImpl _value,
      $Res Function(_$SmartBagEntryEntityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? qty = null,
  }) {
    return _then(_$SmartBagEntryEntityImpl(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      qty: null == qty
          ? _value.qty
          : qty // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc

class _$SmartBagEntryEntityImpl implements _SmartBagEntryEntity {
  const _$SmartBagEntryEntityImpl({required this.name, required this.qty});

  @override
  final String name;
  @override
  final double qty;

  @override
  String toString() {
    return 'SmartBagEntryEntity(name: $name, qty: $qty)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SmartBagEntryEntityImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.qty, qty) || other.qty == qty));
  }

  @override
  int get hashCode => Object.hash(runtimeType, name, qty);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SmartBagEntryEntityImplCopyWith<_$SmartBagEntryEntityImpl> get copyWith =>
      __$$SmartBagEntryEntityImplCopyWithImpl<_$SmartBagEntryEntityImpl>(
          this, _$identity);
}

abstract class _SmartBagEntryEntity implements SmartBagEntryEntity {
  const factory _SmartBagEntryEntity(
      {required final String name,
      required final double qty}) = _$SmartBagEntryEntityImpl;

  @override
  String get name;
  @override
  double get qty;
  @override
  @JsonKey(ignore: true)
  _$$SmartBagEntryEntityImplCopyWith<_$SmartBagEntryEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$DailyPlanEntity {
  String get id => throw _privateConstructorUsedError;
  DateTime get date => throw _privateConstructorUsedError;
  List<PlannedMealEntity> get meals => throw _privateConstructorUsedError;
  int get targetCalories => throw _privateConstructorUsedError;
  int get targetProtein => throw _privateConstructorUsedError;
  int get targetCarbs => throw _privateConstructorUsedError;
  int get targetFats => throw _privateConstructorUsedError;
  List<SmartBagEntryEntity> get smartBagEntries =>
      throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $DailyPlanEntityCopyWith<DailyPlanEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DailyPlanEntityCopyWith<$Res> {
  factory $DailyPlanEntityCopyWith(
          DailyPlanEntity value, $Res Function(DailyPlanEntity) then) =
      _$DailyPlanEntityCopyWithImpl<$Res, DailyPlanEntity>;
  @useResult
  $Res call(
      {String id,
      DateTime date,
      List<PlannedMealEntity> meals,
      int targetCalories,
      int targetProtein,
      int targetCarbs,
      int targetFats,
      List<SmartBagEntryEntity> smartBagEntries});
}

/// @nodoc
class _$DailyPlanEntityCopyWithImpl<$Res, $Val extends DailyPlanEntity>
    implements $DailyPlanEntityCopyWith<$Res> {
  _$DailyPlanEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? date = null,
    Object? meals = null,
    Object? targetCalories = null,
    Object? targetProtein = null,
    Object? targetCarbs = null,
    Object? targetFats = null,
    Object? smartBagEntries = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      meals: null == meals
          ? _value.meals
          : meals // ignore: cast_nullable_to_non_nullable
              as List<PlannedMealEntity>,
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
      smartBagEntries: null == smartBagEntries
          ? _value.smartBagEntries
          : smartBagEntries // ignore: cast_nullable_to_non_nullable
              as List<SmartBagEntryEntity>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DailyPlanEntityImplCopyWith<$Res>
    implements $DailyPlanEntityCopyWith<$Res> {
  factory _$$DailyPlanEntityImplCopyWith(_$DailyPlanEntityImpl value,
          $Res Function(_$DailyPlanEntityImpl) then) =
      __$$DailyPlanEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      DateTime date,
      List<PlannedMealEntity> meals,
      int targetCalories,
      int targetProtein,
      int targetCarbs,
      int targetFats,
      List<SmartBagEntryEntity> smartBagEntries});
}

/// @nodoc
class __$$DailyPlanEntityImplCopyWithImpl<$Res>
    extends _$DailyPlanEntityCopyWithImpl<$Res, _$DailyPlanEntityImpl>
    implements _$$DailyPlanEntityImplCopyWith<$Res> {
  __$$DailyPlanEntityImplCopyWithImpl(
      _$DailyPlanEntityImpl _value, $Res Function(_$DailyPlanEntityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? date = null,
    Object? meals = null,
    Object? targetCalories = null,
    Object? targetProtein = null,
    Object? targetCarbs = null,
    Object? targetFats = null,
    Object? smartBagEntries = null,
  }) {
    return _then(_$DailyPlanEntityImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      meals: null == meals
          ? _value._meals
          : meals // ignore: cast_nullable_to_non_nullable
              as List<PlannedMealEntity>,
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
      smartBagEntries: null == smartBagEntries
          ? _value._smartBagEntries
          : smartBagEntries // ignore: cast_nullable_to_non_nullable
              as List<SmartBagEntryEntity>,
    ));
  }
}

/// @nodoc

class _$DailyPlanEntityImpl extends _DailyPlanEntity {
  const _$DailyPlanEntityImpl(
      {required this.id,
      required this.date,
      required final List<PlannedMealEntity> meals,
      required this.targetCalories,
      required this.targetProtein,
      required this.targetCarbs,
      required this.targetFats,
      final List<SmartBagEntryEntity> smartBagEntries = const []})
      : _meals = meals,
        _smartBagEntries = smartBagEntries,
        super._();

  @override
  final String id;
  @override
  final DateTime date;
  final List<PlannedMealEntity> _meals;
  @override
  List<PlannedMealEntity> get meals {
    if (_meals is EqualUnmodifiableListView) return _meals;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_meals);
  }

  @override
  final int targetCalories;
  @override
  final int targetProtein;
  @override
  final int targetCarbs;
  @override
  final int targetFats;
  final List<SmartBagEntryEntity> _smartBagEntries;
  @override
  @JsonKey()
  List<SmartBagEntryEntity> get smartBagEntries {
    if (_smartBagEntries is EqualUnmodifiableListView) return _smartBagEntries;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_smartBagEntries);
  }

  @override
  String toString() {
    return 'DailyPlanEntity(id: $id, date: $date, meals: $meals, targetCalories: $targetCalories, targetProtein: $targetProtein, targetCarbs: $targetCarbs, targetFats: $targetFats, smartBagEntries: $smartBagEntries)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DailyPlanEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.date, date) || other.date == date) &&
            const DeepCollectionEquality().equals(other._meals, _meals) &&
            (identical(other.targetCalories, targetCalories) ||
                other.targetCalories == targetCalories) &&
            (identical(other.targetProtein, targetProtein) ||
                other.targetProtein == targetProtein) &&
            (identical(other.targetCarbs, targetCarbs) ||
                other.targetCarbs == targetCarbs) &&
            (identical(other.targetFats, targetFats) ||
                other.targetFats == targetFats) &&
            const DeepCollectionEquality()
                .equals(other._smartBagEntries, _smartBagEntries));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      date,
      const DeepCollectionEquality().hash(_meals),
      targetCalories,
      targetProtein,
      targetCarbs,
      targetFats,
      const DeepCollectionEquality().hash(_smartBagEntries));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$DailyPlanEntityImplCopyWith<_$DailyPlanEntityImpl> get copyWith =>
      __$$DailyPlanEntityImplCopyWithImpl<_$DailyPlanEntityImpl>(
          this, _$identity);
}

abstract class _DailyPlanEntity extends DailyPlanEntity {
  const factory _DailyPlanEntity(
      {required final String id,
      required final DateTime date,
      required final List<PlannedMealEntity> meals,
      required final int targetCalories,
      required final int targetProtein,
      required final int targetCarbs,
      required final int targetFats,
      final List<SmartBagEntryEntity> smartBagEntries}) = _$DailyPlanEntityImpl;
  const _DailyPlanEntity._() : super._();

  @override
  String get id;
  @override
  DateTime get date;
  @override
  List<PlannedMealEntity> get meals;
  @override
  int get targetCalories;
  @override
  int get targetProtein;
  @override
  int get targetCarbs;
  @override
  int get targetFats;
  @override
  List<SmartBagEntryEntity> get smartBagEntries;
  @override
  @JsonKey(ignore: true)
  _$$DailyPlanEntityImplCopyWith<_$DailyPlanEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$WeeklyPlanEntity {
  int get weekNumber => throw _privateConstructorUsedError;
  DateTime get startDate => throw _privateConstructorUsedError;
  DateTime get endDate => throw _privateConstructorUsedError;
  List<DailyPlanEntity> get days => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $WeeklyPlanEntityCopyWith<WeeklyPlanEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WeeklyPlanEntityCopyWith<$Res> {
  factory $WeeklyPlanEntityCopyWith(
          WeeklyPlanEntity value, $Res Function(WeeklyPlanEntity) then) =
      _$WeeklyPlanEntityCopyWithImpl<$Res, WeeklyPlanEntity>;
  @useResult
  $Res call(
      {int weekNumber,
      DateTime startDate,
      DateTime endDate,
      List<DailyPlanEntity> days});
}

/// @nodoc
class _$WeeklyPlanEntityCopyWithImpl<$Res, $Val extends WeeklyPlanEntity>
    implements $WeeklyPlanEntityCopyWith<$Res> {
  _$WeeklyPlanEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? weekNumber = null,
    Object? startDate = null,
    Object? endDate = null,
    Object? days = null,
  }) {
    return _then(_value.copyWith(
      weekNumber: null == weekNumber
          ? _value.weekNumber
          : weekNumber // ignore: cast_nullable_to_non_nullable
              as int,
      startDate: null == startDate
          ? _value.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endDate: null == endDate
          ? _value.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      days: null == days
          ? _value.days
          : days // ignore: cast_nullable_to_non_nullable
              as List<DailyPlanEntity>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$WeeklyPlanEntityImplCopyWith<$Res>
    implements $WeeklyPlanEntityCopyWith<$Res> {
  factory _$$WeeklyPlanEntityImplCopyWith(_$WeeklyPlanEntityImpl value,
          $Res Function(_$WeeklyPlanEntityImpl) then) =
      __$$WeeklyPlanEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int weekNumber,
      DateTime startDate,
      DateTime endDate,
      List<DailyPlanEntity> days});
}

/// @nodoc
class __$$WeeklyPlanEntityImplCopyWithImpl<$Res>
    extends _$WeeklyPlanEntityCopyWithImpl<$Res, _$WeeklyPlanEntityImpl>
    implements _$$WeeklyPlanEntityImplCopyWith<$Res> {
  __$$WeeklyPlanEntityImplCopyWithImpl(_$WeeklyPlanEntityImpl _value,
      $Res Function(_$WeeklyPlanEntityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? weekNumber = null,
    Object? startDate = null,
    Object? endDate = null,
    Object? days = null,
  }) {
    return _then(_$WeeklyPlanEntityImpl(
      weekNumber: null == weekNumber
          ? _value.weekNumber
          : weekNumber // ignore: cast_nullable_to_non_nullable
              as int,
      startDate: null == startDate
          ? _value.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endDate: null == endDate
          ? _value.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      days: null == days
          ? _value._days
          : days // ignore: cast_nullable_to_non_nullable
              as List<DailyPlanEntity>,
    ));
  }
}

/// @nodoc

class _$WeeklyPlanEntityImpl extends _WeeklyPlanEntity {
  const _$WeeklyPlanEntityImpl(
      {required this.weekNumber,
      required this.startDate,
      required this.endDate,
      required final List<DailyPlanEntity> days})
      : _days = days,
        super._();

  @override
  final int weekNumber;
  @override
  final DateTime startDate;
  @override
  final DateTime endDate;
  final List<DailyPlanEntity> _days;
  @override
  List<DailyPlanEntity> get days {
    if (_days is EqualUnmodifiableListView) return _days;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_days);
  }

  @override
  String toString() {
    return 'WeeklyPlanEntity(weekNumber: $weekNumber, startDate: $startDate, endDate: $endDate, days: $days)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WeeklyPlanEntityImpl &&
            (identical(other.weekNumber, weekNumber) ||
                other.weekNumber == weekNumber) &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            const DeepCollectionEquality().equals(other._days, _days));
  }

  @override
  int get hashCode => Object.hash(runtimeType, weekNumber, startDate, endDate,
      const DeepCollectionEquality().hash(_days));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$WeeklyPlanEntityImplCopyWith<_$WeeklyPlanEntityImpl> get copyWith =>
      __$$WeeklyPlanEntityImplCopyWithImpl<_$WeeklyPlanEntityImpl>(
          this, _$identity);
}

abstract class _WeeklyPlanEntity extends WeeklyPlanEntity {
  const factory _WeeklyPlanEntity(
      {required final int weekNumber,
      required final DateTime startDate,
      required final DateTime endDate,
      required final List<DailyPlanEntity> days}) = _$WeeklyPlanEntityImpl;
  const _WeeklyPlanEntity._() : super._();

  @override
  int get weekNumber;
  @override
  DateTime get startDate;
  @override
  DateTime get endDate;
  @override
  List<DailyPlanEntity> get days;
  @override
  @JsonKey(ignore: true)
  _$$WeeklyPlanEntityImplCopyWith<_$WeeklyPlanEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$ShoppingItemEntity {
  String get name => throw _privateConstructorUsedError;
  String get amount => throw _privateConstructorUsedError;
  String get unit => throw _privateConstructorUsedError;
  String get category =>
      throw _privateConstructorUsedError; // "Produce", "Dairy", "Meat", etc.
  bool get isPurchased => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $ShoppingItemEntityCopyWith<ShoppingItemEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ShoppingItemEntityCopyWith<$Res> {
  factory $ShoppingItemEntityCopyWith(
          ShoppingItemEntity value, $Res Function(ShoppingItemEntity) then) =
      _$ShoppingItemEntityCopyWithImpl<$Res, ShoppingItemEntity>;
  @useResult
  $Res call(
      {String name,
      String amount,
      String unit,
      String category,
      bool isPurchased});
}

/// @nodoc
class _$ShoppingItemEntityCopyWithImpl<$Res, $Val extends ShoppingItemEntity>
    implements $ShoppingItemEntityCopyWith<$Res> {
  _$ShoppingItemEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? amount = null,
    Object? unit = null,
    Object? category = null,
    Object? isPurchased = null,
  }) {
    return _then(_value.copyWith(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      amount: null == amount
          ? _value.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as String,
      unit: null == unit
          ? _value.unit
          : unit // ignore: cast_nullable_to_non_nullable
              as String,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as String,
      isPurchased: null == isPurchased
          ? _value.isPurchased
          : isPurchased // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ShoppingItemEntityImplCopyWith<$Res>
    implements $ShoppingItemEntityCopyWith<$Res> {
  factory _$$ShoppingItemEntityImplCopyWith(_$ShoppingItemEntityImpl value,
          $Res Function(_$ShoppingItemEntityImpl) then) =
      __$$ShoppingItemEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String name,
      String amount,
      String unit,
      String category,
      bool isPurchased});
}

/// @nodoc
class __$$ShoppingItemEntityImplCopyWithImpl<$Res>
    extends _$ShoppingItemEntityCopyWithImpl<$Res, _$ShoppingItemEntityImpl>
    implements _$$ShoppingItemEntityImplCopyWith<$Res> {
  __$$ShoppingItemEntityImplCopyWithImpl(_$ShoppingItemEntityImpl _value,
      $Res Function(_$ShoppingItemEntityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? amount = null,
    Object? unit = null,
    Object? category = null,
    Object? isPurchased = null,
  }) {
    return _then(_$ShoppingItemEntityImpl(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      amount: null == amount
          ? _value.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as String,
      unit: null == unit
          ? _value.unit
          : unit // ignore: cast_nullable_to_non_nullable
              as String,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as String,
      isPurchased: null == isPurchased
          ? _value.isPurchased
          : isPurchased // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$ShoppingItemEntityImpl implements _ShoppingItemEntity {
  const _$ShoppingItemEntityImpl(
      {required this.name,
      required this.amount,
      required this.unit,
      required this.category,
      this.isPurchased = false});

  @override
  final String name;
  @override
  final String amount;
  @override
  final String unit;
  @override
  final String category;
// "Produce", "Dairy", "Meat", etc.
  @override
  @JsonKey()
  final bool isPurchased;

  @override
  String toString() {
    return 'ShoppingItemEntity(name: $name, amount: $amount, unit: $unit, category: $category, isPurchased: $isPurchased)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ShoppingItemEntityImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.unit, unit) || other.unit == unit) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.isPurchased, isPurchased) ||
                other.isPurchased == isPurchased));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, name, amount, unit, category, isPurchased);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ShoppingItemEntityImplCopyWith<_$ShoppingItemEntityImpl> get copyWith =>
      __$$ShoppingItemEntityImplCopyWithImpl<_$ShoppingItemEntityImpl>(
          this, _$identity);
}

abstract class _ShoppingItemEntity implements ShoppingItemEntity {
  const factory _ShoppingItemEntity(
      {required final String name,
      required final String amount,
      required final String unit,
      required final String category,
      final bool isPurchased}) = _$ShoppingItemEntityImpl;

  @override
  String get name;
  @override
  String get amount;
  @override
  String get unit;
  @override
  String get category;
  @override // "Produce", "Dairy", "Meat", etc.
  bool get isPurchased;
  @override
  @JsonKey(ignore: true)
  _$$ShoppingItemEntityImplCopyWith<_$ShoppingItemEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$ShoppingListEntity {
  int get weekNumber => throw _privateConstructorUsedError;
  List<ShoppingItemEntity> get items => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $ShoppingListEntityCopyWith<ShoppingListEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ShoppingListEntityCopyWith<$Res> {
  factory $ShoppingListEntityCopyWith(
          ShoppingListEntity value, $Res Function(ShoppingListEntity) then) =
      _$ShoppingListEntityCopyWithImpl<$Res, ShoppingListEntity>;
  @useResult
  $Res call({int weekNumber, List<ShoppingItemEntity> items});
}

/// @nodoc
class _$ShoppingListEntityCopyWithImpl<$Res, $Val extends ShoppingListEntity>
    implements $ShoppingListEntityCopyWith<$Res> {
  _$ShoppingListEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? weekNumber = null,
    Object? items = null,
  }) {
    return _then(_value.copyWith(
      weekNumber: null == weekNumber
          ? _value.weekNumber
          : weekNumber // ignore: cast_nullable_to_non_nullable
              as int,
      items: null == items
          ? _value.items
          : items // ignore: cast_nullable_to_non_nullable
              as List<ShoppingItemEntity>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ShoppingListEntityImplCopyWith<$Res>
    implements $ShoppingListEntityCopyWith<$Res> {
  factory _$$ShoppingListEntityImplCopyWith(_$ShoppingListEntityImpl value,
          $Res Function(_$ShoppingListEntityImpl) then) =
      __$$ShoppingListEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int weekNumber, List<ShoppingItemEntity> items});
}

/// @nodoc
class __$$ShoppingListEntityImplCopyWithImpl<$Res>
    extends _$ShoppingListEntityCopyWithImpl<$Res, _$ShoppingListEntityImpl>
    implements _$$ShoppingListEntityImplCopyWith<$Res> {
  __$$ShoppingListEntityImplCopyWithImpl(_$ShoppingListEntityImpl _value,
      $Res Function(_$ShoppingListEntityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? weekNumber = null,
    Object? items = null,
  }) {
    return _then(_$ShoppingListEntityImpl(
      weekNumber: null == weekNumber
          ? _value.weekNumber
          : weekNumber // ignore: cast_nullable_to_non_nullable
              as int,
      items: null == items
          ? _value._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<ShoppingItemEntity>,
    ));
  }
}

/// @nodoc

class _$ShoppingListEntityImpl extends _ShoppingListEntity {
  const _$ShoppingListEntityImpl(
      {required this.weekNumber, required final List<ShoppingItemEntity> items})
      : _items = items,
        super._();

  @override
  final int weekNumber;
  final List<ShoppingItemEntity> _items;
  @override
  List<ShoppingItemEntity> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  String toString() {
    return 'ShoppingListEntity(weekNumber: $weekNumber, items: $items)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ShoppingListEntityImpl &&
            (identical(other.weekNumber, weekNumber) ||
                other.weekNumber == weekNumber) &&
            const DeepCollectionEquality().equals(other._items, _items));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, weekNumber, const DeepCollectionEquality().hash(_items));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ShoppingListEntityImplCopyWith<_$ShoppingListEntityImpl> get copyWith =>
      __$$ShoppingListEntityImplCopyWithImpl<_$ShoppingListEntityImpl>(
          this, _$identity);
}

abstract class _ShoppingListEntity extends ShoppingListEntity {
  const factory _ShoppingListEntity(
          {required final int weekNumber,
          required final List<ShoppingItemEntity> items}) =
      _$ShoppingListEntityImpl;
  const _ShoppingListEntity._() : super._();

  @override
  int get weekNumber;
  @override
  List<ShoppingItemEntity> get items;
  @override
  @JsonKey(ignore: true)
  _$$ShoppingListEntityImplCopyWith<_$ShoppingListEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$DailyMacroTargetEntity {
  int get calories => throw _privateConstructorUsedError;
  int get protein => throw _privateConstructorUsedError;
  int get carbs => throw _privateConstructorUsedError;
  int get fats => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $DailyMacroTargetEntityCopyWith<DailyMacroTargetEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DailyMacroTargetEntityCopyWith<$Res> {
  factory $DailyMacroTargetEntityCopyWith(DailyMacroTargetEntity value,
          $Res Function(DailyMacroTargetEntity) then) =
      _$DailyMacroTargetEntityCopyWithImpl<$Res, DailyMacroTargetEntity>;
  @useResult
  $Res call({int calories, int protein, int carbs, int fats});
}

/// @nodoc
class _$DailyMacroTargetEntityCopyWithImpl<$Res,
        $Val extends DailyMacroTargetEntity>
    implements $DailyMacroTargetEntityCopyWith<$Res> {
  _$DailyMacroTargetEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? calories = null,
    Object? protein = null,
    Object? carbs = null,
    Object? fats = null,
  }) {
    return _then(_value.copyWith(
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
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DailyMacroTargetEntityImplCopyWith<$Res>
    implements $DailyMacroTargetEntityCopyWith<$Res> {
  factory _$$DailyMacroTargetEntityImplCopyWith(
          _$DailyMacroTargetEntityImpl value,
          $Res Function(_$DailyMacroTargetEntityImpl) then) =
      __$$DailyMacroTargetEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int calories, int protein, int carbs, int fats});
}

/// @nodoc
class __$$DailyMacroTargetEntityImplCopyWithImpl<$Res>
    extends _$DailyMacroTargetEntityCopyWithImpl<$Res,
        _$DailyMacroTargetEntityImpl>
    implements _$$DailyMacroTargetEntityImplCopyWith<$Res> {
  __$$DailyMacroTargetEntityImplCopyWithImpl(
      _$DailyMacroTargetEntityImpl _value,
      $Res Function(_$DailyMacroTargetEntityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? calories = null,
    Object? protein = null,
    Object? carbs = null,
    Object? fats = null,
  }) {
    return _then(_$DailyMacroTargetEntityImpl(
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
    ));
  }
}

/// @nodoc

class _$DailyMacroTargetEntityImpl implements _DailyMacroTargetEntity {
  const _$DailyMacroTargetEntityImpl(
      {required this.calories,
      required this.protein,
      required this.carbs,
      required this.fats});

  @override
  final int calories;
  @override
  final int protein;
  @override
  final int carbs;
  @override
  final int fats;

  @override
  String toString() {
    return 'DailyMacroTargetEntity(calories: $calories, protein: $protein, carbs: $carbs, fats: $fats)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DailyMacroTargetEntityImpl &&
            (identical(other.calories, calories) ||
                other.calories == calories) &&
            (identical(other.protein, protein) || other.protein == protein) &&
            (identical(other.carbs, carbs) || other.carbs == carbs) &&
            (identical(other.fats, fats) || other.fats == fats));
  }

  @override
  int get hashCode => Object.hash(runtimeType, calories, protein, carbs, fats);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$DailyMacroTargetEntityImplCopyWith<_$DailyMacroTargetEntityImpl>
      get copyWith => __$$DailyMacroTargetEntityImplCopyWithImpl<
          _$DailyMacroTargetEntityImpl>(this, _$identity);
}

abstract class _DailyMacroTargetEntity implements DailyMacroTargetEntity {
  const factory _DailyMacroTargetEntity(
      {required final int calories,
      required final int protein,
      required final int carbs,
      required final int fats}) = _$DailyMacroTargetEntityImpl;

  @override
  int get calories;
  @override
  int get protein;
  @override
  int get carbs;
  @override
  int get fats;
  @override
  @JsonKey(ignore: true)
  _$$DailyMacroTargetEntityImplCopyWith<_$DailyMacroTargetEntityImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$MonthlyDietPlanEntity {
  String get id => throw _privateConstructorUsedError;
  String get odUserId => throw _privateConstructorUsedError;
  DateTime get startDate => throw _privateConstructorUsedError;
  DateTime get endDate => throw _privateConstructorUsedError;
  DietGoal get goal => throw _privateConstructorUsedError;
  DailyMacroTargetEntity get macroTarget => throw _privateConstructorUsedError;
  List<WeeklyPlanEntity> get weeks => throw _privateConstructorUsedError;
  List<ShoppingListEntity> get shoppingLists =>
      throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $MonthlyDietPlanEntityCopyWith<MonthlyDietPlanEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MonthlyDietPlanEntityCopyWith<$Res> {
  factory $MonthlyDietPlanEntityCopyWith(MonthlyDietPlanEntity value,
          $Res Function(MonthlyDietPlanEntity) then) =
      _$MonthlyDietPlanEntityCopyWithImpl<$Res, MonthlyDietPlanEntity>;
  @useResult
  $Res call(
      {String id,
      String odUserId,
      DateTime startDate,
      DateTime endDate,
      DietGoal goal,
      DailyMacroTargetEntity macroTarget,
      List<WeeklyPlanEntity> weeks,
      List<ShoppingListEntity> shoppingLists,
      DateTime? createdAt,
      DateTime? updatedAt});

  $DailyMacroTargetEntityCopyWith<$Res> get macroTarget;
}

/// @nodoc
class _$MonthlyDietPlanEntityCopyWithImpl<$Res,
        $Val extends MonthlyDietPlanEntity>
    implements $MonthlyDietPlanEntityCopyWith<$Res> {
  _$MonthlyDietPlanEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? odUserId = null,
    Object? startDate = null,
    Object? endDate = null,
    Object? goal = null,
    Object? macroTarget = null,
    Object? weeks = null,
    Object? shoppingLists = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
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
      startDate: null == startDate
          ? _value.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endDate: null == endDate
          ? _value.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      goal: null == goal
          ? _value.goal
          : goal // ignore: cast_nullable_to_non_nullable
              as DietGoal,
      macroTarget: null == macroTarget
          ? _value.macroTarget
          : macroTarget // ignore: cast_nullable_to_non_nullable
              as DailyMacroTargetEntity,
      weeks: null == weeks
          ? _value.weeks
          : weeks // ignore: cast_nullable_to_non_nullable
              as List<WeeklyPlanEntity>,
      shoppingLists: null == shoppingLists
          ? _value.shoppingLists
          : shoppingLists // ignore: cast_nullable_to_non_nullable
              as List<ShoppingListEntity>,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $DailyMacroTargetEntityCopyWith<$Res> get macroTarget {
    return $DailyMacroTargetEntityCopyWith<$Res>(_value.macroTarget, (value) {
      return _then(_value.copyWith(macroTarget: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$MonthlyDietPlanEntityImplCopyWith<$Res>
    implements $MonthlyDietPlanEntityCopyWith<$Res> {
  factory _$$MonthlyDietPlanEntityImplCopyWith(
          _$MonthlyDietPlanEntityImpl value,
          $Res Function(_$MonthlyDietPlanEntityImpl) then) =
      __$$MonthlyDietPlanEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String odUserId,
      DateTime startDate,
      DateTime endDate,
      DietGoal goal,
      DailyMacroTargetEntity macroTarget,
      List<WeeklyPlanEntity> weeks,
      List<ShoppingListEntity> shoppingLists,
      DateTime? createdAt,
      DateTime? updatedAt});

  @override
  $DailyMacroTargetEntityCopyWith<$Res> get macroTarget;
}

/// @nodoc
class __$$MonthlyDietPlanEntityImplCopyWithImpl<$Res>
    extends _$MonthlyDietPlanEntityCopyWithImpl<$Res,
        _$MonthlyDietPlanEntityImpl>
    implements _$$MonthlyDietPlanEntityImplCopyWith<$Res> {
  __$$MonthlyDietPlanEntityImplCopyWithImpl(_$MonthlyDietPlanEntityImpl _value,
      $Res Function(_$MonthlyDietPlanEntityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? odUserId = null,
    Object? startDate = null,
    Object? endDate = null,
    Object? goal = null,
    Object? macroTarget = null,
    Object? weeks = null,
    Object? shoppingLists = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_$MonthlyDietPlanEntityImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      odUserId: null == odUserId
          ? _value.odUserId
          : odUserId // ignore: cast_nullable_to_non_nullable
              as String,
      startDate: null == startDate
          ? _value.startDate
          : startDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endDate: null == endDate
          ? _value.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      goal: null == goal
          ? _value.goal
          : goal // ignore: cast_nullable_to_non_nullable
              as DietGoal,
      macroTarget: null == macroTarget
          ? _value.macroTarget
          : macroTarget // ignore: cast_nullable_to_non_nullable
              as DailyMacroTargetEntity,
      weeks: null == weeks
          ? _value._weeks
          : weeks // ignore: cast_nullable_to_non_nullable
              as List<WeeklyPlanEntity>,
      shoppingLists: null == shoppingLists
          ? _value._shoppingLists
          : shoppingLists // ignore: cast_nullable_to_non_nullable
              as List<ShoppingListEntity>,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc

class _$MonthlyDietPlanEntityImpl extends _MonthlyDietPlanEntity {
  const _$MonthlyDietPlanEntityImpl(
      {required this.id,
      required this.odUserId,
      required this.startDate,
      required this.endDate,
      required this.goal,
      required this.macroTarget,
      required final List<WeeklyPlanEntity> weeks,
      required final List<ShoppingListEntity> shoppingLists,
      this.createdAt,
      this.updatedAt})
      : _weeks = weeks,
        _shoppingLists = shoppingLists,
        super._();

  @override
  final String id;
  @override
  final String odUserId;
  @override
  final DateTime startDate;
  @override
  final DateTime endDate;
  @override
  final DietGoal goal;
  @override
  final DailyMacroTargetEntity macroTarget;
  final List<WeeklyPlanEntity> _weeks;
  @override
  List<WeeklyPlanEntity> get weeks {
    if (_weeks is EqualUnmodifiableListView) return _weeks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_weeks);
  }

  final List<ShoppingListEntity> _shoppingLists;
  @override
  List<ShoppingListEntity> get shoppingLists {
    if (_shoppingLists is EqualUnmodifiableListView) return _shoppingLists;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_shoppingLists);
  }

  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'MonthlyDietPlanEntity(id: $id, odUserId: $odUserId, startDate: $startDate, endDate: $endDate, goal: $goal, macroTarget: $macroTarget, weeks: $weeks, shoppingLists: $shoppingLists, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MonthlyDietPlanEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.odUserId, odUserId) ||
                other.odUserId == odUserId) &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            (identical(other.goal, goal) || other.goal == goal) &&
            (identical(other.macroTarget, macroTarget) ||
                other.macroTarget == macroTarget) &&
            const DeepCollectionEquality().equals(other._weeks, _weeks) &&
            const DeepCollectionEquality()
                .equals(other._shoppingLists, _shoppingLists) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      odUserId,
      startDate,
      endDate,
      goal,
      macroTarget,
      const DeepCollectionEquality().hash(_weeks),
      const DeepCollectionEquality().hash(_shoppingLists),
      createdAt,
      updatedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$MonthlyDietPlanEntityImplCopyWith<_$MonthlyDietPlanEntityImpl>
      get copyWith => __$$MonthlyDietPlanEntityImplCopyWithImpl<
          _$MonthlyDietPlanEntityImpl>(this, _$identity);
}

abstract class _MonthlyDietPlanEntity extends MonthlyDietPlanEntity {
  const factory _MonthlyDietPlanEntity(
      {required final String id,
      required final String odUserId,
      required final DateTime startDate,
      required final DateTime endDate,
      required final DietGoal goal,
      required final DailyMacroTargetEntity macroTarget,
      required final List<WeeklyPlanEntity> weeks,
      required final List<ShoppingListEntity> shoppingLists,
      final DateTime? createdAt,
      final DateTime? updatedAt}) = _$MonthlyDietPlanEntityImpl;
  const _MonthlyDietPlanEntity._() : super._();

  @override
  String get id;
  @override
  String get odUserId;
  @override
  DateTime get startDate;
  @override
  DateTime get endDate;
  @override
  DietGoal get goal;
  @override
  DailyMacroTargetEntity get macroTarget;
  @override
  List<WeeklyPlanEntity> get weeks;
  @override
  List<ShoppingListEntity> get shoppingLists;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;
  @override
  @JsonKey(ignore: true)
  _$$MonthlyDietPlanEntityImplCopyWith<_$MonthlyDietPlanEntityImpl>
      get copyWith => throw _privateConstructorUsedError;
}
