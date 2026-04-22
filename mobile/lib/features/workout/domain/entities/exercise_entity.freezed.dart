// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'exercise_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$ExerciseEntity {
  String get id => throw _privateConstructorUsedError;
  String get exerciseName => throw _privateConstructorUsedError;
  int get orderIndex => throw _privateConstructorUsedError;
  int get targetSets => throw _privateConstructorUsedError;
  int? get targetReps => throw _privateConstructorUsedError;
  int? get targetRepsMax =>
      throw _privateConstructorUsedError; // P2-E: upper rep bound for progressive overload display
  int? get targetSeconds =>
      throw _privateConstructorUsedError; // P2-A: timed holds (Plank, wall-sit) — from targetDuration
  bool get isWarmup =>
      throw _privateConstructorUsedError; // P2-C: warmup flag (orderIndex >= 1000)
  int get restSeconds => throw _privateConstructorUsedError;
  String? get videoUrl => throw _privateConstructorUsedError;
  String? get imageUrl => throw _privateConstructorUsedError;
  String? get instructions => throw _privateConstructorUsedError;
  double? get targetWeight => throw _privateConstructorUsedError;
  double? get rpe => throw _privateConstructorUsedError;
  int? get tempoEccentric => throw _privateConstructorUsedError;
  int? get tempoPause => throw _privateConstructorUsedError;
  int? get tempoConcentric => throw _privateConstructorUsedError;
  String? get progressionNote => throw _privateConstructorUsedError;
  List<MuscleGroup> get targetMuscles => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $ExerciseEntityCopyWith<ExerciseEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ExerciseEntityCopyWith<$Res> {
  factory $ExerciseEntityCopyWith(
          ExerciseEntity value, $Res Function(ExerciseEntity) then) =
      _$ExerciseEntityCopyWithImpl<$Res, ExerciseEntity>;
  @useResult
  $Res call(
      {String id,
      String exerciseName,
      int orderIndex,
      int targetSets,
      int? targetReps,
      int? targetRepsMax,
      int? targetSeconds,
      bool isWarmup,
      int restSeconds,
      String? videoUrl,
      String? imageUrl,
      String? instructions,
      double? targetWeight,
      double? rpe,
      int? tempoEccentric,
      int? tempoPause,
      int? tempoConcentric,
      String? progressionNote,
      List<MuscleGroup> targetMuscles});
}

/// @nodoc
class _$ExerciseEntityCopyWithImpl<$Res, $Val extends ExerciseEntity>
    implements $ExerciseEntityCopyWith<$Res> {
  _$ExerciseEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? exerciseName = null,
    Object? orderIndex = null,
    Object? targetSets = null,
    Object? targetReps = freezed,
    Object? targetRepsMax = freezed,
    Object? targetSeconds = freezed,
    Object? isWarmup = null,
    Object? restSeconds = null,
    Object? videoUrl = freezed,
    Object? imageUrl = freezed,
    Object? instructions = freezed,
    Object? targetWeight = freezed,
    Object? rpe = freezed,
    Object? tempoEccentric = freezed,
    Object? tempoPause = freezed,
    Object? tempoConcentric = freezed,
    Object? progressionNote = freezed,
    Object? targetMuscles = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      exerciseName: null == exerciseName
          ? _value.exerciseName
          : exerciseName // ignore: cast_nullable_to_non_nullable
              as String,
      orderIndex: null == orderIndex
          ? _value.orderIndex
          : orderIndex // ignore: cast_nullable_to_non_nullable
              as int,
      targetSets: null == targetSets
          ? _value.targetSets
          : targetSets // ignore: cast_nullable_to_non_nullable
              as int,
      targetReps: freezed == targetReps
          ? _value.targetReps
          : targetReps // ignore: cast_nullable_to_non_nullable
              as int?,
      targetRepsMax: freezed == targetRepsMax
          ? _value.targetRepsMax
          : targetRepsMax // ignore: cast_nullable_to_non_nullable
              as int?,
      targetSeconds: freezed == targetSeconds
          ? _value.targetSeconds
          : targetSeconds // ignore: cast_nullable_to_non_nullable
              as int?,
      isWarmup: null == isWarmup
          ? _value.isWarmup
          : isWarmup // ignore: cast_nullable_to_non_nullable
              as bool,
      restSeconds: null == restSeconds
          ? _value.restSeconds
          : restSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      videoUrl: freezed == videoUrl
          ? _value.videoUrl
          : videoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      imageUrl: freezed == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      instructions: freezed == instructions
          ? _value.instructions
          : instructions // ignore: cast_nullable_to_non_nullable
              as String?,
      targetWeight: freezed == targetWeight
          ? _value.targetWeight
          : targetWeight // ignore: cast_nullable_to_non_nullable
              as double?,
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
      progressionNote: freezed == progressionNote
          ? _value.progressionNote
          : progressionNote // ignore: cast_nullable_to_non_nullable
              as String?,
      targetMuscles: null == targetMuscles
          ? _value.targetMuscles
          : targetMuscles // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ExerciseEntityImplCopyWith<$Res>
    implements $ExerciseEntityCopyWith<$Res> {
  factory _$$ExerciseEntityImplCopyWith(_$ExerciseEntityImpl value,
          $Res Function(_$ExerciseEntityImpl) then) =
      __$$ExerciseEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String exerciseName,
      int orderIndex,
      int targetSets,
      int? targetReps,
      int? targetRepsMax,
      int? targetSeconds,
      bool isWarmup,
      int restSeconds,
      String? videoUrl,
      String? imageUrl,
      String? instructions,
      double? targetWeight,
      double? rpe,
      int? tempoEccentric,
      int? tempoPause,
      int? tempoConcentric,
      String? progressionNote,
      List<MuscleGroup> targetMuscles});
}

