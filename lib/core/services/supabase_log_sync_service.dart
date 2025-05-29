// lib/core/services/supabase_log_sync_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:diabetes_2/data/models/logs/logs.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

// Helper class to bundle log with its original Hive key
class SyncedLog<T> {
  // MODIFICADO: hiveKey ahora es String porque será un UUID
  final String hiveKey;
  final T log;
  SyncedLog({required this.hiveKey, required this.log});
}

class SupabaseLogSyncService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> syncMealLog(MealLog log, dynamic hiveKey /* String UUID */) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint("SupabaseLogSyncService: User not logged in. Cannot sync MealLog.");
      return;
    }

    final Map<String, dynamic> logData = {
      'user_id': userId,
      'hive_key': hiveKey.toString(), // hiveKey ya es String (UUID)
      'start_time': log.startTime.toIso8601String(),
      'initial_blood_sugar': log.initialBloodSugar,
      'carbohydrates': log.carbohydrates,
      'insulin_units': log.insulinUnits,
      'final_blood_sugar': log.finalBloodSugar,
      'end_time': log.endTime?.toIso8601String(),
    };

    try {
      logData.removeWhere((key, value) => value == null && (key == 'final_blood_sugar' || key == 'end_time'));
      logData['updated_at'] = DateTime.now().toIso8601String();

      await _supabase.from('meal_logs').upsert(
        logData,
        onConflict: 'user_id,hive_key',
      );
      debugPrint("SupabaseLogSyncService: MealLog con hive_key '$hiveKey' sincronizado exitosamente.");
    } catch (e) {
      debugPrint("SupabaseLogSyncService: Error sincronizando MealLog con hive_key '$hiveKey': $e");
      rethrow;
    }
  }

  Future<void> syncOvernightLog(OvernightLog log, dynamic hiveKey /* String UUID */) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint("SupabaseLogSyncService: User not logged in. Cannot sync OvernightLog.");
      return;
    }

    final Map<String, dynamic> logData = {
      'user_id': userId,
      'hive_key': hiveKey.toString(), // hiveKey ya es String (UUID)
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
      debugPrint("SupabaseLogSyncService: OvernightLog con hive_key '$hiveKey' sincronizado exitosamente.");
    } catch (e) {
      debugPrint("SupabaseLogSyncService: Error sincronizando OvernightLog con hive_key '$hiveKey': $e");
      rethrow;
    }
  }

  Future<List<SyncedLog<MealLog>>> fetchMealLogsFromSupabase() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint("SupabaseLogSyncService: User not logged in. Cannot fetch MealLogs.");
      return [];
    }

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
        );
        // MODIFICADO: hiveKey es String (UUID) directamente de Supabase (columna TEXT)
        final String hiveKey = map['hive_key'] as String;
        syncedLogs.add(SyncedLog<MealLog>(hiveKey: hiveKey, log: mealLog));
      }
      debugPrint("SupabaseLogSyncService: Obtenidos ${syncedLogs.length} MealLogs desde Supabase.");
      return syncedLogs;
    } catch (e) {
      debugPrint("SupabaseLogSyncService: Error obteniendo MealLogs desde Supabase: $e");
      throw Exception('Error al obtener registros de comida: $e');
    }
  }

  Future<List<SyncedLog<OvernightLog>>> fetchOvernightLogsFromSupabase() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint("SupabaseLogSyncService: User not logged in. Cannot fetch OvernightLogs.");
      return [];
    }

    try {
      final response = await _supabase
          .from('overnight_logs')
          .select()
          .eq('user_id', userId);

      final List<SyncedLog<OvernightLog>> syncedLogs = [];
      for (var item in response as List<dynamic>) {
        final map = item as Map<String, dynamic>;
        final overnightLog = OvernightLog(
          bedTime: DateTime.parse(map['bed_time'] as String),
          beforeSleepBloodSugar: (map['before_sleep_blood_sugar'] as num).toDouble(),
          slowInsulinUnits: (map['slow_insulin_units'] as num).toDouble(),
          afterWakeUpBloodSugar: map['after_wake_up_blood_sugar'] != null ? (map['after_wake_up_blood_sugar'] as num).toDouble() : null,
        );
        // MODIFICADO: hiveKey es String (UUID)
        final String hiveKey = map['hive_key'] as String;
        syncedLogs.add(SyncedLog<OvernightLog>(hiveKey: hiveKey, log: overnightLog));
      }
      debugPrint("SupabaseLogSyncService: Obtenidos ${syncedLogs.length} OvernightLogs desde Supabase.");
      return syncedLogs;
    } catch (e) {
      debugPrint("SupabaseLogSyncService: Error obteniendo OvernightLogs desde Supabase: $e");
      throw Exception('Error al obtener registros nocturnos: $e');
    }
  }

  Future<void> deleteAllUserMealLogsFromSupabase() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint("SupabaseLogSyncService: User not logged in. Cannot delete MealLogs.");
      throw Exception("Usuario no autenticado para borrar registros de comida.");
    }
    try {
      await _supabase.from('meal_logs').delete().eq('user_id', userId);
      debugPrint("SupabaseLogSyncService: Todos los MealLogs del usuario $userId borrados de Supabase.");
    } catch (e) {
      debugPrint("SupabaseLogSyncService: Error borrando MealLogs de Supabase: $e");
      throw Exception('Error al borrar registros de comida de la nube: $e');
    }
  }

  Future<void> deleteAllUserOvernightLogsFromSupabase() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint("SupabaseLogSyncService: User not logged in. Cannot delete OvernightLogs.");
      throw Exception("Usuario no autenticado para borrar registros nocturnos.");
    }
    try {
      await _supabase.from('overnight_logs').delete().eq('user_id', userId);
      debugPrint("SupabaseLogSyncService: Todos los OvernightLogs del usuario $userId borrados de Supabase.");
    } catch (e) {
      debugPrint("SupabaseLogSyncService: Error borrando OvernightLogs de Supabase: $e");
      throw Exception('Error al borrar registros nocturnos de la nube: $e');
    }
  }
}