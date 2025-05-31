// Archivo: lib/core/services/diabetes_calculator_service.dart
// Descripción: Servicio que centraliza todos los cálculos relacionados con la gestión de la diabetes.
// Esto incluye determinar períodos del día, calcular índices de corrección, promedios de ratios,
// actualizar los campos calculados en los MealLogs y los resúmenes diarios en DailyCalculationData.
// Interactúa con LogRepository y CalculationDataRepository para obtener y guardar datos.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:collection/collection.dart'; // Para extensiones de colecciones, como '.average'.
import 'package:flutter/material.dart' hide DayPeriod; // Framework de UI de Flutter. Se oculta DayPeriod de Material si existiera.
import 'package:intl/intl.dart'; // Para formateo de fechas (ej. 'yyyy-MM-dd' para claves de DailyCalculationData).

// Importaciones de archivos del proyecto
import 'package:DiabetiApp/data/models/logs/logs.dart'; // Modelos MealLog y OvernightLog.
import 'package:DiabetiApp/data/models/calculations/daily_calculation_data.dart'; // Modelo DailyCalculationData y enum DayPeriod.
import 'package:DiabetiApp/data/repositories/log_repository.dart'; // Repositorio para acceder a los logs.
import 'package:DiabetiApp/data/repositories/calculation_data_repository.dart'; // Repositorio para acceder a los datos de cálculo.

/// DiabetesCalculatorService: Clase de servicio para realizar diversos cálculos
/// relacionados con el manejo de la diabetes.
///
/// Este servicio encapsula la lógica para:
/// - Determinar el período del día.
/// - Calcular el total de insulina de comidas y el índice de corrección diario.
/// - Calcular y actualizar campos derivados en los `MealLog` (como ratios y desviaciones).
/// - Calcular y actualizar `DailyCalculationData` con resúmenes diarios y promedios por período.
/// - Obtener promedios de diferentes métricas a lo largo del tiempo (ej. ratio Insulina/CH, índice de corrección).
/// - Reprocesar todos los logs para actualizar cálculos históricos si la lógica cambia.
class DiabetesCalculatorService {
  // Repositorios para acceder a los datos necesarios para los cálculos.
  final LogRepository _logRepository;
  final CalculationDataRepository _calculationDataRepository;

  /// Constructor: Inyecta las dependencias de los repositorios.
  DiabetesCalculatorService({
    required LogRepository logRepository,
    required CalculationDataRepository calculationDataRepository,
  })  : _logRepository = logRepository,
        _calculationDataRepository = calculationDataRepository;


  /// getDayPeriod: Determina el `DayPeriod` (P1-P7, Unknown) para un `DateTime` dado.
  /// Los períodos están definidos por rangos horarios específicos.
  ///
  /// @param dateTime La fecha y hora para la cual se determinará el período.
  /// @return El `DayPeriod` correspondiente.
  DayPeriod getDayPeriod(DateTime dateTime) {
    final time = TimeOfDay.fromDateTime(dateTime); // Convierte DateTime a TimeOfDay.
    // Función helper para convertir TimeOfDay a un valor numérico (ej. 10:30 -> 10.5).
    double timeToDouble(TimeOfDay t) => t.hour + t.minute / 60.0;
    final currentTimeValue = timeToDouble(time);

    // Define los rangos horarios para cada período.
    // P7 (Noche tardía): 23:00 - 00:59
    if ((currentTimeValue >= 23.0 && currentTimeValue < 24.0) || (currentTimeValue >= 0.0 && currentTimeValue < 1.0)) return DayPeriod.P7;
    // P1 (Madrugada temprana): 01:00 - 04:29
    if (currentTimeValue >= 1.0 && currentTimeValue < 4.5) return DayPeriod.P1;
    // P2 (Madrugada tardía): 04:30 - 07:59
    if (currentTimeValue >= 4.5 && currentTimeValue < 8.0) return DayPeriod.P2;
    // P3 (Mañana): 08:00 - 11:59
    if (currentTimeValue >= 8.0 && currentTimeValue < 12.0) return DayPeriod.P3;
    // P4 (Mediodía/Tarde temprana): 12:00 - 15:29
    if (currentTimeValue >= 12.0 && currentTimeValue < 15.5) return DayPeriod.P4;
    // P5 (Tarde): 15:30 - 19:29
    if (currentTimeValue >= 15.5 && currentTimeValue < 19.5) return DayPeriod.P5;
    // P6 (Noche temprana): 19:30 - 22:59
    if (currentTimeValue >= 19.5 && currentTimeValue < 23.0) return DayPeriod.P6;

    return DayPeriod.Unknown; // Si no coincide con ningún período.
  }