/// @nodoc
class __$$ExerciseEntityImplCopyWithImpl<$Res>
    extends _$ExerciseEntityCopyWithImpl<$Res, _$ExerciseEntityImpl>
    implements _$$ExerciseEntityImplCopyWith<$Res> {
  __$$ExerciseEntityImplCopyWithImpl(
      _$ExerciseEntityImpl _value, $Res Function(_$ExerciseEntityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? exerciseName = null,
    Object? orderIndex = null,
    Object? targetSets = null,
    Object? targetReps = freezed,
    Object? targetRepsMax = freezed,
    Object? targetSeconds = freezed,
    Object? isWarmup = null,
    Object? restSeconds = null,
    Object? videoUrl = freezed,
    Object? imageUrl = freezed,
    Object? instructions = freezed,
    Object? targetWeight = freezed,
    Object? rpe = freezed,
    Object? tempoEccentric = freezed,
    Object? tempoPause = freezed,
    Object? tempoConcentric = freezed,
    Object? progressionNote = freezed,
    Object? targetMuscles = null,
  }) {
    return _then(_$ExerciseEntityImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      exerciseName: null == exerciseName
          ? _value.exerciseName
          : exerciseName // ignore: cast_nullable_to_non_nullable
              as String,
      orderIndex: null == orderIndex
          ? _value.orderIndex
          : orderIndex // ignore: cast_nullable_to_non_nullable
              as int,
      targetSets: null == targetSets
          ? _value.targetSets
          : targetSets // ignore: cast_nullable_to_non_nullable
              as int,
      targetReps: freezed == targetReps
          ? _value.targetReps
          : targetReps // ignore: cast_nullable_to_non_nullable
              as int?,
      targetRepsMax: freezed == targetRepsMax
          ? _value.targetRepsMax
          : targetRepsMax // ignore: cast_nullable_to_non_nullable
              as int?,
      targetSeconds: freezed == targetSeconds
          ? _value.targetSeconds
          : targetSeconds // ignore: cast_nullable_to_non_nullable
              as int?,
      isWarmup: null == isWarmup
          ? _value.isWarmup
          : isWarmup // ignore: cast_nullable_to_non_nullable
              as bool,
      restSeconds: null == restSeconds
          ? _value.restSeconds
          : restSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      videoUrl: freezed == videoUrl
          ? _value.videoUrl
          : videoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      imageUrl: freezed == imageUrl
          ? _value.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      instructions: freezed == instructions
          ? _value.instructions
          : instructions // ignore: cast_nullable_to_non_nullable
              as String?,
      targetWeight: freezed == targetWeight
          ? _value.targetWeight
          : targetWeight // ignore: cast_nullable_to_non_nullable
              as double?,
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
      progressionNote: freezed == progressionNote
          ? _value.progressionNote
          : progressionNote // ignore: cast_nullable_to_non_nullable
              as String?,
      targetMuscles: null == targetMuscles
          ? _value._targetMuscles
          : targetMuscles // ignore: cast_nullable_to_non_nullable
              as List<MuscleGroup>,
    ));
  }
}

/// @nodoc

class _$ExerciseEntityImpl implements _ExerciseEntity {
  const _$ExerciseEntityImpl(
      {required this.id,
      required this.exerciseName,
      required this.orderIndex,
      required this.targetSets,
      this.targetReps,
      this.targetRepsMax,
      this.targetSeconds,
      this.isWarmup = false,
      required this.restSeconds,
      this.videoUrl,
      this.imageUrl,
      this.instructions,
      this.targetWeight,
      this.rpe,
      this.tempoEccentric,
      this.tempoPause,
      this.tempoConcentric,
      this.progressionNote,
      final List<MuscleGroup> targetMuscles = const []})
      : _targetMuscles = targetMuscles;

