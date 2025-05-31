// Archivo: lib/features/settings/presentation/settings_view_model.dart
// Descripción: ViewModel para la pantalla de Ajustes (SettingsScreen).
// Este archivo contiene la lógica de negocio y el estado para gestionar las
// configuraciones de la aplicación, como la preferencia de guardado en la nube,
// la sincronización de datos con Supabase, la importación y borrado de datos,
// y la gestión del tema de la aplicación.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:flutter/foundation.dart'; // Para @required y ChangeNotifier.
import 'package:shared_preferences/shared_preferences.dart'; // Para almacenar preferencias simples de forma persistente.
import 'package:supabase_flutter/supabase_flutter.dart'; // Para acceder al cliente de Supabase, especialmente `Supabase.instance.client.auth`.

// Importaciones de archivos del proyecto
import 'package:DiabetiApp/core/services/supabase_log_sync_service.dart'; // Servicio para sincronizar logs con Supabase.
import 'package:DiabetiApp/data/repositories/log_repository.dart'; // Repositorio para operaciones con logs (locales).
import 'package:DiabetiApp/core/theme/theme_provider.dart'; // Proveedor para gestionar el tema de la aplicación.

// Enums y funciones helper para las opciones de configuración.
// Estos podrían moverse a un archivo de utilidades de esta feature si se vuelven más complejos o se usan en otros lugares.

/// Enum CloudImportStrategy: Define las estrategias para importar datos desde la nube.
enum CloudImportStrategy {
  merge,      // Fusionar los datos de la nube con los datos locales existentes.
  overwrite   // Sobrescribir los datos locales con los datos de la nube (borra los locales primero).
}

/// getStrategyText: Devuelve un texto descriptivo para una CloudImportStrategy.
String getStrategyText(CloudImportStrategy strategy) =>
    strategy == CloudImportStrategy.merge ? 'Juntar con datos locales' : 'Sobrescribir datos locales';

/// Enum DeleteDataScope: Define el ámbito para la operación de borrado de datos.
enum DeleteDataScope {
  localOnly,  // Borrar solo los datos almacenados localmente.
  cloudOnly,  // Borrar solo los datos almacenados en la nube.
  both        // Borrar datos tanto locales como en la nube.
}

/// getDeleteScopeText: Devuelve un texto descriptivo para un DeleteDataScope.
String getDeleteScopeText(DeleteDataScope scope) {
  switch (scope) {
    case DeleteDataScope.localOnly: return 'Sólo datos locales';
    case DeleteDataScope.cloudOnly: return 'Sólo datos en la nube';
    case DeleteDataScope.both: return 'Ambos (local y nube)';
  }
}

// Constante para la clave de SharedPreferences que almacena la preferencia de guardado en la nube.
const String cloudSavePreferenceKey = 'saveToCloudEnabled';

/// SettingsViewModel: Gestiona el estado y la lógica para la pantalla de Ajustes.
///
/// Proporciona métodos para:
/// - Cargar y actualizar la preferencia de guardado en la nube.
/// - Realizar la sincronización inicial de datos con Supabase.
/// - Importar datos desde la nube.
/// - Borrar datos de registros (locales, nube o ambos).
/// - Acceder y modificar el tema de la aplicación a través de `ThemeProvider`.
class SettingsViewModel extends ChangeNotifier {
  final SharedPreferences _prefs; // Instancia de SharedPreferences para leer/escribir preferencias.
  final SupabaseLogSyncService _logSyncService; // Servicio para interactuar con Supabase para logs.
  final LogRepository _logRepository; // Repositorio para acceder a los logs locales.
  final ThemeProvider _themeProvider; // Proveedor para gestionar el tema de la app.

  /// Constructor: Inicializa las dependencias necesarias y carga la preferencia de guardado en la nube.
  SettingsViewModel({
    required SharedPreferences sharedPreferences,
    required SupabaseLogSyncService logSyncService,
    required LogRepository logRepository,
    required ThemeProvider themeProvider,
  })  : _prefs = sharedPreferences,
        _logSyncService = logSyncService,
        _logRepository = logRepository,
        _themeProvider = themeProvider {
    _loadCloudPreference(); // Carga la preferencia al iniciar el ViewModel.
  }

  bool _saveToCloudEnabled = false; // Estado de la preferencia de guardado en la nube.
  bool get saveToCloudEnabled => _saveToCloudEnabled;

  bool _isProcessingData = false; // Indica si se está realizando una operación asíncrona (ej. sincronizando, borrando).
  bool get isProcessingData => _isProcessingData;

