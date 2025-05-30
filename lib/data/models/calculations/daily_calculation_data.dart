// lib/data/models/calculations/daily_calculation_data.dart
import 'package:hive/hive.dart';

part 'daily_calculation_data.g.dart'; // Se generará

// Enum para los períodos del día (puedes moverlo a un archivo de utilidades si lo prefieres)
enum DayPeriod { P1, P2, P3, P4, P5, P6, P7, Unknown }

// Funciones helper para convertir entre Enum y String (para claves de Map)
String dayPeriodToString(DayPeriod period) => period.toString().split('.').last;

DayPeriod? stringToDayPeriod(String? periodStr) {
  if (periodStr == null) return null;
  try {
    return DayPeriod.values.firstWhere((e) => dayPeriodToString(e) == periodStr);
  } catch (e) {
    return DayPeriod.Unknown; // o null, o manejar el error de otra forma
  }
}


@HiveType(typeId: 3) // *** USA UN typeId ÚNICO Y NUEVO *** // (MealLog=0, OvernightLog=1, UserProfileData=2)
class DailyCalculationData extends HiveObject {
  @HiveField(0)
  DateTime date; // La fecha para la que son estos cálculos (YYYY-MM-DD)

  @HiveField(1)
  double? totalMealInsulin; // Suma de insulina de MealLogs para este día

  @HiveField(2)
  double? dailyCorrectionIndex; // 1800 / totalMealInsulin

  // Almacenará el promedio del 'indiceCompositoComida' de los MealLogs
  // para cada período del día. Clave: "P1", "P2", etc.
  @HiveField(3)
  Map<String, double>? periodFinalIndexAverage;

  DailyCalculationData({
    required this.date,
    this.totalMealInsulin,
    this.dailyCorrectionIndex,
    this.periodFinalIndexAverage,
  });

  @override
  String toString() {
    return 'DailyCalculationData(date: ${date.toIso8601String().substring(0,10)}, totalMealInsulin: $totalMealInsulin, dailyCorrectionIndex: $dailyCorrectionIndex, periodAverages: $periodFinalIndexAverage)';
  }
}