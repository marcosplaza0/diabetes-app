// lib/core/services/diabetes_calculator_service.dart
import 'package:collection/collection.dart';
import 'package:flutter/material.dart' hide DayPeriod;
import 'package:hive/hive.dart'; // Necesario para DailyCalculationDataBox
import 'package:intl/intl.dart';
import 'package:diabetes_2/data/models/logs/logs.dart';
import 'package:diabetes_2/data/models/calculations/daily_calculation_data.dart';
import 'package:diabetes_2/main.dart' show dailyCalculationsBoxName; // Solo para dailyCalculationsBoxName
import 'package:diabetes_2/data/repositories/log_repository.dart'; // Importar el repositorio

import 'package:diabetes_2/data/repositories/log_repository.dart';
import 'package:diabetes_2/data/repositories/calculation_data_repository.dart'; // Importar el nuevo repo


class DiabetesCalculatorService {
  final LogRepository _logRepository;
  final CalculationDataRepository _calculationDataRepository; // Añadir el nuevo repo
  // late final Box<DailyCalculationData> _dailyCalculationsBox;

  DiabetesCalculatorService({
    required LogRepository logRepository,
    required CalculationDataRepository calculationDataRepository, // Recibirlo en el constructor
  })  : _logRepository = logRepository,
        _calculationDataRepository = calculationDataRepository;


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

