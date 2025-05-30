// lib/core/services/supabase_log_sync_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:diabetes_2/data/models/logs/logs.dart';
import 'package:diabetes_2/data/models/calculations/daily_calculation_data.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class SyncedLog<T> {
  final String hiveKey;
  final T log;
  SyncedLog({required this.hiveKey, required this.log});
}

class SupabaseLogSyncService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> syncMealLog(MealLog log, dynamic hiveKey /* String UUID */) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) { return; }

    final Map<String, dynamic> logData = {
      'user_id': userId,
      'hive_key': hiveKey.toString(),
      'start_time': log.startTime.toIso8601String(),
      'initial_blood_sugar': log.initialBloodSugar,
      'carbohydrates': log.carbohydrates,
      'insulin_units': log.insulinUnits,
      'final_blood_sugar': log.finalBloodSugar,
      'end_time': log.endTime?.toIso8601String(),
      // --- CAMPOS ACTUALIZADOS SEGÚN NUEVOS NOMBRES ---
      'ratio_insulina_carbohidratos_div10': log.ratioInsulinaCarbohidratosDiv10,
      'desviacion': log.desviacion, // RENOMBRADO
      'ratio_final': log.ratioFinal, // RENOMBRADO
      // ---------------------------------------------
    };

    try {
      logData.removeWhere((key, value) => value == null);
      logData['updated_at'] = DateTime.now().toIso8601String();
      logData['user_id'] = userId; // Asegurar que no se eliminen si eran null
      logData['hive_key'] = hiveKey.toString();
      logData['start_time'] = log.startTime.toIso8601String();


      await _supabase.from('meal_logs').upsert(
        logData,
        onConflict: 'user_id,hive_key',
      );
      debugPrint("SupabaseLogSyncService: MealLog con hive_key '$hiveKey' (RatioFinal: ${log.ratioFinal}) sincronizado.");
    } catch (e) {
      debugPrint("SupabaseLogSyncService: Error sincronizando MealLog con hive_key '$hiveKey': $e");
      rethrow;
    }
  }

  Future<void> syncOvernightLog(OvernightLog log, dynamic hiveKey ) async {
    // ... (Sin cambios) ...
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) { return; }

    final Map<String, dynamic> logData = {
      'user_id': userId,
      'hive_key': hiveKey.toString(),
      'bed_time': log.bedTime.toIso8601String(),
      'before_sleep_blood_sugar': log.beforeSleepBloodSugar,
      'slow_insulin_units': log.slowInsulinUnits,
      'after_wake_up_blood_sugar': log.afterWakeUpBloodSugar,
    };
    try {
      logData.removeWhere((key, value) => value == null && key == 'after_wake_up_blood_sugar');
      logData['updated_at'] = DateTime.now().toIso8601String();

      await _supabase.from('overnight_logs').upsert(
        logData,
        onConflict: 'user_id,hive_key',
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> syncDailyCalculation(DailyCalculationData dailyCalc) async {
    // ... (Sin cambios, ya que daily_summaries usa period_pX_avg_index
    // y el significado de lo que se promedia cambió en DiabetesCalculatorService) ...
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) { return; }

    final String dateString = DateFormat('yyyy-MM-dd').format(dailyCalc.date);
    final Map<String, dynamic> dataToSync = {
      'user_id': userId,
      'date': dateString,
      'total_meal_insulin': dailyCalc.totalMealInsulin,
      'daily_correction_index': dailyCalc.dailyCorrectionIndex,
      'period_p1_avg_index': dailyCalc.periodFinalIndexAverage?['P1'],
      'period_p2_avg_index': dailyCalc.periodFinalIndexAverage?['P2'],
      'period_p3_avg_index': dailyCalc.periodFinalIndexAverage?['P3'],
      'period_p4_avg_index': dailyCalc.periodFinalIndexAverage?['P4'],
      'period_p5_avg_index': dailyCalc.periodFinalIndexAverage?['P5'],
      'period_p6_avg_index': dailyCalc.periodFinalIndexAverage?['P6'],
      'period_p7_avg_index': dailyCalc.periodFinalIndexAverage?['P7'],
      'updated_at': DateTime.now().toIso8601String(),
    };
    dataToSync.removeWhere((key, value) => value == null);
    dataToSync['user_id'] = userId;
    dataToSync['date'] = dateString;
    try {
      await _supabase.from('daily_summaries').upsert(
        dataToSync,
        onConflict: 'user_id,date',
      );
      debugPrint("SupabaseLogSyncService: DailyCalculation para fecha '$dateString' sincronizado.");
    } catch (e) {
      debugPrint("SupabaseLogSyncService: Error sincronizando DailyCalculation para fecha '$dateString': $e");
      rethrow;
    }
  }

  Future<List<SyncedLog<MealLog>>> fetchMealLogsFromSupabase() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) { return []; }

    try {
      final response = await _supabase
          .from('meal_logs')
          .select()
          .eq('user_id', userId);

      final List<SyncedLog<MealLog>> syncedLogs = [];
      for (var item in response as List<dynamic>) {
        final map = item as Map<String, dynamic>;
        final mealLog = MealLog(
          startTime: DateTime.parse(map['start_time'] as String),
          initialBloodSugar: (map['initial_blood_sugar'] as num).toDouble(),
          carbohydrates: (map['carbohydrates'] as num).toDouble(),
          insulinUnits: (map['insulin_units'] as num).toDouble(),
          finalBloodSugar: map['final_blood_sugar'] != null ? (map['final_blood_sugar'] as num).toDouble() : null,
          endTime: map['end_time'] != null ? DateTime.parse(map['end_time'] as String) : null,
          // --- LEER LOS NUEVOS NOMBRES DE CAMPO ---
          ratioInsulinaCarbohidratosDiv10: map['ratio_insulina_carbohidratos_div10'] != null ? (map['ratio_insulina_carbohidratos_div10'] as num).toDouble() : null,
          desviacion: map['desviacion'] != null ? (map['desviacion'] as num).toDouble() : null,
          ratioFinal: map['ratio_final'] != null ? (map['ratio_final'] as num).toDouble() : null,
        );
        final String hiveKey = map['hive_key'] as String;
        syncedLogs.add(SyncedLog<MealLog>(hiveKey: hiveKey, log: mealLog));
      }
      return syncedLogs;
    } catch (e) {
      debugPrint("SupabaseLogSyncService: Error obteniendo MealLogs desde Supabase: $e");
      throw Exception('Error al obtener registros de comida: $e');
    }
  }

  Future<List<SyncedLog<OvernightLog>>> fetchOvernightLogsFromSupabase() async {
    // ... (Sin cambios) ...
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) { return []; }
    try {
      final response = await _supabase.from('overnight_logs').select().eq('user_id', userId);
      final List<SyncedLog<OvernightLog>> syncedLogs = [];
      for (var item in response as List<dynamic>) {
        final map = item as Map<String, dynamic>;
        final overnightLog = OvernightLog(
          bedTime: DateTime.parse(map['bed_time'] as String),
          beforeSleepBloodSugar: (map['before_sleep_blood_sugar'] as num).toDouble(),
          slowInsulinUnits: (map['slow_insulin_units'] as num).toDouble(),
          afterWakeUpBloodSugar: map['after_wake_up_blood_sugar'] != null ? (map['after_wake_up_blood_sugar'] as num).toDouble() : null,
        );
        final String hiveKey = map['hive_key'] as String;
        syncedLogs.add(SyncedLog<OvernightLog>(hiveKey: hiveKey, log: overnightLog));
      }
      return syncedLogs;
    } catch (e) {
      debugPrint("SupabaseLogSyncService: Error obteniendo OvernightLogs desde Supabase: $e");
      throw Exception('Error al obtener registros nocturnos: $e');
    }
  }

  Future<void> deleteAllUserMealLogsFromSupabase() async {
    // ... (sin cambios) ...
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("Usuario no autenticado para borrar registros de comida.");
    try {
      await _supabase.from('meal_logs').delete().eq('user_id', userId);
    } catch (e) {
      debugPrint("SupabaseLogSyncService: Error borrando MealLogs de Supabase: $e");
      throw Exception('Error al borrar registros de comida de la nube: $e');
    }
  }

  Future<void> deleteAllUserOvernightLogsFromSupabase() async {
    // ... (sin cambios) ...
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("Usuario no autenticado para borrar registros nocturnos.");
    try {
      await _supabase.from('overnight_logs').delete().eq('user_id', userId);
    } catch (e) {
      debugPrint("SupabaseLogSyncService: Error borrando OvernightLogs de Supabase: $e");
      throw Exception('Error al borrar registros nocturnos de la nube: $e');
    }
  }
}