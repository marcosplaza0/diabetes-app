// Archivo: lib/data/models/logs/logs.dart
// Descripción: Define los modelos de datos para los registros de diabetes,
// específicamente MealLog (registro de comida) y OvernightLog (registro nocturno).
// Estas clases están preparadas para ser almacenadas localmente usando Hive.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:hive/hive.dart'; // Necesario para las anotaciones de Hive (@HiveType, @HiveField) y HiveObject.

// Declaración de 'part' para el archivo generado por build_runner.
// Este archivo (`logs.g.dart`) contendrá los TypeAdapters generados por Hive para MealLog y OvernightLog.
part 'logs.g.dart';

/// MealLog: Clase modelo para los registros de comidas.
///
/// Almacena información detallada sobre una comida, incluyendo glucemias,
/// carbohidratos, insulina administrada y campos calculados relacionados.
/// Extiende `HiveObject` para facilitar su uso con la base de datos Hive.
/// El `typeId` debe ser único entre todos los `HiveType`s registrados.
@HiveType(typeId: 0)
class MealLog extends HiveObject {
  /// startTime: Fecha y hora de inicio de la comida o del registro.
  @HiveField(0)
  DateTime startTime;

  /// initialBloodSugar: Nivel de glucosa en sangre inicial (antes de la comida/insulina).
  @HiveField(1)
  double initialBloodSugar;

  /// carbohydrates: Cantidad de carbohidratos consumidos (en gramos).
  @HiveField(2)
  double carbohydrates;

  /// insulinUnits: Unidades de insulina rápida administradas.
  @HiveField(3)
  double insulinUnits;

  /// finalBloodSugar: Nivel de glucosa en sangre final (ej. 2-3 horas después), opcional.
  @HiveField(4)
  double? finalBloodSugar;

  /// endTime: Fecha y hora de la medición de la glucosa final, opcional.
  @HiveField(5)
  DateTime? endTime;

  // --- CAMPOS CALCULADOS ACTUALIZADOS ---
  // Estos campos se calculan a partir de los datos primarios del log,
  // usualmente mediante DiabetesCalculatorService.

  /// ratioInsulinaCarbohidratosDiv10: Ratio de insulina por cada 10 gramos de carbohidratos.
  /// Fórmula base: `insulinUnits / (carbohydrates / 10.0)`.
  /// Puede ser nulo si los carbohidratos son cero.
  @HiveField(6) // Mismo índice que en versiones anteriores para compatibilidad.
  double? ratioInsulinaCarbohidratosDiv10;

  /// desviacion: Representa la desviación o corrección necesaria basada en el cambio de glucosa
  /// y el índice de corrección. Anteriormente podría haber sido 'desviacionGlucemicaCorregida'.
  /// La fórmula exacta puede variar, pero se relaciona con `ratioFinal - ratioInsulinaCarbohidratosDiv10`.
  @HiveField(7) // Mismo índice que en versiones anteriores.
  double? desviacion; // RENOMBRADO (si aplica, mantener consistencia con usos previos)

  /// ratioFinal: Un índice compuesto que ajusta el ratio insulina/carbohidratos
  /// teniendo en cuenta el efecto de la corrección de glucosa.
  /// Fórmula base: `(insulinUnits + correccionComponent) / (carbohydrates / 10.0)`.
  /// `correccionComponent` se deriva de `(finalBloodSugar - initialBloodSugar) / dailyCorrectionIndex`.
  /// Anteriormente podría haber sido 'indiceCompositoComida'.
  @HiveField(8) // Mismo índice que en versiones anteriores.
  double? ratioFinal; // RENOMBRADO y/o NUEVA FÓRMULA (si aplica)
  // --- FIN CAMPOS ACTUALIZADOS ---

  /// Constructor de MealLog.
  MealLog({
    required this.startTime,
    required this.initialBloodSugar,
    required this.carbohydrates,
    required this.insulinUnits,
    this.finalBloodSugar,
    this.endTime,
    this.ratioInsulinaCarbohidratosDiv10,
    this.desviacion, // Campo actualizado en constructor.
    this.ratioFinal, // Campo actualizado en constructor.
  });

  /// toString: Devuelve una representación en String del objeto MealLog.
  /// Útil para debugging y logging.
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
        'desviacion: $desviacion, ' // Nombre actualizado en el string.
        'ratioFinal: $ratioFinal' // Nombre actualizado en el string.
        ')';
  }
}

/// OvernightLog: Clase modelo para los registros nocturnos.
///
/// Almacena información sobre la glucemia antes de dormir, la insulina lenta
/// administrada y, opcionalmente, la glucemia al despertar.
/// Extiende `HiveObject` para su uso con Hive.
/// El `typeId` debe ser único.
@HiveType(typeId: 1)
class OvernightLog extends HiveObject {
  /// bedTime: Fecha y hora en que el usuario se fue a dormir o realizó el registro.
  @HiveField(0)
  DateTime bedTime;

  /// beforeSleepBloodSugar: Nivel de glucosa en sangre antes de dormir.
  @HiveField(1)
  double beforeSleepBloodSugar;

  /// slowInsulinUnits: Unidades de insulina lenta (basal) administradas.
  @HiveField(2)
  double slowInsulinUnits;

  /// afterWakeUpBloodSugar: Nivel de glucosa en sangre al despertar, opcional.
  @HiveField(3)
  double? afterWakeUpBloodSugar;

  /// Constructor de OvernightLog.
  OvernightLog({
    required this.bedTime,
    required this.beforeSleepBloodSugar,
    required this.slowInsulinUnits,
    this.afterWakeUpBloodSugar,
  });

  /// toString: Devuelve una representación en String del objeto OvernightLog.
  /// Útil para debugging y logging.
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