  /// _calculateDailyInsulinAndCorrectionIndex: Calcula el total de insulina de comidas
  /// y el índice de corrección diario para una fecha dada.
  ///
  /// Privado, ya que es un helper para `updateCalculationsForDay`.
  ///
  /// @param date La fecha para la cual se realizarán los cálculos.
  /// @return Un `Future<Map<String, double?>>` con 'totalMealInsulin' y 'dailyCorrectionIndex'.
  Future<Map<String, double?>> _calculateDailyInsulinAndCorrectionIndex(DateTime date) async {
    double totalInsulin = 0;
    // Obtiene los MealLogs para la fecha dada desde el repositorio.
    final relevantLogs = await _logRepository.getMealLogsForDate(date); //

    // Suma las unidades de insulina de todos los MealLogs del día.
    for (var log in relevantLogs) {
      totalInsulin += log.insulinUnits; //
    }

    double? correctionIndex;
    // Calcula el índice de corrección diario (ej. regla de 1800) si hay insulina total.
    if (totalInsulin > 0) {
      correctionIndex = 1800 / totalInsulin;
    }
    return {
      'totalMealInsulin': totalInsulin,
      'dailyCorrectionIndex': correctionIndex,
    };
  }

  /// getAverageWeeklyCorrectionIndex: Calcula el promedio del índice de corrección diario
  /// durante la última semana (7 días) hasta una fecha de referencia.
  ///
  /// Intenta obtener los índices diarios de `DailyCalculationData`. Si no están disponibles,
  /// los calcula sobre la marcha usando `_calculateDailyInsulinAndCorrectionIndex`.
  ///
  /// @param referenceDate La fecha final de la semana para el cálculo.
  /// @return Un `Future<double?>` con el índice de corrección promedio, o nulo si no hay datos.
  Future<double?> getAverageWeeklyCorrectionIndex(DateTime referenceDate) async {
    List<double> dailyIndices = [];
    // Itera sobre los últimos 7 días.
    for (int i = 0; i < 7; i++) {
      final date = referenceDate.subtract(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(date); // Clave para DailyCalculationData.
      // Intenta obtener los datos de cálculo diarios del repositorio.
      final DailyCalculationData? dailyData = await _calculationDataRepository.getDailyCalculation(dateKey); //

      if (dailyData?.dailyCorrectionIndex != null) { //
        dailyIndices.add(dailyData!.dailyCorrectionIndex!); //
      } else {
        // Si no está en DailyCalculationData, calcula el índice sobre la marcha.
        final calculatedOnFly = await _calculateDailyInsulinAndCorrectionIndex(date);
        if (calculatedOnFly['dailyCorrectionIndex'] != null) {
          dailyIndices.add(calculatedOnFly['dailyCorrectionIndex']!);
        }
      }
    }
    if (dailyIndices.isEmpty) return null;
    return dailyIndices.average; // Devuelve el promedio usando la extensión de `collection`.
  }


  /// updateCalculationsForDay: Actualiza todos los cálculos relevantes para un día específico.
  ///
  /// Esto incluye:
  /// 1. Calcular `totalMealInsulin` y `dailyCorrectionIndex` para el `DailyCalculationData` del día.
  /// 2. Recalcular y actualizar los campos `ratioInsulinaCarbohidratosDiv10`, `desviacion`, y `ratioFinal`
  ///    para cada `MealLog` de ese día.
  /// 3. Guardar los `MealLog`s actualizados a través de `_logRepository`.
  /// 4. Calcular los promedios del `ratioFinal` por `DayPeriod` y guardarlos en `DailyCalculationData`.
  /// 5. Guardar el `DailyCalculationData` actualizado a través de `_calculationDataRepository`.
  ///
  /// @param date La fecha para la cual se actualizarán los cálculos.
  Future<void> updateCalculationsForDay(DateTime date) async {
    // Normaliza la fecha a medianoche para consistencia.
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final dateKey = DateFormat('yyyy-MM-dd').format(normalizedDate); // Clave para DailyCalculationData.

    // Obtiene el DailyCalculationData existente o crea uno nuevo si no existe.
    DailyCalculationData dailyData = await _calculationDataRepository.getDailyCalculation(dateKey) ?? //
        DailyCalculationData(date: normalizedDate, periodFinalIndexAverage: {}); //

    // Calcula el total de insulina y el índice de corrección diario.
    final dailyInsulinCalculations = await _calculateDailyInsulinAndCorrectionIndex(normalizedDate);
    dailyData.totalMealInsulin = dailyInsulinCalculations['totalMealInsulin']; //
    dailyData.dailyCorrectionIndex = dailyInsulinCalculations['dailyCorrectionIndex']; //

    // Obtiene el índice de corrección del día para usarlo en los cálculos de los MealLogs.
    final double? correctionIndexForDeviation = dailyData.dailyCorrectionIndex; //
    // Obtiene todos los MealLogs del día.
    final List<MealLog> mealLogsForDay = await _logRepository.getMealLogsForDate(normalizedDate); //
    bool mealLogUpdated = false; // Flag para saber si algún MealLog fue modificado.

    // Itera sobre cada MealLog del día para actualizar sus campos calculados.
    for (var mealLog in mealLogsForDay) {
      double? ratioInsCarbDiv10; // Ratio Insulina / (CH/10).
      double? currentDesviacion; // Desviación calculada.
      double? currentRatioFinal; // Ratio final ajustado.

      // Calcula ratioInsulinaCarbohidratosDiv10.
      if (mealLog.carbohydrates > 0) { //
        ratioInsCarbDiv10 = mealLog.insulinUnits / (mealLog.carbohydrates / 10.0); //
      }

      // Calcula el componente de corrección si hay glucosa final y índice de corrección.
      double? correctionComponent;
      if (mealLog.finalBloodSugar != null && //
          correctionIndexForDeviation != null &&
          correctionIndexForDeviation > 0) {
        correctionComponent = (mealLog.finalBloodSugar! - mealLog.initialBloodSugar) / correctionIndexForDeviation; //
      }

      // Calcula currentRatioFinal.
      // Si hay CH, se calcula; si no, podría ser nulo o no calcularse.
      if (mealLog.carbohydrates > 0 && (mealLog.carbohydrates / 10.0) != 0) { //
        if (correctionComponent != null) {
          // Ratio final = (Insulina Real + Componente de Corrección) / (CH/10)
          currentRatioFinal = (mealLog.insulinUnits + correctionComponent) / (mealLog.carbohydrates / 10.0); //
        } else {
          // Si no hay componente de corrección (ej. sin glucosa final), el ratio final es igual al ratioInsCarbDiv10.
          currentRatioFinal = (mealLog.insulinUnits) / (mealLog.carbohydrates / 10.0); //
        }
      }

      // Calcula currentDesviacion como la diferencia entre el ratio final y el ratio inicial.
      // Esto representa cuánto se desvió el ratio real del ratio esperado sin corrección de glucosa.
      if (currentRatioFinal != null && ratioInsCarbDiv10 != null) {
        currentDesviacion = currentRatioFinal - ratioInsCarbDiv10;
      }


      // Compara los valores calculados con los existentes en el MealLog.
      // Si hay diferencias, actualiza el MealLog y lo guarda.
      if (mealLog.ratioInsulinaCarbohidratosDiv10 != ratioInsCarbDiv10 || //
          mealLog.desviacion != currentDesviacion || //
          mealLog.ratioFinal != currentRatioFinal) { //

        mealLog.ratioInsulinaCarbohidratosDiv10 = ratioInsCarbDiv10; //
        mealLog.desviacion = currentDesviacion; //
        mealLog.ratioFinal = currentRatioFinal; //

        if (mealLog.key != null) { // Asegura que el MealLog tenga una clave de Hive.
          await _logRepository.saveMealLog(mealLog, mealLog.key as String); // Guarda el MealLog actualizado. //
          mealLogUpdated = true;
        } else {
          // Advertencia si un MealLog no tiene clave (no debería ocurrir si se obtiene del repositorio).
          debugPrint("DiabetesCalculatorService: ADVERTENCIA - MealLog no tiene clave, no se puede guardar a través del repositorio.");
        }
      }
    }
    if (mealLogUpdated) {
      debugPrint("DiabetesCalculatorService: MealLogs actualizados con nuevos campos calculados para el $dateKey via LogRepository");
    }

    // Después de actualizar todos los MealLogs del día, se recalculan los promedios por período para DailyCalculationData.
    // Se vuelven a obtener los MealLogs por si sus campos calculados (especialmente ratioFinal) han cambiado.
    final potentiallyUpdatedMealLogsForDay = await _logRepository.getMealLogsForDate(normalizedDate); //
    Map<String, List<double>> periodIndicesCollector = {}; // Colector para los ratioFinal por período.
    // Agrupa los ratioFinal de los MealLogs por su DayPeriod.
    for (var mealLog in potentiallyUpdatedMealLogsForDay) {
      if (mealLog.ratioFinal != null) { //
        DayPeriod period = getDayPeriod(mealLog.startTime); //
        if (period != DayPeriod.Unknown) {
          String periodKey = dayPeriodToString(period); // Convierte enum a String para la clave del mapa.
          periodIndicesCollector.putIfAbsent(periodKey, () => []).add(mealLog.ratioFinal!); //
        }
      }
    }
    dailyData.periodFinalIndexAverage ??= {}; // Asegura que el mapa exista. //
    dailyData.periodFinalIndexAverage!.clear(); // Limpia promedios anteriores. //
    // Calcula el promedio para cada período y lo guarda en dailyData.
    periodIndicesCollector.forEach((periodKey, indices) {
      if (indices.isNotEmpty) {
        dailyData.periodFinalIndexAverage![periodKey] = indices.average; //
      }
    });

    // Guarda el DailyCalculationData actualizado a través del repositorio.
    // Esto también maneja la sincronización con Supabase si está activada dentro del repositorio.
    await _calculationDataRepository.saveDailyCalculation(dateKey, dailyData); //
    debugPrint("DiabetesCalculatorService: Cálculos diarios actualizados y guardados para $dateKey via CalculationDataRepository: ${dailyData.toString()}");
  }

  /// reprocessAllLogs: Reprocesa todos los MealLogs existentes para actualizar sus campos calculados
  /// y los DailyCalculationData correspondientes.
  ///
  /// Útil si la lógica de cálculo cambia y se necesita aplicar retroactivamente.
  ///
  /// @param forceAllDays Si es `true`, reprocesa todos los días con MealLogs.
  ///                    Si es `false` (defecto), solo reprocesa días donde los MealLogs
  ///                    no tienen los campos calculados (`ratioInsulinaCarbohidratosDiv10`, `desviacion`, `ratioFinal`).
  Future<void> reprocessAllLogs({bool forceAllDays = false}) async {
    debugPrint("DiabetesCalculatorService: Iniciando reprocesamiento de todos los logs via LogRepository...");
    Set<DateTime> uniqueDates = {}; // Para almacenar las fechas únicas que necesitan reprocesamiento.
    // Obtiene todos los MealLogs mapeados por su clave.
    final allMealLogsMap = await _logRepository.getAllMealLogsMappedByKey(); //

    // Determina qué días necesitan ser reprocesados.
    for (var logEntry in allMealLogsMap.entries) {
      var log = logEntry.value;
      // Si se fuerza el reprocesamiento para todos los días, O si alguno de los campos calculados es nulo.
      if (forceAllDays ||
          log.ratioInsulinaCarbohidratosDiv10 == null || //
          log.desviacion == null || //
          log.ratioFinal == null) { //
        // Añade la fecha (normalizada a medianoche) del log al conjunto de fechas únicas.
        uniqueDates.add(DateTime(log.startTime.year, log.startTime.month, log.startTime.day)); //
      }
    }
    // Ordena las fechas para procesarlas cronológicamente.
    List<DateTime> sortedDates = uniqueDates.toList()..sort((a,b) => a.compareTo(b));
    debugPrint("DiabetesCalculatorService: Se reprocesarán ${sortedDates.length} días.");
    // Itera sobre cada fecha y llama a updateCalculationsForDay.
    for (int i = 0; i < sortedDates.length; i++) {
      DateTime date = sortedDates[i];
      debugPrint("DiabetesCalculatorService: Reprocesando día ${i+1}/${sortedDates.length}: ${DateFormat('yyyy-MM-dd').format(date)}");
      await updateCalculationsForDay(date);
      // Pequeña pausa para evitar sobrecargar el sistema, especialmente si hay muchas operaciones de base de datos.
      await Future.delayed(const Duration(milliseconds: 50));
    }
    debugPrint("DiabetesCalculatorService: Reprocesamiento de todos los logs completado.");
  }


  /// getAverageRatioInsulinaCarbohidratosDiv10ForPeriod: Calcula el promedio del campo
  /// `ratioInsulinaCarbohidratosDiv10` de los `MealLog`s para un `DayPeriod` específico
  /// durante un número determinado de días hasta una fecha de finalización.
  ///
  /// @param period El `DayPeriod` para el cual se calcula el promedio.
  /// @param days El número de días hacia atrás a considerar (defecto 7).
  /// @param endDate La fecha final del rango (defecto `DateTime.now()`).
  /// @return Un `Future<double?>` con el promedio, o nulo si no hay datos.
  Future<double?> getAverageRatioInsulinaCarbohidratosDiv10ForPeriod(
      {required DayPeriod period, int days = 7, DateTime? endDate}) async {
    endDate ??= DateTime.now(); // Si no se provee endDate, usa la fecha actual.
    List<double> ratios = [];
    // Calcula la fecha de inicio del rango.
    final startDate = endDate.subtract(Duration(days: days -1));
    // Obtiene los MealLogs dentro del rango de fechas.
    final logsInRange = await _logRepository.getMealLogsInDateRange(DateTime(startDate.year, startDate.month, startDate.day), endDate); //
    // Filtra los logs por el período especificado y que tengan el ratio calculado.
    for (var log in logsInRange) {
      if (getDayPeriod(log.startTime) == period && log.ratioInsulinaCarbohidratosDiv10 != null) { //
        ratios.add(log.ratioInsulinaCarbohidratosDiv10!); //
      }
    }
    if (ratios.isEmpty) return null;
    double average = ratios.average; // Calcula el promedio.
    debugPrint("DiabetesCalculatorService: Promedio RatioInsulinaCarbohidratosDiv10 para período $period ($days días): $average");
    return average;
  }


  /// getAverageOfDailyPeriodAvgRatioFinal: Calcula el promedio de los promedios diarios del `ratioFinal`
  /// para un `DayPeriod` específico. Es decir, toma el valor de `periodFinalIndexAverage[periodKey]`
  /// de cada `DailyCalculationData` en el rango y promedia estos valores.
  ///
  /// @param period El `DayPeriod` para el cual se calcula el promedio.
  /// @param days El número de días hacia atrás a considerar (defecto 7).
  /// @param endDate La fecha final del rango (defecto `DateTime.now()`).
  /// @return Un `Future<double?>` con el promedio, o nulo si no hay datos.
  Future<double?> getAverageOfDailyPeriodAvgRatioFinal(
      {required DayPeriod period, int days = 7, DateTime? endDate}) async {
    endDate ??= DateTime.now();
    List<double> dailyPeriodAverages = [];
    String periodKey = dayPeriodToString(period); // Clave String para el mapa.

    // Itera sobre los días en el rango.
    for (int i = 0; i < days; i++) {
      final date = endDate.subtract(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      // Obtiene el DailyCalculationData para la fecha.
      final DailyCalculationData? dailyData = await _calculationDataRepository.getDailyCalculation(dateKey); //

      // Si existe y tiene un promedio para el período especificado, lo añade a la lista.
      if (dailyData?.periodFinalIndexAverage?[periodKey] != null) { //
        dailyPeriodAverages.add(dailyData!.periodFinalIndexAverage![periodKey]!); //
      }
    }
    if (dailyPeriodAverages.isEmpty) return null;
    double average = dailyPeriodAverages.average; // Calcula el promedio de los promedios diarios.
    debugPrint("DiabetesCalculatorService: Promedio de (Promedios Diarios de RatioFinal) para período $period ($days días): $average");
    return average;
  }

  /// getAverageDailyCorrectionIndex: Calcula el promedio del `dailyCorrectionIndex`
  /// a lo largo de un número determinado de días.
  ///
  /// Similar a `getAverageWeeklyCorrectionIndex` pero más genérico en cuanto al número de días.
  ///
  /// @param days El número de días hacia atrás a considerar (defecto 7).
  /// @param endDate La fecha final del rango (defecto `DateTime.now()`).
  /// @return Un `Future<double?>` con el promedio, o nulo si no hay datos.
  Future<double?> getAverageDailyCorrectionIndex({int days = 7, DateTime? endDate}) async {
    endDate ??= DateTime.now();
    List<double> dailyIndices = [];
    for (int i = 0; i < days; i++) {
      final date = endDate.subtract(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      // Obtiene el DailyCalculationData.
      final DailyCalculationData? dailyData = await _calculationDataRepository.getDailyCalculation(dateKey); //

      if (dailyData?.dailyCorrectionIndex != null) { //
        dailyIndices.add(dailyData!.dailyCorrectionIndex!); //
      } else {
        // Si no está, lo calcula sobre la marcha.
        final calculatedOnFly = await _calculateDailyInsulinAndCorrectionIndex(date);
        if (calculatedOnFly['dailyCorrectionIndex'] != null) {
          dailyIndices.add(calculatedOnFly['dailyCorrectionIndex']!);
        }
      }
    }
    if (dailyIndices.isEmpty) return null;
    double average = dailyIndices.average;
    debugPrint("DiabetesCalculatorService: Promedio DailyCorrectionIndex ($days días): $average");
    return average;
  }
}