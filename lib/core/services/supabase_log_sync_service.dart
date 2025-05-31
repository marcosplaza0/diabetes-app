// Archivo: lib/core/services/supabase_log_sync_service.dart
// Descripción: Servicio dedicado a la sincronización de datos de registros
// (MealLog, OvernightLog) y resúmenes diarios (DailyCalculationData)
// con una base de datos Supabase. Proporciona métodos para subir (upsert),
// descargar (fetch) y eliminar datos de las tablas correspondientes en Supabase.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:supabase_flutter/supabase_flutter.dart'; // Para SupabaseClient y la interacción con Supabase.
import 'package:flutter/foundation.dart'; // Para debugPrint.
import 'package:intl/intl.dart'; // Para formateo de fechas (ej. para DailyCalculationData).

// Importaciones de archivos del proyecto
import 'package:DiabetiApp/data/models/logs/logs.dart'; // Modelos MealLog y OvernightLog.
import 'package:DiabetiApp/data/models/calculations/daily_calculation_data.dart'; // Modelo DailyCalculationData.

/// SyncedLog: Clase genérica para envolver un log junto con su clave de Hive.
///
/// Utilizada principalmente al descargar logs desde Supabase para mantener la asociación
/// entre el log y su identificador único en el almacenamiento local (Hive).
///
/// @param T El tipo de log (ej. MealLog, OvernightLog).
class SyncedLog<T> {
  final String hiveKey; // La clave del log tal como se almacena en Hive.
  final T log;          // El objeto de log en sí.

  SyncedLog({required this.hiveKey, required this.log});
}

/// SupabaseLogSyncService: Servicio para gestionar la sincronización de datos con Supabase.
///
/// Encapsula la lógica para:
/// - Enviar (upsert) `MealLog`, `OvernightLog` y `DailyCalculationData` a sus respectivas tablas en Supabase.
/// - Obtener (fetch) `MealLog` y `OvernightLog` de Supabase para el usuario actual.
/// - Eliminar todos los logs de un usuario de las tablas de Supabase.
class SupabaseLogSyncService {
  // Instancia del cliente de Supabase para interactuar con la base de datos.
  final SupabaseClient _supabase = Supabase.instance.client;

  /// syncMealLog: Sincroniza un `MealLog` con la tabla 'meal_logs' en Supabase.
  ///
  /// Utiliza una operación `upsert` (update or insert) basada en el conflicto de `user_id` y `hive_key`.
  /// Esto significa que si ya existe un log con el mismo `user_id` y `hive_key`, se actualizará;
  /// de lo contrario, se insertará uno nuevo.
  ///
  /// @param log El objeto `MealLog` a sincronizar.
  /// @param hiveKey La clave de Hive del log, usada como parte de la clave primaria compuesta en Supabase.
  Future<void> syncMealLog(MealLog log, dynamic hiveKey /* String UUID */) async {
    final userId = _supabase.auth.currentUser?.id; // Obtiene el ID del usuario actual.
    if (userId == null) { return; } // No hacer nada si no hay usuario logueado.

    // Mapea los campos del objeto MealLog a un Map<String, dynamic> para Supabase.
    // Asegura la consistencia de nombres de campo con la tabla de Supabase.
    final Map<String, dynamic> logData = {
      'user_id': userId,
      'hive_key': hiveKey.toString(), // Clave de Hive como String.
      'start_time': log.startTime.toIso8601String(), //
      'initial_blood_sugar': log.initialBloodSugar, //
      'carbohydrates': log.carbohydrates, //
      'insulin_units': log.insulinUnits, //
      'final_blood_sugar': log.finalBloodSugar, //
      'end_time': log.endTime?.toIso8601String(), //
      // --- CAMPOS ACTUALIZADOS SEGÚN NUEVOS NOMBRES EN EL MODELO/SUPABASE ---
      'ratio_insulina_carbohidratos_div10': log.ratioInsulinaCarbohidratosDiv10, //
      'desviacion': log.desviacion, // RENOMBRADO (del modelo Dart) //
      'ratio_final': log.ratioFinal, // RENOMBRADO (del modelo Dart) //
      // ---------------------------------------------
    };

    try {
      // Elimina campos nulos del mapa, excepto los que son obligatorios o claves.
      // Supabase puede requerir que ciertos campos no se envíen si son nulos y la columna no los permite,
      // o puede interpretarlos como un deseo de poner a NULL el campo en la BD.
      // Esta lógica asegura que `updated_at` y las claves primarias siempre se envíen.
      logData.removeWhere((key, value) => value == null);
      logData['updated_at'] = DateTime.now().toIso8601String(); // Sello de tiempo de la última actualización.
      // Re-asegura que los campos clave no se eliminen si eran null antes de removeWhere (aunque no deberían serlo).
      logData['user_id'] = userId;
      logData['hive_key'] = hiveKey.toString();
      logData['start_time'] = log.startTime.toIso8601String(); //


      // Realiza la operación de upsert en la tabla 'meal_logs'.
      // `onConflict` especifica las columnas que definen un conflicto (clave primaria compuesta).
      await _supabase.from('meal_logs').upsert(
        logData,
        onConflict: 'user_id,hive_key', // Si existe un registro con este user_id y hive_key, se actualiza.
      );
      debugPrint("SupabaseLogSyncService: MealLog con hive_key '$hiveKey' (RatioFinal: ${log.ratioFinal}) sincronizado."); //
    } catch (e) {
      debugPrint("SupabaseLogSyncService: Error sincronizando MealLog con hive_key '$hiveKey': $e");
      rethrow; // Relanza la excepción para que el llamador pueda manejarla.
    }
  }

