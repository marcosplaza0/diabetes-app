// Archivo: settings_screen.dart
import 'package:flutter/material.dart';
import 'package:diabetes_2/core/layout/main_layout.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:diabetes_2/core/theme/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Enum para las estrategias de importación
enum CloudImportStrategy {
  merge,
  overwrite,
}

// Helper para obtener el texto descriptivo de la estrategia
String _getStrategyText(CloudImportStrategy strategy) {
  switch (strategy) {
    case CloudImportStrategy.merge:
      return 'Juntar con datos locales';
    case CloudImportStrategy.overwrite:
      return 'Sobrescribir datos locales';
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

  @override
  void initState() {
    super.initState();
    _loadCloudPreference();
  }

  Future<void> _loadCloudPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _saveToCloudEnabled = prefs.getBool(_cloudSavePreferenceKey) ?? false;
    });
  }

  Future<void> _saveCloudPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cloudSavePreferenceKey, value);
  }

  void _showThemeDialog(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        // ... (código del diálogo de tema sin cambios)
        return AlertDialog(
          title: const Text('Seleccionar Tema'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ThemeMode.values.map((mode) {
              String modeText;
              switch (mode) {
                case ThemeMode.light:
                  modeText = 'Claro';
                  break;
                case ThemeMode.dark:
                  modeText = 'Oscuro';
                  break;
                case ThemeMode.system:
                  modeText = 'Predeterminado del sistema';
                  break;
              }
              return RadioListTile<ThemeMode>(
                title: Text(modeText),
                value: mode,
                groupValue: themeProvider.themeMode,
                onChanged: (ThemeMode? value) {
                  if (value != null) {
                    themeProvider.setThemeMode(value);
                  }
                  Navigator.of(dialogContext).pop();
                },
                activeColor: Theme.of(context).colorScheme.primary,
              );
            }).toList(),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showCloudSaveDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        // ... (código del diálogo de guardado en la nube sin cambios)
        return AlertDialog(
          title: const Text('Guardar datos en la nube'),
          content: Text(
              _saveToCloudEnabled
                  ? '¿Deseas desactivar el guardado de datos en la nube?'
                  : '¿Deseas activar el guardado de datos en la nube para mantener tu información segura y accesible?'
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: Text(_saveToCloudEnabled ? 'Desactivar' : 'Activar'),
              onPressed: () {
                final newValue = !_saveToCloudEnabled;
                setState(() {
                  _saveToCloudEnabled = newValue;
                });
                _saveCloudPreference(newValue);
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          _saveToCloudEnabled
                              ? 'Guardado en la nube activado.'
                              : 'Guardado en la nube desactivado.'
                      )
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showCloudImportDialog(BuildContext context) {
    CloudImportStrategy? selectedStrategy = CloudImportStrategy.merge; // Valor inicial por defecto

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder( // Usamos StatefulBuilder para manejar el estado del diálogo
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Importar datos desde la nube'),
                content: Column(
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
                            setDialogState(() { // Actualiza el estado del diálogo
                              selectedStrategy = value;
                            });
                          }
                        },
                        activeColor: Theme.of(context).colorScheme.primary,
                      );
                    }),
                    const SizedBox(height: 8),
                    if (selectedStrategy == CloudImportStrategy.overwrite)
                      Text(
                        'Advertencia: Sobrescribir eliminará los datos locales no sincronizados.',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error),
                      ),
                  ],
                ),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Cancelar'),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                  ),
                  TextButton(
                    child: const Text('Importar'),
                    onPressed: () {
                      if (selectedStrategy == null) return; // Nobería pasar si hay valor inicial

                      // TODO: Implementar la lógica real para importar datos desde la nube
                      // usando la estrategia seleccionada: selectedStrategy.
                      String strategyMessage;
                      if (selectedStrategy == CloudImportStrategy.merge) {
                        strategyMessage = "juntando datos...";
                      } else {
                        strategyMessage = "sobrescribiendo datos locales...";
                      }

                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Iniciando importación y $strategyMessage (Función no implementada)')),
                      );
                    },
                  ),
                ],
              );
            }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MainLayout(
      title: 'Ajustes',
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Icon(Icons.brightness_6_outlined, color: theme.colorScheme.primary),
              title: Text('Tema de la Aplicación', style: theme.textTheme.titleMedium),
              subtitle: Text(themeProvider.currentThemeModeName, style: theme.textTheme.bodySmall),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              onTap: () {
                _showThemeDialog(context, themeProvider);
              },
            ),
          ),
          const SizedBox(height: 16),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Icon(Icons.cloud_upload_outlined, color: theme.colorScheme.primary),
              title: Text('Guardar datos en la nube', style: theme.textTheme.titleMedium),
              subtitle: Text(
                  _saveToCloudEnabled ? 'Activado' : 'Desactivado',
                  style: theme.textTheme.bodySmall
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              onTap: () {
                _showCloudSaveDialog(context);
              },
            ),
          ),
          const SizedBox(height: 16),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Icon(Icons.cloud_download_outlined, color: theme.colorScheme.primary),
              title: Text('Importar datos desde la nube', style: theme.textTheme.titleMedium),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              onTap: () {
                _showCloudImportDialog(context);
              },
            ),
          ),
          const SizedBox(height: 16),

          // ... (resto de las opciones de configuración sin cambios)
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Icon(Icons.notifications_outlined, color: theme.colorScheme.primary),
              title: Text('Notificaciones', style: theme.textTheme.titleMedium),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pantalla de notificaciones no implementada.')),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Icon(Icons.account_circle_outlined, color: theme.colorScheme.primary),
              title: Text('Cuenta', style: theme.textTheme.titleMedium),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              onTap: () {
                context.push('/account');
              },
            ),
          ),
          const SizedBox(height: 16),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
              title: Text('Acerca de la App', style: theme.textTheme.titleMedium),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'Diabetes App',
                  applicationVersion: '1.0.0',
                  applicationLegalese: '© ${DateTime.now().year} De nadie porque no soy una compania registrada',
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.only(top: 20, left: 10, right: 10),
                      alignment: Alignment.center,
                      child: const Text('Esta es una aplicación pensada para ayudar a las personas con diabetes.'),
                    ),
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