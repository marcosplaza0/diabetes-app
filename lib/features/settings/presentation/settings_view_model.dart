// lib/features/settings/presentation/settings_view_model.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Para Supabase.instance.client.auth

import 'package:diabetes_2/core/services/supabase_log_sync_service.dart';
import 'package:diabetes_2/data/repositories/log_repository.dart';
// import 'package:diabetes_2/data/models/logs/logs.dart'; // No se necesitan los modelos aquí directamente
import 'package:diabetes_2/core/theme/theme_provider.dart'; // Para cambiar el tema

// Enums y helpers de SettingsScreen (podrían estar en un archivo de utilidades de esta feature)
enum CloudImportStrategy { merge, overwrite }
String getStrategyText(CloudImportStrategy strategy) =>
    strategy == CloudImportStrategy.merge ? 'Juntar con datos locales' : 'Sobrescribir datos locales';

enum DeleteDataScope { localOnly, cloudOnly, both }
String getDeleteScopeText(DeleteDataScope scope) {
  switch (scope) {
    case DeleteDataScope.localOnly: return 'Sólo datos locales';
    case DeleteDataScope.cloudOnly: return 'Sólo datos en la nube';
    case DeleteDataScope.both: return 'Ambos (local y nube)';
  }
}

const String cloudSavePreferenceKey = 'saveToCloudEnabled'; // Usada por el ViewModel

class SettingsViewModel extends ChangeNotifier {
  final SharedPreferences _prefs;
  final SupabaseLogSyncService _logSyncService;
  final LogRepository _logRepository;
  final ThemeProvider _themeProvider; // Para cambiar el tema

  SettingsViewModel({
    required SharedPreferences sharedPreferences,
    required SupabaseLogSyncService logSyncService,
    required LogRepository logRepository,
    required ThemeProvider themeProvider,
  })  : _prefs = sharedPreferences,
        _logSyncService = logSyncService,
        _logRepository = logRepository,
        _themeProvider = themeProvider {
    _loadCloudPreference();
  }

  bool _saveToCloudEnabled = false;
  bool get saveToCloudEnabled => _saveToCloudEnabled;

  bool _isProcessingData = false;
  bool get isProcessingData => _isProcessingData;

  String _operationStatus = ''; // Para feedback simple
  String get operationStatus => _operationStatus;

  ThemeProvider get themeProvider => _themeProvider; // Exponer para la UI del diálogo de tema

  void _setProcessing(bool processing) {
    _isProcessingData = processing;
    notifyListeners();
  }

  void _setStatus(String status) {
    _operationStatus = status;
    notifyListeners(); // Podrías tener un listener específico para esto o no.
  }

  Future<void> _loadCloudPreference() async {
    _saveToCloudEnabled = _prefs.getBool(cloudSavePreferenceKey) ?? false;
    notifyListeners();
  }

  Future<String> updateCloudSavePreference(bool value) async {
    _setProcessing(true);
    final bool previousValue = _prefs.getBool(cloudSavePreferenceKey) ?? false;
    await _prefs.setBool(cloudSavePreferenceKey, value);
    _saveToCloudEnabled = value;

    String feedback = value ? "Guardado en la nube activado." : "Guardado en la nube desactivado.";

    if (value == true && previousValue == false) {
      if (Supabase.instance.client.auth.currentUser == null) {
        await _prefs.setBool(cloudSavePreferenceKey, false); // Revertir
        _saveToCloudEnabled = false;
        _setProcessing(false);
        return "Debes iniciar sesión para activar el guardado en la nube.";
      }
      feedback = await performInitialSupabaseSync(showInProgressMessage: true);
    }
    _setProcessing(false);
    return feedback;
  }

  Future<String> performInitialSupabaseSync({bool showInProgressMessage = false}) async {
    if (Supabase.instance.client.auth.currentUser == null) {
      return 'Debes iniciar sesión para sincronizar.';
    }
    if(showInProgressMessage) _setStatus('Iniciando sincronización...');
    _setProcessing(true);

    int successCount = 0;
    int errorCount = 0;
    String resultMessage = "";

    try {
      final mealLogsToSync = await _logRepository.getAllMealLogsMappedByKey();
      final overnightLogsToSync = await _logRepository.getAllOvernightLogsMappedByKey();

      for (var entry in mealLogsToSync.entries) {
        try {
          await _logSyncService.syncMealLog(entry.value, entry.key);
          successCount++;
        } catch (e) { debugPrint("SettingsVM: Error syncing MealLog key ${entry.key}: $e"); errorCount++; }
      }
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
      _setStatus(resultMessage);
      _setProcessing(false);
    }
    return resultMessage;
  }

  Future<String> importDataFromCloud(CloudImportStrategy strategy) async {
    if (Supabase.instance.client.auth.currentUser == null) {
      return 'Debes iniciar sesión para importar desde la nube.';
    }
    _setStatus('Iniciando importación (${getStrategyText(strategy)})...');
    _setProcessing(true);

    int mealLogsImported = 0;
    int overnightLogsImported = 0;
    String resultMessage = "";

    try {
      if (strategy == CloudImportStrategy.overwrite) {
        await _logRepository.clearAllLocalMealLogs();
        await _logRepository.clearAllLocalOvernightLogs();
      }

      final mealLogsFromCloud = await _logSyncService.fetchMealLogsFromSupabase();
      for (final syncedLog in mealLogsFromCloud) {
        await _logRepository.saveMealLog(syncedLog.log, syncedLog.hiveKey);
        mealLogsImported++;
      }

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

  Future<String> deleteLogData(DeleteDataScope scope) async {
    _setStatus('Borrando datos...');
    _setProcessing(true);
    String successMessage = "Datos borrados exitosamente.";
    String? locationMessage;
    String resultMessage = "";

    try {
      if (scope == DeleteDataScope.localOnly || scope == DeleteDataScope.both) {
        await _logRepository.clearAllLocalMealLogs();
        await _logRepository.clearAllLocalOvernightLogs();
        locationMessage = "locales";
      }

      if (scope == DeleteDataScope.cloudOnly || scope == DeleteDataScope.both) {
        if (Supabase.instance.client.auth.currentUser == null) {
          throw Exception("Debes iniciar sesión para borrar datos de la nube.");
        }
        await _logSyncService.deleteAllUserMealLogsFromSupabase();
        await _logSyncService.deleteAllUserOvernightLogsFromSupabase();
        locationMessage = (locationMessage != null) ? (locationMessage + " y de la nube") : "de la nube";
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