  @override
  final String id;
  @override
  final String exerciseName;
  @override
  final int orderIndex;
  @override
  final int targetSets;
  @override
  final int? targetReps;
  @override
  final int? targetRepsMax;
// P2-E: upper rep bound for progressive overload display
  @override
  final int? targetSeconds;
// P2-A: timed holds (Plank, wall-sit) — from targetDuration
  @override
  @JsonKey()
  final bool isWarmup;
// P2-C: warmup flag (orderIndex >= 1000)
  @override
  final int restSeconds;
  @override
  final String? videoUrl;
  @override
  final String? imageUrl;
  @override
  final String? instructions;
  @override
  final double? targetWeight;
  @override
  final double? rpe;
  @override
  final int? tempoEccentric;
  @override
  final int? tempoPause;
  @override
  final int? tempoConcentric;
  @override
  final String? progressionNote;
  final List<MuscleGroup> _targetMuscles;
  @override
  @JsonKey()
  List<MuscleGroup> get targetMuscles {
    if (_targetMuscles is EqualUnmodifiableListView) return _targetMuscles;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_targetMuscles);
  }

  @override
  String toString() {
    return 'ExerciseEntity(id: $id, exerciseName: $exerciseName, orderIndex: $orderIndex, targetSets: $targetSets, targetReps: $targetReps, targetRepsMax: $targetRepsMax, targetSeconds: $targetSeconds, isWarmup: $isWarmup, restSeconds: $restSeconds, videoUrl: $videoUrl, imageUrl: $imageUrl, instructions: $instructions, targetWeight: $targetWeight, rpe: $rpe, tempoEccentric: $tempoEccentric, tempoPause: $tempoPause, tempoConcentric: $tempoConcentric, progressionNote: $progressionNote, targetMuscles: $targetMuscles)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ExerciseEntityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.exerciseName, exerciseName) ||
                other.exerciseName == exerciseName) &&
            (identical(other.orderIndex, orderIndex) ||
                other.orderIndex == orderIndex) &&
            (identical(other.targetSets, targetSets) ||
                other.targetSets == targetSets) &&
            (identical(other.targetReps, targetReps) ||
                other.targetReps == targetReps) &&
            (identical(other.targetRepsMax, targetRepsMax) ||
                other.targetRepsMax == targetRepsMax) &&
            (identical(other.targetSeconds, targetSeconds) ||
                other.targetSeconds == targetSeconds) &&
            (identical(other.isWarmup, isWarmup) ||
                other.isWarmup == isWarmup) &&
            (identical(other.restSeconds, restSeconds) ||
                other.restSeconds == restSeconds) &&
            (identical(other.videoUrl, videoUrl) ||
                other.videoUrl == videoUrl) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.instructions, instructions) ||
                other.instructions == instructions) &&
            (identical(other.targetWeight, targetWeight) ||
                other.targetWeight == targetWeight) &&
            (identical(other.rpe, rpe) || other.rpe == rpe) &&
            (identical(other.tempoEccentric, tempoEccentric) ||
                other.tempoEccentric == tempoEccentric) &&
            (identical(other.tempoPause, tempoPause) ||
                other.tempoPause == tempoPause) &&
            (identical(other.tempoConcentric, tempoConcentric) ||
                other.tempoConcentric == tempoConcentric) &&
            (identical(other.progressionNote, progressionNote) ||
                other.progressionNote == progressionNote) &&
            const DeepCollectionEquality()
                .equals(other._targetMuscles, _targetMuscles));
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        exerciseName,
        orderIndex,
        targetSets,
        targetReps,
        targetRepsMax,
        targetSeconds,
        isWarmup,
        restSeconds,
        videoUrl,
        imageUrl,
        instructions,
        targetWeight,
        rpe,
        tempoEccentric,
        tempoPause,
        tempoConcentric,
        progressionNote,
        const DeepCollectionEquality().hash(_targetMuscles)
      ]);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ExerciseEntityImplCopyWith<_$ExerciseEntityImpl> get copyWith =>
      __$$ExerciseEntityImplCopyWithImpl<_$ExerciseEntityImpl>(
          this, _$identity);
}

abstract class _ExerciseEntity implements ExerciseEntity {
  const factory _ExerciseEntity(
      {required final String id,
      required final String exerciseName,
      required final int orderIndex,
      required final int targetSets,
      final int? targetReps,
      final int? targetRepsMax,
      final int? targetSeconds,
      final bool isWarmup,
      required final int restSeconds,
      final String? videoUrl,
      final String? imageUrl,
      final String? instructions,
      final double? targetWeight,
      final double? rpe,
      final int? tempoEccentric,
      final int? tempoPause,
      final int? tempoConcentric,
      final String? progressionNote,
      final List<MuscleGroup> targetMuscles}) = _$ExerciseEntityImpl;

  @override
  String get id;
  @override
  String get exerciseName;
  @override
  int get orderIndex;
  @override
  int get targetSets;
  @override
  int? get targetReps;
  @override
  int? get targetRepsMax;
  @override // P2-E: upper rep bound for progressive overload display
  int? get targetSeconds;
  @override // P2-A: timed holds (Plank, wall-sit) — from targetDuration
  bool get isWarmup;
  @override // P2-C: warmup flag (orderIndex >= 1000)
  int get restSeconds;
  @override
  String? get videoUrl;
  @override
  String? get imageUrl;
  @override
  String? get instructions;
  @override
  double? get targetWeight;
  @override
  double? get rpe;
  @override
  int? get tempoEccentric;
  @override
  int? get tempoPause;
  @override
  int? get tempoConcentric;
  @override
  String? get progressionNote;
  @override
  List<MuscleGroup> get targetMuscles;
  @override
  @JsonKey(ignore: true)
  _$$ExerciseEntityImplCopyWith<_$ExerciseEntityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
