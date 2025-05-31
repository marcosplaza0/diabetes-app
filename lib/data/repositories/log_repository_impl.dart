// lib/data/repositories/log_repository_impl.dart
import 'package:diabetes_2/main.dart'; // Para supabase y nombres de cajas
import 'package:diabetes_2/data/models/logs/logs.dart';
import 'package:diabetes_2/data/repositories/log_repository.dart';
import 'package:diabetes_2/core/services/supabase_log_sync_service.dart';
import 'package:flutter/material.dart'; // Para DateUtils
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Clave de SharedPreferences (idealmente definida en un lugar central)
const String cloudSavePreferenceKeyFromRepo = 'saveToCloudEnabled';

class LogRepositoryImpl implements LogRepository {
  final Box<MealLog> _mealLogBox;
  final Box<OvernightLog> _overnightLogBox;
  final SupabaseLogSyncService _supabaseLogSyncService;
  final SharedPreferences _sharedPreferences;

  LogRepositoryImpl({
    required Box<MealLog> mealLogBox,
    required Box<OvernightLog> overnightLogBox,
    required SupabaseLogSyncService supabaseLogSyncService,
    required SharedPreferences sharedPreferences,
  })  : _mealLogBox = mealLogBox,
        _overnightLogBox = overnightLogBox,
        _supabaseLogSyncService = supabaseLogSyncService,
        _sharedPreferences = sharedPreferences;

  // --- MealLog Implementations ---
  @override
  Future<void> saveMealLog(MealLog log, String hiveKey) async {
    await _mealLogBox.put(hiveKey, log);
    final bool cloudSaveEnabled = _sharedPreferences.getBool(cloudSavePreferenceKeyFromRepo) ?? false;
    final bool isLoggedIn = supabase.auth.currentUser != null;

    if (cloudSaveEnabled && isLoggedIn) {
      try {
        await _supabaseLogSyncService.syncMealLog(log, hiveKey);
      } catch (e) {
        // Considera un logging más robusto o una estrategia de reintento
        debugPrint("LogRepositoryImpl: Error syncing MealLog $hiveKey during save: $e");
        // No relanzar necesariamente para no interrumpir el guardado local.
      }
    }
  }

  @override
  Future<MealLog?> getMealLog(String hiveKey) async {
    return _mealLogBox.get(hiveKey);
  }

  @override
  Future<List<MealLog>> getMealLogsForDate(DateTime date) async {
    return _mealLogBox.values
        .where((log) => DateUtils.isSameDay(log.startTime, date))
        .toList();
  }

  @override
  Future<List<MealLog>> getMealLogsInDateRange(DateTime startDate, DateTime endDate) async {
    return _mealLogBox.values.where((log) {
      final logDate = log.startTime;
      return !logDate.isBefore(startDate) && logDate.isBefore(endDate.add(const Duration(days: 1))); // endDate es inclusivo
    }).toList();
  }

  @override
  Future<Map<String, MealLog>> getAllMealLogsMappedByKey() async {
    return _mealLogBox.toMap().cast<String, MealLog>();
  }

  @override
  Future<void> deleteMealLog(String hiveKey) async {
    await _mealLogBox.delete(hiveKey);
    // Aquí también podrías añadir la lógica para eliminar de Supabase si es necesario
    // o dejar que la sincronización maneje los borrados (más complejo).
    // Por ahora, borra solo localmente desde el repo. El borrado de Supabase
    // está más centralizado en SupabaseLogSyncService y usado por SettingsScreen.
  }

  @override
  Future<void> clearAllLocalMealLogs() async {
    await _mealLogBox.clear();
  }

  // --- OvernightLog Implementations ---
  @override
  Future<void> saveOvernightLog(OvernightLog log, String hiveKey) async {
    await _overnightLogBox.put(hiveKey, log);
    final bool cloudSaveEnabled = _sharedPreferences.getBool(cloudSavePreferenceKeyFromRepo) ?? false;
    final bool isLoggedIn = supabase.auth.currentUser != null;
    if (cloudSaveEnabled && isLoggedIn) {
      try {
        await _supabaseLogSyncService.syncOvernightLog(log, hiveKey);
      } catch (e) {
        debugPrint("LogRepositoryImpl: Error syncing OvernightLog $hiveKey during save: $e");
      }
    }
  }

  @override
  Future<OvernightLog?> getOvernightLog(String hiveKey) async {
    return _overnightLogBox.get(hiveKey);
  }

  @override
  Future<List<OvernightLog>> getOvernightLogsForDate(DateTime date) async {
    return _overnightLogBox.values
        .where((log) => DateUtils.isSameDay(log.bedTime, date))
        .toList();
  }

  @override
  Future<List<OvernightLog>> getOvernightLogsInDateRange(DateTime startDate, DateTime endDate) async {
    return _overnightLogBox.values.where((log) {
      final logDate = log.bedTime;
      return !logDate.isBefore(startDate) && logDate.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
  }

  @override
  Future<Map<String, OvernightLog>> getAllOvernightLogsMappedByKey() async {
    return _overnightLogBox.toMap().cast<String, OvernightLog>();
  }

  @override
  Future<void> deleteOvernightLog(String hiveKey) async {
    await _overnightLogBox.delete(hiveKey);
    // Similar a deleteMealLog, manejo de borrado en Supabase es externo.
  }

  @override
  Future<void> clearAllLocalOvernightLogs() async {
    await _overnightLogBox.clear();
  }

  // --- Combined Log Implementations ---
  @override
  Future<List<Map<String, dynamic>>> getRecentLogs(Duration duration) async {
    final now = DateTime.now();
    final cutOffTime = now.subtract(duration);
    List<Map<String, dynamic>> combinedLogs = [];

    for (var entry in _mealLogBox.toMap().entries) {
      if (entry.value.startTime.isAfter(cutOffTime)) {
        combinedLogs.add({'time': entry.value.startTime, 'log': entry.value, 'type': 'meal', 'key': entry.key});
      }
    }
    for (var entry in _overnightLogBox.toMap().entries) {
      if (entry.value.bedTime.isAfter(cutOffTime)) {
        combinedLogs.add({'time': entry.value.bedTime, 'log': entry.value, 'type': 'overnight', 'key': entry.key});
      }
    }
    combinedLogs.sort((a, b) => (b['time'] as DateTime).compareTo(a['time'] as DateTime)); // Más recientes primero
    return combinedLogs;
  }

  @override
  Future<List<dynamic>> getFilteredAndSortedLogsForDate(DateTime date) async {
    List<dynamic> dailyLogs = [];
    dailyLogs.addAll(await getMealLogsForDate(date));
    dailyLogs.addAll(await getOvernightLogsForDate(date));

    dailyLogs.sort((a, b) {
      DateTime timeA = a is MealLog ? a.startTime : (a as OvernightLog).bedTime;
      DateTime timeB = b is MealLog ? b.startTime : (b as OvernightLog).bedTime;
      return timeA.compareTo(timeB);
    });
    return dailyLogs;
  }
}