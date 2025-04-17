// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OnboardingDataAdapter extends TypeAdapter<OnboardingData> {
  @override
  final int typeId = 0;

  @override
  OnboardingData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OnboardingData()
      ..accountType = fields[0] as String?
      ..displayName = fields[1] as String?
      ..birthday = fields[2] as DateTime?
      ..phoneNumber = fields[3] as String?
      ..profileImageUrl = fields[4] as String?
      ..interests = (fields[5] as List?)?.cast<String>()
      ..username = fields[6] as String?
      ..onboardingCompleted = fields[7] as bool? ?? false;
  }

  @override
  void write(BinaryWriter writer, OnboardingData obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.accountType)
      ..writeByte(1)
      ..write(obj.displayName)
      ..writeByte(2)
      ..write(obj.birthday)
      ..writeByte(3)
      ..write(obj.phoneNumber)
      ..writeByte(4)
      ..write(obj.profileImageUrl)
      ..writeByte(5)
      ..write(obj.interests)
      ..writeByte(6)
      ..write(obj.username)
      ..writeByte(7)
      ..write(obj.onboardingCompleted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnboardingDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
