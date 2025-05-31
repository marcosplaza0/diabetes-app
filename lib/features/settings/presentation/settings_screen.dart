// Archivo: lib/features/settings/presentation/settings_screen.dart
// Descripción: Define la interfaz de usuario para la pantalla de Ajustes de la aplicación.
// Permite al usuario configurar opciones como el tema de la aplicación, el guardado en la nube,
// la importación/exportación de datos y el borrado de datos. También proporciona acceso
// a la pantalla de la cuenta y a la información "Acerca de".
// Esta pantalla interactúa con SettingsViewModel para la lógica y el estado.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:flutter/material.dart'; // Framework principal de Flutter para UI.
import 'package:go_router/go_router.dart'; // Para la navegación (ej. a la pantalla de cuenta).
import 'package:provider/provider.dart'; // Para acceder al SettingsViewModel.

// Importaciones de archivos del proyecto
import 'package:DiabetiApp/core/layout/main_layout.dart'; // Widget de diseño principal de la pantalla.
import 'package:DiabetiApp/features/settings/presentation/settings_view_model.dart'; // ViewModel para esta pantalla.

/// SettingsScreen: Un StatelessWidget que construye la UI para la pantalla de Ajustes.
///
/// La lógica de estado y las operaciones se delegan a `SettingsViewModel`.
/// La pantalla se compone de una lista de opciones de configuración, cada una
/// típicamente presentada en un `ListTile` dentro de un `Card`.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // --- Métodos para mostrar diálogos de configuración ---
  // Estos métodos construyen y muestran diálogos para interactuar con configuraciones específicas.
  // Toman el BuildContext y el SettingsViewModel como parámetros para acceder al estado actual
  // y para invocar métodos del ViewModel que realizan las acciones.

  /// _showThemeDialog: Muestra un diálogo para seleccionar el tema de la aplicación.
  ///
  /// Permite al usuario elegir entre tema claro, oscuro o el predeterminado del sistema.
  /// La selección se actualiza a través del `themeProvider` en el `SettingsViewModel`.
  void _showThemeDialog(BuildContext context, SettingsViewModel viewModel) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Seleccionar Tema'),
          content: Column(
            mainAxisSize: MainAxisSize.min, // El diálogo ocupa el mínimo espacio vertical.
            children: ThemeMode.values.map((mode) { // Itera sobre todos los valores de ThemeMode.
              String modeText; // Texto descriptivo para cada modo.
              switch (mode) {
                case ThemeMode.light: modeText = 'Claro'; break;
                case ThemeMode.dark: modeText = 'Oscuro'; break;
                case ThemeMode.system: modeText = 'Predeterminado del sistema'; break;
              }
              return RadioListTile<ThemeMode>(
                title: Text(modeText),
                value: mode, // Valor del modo actual.
                groupValue: viewModel.themeProvider.themeMode, // Modo actualmente seleccionado en el ViewModel. //
                // Deshabilita la opción si el ViewModel está procesando otra operación.
                onChanged: viewModel.isProcessingData ? null : (ThemeMode? value) { //
                  if (value != null) viewModel.themeProvider.setThemeMode(value); // Actualiza el tema en el ViewModel. //
                  Navigator.of(dialogContext).pop(); // Cierra el diálogo.
                },
                activeColor: Theme.of(context).colorScheme.primary, // Color del radio button cuando está activo.
              );
            }).toList(),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: viewModel.isProcessingData ? null : () => Navigator.of(dialogContext).pop(), //
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }

  /// _showCloudSaveDialog: Muestra un diálogo para activar/desactivar el guardado en la nube.
  ///
  /// Muestra un indicador de progreso si el ViewModel está procesando.
  /// Llama a `updateCloudSavePreference` en el ViewModel al confirmar.
  void _showCloudSaveDialog(BuildContext context, SettingsViewModel viewModel) {
    showDialog(
      context: context,
      barrierDismissible: !viewModel.isProcessingData, // No se puede cerrar tocando fuera si está procesando. //
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(viewModel.isProcessingData ? 'Procesando...' : 'Guardar datos en la nube'), //
          content: viewModel.isProcessingData // Muestra un loader o el texto de confirmación. //
              ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height:16), Text("Por favor, espera...")]))
              : Text(
              viewModel.saveToCloudEnabled // Texto depende del estado actual del guardado en la nube. //
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
                Navigator.of(dialogContext).pop(); // Cierra el diálogo antes de la operación asíncrona.
                // Llama al método del ViewModel para actualizar la preferencia.
                String message = await viewModel.updateCloudSavePreference(!viewModel.saveToCloudEnabled);
                if (context.mounted) { // Verifica si el widget sigue montado antes de mostrar SnackBar.
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(message),
                      // Color del SnackBar basado en el éxito/error del mensaje.
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

  /// _showCloudImportDialog: Muestra un diálogo para importar datos desde la nube.
  ///
  /// Permite al usuario elegir una estrategia de importación (fusionar o sobrescribir).
  /// Utiliza `StatefulBuilder` para manejar el estado local del diálogo (la estrategia seleccionada).
  /// Llama a `importDataFromCloud` en el ViewModel.
  void _showCloudImportDialog(BuildContext context, SettingsViewModel viewModel) {
    CloudImportStrategy? selectedStrategy = CloudImportStrategy.merge; // Estrategia por defecto. //

    showDialog(
      context: context,
      barrierDismissible: !viewModel.isProcessingData, //
      builder: (BuildContext dialogContext) {
        // StatefulBuilder permite manejar estado local dentro de un diálogo que es parte de un StatelessWidget.
        return StatefulBuilder(
            builder: (context, setDialogState) { // setDialogState para actualizar el estado del diálogo.
              return AlertDialog(
                title: Text(viewModel.isProcessingData ? 'Importando...' : 'Importar datos desde la nube'), //
                content: viewModel.isProcessingData //
                    ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height:16), Text("Importando datos...")]))
                    : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('Selecciona cómo deseas importar los datos:'),
                    const SizedBox(height: 16),
                    // Crea RadioListTiles para cada estrategia de importación.
                    ...CloudImportStrategy.values.map((strategy) { //
                      return RadioListTile<CloudImportStrategy>( //
                        title: Text(getStrategyText(strategy)), // Texto descriptivo de la estrategia. //
                        value: strategy,
                        groupValue: selectedStrategy,
                        onChanged: (CloudImportStrategy? value) { //
                          // Actualiza la estrategia seleccionada usando setDialogState.
                          if (value != null) setDialogState(() { selectedStrategy = value; });
                        },
                        activeColor: Theme.of(context).colorScheme.primary,
                      );
                    }),
                    const SizedBox(height: 8),
                    // Muestra una advertencia si se selecciona sobrescribir.
                    if (selectedStrategy == CloudImportStrategy.overwrite) //
                      Text('Advertencia: Sobrescribir eliminará TODOS los datos locales de registros.', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error)),
                  ],
                ),
                actions: <Widget>[
                  TextButton(onPressed: viewModel.isProcessingData ? null : () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
                  TextButton(
                    onPressed: viewModel.isProcessingData ? null : () async {
                      if (selectedStrategy == null) return; // No hacer nada si no hay estrategia seleccionada.
                      Navigator.of(dialogContext).pop(); // Cierra el diálogo.
                      // Llama al método de importación del ViewModel.
                      String message = await viewModel.importDataFromCloud(selectedStrategy!);
                      if (context.mounted) { // Muestra feedback.
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

  /// _showDeleteDataDialog: Muestra un diálogo de confirmación en dos pasos para borrar datos.
  ///
  /// Primero permite seleccionar el ámbito del borrado (local, nube, ambos).
  /// Luego muestra una confirmación final antes de proceder.
  /// Utiliza `StatefulBuilder` para manejar el estado de los pasos del diálogo.
  /// Llama a `deleteLogData` en el ViewModel.
  void _showDeleteDataDialog(BuildContext context, SettingsViewModel viewModel) {
    DeleteDataScope? selectedScope = DeleteDataScope.localOnly; // Ámbito por defecto. //
    bool confirmedFirstStep = false; // Flag para controlar el paso del diálogo.

    showDialog(
      context: context,
      barrierDismissible: !viewModel.isProcessingData,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          // Muestra un loader si se está procesando y ya se pasó el primer paso.
          if (viewModel.isProcessingData && confirmedFirstStep) {
            return const AlertDialog(
              title: Text("Borrando datos..."),
              content: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text("Por favor, espera...")])),
            );
          }

          // Primer paso: seleccionar el ámbito del borrado.
          if (!confirmedFirstStep) {
            return AlertDialog(
              title: const Text('Borrar Datos de Registros'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: DeleteDataScope.values.map((scope) {
                  return RadioListTile<DeleteDataScope>(
                    title: Text(getDeleteScopeText(scope)), // Texto descriptivo del ámbito. //
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
          } else { // Segundo paso: confirmación final.
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
                    Navigator.of(dialogContext).pop(); // Cierra el diálogo.
                    // Llama al método de borrado del ViewModel.
                    String message = await viewModel.deleteLogData(selectedScope!);
                    if (context.mounted) { // Muestra feedback.
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
  /// build: Construye la interfaz de usuario de la pantalla de Ajustes.
  ///
  /// Muestra una lista de `Card`s, cada una con un `ListTile` para una opción de configuración.
  /// Utiliza `context.watch<SettingsViewModel>()` para que la UI se reconstruya cuando
  /// cambien los datos del ViewModel (ej. `saveToCloudEnabled`, `isProcessingData`).
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // `context.watch` se suscribe a los cambios del ViewModel.
    final viewModel = context.watch<SettingsViewModel>();

    return MainLayout(
      title: 'Ajustes', // Título de la AppBar.
      body: ListView( // Permite el desplazamiento si hay muchas opciones.
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          // Opción: Tema de la Aplicación
          Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Icon(Icons.brightness_6_outlined, color: theme.colorScheme.primary),
              title: Text('Tema de la Aplicación', style: theme.textTheme.titleMedium),
              subtitle: Text(viewModel.themeProvider.currentThemeModeName, style: theme.textTheme.bodySmall), // Muestra el nombre del tema actual. //
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              onTap: viewModel.isProcessingData ? null : () => _showThemeDialog(context, viewModel), // Muestra el diálogo de tema. //
            ),
          ),
          const SizedBox(height: 16),

          // Opción: Guardar datos en la nube
          Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: viewModel.isProcessingData && (viewModel.operationStatus.contains("Subiendo") || viewModel.operationStatus.contains("sincronización"))
                  ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary)) // Loader si está sincronizando.
                  : Icon(Icons.cloud_upload_outlined, color: theme.colorScheme.primary),
              title: Text('Guardar datos en la nube', style: theme.textTheme.titleMedium),
              subtitle: Text(viewModel.isProcessingData ? viewModel.operationStatus : (viewModel.saveToCloudEnabled ? 'Activado' : 'Desactivado'), style: theme.textTheme.bodySmall), // Muestra estado o mensaje de operación. //
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              onTap: viewModel.isProcessingData ? null : () => _showCloudSaveDialog(context, viewModel), // Muestra diálogo de guardado en nube. //
            ),
          ),
          const SizedBox(height: 16),

          // Opción: Importar datos desde la nube
          Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: viewModel.isProcessingData && viewModel.operationStatus.contains("Importando")
                  ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary)) // Loader si está importando.
                  : Icon(Icons.cloud_download_outlined, color: theme.colorScheme.primary),
              title: Text('Importar datos desde la nube', style: theme.textTheme.titleMedium),
              subtitle: Text(viewModel.isProcessingData && viewModel.operationStatus.contains("Importando") ? viewModel.operationStatus : 'Fusionar o sobrescribir datos locales', style: theme.textTheme.bodySmall),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              onTap: viewModel.isProcessingData ? null : () => _showCloudImportDialog(context, viewModel), // Muestra diálogo de importación. //
            ),
          ),
          const SizedBox(height: 16),

          // Opción: Borrar Datos de Registros
          Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: viewModel.isProcessingData && viewModel.operationStatus.contains("Borrando")
                  ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.error)) // Loader si está borrando.
                  : Icon(Icons.delete_sweep_outlined, color: theme.colorScheme.error),
              title: Text('Borrar Datos de Registros', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error)),
              subtitle: Text(viewModel.isProcessingData && viewModel.operationStatus.contains("Borrando") ? viewModel.operationStatus : 'Eliminar datos locales y/o en la nube', style: theme.textTheme.bodySmall),
              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 18, color: theme.colorScheme.error),
              onTap: viewModel.isProcessingData ? null : () => _showDeleteDataDialog(context, viewModel), // Muestra diálogo de borrado. //
            ),
          ),
          const SizedBox(height: 16),

          // Opción: Cuenta (navega a la pantalla de perfil/cuenta)
          Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Icon(Icons.account_circle_outlined, color: theme.colorScheme.primary),
              title: Text('Cuenta', style: theme.textTheme.titleMedium),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              onTap: viewModel.isProcessingData ? null : () => context.push('/account'), // Navega a '/account'. //
            ),
          ),
          const SizedBox(height: 16),

          // Opción: Acerca de la App
          Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
              title: Text('Acerca de la App', style: theme.textTheme.titleMedium),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              onTap: viewModel.isProcessingData ? null : () {
                // Muestra el diálogo estándar "Acerca de".
                showAboutDialog(
                  context: context,
                  applicationName: 'Diabetes App', // Nombre de la aplicación.
                  applicationVersion: '1.0.0', // Versión.
                  applicationLegalese: '© ${DateTime.now().year} Marcos Plaza Piqueras', // Información legal/copyright.
                  children: <Widget>[ // Contenido adicional para el diálogo.
                    Padding(
                        padding: const EdgeInsets.only(top: 20, left: 10, right: 10),
                        child: const Text('Esta es una aplicación pensada para ayudar a las personas con diabetes.', textAlign: TextAlign.center,)
                    )
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}