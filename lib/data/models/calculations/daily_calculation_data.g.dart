// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_calculation_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DailyCalculationDataAdapter extends TypeAdapter<DailyCalculationData> {
  @override
  final int typeId = 3;

  @override
  DailyCalculationData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyCalculationData(
      date: fields[0] as DateTime,
      totalMealInsulin: fields[1] as double?,
      dailyCorrectionIndex: fields[2] as double?,
      periodFinalIndexAverage: (fields[3] as Map?)?.cast<String, double>(),
    );
  }

  @override
  void write(BinaryWriter writer, DailyCalculationData obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.totalMealInsulin)
      ..writeByte(2)
      ..write(obj.dailyCorrectionIndex)
      ..writeByte(3)
      ..write(obj.periodFinalIndexAverage);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyCalculationDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
