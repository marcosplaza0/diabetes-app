// lib/data/repositories/log_repository.dart
import 'package:diabetes_2/data/models/logs/logs.dart';

abstract class LogRepository {
  // MealLog Operations
  Future<void> saveMealLog(MealLog log, String hiveKey);
  Future<MealLog?> getMealLog(String hiveKey);
  Future<List<MealLog>> getMealLogsForDate(DateTime date);
  Future<List<MealLog>> getMealLogsInDateRange(DateTime startDate, DateTime endDate);
  Future<Map<String, MealLog>> getAllMealLogsMappedByKey(); // Útil para sincronización o migraciones
  Future<void> deleteMealLog(String hiveKey); // Para borrado individual si es necesario
  Future<void> clearAllLocalMealLogs();

  // OvernightLog Operations
  Future<void> saveOvernightLog(OvernightLog log, String hiveKey);
  Future<OvernightLog?> getOvernightLog(String hiveKey);
  Future<List<OvernightLog>> getOvernightLogsForDate(DateTime date);
  Future<List<OvernightLog>> getOvernightLogsInDateRange(DateTime startDate, DateTime endDate);
  Future<Map<String, OvernightLog>> getAllOvernightLogsMappedByKey();
  Future<void> deleteOvernightLog(String hiveKey);
  Future<void> clearAllLocalOvernightLogs();

  // Combined Operations
  Future<List<Map<String, dynamic>>> getRecentLogs(Duration duration);
  Future<List<dynamic>> getFilteredAndSortedLogsForDate(DateTime date);
}