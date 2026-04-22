// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'diet_preferences_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$UserAllergyEntity {
  AllergyType get type => throw _privateConstructorUsedError;
  AllergySeverity get severity => throw _privateConstructorUsedError;
  String? get customName =>
      throw _privateConstructorUsedError; // For "other" type
  String? get notes => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $UserAllergyEntityCopyWith<UserAllergyEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserAllergyEntityCopyWith<$Res> {
  factory $UserAllergyEntityCopyWith(
          UserAllergyEntity value, $Res Function(UserAllergyEntity) then) =
      _$UserAllergyEntityCopyWithImpl<$Res, UserAllergyEntity>;
  @useResult
  $Res call(
      {AllergyType type,
      AllergySeverity severity,
      String? customName,
      String? notes});
}

/// @nodoc
class _$UserAllergyEntityCopyWithImpl<$Res, $Val extends UserAllergyEntity>
    implements $UserAllergyEntityCopyWith<$Res> {
  _$UserAllergyEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? severity = null,
    Object? customName = freezed,
    Object? notes = freezed,
  }) {
    return _then(_value.copyWith(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as AllergyType,
      severity: null == severity
          ? _value.severity
          : severity // ignore: cast_nullable_to_non_nullable
              as AllergySeverity,
      customName: freezed == customName
          ? _value.customName
          : customName // ignore: cast_nullable_to_non_nullable
              as String?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$UserAllergyEntityImplCopyWith<$Res>
    implements $UserAllergyEntityCopyWith<$Res> {
  factory _$$UserAllergyEntityImplCopyWith(_$UserAllergyEntityImpl value,
          $Res Function(_$UserAllergyEntityImpl) then) =
      __$$UserAllergyEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {AllergyType type,
      AllergySeverity severity,
      String? customName,
      String? notes});
}

/// @nodoc
class __$$UserAllergyEntityImplCopyWithImpl<$Res>
    extends _$UserAllergyEntityCopyWithImpl<$Res, _$UserAllergyEntityImpl>
    implements _$$UserAllergyEntityImplCopyWith<$Res> {
  __$$UserAllergyEntityImplCopyWithImpl(_$UserAllergyEntityImpl _value,
      $Res Function(_$UserAllergyEntityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? severity = null,
    Object? customName = freezed,
    Object? notes = freezed,
  }) {
    return _then(_$UserAllergyEntityImpl(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as AllergyType,
      severity: null == severity
          ? _value.severity
          : severity // ignore: cast_nullable_to_non_nullable
              as AllergySeverity,
      customName: freezed == customName
          ? _value.customName
          : customName // ignore: cast_nullable_to_non_nullable
              as String?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$UserAllergyEntityImpl implements _UserAllergyEntity {
  const _$UserAllergyEntityImpl(
      {required this.type,
      required this.severity,
      this.customName,
      this.notes});

  @override
  final AllergyType type;
  @override
  final AllergySeverity severity;
  @override
  final String? customName;
// For "other" type
  @override
  final String? notes;

  @override
  String toString() {
    return 'UserAllergyEntity(type: $type, severity: $severity, customName: $customName, notes: $notes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserAllergyEntityImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.severity, severity) ||
                other.severity == severity) &&
            (identical(other.customName, customName) ||
                other.customName == customName) &&
            (identical(other.notes, notes) || other.notes == notes));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, type, severity, customName, notes);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$UserAllergyEntityImplCopyWith<_$UserAllergyEntityImpl> get copyWith =>
      __$$UserAllergyEntityImplCopyWithImpl<_$UserAllergyEntityImpl>(
          this, _$identity);
}

abstract class _UserAllergyEntity implements UserAllergyEntity {
  const factory _UserAllergyEntity(
      {required final AllergyType type,
      required final AllergySeverity severity,
      final String? customName,
      final String? notes}) = _$UserAllergyEntityImpl;

  @override
  AllergyType get type;
  @override
  AllergySeverity get severity;
  @override
  String? get customName;
  @override // For "other" type
  String? get notes;
  @override
  @JsonKey(ignore: true)
  _$$UserAllergyEntityImplCopyWith<_$UserAllergyEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$DietPreferencesEntity {
  String get odUserId => throw _privateConstructorUsedError;
  DietGoal get goal => throw _privateConstructorUsedError;
  double? get targetWeightChangePerWeek =>
      throw _privateConstructorUsedError; // kg per week (negative for loss)
  DietaryStyle get dietaryStyle => throw _privateConstructorUsedError;
  List<UserAllergyEntity> get allergies => throw _privateConstructorUsedError;
  List<String> get likedFoods => throw _privateConstructorUsedError;
  List<String> get dislikedFoods => throw _privateConstructorUsedError;
  int get mealsPerDay => throw _privateConstructorUsedError;
  CookingSkill get cookingSkill => throw _privateConstructorUsedError;
  int get maxPrepTimeMinutes => throw _privateConstructorUsedError;
  BudgetPreference get budget => throw _privateConstructorUsedError;
  bool get mealRemindersEnabled => throw _privateConstructorUsedError;
  String? get breakfastTime => throw _privateConstructorUsedError; // "08:00"
  String? get lunchTime => throw _privateConstructorUsedError; // "12:30"
  String? get dinnerTime => throw _privateConstructorUsedError; // "19:00"
  String? get morningSnackTime => throw _privateConstructorUsedError; // "10:30"
  String? get afternoonSnackTime =>
      throw _privateConstructorUsedError; // "16:30"
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $DietPreferencesEntityCopyWith<DietPreferencesEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DietPreferencesEntityCopyWith<$Res> {
  factory $DietPreferencesEntityCopyWith(DietPreferencesEntity value,
          $Res Function(DietPreferencesEntity) then) =
      _$DietPreferencesEntityCopyWithImpl<$Res, DietPreferencesEntity>;
  @useResult
  $Res call(
      {String odUserId,
      DietGoal goal,
      double? targetWeightChangePerWeek,
      DietaryStyle dietaryStyle,
      List<UserAllergyEntity> allergies,
      List<String> likedFoods,
      List<String> dislikedFoods,
      int mealsPerDay,
      CookingSkill cookingSkill,
      int maxPrepTimeMinutes,
      BudgetPreference budget,
      bool mealRemindersEnabled,
      String? breakfastTime,
      String? lunchTime,
      String? dinnerTime,
      String? morningSnackTime,
      String? afternoonSnackTime,
      DateTime? createdAt,
      DateTime? updatedAt});
}

/// @nodoc
class _$DietPreferencesEntityCopyWithImpl<$Res,
        $Val extends DietPreferencesEntity>
    implements $DietPreferencesEntityCopyWith<$Res> {
  _$DietPreferencesEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? odUserId = null,
    Object? goal = null,
    Object? targetWeightChangePerWeek = freezed,
    Object? dietaryStyle = null,
    Object? allergies = null,
    Object? likedFoods = null,
    Object? dislikedFoods = null,
    Object? mealsPerDay = null,
    Object? cookingSkill = null,
    Object? maxPrepTimeMinutes = null,
    Object? budget = null,
    Object? mealRemindersEnabled = null,
    Object? breakfastTime = freezed,
    Object? lunchTime = freezed,
    Object? dinnerTime = freezed,
    Object? morningSnackTime = freezed,
    Object? afternoonSnackTime = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_value.copyWith(
      odUserId: null == odUserId
          ? _value.odUserId
          : odUserId // ignore: cast_nullable_to_non_nullable
              as String,
      goal: null == goal
          ? _value.goal
          : goal // ignore: cast_nullable_to_non_nullable
              as DietGoal,
      targetWeightChangePerWeek: freezed == targetWeightChangePerWeek
          ? _value.targetWeightChangePerWeek
          : targetWeightChangePerWeek // ignore: cast_nullable_to_non_nullable
              as double?,
      dietaryStyle: null == dietaryStyle
          ? _value.dietaryStyle
          : dietaryStyle // ignore: cast_nullable_to_non_nullable
              as DietaryStyle,
      allergies: null == allergies
          ? _value.allergies
          : allergies // ignore: cast_nullable_to_non_nullable
              as List<UserAllergyEntity>,
      likedFoods: null == likedFoods
          ? _value.likedFoods
          : likedFoods // ignore: cast_nullable_to_non_nullable
              as List<String>,
      dislikedFoods: null == dislikedFoods
          ? _value.dislikedFoods
          : dislikedFoods // ignore: cast_nullable_to_non_nullable
              as List<String>,
      mealsPerDay: null == mealsPerDay
          ? _value.mealsPerDay
          : mealsPerDay // ignore: cast_nullable_to_non_nullable
              as int,
      cookingSkill: null == cookingSkill
          ? _value.cookingSkill
          : cookingSkill // ignore: cast_nullable_to_non_nullable
              as CookingSkill,
      maxPrepTimeMinutes: null == maxPrepTimeMinutes
          ? _value.maxPrepTimeMinutes
          : maxPrepTimeMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      budget: null == budget
          ? _value.budget
          : budget // ignore: cast_nullable_to_non_nullable
              as BudgetPreference,
      mealRemindersEnabled: null == mealRemindersEnabled
          ? _value.mealRemindersEnabled
          : mealRemindersEnabled // ignore: cast_nullable_to_non_nullable
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
}

/// @nodoc
abstract class _$$DietPreferencesEntityImplCopyWith<$Res>
    implements $DietPreferencesEntityCopyWith<$Res> {
  factory _$$DietPreferencesEntityImplCopyWith(
          _$DietPreferencesEntityImpl value,
          $Res Function(_$DietPreferencesEntityImpl) then) =
      __$$DietPreferencesEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String odUserId,
      DietGoal goal,
      double? targetWeightChangePerWeek,
      DietaryStyle dietaryStyle,
      List<UserAllergyEntity> allergies,
      List<String> likedFoods,
      List<String> dislikedFoods,
      int mealsPerDay,
      CookingSkill cookingSkill,
      int maxPrepTimeMinutes,
      BudgetPreference budget,
      bool mealRemindersEnabled,
      String? breakfastTime,
      String? lunchTime,
      String? dinnerTime,
      String? morningSnackTime,
      String? afternoonSnackTime,
      DateTime? createdAt,
      DateTime? updatedAt});
}

/// @nodoc
class __$$DietPreferencesEntityImplCopyWithImpl<$Res>
    extends _$DietPreferencesEntityCopyWithImpl<$Res,
        _$DietPreferencesEntityImpl>
    implements _$$DietPreferencesEntityImplCopyWith<$Res> {
  __$$DietPreferencesEntityImplCopyWithImpl(_$DietPreferencesEntityImpl _value,
      $Res Function(_$DietPreferencesEntityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? odUserId = null,
    Object? goal = null,
    Object? targetWeightChangePerWeek = freezed,
    Object? dietaryStyle = null,
    Object? allergies = null,
    Object? likedFoods = null,
    Object? dislikedFoods = null,
    Object? mealsPerDay = null,
    Object? cookingSkill = null,
    Object? maxPrepTimeMinutes = null,
    Object? budget = null,
    Object? mealRemindersEnabled = null,
    Object? breakfastTime = freezed,
    Object? lunchTime = freezed,
    Object? dinnerTime = freezed,
    Object? morningSnackTime = freezed,
    Object? afternoonSnackTime = freezed,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_$DietPreferencesEntityImpl(
      odUserId: null == odUserId
          ? _value.odUserId
          : odUserId // ignore: cast_nullable_to_non_nullable
              as String,
      goal: null == goal
          ? _value.goal
          : goal // ignore: cast_nullable_to_non_nullable
              as DietGoal,
      targetWeightChangePerWeek: freezed == targetWeightChangePerWeek
          ? _value.targetWeightChangePerWeek
          : targetWeightChangePerWeek // ignore: cast_nullable_to_non_nullable
              as double?,
      dietaryStyle: null == dietaryStyle
          ? _value.dietaryStyle
          : dietaryStyle // ignore: cast_nullable_to_non_nullable
              as DietaryStyle,
      allergies: null == allergies
          ? _value._allergies
          : allergies // ignore: cast_nullable_to_non_nullable
              as List<UserAllergyEntity>,
      likedFoods: null == likedFoods
          ? _value._likedFoods
          : likedFoods // ignore: cast_nullable_to_non_nullable
              as List<String>,
      dislikedFoods: null == dislikedFoods
          ? _value._dislikedFoods
          : dislikedFoods // ignore: cast_nullable_to_non_nullable
              as List<String>,
      mealsPerDay: null == mealsPerDay
          ? _value.mealsPerDay
          : mealsPerDay // ignore: cast_nullable_to_non_nullable
              as int,
      cookingSkill: null == cookingSkill
          ? _value.cookingSkill
          : cookingSkill // ignore: cast_nullable_to_non_nullable
              as CookingSkill,
      maxPrepTimeMinutes: null == maxPrepTimeMinutes
          ? _value.maxPrepTimeMinutes
          : maxPrepTimeMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      budget: null == budget
          ? _value.budget
          : budget // ignore: cast_nullable_to_non_nullable
              as BudgetPreference,
      mealRemindersEnabled: null == mealRemindersEnabled
          ? _value.mealRemindersEnabled
          : mealRemindersEnabled // ignore: cast_nullable_to_non_nullable
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

class _$DietPreferencesEntityImpl implements _DietPreferencesEntity {
  const _$DietPreferencesEntityImpl(
      {required this.odUserId,
      required this.goal,
      this.targetWeightChangePerWeek,
      this.dietaryStyle = DietaryStyle.noRestrictions,
      final List<UserAllergyEntity> allergies = const [],
      final List<String> likedFoods = const [],
      final List<String> dislikedFoods = const [],
      this.mealsPerDay = 3,
      this.cookingSkill = CookingSkill.moderate,
      this.maxPrepTimeMinutes = 30,
      this.budget = BudgetPreference.standard,
      this.mealRemindersEnabled = true,
      this.breakfastTime,
      this.lunchTime,
      this.dinnerTime,
      this.morningSnackTime,
      this.afternoonSnackTime,
      this.createdAt,
      this.updatedAt})
      : _allergies = allergies,
        _likedFoods = likedFoods,
        _dislikedFoods = dislikedFoods;

  @override
  final String odUserId;
  @override
  final DietGoal goal;
  @override
  final double? targetWeightChangePerWeek;
// kg per week (negative for loss)
  @override
  @JsonKey()
  final DietaryStyle dietaryStyle;
  final List<UserAllergyEntity> _allergies;
  @override
  @JsonKey()
  List<UserAllergyEntity> get allergies {
    if (_allergies is EqualUnmodifiableListView) return _allergies;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_allergies);
  }

  final List<String> _likedFoods;
  @override
  @JsonKey()
  List<String> get likedFoods {
    if (_likedFoods is EqualUnmodifiableListView) return _likedFoods;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_likedFoods);
  }

  final List<String> _dislikedFoods;
  @override
  @JsonKey()
  List<String> get dislikedFoods {
    if (_dislikedFoods is EqualUnmodifiableListView) return _dislikedFoods;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_dislikedFoods);
  }

  @override
  @JsonKey()
  final int mealsPerDay;
  @override
  @JsonKey()
  final CookingSkill cookingSkill;
  @override
  @JsonKey()
  final int maxPrepTimeMinutes;
  @override
  @JsonKey()
  final BudgetPreference budget;
  @override
  @JsonKey()
  final bool mealRemindersEnabled;
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
// "16:30"
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'DietPreferencesEntity(odUserId: $odUserId, goal: $goal, targetWeightChangePerWeek: $targetWeightChangePerWeek, dietaryStyle: $dietaryStyle, allergies: $allergies, likedFoods: $likedFoods, dislikedFoods: $dislikedFoods, mealsPerDay: $mealsPerDay, cookingSkill: $cookingSkill, maxPrepTimeMinutes: $maxPrepTimeMinutes, budget: $budget, mealRemindersEnabled: $mealRemindersEnabled, breakfastTime: $breakfastTime, lunchTime: $lunchTime, dinnerTime: $dinnerTime, morningSnackTime: $morningSnackTime, afternoonSnackTime: $afternoonSnackTime, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DietPreferencesEntityImpl &&
            (identical(other.odUserId, odUserId) ||
                other.odUserId == odUserId) &&
            (identical(other.goal, goal) || other.goal == goal) &&
            (identical(other.targetWeightChangePerWeek,
                    targetWeightChangePerWeek) ||
                other.targetWeightChangePerWeek == targetWeightChangePerWeek) &&
            (identical(other.dietaryStyle, dietaryStyle) ||
                other.dietaryStyle == dietaryStyle) &&
            const DeepCollectionEquality()
                .equals(other._allergies, _allergies) &&
            const DeepCollectionEquality()
                .equals(other._likedFoods, _likedFoods) &&
            const DeepCollectionEquality()
                .equals(other._dislikedFoods, _dislikedFoods) &&
            (identical(other.mealsPerDay, mealsPerDay) ||
                other.mealsPerDay == mealsPerDay) &&
            (identical(other.cookingSkill, cookingSkill) ||
                other.cookingSkill == cookingSkill) &&
            (identical(other.maxPrepTimeMinutes, maxPrepTimeMinutes) ||
                other.maxPrepTimeMinutes == maxPrepTimeMinutes) &&
            (identical(other.budget, budget) || other.budget == budget) &&
            (identical(other.mealRemindersEnabled, mealRemindersEnabled) ||
                other.mealRemindersEnabled == mealRemindersEnabled) &&
            (identical(other.breakfastTime, breakfastTime) ||
                other.breakfastTime == breakfastTime) &&
            (identical(other.lunchTime, lunchTime) ||
                other.lunchTime == lunchTime) &&
            (identical(other.dinnerTime, dinnerTime) ||
                other.dinnerTime == dinnerTime) &&
            (identical(other.morningSnackTime, morningSnackTime) ||
                other.morningSnackTime == morningSnackTime) &&
            (identical(other.afternoonSnackTime, afternoonSnackTime) ||
                other.afternoonSnackTime == afternoonSnackTime) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        odUserId,
        goal,
        targetWeightChangePerWeek,
        dietaryStyle,
        const DeepCollectionEquality().hash(_allergies),
        const DeepCollectionEquality().hash(_likedFoods),
        const DeepCollectionEquality().hash(_dislikedFoods),
        mealsPerDay,
        cookingSkill,
        maxPrepTimeMinutes,
        budget,
        mealRemindersEnabled,
        breakfastTime,
        lunchTime,
        dinnerTime,
        morningSnackTime,
        afternoonSnackTime,
        createdAt,
        updatedAt
      ]);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$DietPreferencesEntityImplCopyWith<_$DietPreferencesEntityImpl>
      get copyWith => __$$DietPreferencesEntityImplCopyWithImpl<
          _$DietPreferencesEntityImpl>(this, _$identity);
}

abstract class _DietPreferencesEntity implements DietPreferencesEntity {
  const factory _DietPreferencesEntity(
      {required final String odUserId,
      required final DietGoal goal,
      final double? targetWeightChangePerWeek,
      final DietaryStyle dietaryStyle,
      final List<UserAllergyEntity> allergies,
      final List<String> likedFoods,
      final List<String> dislikedFoods,
      final int mealsPerDay,
      final CookingSkill cookingSkill,
      final int maxPrepTimeMinutes,
      final BudgetPreference budget,
      final bool mealRemindersEnabled,
      final String? breakfastTime,
      final String? lunchTime,
      final String? dinnerTime,
      final String? morningSnackTime,
      final String? afternoonSnackTime,
      final DateTime? createdAt,
      final DateTime? updatedAt}) = _$DietPreferencesEntityImpl;

  @override
  String get odUserId;
  @override
  DietGoal get goal;
  @override
  double? get targetWeightChangePerWeek;
  @override // kg per week (negative for loss)
  DietaryStyle get dietaryStyle;
  @override
  List<UserAllergyEntity> get allergies;
  @override
  List<String> get likedFoods;
  @override
  List<String> get dislikedFoods;
  @override
  int get mealsPerDay;
  @override
  CookingSkill get cookingSkill;
  @override
  int get maxPrepTimeMinutes;
  @override
  BudgetPreference get budget;
  @override
  bool get mealRemindersEnabled;
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
  @override // "16:30"
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;
  @override
  @JsonKey(ignore: true)
  _$$DietPreferencesEntityImplCopyWith<_$DietPreferencesEntityImpl>
      get copyWith => throw _privateConstructorUsedError;
}
