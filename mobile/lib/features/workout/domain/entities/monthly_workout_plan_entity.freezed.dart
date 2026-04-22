// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'monthly_workout_plan_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$ExerciseSetEntity {
  @HiveField(0)
  int get setNumber => throw _privateConstructorUsedError;
  @HiveField(1)
  int get targetReps => throw _privateConstructorUsedError;
  @HiveField(13)
  int? get targetRepsMax =>
      throw _privateConstructorUsedError; // P2-E: upper rep bound for progressive overload
  @HiveField(2)
  int? get targetSeconds =>
      throw _privateConstructorUsedError; // For timed exercises like plank
  @HiveField(3)
  double? get targetWeight =>
      throw _privateConstructorUsedError; // kg, null for bodyweight
  @HiveField(4)
  int get restSeconds => throw _privateConstructorUsedError;
  @HiveField(5)
  bool get isCompleted => throw _privateConstructorUsedError;
  @HiveField(6)
  int? get actualReps => throw _privateConstructorUsedError;
  @HiveField(7)
  double? get actualWeight => throw _privateConstructorUsedError;
  @HiveField(8)
  DateTime? get completedAt => throw _privateConstructorUsedError;
  @HiveField(9)
  double? get rpe => throw _privateConstructorUsedError;
  @HiveField(10)
  int? get tempoEccentric => throw _privateConstructorUsedError;
  @HiveField(11)
  int? get tempoPause => throw _privateConstructorUsedError;
  @HiveField(12)
  int? get tempoConcentric => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $ExerciseSetEntityCopyWith<ExerciseSetEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ExerciseSetEntityCopyWith<$Res> {
  factory $ExerciseSetEntityCopyWith(
          ExerciseSetEntity value, $Res Function(ExerciseSetEntity) then) =
      _$ExerciseSetEntityCopyWithImpl<$Res, ExerciseSetEntity>;
  @useResult
  $Res call(
      {@HiveField(0) int setNumber,
      @HiveField(1) int targetReps,
      @HiveField(13) int? targetRepsMax,
      @HiveField(2) int? targetSeconds,
      @HiveField(3) double? targetWeight,
      @HiveField(4) int restSeconds,
      @HiveField(5) bool isCompleted,
      @HiveField(6) int? actualReps,
      @HiveField(7) double? actualWeight,
      @HiveField(8) DateTime? completedAt,
      @HiveField(9) double? rpe,
      @HiveField(10) int? tempoEccentric,
      @HiveField(11) int? tempoPause,
      @HiveField(12) int? tempoConcentric});
}