  String _operationStatus = ''; // Mensaje de estado para mostrar feedback simple a la UI.
  String get operationStatus => _operationStatus;

  /// themeProvider: Expone el ThemeProvider para que la UI pueda interactuar con él (ej. en el diálogo de selección de tema).
  ThemeProvider get themeProvider => _themeProvider;

  /// _setProcessing: Método privado para actualizar el estado de procesamiento y notificar a los listeners.
  void _setProcessing(bool processing) {
    _isProcessingData = processing;
    notifyListeners(); // Notifica a la UI para que se reconstruya (ej. mostrar/ocultar loaders).
  }

  /// _setStatus: Método privado para actualizar el mensaje de estado de la operación.
  void _setStatus(String status) {
    _operationStatus = status;
    notifyListeners(); // Notifica para que la UI pueda mostrar el mensaje.
  }

  /// _loadCloudPreference: Carga la preferencia de guardado en la nube desde SharedPreferences.
  Future<void> _loadCloudPreference() async {
    _saveToCloudEnabled = _prefs.getBool(cloudSavePreferenceKey) ?? false; // Obtiene el valor, o false si no existe.
    notifyListeners(); // Notifica para que la UI refleje el estado cargado.
  }

  /// updateCloudSavePreference: Actualiza la preferencia de guardado en la nube.
  ///
  /// Si se activa el guardado y previamente estaba desactivado, y el usuario está logueado,
  /// intenta realizar una sincronización inicial de los datos locales a la nube.
  ///
  /// @param value El nuevo valor para la preferencia (true para activar, false para desactivar).
  /// @return Un Future<String> con un mensaje de feedback sobre la operación.
  Future<String> updateCloudSavePreference(bool value) async {
    _setProcessing(true); // Inicia estado de procesamiento.
    final bool previousValue = _prefs.getBool(cloudSavePreferenceKey) ?? false;
    await _prefs.setBool(cloudSavePreferenceKey, value); // Guarda la nueva preferencia.
    _saveToCloudEnabled = value;

    String feedback = value ? "Guardado en la nube activado." : "Guardado en la nube desactivado.";

    // Si se activa el guardado en la nube (y antes estaba desactivado).
    if (value == true && previousValue == false) {
      if (Supabase.instance.client.auth.currentUser == null) { // Comprueba si el usuario está autenticado.
        await _prefs.setBool(cloudSavePreferenceKey, false); // Revierte el cambio si no hay usuario.
        _saveToCloudEnabled = false;
        _setProcessing(false);
        return "Debes iniciar sesión para activar el guardado en la nube.";
      }
      // Realiza la sincronización inicial de datos locales a la nube.
      feedback = await performInitialSupabaseSync(showInProgressMessage: true);
    }
    _setProcessing(false); // Finaliza estado de procesamiento.
    return feedback;
  }

  /// performInitialSupabaseSync: Sincroniza todos los logs locales (comidas y nocturnos) con Supabase.
  ///
  /// Este método se llama típicamente cuando se activa por primera vez el guardado en la nube.
  ///
  /// @param showInProgressMessage Indica si se debe actualizar `_operationStatus` con un mensaje de progreso.
  /// @return Un Future<String> con un mensaje de resultado de la sincronización.
  Future<String> performInitialSupabaseSync({bool showInProgressMessage = false}) async {
    if (Supabase.instance.client.auth.currentUser == null) { // Requiere usuario autenticado.
      return 'Debes iniciar sesión para sincronizar.';
    }
    if(showInProgressMessage) _setStatus('Iniciando sincronización...');
    _setProcessing(true);

    int successCount = 0; // Contador de logs sincronizados exitosamente.
    int errorCount = 0;   // Contador de errores durante la sincronización.
    String resultMessage = "";

    try {
      // Obtiene todos los logs locales del repositorio.
      final mealLogsToSync = await _logRepository.getAllMealLogsMappedByKey();
      final overnightLogsToSync = await _logRepository.getAllOvernightLogsMappedByKey();

      // Itera y sincroniza cada MealLog.
      for (var entry in mealLogsToSync.entries) {
        try {
          await _logSyncService.syncMealLog(entry.value, entry.key);
          successCount++;
        } catch (e) { debugPrint("SettingsVM: Error syncing MealLog key ${entry.key}: $e"); errorCount++; }
      }
      // Itera y sincroniza cada OvernightLog.
      for (var entry in overnightLogsToSync.entries) {
        try {
          await _logSyncService.syncOvernightLog(entry.value, entry.key);
          successCount++;
        } catch (e) { debugPrint("SettingsVM: Error syncing OvernightLog key ${entry.key}: $e"); errorCount++; }
      }
      resultMessage = 'Sincronización completada. Éxitos: $successCount, Errores: $errorCount';
    } catch (e) {
      resultMessage = 'Error durante la sincronización: ${e.toString()}';
    } finally {
      _setStatus(resultMessage); // Actualiza el mensaje de estado final.
      _setProcessing(false);
    }
    return resultMessage;
  }

