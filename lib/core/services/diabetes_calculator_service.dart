// lib/core/services/diabetes_calculator_service.dart
import 'package:collection/collection.dart';
import 'package:flutter/material.dart' hide DayPeriod;
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:diabetes_2/data/models/logs/logs.dart';
import 'package:diabetes_2/data/models/calculations/daily_calculation_data.dart';
import 'package:diabetes_2/main.dart' show mealLogBoxName, dailyCalculationsBoxName;

class DiabetesCalculatorService {
  late final Box<MealLog> _mealLogBox;
  late final Box<DailyCalculationData> _dailyCalculationsBox;

  DiabetesCalculatorService() {
    if (Hive.isBoxOpen(mealLogBoxName) && Hive.isBoxOpen(dailyCalculationsBoxName)) {
      _mealLogBox = Hive.box<MealLog>(mealLogBoxName);
      _dailyCalculationsBox = Hive.box<DailyCalculationData>(dailyCalculationsBoxName);
    } else {
      throw Exception("DiabetesCalculatorService: Hive boxes not open.");
    }
  }

  DayPeriod getDayPeriod(DateTime dateTime) {
    final time = TimeOfDay.fromDateTime(dateTime);
    double timeToDouble(TimeOfDay t) => t.hour + t.minute / 60.0;
    final currentTimeValue = timeToDouble(time);

    if ((currentTimeValue >= 23.0 && currentTimeValue < 24.0) || (currentTimeValue >= 0.0 && currentTimeValue < 1.0)) return DayPeriod.P7;
    if (currentTimeValue >= 1.0 && currentTimeValue < 4.5) return DayPeriod.P1;
    if (currentTimeValue >= 4.5 && currentTimeValue < 8.0) return DayPeriod.P2;
    if (currentTimeValue >= 8.0 && currentTimeValue < 12.0) return DayPeriod.P3;
    if (currentTimeValue >= 12.0 && currentTimeValue < 15.5) return DayPeriod.P4;
    if (currentTimeValue >= 15.5 && currentTimeValue < 19.5) return DayPeriod.P5;
    if (currentTimeValue >= 19.5 && currentTimeValue < 23.0) return DayPeriod.P6;

    return DayPeriod.Unknown;
  }

  Map<String, double?> _calculateDailyInsulinAndCorrectionIndex(DateTime date) {
    double totalInsulin = 0;
    final relevantLogs = _mealLogBox.values.where((log) =>
    log.startTime.year == date.year &&
        log.startTime.month == date.month &&
        log.startTime.day == date.day);

    for (var log in relevantLogs) {
      totalInsulin += log.insulinUnits;
    }

    double? correctionIndex;
    if (totalInsulin > 0) {
      correctionIndex = 1800 / totalInsulin;
    }
    return {
      'totalMealInsulin': totalInsulin,
      'dailyCorrectionIndex': correctionIndex,
    };
  }

