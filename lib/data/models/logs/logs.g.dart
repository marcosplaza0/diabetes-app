// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'logs.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MealLogAdapter extends TypeAdapter<MealLog> {
  @override
  final int typeId = 0;

  @override
  MealLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MealLog(
      startTime: fields[0] as DateTime,
      initialBloodSugar: fields[1] as double,
      carbohydrates: fields[2] as double,
      insulinUnits: fields[3] as double,
      finalBloodSugar: fields[4] as double?,
      endTime: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, MealLog obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.startTime)
      ..writeByte(1)
      ..write(obj.initialBloodSugar)
      ..writeByte(2)
      ..write(obj.carbohydrates)
      ..writeByte(3)
      ..write(obj.insulinUnits)
      ..writeByte(4)
      ..write(obj.finalBloodSugar)
      ..writeByte(5)
      ..write(obj.endTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OvernightLogAdapter extends TypeAdapter<OvernightLog> {
  @override
  final int typeId = 1;

  @override
  OvernightLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OvernightLog(
      bedTime: fields[0] as DateTime,
      beforeSleepBloodSugar: fields[1] as double,
      slowInsulinUnits: fields[2] as double,
      afterWakeUpBloodSugar: fields[3] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, OvernightLog obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.bedTime)
      ..writeByte(1)
      ..write(obj.beforeSleepBloodSugar)
      ..writeByte(2)
      ..write(obj.slowInsulinUnits)
      ..writeByte(3)
      ..write(obj.afterWakeUpBloodSugar);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OvernightLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
