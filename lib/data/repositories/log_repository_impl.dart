// Archivo: lib/data/repositories/log_repository_impl.dart
// Descripción: Implementación concreta de la interfaz LogRepository.
// Esta clase maneja la lógica específica para guardar, recuperar, eliminar y consultar
// los registros de MealLog y OvernightLog. Utiliza Hive para el almacenamiento local
// y SupabaseLogSyncService para la sincronización con la nube si está habilitada.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:flutter/material.dart'; // Para DateUtils y potencialmente otros helpers de UI si fueran necesarios.
import 'package:hive/hive.dart'; // Para interactuar con la base de datos local Hive (Box).
import 'package:shared_preferences/shared_preferences.dart'; // Para leer preferencias compartidas.

// Importaciones de archivos del proyecto
import 'package:DiabetiApp/main.dart' show supabase; // Para acceder a `supabase.auth.currentUser` y verificar estado de login.
import 'package:DiabetiApp/data/models/logs/logs.dart'; // Modelos MealLog y OvernightLog.
import 'package:DiabetiApp/data/repositories/log_repository.dart'; // Interfaz que esta clase implementa.
import 'package:DiabetiApp/core/services/supabase_log_sync_service.dart'; // Servicio para sincronizar con Supabase.

// Constante para la clave de SharedPreferences que indica si el guardado en la nube está habilitado.
// Es importante que esta clave sea consistente dondequiera que se use.
const String cloudSavePreferenceKeyFromRepo = 'saveToCloudEnabled';

/// LogRepositoryImpl: Implementación de `LogRepository`.
///
/// Gestiona la persistencia de `MealLog` y `OvernightLog` en sus respectivas
/// cajas de Hive y, opcionalmente, sincroniza estos datos con Supabase.
class LogRepositoryImpl implements LogRepository {
  // Cajas de Hive para almacenar MealLog y OvernightLog.
  final Box<MealLog> _mealLogBox;
  final Box<OvernightLog> _overnightLogBox;

  // Servicio para sincronizar los logs con Supabase.
  final SupabaseLogSyncService _supabaseLogSyncService;

  // Instancia de SharedPreferences para comprobar preferencias de sincronización.
  final SharedPreferences _sharedPreferences;

  /// Constructor: Inyecta las dependencias necesarias.
  ///
  /// @param mealLogBox La caja de Hive para MealLog.
  /// @param overnightLogBox La caja de Hive para OvernightLog.
  /// @param supabaseLogSyncService El servicio para la sincronización con Supabase.
  /// @param sharedPreferences Instancia de SharedPreferences.
  LogRepositoryImpl({
    required Box<MealLog> mealLogBox,
    required Box<OvernightLog> overnightLogBox,
    required SupabaseLogSyncService supabaseLogSyncService,
    required SharedPreferences sharedPreferences,
  })  : _mealLogBox = mealLogBox,
        _overnightLogBox = overnightLogBox,
        _supabaseLogSyncService = supabaseLogSyncService,
        _sharedPreferences = sharedPreferences;

  // --- Implementaciones para MealLog ---

  @override
  /// saveMealLog: Guarda un `MealLog` en Hive y lo sincroniza con Supabase si está habilitado.
  Future<void> saveMealLog(MealLog log, String hiveKey) async {
    await _mealLogBox.put(hiveKey, log); // Guarda en la caja local de Hive.
    // Verifica si el guardado en la nube está activo y si el usuario está logueado.
    final bool cloudSaveEnabled = _sharedPreferences.getBool(cloudSavePreferenceKeyFromRepo) ?? false;
    final bool isLoggedIn = supabase.auth.currentUser != null; //

    if (cloudSaveEnabled && isLoggedIn) {
      try {
        // Sincroniza el log con Supabase.
        await _supabaseLogSyncService.syncMealLog(log, hiveKey); //
      } catch (e) {
        // Manejo de errores durante la sincronización.
        // Se registra el error pero no se relanza para no interrumpir el guardado local.
        debugPrint("LogRepositoryImpl: Error syncing MealLog $hiveKey during save: $e");
      }
    }
  }

  @override
  /// getMealLog: Obtiene un `MealLog` de Hive por su clave.
  Future<MealLog?> getMealLog(String hiveKey) async {
    return _mealLogBox.get(hiveKey);
  }

  @override
  /// getMealLogsForDate: Obtiene todos los `MealLog`s de Hive para una fecha específica.
  /// Compara solo la parte de la fecha, ignorando la hora.
  Future<List<MealLog>> getMealLogsForDate(DateTime date) async {
    return _mealLogBox.values
        .where((log) => DateUtils.isSameDay(log.startTime, date)) //
        .toList();
  }

