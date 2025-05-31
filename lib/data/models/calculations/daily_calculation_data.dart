// Archivo: lib/data/models/calculations/daily_calculation_data.dart
// Descripción: Define el modelo de datos para almacenar los cálculos diarios
// relacionados con la gestión de la diabetes. Incluye el enum DayPeriod
// para representar los diferentes períodos del día.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:hive/hive.dart'; // Necesario para las anotaciones de Hive (@HiveType, @HiveField) y HiveObject.

// Declaración de 'part' para el archivo generado por build_runner.
// Este archivo (`daily_calculation_data.g.dart`) contendrá el TypeAdapter generado por Hive.
part 'daily_calculation_data.g.dart';

// Enum DayPeriod: Representa los diferentes períodos del día utilizados en la aplicación
// para segmentar y analizar datos.
enum DayPeriod {
  P1, // Período 1 (ej. madrugada temprana)
  P2, // Período 2 (ej. madrugada tardía)
  P3, // Período 3 (ej. mañana)
  P4, // Período 4 (ej. mediodía/tarde temprana)
  P5, // Período 5 (ej. tarde)
  P6, // Período 6 (ej. noche temprana)
  P7, // Período 7 (ej. noche tardía)
  Unknown // Período desconocido o no aplicable.
}

// Funciones helper para convertir entre el enum DayPeriod y su representación como String.
// Esto es útil para almacenar las claves de los períodos en Mapas o bases de datos.

/// dayPeriodToString: Convierte un enum DayPeriod a su nombre como String.
/// Ejemplo: DayPeriod.P1 -> "P1"
String dayPeriodToString(DayPeriod period) => period.toString().split('.').last;

/// stringToDayPeriod: Convierte un String (nombre del período) de nuevo a un enum DayPeriod.
///
/// @param periodStr El String que representa el período (ej. "P1").
/// @return El enum DayPeriod correspondiente, o DayPeriod.Unknown si el String no es válido.
DayPeriod? stringToDayPeriod(String? periodStr) {
  if (periodStr == null) return null;
  try {
    // Busca en los valores de DayPeriod aquel cuyo nombre (después de "DayPeriod.") coincide con periodStr.
    return DayPeriod.values.firstWhere((e) => dayPeriodToString(e) == periodStr);
  } catch (e) {
    // Si no se encuentra una coincidencia, se devuelve Unknown o se podría manejar el error de otra forma.
    return DayPeriod.Unknown;
  }
}


/// DailyCalculationData: Clase modelo para almacenar datos calculados diariamente.
///
/// Esta clase está anotada para ser utilizada con Hive, lo que permite su persistencia
/// en el almacenamiento local del dispositivo. Extiende `HiveObject` para facilitar
/// las operaciones con la base de datos Hive.
///
/// El `typeId` debe ser único entre todos los `HiveType`s registrados en la aplicación.
@HiveType(typeId: 3) // TypeId único para este modelo en Hive. (MealLog=0, OvernightLog=1, UserProfileData=2)
class DailyCalculationData extends HiveObject {
  /// date: La fecha para la cual se aplican estos cálculos.
  /// Se almacena solo la fecha (YYYY-MM-DD), la hora es irrelevante aquí.
  @HiveField(0)
  DateTime date;

  /// totalMealInsulin: Suma total de unidades de insulina de comidas (MealLogs) para este día.
  /// Puede ser nulo si no hay registros de comida o no se ha calculado.
  @HiveField(1)
  double? totalMealInsulin;

  /// dailyCorrectionIndex: El índice de corrección diario, calculado comúnmente como 1800 / totalMealInsulin.
  /// Puede ser nulo si `totalMealInsulin` es cero o no está disponible.
  @HiveField(2)
  double? dailyCorrectionIndex;

  /// periodFinalIndexAverage: Un mapa que almacena el promedio del 'ratioFinal'
  /// (o un índice compuesto similar) de los `MealLog`s para cada `DayPeriod` del día.
  /// Las claves del mapa son Strings que representan los períodos (ej. "P1", "P2", obtenidos de `dayPeriodToString`).
  /// Los valores son los promedios de dicho índice para ese período.
  /// Puede ser nulo si no hay datos o no se han calculado promedios.
  @HiveField(3)
  Map<String, double>? periodFinalIndexAverage;

  /// Constructor de DailyCalculationData.
  DailyCalculationData({
    required this.date,
    this.totalMealInsulin,
    this.dailyCorrectionIndex,
    this.periodFinalIndexAverage,
  });

  /// toString: Devuelve una representación en String del objeto DailyCalculationData.
  /// Útil para debugging y logging. Muestra la fecha y los valores calculados.
  @override
  String toString() {
    // Formatea la fecha a YYYY-MM-DD para una lectura más clara.
    return 'DailyCalculationData(date: ${date.toIso8601String().substring(0,10)}, totalMealInsulin: $totalMealInsulin, dailyCorrectionIndex: $dailyCorrectionIndex, periodAverages: $periodFinalIndexAverage)';
  }
}