  Future<double?> getAverageWeeklyCorrectionIndex(DateTime referenceDate) async {
    List<double> dailyIndices = [];
    for (int i = 0; i < 7; i++) {
      final date = referenceDate.subtract(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      final dailyData = _dailyCalculationsBox.get(dateKey);

      if (dailyData?.dailyCorrectionIndex != null) {
        dailyIndices.add(dailyData!.dailyCorrectionIndex!);
      } else {
        final calculatedOnFly = _calculateDailyInsulinAndCorrectionIndex(date);
        if (calculatedOnFly['dailyCorrectionIndex'] != null) {
          dailyIndices.add(calculatedOnFly['dailyCorrectionIndex']!);
        }
      }
    }

    if (dailyIndices.isEmpty) return null;
    return dailyIndices.average;
  }

  Future<void> updateCalculationsForDay(DateTime date) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final dateKey = DateFormat('yyyy-MM-dd').format(normalizedDate);

    DailyCalculationData dailyData = _dailyCalculationsBox.get(dateKey) ??
        DailyCalculationData(date: normalizedDate, periodFinalIndexAverage: {});

    final dailyInsulinCalculations = _calculateDailyInsulinAndCorrectionIndex(normalizedDate);
    dailyData.totalMealInsulin = dailyInsulinCalculations['totalMealInsulin'];
    dailyData.dailyCorrectionIndex = dailyInsulinCalculations['dailyCorrectionIndex'];

    // Este es el índice de corrección DEL DÍA ACTUAL, que se usará para calcular 'desviacion'.
    final double? correctionIndexForDeviation = dailyData.dailyCorrectionIndex;

    final List<MealLog> mealLogsForDay = _mealLogBox.values.where((log) {
      final logDate = log.startTime;
      return logDate.year == normalizedDate.year &&
          logDate.month == normalizedDate.month &&
          logDate.day == normalizedDate.day;
    }).toList();

    bool mealLogUpdated = false;
    for (var mealLog in mealLogsForDay) {
      double? ratioInsCarbDiv10;
      double? currentDesviacion; // Renombrado para evitar confusión con el campo del log
      double? currentRatioFinal; // Renombrado

      // Calcular ratio_insulina_carbohidratos_div10
      if (mealLog.carbohydrates > 0) {
        ratioInsCarbDiv10 = mealLog.insulinUnits / (mealLog.carbohydrates/ 10.0);
      }

      // Calcular desviacion
      // Usando la fórmula: (glucemia_inicial - glucemia_final) / indice_de_correccion_DEL_DIA
      if (mealLog.finalBloodSugar != null &&
          correctionIndexForDeviation != null &&
          correctionIndexForDeviation > 0) {
        currentDesviacion = (mealLog.finalBloodSugar! - mealLog.initialBloodSugar) / correctionIndexForDeviation;
      }

      // Calcular ratio_final (NUEVA FÓRMULA PROPORCIONADA)
      // ratio_final = (mealLog.insulinUnits + ((mealLog.initialBloodSugar - mealLog.finalBloodSugar!) / correctionIndexForDeviation)) / (mealLog.carbohydrates / 10)
      if (mealLog.carbohydrates > 0 && (mealLog.carbohydrates / 10.0) != 0) { // Evitar división por cero
        double? correctionComponent;
        if (mealLog.finalBloodSugar != null && correctionIndexForDeviation != null && correctionIndexForDeviation > 0) {
          correctionComponent = (mealLog.finalBloodSugar! - mealLog.initialBloodSugar) / correctionIndexForDeviation;
        }

        if (correctionComponent != null) {
          currentRatioFinal = (mealLog.insulinUnits + correctionComponent) / (mealLog.carbohydrates / 10.0);
        } else {
          // Si no se puede calcular el componente de corrección, ratio_final es solo basado en insulina/CH
          currentRatioFinal = (mealLog.insulinUnits) / (mealLog.carbohydrates / 10.0);
        }
      }


      // Calcular la 'desviacion' según la nueva fórmula: ratio_final - ratio_insulina_carbohidratos_div10
      // Esto sobreescribe el 'currentDesviacion' calculado antes si 'currentRatioFinal' y 'ratioInsCarbDiv10' están disponibles.
      if (currentRatioFinal != null && ratioInsCarbDiv10 != null) {
        currentDesviacion = currentRatioFinal - ratioInsCarbDiv10;
      }


      // Actualizar el MealLog en Hive si algún campo cambió
      if (mealLog.ratioInsulinaCarbohidratosDiv10 != ratioInsCarbDiv10 ||
          mealLog.desviacion != currentDesviacion || // Comparar con el nuevo 'desviacion'
          mealLog.ratioFinal != currentRatioFinal) { // Comparar con el nuevo 'ratio_final'

        mealLog.ratioInsulinaCarbohidratosDiv10 = ratioInsCarbDiv10;
        mealLog.desviacion = currentDesviacion; // Guardar el 'desviacion' recalculado
        mealLog.ratioFinal = currentRatioFinal; // Guardar el 'ratio_final'

        await _mealLogBox.put(mealLog.key, mealLog);
        mealLogUpdated = true;
      }
    }
    if (mealLogUpdated) {
      debugPrint("MealLogs actualizados con nuevos campos calculados para el $dateKey");
    }

    // Recalcular promedios de ratio_final por período
    final potentiallyUpdatedMealLogsForDay = _mealLogBox.values.where((log) {
      final logDate = log.startTime;
      return logDate.year == normalizedDate.year &&
          logDate.month == normalizedDate.month &&
          logDate.day == normalizedDate.day;
    });

    Map<String, List<double>> periodIndicesCollector = {};
    for (var mealLog in potentiallyUpdatedMealLogsForDay) {
      // Ahora promediamos el 'ratioFinal'
      if (mealLog.ratioFinal != null) {
        DayPeriod period = getDayPeriod(mealLog.startTime);
        if (period != DayPeriod.Unknown) {
          String periodKey = dayPeriodToString(period);
          periodIndicesCollector.putIfAbsent(periodKey, () => []).add(mealLog.ratioFinal!);
        }
      }
    }

    dailyData.periodFinalIndexAverage ??= {};
    dailyData.periodFinalIndexAverage!.clear();

    periodIndicesCollector.forEach((periodKey, indices) {
      if (indices.isNotEmpty) {
        dailyData.periodFinalIndexAverage![periodKey] = indices.average;
      }
    });

    await _dailyCalculationsBox.put(dateKey, dailyData);
    debugPrint("Cálculos diarios actualizados para $dateKey: ${dailyData.toString()}");
  }