  @override
  /// getMealLogsInDateRange: Obtiene todos los `MealLog`s de Hive dentro de un rango de fechas.
  /// El rango es inclusivo para startDate y endDate.
  Future<List<MealLog>> getMealLogsInDateRange(DateTime startDate, DateTime endDate) async {
    return _mealLogBox.values.where((log) {
      final logDate = log.startTime; //
      // Asegura que la fecha del log no sea anterior a startDate y no sea posterior a endDate.
      // Se añade un día a endDate y se usa isBefore para hacer que endDate sea inclusivo a nivel de día.
      return !logDate.isBefore(startDate) && logDate.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
  }

  @override
  /// getAllMealLogsMappedByKey: Obtiene todos los `MealLog`s de Hive como un mapa [clave -> log].
  Future<Map<String, MealLog>> getAllMealLogsMappedByKey() async {
    return _mealLogBox.toMap().cast<String, MealLog>(); // Asegura el tipo correcto del mapa.
  }

  @override
  /// deleteMealLog: Elimina un `MealLog` de Hive por su clave.
  /// Nota: Este método, por sí solo, no elimina el log de Supabase.
  Future<void> deleteMealLog(String hiveKey) async {
    await _mealLogBox.delete(hiveKey);
  }

  @override
  /// clearAllLocalMealLogs: Elimina todos los `MealLog`s de la caja local de Hive.
  Future<void> clearAllLocalMealLogs() async {
    await _mealLogBox.clear(); // Limpia completamente la caja.
  }

  // --- Implementaciones para OvernightLog ---

  @override
  /// saveOvernightLog: Guarda un `OvernightLog` en Hive y lo sincroniza con Supabase si está habilitado.
  Future<void> saveOvernightLog(OvernightLog log, String hiveKey) async {
    await _overnightLogBox.put(hiveKey, log);
    final bool cloudSaveEnabled = _sharedPreferences.getBool(cloudSavePreferenceKeyFromRepo) ?? false;
    final bool isLoggedIn = supabase.auth.currentUser != null; //
    if (cloudSaveEnabled && isLoggedIn) {
      try {
        await _supabaseLogSyncService.syncOvernightLog(log, hiveKey); //
      } catch (e) {
        debugPrint("LogRepositoryImpl: Error syncing OvernightLog $hiveKey during save: $e");
      }
    }
  }

  @override
  /// getOvernightLog: Obtiene un `OvernightLog` de Hive por su clave.
  Future<OvernightLog?> getOvernightLog(String hiveKey) async {
    return _overnightLogBox.get(hiveKey);
  }

  @override
  /// getOvernightLogsForDate: Obtiene todos los `OvernightLog`s de Hive para una fecha específica.
  Future<List<OvernightLog>> getOvernightLogsForDate(DateTime date) async {
    return _overnightLogBox.values
        .where((log) => DateUtils.isSameDay(log.bedTime, date)) //
        .toList();
  }

  @override
  /// getOvernightLogsInDateRange: Obtiene todos los `OvernightLog`s de Hive dentro de un rango de fechas.
  Future<List<OvernightLog>> getOvernightLogsInDateRange(DateTime startDate, DateTime endDate) async {
    return _overnightLogBox.values.where((log) {
      final logDate = log.bedTime; //
      return !logDate.isBefore(startDate) && logDate.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
  }

  @override
  /// getAllOvernightLogsMappedByKey: Obtiene todos los `OvernightLog`s de Hive como un mapa [clave -> log].
  Future<Map<String, OvernightLog>> getAllOvernightLogsMappedByKey() async {
    return _overnightLogBox.toMap().cast<String, OvernightLog>();
  }

  @override
  /// deleteOvernightLog: Elimina un `OvernightLog` de Hive por su clave.
  Future<void> deleteOvernightLog(String hiveKey) async {
    await _overnightLogBox.delete(hiveKey);
  }

  @override
  /// clearAllLocalOvernightLogs: Elimina todos los `OvernightLog`s de la caja local de Hive.
  Future<void> clearAllLocalOvernightLogs() async {
    await _overnightLogBox.clear();
  }

  // --- Implementaciones Combinadas de Logs ---

  @override
  /// getRecentLogs: Obtiene logs recientes (MealLog y OvernightLog) de las últimas `duration` horas.
  /// Devuelve una lista de mapas, cada uno con el log, tipo, clave y hora, ordenados por más recientes primero.
  Future<List<Map<String, dynamic>>> getRecentLogs(Duration duration) async {
    final now = DateTime.now();
    final cutOffTime = now.subtract(duration); // Calcula el tiempo límite.
    List<Map<String, dynamic>> combinedLogs = [];

    // Procesa MealLogs.
    for (var entry in _mealLogBox.toMap().entries) {
      if (entry.value.startTime.isAfter(cutOffTime)) { //
        combinedLogs.add({'time': entry.value.startTime, 'log': entry.value, 'type': 'meal', 'key': entry.key}); //
      }
    }
    // Procesa OvernightLogs.
    for (var entry in _overnightLogBox.toMap().entries) {
      if (entry.value.bedTime.isAfter(cutOffTime)) { //
        combinedLogs.add({'time': entry.value.bedTime, 'log': entry.value, 'type': 'overnight', 'key': entry.key}); //
      }
    }
    // Ordena los logs combinados por fecha/hora descendente (más recientes primero).
    combinedLogs.sort((a, b) => (b['time'] as DateTime).compareTo(a['time'] as DateTime));
    return combinedLogs;
  }

  @override
  /// getFilteredAndSortedLogsForDate: Obtiene y ordena todos los logs (MealLog y OvernightLog) para una fecha dada.
  /// La lista resultante está ordenada cronológicamente.
  Future<List<dynamic>> getFilteredAndSortedLogsForDate(DateTime date) async {
    List<dynamic> dailyLogs = [];
    // Obtiene y añade MealLogs para la fecha.
    dailyLogs.addAll(await getMealLogsForDate(date));
    // Obtiene y añade OvernightLogs para la fecha.
    dailyLogs.addAll(await getOvernightLogsForDate(date));

    // Ordena la lista combinada por la hora del evento.
    dailyLogs.sort((a, b) {
      DateTime timeA = a is MealLog ? a.startTime : (a as OvernightLog).bedTime; //
      DateTime timeB = b is MealLog ? b.startTime : (b as OvernightLog).bedTime; //
      return timeA.compareTo(timeB); // Orden ascendente.
    });
    return dailyLogs;
  }
}