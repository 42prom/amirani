// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'workout_preferences_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$UserInjuryEntity {
  @HiveField(0)
  InjuryType get type => throw _privateConstructorUsedError;
  @HiveField(1)
  InjurySeverity get severity => throw _privateConstructorUsedError;
  @HiveField(2)
  String? get customName =>
      throw _privateConstructorUsedError; // For "other" type
  @HiveField(3)
  String? get notes => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $UserInjuryEntityCopyWith<UserInjuryEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserInjuryEntityCopyWith<$Res> {
  factory $UserInjuryEntityCopyWith(
          UserInjuryEntity value, $Res Function(UserInjuryEntity) then) =
      _$UserInjuryEntityCopyWithImpl<$Res, UserInjuryEntity>;
  @useResult
  $Res call(
      {@HiveField(0) InjuryType type,
      @HiveField(1) InjurySeverity severity,
      @HiveField(2) String? customName,
      @HiveField(3) String? notes});
}

/// @nodoc
class _$UserInjuryEntityCopyWithImpl<$Res, $Val extends UserInjuryEntity>
    implements $UserInjuryEntityCopyWith<$Res> {
  _$UserInjuryEntityCopyWithImpl(this._value, this._then);

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
              as InjuryType,
      severity: null == severity
          ? _value.severity
          : severity // ignore: cast_nullable_to_non_nullable
              as InjurySeverity,
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
abstract class _$$UserInjuryEntityImplCopyWith<$Res>
    implements $UserInjuryEntityCopyWith<$Res> {
  factory _$$UserInjuryEntityImplCopyWith(_$UserInjuryEntityImpl value,
          $Res Function(_$UserInjuryEntityImpl) then) =
      __$$UserInjuryEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@HiveField(0) InjuryType type,
      @HiveField(1) InjurySeverity severity,
      @HiveField(2) String? customName,
      @HiveField(3) String? notes});
}

