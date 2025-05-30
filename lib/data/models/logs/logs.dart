// lib/data/models/logs/logs.dart
import 'package:hive/hive.dart';

part 'logs.g.dart'; // Importante: Este archivo se generará/actualizará

@HiveType(typeId: 0)
class MealLog extends HiveObject {
  @HiveField(0)
  DateTime startTime;

  @HiveField(1)
  double initialBloodSugar;

  @HiveField(2)
  double carbohydrates;

  @HiveField(3)
  double insulinUnits;

  @HiveField(4)
  double? finalBloodSugar;

  @HiveField(5)
  DateTime? endTime;

  // --- CAMPOS CALCULADOS ACTUALIZADOS ---
  @HiveField(6) // Mismo índice que antes para ratioInsulinaCarbohidratosDiv10
  double? ratioInsulinaCarbohidratosDiv10;

  @HiveField(7) // Mismo índice que antes para desviacionGlucemicaCorregida, ahora 'desviacion'
  double? desviacion; // RENOMBRADO

  @HiveField(8) // Mismo índice que antes para indiceCompositoComida, ahora 'ratio_final'
  double? ratioFinal; // RENOMBRADO Y NUEVA FÓRMULA
  // --- FIN CAMPOS ACTUALIZADOS ---

  MealLog({
    required this.startTime,
    required this.initialBloodSugar,
    required this.carbohydrates,
    required this.insulinUnits,
    this.finalBloodSugar,
    this.endTime,
    this.ratioInsulinaCarbohidratosDiv10,
    this.desviacion, // ACTUALIZADO
    this.ratioFinal, // ACTUALIZADO
  });

  @override
  String toString() {
    return 'MealLog('
        'startTime: $startTime, '
        'initialBloodSugar: $initialBloodSugar, '
        'carbohydrates: $carbohydrates, '
        'insulinUnits: $insulinUnits, '
        'finalBloodSugar: $finalBloodSugar, '
        'endTime: $endTime, '
        'ratioInsCarbDiv10: $ratioInsulinaCarbohidratosDiv10, '
        'desviacion: $desviacion, ' // ACTUALIZADO
        'ratioFinal: $ratioFinal' // ACTUALIZADO
        ')';
  }
}

@HiveType(typeId: 1)
class OvernightLog extends HiveObject {
  @HiveField(0)
  DateTime bedTime;

  @HiveField(1)
  double beforeSleepBloodSugar;

  @HiveField(2)
  double slowInsulinUnits;

  @HiveField(3)
  double? afterWakeUpBloodSugar;

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
        'afterWakeUpBloodSugar: $afterWakeUpBloodSugar '
        ')';
  }
}