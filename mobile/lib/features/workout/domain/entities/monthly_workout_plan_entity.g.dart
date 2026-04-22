// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monthly_workout_plan_entity.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExerciseSetEntityAdapter extends TypeAdapter<ExerciseSetEntity> {
  @override
  final int typeId = 22;

  @override
  ExerciseSetEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExerciseSetEntity(
      setNumber: fields[0] as int,
      targetReps: fields[1] as int,
      targetRepsMax: fields[13] as int?,
      targetSeconds: fields[2] as int?,
      targetWeight: fields[3] as double?,
      restSeconds: fields[4] as int,
      isCompleted: fields[5] as bool,
      actualReps: fields[6] as int?,
      actualWeight: fields[7] as double?,
      completedAt: fields[8] as DateTime?,
      rpe: fields[9] as double?,
      tempoEccentric: fields[10] as int?,
      tempoPause: fields[11] as int?,
      tempoConcentric: fields[12] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, ExerciseSetEntity obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.setNumber)
      ..writeByte(1)
      ..write(obj.targetReps)
      ..writeByte(13)
      ..write(obj.targetRepsMax)
      ..writeByte(2)
      ..write(obj.targetSeconds)
      ..writeByte(3)
      ..write(obj.targetWeight)
      ..writeByte(4)
      ..write(obj.restSeconds)
      ..writeByte(5)
      ..write(obj.isCompleted)
      ..writeByte(6)
      ..write(obj.actualReps)
      ..writeByte(7)
      ..write(obj.actualWeight)
      ..writeByte(8)
      ..write(obj.completedAt)
      ..writeByte(9)
      ..write(obj.rpe)
      ..writeByte(10)
      ..write(obj.tempoEccentric)
      ..writeByte(11)
      ..write(obj.tempoPause)
      ..writeByte(12)
      ..write(obj.tempoConcentric);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExerciseSetEntityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PlannedExerciseEntityAdapter extends TypeAdapter<PlannedExerciseEntity> {
  @override
  final int typeId = 23;

  @override
  PlannedExerciseEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlannedExerciseEntity(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      targetMuscles: (fields[3] as List).cast<MuscleGroup>(),
      difficulty: fields[4] as ExerciseDifficulty,
      sets: (fields[5] as List).cast<ExerciseSetEntity>(),
      requiredEquipment: (fields[6] as List).cast<Equipment>(),
      imageUrl: fields[7] as String?,
      videoUrl: fields[8] as String?,
      instructions: fields[9] as String?,
      isCompleted: fields[10] as bool,
      isSwapped: fields[11] as bool,
      isSkipped: fields[12] as bool,
      completedAt: fields[13] as DateTime?,
      progressionNote: fields[14] as String?,
      rpe: fields[15] as double?,
      targetWeight: fields[16] as double?,
      tempoEccentric: fields[17] as int?,
      tempoPause: fields[18] as int?,
      tempoConcentric: fields[19] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, PlannedExerciseEntity obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.targetMuscles)
      ..writeByte(4)
      ..write(obj.difficulty)
      ..writeByte(5)
      ..write(obj.sets)
      ..writeByte(6)
      ..write(obj.requiredEquipment)
      ..writeByte(7)
      ..write(obj.imageUrl)
      ..writeByte(8)
      ..write(obj.videoUrl)
      ..writeByte(9)
      ..write(obj.instructions)
      ..writeByte(10)
      ..write(obj.isCompleted)
      ..writeByte(11)
      ..write(obj.isSwapped)
      ..writeByte(12)
      ..write(obj.isSkipped)
      ..writeByte(13)
      ..write(obj.completedAt)
      ..writeByte(14)
      ..write(obj.progressionNote)
      ..writeByte(15)
      ..write(obj.rpe)
      ..writeByte(16)
      ..write(obj.targetWeight)
      ..writeByte(17)
      ..write(obj.tempoEccentric)
      ..writeByte(18)
      ..write(obj.tempoPause)
      ..writeByte(19)
      ..write(obj.tempoConcentric);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlannedExerciseEntityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DailyWorkoutPlanEntityAdapter
    extends TypeAdapter<DailyWorkoutPlanEntity> {
  @override
  final int typeId = 24;

  @override
  DailyWorkoutPlanEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyWorkoutPlanEntity(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      workoutName: fields[2] as String,
      exercises: (fields[3] as List).cast<PlannedExerciseEntity>(),
      estimatedDurationMinutes: fields[4] as int,
      estimatedCaloriesBurned: fields[5] as int,
      targetMuscleGroups: (fields[6] as List).cast<MuscleGroup>(),
      scheduledTime: fields[7] as String?,
      isRestDay: fields[8] as bool,
      isCompleted: fields[9] as bool,
      startedAt: fields[10] as DateTime?,
      completedAt: fields[11] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, DailyWorkoutPlanEntity obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.workoutName)
      ..writeByte(3)
      ..write(obj.exercises)
      ..writeByte(4)
      ..write(obj.estimatedDurationMinutes)
      ..writeByte(5)
      ..write(obj.estimatedCaloriesBurned)
      ..writeByte(6)
      ..write(obj.targetMuscleGroups)
      ..writeByte(7)
      ..write(obj.scheduledTime)
      ..writeByte(8)
      ..write(obj.isRestDay)
      ..writeByte(9)
      ..write(obj.isCompleted)
      ..writeByte(10)
      ..write(obj.startedAt)
      ..writeByte(11)
      ..write(obj.completedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyWorkoutPlanEntityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WeeklyWorkoutPlanEntityAdapter
    extends TypeAdapter<WeeklyWorkoutPlanEntity> {
  @override
  final int typeId = 25;

  @override
  WeeklyWorkoutPlanEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WeeklyWorkoutPlanEntity(
      weekNumber: fields[0] as int,
      startDate: fields[1] as DateTime,
      endDate: fields[2] as DateTime,
      days: (fields[3] as List).cast<DailyWorkoutPlanEntity>(),
    );
  }

  @override
  void write(BinaryWriter writer, WeeklyWorkoutPlanEntity obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.weekNumber)
      ..writeByte(1)
      ..write(obj.startDate)
      ..writeByte(2)
      ..write(obj.endDate)
      ..writeByte(3)
      ..write(obj.days);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeeklyWorkoutPlanEntityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DailyWorkoutTargetEntityAdapter
    extends TypeAdapter<DailyWorkoutTargetEntity> {
  @override
  final int typeId = 26;

  @override
  DailyWorkoutTargetEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyWorkoutTargetEntity(
      exercisesPerSession: fields[0] as int,
      durationMinutes: fields[1] as int,
      caloriesBurned: fields[2] as int,
      setsPerMuscleGroup: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, DailyWorkoutTargetEntity obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.exercisesPerSession)
      ..writeByte(1)
      ..write(obj.durationMinutes)
      ..writeByte(2)
      ..write(obj.caloriesBurned)
      ..writeByte(3)
      ..write(obj.setsPerMuscleGroup);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyWorkoutTargetEntityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MonthlyWorkoutPlanEntityAdapter
    extends TypeAdapter<MonthlyWorkoutPlanEntity> {
  @override
  final int typeId = 27;

  @override
  MonthlyWorkoutPlanEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MonthlyWorkoutPlanEntity(
      id: fields[0] as String,
      odUserId: fields[1] as String,
      startDate: fields[2] as DateTime,
      endDate: fields[3] as DateTime,
      goal: fields[4] as WorkoutGoal,
      location: fields[5] as TrainingLocation,
      split: fields[6] as TrainingSplit,
      dailyTarget: fields[7] as DailyWorkoutTargetEntity,
      weeks: (fields[8] as List).cast<WeeklyWorkoutPlanEntity>(),
      createdAt: fields[9] as DateTime?,
      updatedAt: fields[10] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, MonthlyWorkoutPlanEntity obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.odUserId)
      ..writeByte(2)
      ..write(obj.startDate)
      ..writeByte(3)
      ..write(obj.endDate)
      ..writeByte(4)
      ..write(obj.goal)
      ..writeByte(5)
      ..write(obj.location)
      ..writeByte(6)
      ..write(obj.split)
      ..writeByte(7)
      ..write(obj.dailyTarget)
      ..writeByte(8)
      ..write(obj.weeks)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthlyWorkoutPlanEntityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MuscleGroupAdapter extends TypeAdapter<MuscleGroup> {
  @override
  final int typeId = 20;

  @override
  MuscleGroup read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MuscleGroup.chest;
      case 1:
        return MuscleGroup.back;
      case 2:
        return MuscleGroup.shoulders;
      case 3:
        return MuscleGroup.biceps;
      case 4:
        return MuscleGroup.triceps;
      case 5:
        return MuscleGroup.forearms;
      case 6:
        return MuscleGroup.abs;
      case 7:
        return MuscleGroup.obliques;
      case 8:
        return MuscleGroup.quads;
      case 9:
        return MuscleGroup.hamstrings;
      case 10:
        return MuscleGroup.glutes;
      case 11:
        return MuscleGroup.calves;
      case 12:
        return MuscleGroup.traps;
      case 13:
        return MuscleGroup.neck;
      case 14:
        return MuscleGroup.adductors;
      case 15:
        return MuscleGroup.fullBody;
      case 16:
        return MuscleGroup.cardio;
      default:
        return MuscleGroup.chest;
    }
  }

  @override
  void write(BinaryWriter writer, MuscleGroup obj) {
    switch (obj) {
      case MuscleGroup.chest:
        writer.writeByte(0);
        break;
      case MuscleGroup.back:
        writer.writeByte(1);
        break;
      case MuscleGroup.shoulders:
        writer.writeByte(2);
        break;
      case MuscleGroup.biceps:
        writer.writeByte(3);
        break;
      case MuscleGroup.triceps:
        writer.writeByte(4);
        break;
      case MuscleGroup.forearms:
        writer.writeByte(5);
        break;
      case MuscleGroup.abs:
        writer.writeByte(6);
        break;
      case MuscleGroup.obliques:
        writer.writeByte(7);
        break;
      case MuscleGroup.quads:
        writer.writeByte(8);
        break;
      case MuscleGroup.hamstrings:
        writer.writeByte(9);
        break;
      case MuscleGroup.glutes:
        writer.writeByte(10);
        break;
      case MuscleGroup.calves:
        writer.writeByte(11);
        break;
      case MuscleGroup.traps:
        writer.writeByte(12);
        break;
      case MuscleGroup.neck:
        writer.writeByte(13);
        break;
      case MuscleGroup.adductors:
        writer.writeByte(14);
        break;
      case MuscleGroup.fullBody:
        writer.writeByte(15);
        break;
      case MuscleGroup.cardio:
        writer.writeByte(16);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MuscleGroupAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ExerciseDifficultyAdapter extends TypeAdapter<ExerciseDifficulty> {
  @override
  final int typeId = 21;

  @override
  ExerciseDifficulty read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ExerciseDifficulty.beginner;
      case 1:
        return ExerciseDifficulty.intermediate;
      case 2:
        return ExerciseDifficulty.advanced;
      default:
        return ExerciseDifficulty.beginner;
    }
  }

  @override
  void write(BinaryWriter writer, ExerciseDifficulty obj) {
    switch (obj) {
      case ExerciseDifficulty.beginner:
        writer.writeByte(0);
        break;
      case ExerciseDifficulty.intermediate:
        writer.writeByte(1);
        break;
      case ExerciseDifficulty.advanced:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExerciseDifficultyAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