/// @nodoc
class __$$UserInjuryEntityImplCopyWithImpl<$Res>
    extends _$UserInjuryEntityCopyWithImpl<$Res, _$UserInjuryEntityImpl>
    implements _$$UserInjuryEntityImplCopyWith<$Res> {
  __$$UserInjuryEntityImplCopyWithImpl(_$UserInjuryEntityImpl _value,
      $Res Function(_$UserInjuryEntityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? severity = null,
    Object? customName = freezed,
    Object? notes = freezed,
  }) {
    return _then(_$UserInjuryEntityImpl(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as InjuryType,
      severity: null == severity
          ? _value.severity
          : severity // ignore: cast_nullable_to_non_nullable
              as InjurySeverity,
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

class _$UserInjuryEntityImpl implements _UserInjuryEntity {
  const _$UserInjuryEntityImpl(
      {@HiveField(0) required this.type,
      @HiveField(1) required this.severity,
      @HiveField(2) this.customName,
      @HiveField(3) this.notes});

  @override
  @HiveField(0)
  final InjuryType type;
  @override
  @HiveField(1)
  final InjurySeverity severity;
  @override
  @HiveField(2)
  final String? customName;
// For "other" type
  @override
  @HiveField(3)
  final String? notes;

  @override
  String toString() {
    return 'UserInjuryEntity(type: $type, severity: $severity, customName: $customName, notes: $notes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserInjuryEntityImpl &&
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
  _$$UserInjuryEntityImplCopyWith<_$UserInjuryEntityImpl> get copyWith =>
      __$$UserInjuryEntityImplCopyWithImpl<_$UserInjuryEntityImpl>(
          this, _$identity);
}

abstract class _UserInjuryEntity implements UserInjuryEntity {
  const factory _UserInjuryEntity(
      {@HiveField(0) required final InjuryType type,
      @HiveField(1) required final InjurySeverity severity,
      @HiveField(2) final String? customName,
      @HiveField(3) final String? notes}) = _$UserInjuryEntityImpl;

  @override
  @HiveField(0)
  InjuryType get type;
  @override
  @HiveField(1)
  InjurySeverity get severity;
  @override
  @HiveField(2)
  String? get customName;
  @override // For "other" type
  @HiveField(3)
  String? get notes;
  @override
  @JsonKey(ignore: true)
  _$$UserInjuryEntityImplCopyWith<_$UserInjuryEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$WorkoutPreferencesEntity {
  @HiveField(0)
  String get odUserId => throw _privateConstructorUsedError;
  @HiveField(1)
  WorkoutGoal get goal => throw _privateConstructorUsedError; // Training setup
  @HiveField(2)
  TrainingLocation get location => throw _privateConstructorUsedError;
  @HiveField(3)
  List<Equipment> get availableEquipment => throw _privateConstructorUsedError;
  @HiveField(4)
  List<String> get outOfOrderMachines => throw _privateConstructorUsedError;
  @HiveField(5)
  TrainingSplit get trainingSplit =>
      throw _privateConstructorUsedError; // Fitness profile
  @HiveField(6)
  FitnessLevel get fitnessLevel => throw _privateConstructorUsedError;
  @HiveField(7)
  int get experienceYears => throw _privateConstructorUsedError;
  @HiveField(8)
  List<UserInjuryEntity> get injuries =>
      throw _privateConstructorUsedError; // Exercise preferences
  @HiveField(9)
  List<String> get likedExercises => throw _privateConstructorUsedError;
  @HiveField(10)
  List<String> get dislikedExercises =>
      throw _privateConstructorUsedError; // Schedule
  @HiveField(11)
  int get daysPerWeek => throw _privateConstructorUsedError;
  @HiveField(12)
  List<int> get preferredDays =>
      throw _privateConstructorUsedError; // 0=Monday, 6=Sunday
  @HiveField(13)
  int get sessionDurationMinutes => throw _privateConstructorUsedError;
  @HiveField(14)
  PreferredWorkoutTime get preferredTime =>
      throw _privateConstructorUsedError; // Reminders
  @HiveField(15)
  bool get workoutRemindersEnabled => throw _privateConstructorUsedError;
  @HiveField(16)
  String? get reminderTime => throw _privateConstructorUsedError; // "08:00"
// Targets
  @HiveField(17)
  double? get targetWeightKg => throw _privateConstructorUsedError;
  @HiveField(18)
  int? get targetCaloriesBurnedPerSession => throw _privateConstructorUsedError;
  @HiveField(21)
  List<String> get targetMuscles => throw _privateConstructorUsedError;
  @HiveField(19)
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @HiveField(20)
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $WorkoutPreferencesEntityCopyWith<WorkoutPreferencesEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WorkoutPreferencesEntityCopyWith<$Res> {
  factory $WorkoutPreferencesEntityCopyWith(WorkoutPreferencesEntity value,
          $Res Function(WorkoutPreferencesEntity) then) =
      _$WorkoutPreferencesEntityCopyWithImpl<$Res, WorkoutPreferencesEntity>;
  @useResult
  $Res call(
      {@HiveField(0) String odUserId,
      @HiveField(1) WorkoutGoal goal,
      @HiveField(2) TrainingLocation location,
      @HiveField(3) List<Equipment> availableEquipment,
      @HiveField(4) List<String> outOfOrderMachines,
      @HiveField(5) TrainingSplit trainingSplit,
      @HiveField(6) FitnessLevel fitnessLevel,
      @HiveField(7) int experienceYears,
      @HiveField(8) List<UserInjuryEntity> injuries,
      @HiveField(9) List<String> likedExercises,
      @HiveField(10) List<String> dislikedExercises,
      @HiveField(11) int daysPerWeek,
      @HiveField(12) List<int> preferredDays,
      @HiveField(13) int sessionDurationMinutes,
      @HiveField(14) PreferredWorkoutTime preferredTime,
      @HiveField(15) bool workoutRemindersEnabled,
      @HiveField(16) String? reminderTime,
      @HiveField(17) double? targetWeightKg,
      @HiveField(18) int? targetCaloriesBurnedPerSession,
      @HiveField(21) List<String> targetMuscles,
      @HiveField(19) DateTime? createdAt,
      @HiveField(20) DateTime? updatedAt});
}

/// @nodoc
class _$WorkoutPreferencesEntityCopyWithImpl<$Res,
        $Val extends WorkoutPreferencesEntity>
    implements $WorkoutPreferencesEntityCopyWith<$Res> {
  _$WorkoutPreferencesEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? odUserId = null,
    Object? goal = null,
    Object? location = null,
    Object? availableEquipment = null,
    Object? outOfOrderMachines = null,
    Object? trainingSplit = null,
    Object? fitnessLevel = null,
    Object? experienceYears = null,
    Object? injuries = null,
    Object? likedExercises = null,
    Object? dislikedExercises = null,
    Object? daysPerWeek = null,
    Object? preferredDays = null,
    Object? sessionDurationMinutes = null,
    Object? preferredTime = null,
    Object? workoutRemindersEnabled = null,
    Object? reminderTime = freezed,
    Object? targetWeightKg = freezed,
    Object? targetCaloriesBurnedPerSession = freezed,
    Object? targetMuscles = null,
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
              as WorkoutGoal,
      location: null == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as TrainingLocation,
      availableEquipment: null == availableEquipment
          ? _value.availableEquipment
          : availableEquipment // ignore: cast_nullable_to_non_nullable
              as List<Equipment>,
      outOfOrderMachines: null == outOfOrderMachines
          ? _value.outOfOrderMachines
          : outOfOrderMachines // ignore: cast_nullable_to_non_nullable
              as List<String>,
      trainingSplit: null == trainingSplit
          ? _value.trainingSplit
          : trainingSplit // ignore: cast_nullable_to_non_nullable
              as TrainingSplit,
      fitnessLevel: null == fitnessLevel
          ? _value.fitnessLevel
          : fitnessLevel // ignore: cast_nullable_to_non_nullable
              as FitnessLevel,
      experienceYears: null == experienceYears
          ? _value.experienceYears
          : experienceYears // ignore: cast_nullable_to_non_nullable
              as int,
      injuries: null == injuries
          ? _value.injuries
          : injuries // ignore: cast_nullable_to_non_nullable
              as List<UserInjuryEntity>,
      likedExercises: null == likedExercises
          ? _value.likedExercises
          : likedExercises // ignore: cast_nullable_to_non_nullable
              as List<String>,
      dislikedExercises: null == dislikedExercises
          ? _value.dislikedExercises
          : dislikedExercises // ignore: cast_nullable_to_non_nullable
              as List<String>,
      daysPerWeek: null == daysPerWeek
          ? _value.daysPerWeek
          : daysPerWeek // ignore: cast_nullable_to_non_nullable
              as int,
      preferredDays: null == preferredDays
          ? _value.preferredDays
          : preferredDays // ignore: cast_nullable_to_non_nullable
              as List<int>,
      sessionDurationMinutes: null == sessionDurationMinutes
          ? _value.sessionDurationMinutes
          : sessionDurationMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      preferredTime: null == preferredTime
          ? _value.preferredTime
          : preferredTime // ignore: cast_nullable_to_non_nullable
              as PreferredWorkoutTime,
      workoutRemindersEnabled: null == workoutRemindersEnabled
          ? _value.workoutRemindersEnabled
          : workoutRemindersEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      reminderTime: freezed == reminderTime
          ? _value.reminderTime
          : reminderTime // ignore: cast_nullable_to_non_nullable
              as String?,
      targetWeightKg: freezed == targetWeightKg
          ? _value.targetWeightKg
          : targetWeightKg // ignore: cast_nullable_to_non_nullable
              as double?,
      targetCaloriesBurnedPerSession: freezed == targetCaloriesBurnedPerSession
          ? _value.targetCaloriesBurnedPerSession
          : targetCaloriesBurnedPerSession // ignore: cast_nullable_to_non_nullable
              as int?,
      targetMuscles: null == targetMuscles
          ? _value.targetMuscles
          : targetMuscles // ignore: cast_nullable_to_non_nullable
              as List<String>,
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
abstract class _$$WorkoutPreferencesEntityImplCopyWith<$Res>
    implements $WorkoutPreferencesEntityCopyWith<$Res> {
  factory _$$WorkoutPreferencesEntityImplCopyWith(
          _$WorkoutPreferencesEntityImpl value,
          $Res Function(_$WorkoutPreferencesEntityImpl) then) =
      __$$WorkoutPreferencesEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@HiveField(0) String odUserId,
      @HiveField(1) WorkoutGoal goal,
      @HiveField(2) TrainingLocation location,
      @HiveField(3) List<Equipment> availableEquipment,
      @HiveField(4) List<String> outOfOrderMachines,
      @HiveField(5) TrainingSplit trainingSplit,
      @HiveField(6) FitnessLevel fitnessLevel,
      @HiveField(7) int experienceYears,
      @HiveField(8) List<UserInjuryEntity> injuries,
      @HiveField(9) List<String> likedExercises,
      @HiveField(10) List<String> dislikedExercises,
      @HiveField(11) int daysPerWeek,
      @HiveField(12) List<int> preferredDays,
      @HiveField(13) int sessionDurationMinutes,
      @HiveField(14) PreferredWorkoutTime preferredTime,
      @HiveField(15) bool workoutRemindersEnabled,
      @HiveField(16) String? reminderTime,
      @HiveField(17) double? targetWeightKg,
      @HiveField(18) int? targetCaloriesBurnedPerSession,
      @HiveField(21) List<String> targetMuscles,
      @HiveField(19) DateTime? createdAt,
      @HiveField(20) DateTime? updatedAt});
}

/// @nodoc
class __$$WorkoutPreferencesEntityImplCopyWithImpl<$Res>
    extends _$WorkoutPreferencesEntityCopyWithImpl<$Res,
        _$WorkoutPreferencesEntityImpl>
    implements _$$WorkoutPreferencesEntityImplCopyWith<$Res> {
  __$$WorkoutPreferencesEntityImplCopyWithImpl(
      _$WorkoutPreferencesEntityImpl _value,
      $Res Function(_$WorkoutPreferencesEntityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? odUserId = null,
    Object? goal = null,
    Object? location = null,
    Object? availableEquipment = null,
    Object? outOfOrderMachines = null,
    Object? trainingSplit = null,
    Object? fitnessLevel = null,
    Object? experienceYears = null,
    Object? injuries = null,
    Object? likedExercises = null,
    Object? dislikedExercises = null,
    Object? daysPerWeek = null,
    Object? preferredDays = null,
    Object? sessionDurationMinutes = null,
    Object? preferredTime = null,
    Object? workoutRemindersEnabled = null,
    Object? reminderTime = freezed,
    Object? targetWeightKg = freezed,
    Object? targetCaloriesBurnedPerSession = freezed,
    Object? targetMuscles = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_$WorkoutPreferencesEntityImpl(
      odUserId: null == odUserId
          ? _value.odUserId
          : odUserId // ignore: cast_nullable_to_non_nullable
              as String,
      goal: null == goal
          ? _value.goal
          : goal // ignore: cast_nullable_to_non_nullable
              as WorkoutGoal,
      location: null == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as TrainingLocation,
      availableEquipment: null == availableEquipment
          ? _value._availableEquipment
          : availableEquipment // ignore: cast_nullable_to_non_nullable
              as List<Equipment>,
      outOfOrderMachines: null == outOfOrderMachines
          ? _value._outOfOrderMachines
          : outOfOrderMachines // ignore: cast_nullable_to_non_nullable
              as List<String>,
      trainingSplit: null == trainingSplit
          ? _value.trainingSplit
          : trainingSplit // ignore: cast_nullable_to_non_nullable
              as TrainingSplit,
      fitnessLevel: null == fitnessLevel
          ? _value.fitnessLevel
          : fitnessLevel // ignore: cast_nullable_to_non_nullable
              as FitnessLevel,
      experienceYears: null == experienceYears
          ? _value.experienceYears
          : experienceYears // ignore: cast_nullable_to_non_nullable
              as int,
      injuries: null == injuries
          ? _value._injuries
          : injuries // ignore: cast_nullable_to_non_nullable
              as List<UserInjuryEntity>,
      likedExercises: null == likedExercises
          ? _value._likedExercises
          : likedExercises // ignore: cast_nullable_to_non_nullable
              as List<String>,
      dislikedExercises: null == dislikedExercises
          ? _value._dislikedExercises
          : dislikedExercises // ignore: cast_nullable_to_non_nullable
              as List<String>,
      daysPerWeek: null == daysPerWeek
          ? _value.daysPerWeek
          : daysPerWeek // ignore: cast_nullable_to_non_nullable
              as int,
      preferredDays: null == preferredDays
          ? _value._preferredDays
          : preferredDays // ignore: cast_nullable_to_non_nullable
              as List<int>,
      sessionDurationMinutes: null == sessionDurationMinutes
          ? _value.sessionDurationMinutes
          : sessionDurationMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      preferredTime: null == preferredTime
          ? _value.preferredTime
          : preferredTime // ignore: cast_nullable_to_non_nullable
              as PreferredWorkoutTime,
      workoutRemindersEnabled: null == workoutRemindersEnabled
          ? _value.workoutRemindersEnabled
          : workoutRemindersEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      reminderTime: freezed == reminderTime
          ? _value.reminderTime
          : reminderTime // ignore: cast_nullable_to_non_nullable
              as String?,
      targetWeightKg: freezed == targetWeightKg
          ? _value.targetWeightKg
          : targetWeightKg // ignore: cast_nullable_to_non_nullable
              as double?,
      targetCaloriesBurnedPerSession: freezed == targetCaloriesBurnedPerSession
          ? _value.targetCaloriesBurnedPerSession
          : targetCaloriesBurnedPerSession // ignore: cast_nullable_to_non_nullable
              as int?,
      targetMuscles: null == targetMuscles
          ? _value._targetMuscles
          : targetMuscles // ignore: cast_nullable_to_non_nullable
              as List<String>,
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

class _$WorkoutPreferencesEntityImpl implements _WorkoutPreferencesEntity {
  const _$WorkoutPreferencesEntityImpl(
      {@HiveField(0) required this.odUserId,
      @HiveField(1) required this.goal,
      @HiveField(2) this.location = TrainingLocation.home,
      @HiveField(3) final List<Equipment> availableEquipment = const [
        Equipment.bodyweightOnly
      ],
      @HiveField(4) final List<String> outOfOrderMachines = const [],
      @HiveField(5) this.trainingSplit = TrainingSplit.fullBody,
      @HiveField(6) this.fitnessLevel = FitnessLevel.beginner,
      @HiveField(7) this.experienceYears = 0,
      @HiveField(8) final List<UserInjuryEntity> injuries = const [],
      @HiveField(9) final List<String> likedExercises = const [],
      @HiveField(10) final List<String> dislikedExercises = const [],
      @HiveField(11) this.daysPerWeek = 3,
      @HiveField(12) final List<int> preferredDays = const [],
      @HiveField(13) this.sessionDurationMinutes = 45,
      @HiveField(14) this.preferredTime = PreferredWorkoutTime.morning,
      @HiveField(15) this.workoutRemindersEnabled = true,
      @HiveField(16) this.reminderTime,
      @HiveField(17) this.targetWeightKg,
      @HiveField(18) this.targetCaloriesBurnedPerSession,
      @HiveField(21) final List<String> targetMuscles = const [],
      @HiveField(19) this.createdAt,
      @HiveField(20) this.updatedAt})
      : _availableEquipment = availableEquipment,
        _outOfOrderMachines = outOfOrderMachines,
        _injuries = injuries,
        _likedExercises = likedExercises,
        _dislikedExercises = dislikedExercises,
        _preferredDays = preferredDays,
        _targetMuscles = targetMuscles;

  @override
  @HiveField(0)
  final String odUserId;
  @override
  @HiveField(1)
  final WorkoutGoal goal;
// Training setup
  @override
  @JsonKey()
  @HiveField(2)
  final TrainingLocation location;
  final List<Equipment> _availableEquipment;
  @override
  @JsonKey()
  @HiveField(3)
  List<Equipment> get availableEquipment {
    if (_availableEquipment is EqualUnmodifiableListView)
      return _availableEquipment;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_availableEquipment);
  }

  final List<String> _outOfOrderMachines;
  @override
  @JsonKey()
  @HiveField(4)
  List<String> get outOfOrderMachines {
    if (_outOfOrderMachines is EqualUnmodifiableListView)
      return _outOfOrderMachines;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_outOfOrderMachines);
  }

  @override
  @JsonKey()
  @HiveField(5)
  final TrainingSplit trainingSplit;
// Fitness profile
  @override
  @JsonKey()
  @HiveField(6)
  final FitnessLevel fitnessLevel;
  @override
  @JsonKey()
  @HiveField(7)
  final int experienceYears;
  final List<UserInjuryEntity> _injuries;
  @override
  @JsonKey()
  @HiveField(8)
  List<UserInjuryEntity> get injuries {
    if (_injuries is EqualUnmodifiableListView) return _injuries;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_injuries);
  }

// Exercise preferences
  final List<String> _likedExercises;
// Exercise preferences
  @override
  @JsonKey()
  @HiveField(9)
  List<String> get likedExercises {
    if (_likedExercises is EqualUnmodifiableListView) return _likedExercises;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_likedExercises);
  }

  final List<String> _dislikedExercises;
  @override
  @JsonKey()
  @HiveField(10)
  List<String> get dislikedExercises {
    if (_dislikedExercises is EqualUnmodifiableListView)
      return _dislikedExercises;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_dislikedExercises);
  }

// Schedule
  @override
  @JsonKey()
  @HiveField(11)
  final int daysPerWeek;
  final List<int> _preferredDays;
  @override
  @JsonKey()
  @HiveField(12)
  List<int> get preferredDays {
    if (_preferredDays is EqualUnmodifiableListView) return _preferredDays;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_preferredDays);
  }

// 0=Monday, 6=Sunday
  @override
  @JsonKey()
  @HiveField(13)
  final int sessionDurationMinutes;
  @override
  @JsonKey()
  @HiveField(14)
  final PreferredWorkoutTime preferredTime;
// Reminders
  @override
  @JsonKey()
  @HiveField(15)
  final bool workoutRemindersEnabled;
  @override
  @HiveField(16)
  final String? reminderTime;
// "08:00"
// Targets
  @override
  @HiveField(17)
  final double? targetWeightKg;
  @override
  @HiveField(18)
  final int? targetCaloriesBurnedPerSession;
  final List<String> _targetMuscles;
  @override
  @JsonKey()
  @HiveField(21)
  List<String> get targetMuscles {
    if (_targetMuscles is EqualUnmodifiableListView) return _targetMuscles;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_targetMuscles);
  }

  @override
  @HiveField(19)
  final DateTime? createdAt;
  @override
  @HiveField(20)
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'WorkoutPreferencesEntity(odUserId: $odUserId, goal: $goal, location: $location, availableEquipment: $availableEquipment, outOfOrderMachines: $outOfOrderMachines, trainingSplit: $trainingSplit, fitnessLevel: $fitnessLevel, experienceYears: $experienceYears, injuries: $injuries, likedExercises: $likedExercises, dislikedExercises: $dislikedExercises, daysPerWeek: $daysPerWeek, preferredDays: $preferredDays, sessionDurationMinutes: $sessionDurationMinutes, preferredTime: $preferredTime, workoutRemindersEnabled: $workoutRemindersEnabled, reminderTime: $reminderTime, targetWeightKg: $targetWeightKg, targetCaloriesBurnedPerSession: $targetCaloriesBurnedPerSession, targetMuscles: $targetMuscles, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WorkoutPreferencesEntityImpl &&
            (identical(other.odUserId, odUserId) ||
                other.odUserId == odUserId) &&
            (identical(other.goal, goal) || other.goal == goal) &&
            (identical(other.location, location) ||
                other.location == location) &&
            const DeepCollectionEquality()
                .equals(other._availableEquipment, _availableEquipment) &&
            const DeepCollectionEquality()
                .equals(other._outOfOrderMachines, _outOfOrderMachines) &&
            (identical(other.trainingSplit, trainingSplit) ||
                other.trainingSplit == trainingSplit) &&
            (identical(other.fitnessLevel, fitnessLevel) ||
                other.fitnessLevel == fitnessLevel) &&
            (identical(other.experienceYears, experienceYears) ||
                other.experienceYears == experienceYears) &&
            const DeepCollectionEquality().equals(other._injuries, _injuries) &&
            const DeepCollectionEquality()
                .equals(other._likedExercises, _likedExercises) &&
            const DeepCollectionEquality()
                .equals(other._dislikedExercises, _dislikedExercises) &&
            (identical(other.daysPerWeek, daysPerWeek) ||
                other.daysPerWeek == daysPerWeek) &&
            const DeepCollectionEquality()
                .equals(other._preferredDays, _preferredDays) &&
            (identical(other.sessionDurationMinutes, sessionDurationMinutes) ||
                other.sessionDurationMinutes == sessionDurationMinutes) &&
            (identical(other.preferredTime, preferredTime) ||
                other.preferredTime == preferredTime) &&
            (identical(
                    other.workoutRemindersEnabled, workoutRemindersEnabled) ||
                other.workoutRemindersEnabled == workoutRemindersEnabled) &&
            (identical(other.reminderTime, reminderTime) ||
                other.reminderTime == reminderTime) &&
            (identical(other.targetWeightKg, targetWeightKg) ||
                other.targetWeightKg == targetWeightKg) &&
            (identical(other.targetCaloriesBurnedPerSession,
                    targetCaloriesBurnedPerSession) ||
                other.targetCaloriesBurnedPerSession ==
                    targetCaloriesBurnedPerSession) &&
            const DeepCollectionEquality()
                .equals(other._targetMuscles, _targetMuscles) &&
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
        location,
        const DeepCollectionEquality().hash(_availableEquipment),
        const DeepCollectionEquality().hash(_outOfOrderMachines),
        trainingSplit,
        fitnessLevel,
        experienceYears,
        const DeepCollectionEquality().hash(_injuries),
        const DeepCollectionEquality().hash(_likedExercises),
        const DeepCollectionEquality().hash(_dislikedExercises),
        daysPerWeek,
        const DeepCollectionEquality().hash(_preferredDays),
        sessionDurationMinutes,
        preferredTime,
        workoutRemindersEnabled,
        reminderTime,
        targetWeightKg,
        targetCaloriesBurnedPerSession,
        const DeepCollectionEquality().hash(_targetMuscles),
        createdAt,
        updatedAt
      ]);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$WorkoutPreferencesEntityImplCopyWith<_$WorkoutPreferencesEntityImpl>
      get copyWith => __$$WorkoutPreferencesEntityImplCopyWithImpl<
          _$WorkoutPreferencesEntityImpl>(this, _$identity);
}

abstract class _WorkoutPreferencesEntity implements WorkoutPreferencesEntity {
  const factory _WorkoutPreferencesEntity(
          {@HiveField(0) required final String odUserId,
          @HiveField(1) required final WorkoutGoal goal,
          @HiveField(2) final TrainingLocation location,
          @HiveField(3) final List<Equipment> availableEquipment,
          @HiveField(4) final List<String> outOfOrderMachines,
          @HiveField(5) final TrainingSplit trainingSplit,
          @HiveField(6) final FitnessLevel fitnessLevel,
          @HiveField(7) final int experienceYears,
          @HiveField(8) final List<UserInjuryEntity> injuries,
          @HiveField(9) final List<String> likedExercises,
          @HiveField(10) final List<String> dislikedExercises,
          @HiveField(11) final int daysPerWeek,
          @HiveField(12) final List<int> preferredDays,
          @HiveField(13) final int sessionDurationMinutes,
          @HiveField(14) final PreferredWorkoutTime preferredTime,
          @HiveField(15) final bool workoutRemindersEnabled,
          @HiveField(16) final String? reminderTime,
          @HiveField(17) final double? targetWeightKg,
          @HiveField(18) final int? targetCaloriesBurnedPerSession,
          @HiveField(21) final List<String> targetMuscles,
          @HiveField(19) final DateTime? createdAt,
          @HiveField(20) final DateTime? updatedAt}) =
      _$WorkoutPreferencesEntityImpl;

  @override
  @HiveField(0)
  String get odUserId;
  @override
  @HiveField(1)
  WorkoutGoal get goal;
  @override // Training setup
  @HiveField(2)
  TrainingLocation get location;
  @override
  @HiveField(3)
  List<Equipment> get availableEquipment;
  @override
  @HiveField(4)
  List<String> get outOfOrderMachines;
  @override
  @HiveField(5)
  TrainingSplit get trainingSplit;
  @override // Fitness profile
  @HiveField(6)
  FitnessLevel get fitnessLevel;
  @override
  @HiveField(7)
  int get experienceYears;
  @override
  @HiveField(8)
  List<UserInjuryEntity> get injuries;
  @override // Exercise preferences
  @HiveField(9)
  List<String> get likedExercises;
  @override
  @HiveField(10)
  List<String> get dislikedExercises;
  @override // Schedule
  @HiveField(11)
  int get daysPerWeek;
  @override
  @HiveField(12)
  List<int> get preferredDays;
  @override // 0=Monday, 6=Sunday
  @HiveField(13)
  int get sessionDurationMinutes;
  @override
  @HiveField(14)
  PreferredWorkoutTime get preferredTime;
  @override // Reminders
  @HiveField(15)
  bool get workoutRemindersEnabled;
  @override
  @HiveField(16)
  String? get reminderTime;
  @override // "08:00"
// Targets
  @HiveField(17)
  double? get targetWeightKg;
  @override
  @HiveField(18)
  int? get targetCaloriesBurnedPerSession;
  @override
  @HiveField(21)
  List<String> get targetMuscles;
  @override
  @HiveField(19)
  DateTime? get createdAt;
  @override
  @HiveField(20)
  DateTime? get updatedAt;
  @override
  @JsonKey(ignore: true)
  _$$WorkoutPreferencesEntityImplCopyWith<_$WorkoutPreferencesEntityImpl>
      get copyWith => throw _privateConstructorUsedError;
}
