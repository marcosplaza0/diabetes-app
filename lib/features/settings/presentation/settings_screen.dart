// lib/features/settings/presentation/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:diabetes_2/core/layout/main_layout.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:diabetes_2/core/theme/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// import 'package:hive/hive.dart'; // No para Box directamente
// import 'package:diabetes_2/data/models/logs/logs.dart'; // No para modelos directamente aquí
// import 'package:diabetes_2/main.dart' show mealLogBoxName, overnightLogBoxName, supabase; // No para nombres de cajas
import 'package:diabetes_2/main.dart' show supabase; // Solo para supabase client
import 'package:diabetes_2/core/services/supabase_log_sync_service.dart';
import 'package:diabetes_2/data/repositories/log_repository.dart'; // Importar el repositorio

enum CloudImportStrategy { merge, overwrite }
String _getStrategyText(CloudImportStrategy strategy) =>
    strategy == CloudImportStrategy.merge ? 'Juntar con datos locales' : 'Sobrescribir datos locales';

enum DeleteDataScope { localOnly, cloudOnly, both }
String _getDeleteScopeText(DeleteDataScope scope) {
  switch (scope) {
    case DeleteDataScope.localOnly: return 'Sólo datos locales';
    case DeleteDataScope.cloudOnly: return 'Sólo datos en la nube';
    case DeleteDataScope.both: return 'Ambos (local y nube)';
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _saveToCloudEnabled = false;
  static const String _cloudSavePreferenceKey = 'saveToCloudEnabled';
  bool _isProcessingData = false;

  late SupabaseLogSyncService _logSyncService; // Mantener para operaciones de Supabase no cubiertas por LogRepository (ej. fetch/delete all)
  late LogRepository _logRepository;
  // Ya no se necesitan las cajas directamente
  // late Box<MealLog> _mealLogBox;
  // late Box<OvernightLog> _overnightLogBox;

  @override
  void initState() {
    super.initState();
    _logRepository = Provider.of<LogRepository>(context, listen: false);
    _logSyncService = Provider.of<SupabaseLogSyncService>(context, listen: false);
    // _mealLogBox = Hive.box<MealLog>(mealLogBoxName); // No necesario
    // _overnightLogBox = Hive.box<OvernightLog>(overnightLogBoxName); // No necesario
    _loadCloudPreference();
  }

  Future<void> _loadCloudPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() { _saveToCloudEnabled = prefs.getBool(_cloudSavePreferenceKey) ?? false; });
    }
  }

  Future<void> _saveCloudPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final bool previousValue = prefs.getBool(_cloudSavePreferenceKey) ?? false;
    await prefs.setBool(_cloudSavePreferenceKey, value);
    if (mounted) setState(() { _saveToCloudEnabled = value; });
    if (value == true && previousValue == false) _performInitialSupabaseSync();
  }

  Future<void> _performInitialSupabaseSync() async {
    if (supabase.auth.currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debes iniciar sesión para guardar en la nube.'), backgroundColor: Colors.orange));
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_cloudSavePreferenceKey, false);
        if (mounted) setState(() { _saveToCloudEnabled = false; });
      }
      return;
    }
    if (mounted) setState(() { _isProcessingData = true; });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Iniciando sincronización con la nube...'), duration: Duration(seconds: 2)));

    int successCount = 0; int errorCount = 0;
    try {
      // Usar el repositorio para obtener todos los logs
      final mealLogsToSync = await _logRepository.getAllMealLogsMappedByKey();
      final overnightLogsToSync = await _logRepository.getAllOvernightLogsMappedByKey();

      for (var entry in mealLogsToSync.entries) {
        try {
          await _logSyncService.syncMealLog(entry.value, entry.key); successCount++;
        } catch (e) { debugPrint("Error syncing MealLog key ${entry.key}: $e"); errorCount++; }
      }
      for (var entry in overnightLogsToSync.entries) {
        try {
          await _logSyncService.syncOvernightLog(entry.value, entry.key); successCount++;
        } catch (e) { debugPrint("Error syncing OvernightLog key ${entry.key}: $e"); errorCount++; }
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sincronización inicial completada. Éxitos: $successCount, Errores: $errorCount'), backgroundColor: errorCount > 0 ? Colors.orange : Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error durante la sincronización inicial: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isProcessingData = false; });
    }
  }

  Future<void> _handleCloudImport(CloudImportStrategy strategy) async {
    if (supabase.auth.currentUser == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debes iniciar sesión para importar desde la nube.'), backgroundColor: Colors.orange));
      return;
    }
    if (mounted) setState(() { _isProcessingData = true; });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Iniciando importación (${_getStrategyText(strategy)})...')));

    int mealLogsImported = 0; int overnightLogsImported = 0;
    try {
      if (strategy == CloudImportStrategy.overwrite) {
        debugPrint("Importación: Estrategia Sobrescribir. Limpiando logs locales via repo.");
        await _logRepository.clearAllLocalMealLogs();
        await _logRepository.clearAllLocalOvernightLogs();
        debugPrint("Importación: Logs locales limpiados.");
      }

      final mealLogsFromCloud = await _logSyncService.fetchMealLogsFromSupabase();
      for (final syncedLog in mealLogsFromCloud) {
        // Usar el repositorio para guardar. El repo decidirá si sincronizar de vuelta (en este caso, no debería si la lógica es de solo guardar local)
        // Sin embargo, la implementación actual de saveMealLog en el repo SÍ intentará sincronizar.
        // Para una importación pura, el método save del repo podría tener un flag opcional `syncToCloud: false`.
        // Por ahora, funcionará como un upsert en Supabase si la nube está activa.
        await _logRepository.saveMealLog(syncedLog.log, syncedLog.hiveKey);
        mealLogsImported++;
      }
      debugPrint("Importación: $mealLogsImported MealLogs importados/actualizados via repo.");

      final overnightLogsFromCloud = await _logSyncService.fetchOvernightLogsFromSupabase();
      for (final syncedLog in overnightLogsFromCloud) {
        await _logRepository.saveOvernightLog(syncedLog.log, syncedLog.hiveKey);
        overnightLogsImported++;
      }
      debugPrint("Importación: $overnightLogsImported OvernightLogs importados/actualizados via repo.");

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Importación completada. Comidas: $mealLogsImported, Noches: $overnightLogsImported.'), backgroundColor: Colors.green));
    } catch (e) {
      debugPrint("Error durante la importación desde la nube: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al importar: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isProcessingData = false; });
    }
  }

  Future<void> _handleActualDeletion(DeleteDataScope scope) async {
    if (mounted) setState(() { _isProcessingData = true; });
    String successMessage = "Datos borrados exitosamente."; String? locationMessage;
    try {
      if (scope == DeleteDataScope.localOnly || scope == DeleteDataScope.both) {
        await _logRepository.clearAllLocalMealLogs();
        await _logRepository.clearAllLocalOvernightLogs();
        locationMessage = "locales";
        debugPrint("Borrado: Datos locales de logs eliminados via repo.");
      }
      if (scope == DeleteDataScope.cloudOnly || scope == DeleteDataScope.both) {
        if (supabase.auth.currentUser == null) throw Exception("Debes iniciar sesión para borrar datos de la nube.");
        await _logSyncService.deleteAllUserMealLogsFromSupabase();
        await _logSyncService.deleteAllUserOvernightLogsFromSupabase();
        locationMessage = (locationMessage != null) ? (locationMessage + " y de la nube") : "de la nube";
        debugPrint("Borrado: Datos de logs en la nube eliminados.");
      }
      if (locationMessage != null) successMessage = "Datos $locationMessage borrados exitosamente.";
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage), backgroundColor: Colors.green));
    } catch (e) {
      debugPrint("Error durante el borrado de datos ($scope): $e");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al borrar datos: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isProcessingData = false; });
    }
  }

  // _showThemeDialog, _showCloudSaveDialog, _showCloudImportDialog, _showDeleteDataDialog se mantienen sin cambios estructurales internos,
  // solo que ahora los handlers (_handleCloudImport, _handleActualDeletion, etc.) usan _logRepository.

  void _showThemeDialog(BuildContext context, ThemeProvider themeProvider) { /* ... (sin cambios) ... */
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Seleccionar Tema'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ThemeMode.values.map((mode) {
              String modeText;
              switch (mode) {
                case ThemeMode.light: modeText = 'Claro'; break;
                case ThemeMode.dark: modeText = 'Oscuro'; break;
                case ThemeMode.system: modeText = 'Predeterminado del sistema'; break;
              }
              return RadioListTile<ThemeMode>(
                title: Text(modeText),
                value: mode,
                groupValue: themeProvider.themeMode,
                onChanged: _isProcessingData ? null : (ThemeMode? value) {
                  if (value != null) themeProvider.setThemeMode(value);
                  Navigator.of(dialogContext).pop();
                },
                activeColor: Theme.of(context).colorScheme.primary,
              );
            }).toList(),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: _isProcessingData ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  void _showCloudSaveDialog(BuildContext context) { /* ... (sin cambios) ... */
    showDialog(
      context: context,
      barrierDismissible: !_isProcessingData,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(_isProcessingData ? 'Procesando...' : 'Guardar datos en la nube'),
          content: _isProcessingData
              ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height:16), Text("Por favor, espera...")]))
              : Text(
              _saveToCloudEnabled
                  ? '¿Deseas desactivar el guardado de datos en la nube?'
                  : '¿Deseas activar el guardado de datos en la nube?'
          ),
          actions: <Widget>[
            TextButton(
              onPressed: _isProcessingData ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: _isProcessingData ? null : () {
                _saveCloudPreference(!_saveToCloudEnabled);
                Navigator.of(dialogContext).pop();
              },
              child: Text(_saveToCloudEnabled ? 'Desactivar' : 'Activar'),
            ),
          ],
        );
      },
    );
  }

  void _showCloudImportDialog(BuildContext context) { /* ... (sin cambios) ... */
    CloudImportStrategy? selectedStrategy = CloudImportStrategy.merge;

    showDialog(
      context: context,
      barrierDismissible: !_isProcessingData,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(_isProcessingData ? 'Importando...' : 'Importar datos desde la nube'),
                content: _isProcessingData
                    ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height:16), Text("Importando datos...")]))
                    : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('Selecciona cómo deseas importar los datos:'),
                    const SizedBox(height: 16),
                    ...CloudImportStrategy.values.map((strategy) {
                      return RadioListTile<CloudImportStrategy>(
                        title: Text(_getStrategyText(strategy)),
                        value: strategy,
                        groupValue: selectedStrategy,
                        onChanged: (CloudImportStrategy? value) {
                          if (value != null) {
                            setDialogState(() { selectedStrategy = value; });
                          }
                        },
                        activeColor: Theme.of(context).colorScheme.primary,
                      );
                    }),
                    const SizedBox(height: 8),
                    if (selectedStrategy == CloudImportStrategy.overwrite)
                      Text(
                        'Advertencia: Sobrescribir eliminará TODOS los datos locales de registros.',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error),
                      ),
                  ],
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: _isProcessingData ? null : () {
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: _isProcessingData ? null : () {
                      if (selectedStrategy == null) return;
                      Navigator.of(dialogContext).pop();
                      _handleCloudImport(selectedStrategy!); // Ya usa el repo
                    },
                    child: const Text('Importar'),
                  ),
                ],
              );
            }
        );
      },
    );
  }

  void _showDeleteDataDialog(BuildContext context) { /* ... (sin cambios) ... */
    DeleteDataScope? selectedScope = DeleteDataScope.localOnly;
    bool confirmedFirstStep = false;

    showDialog(
      context: context,
      barrierDismissible: !_isProcessingData,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          if (_isProcessingData) {
            return const AlertDialog(
              title: Text("Borrando datos..."),
              content: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text("Por favor, espera...")])),
            );
          }

          if (!confirmedFirstStep) {
            return AlertDialog(
              title: const Text('Borrar Datos de Registros'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: DeleteDataScope.values.map((scope) {
                  return RadioListTile<DeleteDataScope>(
                    title: Text(_getDeleteScopeText(scope)),
                    value: scope,
                    groupValue: selectedScope,
                    onChanged: (DeleteDataScope? value) {
                      if (value != null) {
                        setDialogState(() { selectedScope = value; });
                      }
                    },
                    activeColor: Theme.of(context).colorScheme.primary,
                  );
                }).toList(),
              ),
              actions: <Widget>[
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
                TextButton(
                  onPressed: () {
                    setDialogState(() { confirmedFirstStep = true; });
                  },
                  child: const Text('Siguiente'),
                ),
              ],
            );
          } else {
            String scopeText = _getDeleteScopeText(selectedScope!);
            String warningMessage = "Esta acción es IRREVERSIBLE y borrará permanentemente tus registros";
            if (selectedScope == DeleteDataScope.localOnly) warningMessage += " locales.";
            else if (selectedScope == DeleteDataScope.cloudOnly) warningMessage += " de la nube (si el guardado en nube está activo).";
            else warningMessage += " locales Y de la nube (si el guardado en nube está activo).";

            return AlertDialog(
              title: Text('¡CONFIRMACIÓN FINAL!', style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold)),
              content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Vas a borrar: $scopeText."), const SizedBox(height: 10),
                Text(warningMessage, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 10),
                const Text("¿Estás absolutamente seguro de continuar?"),
              ]),
              actions: <Widget>[
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('NO, CANCELAR')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: Theme.of(context).colorScheme.onError),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _handleActualDeletion(selectedScope!); // Ya usa el repo
                  },
                  child: const Text('SÍ, BORRAR DATOS'),
                ),
              ],
            );
          }
        });
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MainLayout(
      title: 'Ajustes',
      body: ListView(padding: const EdgeInsets.all(16.0), children: <Widget>[
        Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Icon(Icons.brightness_6_outlined, color: theme.colorScheme.primary),
            title: Text('Tema de la Aplicación', style: theme.textTheme.titleMedium),
            subtitle: Text(themeProvider.currentThemeModeName, style: theme.textTheme.bodySmall),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            onTap: _isProcessingData ? null : () => _showThemeDialog(context, themeProvider),
          ),
        ), const SizedBox(height: 16),
        Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: _isProcessingData ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary)) : Icon(Icons.cloud_upload_outlined, color: theme.colorScheme.primary),
            title: Text('Guardar datos en la nube', style: theme.textTheme.titleMedium),
            subtitle: Text(_isProcessingData ? 'Procesando...' : (_saveToCloudEnabled ? 'Activado' : 'Desactivado'), style: theme.textTheme.bodySmall),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            onTap: _isProcessingData ? null : () => _showCloudSaveDialog(context),
          ),
        ), const SizedBox(height: 16),
        Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: _isProcessingData ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary)) : Icon(Icons.cloud_download_outlined, color: theme.colorScheme.primary),
            title: Text('Importar datos desde la nube', style: theme.textTheme.titleMedium),
            subtitle: Text(_isProcessingData ? 'Procesando...' : 'Fusionar o sobrescribir datos locales', style: theme.textTheme.bodySmall),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            onTap: _isProcessingData ? null : () => _showCloudImportDialog(context),
          ),
        ), const SizedBox(height: 16),
        Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Icon(Icons.delete_sweep_outlined, color: _isProcessingData ? theme.disabledColor : theme.colorScheme.error),
            title: Text('Borrar Datos de Registros', style: theme.textTheme.titleMedium?.copyWith(color: _isProcessingData ? theme.disabledColor : theme.colorScheme.error)),
            subtitle: Text(_isProcessingData ? 'Procesando...' : 'Eliminar datos locales y/o en la nube', style: theme.textTheme.bodySmall),
            trailing: Icon(Icons.arrow_forward_ios_rounded, size: 18, color: _isProcessingData ? theme.disabledColor : theme.colorScheme.error),
            onTap: _isProcessingData ? null : () => _showDeleteDataDialog(context),
          ),
        ), const SizedBox(height: 16),
        Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Icon(Icons.account_circle_outlined, color: theme.colorScheme.primary),
            title: Text('Cuenta', style: theme.textTheme.titleMedium),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            onTap: _isProcessingData ? null : () => context.push('/account'),
          ),
        ), const SizedBox(height: 16),
        Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
            title: Text('Acerca de la App', style: theme.textTheme.titleMedium),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            onTap: _isProcessingData ? null : () {
              showAboutDialog(context: context, applicationName: 'Diabetes App', applicationVersion: '1.0.0',
                applicationLegalese: '© ${DateTime.now().year} Marcos Plaza Piqueras',
                children: <Widget>[Padding(padding: const EdgeInsets.only(top: 20, left: 10, right: 10), child: const Text('Esta es una aplicación pensada para ayudar a las personas con diabetes.', textAlign: TextAlign.center,))],
              );
            },
          ),
        ),
      ]),
    );
  }
}