  /// syncOvernightLog: Sincroniza un `OvernightLog` con la tabla 'overnight_logs' en Supabase.
  ///
  /// Similar a `syncMealLog`, usa `upsert` basado en `user_id` y `hive_key`.
  ///
  /// @param log El objeto `OvernightLog` a sincronizar.
  /// @param hiveKey La clave de Hive del log.
  Future<void> syncOvernightLog(OvernightLog log, dynamic hiveKey ) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) { return; }

    final Map<String, dynamic> logData = {
      'user_id': userId,
      'hive_key': hiveKey.toString(),
      'bed_time': log.bedTime.toIso8601String(), //
      'before_sleep_blood_sugar': log.beforeSleepBloodSugar, //
      'slow_insulin_units': log.slowInsulinUnits, //
      'after_wake_up_blood_sugar': log.afterWakeUpBloodSugar, //
    };
    try {
      // Lógica específica para OvernightLog: solo elimina 'after_wake_up_blood_sugar' si es nulo.
      // Otros campos nulos no se eliminan explícitamente aquí, asumiendo que la tabla los permite
      // o que no deberían ser nulos.
      logData.removeWhere((key, value) => value == null && key == 'after_wake_up_blood_sugar');
      logData['updated_at'] = DateTime.now().toIso8601String();

      await _supabase.from('overnight_logs').upsert(
        logData,
        onConflict: 'user_id,hive_key',
      );
    } catch (e) {
      debugPrint("SupabaseLogSyncService: Error sincronizando OvernightLog con hive_key '$hiveKey': $e");
      rethrow;
    }
  }

  /// syncDailyCalculation: Sincroniza un `DailyCalculationData` con la tabla 'daily_summaries' en Supabase.
  ///
  /// Utiliza `upsert` basado en `user_id` y `date`.
  ///
  /// @param dailyCalc El objeto `DailyCalculationData` a sincronizar.
  Future<void> syncDailyCalculation(DailyCalculationData dailyCalc) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) { return; }

    // Formatea la fecha a 'yyyy-MM-dd' para la clave en Supabase.
    final String dateString = DateFormat('yyyy-MM-dd').format(dailyCalc.date); //
    // Mapea los campos de DailyCalculationData al formato esperado por la tabla 'daily_summaries'.
    final Map<String, dynamic> dataToSync = {
      'user_id': userId,
      'date': dateString,
      'total_meal_insulin': dailyCalc.totalMealInsulin, //
      'daily_correction_index': dailyCalc.dailyCorrectionIndex, //
      // Mapeo de promedios por período (P1-P7).
      'period_p1_avg_index': dailyCalc.periodFinalIndexAverage?['P1'], //
      'period_p2_avg_index': dailyCalc.periodFinalIndexAverage?['P2'], //
      'period_p3_avg_index': dailyCalc.periodFinalIndexAverage?['P3'], //
      'period_p4_avg_index': dailyCalc.periodFinalIndexAverage?['P4'], //
      'period_p5_avg_index': dailyCalc.periodFinalIndexAverage?['P5'], //
      'period_p6_avg_index': dailyCalc.periodFinalIndexAverage?['P6'], //
      'period_p7_avg_index': dailyCalc.periodFinalIndexAverage?['P7'], //
      'updated_at': DateTime.now().toIso8601String(),
    };
    // Elimina campos nulos del mapa, excepto las claves primarias.
    dataToSync.removeWhere((key, value) => value == null);
    dataToSync['user_id'] = userId; // Re-asegura claves.
    dataToSync['date'] = dateString;
    try {
      await _supabase.from('daily_summaries').upsert(
        dataToSync,
        onConflict: 'user_id,date', // Clave primaria compuesta en Supabase.
      );
      debugPrint("SupabaseLogSyncService: DailyCalculation para fecha '$dateString' sincronizado.");
    } catch (e) {
      debugPrint("SupabaseLogSyncService: Error sincronizando DailyCalculation para fecha '$dateString': $e");
      rethrow;
    }
  }

  /// fetchMealLogsFromSupabase: Obtiene todos los `MealLog`s del usuario actual desde Supabase.
  ///
  /// @return Un `Future<List<SyncedLog<MealLog>>>` que contiene los logs descargados,
  ///         cada uno envuelto en `SyncedLog` con su `hive_key`.
  Future<List<SyncedLog<MealLog>>> fetchMealLogsFromSupabase() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) { return []; } // Devuelve lista vacía si no hay usuario.

    try {
      // Selecciona todos los logs del usuario actual de la tabla 'meal_logs'.
      final response = await _supabase
          .from('meal_logs')
          .select() // Selecciona todas las columnas.
          .eq('user_id', userId); // Filtra por user_id.

      final List<SyncedLog<MealLog>> syncedLogs = [];
      // Procesa la respuesta (lista de mapas) y convierte cada item a un objeto MealLog.
      for (var item in response as List<dynamic>) {
        final map = item as Map<String, dynamic>;
        // Mapeo inverso: de Supabase a objeto MealLog.
        // Es crucial que los nombres de campo ('start_time', etc.) coincidan con los de la tabla Supabase.
        // También se manejan las conversiones de tipo (ej. num a double, String a DateTime).
        final mealLog = MealLog(
          startTime: DateTime.parse(map['start_time'] as String),
          initialBloodSugar: (map['initial_blood_sugar'] as num).toDouble(),
          carbohydrates: (map['carbohydrates'] as num).toDouble(),
          insulinUnits: (map['insulin_units'] as num).toDouble(),
          finalBloodSugar: map['final_blood_sugar'] != null ? (map['final_blood_sugar'] as num).toDouble() : null,
          endTime: map['end_time'] != null ? DateTime.parse(map['end_time'] as String) : null,
          // --- LECTURA DE LOS NUEVOS NOMBRES DE CAMPO (si han cambiado en Supabase) ---
          ratioInsulinaCarbohidratosDiv10: map['ratio_insulina_carbohidratos_div10'] != null ? (map['ratio_insulina_carbohidratos_div10'] as num).toDouble() : null,
          desviacion: map['desviacion'] != null ? (map['desviacion'] as num).toDouble() : null,
          ratioFinal: map['ratio_final'] != null ? (map['ratio_final'] as num).toDouble() : null,
        );
        final String hiveKey = map['hive_key'] as String; // Obtiene la hive_key.
        syncedLogs.add(SyncedLog<MealLog>(hiveKey: hiveKey, log: mealLog)); // Añade a la lista de SyncedLog.
      }
      return syncedLogs;
    } catch (e) {
      debugPrint("SupabaseLogSyncService: Error obteniendo MealLogs desde Supabase: $e");
      throw Exception('Error al obtener registros de comida: $e'); // Relanza como una excepción más genérica.
    }
  }

  /// fetchOvernightLogsFromSupabase: Obtiene todos los `OvernightLog`s del usuario actual desde Supabase.
  ///
  /// Similar a `fetchMealLogsFromSupabase`.
  /// @return Un `Future<List<SyncedLog<OvernightLog>>>`.
  Future<List<SyncedLog<OvernightLog>>> fetchOvernightLogsFromSupabase() async {
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

  /// deleteAllUserMealLogsFromSupabase: Elimina todos los `MealLog`s del usuario actual de Supabase.
  Future<void> deleteAllUserMealLogsFromSupabase() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("Usuario no autenticado para borrar registros de comida.");
    try {
      // Elimina todos los registros de 'meal_logs' que coincidan con el user_id.
      await _supabase.from('meal_logs').delete().eq('user_id', userId);
    } catch (e) {
      debugPrint("SupabaseLogSyncService: Error borrando MealLogs de Supabase: $e");
      throw Exception('Error al borrar registros de comida de la nube: $e');
    }
  }

  /// deleteAllUserOvernightLogsFromSupabase: Elimina todos los `OvernightLog`s del usuario actual de Supabase.
  Future<void> deleteAllUserOvernightLogsFromSupabase() async {
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