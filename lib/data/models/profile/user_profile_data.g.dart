// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserProfileDataAdapter extends TypeAdapter<UserProfileData> {
  @override
  final int typeId = 2;

  @override
  UserProfileData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProfileData(
      username: fields[0] as String?,
      email: fields[1] as String?,
      avatarCacheKey: fields[2] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, UserProfileData obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.username)
      ..writeByte(1)
      ..write(obj.email)
      ..writeByte(2)
      ..write(obj.avatarCacheKey);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfileDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