/// @nodoc
class _$ExerciseSetEntityCopyWithImpl<$Res, $Val extends ExerciseSetEntity>
    implements $ExerciseSetEntityCopyWith<$Res> {
  _$ExerciseSetEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? setNumber = null,
    Object? targetReps = null,
    Object? targetRepsMax = freezed,
    Object? targetSeconds = freezed,
    Object? targetWeight = freezed,
    Object? restSeconds = null,
    Object? isCompleted = null,
    Object? actualReps = freezed,
    Object? actualWeight = freezed,
    Object? completedAt = freezed,
    Object? rpe = freezed,
    Object? tempoEccentric = freezed,
    Object? tempoPause = freezed,
    Object? tempoConcentric = freezed,
  }) {
    return _then(_value.copyWith(
      setNumber: null == setNumber
          ? _value.setNumber
          : setNumber // ignore: cast_nullable_to_non_nullable
              as int,
      targetReps: null == targetReps
          ? _value.targetReps
          : targetReps // ignore: cast_nullable_to_non_nullable
              as int,
      targetRepsMax: freezed == targetRepsMax
          ? _value.targetRepsMax
          : targetRepsMax // ignore: cast_nullable_to_non_nullable
              as int?,
      targetSeconds: freezed == targetSeconds
          ? _value.targetSeconds
          : targetSeconds // ignore: cast_nullable_to_non_nullable
              as int?,
      targetWeight: freezed == targetWeight
          ? _value.targetWeight
          : targetWeight // ignore: cast_nullable_to_non_nullable
              as double?,
      restSeconds: null == restSeconds
          ? _value.restSeconds
          : restSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      isCompleted: null == isCompleted
          ? _value.isCompleted
          : isCompleted // ignore: cast_nullable_to_non_nullable
              as bool,
      actualReps: freezed == actualReps
          ? _value.actualReps
          : actualReps // ignore: cast_nullable_to_non_nullable
              as int?,
      actualWeight: freezed == actualWeight
          ? _value.actualWeight
          : actualWeight // ignore: cast_nullable_to_non_nullable
              as double?,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      rpe: freezed == rpe
          ? _value.rpe
          : rpe // ignore: cast_nullable_to_non_nullable
              as double?,
      tempoEccentric: freezed == tempoEccentric
          ? _value.tempoEccentric
          : tempoEccentric // ignore: cast_nullable_to_non_nullable
              as int?,
      tempoPause: freezed == tempoPause
          ? _value.tempoPause
          : tempoPause // ignore: cast_nullable_to_non_nullable
              as int?,
      tempoConcentric: freezed == tempoConcentric
          ? _value.tempoConcentric
          : tempoConcentric // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ExerciseSetEntityImplCopyWith<$Res>
    implements $ExerciseSetEntityCopyWith<$Res> {
  factory _$$ExerciseSetEntityImplCopyWith(_$ExerciseSetEntityImpl value,
          $Res Function(_$ExerciseSetEntityImpl) then) =
      __$$ExerciseSetEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@HiveField(0) int setNumber,
      @HiveField(1) int targetReps,
      @HiveField(13) int? targetRepsMax,
      @HiveField(2) int? targetSeconds,
      @HiveField(3) double? targetWeight,
      @HiveField(4) int restSeconds,
      @HiveField(5) bool isCompleted,
      @HiveField(6) int? actualReps,
      @HiveField(7) double? actualWeight,
      @HiveField(8) DateTime? completedAt,
      @HiveField(9) double? rpe,
      @HiveField(10) int? tempoEccentric,
      @HiveField(11) int? tempoPause,
      @HiveField(12) int? tempoConcentric});
}

/// @nodoc
class __$$ExerciseSetEntityImplCopyWithImpl<$Res>
    extends _$ExerciseSetEntityCopyWithImpl<$Res, _$ExerciseSetEntityImpl>
    implements _$$ExerciseSetEntityImplCopyWith<$Res> {
  __$$ExerciseSetEntityImplCopyWithImpl(_$ExerciseSetEntityImpl _value,
      $Res Function(_$ExerciseSetEntityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? setNumber = null,
    Object? targetReps = null,
    Object? targetRepsMax = freezed,
    Object? targetSeconds = freezed,
    Object? targetWeight = freezed,
    Object? restSeconds = null,
    Object? isCompleted = null,
    Object? actualReps = freezed,
    Object? actualWeight = freezed,
    Object? completedAt = freezed,
    Object? rpe = freezed,
    Object? tempoEccentric = freezed,
    Object? tempoPause = freezed,
    Object? tempoConcentric = freezed,
  }) {
    return _then(_$ExerciseSetEntityImpl(
      setNumber: null == setNumber
          ? _value.setNumber
          : setNumber // ignore: cast_nullable_to_non_nullable
              as int,
      targetReps: null == targetReps
          ? _value.targetReps
          : targetReps // ignore: cast_nullable_to_non_nullable
              as int,
      targetRepsMax: freezed == targetRepsMax
          ? _value.targetRepsMax
          : targetRepsMax // ignore: cast_nullable_to_non_nullable
              as int?,
      targetSeconds: freezed == targetSeconds
          ? _value.targetSeconds
          : targetSeconds // ignore: cast_nullable_to_non_nullable
              as int?,
      targetWeight: freezed == targetWeight
          ? _value.targetWeight
          : targetWeight // ignore: cast_nullable_to_non_nullable
              as double?,
      restSeconds: null == restSeconds
          ? _value.restSeconds
          : restSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      isCompleted: null == isCompleted
          ? _value.isCompleted
          : isCompleted // ignore: cast_nullable_to_non_nullable
              as bool,
      actualReps: freezed == actualReps
          ? _value.actualReps
          : actualReps // ignore: cast_nullable_to_non_nullable
              as int?,
      actualWeight: freezed == actualWeight
          ? _value.actualWeight
          : actualWeight // ignore: cast_nullable_to_non_nullable
              as double?,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      rpe: freezed == rpe
          ? _value.rpe
          : rpe // ignore: cast_nullable_to_non_nullable
              as double?,
      tempoEccentric: freezed == tempoEccentric
          ? _value.tempoEccentric
          : tempoEccentric // ignore: cast_nullable_to_non_nullable
              as int?,
      tempoPause: freezed == tempoPause
          ? _value.tempoPause
          : tempoPause // ignore: cast_nullable_to_non_nullable
              as int?,
      tempoConcentric: freezed == tempoConcentric
          ? _value.tempoConcentric
          : tempoConcentric // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc

class _$ExerciseSetEntityImpl implements _ExerciseSetEntity {
  const _$ExerciseSetEntityImpl(
      {@HiveField(0) required this.setNumber,
      @HiveField(1) required this.targetReps,
      @HiveField(13) this.targetRepsMax,
      @HiveField(2) this.targetSeconds,
      @HiveField(3) this.targetWeight,
      @HiveField(4) this.restSeconds = 60,
      @HiveField(5) this.isCompleted = false,
      @HiveField(6) this.actualReps,
      @HiveField(7) this.actualWeight,
      @HiveField(8) this.completedAt,
      @HiveField(9) this.rpe,
      @HiveField(10) this.tempoEccentric,
      @HiveField(11) this.tempoPause,
      @HiveField(12) this.tempoConcentric});

  @override
  @HiveField(0)
  final int setNumber;
  @override
  @HiveField(1)
  final int targetReps;
  @override
  @HiveField(13)
  final int? targetRepsMax;
// P2-E: upper rep bound for progressive overload
  @override
  @HiveField(2)
  final int? targetSeconds;
// For timed exercises like plank
  @override
  @HiveField(3)
  final double? targetWeight;
// kg, null for bodyweight
  @override
  @JsonKey()
  @HiveField(4)
  final int restSeconds;
  @override
  @JsonKey()
  @HiveField(5)
  final bool isCompleted;
  @override
  @HiveField(6)
  final int? actualReps;
  @override
  @HiveField(7)
  final double? actualWeight;
  @override
  @HiveField(8)
  final DateTime? completedAt;
  @override
  @HiveField(9)
  final double? rpe;
  @override
  @HiveField(10)
  final int? tempoEccentric;
  @override
  @HiveField(11)
  final int? tempoPause;
  @override
  @HiveField(12)
  final int? tempoConcentric;

  @override
  String toString() {
    return 'ExerciseSetEntity(setNumber: $setNumber, targetReps: $targetReps, targetRepsMax: $targetRepsMax, targetSeconds: $targetSeconds, targetWeight: $targetWeight, restSeconds: $restSeconds, isCompleted: $isCompleted, actualReps: $actualReps, actualWeight: $actualWeight, completedAt: $completedAt, rpe: $rpe, tempoEccentric: $tempoEccentric, tempoPause: $tempoPause, tempoConcentric: $tempoConcentric)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ExerciseSetEntityImpl &&
            (identical(other.setNumber, setNumber) ||
                other.setNumber == setNumber) &&
            (identical(other.targetReps, targetReps) ||
                other.targetReps == targetReps) &&
            (identical(other.targetRepsMax, targetRepsMax) ||
                other.targetRepsMax == targetRepsMax) &&
            (identical(other.targetSeconds, targetSeconds) ||
                other.targetSeconds == targetSeconds) &&
            (identical(other.targetWeight, targetWeight) ||
                other.targetWeight == targetWeight) &&
            (identical(other.restSeconds, restSeconds) ||
                other.restSeconds == restSeconds) &&
            (identical(other.isCompleted, isCompleted) ||
                other.isCompleted == isCompleted) &&
            (identical(other.actualReps, actualReps) ||
                other.actualReps == actualReps) &&
            (identical(other.actualWeight, actualWeight) ||
                other.actualWeight == actualWeight) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.rpe, rpe) || other.rpe == rpe) &&
            (identical(other.tempoEccentric, tempoEccentric) ||
                other.tempoEccentric == tempoEccentric) &&
            (identical(other.tempoPause, tempoPause) ||
                other.tempoPause == tempoPause) &&
            (identical(other.tempoConcentric, tempoConcentric) ||
                other.tempoConcentric == tempoConcentric));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      setNumber,
      targetReps,
      targetRepsMax,
      targetSeconds,
      targetWeight,
      restSeconds,
      isCompleted,
      actualReps,
      actualWeight,
      completedAt,
      rpe,
      tempoEccentric,
      tempoPause,
      tempoConcentric);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ExerciseSetEntityImplCopyWith<_$ExerciseSetEntityImpl> get copyWith =>
      __$$ExerciseSetEntityImplCopyWithImpl<_$ExerciseSetEntityImpl>(
          this, _$identity);
}

abstract class _ExerciseSetEntity implements ExerciseSetEntity {
  const factory _ExerciseSetEntity(
      {@HiveField(0) required final int setNumber,
      @HiveField(1) required final int targetReps,
      @HiveField(13) final int? targetRepsMax,
      @HiveField(2) final int? targetSeconds,
      @HiveField(3) final double? targetWeight,
      @HiveField(4) final int restSeconds,
      @HiveField(5) final bool isCompleted,
      @HiveField(6) final int? actualReps,
      @HiveField(7) final double? actualWeight,
      @HiveField(8) final DateTime? completedAt,
      @HiveField(9) final double? rpe,
      @HiveField(10) final int? tempoEccentric,
      @HiveField(11) final int? tempoPause,
      @HiveField(12) final int? tempoConcentric}) = _$ExerciseSetEntityImpl;

  @override
  @HiveField(0)
  int get setNumber;
  @override
  @HiveField(1)
  int get targetReps;
  @override
  @HiveField(13)
  int? get targetRepsMax;
  @override // P2-E: upper rep bound for progressive overload
  @HiveField(2)
  int? get targetSeconds;
  @override // For timed exercises like plank
  @HiveField(3)
  double? get targetWeight;
  @override // kg, null for bodyweight
  @HiveField(4)
  int get restSeconds;
  @override
  @HiveField(5)
  bool get isCompleted;
  @override
  @HiveField(6)
  int? get actualReps;
  @override
  @HiveField(7)
  double? get actualWeight;
  @override
  @HiveField(8)
  DateTime? get completedAt;
  @override
  @HiveField(9)
  double? get rpe;
  @override
  @HiveField(10)
  int? get tempoEccentric;
  @override
  @HiveField(11)
  int? get tempoPause;
  @override
  @HiveField(12)
  int? get tempoConcentric;
  @override
  @JsonKey(ignore: true)
  _$$ExerciseSetEntityImplCopyWith<_$ExerciseSetEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$PlannedExerciseEntity {
  @HiveField(0)
  String get id => throw _privateConstructorUsedError;
  @HiveField(1)
  String get name => throw _privateConstructorUsedError;
  @HiveField(2)
  String get description => throw _privateConstructorUsedError;
  @HiveField(3)
  List<MuscleGroup> get targetMuscles => throw _privateConstructorUsedError;
  @HiveField(4)
  ExerciseDifficulty get difficulty => throw _privateConstructorUsedError;
  @HiveField(5)
  List<ExerciseSetEntity> get sets => throw _privateConstructorUsedError;
  @HiveField(6)
  List<Equipment> get requiredEquipment => throw _privateConstructorUsedError;
  @HiveField(7)
  String? get imageUrl => throw _privateConstructorUsedError;
  @HiveField(8)
  String? get videoUrl => throw _privateConstructorUsedError;
  @HiveField(9)
  String? get instructions => throw _privateConstructorUsedError;
  @HiveField(10)
  bool get isCompleted => throw _privateConstructorUsedError;
  @HiveField(11)
  bool get isSwapped => throw _privateConstructorUsedError;
  @HiveField(12)
  bool get isSkipped => throw _privateConstructorUsedError;
  @HiveField(13)
  DateTime? get completedAt => throw _privateConstructorUsedError;
  @HiveField(14)
  String? get progressionNote => throw _privateConstructorUsedError;
  @HiveField(15)
  double? get rpe => throw _privateConstructorUsedError;
  @HiveField(16)
  double? get targetWeight => throw _privateConstructorUsedError;
  @HiveField(17)
  int? get tempoEccentric => throw _privateConstructorUsedError;
  @HiveField(18)
  int? get tempoPause => throw _privateConstructorUsedError;
  @HiveField(19)
  int? get tempoConcentric => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $PlannedExerciseEntityCopyWith<PlannedExerciseEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlannedExerciseEntityCopyWith<$Res> {
  factory $PlannedExerciseEntityCopyWith(PlannedExerciseEntity value,
          $Res Function(PlannedExerciseEntity) then) =
      _$PlannedExerciseEntityCopyWithImpl<$Res, PlannedExerciseEntity>;
  @useResult
  $Res call(
      {@HiveField(0) String id,
      @HiveField(1) String name,
      @HiveField(2) String description,
      @HiveField(3) List<MuscleGroup> targetMuscles,
      @HiveField(4) ExerciseDifficulty difficulty,
      @HiveField(5) List<ExerciseSetEntity> sets,
      @HiveField(6) List<Equipment> requiredEquipment,
      @HiveField(7) String? imageUrl,
      @HiveField(8) String? videoUrl,
      @HiveField(9) String? instructions,
      @HiveField(10) bool isCompleted,
      @HiveField(11) bool isSwapped,
      @HiveField(12) bool isSkipped,
      @HiveField(13) DateTime? completedAt,
      @HiveField(14) String? progressionNote,
      @HiveField(15) double? rpe,
      @HiveField(16) double? targetWeight,
      @HiveField(17) int? tempoEccentric,
      @HiveField(18) int? tempoPause,
      @HiveField(19) int? tempoConcentric});
}

/// @nodoc
class _$PlannedExerciseEntityCopyWithImpl<$Res,
        $Val extends PlannedExerciseEntity>
    implements $PlannedExerciseEntityCopyWith<$Res> {
  _$PlannedExerciseEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = null,
    Object? targetMuscles = null,
    Object? difficulty = null,
    Object? sets = null,
    Object? requiredEquipment = null,
    Object? imageUrl = freezed,
    Object? videoUrl = freezed,
    Object? instructions = freezed,
    Object? isCompleted = null,
    Object? isSwapped = null,
    Object? isSkipped = null,
    Object? completedAt = freezed,
    Object? progressionNote = freezed,
    Object? rpe = freezed,
    Object? targetWeight = freezed,
    Object? tempoEccentric = freezed,
    Object? tempoPause = freezed,
    Object? tempoConcentric = freezed,
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
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      targetMuscles: null == targetMuscles
          ? _value.targetMuscles
          : targetMuscles // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>,
      difficulty: null == difficulty
          ? _value.difficulty
          : difficulty // ignore: cast_nullable_to_non_nullable
              as ExerciseDifficulty,
      sets: null == sets
          ? _value.sets
          : sets // ignore: cast_nullable_to_non_nullable
              as List<ExerciseSetEntity>,
      requiredEquipment: null == requiredEquipment
          ? _value.requiredEquipment
          : requiredEquipment // ignore: cast_nullable_to_non_nullable
              as List<Equipment>,
      imageUrl: freezed == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      videoUrl: freezed == videoUrl
          ? _value.videoUrl
          : videoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      instructions: freezed == instructions
          ? _value.instructions
          : instructions // ignore: cast_nullable_to_non_nullable
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
      progressionNote: freezed == progressionNote
          ? _value.progressionNote
          : progressionNote // ignore: cast_nullable_to_non_nullable
              as String?,
      rpe: freezed == rpe
          ? _value.rpe
          : rpe // ignore: cast_nullable_to_non_nullable
              as double?,
      targetWeight: freezed == targetWeight
          ? _value.targetWeight
          : targetWeight // ignore: cast_nullable_to_non_nullable
              as double?,
      tempoEccentric: freezed == tempoEccentric
          ? _value.tempoEccentric
          : tempoEccentric // ignore: cast_nullable_to_non_nullable
              as int?,
      tempoPause: freezed == tempoPause
          ? _value.tempoPause
          : tempoPause // ignore: cast_nullable_to_non_nullable
              as int?,
      tempoConcentric: freezed == tempoConcentric
          ? _value.tempoConcentric
          : tempoConcentric // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PlannedExerciseEntityImplCopyWith<$Res>
    implements $PlannedExerciseEntityCopyWith<$Res> {
  factory _$$PlannedExerciseEntityImplCopyWith(
          _$PlannedExerciseEntityImpl value,
          $Res Function(_$PlannedExerciseEntityImpl) then) =
      __$$PlannedExerciseEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@HiveField(0) String id,
      @HiveField(1) String name,
      @HiveField(2) String description,
      @HiveField(3) List<MuscleGroup> targetMuscles,
      @HiveField(4) ExerciseDifficulty difficulty,
      @HiveField(5) List<ExerciseSetEntity> sets,
      @HiveField(6) List<Equipment> requiredEquipment,
      @HiveField(7) String? imageUrl,
      @HiveField(8) String? videoUrl,
      @HiveField(9) String? instructions,
      @HiveField(10) bool isCompleted,
      @HiveField(11) bool isSwapped,
      @HiveField(12) bool isSkipped,
      @HiveField(13) DateTime? completedAt,
      @HiveField(14) String? progressionNote,
      @HiveField(15) double? rpe,
      @HiveField(16) double? targetWeight,
      @HiveField(17) int? tempoEccentric,
      @HiveField(18) int? tempoPause,
      @HiveField(19) int? tempoConcentric});
}

/// @nodoc
class __$$PlannedExerciseEntityImplCopyWithImpl<$Res>
    extends _$PlannedExerciseEntityCopyWithImpl<$Res,
        _$PlannedExerciseEntityImpl>
    implements _$$PlannedExerciseEntityImplCopyWith<$Res> {
  __$$PlannedExerciseEntityImplCopyWithImpl(_$PlannedExerciseEntityImpl _value,
      $Res Function(_$PlannedExerciseEntityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = null,
    Object? targetMuscles = null,
    Object? difficulty = null,
    Object? sets = null,
    Object? requiredEquipment = null,
    Object? imageUrl = freezed,
    Object? videoUrl = freezed,
    Object? instructions = freezed,
    Object? isCompleted = null,
    Object? isSwapped = null,
    Object? isSkipped = null,
    Object? completedAt = freezed,
    Object? progressionNote = freezed,
    Object? rpe = freezed,
    Object? targetWeight = freezed,
    Object? tempoEccentric = freezed,
    Object? tempoPause = freezed,
    Object? tempoConcentric = freezed,
  }) {
    return _then(_$PlannedExerciseEntityImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      targetMuscles: null == targetMuscles
          ? _value._targetMuscles
          : targetMuscles // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>,
      difficulty: null == difficulty
          ? _value.difficulty
          : difficulty // ignore: cast_nullable_to_non_nullable
              as ExerciseDifficulty,
      sets: null == sets
          ? _value._sets
          : sets // ignore: cast_nullable_to_non_nullable
              as List<ExerciseSetEntity>,
      requiredEquipment: null == requiredEquipment
          ? _value._requiredEquipment
          : requiredEquipment // ignore: cast_nullable_to_non_nullable
              as List<Equipment>,
      imageUrl: freezed == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      videoUrl: freezed == videoUrl
          ? _value.videoUrl
          : videoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      instructions: freezed == instructions
          ? _value.instructions
          : instructions // ignore: cast_nullable_to_non_nullable
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
      progressionNote: freezed == progressionNote
          ? _value.progressionNote
          : progressionNote // ignore: cast_nullable_to_non_nullable
              as String?,
      rpe: freezed == rpe
          ? _value.rpe
          : rpe // ignore: cast_nullable_to_non_nullable
              as double?,
      targetWeight: freezed == targetWeight
          ? _value.targetWeight
          : targetWeight // ignore: cast_nullable_to_non_nullable
              as double?,
      tempoEccentric: freezed == tempoEccentric
          ? _value.tempoEccentric
          : tempoEccentric // ignore: cast_nullable_to_non_nullable
              as int?,
      tempoPause: freezed == tempoPause
          ? _value.tempoPause
          : tempoPause // ignore: cast_nullable_to_non_nullable
              as int?,
      tempoConcentric: freezed == tempoConcentric
          ? _value.tempoConcentric
          : tempoConcentric // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc

class _$PlannedExerciseEntityImpl extends _PlannedExerciseEntity {
  const _$PlannedExerciseEntityImpl(
      {@HiveField(0) required this.id,
      @HiveField(1) required this.name,
      @HiveField(2) required this.description,
      @HiveField(3) required final List<MuscleGroup> targetMuscles,
      @HiveField(4) required this.difficulty,
      @HiveField(5) required final List<ExerciseSetEntity> sets,
      @HiveField(6) required final List<Equipment> requiredEquipment,
      @HiveField(7) this.imageUrl,
      @HiveField(8) this.videoUrl,
      @HiveField(9) this.instructions,
      @HiveField(10) this.isCompleted = false,
      @HiveField(11) this.isSwapped = false,
      @HiveField(12) this.isSkipped = false,
      @HiveField(13) this.completedAt,
      @HiveField(14) this.progressionNote,
      @HiveField(15) this.rpe,
      @HiveField(16) this.targetWeight,
      @HiveField(17) this.tempoEccentric,
      @HiveField(18) this.tempoPause,
      @HiveField(19) this.tempoConcentric})
      : _targetMuscles = targetMuscles,
        _sets = sets,
        _requiredEquipment = requiredEquipment,
        super._();

  @override
  @HiveField(0)
  final String id;
  @override
  @HiveField(1)
  final String name;
  @override
  @HiveField(2)
  final String description;
  final List<MuscleGroup> _targetMuscles;
  @override
  @HiveField(3)
  List<MuscleGroup> get targetMuscles {
    if (_targetMuscles is EqualUnmodifiableListView) return _targetMuscles;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_targetMuscles);
  }

  @override
  @HiveField(4)
  final ExerciseDifficulty difficulty;
  final List<ExerciseSetEntity> _sets;
  @override
  @HiveField(5)
  List<ExerciseSetEntity> get sets {
    if (_sets is EqualUnmodifiableListView) return _sets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sets);
  }

  final List<Equipment> _requiredEquipment;
  @override
  @HiveField(6)
  List<Equipment> get requiredEquipment {
    if (_requiredEquipment is EqualUnmodifiableListView)
      return _requiredEquipment;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_requiredEquipment);
  }

  @override
  @HiveField(7)
  final String? imageUrl;
  @override
  @HiveField(8)
  final String? videoUrl;
  @override
  @HiveField(9)
  final String? instructions;
  @override
  @JsonKey()
  @HiveField(10)
  final bool isCompleted;
  @override
  @JsonKey()
  @HiveField(11)
  final bool isSwapped;
  @override
  @JsonKey()
  @HiveField(12)
  final bool isSkipped;
  @override
  @HiveField(13)
  final DateTime? completedAt;
  @override
  @HiveField(14)
  final String? progressionNote;
  @override
  @HiveField(15)
  final double? rpe;
  @override
  @HiveField(16)
  final double? targetWeight;
  @override
  @HiveField(17)
  final int? tempoEccentric;
  @override
  @HiveField(18)
  final int? tempoPause;
  @override
  @HiveField(19)
  final int? tempoConcentric;

  @override
  String toString() {
    return 'PlannedExerciseEntity(id: $id, name: $name, description: $description, targetMuscles: $targetMuscles, difficulty: $difficulty, sets: $sets, requiredEquipment: $requiredEquipment, imageUrl: $imageUrl, videoUrl: $videoUrl, instructions: $instructions, isCompleted: $isCompleted, isSwapped: $isSwapped, isSkipped: $isSkipped, completedAt: $completedAt, progressionNote: $progressionNote, rpe: $rpe, targetWeight: $targetWeight, tempoEccentric: $tempoEccentric, tempoPause: $tempoPause, tempoConcentric: $tempoConcentric)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlannedExerciseEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality()
                .equals(other._targetMuscles, _targetMuscles) &&
            (identical(other.difficulty, difficulty) ||
                other.difficulty == difficulty) &&
            const DeepCollectionEquality().equals(other._sets, _sets) &&
            const DeepCollectionEquality()
                .equals(other._requiredEquipment, _requiredEquipment) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.videoUrl, videoUrl) ||
                other.videoUrl == videoUrl) &&
            (identical(other.instructions, instructions) ||
                other.instructions == instructions) &&
            (identical(other.isCompleted, isCompleted) ||
                other.isCompleted == isCompleted) &&
            (identical(other.isSwapped, isSwapped) ||
                other.isSwapped == isSwapped) &&
            (identical(other.isSkipped, isSkipped) ||
                other.isSkipped == isSkipped) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.progressionNote, progressionNote) ||
                other.progressionNote == progressionNote) &&
            (identical(other.rpe, rpe) || other.rpe == rpe) &&
            (identical(other.targetWeight, targetWeight) ||
                other.targetWeight == targetWeight) &&
            (identical(other.tempoEccentric, tempoEccentric) ||
                other.tempoEccentric == tempoEccentric) &&
            (identical(other.tempoPause, tempoPause) ||
                other.tempoPause == tempoPause) &&
            (identical(other.tempoConcentric, tempoConcentric) ||
                other.tempoConcentric == tempoConcentric));
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        name,
        description,
        const DeepCollectionEquality().hash(_targetMuscles),
        difficulty,
        const DeepCollectionEquality().hash(_sets),
        const DeepCollectionEquality().hash(_requiredEquipment),
        imageUrl,
        videoUrl,
        instructions,
        isCompleted,
        isSwapped,
        isSkipped,
        completedAt,
        progressionNote,
        rpe,
        targetWeight,
        tempoEccentric,
        tempoPause,
        tempoConcentric
      ]);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PlannedExerciseEntityImplCopyWith<_$PlannedExerciseEntityImpl>
      get copyWith => __$$PlannedExerciseEntityImplCopyWithImpl<
          _$PlannedExerciseEntityImpl>(this, _$identity);
}