  /// importDataFromCloud: Importa datos de logs desde Supabase a la base de datos local (Hive).
  ///
  /// @param strategy La estrategia de importación (fusionar o sobrescribir).
  /// @return Un Future<String> con un mensaje de resultado de la importación.
  Future<String> importDataFromCloud(CloudImportStrategy strategy) async {
    if (Supabase.instance.client.auth.currentUser == null) { // Requiere usuario autenticado.
      return 'Debes iniciar sesión para importar desde la nube.';
    }
    _setStatus('Iniciando importación (${getStrategyText(strategy)})...');
    _setProcessing(true);

    int mealLogsImported = 0; // Contador de MealLogs importados.
    int overnightLogsImported = 0; // Contador de OvernightLogs importados.
    String resultMessage = "";

    try {
      // Si la estrategia es sobrescribir, borra todos los logs locales primero.
      if (strategy == CloudImportStrategy.overwrite) {
        await _logRepository.clearAllLocalMealLogs();
        await _logRepository.clearAllLocalOvernightLogs();
      }

      // Obtiene los MealLogs de Supabase.
      final mealLogsFromCloud = await _logSyncService.fetchMealLogsFromSupabase();
      for (final syncedLog in mealLogsFromCloud) {
        // Guarda cada log en la base de datos local usando el repositorio.
        // El repositorio maneja la lógica de `put` en Hive, actualizando si la clave ya existe (merge)
        // o añadiendo nuevo si no (overwrite o merge).
        await _logRepository.saveMealLog(syncedLog.log, syncedLog.hiveKey);
        mealLogsImported++;
      }

      // Obtiene los OvernightLogs de Supabase.
      final overnightLogsFromCloud = await _logSyncService.fetchOvernightLogsFromSupabase();
      for (final syncedLog in overnightLogsFromCloud) {
        await _logRepository.saveOvernightLog(syncedLog.log, syncedLog.hiveKey);
        overnightLogsImported++;
      }
      resultMessage = 'Importación completada. Comidas: $mealLogsImported, Noches: $overnightLogsImported.';
    } catch (e) {
      debugPrint("SettingsVM: Error durante la importación: $e");
      resultMessage = 'Error al importar: ${e.toString()}';
    } finally {
      _setStatus(resultMessage);
      _setProcessing(false);
    }
    return resultMessage;
  }

  /// deleteLogData: Borra datos de logs según el ámbito especificado.
  ///
  /// @param scope El ámbito del borrado (local, nube o ambos).
  /// @return Un Future<String> con un mensaje de resultado de la operación de borrado.
  Future<String> deleteLogData(DeleteDataScope scope) async {
    _setStatus('Borrando datos...');
    _setProcessing(true);
    String? locationMessage; // Para construir el mensaje de feedback.
    String resultMessage = "";

    try {
      // Borrado de datos locales.
      if (scope == DeleteDataScope.localOnly || scope == DeleteDataScope.both) {
        await _logRepository.clearAllLocalMealLogs();
        await _logRepository.clearAllLocalOvernightLogs();
        locationMessage = "locales";
      }

      // Borrado de datos en la nube.
      if (scope == DeleteDataScope.cloudOnly || scope == DeleteDataScope.both) {
        if (Supabase.instance.client.auth.currentUser == null) { // Requiere usuario autenticado.
          throw Exception("Debes iniciar sesión para borrar datos de la nube.");
        }
        await _logSyncService.deleteAllUserMealLogsFromSupabase();
        await _logSyncService.deleteAllUserOvernightLogsFromSupabase();
        // Actualiza el mensaje para reflejar que se borraron datos de la nube.
        locationMessage = (locationMessage != null) ? ("$locationMessage y de la nube") : "de la nube";
      }
      resultMessage = (locationMessage != null) ? "Datos $locationMessage borrados exitosamente." : "No se especificó un ámbito de borrado válido.";

    } catch (e) {
      debugPrint("SettingsVM: Error durante el borrado ($scope): $e");
      resultMessage = 'Error al borrar datos: ${e.toString()}';
    } finally {
      _setStatus(resultMessage);
      _setProcessing(false);
    }
    return resultMessage;
  }
}