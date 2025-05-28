// Archivo: settings_screen.dart
import 'package:flutter/material.dart';
import 'package:diabetes_2/core/layout/main_layout.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart'; // Importa Provider
import 'package:diabetes_2/core/theme/theme_provider.dart'; // Importa tu ThemeProvider

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void _showThemeDialog(BuildContext context, ThemeProvider themeProvider) {
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
                  Navigator.of(dialogContext).pop(); // Cierra el diálogo
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Accede al ThemeProvider
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

          // Mantén las otras opciones de configuración como las tenías
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