  Future<Map<String, double?>> _calculateDailyInsulinAndCorrectionIndex(DateTime date) async {
    double totalInsulin = 0;
    final relevantLogs = await _logRepository.getMealLogsForDate(date);

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
      // Usar el repositorio para obtener DailyCalculationData
      final DailyCalculationData? dailyData = await _calculationDataRepository.getDailyCalculation(dateKey);

      if (dailyData?.dailyCorrectionIndex != null) {
        dailyIndices.add(dailyData!.dailyCorrectionIndex!);
      } else {
        final calculatedOnFly = await _calculateDailyInsulinAndCorrectionIndex(date);
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

    // Usar el repositorio para obtener DailyCalculationData
    DailyCalculationData dailyData = await _calculationDataRepository.getDailyCalculation(dateKey) ??
        DailyCalculationData(date: normalizedDate, periodFinalIndexAverage: {});

    final dailyInsulinCalculations = await _calculateDailyInsulinAndCorrectionIndex(normalizedDate);
    dailyData.totalMealInsulin = dailyInsulinCalculations['totalMealInsulin'];
    dailyData.dailyCorrectionIndex = dailyInsulinCalculations['dailyCorrectionIndex'];

    // ... (la lógica de cálculo de campos de MealLog se mantiene igual, incluyendo saveMealLog via _logRepository) ...
    final double? correctionIndexForDeviation = dailyData.dailyCorrectionIndex;
    final List<MealLog> mealLogsForDay = await _logRepository.getMealLogsForDate(normalizedDate);
    bool mealLogUpdated = false;

    for (var mealLog in mealLogsForDay) {
      double? ratioInsCarbDiv10;
      double? currentDesviacion;
      double? currentRatioFinal;

      if (mealLog.carbohydrates > 0) {
        ratioInsCarbDiv10 = mealLog.insulinUnits / (mealLog.carbohydrates / 10.0);
      }

      if (mealLog.finalBloodSugar != null &&
          correctionIndexForDeviation != null &&
          correctionIndexForDeviation > 0) {
        currentDesviacion = (mealLog.finalBloodSugar! - mealLog.initialBloodSugar) / correctionIndexForDeviation;
      }

      if (mealLog.carbohydrates > 0 && (mealLog.carbohydrates / 10.0) != 0) {
        double? correctionComponent;
        if (mealLog.finalBloodSugar != null && correctionIndexForDeviation != null && correctionIndexForDeviation > 0) {
          correctionComponent = (mealLog.finalBloodSugar! - mealLog.initialBloodSugar) / correctionIndexForDeviation;
        }

        if (correctionComponent != null) {
          currentRatioFinal = (mealLog.insulinUnits + correctionComponent) / (mealLog.carbohydrates / 10.0);
        } else {
          currentRatioFinal = (mealLog.insulinUnits) / (mealLog.carbohydrates / 10.0);
        }
      }

      if (currentRatioFinal != null && ratioInsCarbDiv10 != null) {
        currentDesviacion = currentRatioFinal - ratioInsCarbDiv10;
      }

      if (mealLog.ratioInsulinaCarbohidratosDiv10 != ratioInsCarbDiv10 ||
          mealLog.desviacion != currentDesviacion ||
          mealLog.ratioFinal != currentRatioFinal) {

        mealLog.ratioInsulinaCarbohidratosDiv10 = ratioInsCarbDiv10;
        mealLog.desviacion = currentDesviacion;
        mealLog.ratioFinal = currentRatioFinal;

        if (mealLog.key != null) {
          await _logRepository.saveMealLog(mealLog, mealLog.key as String);
          mealLogUpdated = true;
        } else {
          debugPrint("DiabetesCalculatorService: ADVERTENCIA - MealLog no tiene clave, no se puede guardar a través del repositorio.");
        }
      }
    }
    if (mealLogUpdated) {
      debugPrint("MealLogs actualizados con nuevos campos calculados para el $dateKey via LogRepository");
    }


    final potentiallyUpdatedMealLogsForDay = await _logRepository.getMealLogsForDate(normalizedDate);
    Map<String, List<double>> periodIndicesCollector = {};
    for (var mealLog in potentiallyUpdatedMealLogsForDay) {
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

    // Usar el repositorio para guardar DailyCalculationData
    // Esto también manejará la sincronización con Supabase si está activada.
    await _calculationDataRepository.saveDailyCalculation(dateKey, dailyData);
    debugPrint("Cálculos diarios actualizados y guardados para $dateKey via CalculationDataRepository: ${dailyData.toString()}");
  }

  // ... (reprocessAllLogs se mantiene, ya usa _logRepository y updateCalculationsForDay) ...
  Future<void> reprocessAllLogs({bool forceAllDays = false}) async {
    debugPrint("Iniciando reprocesamiento de todos los logs via LogRepository...");
    Set<DateTime> uniqueDates = {};
    final allMealLogsMap = await _logRepository.getAllMealLogsMappedByKey();

    for (var logEntry in allMealLogsMap.entries) {
      var log = logEntry.value;
      if (forceAllDays ||
          log.ratioInsulinaCarbohidratosDiv10 == null ||
          log.desviacion == null ||
          log.ratioFinal == null) {
        uniqueDates.add(DateTime(log.startTime.year, log.startTime.month, log.startTime.day));
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


  // ... (getAverageRatioInsulinaCarbohidratosDiv10ForPeriod se mantiene, ya usa _logRepository) ...
  Future<double?> getAverageRatioInsulinaCarbohidratosDiv10ForPeriod(
      {required DayPeriod period, int days = 7, DateTime? endDate}) async {
    endDate ??= DateTime.now();
    List<double> ratios = [];
    final startDate = endDate.subtract(Duration(days: days -1));
    final logsInRange = await _logRepository.getMealLogsInDateRange(DateTime(startDate.year, startDate.month, startDate.day), endDate);
    for (var log in logsInRange) {
      if (getDayPeriod(log.startTime) == period && log.ratioInsulinaCarbohidratosDiv10 != null) {
        ratios.add(log.ratioInsulinaCarbohidratosDiv10!);
      }
    }
    if (ratios.isEmpty) return null;
    double average = ratios.average;
    debugPrint("Promedio RatioInsulinaCarbohidratosDiv10 para período $period ($days días): $average");
    return average;
  }


  Future<double?> getAverageOfDailyPeriodAvgRatioFinal(
      {required DayPeriod period, int days = 7, DateTime? endDate}) async {
    endDate ??= DateTime.now();
    List<double> dailyPeriodAverages = [];
    String periodKey = dayPeriodToString(period);

    for (int i = 0; i < days; i++) {
      final date = endDate.subtract(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      // Usar el repositorio para obtener DailyCalculationData
      final DailyCalculationData? dailyData = await _calculationDataRepository.getDailyCalculation(dateKey);

      if (dailyData?.periodFinalIndexAverage?[periodKey] != null) {
        dailyPeriodAverages.add(dailyData!.periodFinalIndexAverage![periodKey]!);
      }
    }
    if (dailyPeriodAverages.isEmpty) return null;
    double average = dailyPeriodAverages.average;
    debugPrint("Promedio de (Promedios Diarios de RatioFinal) para período $period ($days días): $average");
    return average;
  }

  Future<double?> getAverageDailyCorrectionIndex({int days = 7, DateTime? endDate}) async {
    endDate ??= DateTime.now();
    List<double> dailyIndices = [];
    for (int i = 0; i < days; i++) {
      final date = endDate.subtract(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      // Usar el repositorio para obtener DailyCalculationData
      final DailyCalculationData? dailyData = await _calculationDataRepository.getDailyCalculation(dateKey);

      if (dailyData?.dailyCorrectionIndex != null) {
        dailyIndices.add(dailyData!.dailyCorrectionIndex!);
      } else {
        final calculatedOnFly = await _calculateDailyInsulinAndCorrectionIndex(date);
        if (calculatedOnFly['dailyCorrectionIndex'] != null) {
          dailyIndices.add(calculatedOnFly['dailyCorrectionIndex']!);
        }
      }
    }
    if (dailyIndices.isEmpty) return null;
    double average = dailyIndices.average;
    debugPrint("Promedio DailyCorrectionIndex ($days días): $average");
    return average;
  }}