abstract class _PlannedExerciseEntity extends PlannedExerciseEntity {
  const factory _PlannedExerciseEntity(
      {@HiveField(0) required final String id,
      @HiveField(1) required final String name,
      @HiveField(2) required final String description,
      @HiveField(3) required final List<MuscleGroup> targetMuscles,
      @HiveField(4) required final ExerciseDifficulty difficulty,
      @HiveField(5) required final List<ExerciseSetEntity> sets,
      @HiveField(6) required final List<Equipment> requiredEquipment,
      @HiveField(7) final String? imageUrl,
      @HiveField(8) final String? videoUrl,
      @HiveField(9) final String? instructions,
      @HiveField(10) final bool isCompleted,
      @HiveField(11) final bool isSwapped,
      @HiveField(12) final bool isSkipped,
      @HiveField(13) final DateTime? completedAt,
      @HiveField(14) final String? progressionNote,
      @HiveField(15) final double? rpe,
      @HiveField(16) final double? targetWeight,
      @HiveField(17) final int? tempoEccentric,
      @HiveField(18) final int? tempoPause,
      @HiveField(19) final int? tempoConcentric}) = _$PlannedExerciseEntityImpl;
  const _PlannedExerciseEntity._() : super._();

  @override
  @HiveField(0)
  String get id;
  @override
  @HiveField(1)
  String get name;
  @override
  @HiveField(2)
  String get description;
  @override
  @HiveField(3)
  List<MuscleGroup> get targetMuscles;
  @override
  @HiveField(4)
  ExerciseDifficulty get difficulty;
  @override
  @HiveField(5)
  List<ExerciseSetEntity> get sets;
  @override
  @HiveField(6)
  List<Equipment> get requiredEquipment;
  @override
  @HiveField(7)
  String? get imageUrl;
  @override
  @HiveField(8)
  String? get videoUrl;
  @override
  @HiveField(9)
  String? get instructions;
  @override
  @HiveField(10)
  bool get isCompleted;
  @override
  @HiveField(11)
  bool get isSwapped;
  @override
  @HiveField(12)
  bool get isSkipped;
  @override
  @HiveField(13)
  DateTime? get completedAt;
  @override
  @HiveField(14)
  String? get progressionNote;
  @override
  @HiveField(15)
  double? get rpe;
  @override
  @HiveField(16)
  double? get targetWeight;
  @override
  @HiveField(17)
  int? get tempoEccentric;
  @override
  @HiveField(18)
  int? get tempoPause;
  @override
  @HiveField(19)
  int? get tempoConcentric;
  @override
  @JsonKey(ignore: true)
  _$$PlannedExerciseEntityImplCopyWith<_$PlannedExerciseEntityImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$DailyWorkoutPlanEntity {
  @HiveField(0)
  String get id => throw _privateConstructorUsedError;
  @HiveField(1)
  DateTime get date => throw _privateConstructorUsedError;
  @HiveField(2)
  String get workoutName =>
      throw _privateConstructorUsedError; // "Push Day", "Full Body A", etc.
  @HiveField(3)
  List<PlannedExerciseEntity> get exercises =>
      throw _privateConstructorUsedError;
  @HiveField(4)
  int get estimatedDurationMinutes => throw _privateConstructorUsedError;
  @HiveField(5)
  int get estimatedCaloriesBurned => throw _privateConstructorUsedError;
  @HiveField(6)
  List<MuscleGroup> get targetMuscleGroups =>
      throw _privateConstructorUsedError;
  @HiveField(7)
  String? get scheduledTime =>
      throw _privateConstructorUsedError; // "08:00" for reminders
  @HiveField(8)
  bool get isRestDay => throw _privateConstructorUsedError;
  @HiveField(9)
  bool get isCompleted => throw _privateConstructorUsedError;
  @HiveField(10)
  DateTime? get startedAt => throw _privateConstructorUsedError;
  @HiveField(11)
  DateTime? get completedAt => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $DailyWorkoutPlanEntityCopyWith<DailyWorkoutPlanEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DailyWorkoutPlanEntityCopyWith<$Res> {
  factory $DailyWorkoutPlanEntityCopyWith(DailyWorkoutPlanEntity value,
          $Res Function(DailyWorkoutPlanEntity) then) =
      _$DailyWorkoutPlanEntityCopyWithImpl<$Res, DailyWorkoutPlanEntity>;
  @useResult
  $Res call(
      {@HiveField(0) String id,
      @HiveField(1) DateTime date,
      @HiveField(2) String workoutName,
      @HiveField(3) List<PlannedExerciseEntity> exercises,
      @HiveField(4) int estimatedDurationMinutes,
      @HiveField(5) int estimatedCaloriesBurned,
      @HiveField(6) List<MuscleGroup> targetMuscleGroups,
      @HiveField(7) String? scheduledTime,
      @HiveField(8) bool isRestDay,
      @HiveField(9) bool isCompleted,
      @HiveField(10) DateTime? startedAt,
      @HiveField(11) DateTime? completedAt});
}

/// @nodoc
class _$DailyWorkoutPlanEntityCopyWithImpl<$Res,
        $Val extends DailyWorkoutPlanEntity>
    implements $DailyWorkoutPlanEntityCopyWith<$Res> {
  _$DailyWorkoutPlanEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? date = null,
    Object? workoutName = null,
    Object? exercises = null,
    Object? estimatedDurationMinutes = null,
    Object? estimatedCaloriesBurned = null,
    Object? targetMuscleGroups = null,
    Object? scheduledTime = freezed,
    Object? isRestDay = null,
    Object? isCompleted = null,
    Object? startedAt = freezed,
    Object? completedAt = freezed,
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
      workoutName: null == workoutName
          ? _value.workoutName
          : workoutName // ignore: cast_nullable_to_non_nullable
              as String,
      exercises: null == exercises
          ? _value.exercises
          : exercises // ignore: cast_nullable_to_non_nullable
              as List<PlannedExerciseEntity>,
      estimatedDurationMinutes: null == estimatedDurationMinutes
          ? _value.estimatedDurationMinutes
          : estimatedDurationMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      estimatedCaloriesBurned: null == estimatedCaloriesBurned
          ? _value.estimatedCaloriesBurned
          : estimatedCaloriesBurned // ignore: cast_nullable_to_non_nullable
              as int,
      targetMuscleGroups: null == targetMuscleGroups
          ? _value.targetMuscleGroups
          : targetMuscleGroups // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>,
      scheduledTime: freezed == scheduledTime
          ? _value.scheduledTime
          : scheduledTime // ignore: cast_nullable_to_non_nullable
              as String?,
      isRestDay: null == isRestDay
          ? _value.isRestDay
          : isRestDay // ignore: cast_nullable_to_non_nullable
              as bool,
      isCompleted: null == isCompleted
          ? _value.isCompleted
          : isCompleted // ignore: cast_nullable_to_non_nullable
              as bool,
      startedAt: freezed == startedAt
          ? _value.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DailyWorkoutPlanEntityImplCopyWith<$Res>
    implements $DailyWorkoutPlanEntityCopyWith<$Res> {
  factory _$$DailyWorkoutPlanEntityImplCopyWith(
          _$DailyWorkoutPlanEntityImpl value,
          $Res Function(_$DailyWorkoutPlanEntityImpl) then) =
      __$$DailyWorkoutPlanEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@HiveField(0) String id,
      @HiveField(1) DateTime date,
      @HiveField(2) String workoutName,
      @HiveField(3) List<PlannedExerciseEntity> exercises,
      @HiveField(4) int estimatedDurationMinutes,
      @HiveField(5) int estimatedCaloriesBurned,
      @HiveField(6) List<MuscleGroup> targetMuscleGroups,
      @HiveField(7) String? scheduledTime,
      @HiveField(8) bool isRestDay,
      @HiveField(9) bool isCompleted,
      @HiveField(10) DateTime? startedAt,
      @HiveField(11) DateTime? completedAt});
}

/// @nodoc
class __$$DailyWorkoutPlanEntityImplCopyWithImpl<$Res>
    extends _$DailyWorkoutPlanEntityCopyWithImpl<$Res,
        _$DailyWorkoutPlanEntityImpl>
    implements _$$DailyWorkoutPlanEntityImplCopyWith<$Res> {
  __$$DailyWorkoutPlanEntityImplCopyWithImpl(
      _$DailyWorkoutPlanEntityImpl _value,
      $Res Function(_$DailyWorkoutPlanEntityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? date = null,
    Object? workoutName = null,
    Object? exercises = null,
    Object? estimatedDurationMinutes = null,
    Object? estimatedCaloriesBurned = null,
    Object? targetMuscleGroups = null,
    Object? scheduledTime = freezed,
    Object? isRestDay = null,
    Object? isCompleted = null,
    Object? startedAt = freezed,
    Object? completedAt = freezed,
  }) {
    return _then(_$DailyWorkoutPlanEntityImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
      workoutName: null == workoutName
          ? _value.workoutName
          : workoutName // ignore: cast_nullable_to_non_nullable
              as String,
      exercises: null == exercises
          ? _value._exercises
          : exercises // ignore: cast_nullable_to_non_nullable
              as List<PlannedExerciseEntity>,
      estimatedDurationMinutes: null == estimatedDurationMinutes
          ? _value.estimatedDurationMinutes
          : estimatedDurationMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      estimatedCaloriesBurned: null == estimatedCaloriesBurned
          ? _value.estimatedCaloriesBurned
          : estimatedCaloriesBurned // ignore: cast_nullable_to_non_nullable
              as int,
      targetMuscleGroups: null == targetMuscleGroups
          ? _value._targetMuscleGroups
          : targetMuscleGroups // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>,
      scheduledTime: freezed == scheduledTime
          ? _value.scheduledTime
          : scheduledTime // ignore: cast_nullable_to_non_nullable
              as String?,
      isRestDay: null == isRestDay
          ? _value.isRestDay
          : isRestDay // ignore: cast_nullable_to_non_nullable
              as bool,
      isCompleted: null == isCompleted
          ? _value.isCompleted
          : isCompleted // ignore: cast_nullable_to_non_nullable
              as bool,
      startedAt: freezed == startedAt
          ? _value.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc

class _$DailyWorkoutPlanEntityImpl extends _DailyWorkoutPlanEntity {
  const _$DailyWorkoutPlanEntityImpl(
      {@HiveField(0) required this.id,
      @HiveField(1) required this.date,
      @HiveField(2) required this.workoutName,
      @HiveField(3) required final List<PlannedExerciseEntity> exercises,
      @HiveField(4) required this.estimatedDurationMinutes,
      @HiveField(5) required this.estimatedCaloriesBurned,
      @HiveField(6) required final List<MuscleGroup> targetMuscleGroups,
      @HiveField(7) this.scheduledTime,
      @HiveField(8) this.isRestDay = false,
      @HiveField(9) this.isCompleted = false,
      @HiveField(10) this.startedAt,
      @HiveField(11) this.completedAt})
      : _exercises = exercises,
        _targetMuscleGroups = targetMuscleGroups,
        super._();

  @override
  @HiveField(0)
  final String id;
  @override
  @HiveField(1)
  final DateTime date;
  @override
  @HiveField(2)
  final String workoutName;
// "Push Day", "Full Body A", etc.
  final List<PlannedExerciseEntity> _exercises;
// "Push Day", "Full Body A", etc.
  @override
  @HiveField(3)
  List<PlannedExerciseEntity> get exercises {
    if (_exercises is EqualUnmodifiableListView) return _exercises;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_exercises);
  }

  @override
  @HiveField(4)
  final int estimatedDurationMinutes;
  @override
  @HiveField(5)
  final int estimatedCaloriesBurned;
  final List<MuscleGroup> _targetMuscleGroups;
  @override
  @HiveField(6)
  List<MuscleGroup> get targetMuscleGroups {
    if (_targetMuscleGroups is EqualUnmodifiableListView)
      return _targetMuscleGroups;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_targetMuscleGroups);
  }

  @override
  @HiveField(7)
  final String? scheduledTime;
// "08:00" for reminders
  @override
  @JsonKey()
  @HiveField(8)
  final bool isRestDay;
  @override
  @JsonKey()
  @HiveField(9)
  final bool isCompleted;
  @override
  @HiveField(10)
  final DateTime? startedAt;
  @override
  @HiveField(11)
  final DateTime? completedAt;

  @override
  String toString() {
    return 'DailyWorkoutPlanEntity(id: $id, date: $date, workoutName: $workoutName, exercises: $exercises, estimatedDurationMinutes: $estimatedDurationMinutes, estimatedCaloriesBurned: $estimatedCaloriesBurned, targetMuscleGroups: $targetMuscleGroups, scheduledTime: $scheduledTime, isRestDay: $isRestDay, isCompleted: $isCompleted, startedAt: $startedAt, completedAt: $completedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DailyWorkoutPlanEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.workoutName, workoutName) ||
                other.workoutName == workoutName) &&
            const DeepCollectionEquality()
                .equals(other._exercises, _exercises) &&
            (identical(
                    other.estimatedDurationMinutes, estimatedDurationMinutes) ||
                other.estimatedDurationMinutes == estimatedDurationMinutes) &&
            (identical(
                    other.estimatedCaloriesBurned, estimatedCaloriesBurned) ||
                other.estimatedCaloriesBurned == estimatedCaloriesBurned) &&
            const DeepCollectionEquality()
                .equals(other._targetMuscleGroups, _targetMuscleGroups) &&
            (identical(other.scheduledTime, scheduledTime) ||
                other.scheduledTime == scheduledTime) &&
            (identical(other.isRestDay, isRestDay) ||
                other.isRestDay == isRestDay) &&
            (identical(other.isCompleted, isCompleted) ||
                other.isCompleted == isCompleted) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      date,
      workoutName,
      const DeepCollectionEquality().hash(_exercises),
      estimatedDurationMinutes,
      estimatedCaloriesBurned,
      const DeepCollectionEquality().hash(_targetMuscleGroups),
      scheduledTime,
      isRestDay,
      isCompleted,
      startedAt,
      completedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$DailyWorkoutPlanEntityImplCopyWith<_$DailyWorkoutPlanEntityImpl>
      get copyWith => __$$DailyWorkoutPlanEntityImplCopyWithImpl<
          _$DailyWorkoutPlanEntityImpl>(this, _$identity);
}

abstract class _DailyWorkoutPlanEntity extends DailyWorkoutPlanEntity {
  const factory _DailyWorkoutPlanEntity(
          {@HiveField(0) required final String id,
          @HiveField(1) required final DateTime date,
          @HiveField(2) required final String workoutName,
          @HiveField(3) required final List<PlannedExerciseEntity> exercises,
          @HiveField(4) required final int estimatedDurationMinutes,
          @HiveField(5) required final int estimatedCaloriesBurned,
          @HiveField(6) required final List<MuscleGroup> targetMuscleGroups,
          @HiveField(7) final String? scheduledTime,
          @HiveField(8) final bool isRestDay,
          @HiveField(9) final bool isCompleted,
          @HiveField(10) final DateTime? startedAt,
          @HiveField(11) final DateTime? completedAt}) =
      _$DailyWorkoutPlanEntityImpl;
  const _DailyWorkoutPlanEntity._() : super._();

  @override
  @HiveField(0)
  String get id;
  @override
  @HiveField(1)
  DateTime get date;
  @override
  @HiveField(2)
  String get workoutName;
  @override // "Push Day", "Full Body A", etc.
  @HiveField(3)
  List<PlannedExerciseEntity> get exercises;
  @override
  @HiveField(4)
  int get estimatedDurationMinutes;
  @override
  @HiveField(5)
  int get estimatedCaloriesBurned;
  @override
  @HiveField(6)
  List<MuscleGroup> get targetMuscleGroups;
  @override
  @HiveField(7)
  String? get scheduledTime;
  @override // "08:00" for reminders
  @HiveField(8)
  bool get isRestDay;
  @override
  @HiveField(9)
  bool get isCompleted;
  @override
  @HiveField(10)
  DateTime? get startedAt;
  @override
  @HiveField(11)
  DateTime? get completedAt;
  @override
  @JsonKey(ignore: true)
  _$$DailyWorkoutPlanEntityImplCopyWith<_$DailyWorkoutPlanEntityImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$WeeklyWorkoutPlanEntity {
  @HiveField(0)
  int get weekNumber => throw _privateConstructorUsedError;
  @HiveField(1)
  DateTime get startDate => throw _privateConstructorUsedError;
  @HiveField(2)
  DateTime get endDate => throw _privateConstructorUsedError;
  @HiveField(3)
  List<DailyWorkoutPlanEntity> get days => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $WeeklyWorkoutPlanEntityCopyWith<WeeklyWorkoutPlanEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WeeklyWorkoutPlanEntityCopyWith<$Res> {
  factory $WeeklyWorkoutPlanEntityCopyWith(WeeklyWorkoutPlanEntity value,
          $Res Function(WeeklyWorkoutPlanEntity) then) =
      _$WeeklyWorkoutPlanEntityCopyWithImpl<$Res, WeeklyWorkoutPlanEntity>;
  @useResult
  $Res call(
      {@HiveField(0) int weekNumber,
      @HiveField(1) DateTime startDate,
      @HiveField(2) DateTime endDate,
      @HiveField(3) List<DailyWorkoutPlanEntity> days});
}

/// @nodoc
class _$WeeklyWorkoutPlanEntityCopyWithImpl<$Res,
        $Val extends WeeklyWorkoutPlanEntity>
    implements $WeeklyWorkoutPlanEntityCopyWith<$Res> {
  _$WeeklyWorkoutPlanEntityCopyWithImpl(this._value, this._then);

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
              as List<DailyWorkoutPlanEntity>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$WeeklyWorkoutPlanEntityImplCopyWith<$Res>
    implements $WeeklyWorkoutPlanEntityCopyWith<$Res> {
  factory _$$WeeklyWorkoutPlanEntityImplCopyWith(
          _$WeeklyWorkoutPlanEntityImpl value,
          $Res Function(_$WeeklyWorkoutPlanEntityImpl) then) =
      __$$WeeklyWorkoutPlanEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@HiveField(0) int weekNumber,
      @HiveField(1) DateTime startDate,
      @HiveField(2) DateTime endDate,
      @HiveField(3) List<DailyWorkoutPlanEntity> days});
}

/// @nodoc
class __$$WeeklyWorkoutPlanEntityImplCopyWithImpl<$Res>
    extends _$WeeklyWorkoutPlanEntityCopyWithImpl<$Res,
        _$WeeklyWorkoutPlanEntityImpl>
    implements _$$WeeklyWorkoutPlanEntityImplCopyWith<$Res> {
  __$$WeeklyWorkoutPlanEntityImplCopyWithImpl(
      _$WeeklyWorkoutPlanEntityImpl _value,
      $Res Function(_$WeeklyWorkoutPlanEntityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? weekNumber = null,
    Object? startDate = null,
    Object? endDate = null,
    Object? days = null,
  }) {
    return _then(_$WeeklyWorkoutPlanEntityImpl(
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
              as List<DailyWorkoutPlanEntity>,
    ));
  }
}

/// @nodoc

class _$WeeklyWorkoutPlanEntityImpl extends _WeeklyWorkoutPlanEntity {
  const _$WeeklyWorkoutPlanEntityImpl(
      {@HiveField(0) required this.weekNumber,
      @HiveField(1) required this.startDate,
      @HiveField(2) required this.endDate,
      @HiveField(3) required final List<DailyWorkoutPlanEntity> days})
      : _days = days,
        super._();

  @override
  @HiveField(0)
  final int weekNumber;
  @override
  @HiveField(1)
  final DateTime startDate;
  @override
  @HiveField(2)
  final DateTime endDate;
  final List<DailyWorkoutPlanEntity> _days;
  @override
  @HiveField(3)
  List<DailyWorkoutPlanEntity> get days {
    if (_days is EqualUnmodifiableListView) return _days;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_days);
  }

  @override
  String toString() {
    return 'WeeklyWorkoutPlanEntity(weekNumber: $weekNumber, startDate: $startDate, endDate: $endDate, days: $days)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WeeklyWorkoutPlanEntityImpl &&
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
  _$$WeeklyWorkoutPlanEntityImplCopyWith<_$WeeklyWorkoutPlanEntityImpl>
      get copyWith => __$$WeeklyWorkoutPlanEntityImplCopyWithImpl<
          _$WeeklyWorkoutPlanEntityImpl>(this, _$identity);
}

abstract class _WeeklyWorkoutPlanEntity extends WeeklyWorkoutPlanEntity {
  const factory _WeeklyWorkoutPlanEntity(
          {@HiveField(0) required final int weekNumber,
          @HiveField(1) required final DateTime startDate,
          @HiveField(2) required final DateTime endDate,
          @HiveField(3) required final List<DailyWorkoutPlanEntity> days}) =
      _$WeeklyWorkoutPlanEntityImpl;
  const _WeeklyWorkoutPlanEntity._() : super._();

  @override
  @HiveField(0)
  int get weekNumber;
  @override
  @HiveField(1)
  DateTime get startDate;
  @override
  @HiveField(2)
  DateTime get endDate;
  @override
  @HiveField(3)
  List<DailyWorkoutPlanEntity> get days;
  @override
  @JsonKey(ignore: true)
  _$$WeeklyWorkoutPlanEntityImplCopyWith<_$WeeklyWorkoutPlanEntityImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$DailyWorkoutTargetEntity {
  @HiveField(0)
  int get exercisesPerSession => throw _privateConstructorUsedError;
  @HiveField(1)
  int get durationMinutes => throw _privateConstructorUsedError;
  @HiveField(2)
  int get caloriesBurned => throw _privateConstructorUsedError;
  @HiveField(3)
  int get setsPerMuscleGroup => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $DailyWorkoutTargetEntityCopyWith<DailyWorkoutTargetEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DailyWorkoutTargetEntityCopyWith<$Res> {
  factory $DailyWorkoutTargetEntityCopyWith(DailyWorkoutTargetEntity value,
          $Res Function(DailyWorkoutTargetEntity) then) =
      _$DailyWorkoutTargetEntityCopyWithImpl<$Res, DailyWorkoutTargetEntity>;
  @useResult
  $Res call(
      {@HiveField(0) int exercisesPerSession,
      @HiveField(1) int durationMinutes,
      @HiveField(2) int caloriesBurned,
      @HiveField(3) int setsPerMuscleGroup});
}

/// @nodoc
class _$DailyWorkoutTargetEntityCopyWithImpl<$Res,
        $Val extends DailyWorkoutTargetEntity>
    implements $DailyWorkoutTargetEntityCopyWith<$Res> {
  _$DailyWorkoutTargetEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? exercisesPerSession = null,
    Object? durationMinutes = null,
    Object? caloriesBurned = null,
    Object? setsPerMuscleGroup = null,
  }) {
    return _then(_value.copyWith(
      exercisesPerSession: null == exercisesPerSession
          ? _value.exercisesPerSession
          : exercisesPerSession // ignore: cast_nullable_to_non_nullable
              as int,
      durationMinutes: null == durationMinutes
          ? _value.durationMinutes
          : durationMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      caloriesBurned: null == caloriesBurned
          ? _value.caloriesBurned
          : caloriesBurned // ignore: cast_nullable_to_non_nullable
              as int,
      setsPerMuscleGroup: null == setsPerMuscleGroup
          ? _value.setsPerMuscleGroup
          : setsPerMuscleGroup // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DailyWorkoutTargetEntityImplCopyWith<$Res>
    implements $DailyWorkoutTargetEntityCopyWith<$Res> {
  factory _$$DailyWorkoutTargetEntityImplCopyWith(
          _$DailyWorkoutTargetEntityImpl value,
          $Res Function(_$DailyWorkoutTargetEntityImpl) then) =
      __$$DailyWorkoutTargetEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@HiveField(0) int exercisesPerSession,
      @HiveField(1) int durationMinutes,
      @HiveField(2) int caloriesBurned,
      @HiveField(3) int setsPerMuscleGroup});
}

/// @nodoc
class __$$DailyWorkoutTargetEntityImplCopyWithImpl<$Res>
    extends _$DailyWorkoutTargetEntityCopyWithImpl<$Res,
        _$DailyWorkoutTargetEntityImpl>
    implements _$$DailyWorkoutTargetEntityImplCopyWith<$Res> {
  __$$DailyWorkoutTargetEntityImplCopyWithImpl(
      _$DailyWorkoutTargetEntityImpl _value,
      $Res Function(_$DailyWorkoutTargetEntityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? exercisesPerSession = null,
    Object? durationMinutes = null,
    Object? caloriesBurned = null,
    Object? setsPerMuscleGroup = null,
  }) {
    return _then(_$DailyWorkoutTargetEntityImpl(
      exercisesPerSession: null == exercisesPerSession
          ? _value.exercisesPerSession
          : exercisesPerSession // ignore: cast_nullable_to_non_nullable
              as int,
      durationMinutes: null == durationMinutes
          ? _value.durationMinutes
          : durationMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      caloriesBurned: null == caloriesBurned
          ? _value.caloriesBurned
          : caloriesBurned // ignore: cast_nullable_to_non_nullable
              as int,
      setsPerMuscleGroup: null == setsPerMuscleGroup
          ? _value.setsPerMuscleGroup
          : setsPerMuscleGroup // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$DailyWorkoutTargetEntityImpl implements _DailyWorkoutTargetEntity {
  const _$DailyWorkoutTargetEntityImpl(
      {@HiveField(0) required this.exercisesPerSession,
      @HiveField(1) required this.durationMinutes,
      @HiveField(2) required this.caloriesBurned,
      @HiveField(3) required this.setsPerMuscleGroup});

  @override
  @HiveField(0)
  final int exercisesPerSession;
  @override
  @HiveField(1)
  final int durationMinutes;
  @override
  @HiveField(2)
  final int caloriesBurned;
  @override
  @HiveField(3)
  final int setsPerMuscleGroup;

  @override
  String toString() {
    return 'DailyWorkoutTargetEntity(exercisesPerSession: $exercisesPerSession, durationMinutes: $durationMinutes, caloriesBurned: $caloriesBurned, setsPerMuscleGroup: $setsPerMuscleGroup)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DailyWorkoutTargetEntityImpl &&
            (identical(other.exercisesPerSession, exercisesPerSession) ||
                other.exercisesPerSession == exercisesPerSession) &&
            (identical(other.durationMinutes, durationMinutes) ||
                other.durationMinutes == durationMinutes) &&
            (identical(other.caloriesBurned, caloriesBurned) ||
                other.caloriesBurned == caloriesBurned) &&
            (identical(other.setsPerMuscleGroup, setsPerMuscleGroup) ||
                other.setsPerMuscleGroup == setsPerMuscleGroup));
  }

  @override
  int get hashCode => Object.hash(runtimeType, exercisesPerSession,
      durationMinutes, caloriesBurned, setsPerMuscleGroup);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$DailyWorkoutTargetEntityImplCopyWith<_$DailyWorkoutTargetEntityImpl>
      get copyWith => __$$DailyWorkoutTargetEntityImplCopyWithImpl<
          _$DailyWorkoutTargetEntityImpl>(this, _$identity);
}

abstract class _DailyWorkoutTargetEntity implements DailyWorkoutTargetEntity {
  const factory _DailyWorkoutTargetEntity(
          {@HiveField(0) required final int exercisesPerSession,
          @HiveField(1) required final int durationMinutes,
          @HiveField(2) required final int caloriesBurned,
          @HiveField(3) required final int setsPerMuscleGroup}) =
      _$DailyWorkoutTargetEntityImpl;

  @override
  @HiveField(0)
  int get exercisesPerSession;
  @override
  @HiveField(1)
  int get durationMinutes;
  @override
  @HiveField(2)
  int get caloriesBurned;
  @override
  @HiveField(3)
  int get setsPerMuscleGroup;
  @override
  @JsonKey(ignore: true)
  _$$DailyWorkoutTargetEntityImplCopyWith<_$DailyWorkoutTargetEntityImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$MonthlyWorkoutPlanEntity {
  @HiveField(0)
  String get id => throw _privateConstructorUsedError;
  @HiveField(1)
  String get odUserId => throw _privateConstructorUsedError;
  @HiveField(2)
  DateTime get startDate => throw _privateConstructorUsedError;
  @HiveField(3)
  DateTime get endDate => throw _privateConstructorUsedError;
  @HiveField(4)
  WorkoutGoal get goal => throw _privateConstructorUsedError;
  @HiveField(5)
  TrainingLocation get location => throw _privateConstructorUsedError;
  @HiveField(6)
  TrainingSplit get split => throw _privateConstructorUsedError;
  @HiveField(7)
  DailyWorkoutTargetEntity get dailyTarget =>
      throw _privateConstructorUsedError;
  @HiveField(8)
  List<WeeklyWorkoutPlanEntity> get weeks => throw _privateConstructorUsedError;
  @HiveField(9)
  DateTime? get createdAt => throw _privateConstructorUsedError;
  @HiveField(10)
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $MonthlyWorkoutPlanEntityCopyWith<MonthlyWorkoutPlanEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MonthlyWorkoutPlanEntityCopyWith<$Res> {
  factory $MonthlyWorkoutPlanEntityCopyWith(MonthlyWorkoutPlanEntity value,
          $Res Function(MonthlyWorkoutPlanEntity) then) =
      _$MonthlyWorkoutPlanEntityCopyWithImpl<$Res, MonthlyWorkoutPlanEntity>;
  @useResult
  $Res call(
      {@HiveField(0) String id,
      @HiveField(1) String odUserId,
      @HiveField(2) DateTime startDate,
      @HiveField(3) DateTime endDate,
      @HiveField(4) WorkoutGoal goal,
      @HiveField(5) TrainingLocation location,
      @HiveField(6) TrainingSplit split,
      @HiveField(7) DailyWorkoutTargetEntity dailyTarget,
      @HiveField(8) List<WeeklyWorkoutPlanEntity> weeks,
      @HiveField(9) DateTime? createdAt,
      @HiveField(10) DateTime? updatedAt});

  $DailyWorkoutTargetEntityCopyWith<$Res> get dailyTarget;
}

/// @nodoc
class _$MonthlyWorkoutPlanEntityCopyWithImpl<$Res,
        $Val extends MonthlyWorkoutPlanEntity>
    implements $MonthlyWorkoutPlanEntityCopyWith<$Res> {
  _$MonthlyWorkoutPlanEntityCopyWithImpl(this._value, this._then);

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
    Object? location = null,
    Object? split = null,
    Object? dailyTarget = null,
    Object? weeks = null,
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
              as WorkoutGoal,
      location: null == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as TrainingLocation,
      split: null == split
          ? _value.split
          : split // ignore: cast_nullable_to_non_nullable
              as TrainingSplit,
      dailyTarget: null == dailyTarget
          ? _value.dailyTarget
          : dailyTarget // ignore: cast_nullable_to_non_nullable
              as DailyWorkoutTargetEntity,
      weeks: null == weeks
          ? _value.weeks
          : weeks // ignore: cast_nullable_to_non_nullable
              as List<WeeklyWorkoutPlanEntity>,
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
  $DailyWorkoutTargetEntityCopyWith<$Res> get dailyTarget {
    return $DailyWorkoutTargetEntityCopyWith<$Res>(_value.dailyTarget, (value) {
      return _then(_value.copyWith(dailyTarget: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$MonthlyWorkoutPlanEntityImplCopyWith<$Res>
    implements $MonthlyWorkoutPlanEntityCopyWith<$Res> {
  factory _$$MonthlyWorkoutPlanEntityImplCopyWith(
          _$MonthlyWorkoutPlanEntityImpl value,
          $Res Function(_$MonthlyWorkoutPlanEntityImpl) then) =
      __$$MonthlyWorkoutPlanEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@HiveField(0) String id,
      @HiveField(1) String odUserId,
      @HiveField(2) DateTime startDate,
      @HiveField(3) DateTime endDate,
      @HiveField(4) WorkoutGoal goal,
      @HiveField(5) TrainingLocation location,
      @HiveField(6) TrainingSplit split,
      @HiveField(7) DailyWorkoutTargetEntity dailyTarget,
      @HiveField(8) List<WeeklyWorkoutPlanEntity> weeks,
      @HiveField(9) DateTime? createdAt,
      @HiveField(10) DateTime? updatedAt});

  @override
  $DailyWorkoutTargetEntityCopyWith<$Res> get dailyTarget;
}

/// @nodoc
class __$$MonthlyWorkoutPlanEntityImplCopyWithImpl<$Res>
    extends _$MonthlyWorkoutPlanEntityCopyWithImpl<$Res,
        _$MonthlyWorkoutPlanEntityImpl>
    implements _$$MonthlyWorkoutPlanEntityImplCopyWith<$Res> {
  __$$MonthlyWorkoutPlanEntityImplCopyWithImpl(
      _$MonthlyWorkoutPlanEntityImpl _value,
      $Res Function(_$MonthlyWorkoutPlanEntityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? odUserId = null,
    Object? startDate = null,
    Object? endDate = null,
    Object? goal = null,
    Object? location = null,
    Object? split = null,
    Object? dailyTarget = null,
    Object? weeks = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_$MonthlyWorkoutPlanEntityImpl(
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
              as WorkoutGoal,
      location: null == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as TrainingLocation,
      split: null == split
          ? _value.split
          : split // ignore: cast_nullable_to_non_nullable
              as TrainingSplit,
      dailyTarget: null == dailyTarget
          ? _value.dailyTarget
          : dailyTarget // ignore: cast_nullable_to_non_nullable
              as DailyWorkoutTargetEntity,
      weeks: null == weeks
          ? _value._weeks
          : weeks // ignore: cast_nullable_to_non_nullable
              as List<WeeklyWorkoutPlanEntity>,
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

class _$MonthlyWorkoutPlanEntityImpl extends _MonthlyWorkoutPlanEntity {
  const _$MonthlyWorkoutPlanEntityImpl(
      {@HiveField(0) required this.id,
      @HiveField(1) required this.odUserId,
      @HiveField(2) required this.startDate,
      @HiveField(3) required this.endDate,
      @HiveField(4) required this.goal,
      @HiveField(5) required this.location,
      @HiveField(6) required this.split,
      @HiveField(7) required this.dailyTarget,
      @HiveField(8) required final List<WeeklyWorkoutPlanEntity> weeks,
      @HiveField(9) this.createdAt,
      @HiveField(10) this.updatedAt})
      : _weeks = weeks,
        super._();

  @override
  @HiveField(0)
  final String id;
  @override
  @HiveField(1)
  final String odUserId;
  @override
  @HiveField(2)
  final DateTime startDate;
  @override
  @HiveField(3)
  final DateTime endDate;
  @override
  @HiveField(4)
  final WorkoutGoal goal;
  @override
  @HiveField(5)
  final TrainingLocation location;
  @override
  @HiveField(6)
  final TrainingSplit split;
  @override
  @HiveField(7)
  final DailyWorkoutTargetEntity dailyTarget;
  final List<WeeklyWorkoutPlanEntity> _weeks;
  @override
  @HiveField(8)
  List<WeeklyWorkoutPlanEntity> get weeks {
    if (_weeks is EqualUnmodifiableListView) return _weeks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_weeks);
  }

  @override
  @HiveField(9)
  final DateTime? createdAt;
  @override
  @HiveField(10)
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'MonthlyWorkoutPlanEntity(id: $id, odUserId: $odUserId, startDate: $startDate, endDate: $endDate, goal: $goal, location: $location, split: $split, dailyTarget: $dailyTarget, weeks: $weeks, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MonthlyWorkoutPlanEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.odUserId, odUserId) ||
                other.odUserId == odUserId) &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            (identical(other.goal, goal) || other.goal == goal) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.split, split) || other.split == split) &&
            (identical(other.dailyTarget, dailyTarget) ||
                other.dailyTarget == dailyTarget) &&
            const DeepCollectionEquality().equals(other._weeks, _weeks) &&
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
      location,
      split,
      dailyTarget,
      const DeepCollectionEquality().hash(_weeks),
      createdAt,
      updatedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$MonthlyWorkoutPlanEntityImplCopyWith<_$MonthlyWorkoutPlanEntityImpl>
      get copyWith => __$$MonthlyWorkoutPlanEntityImplCopyWithImpl<
          _$MonthlyWorkoutPlanEntityImpl>(this, _$identity);
}

abstract class _MonthlyWorkoutPlanEntity extends MonthlyWorkoutPlanEntity {
  const factory _MonthlyWorkoutPlanEntity(
          {@HiveField(0) required final String id,
          @HiveField(1) required final String odUserId,
          @HiveField(2) required final DateTime startDate,
          @HiveField(3) required final DateTime endDate,
          @HiveField(4) required final WorkoutGoal goal,
          @HiveField(5) required final TrainingLocation location,
          @HiveField(6) required final TrainingSplit split,
          @HiveField(7) required final DailyWorkoutTargetEntity dailyTarget,
          @HiveField(8) required final List<WeeklyWorkoutPlanEntity> weeks,
          @HiveField(9) final DateTime? createdAt,
          @HiveField(10) final DateTime? updatedAt}) =
      _$MonthlyWorkoutPlanEntityImpl;
  const _MonthlyWorkoutPlanEntity._() : super._();

  @override
  @HiveField(0)
  String get id;
  @override
  @HiveField(1)
  String get odUserId;
  @override
  @HiveField(2)
  DateTime get startDate;
  @override
  @HiveField(3)
  DateTime get endDate;
  @override
  @HiveField(4)
  WorkoutGoal get goal;
  @override
  @HiveField(5)
  TrainingLocation get location;
  @override
  @HiveField(6)
  TrainingSplit get split;
  @override
  @HiveField(7)
  DailyWorkoutTargetEntity get dailyTarget;
  @override
  @HiveField(8)
  List<WeeklyWorkoutPlanEntity> get weeks;
  @override
  @HiveField(9)
  DateTime? get createdAt;
  @override
  @HiveField(10)
  DateTime? get updatedAt;
  @override
  @JsonKey(ignore: true)
  _$$MonthlyWorkoutPlanEntityImplCopyWith<_$MonthlyWorkoutPlanEntityImpl>
      get copyWith => throw _privateConstructorUsedError;
}
