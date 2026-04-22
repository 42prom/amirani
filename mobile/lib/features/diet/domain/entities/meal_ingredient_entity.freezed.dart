// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'meal_ingredient_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

MealIngredientEntity _$MealIngredientEntityFromJson(Map<String, dynamic> json) {
  return _MealIngredientEntity.fromJson(json);
}

/// @nodoc
mixin _$MealIngredientEntity {
  String get name => throw _privateConstructorUsedError;
  double get amount => throw _privateConstructorUsedError;
  String get unit => throw _privateConstructorUsedError;
  int get calories => throw _privateConstructorUsedError;
  int get protein => throw _privateConstructorUsedError;
  int get carbs => throw _privateConstructorUsedError;
  int get fats => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $MealIngredientEntityCopyWith<MealIngredientEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MealIngredientEntityCopyWith<$Res> {
  factory $MealIngredientEntityCopyWith(MealIngredientEntity value,
          $Res Function(MealIngredientEntity) then) =
      _$MealIngredientEntityCopyWithImpl<$Res, MealIngredientEntity>;
  @useResult
  $Res call(
      {String name,
      double amount,
      String unit,
      int calories,
      int protein,
      int carbs,
      int fats});
}

/// @nodoc
class _$MealIngredientEntityCopyWithImpl<$Res,
        $Val extends MealIngredientEntity>
    implements $MealIngredientEntityCopyWith<$Res> {
  _$MealIngredientEntityCopyWithImpl(this._value, this._then);

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
      amount: null == amount
          ? _value.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as double,
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
abstract class _$$MealIngredientEntityImplCopyWith<$Res>
    implements $MealIngredientEntityCopyWith<$Res> {
  factory _$$MealIngredientEntityImplCopyWith(_$MealIngredientEntityImpl value,
          $Res Function(_$MealIngredientEntityImpl) then) =
      __$$MealIngredientEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String name,
      double amount,
      String unit,
      int calories,
      int protein,
      int carbs,
      int fats});
}

/// @nodoc
class __$$MealIngredientEntityImplCopyWithImpl<$Res>
    extends _$MealIngredientEntityCopyWithImpl<$Res, _$MealIngredientEntityImpl>
    implements _$$MealIngredientEntityImplCopyWith<$Res> {
  __$$MealIngredientEntityImplCopyWithImpl(_$MealIngredientEntityImpl _value,
      $Res Function(_$MealIngredientEntityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? amount = null,
    Object? unit = null,
    Object? calories = null,
    Object? protein = null,
    Object? carbs = null,
    Object? fats = null,
  }) {
    return _then(_$MealIngredientEntityImpl(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      amount: null == amount
          ? _value.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as double,
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
@JsonSerializable()
class _$MealIngredientEntityImpl implements _MealIngredientEntity {
  const _$MealIngredientEntityImpl(
      {required this.name,
      required this.amount,
      required this.unit,
      required this.calories,
      required this.protein,
      required this.carbs,
      required this.fats});

  factory _$MealIngredientEntityImpl.fromJson(Map<String, dynamic> json) =>
      _$$MealIngredientEntityImplFromJson(json);

  @override
  final String name;
  @override
  final double amount;
  @override
  final String unit;
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
    return 'MealIngredientEntity(name: $name, amount: $amount, unit: $unit, calories: $calories, protein: $protein, carbs: $carbs, fats: $fats)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MealIngredientEntityImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.unit, unit) || other.unit == unit) &&
            (identical(other.calories, calories) ||
                other.calories == calories) &&
            (identical(other.protein, protein) || other.protein == protein) &&
            (identical(other.carbs, carbs) || other.carbs == carbs) &&
            (identical(other.fats, fats) || other.fats == fats));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType, name, amount, unit, calories, protein, carbs, fats);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$MealIngredientEntityImplCopyWith<_$MealIngredientEntityImpl>
      get copyWith =>
          __$$MealIngredientEntityImplCopyWithImpl<_$MealIngredientEntityImpl>(
              this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MealIngredientEntityImplToJson(
      this,
    );
  }
}

abstract class _MealIngredientEntity implements MealIngredientEntity {
  const factory _MealIngredientEntity(
      {required final String name,
      required final double amount,
      required final String unit,
      required final int calories,
      required final int protein,
      required final int carbs,
      required final int fats}) = _$MealIngredientEntityImpl;

  factory _MealIngredientEntity.fromJson(Map<String, dynamic> json) =
      _$MealIngredientEntityImpl.fromJson;

  @override
  String get name;
  @override
  double get amount;
  @override
  String get unit;
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
  _$$MealIngredientEntityImplCopyWith<_$MealIngredientEntityImpl>
      get copyWith => throw _privateConstructorUsedError;
}
