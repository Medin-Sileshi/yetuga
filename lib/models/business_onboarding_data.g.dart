// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_onboarding_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BusinessOnboardingDataAdapter
    extends TypeAdapter<BusinessOnboardingData> {
  @override
  final int typeId = 1;

  @override
  BusinessOnboardingData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BusinessOnboardingData()
      ..accountType = fields[0] as String?
      ..businessName = fields[1] as String?
      ..establishedDate = fields[2] as DateTime?
      ..phoneNumber = fields[3] as String?
      ..profileImageUrl = fields[4] as String?
      ..businessTypes = (fields[5] as List?)?.cast<String>()
      ..username = fields[6] as String?
      ..onboardingCompleted = fields[7] as bool;
  }

  @override
  void write(BinaryWriter writer, BusinessOnboardingData obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.accountType)
      ..writeByte(1)
      ..write(obj.businessName)
      ..writeByte(2)
      ..write(obj.establishedDate)
      ..writeByte(3)
      ..write(obj.phoneNumber)
      ..writeByte(4)
      ..write(obj.profileImageUrl)
      ..writeByte(5)
      ..write(obj.businessTypes)
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
      other is BusinessOnboardingDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
