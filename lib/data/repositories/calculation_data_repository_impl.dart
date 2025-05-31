// Archivo: lib/data/repositories/calculation_data_repository_impl.dart
// Descripción: Implementación concreta de la interfaz CalculationDataRepository.
// Esta clase se encarga de la lógica específica para guardar y recuperar
// objetos DailyCalculationData, utilizando Hive para el almacenamiento local
// y SupabaseLogSyncService para la sincronización con la nube si está habilitada.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:flutter/foundation.dart'; // Para debugPrint.
import 'package:hive/hive.dart'; // Para interactuar con la base de datos local Hive (Box).
import 'package:shared_preferences/shared_preferences.dart'; // Para leer preferencias compartidas (ej. si el guardado en nube está activo).

// Importaciones de archivos del proyecto
import 'package:DiabetiApp/data/models/calculations/daily_calculation_data.dart'; // Modelo DailyCalculationData.
import 'package:DiabetiApp/data/repositories/calculation_data_repository.dart'; // Interfaz que esta clase implementa.
import 'package:DiabetiApp/core/services/supabase_log_sync_service.dart'; // Servicio para sincronizar con Supabase.
import 'package:DiabetiApp/main.dart' show supabase; // Para acceder a `supabase.auth.currentUser` y verificar el estado de login.

// Constante para la clave de SharedPreferences que indica si el guardado en la nube está habilitado.
// Sería ideal que esta constante estuviera definida en un lugar central si se usa en múltiples repositorios o servicios.
const String cloudSavePreferenceKeyFromCalcRepo = 'saveToCloudEnabled';

/// CalculationDataRepositoryImpl: Implementación de `CalculationDataRepository`.
///
/// Gestiona la persistencia de `DailyCalculationData` en una caja de Hive y,
/// opcionalmente, sincroniza estos datos con Supabase.
class CalculationDataRepositoryImpl implements CalculationDataRepository {
  // Caja de Hive para almacenar objetos DailyCalculationData.
  // La clave en esta caja suele ser la fecha formateada como 'yyyy-MM-dd'.
  final Box<DailyCalculationData> _dailyCalculationsBox;

  // Servicio para sincronizar los datos de cálculo diario con Supabase.
  final SupabaseLogSyncService _supabaseLogSyncService;

  // Instancia de SharedPreferences para comprobar si el guardado en la nube está habilitado.
  final SharedPreferences _sharedPreferences;

  /// Constructor: Inyecta las dependencias necesarias.
  ///
  /// @param dailyCalculationsBox La caja de Hive donde se almacenan los DailyCalculationData.
  /// @param supabaseLogSyncService El servicio para la sincronización con Supabase.
  /// @param sharedPreferences Instancia de SharedPreferences.
  CalculationDataRepositoryImpl({
    required Box<DailyCalculationData> dailyCalculationsBox,
    required SupabaseLogSyncService supabaseLogSyncService,
    required SharedPreferences sharedPreferences,
  })  : _dailyCalculationsBox = dailyCalculationsBox,
        _supabaseLogSyncService = supabaseLogSyncService,
        _sharedPreferences = sharedPreferences;

  @override
  /// getDailyCalculation: Obtiene los datos de cálculo para una fecha específica desde Hive.
  ///
  /// @param dateKey La fecha (formateada como 'yyyy-MM-dd') de los datos a recuperar.
  /// @return Un `Future` que resuelve al `DailyCalculationData` correspondiente a `dateKey`,
  ///         o `null` si no se encuentra.
  Future<DailyCalculationData?> getDailyCalculation(String dateKey) async {
    return _dailyCalculationsBox.get(dateKey);
  }

  @override
  /// saveDailyCalculation: Guarda o actualiza los datos de cálculo diario en Hive y,
  /// si está configurado, los sincroniza con Supabase.
  ///
  /// @param dateKey La fecha (formateada como 'yyyy-MM-dd') a la que corresponden los datos.
  /// @param data El objeto `DailyCalculationData` a guardar.
  /// @return Un `Future<void>` que se completa cuando la operación de guardado (y sincronización opcional) termina.
  Future<void> saveDailyCalculation(String dateKey, DailyCalculationData data) async {
    // Guarda el objeto en la caja de Hive usando dateKey como clave.
    await _dailyCalculationsBox.put(dateKey, data);
    debugPrint("CalculationDataRepository: DailyCalculationData para '$dateKey' guardado en Hive.");

    // Comprueba si el guardado en la nube está habilitado y si el usuario está logueado.
    final bool cloudSaveEnabled = _sharedPreferences.getBool(cloudSavePreferenceKeyFromCalcRepo) ?? false;
    final bool isLoggedIn = supabase.auth.currentUser != null; //

    if (cloudSaveEnabled && isLoggedIn) {
      try {
        // Si ambas condiciones se cumplen, sincroniza los datos con Supabase.
        await _supabaseLogSyncService.syncDailyCalculation(data); //
        debugPrint("CalculationDataRepository: DailyCalculationData para '$dateKey' sincronizado con Supabase.");
      } catch (e) {
        // Maneja errores durante la sincronización.
        // Se podría implementar una estrategia de reintento o logging más robusto aquí.
        debugPrint("CalculationDataRepository: Error sincronizando DailyCalculationData para '$dateKey': $e");
        // Es importante considerar si se debe relanzar el error. En este caso, se prioriza
        // el guardado local, por lo que un error de sincronización no interrumpe la operación.
      }
    } else {
      // Mensaje informativo si la sincronización no se realiza.
      String reason = !cloudSaveEnabled ? "guardado en la nube desactivado" : "usuario no logueado";
      debugPrint("CalculationDataRepository: DailyCalculationData para '$dateKey' NO sincronizado ($reason).");
    }
  }

  @override
  /// getDailyCalculationsInDateRange: Obtiene una lista de `DailyCalculationData` para un rango de fechas desde Hive.
  ///
  /// @param startDate La fecha de inicio del rango (inclusiva).
  /// @param endDate La fecha de fin del rango (inclusiva).
  /// @return Un `Future` que resuelve a una `List<DailyCalculationData>`
  ///         conteniendo todos los registros dentro del rango especificado.
  Future<List<DailyCalculationData>> getDailyCalculationsInDateRange(DateTime startDate, DateTime endDate) async {
    // Filtra los valores de la caja de Hive.
    return _dailyCalculationsBox.values.where((calc) {
      // Normaliza las fechas a medianoche para asegurar comparaciones correctas a nivel de día.
      final calcDate = DateTime(calc.date.year, calc.date.month, calc.date.day); //
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day);
      // Comprueba si la fecha del cálculo está dentro del rango [start, end].
      return !calcDate.isBefore(start) && !calcDate.isAfter(end);
    }).toList();
  }
}