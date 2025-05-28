// diabetes_2/data/transfer_objects/logs.dart
import 'package:hive/hive.dart';

part 'logs.g.dart'; // Importante: Este archivo se generará

@HiveType(typeId: 0) // typeId debe ser único por clase
class MealLog extends HiveObject { // Extender HiveObject es opcional pero útil para auto-increment keys, etc.
  @HiveField(0)
  DateTime startTime;

  @HiveField(1)
  double initialBloodSugar;

  @HiveField(2)
  double carbohydrates;

  @HiveField(3)
  double insulinUnits;

  @HiveField(4)
  double? finalBloodSugar; // Campo opcional

  @HiveField(5)
  DateTime? endTime; // Campo opcional

  MealLog({
    required this.startTime,
    required this.initialBloodSugar,
    required this.carbohydrates,
    required this.insulinUnits,
    this.finalBloodSugar,
    this.endTime,
  });

  @override
  String toString() {
    return 'MealLog('
        'startTime: $startTime, '
        'initialBloodSugar: $initialBloodSugar, '
        'carbohydrates: $carbohydrates, '
        'insulinUnits: $insulinUnits, '
        'finalBloodSugar: $finalBloodSugar, '
        'endTime: $endTime'
        ')';
  }
}

@HiveType(typeId: 1) // typeId único y diferente del anterior
class OvernightLog extends HiveObject {
  @HiveField(0)
  DateTime bedTime;

  @HiveField(1)
  double beforeSleepBloodSugar;

  @HiveField(2)
  double slowInsulinUnits;

  @HiveField(3)
  double? afterWakeUpBloodSugar; // Campo opcional

  OvernightLog({
    required this.bedTime,
    required this.beforeSleepBloodSugar,
    required this.slowInsulinUnits,
    this.afterWakeUpBloodSugar,
  });

  @override
  String toString() {
    return 'OvernightLog('
        'bedTime: $bedTime, '
        'beforeSleepBloodSugar: $beforeSleepBloodSugar, '
        'slowInsulinUnits: $slowInsulinUnits, '
        'afterWakeUpBloodSugar: $afterWakeUpBloodSugar, '
        ')';
  }
}