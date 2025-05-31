// lib/features/settings/presentation/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:diabetes_2/core/layout/main_layout.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
// import 'package:diabetes_2/core/theme/theme_provider.dart'; // Se accede via ViewModel
// import 'package:shared_preferences/shared_preferences.dart'; // Se accede via ViewModel
// import 'package:hive/hive.dart'; // No necesario
// import 'package:diabetes_2/data/models/logs/logs.dart'; // No necesario
// import 'package:diabetes_2/main.dart' show mealLogBoxName, overnightLogBoxName, supabase; // No necesario para cajas o supabase directamente
// import 'package:diabetes_2/core/services/supabase_log_sync_service.dart'; // Se accede via ViewModel
// import 'package:diabetes_2/data/repositories/log_repository.dart'; // Se accede via ViewModel

import 'package:diabetes_2/features/settings/presentation/settings_view_model.dart'; // Importar ViewModel

// Los Enums y helpers (_getStrategyText, etc.) ahora están en el ViewModel
// o podrían estar en un archivo de utilidades de esta feature.
// Si están en el ViewModel, no se necesitan aquí. Si son globales, importarlos.


class SettingsScreen extends StatelessWidget { // Convertido a StatelessWidget
  const SettingsScreen({super.key});

  // Los métodos para mostrar diálogos se mantienen aquí, pero las acciones llaman al ViewModel
  void _showThemeDialog(BuildContext context, SettingsViewModel viewModel) {
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
                groupValue: viewModel.themeProvider.themeMode, // Usar del ViewModel
                onChanged: viewModel.isProcessingData ? null : (ThemeMode? value) {
                  if (value != null) viewModel.themeProvider.setThemeMode(value); // Usar del ViewModel
                  Navigator.of(dialogContext).pop();
                },
                activeColor: Theme.of(context).colorScheme.primary,
              );
            }).toList(),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: viewModel.isProcessingData ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  void _showCloudSaveDialog(BuildContext context, SettingsViewModel viewModel) {
    showDialog(
      context: context,
      barrierDismissible: !viewModel.isProcessingData,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(viewModel.isProcessingData ? 'Procesando...' : 'Guardar datos en la nube'),
          content: viewModel.isProcessingData
              ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height:16), Text("Por favor, espera...")]))
              : Text(
              viewModel.saveToCloudEnabled
                  ? '¿Deseas desactivar el guardado de datos en la nube?'
                  : '¿Deseas activar el guardado de datos en la nube?'
          ),
          actions: <Widget>[
            TextButton(
              onPressed: viewModel.isProcessingData ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: viewModel.isProcessingData ? null : () async {
                Navigator.of(dialogContext).pop(); // Cerrar diálogo primero
                String message = await viewModel.updateCloudSavePreference(!viewModel.saveToCloudEnabled);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(message),
                      backgroundColor: message.toLowerCase().contains("error") || message.toLowerCase().contains("debes iniciar sesión")
                          ? Colors.orange
                          : Colors.green));
                }
              },
              child: Text(viewModel.saveToCloudEnabled ? 'Desactivar' : 'Activar'),
            ),
          ],
        );
      },
    );
  }

  void _showCloudImportDialog(BuildContext context, SettingsViewModel viewModel) {
    CloudImportStrategy? selectedStrategy = CloudImportStrategy.merge; // Default

    showDialog(
      context: context,
      barrierDismissible: !viewModel.isProcessingData,
      builder: (BuildContext dialogContext) {
        // Usar StatefulBuilder para el estado local del diálogo (selectedStrategy)
        return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(viewModel.isProcessingData ? 'Importando...' : 'Importar datos desde la nube'),
                content: viewModel.isProcessingData
                    ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height:16), Text("Importando datos...")]))
                    : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('Selecciona cómo deseas importar los datos:'),
                    const SizedBox(height: 16),
                    ...CloudImportStrategy.values.map((strategy) {
                      return RadioListTile<CloudImportStrategy>(
                        title: Text(getStrategyText(strategy)), // Usar helper local o del VM
                        value: strategy,
                        groupValue: selectedStrategy,
                        onChanged: (CloudImportStrategy? value) {
                          if (value != null) setDialogState(() { selectedStrategy = value; });
                        },
                        activeColor: Theme.of(context).colorScheme.primary,
                      );
                    }),
                    const SizedBox(height: 8),
                    if (selectedStrategy == CloudImportStrategy.overwrite)
                      Text('Advertencia: Sobrescribir eliminará TODOS los datos locales de registros.', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error)),
                  ],
                ),
                actions: <Widget>[
                  TextButton(onPressed: viewModel.isProcessingData ? null : () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
                  TextButton(
                    onPressed: viewModel.isProcessingData ? null : () async {
                      if (selectedStrategy == null) return;
                      Navigator.of(dialogContext).pop();
                      String message = await viewModel.importDataFromCloud(selectedStrategy!);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(message),
                            backgroundColor: message.toLowerCase().contains("error") ? Colors.red : Colors.green));
                      }
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

  void _showDeleteDataDialog(BuildContext context, SettingsViewModel viewModel) {
    DeleteDataScope? selectedScope = DeleteDataScope.localOnly; // Default
    bool confirmedFirstStep = false;

    showDialog(
      context: context,
      barrierDismissible: !viewModel.isProcessingData,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          if (viewModel.isProcessingData && confirmedFirstStep) { // Solo mostrar loader si ya se confirmó
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
                    title: Text(getDeleteScopeText(scope)), // Usar helper local o del VM
                    value: scope,
                    groupValue: selectedScope,
                    onChanged: (DeleteDataScope? value) {
                      if (value != null) setDialogState(() { selectedScope = value; });
                    },
                    activeColor: Theme.of(context).colorScheme.primary,
                  );
                }).toList(),
              ),
              actions: <Widget>[
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
                TextButton(onPressed: () => setDialogState(() { confirmedFirstStep = true; }), child: const Text('Siguiente')),
              ],
            );
          } else {
            // ... (Lógica del diálogo de confirmación final sin cambios, llama a viewModel.deleteLogData)
            String scopeText = getDeleteScopeText(selectedScope!);
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
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    String message = await viewModel.deleteLogData(selectedScope!);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(message),
                          backgroundColor: message.toLowerCase().contains("error") ? Colors.red : Colors.green));
                    }
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
    // Usar context.watch para que la UI se reconstruya cuando cambien los datos del ViewModel
    final viewModel = context.watch<SettingsViewModel>();

    return MainLayout(
      title: 'Ajustes',
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Icon(Icons.brightness_6_outlined, color: theme.colorScheme.primary),
              title: Text('Tema de la Aplicación', style: theme.textTheme.titleMedium),
              subtitle: Text(viewModel.themeProvider.currentThemeModeName, style: theme.textTheme.bodySmall), // Acceder via viewModel
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              onTap: viewModel.isProcessingData ? null : () => _showThemeDialog(context, viewModel),
            ),
          ),
          const SizedBox(height: 16),
          Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: viewModel.isProcessingData && (viewModel.operationStatus.contains("Subiendo") || viewModel.operationStatus.contains("sincronización"))
                  ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary))
                  : Icon(Icons.cloud_upload_outlined, color: theme.colorScheme.primary),
              title: Text('Guardar datos en la nube', style: theme.textTheme.titleMedium),
              subtitle: Text(viewModel.isProcessingData ? viewModel.operationStatus : (viewModel.saveToCloudEnabled ? 'Activado' : 'Desactivado'), style: theme.textTheme.bodySmall),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              onTap: viewModel.isProcessingData ? null : () => _showCloudSaveDialog(context, viewModel),
            ),
          ),
          const SizedBox(height: 16),
          Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: viewModel.isProcessingData && viewModel.operationStatus.contains("Importando")
                  ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary))
                  : Icon(Icons.cloud_download_outlined, color: theme.colorScheme.primary),
              title: Text('Importar datos desde la nube', style: theme.textTheme.titleMedium),
              subtitle: Text(viewModel.isProcessingData && viewModel.operationStatus.contains("Importando") ? viewModel.operationStatus : 'Fusionar o sobrescribir datos locales', style: theme.textTheme.bodySmall),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              onTap: viewModel.isProcessingData ? null : () => _showCloudImportDialog(context, viewModel),
            ),
          ),
          const SizedBox(height: 16),
          Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: viewModel.isProcessingData && viewModel.operationStatus.contains("Borrando")
                  ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.error))
                  : Icon(Icons.delete_sweep_outlined, color: theme.colorScheme.error),
              title: Text('Borrar Datos de Registros', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error)),
              subtitle: Text(viewModel.isProcessingData && viewModel.operationStatus.contains("Borrando") ? viewModel.operationStatus : 'Eliminar datos locales y/o en la nube', style: theme.textTheme.bodySmall),
              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 18, color: theme.colorScheme.error),
              onTap: viewModel.isProcessingData ? null : () => _showDeleteDataDialog(context, viewModel),
            ),
          ),
          const SizedBox(height: 16),
          Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Icon(Icons.account_circle_outlined, color: theme.colorScheme.primary),
              title: Text('Cuenta', style: theme.textTheme.titleMedium),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              onTap: viewModel.isProcessingData ? null : () => context.push('/account'),
            ),
          ),
          const SizedBox(height: 16),
          Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
              title: Text('Acerca de la App', style: theme.textTheme.titleMedium),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              onTap: viewModel.isProcessingData ? null : () {
                showAboutDialog(context: context, applicationName: 'Diabetes App', applicationVersion: '1.0.0',
                  applicationLegalese: '© ${DateTime.now().year} Marcos Plaza Piqueras',
                  children: <Widget>[Padding(padding: const EdgeInsets.only(top: 20, left: 10, right: 10), child: const Text('Esta es una aplicación pensada para ayudar a las personas con diabetes.', textAlign: TextAlign.center,))],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}