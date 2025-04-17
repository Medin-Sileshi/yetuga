// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_cache.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OnboardingCacheAdapter extends TypeAdapter<OnboardingCache> {
  @override
  final int typeId = 2;

  @override
  OnboardingCache read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OnboardingCache(
      accountType: fields[0] as String?,
      displayName: fields[1] as String?,
      username: fields[2] as String?,
      birthday: fields[3] as DateTime?,
      phoneNumber: fields[4] as String?,
      profileImageUrl: fields[5] as String?,
      interests: (fields[6] as List?)?.cast<String>(),
      isComplete: fields[7] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, OnboardingCache obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.accountType)
      ..writeByte(1)
      ..write(obj.displayName)
      ..writeByte(2)
      ..write(obj.username)
      ..writeByte(3)
      ..write(obj.birthday)
      ..writeByte(4)
      ..write(obj.phoneNumber)
      ..writeByte(5)
      ..write(obj.profileImageUrl)
      ..writeByte(6)
      ..write(obj.interests)
      ..writeByte(7)
      ..write(obj.isComplete);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnboardingCacheAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
