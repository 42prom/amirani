// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_preferences_entity.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserInjuryEntityAdapter extends TypeAdapter<UserInjuryEntity> {
  @override
  final int typeId = 36;

  @override
  UserInjuryEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserInjuryEntity(
      type: fields[0] as InjuryType,
      severity: fields[1] as InjurySeverity,
      customName: fields[2] as String?,
      notes: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, UserInjuryEntity obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.severity)
      ..writeByte(2)
      ..write(obj.customName)
      ..writeByte(3)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserInjuryEntityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WorkoutPreferencesEntityAdapter
    extends TypeAdapter<WorkoutPreferencesEntity> {
  @override
  final int typeId = 37;

  @override
  WorkoutPreferencesEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkoutPreferencesEntity(
      odUserId: fields[0] as String,
      goal: fields[1] as WorkoutGoal,
      location: fields[2] as TrainingLocation,
      availableEquipment: (fields[3] as List).cast<Equipment>(),
      outOfOrderMachines: (fields[4] as List).cast<String>(),
      trainingSplit: fields[5] as TrainingSplit,
      fitnessLevel: fields[6] as FitnessLevel,
      experienceYears: fields[7] as int,
      injuries: (fields[8] as List).cast<UserInjuryEntity>(),
      likedExercises: (fields[9] as List).cast<String>(),
      dislikedExercises: (fields[10] as List).cast<String>(),
      daysPerWeek: fields[11] as int,
      preferredDays: (fields[12] as List).cast<int>(),
      sessionDurationMinutes: fields[13] as int,
      preferredTime: fields[14] as PreferredWorkoutTime,
      workoutRemindersEnabled: fields[15] as bool,
      reminderTime: fields[16] as String?,
      targetWeightKg: fields[17] as double?,
      targetCaloriesBurnedPerSession: fields[18] as int?,
      targetMuscles: (fields[21] as List).cast<String>(),
      createdAt: fields[19] as DateTime?,
      updatedAt: fields[20] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutPreferencesEntity obj) {
    writer
      ..writeByte(22)
      ..writeByte(0)
      ..write(obj.odUserId)
      ..writeByte(1)
      ..write(obj.goal)
      ..writeByte(2)
      ..write(obj.location)
      ..writeByte(3)
      ..write(obj.availableEquipment)
      ..writeByte(4)
      ..write(obj.outOfOrderMachines)
      ..writeByte(5)
      ..write(obj.trainingSplit)
      ..writeByte(6)
      ..write(obj.fitnessLevel)
      ..writeByte(7)
      ..write(obj.experienceYears)
      ..writeByte(8)
      ..write(obj.injuries)
      ..writeByte(9)
      ..write(obj.likedExercises)
      ..writeByte(10)
      ..write(obj.dislikedExercises)
      ..writeByte(11)
      ..write(obj.daysPerWeek)
      ..writeByte(12)
      ..write(obj.preferredDays)
      ..writeByte(13)
      ..write(obj.sessionDurationMinutes)
      ..writeByte(14)
      ..write(obj.preferredTime)
      ..writeByte(15)
      ..write(obj.workoutRemindersEnabled)
      ..writeByte(16)
      ..write(obj.reminderTime)
      ..writeByte(17)
      ..write(obj.targetWeightKg)
      ..writeByte(18)
      ..write(obj.targetCaloriesBurnedPerSession)
      ..writeByte(21)
      ..write(obj.targetMuscles)
      ..writeByte(19)
      ..write(obj.createdAt)
      ..writeByte(20)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutPreferencesEntityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WorkoutGoalAdapter extends TypeAdapter<WorkoutGoal> {
  @override
  final int typeId = 28;

  @override
  WorkoutGoal read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return WorkoutGoal.weightLoss;
      case 1:
        return WorkoutGoal.muscleGain;
      case 2:
        return WorkoutGoal.strength;
      case 3:
        return WorkoutGoal.endurance;
      case 4:
        return WorkoutGoal.flexibility;
      case 5:
        return WorkoutGoal.generalFitness;
      default:
        return WorkoutGoal.weightLoss;
    }
  }

  @override
  void write(BinaryWriter writer, WorkoutGoal obj) {
    switch (obj) {
      case WorkoutGoal.weightLoss:
        writer.writeByte(0);
        break;
      case WorkoutGoal.muscleGain:
        writer.writeByte(1);
        break;
      case WorkoutGoal.strength:
        writer.writeByte(2);
        break;
      case WorkoutGoal.endurance:
        writer.writeByte(3);
        break;
      case WorkoutGoal.flexibility:
        writer.writeByte(4);
        break;
      case WorkoutGoal.generalFitness:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutGoalAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TrainingLocationAdapter extends TypeAdapter<TrainingLocation> {
  @override
  final int typeId = 29;

  @override
  TrainingLocation read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TrainingLocation.home;
      case 1:
        return TrainingLocation.gym;
      default:
        return TrainingLocation.home;
    }
  }

  @override
  void write(BinaryWriter writer, TrainingLocation obj) {
    switch (obj) {
      case TrainingLocation.home:
        writer.writeByte(0);
        break;
      case TrainingLocation.gym:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrainingLocationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class EquipmentAdapter extends TypeAdapter<Equipment> {
  @override
  final int typeId = 30;

  @override
  Equipment read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return Equipment.bodyweightOnly;
      case 1:
        return Equipment.dumbbells;
      case 2:
        return Equipment.barbell;
      case 3:
        return Equipment.machines;
      case 4:
        return Equipment.resistanceBands;
      case 5:
        return Equipment.pullUpBar;
      case 6:
        return Equipment.kettlebell;
      case 7:
        return Equipment.cables;
      case 8:
        return Equipment.bench;
      case 9:
        return Equipment.jumpRope;
      case 10:
        return Equipment.medicineBall;
      case 11:
        return Equipment.foamRoller;
      case 12:
        return Equipment.yogaMat;
      case 13:
        return Equipment.stabilityBall;
      case 14:
        return Equipment.trxStraps;
      case 15:
        return Equipment.parallelBars;
      case 16:
        return Equipment.weightedVest;
      case 17:
        return Equipment.ankleWeights;
      case 18:
        return Equipment.abWheel;
      case 19:
        return Equipment.battleRopes;
      default:
        return Equipment.bodyweightOnly;
    }
  }

  @override
  void write(BinaryWriter writer, Equipment obj) {
    switch (obj) {
      case Equipment.bodyweightOnly:
        writer.writeByte(0);
        break;
      case Equipment.dumbbells:
        writer.writeByte(1);
        break;
      case Equipment.barbell:
        writer.writeByte(2);
        break;
      case Equipment.machines:
        writer.writeByte(3);
        break;
      case Equipment.resistanceBands:
        writer.writeByte(4);
        break;
      case Equipment.pullUpBar:
        writer.writeByte(5);
        break;
      case Equipment.kettlebell:
        writer.writeByte(6);
        break;
      case Equipment.cables:
        writer.writeByte(7);
        break;
      case Equipment.bench:
        writer.writeByte(8);
        break;
      case Equipment.jumpRope:
        writer.writeByte(9);
        break;
      case Equipment.medicineBall:
        writer.writeByte(10);
        break;
      case Equipment.foamRoller:
        writer.writeByte(11);
        break;
      case Equipment.yogaMat:
        writer.writeByte(12);
        break;
      case Equipment.stabilityBall:
        writer.writeByte(13);
        break;
      case Equipment.trxStraps:
        writer.writeByte(14);
        break;
      case Equipment.parallelBars:
        writer.writeByte(15);
        break;
      case Equipment.weightedVest:
        writer.writeByte(16);
        break;
      case Equipment.ankleWeights:
        writer.writeByte(17);
        break;
      case Equipment.abWheel:
        writer.writeByte(18);
        break;
      case Equipment.battleRopes:
        writer.writeByte(19);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EquipmentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TrainingSplitAdapter extends TypeAdapter<TrainingSplit> {
  @override
  final int typeId = 31;

  @override
  TrainingSplit read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TrainingSplit.fullBody;
      case 1:
        return TrainingSplit.upperLower;
      case 2:
        return TrainingSplit.pushPullLegs;
      case 3:
        return TrainingSplit.broSplit;
      case 4:
        return TrainingSplit.custom;
      default:
        return TrainingSplit.fullBody;
    }
  }

  @override
  void write(BinaryWriter writer, TrainingSplit obj) {
    switch (obj) {
      case TrainingSplit.fullBody:
        writer.writeByte(0);
        break;
      case TrainingSplit.upperLower:
        writer.writeByte(1);
        break;
      case TrainingSplit.pushPullLegs:
        writer.writeByte(2);
        break;
      case TrainingSplit.broSplit:
        writer.writeByte(3);
        break;
      case TrainingSplit.custom:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrainingSplitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FitnessLevelAdapter extends TypeAdapter<FitnessLevel> {
  @override
  final int typeId = 32;

  @override
  FitnessLevel read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return FitnessLevel.beginner;
      case 1:
        return FitnessLevel.intermediate;
      case 2:
        return FitnessLevel.advanced;
      case 3:
        return FitnessLevel.athlete;
      default:
        return FitnessLevel.beginner;
    }
  }

  @override
  void write(BinaryWriter writer, FitnessLevel obj) {
    switch (obj) {
      case FitnessLevel.beginner:
        writer.writeByte(0);
        break;
      case FitnessLevel.intermediate:
        writer.writeByte(1);
        break;
      case FitnessLevel.advanced:
        writer.writeByte(2);
        break;
      case FitnessLevel.athlete:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FitnessLevelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PreferredWorkoutTimeAdapter extends TypeAdapter<PreferredWorkoutTime> {
  @override
  final int typeId = 33;

  @override
  PreferredWorkoutTime read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PreferredWorkoutTime.earlyMorning;
      case 1:
        return PreferredWorkoutTime.morning;
      case 2:
        return PreferredWorkoutTime.midday;
      case 3:
        return PreferredWorkoutTime.afternoon;
      case 4:
        return PreferredWorkoutTime.evening;
      case 5:
        return PreferredWorkoutTime.night;
      default:
        return PreferredWorkoutTime.earlyMorning;
    }
  }

  @override
  void write(BinaryWriter writer, PreferredWorkoutTime obj) {
    switch (obj) {
      case PreferredWorkoutTime.earlyMorning:
        writer.writeByte(0);
        break;
      case PreferredWorkoutTime.morning:
        writer.writeByte(1);
        break;
      case PreferredWorkoutTime.midday:
        writer.writeByte(2);
        break;
      case PreferredWorkoutTime.afternoon:
        writer.writeByte(3);
        break;
      case PreferredWorkoutTime.evening:
        writer.writeByte(4);
        break;
      case PreferredWorkoutTime.night:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PreferredWorkoutTimeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class InjuryTypeAdapter extends TypeAdapter<InjuryType> {
  @override
  final int typeId = 34;

  @override
  InjuryType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return InjuryType.shoulder;
      case 1:
        return InjuryType.back;
      case 2:
        return InjuryType.knee;
      case 3:
        return InjuryType.wrist;
      case 4:
        return InjuryType.ankle;
      case 5:
        return InjuryType.hip;
      case 6:
        return InjuryType.neck;
      case 7:
        return InjuryType.elbow;
      case 8:
        return InjuryType.other;
      default:
        return InjuryType.shoulder;
    }
  }

  @override
  void write(BinaryWriter writer, InjuryType obj) {
    switch (obj) {
      case InjuryType.shoulder:
        writer.writeByte(0);
        break;
      case InjuryType.back:
        writer.writeByte(1);
        break;
      case InjuryType.knee:
        writer.writeByte(2);
        break;
      case InjuryType.wrist:
        writer.writeByte(3);
        break;
      case InjuryType.ankle:
        writer.writeByte(4);
        break;
      case InjuryType.hip:
        writer.writeByte(5);
        break;
      case InjuryType.neck:
        writer.writeByte(6);
        break;
      case InjuryType.elbow:
        writer.writeByte(7);
        break;
      case InjuryType.other:
        writer.writeByte(8);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InjuryTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class InjurySeverityAdapter extends TypeAdapter<InjurySeverity> {
  @override
  final int typeId = 35;

  @override
  InjurySeverity read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return InjurySeverity.minor;
      case 1:
        return InjurySeverity.moderate;
      case 2:
        return InjurySeverity.severe;
      default:
        return InjurySeverity.minor;
    }
  }

  @override
  void write(BinaryWriter writer, InjurySeverity obj) {
    switch (obj) {
      case InjurySeverity.minor:
        writer.writeByte(0);
        break;
      case InjurySeverity.moderate:
        writer.writeByte(1);
        break;
      case InjurySeverity.severe:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InjurySeverityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
