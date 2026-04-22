// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserModelAdapter extends TypeAdapter<UserModel> {
  @override
  final int typeId = 40;

  @override
  UserModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserModel(
      id: fields[0] as String,
      email: fields[1] as String,
      role: fields[2] as String,
      managedGymId: fields[3] as String?,
      phoneNumber: fields[4] as String?,
      fullName: fields[5] as String?,
      firstName: fields[6] as String?,
      lastName: fields[7] as String?,
      gender: fields[8] as String?,
      dob: fields[9] as String?,
      weight: fields[10] as String?,
      height: fields[11] as String?,
      medicalConditions: fields[12] as String?,
      noMedicalConditions: fields[13] as bool,
      personalNumber: fields[14] as String?,
      address: fields[15] as String?,
      avatarUrl: fields[16] as String?,
      idPhotoUrl: fields[17] as String?,
      targetWeightKg: fields[18] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, UserModel obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.email)
      ..writeByte(2)
      ..write(obj.role)
      ..writeByte(3)
      ..write(obj.managedGymId)
      ..writeByte(4)
      ..write(obj.phoneNumber)
      ..writeByte(5)
      ..write(obj.fullName)
      ..writeByte(6)
      ..write(obj.firstName)
      ..writeByte(7)
      ..write(obj.lastName)
      ..writeByte(8)
      ..write(obj.gender)
      ..writeByte(9)
      ..write(obj.dob)
      ..writeByte(10)
      ..write(obj.weight)
      ..writeByte(11)
      ..write(obj.height)
      ..writeByte(12)
      ..write(obj.medicalConditions)
      ..writeByte(13)
      ..write(obj.noMedicalConditions)
      ..writeByte(14)
      ..write(obj.personalNumber)
      ..writeByte(15)
      ..write(obj.address)
      ..writeByte(16)
      ..write(obj.avatarUrl)
      ..writeByte(17)
      ..write(obj.idPhotoUrl)
      ..writeByte(18)
      ..write(obj.targetWeightKg);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserModelImpl _$$UserModelImplFromJson(Map<String, dynamic> json) =>
    _$UserModelImpl(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      managedGymId: json['managedGymId'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      fullName: json['fullName'] as String?,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      gender: json['gender'] as String?,
      dob: json['dob'] as String?,
      weight: json['weight'] as String?,
      height: json['height'] as String?,
      medicalConditions: json['medicalConditions'] as String?,
      noMedicalConditions: json['noMedicalConditions'] as bool? ?? false,
      personalNumber: json['personalNumber'] as String?,
      address: json['address'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      idPhotoUrl: json['idPhotoUrl'] as String?,
      targetWeightKg: (json['targetWeightKg'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$$UserModelImplToJson(_$UserModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'role': instance.role,
      'managedGymId': instance.managedGymId,
      'phoneNumber': instance.phoneNumber,
      'fullName': instance.fullName,
      'firstName': instance.firstName,
      'lastName': instance.lastName,
      'gender': instance.gender,
      'dob': instance.dob,
      'weight': instance.weight,
      'height': instance.height,
      'medicalConditions': instance.medicalConditions,
      'noMedicalConditions': instance.noMedicalConditions,
      'personalNumber': instance.personalNumber,
      'address': instance.address,
      'avatarUrl': instance.avatarUrl,
      'idPhotoUrl': instance.idPhotoUrl,
      'targetWeightKg': instance.targetWeightKg,
    };