  Future<void> reprocessAllLogs({bool forceAllDays = false}) async {
    debugPrint("Iniciando reprocesamiento de todos los logs...");
    Set<DateTime> uniqueDates = {};

    for (var logKey in _mealLogBox.keys) {
      var log = _mealLogBox.get(logKey);
      if (log != null) {
        if (forceAllDays ||
            log.ratioInsulinaCarbohidratosDiv10 == null ||
            log.desviacion == null || // Usar el nuevo nombre de campo
            log.ratioFinal == null) { // Usar el nuevo nombre de campo
          uniqueDates.add(DateTime(log.startTime.year, log.startTime.month, log.startTime.day));
        }
      }
    }

    List<DateTime> sortedDates = uniqueDates.toList()..sort((a,b) => a.compareTo(b));

    debugPrint("Se reprocesarán ${sortedDates.length} días.");

    for (int i = 0; i < sortedDates.length; i++) {
      DateTime date = sortedDates[i];
      debugPrint("Reprocesando día ${i+1}/${sortedDates.length}: ${DateFormat('yyyy-MM-dd').format(date)}");
      await updateCalculationsForDay(date);
      await Future.delayed(const Duration(milliseconds: 50));
    }
    debugPrint("Reprocesamiento de todos los logs completado.");
  }
  Future<double?> getAverageRatioInsulinaCarbohidratosDiv10ForPeriod(
      {required DayPeriod period, int days = 7, DateTime? endDate}) async {
    endDate ??= DateTime.now();
    List<double> ratios = [];

    for (int i = 0; i < days; i++) {
      final date = endDate.subtract(Duration(days: i));
      final mealLogsForDayAndPeriod = _mealLogBox.values.where((log) {
        final logDate = log.startTime;
        return logDate.year == date.year &&
            logDate.month == date.month &&
            logDate.day == date.day &&
            getDayPeriod(log.startTime) == period &&
            log.ratioInsulinaCarbohidratosDiv10 != null;
      });

      for (var log in mealLogsForDayAndPeriod) {
        ratios.add(log.ratioInsulinaCarbohidratosDiv10!);
      }
    }

    if (ratios.isEmpty) return null;
    double average = ratios.average;
    debugPrint("Promedio RatioInsulinaCarbohidratosDiv10 para período $period ($days días): $average");
    return average;
  }

  // NUEVO: Obtener el promedio de 'period_pX_avg_index' (que es el avg(ratio_final) de DailyCalculationData)
  // para un período específico durante los últimos 'days' días.
  Future<double?> getAverageOfDailyPeriodAvgRatioFinal(
      {required DayPeriod period, int days = 7, DateTime? endDate}) async {
    endDate ??= DateTime.now();
    List<double> dailyPeriodAverages = [];
    String periodKey = dayPeriodToString(period);

    for (int i = 0; i < days; i++) {
      final date = endDate.subtract(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      final dailyData = _dailyCalculationsBox.get(dateKey);

      if (dailyData?.periodFinalIndexAverage?[periodKey] != null) {
        dailyPeriodAverages.add(dailyData!.periodFinalIndexAverage![periodKey]!);
      }
    }

    if (dailyPeriodAverages.isEmpty) return null;
    double average = dailyPeriodAverages.average;
    debugPrint("Promedio de (Promedios Diarios de RatioFinal) para período $period ($days días): $average");
    return average;
  }

  // NUEVO: Obtener el promedio de 'dailyCorrectionIndex' de los últimos 'days' días.
  // (Este método ya existía como getAverageWeeklyCorrectionIndex, lo hacemos más genérico)
  Future<double?> getAverageDailyCorrectionIndex({int days = 7, DateTime? endDate}) async {
    endDate ??= DateTime.now();
    List<double> dailyIndices = [];
    for (int i = 0; i < days; i++) {
      final date = endDate.subtract(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      final dailyData = _dailyCalculationsBox.get(dateKey);

      if (dailyData?.dailyCorrectionIndex != null) {
        dailyIndices.add(dailyData!.dailyCorrectionIndex!);
      } else {
        // Si no está precalculado, lo calculamos al vuelo para el promedio
        final calculatedOnFly = _calculateDailyInsulinAndCorrectionIndex(date);
        if (calculatedOnFly['dailyCorrectionIndex'] != null) {
          dailyIndices.add(calculatedOnFly['dailyCorrectionIndex']!);
        }
      }
    }

    if (dailyIndices.isEmpty) return null;
    double average = dailyIndices.average;
    debugPrint("Promedio DailyCorrectionIndex ($days días): $average");
    return average;
  }
}