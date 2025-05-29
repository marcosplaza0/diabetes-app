// lib/core/layout/main_layout.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'drawer/drawer_app.dart';
// import 'package:diabetes_2/core/auth/auth_service.dart'; // AuthService no maneja la lógica de UI del diálogo

// NUEVAS IMPORTACIONES para la lógica de logout
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:diabetes_2/main.dart' show supabase, mealLogBoxName, overnightLogBoxName;
import 'package:diabetes_2/data/models/logs/logs.dart';
import 'package:diabetes_2/core/services/supabase_log_sync_service.dart';

// Clave para SharedPreferences (debería ser global o importada)
const String cloudSavePreferenceKeyFromMainLayout = 'saveToCloudEnabled';

// Enum para las acciones del diálogo de logout (puede estar en un archivo común)
enum MainLayoutLogoutPromptAction {
  uploadAndLogout,
  logoutWithoutUploading,
  cancel,
}


class MainLayout extends StatefulWidget {
  final String title;
  final Widget body;

  const MainLayout({
    super.key,
    required this.title,
    required this.body
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  // final authService = AuthService(); // No es necesario para la lógica de UI del diálogo

  // NUEVO: Estado para manejar el proceso de logout
  bool _isProcessingLogoutMainLayout = false;
  final SupabaseLogSyncService _logSyncServiceMainLayout = SupabaseLogSyncService();


  // NUEVO: Método para manejar el proceso de logout con diálogo condicional
  Future<void> _handleLogoutWithPrompt(BuildContext context) async { // Pasar BuildContext
    if (_isProcessingLogoutMainLayout || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final bool cloudSaveCurrentlyEnabled = prefs.getBool(cloudSavePreferenceKeyFromMainLayout) ?? false;

    final mealLogBox = Hive.box<MealLog>(mealLogBoxName);
    final overnightLogBox = Hive.box<OvernightLog>(overnightLogBoxName);
    final bool hasLocalData = mealLogBox.isNotEmpty || overnightLogBox.isNotEmpty;
    final bool isLoggedIn = supabase.auth.currentUser != null;

    MainLayoutLogoutPromptAction? userAction = MainLayoutLogoutPromptAction.logoutWithoutUploading;

    if (isLoggedIn && !cloudSaveCurrentlyEnabled && hasLocalData) {
      if (!mounted) return;
      userAction = await showDialog<MainLayoutLogoutPromptAction>(
        context: (!mounted) ? context: context, // Usar el context pasado
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Datos Locales Sin Sincronizar'),
            content: const Text('Tienes registros locales que no se han guardado en la nube. ¿Deseas subirlos antes de cerrar sesión?'),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancelar'),
                onPressed: () => Navigator.of(dialogContext).pop(MainLayoutLogoutPromptAction.cancel),
              ),
              TextButton(
                child: const Text('Cerrar Sin Subir'),
                onPressed: () => Navigator.of(dialogContext).pop(MainLayoutLogoutPromptAction.logoutWithoutUploading),
              ),
              ElevatedButton(
                child: const Text('Subir y Cerrar Sesión'),
                onPressed: () => Navigator.of(dialogContext).pop(MainLayoutLogoutPromptAction.uploadAndLogout),
              ),
            ],
          );
        },
      );
    }

    if (!mounted || userAction == MainLayoutLogoutPromptAction.cancel) {
      return;
    }

    if (userAction == MainLayoutLogoutPromptAction.uploadAndLogout) {
      if (!mounted) return;
      setState(() { _isProcessingLogoutMainLayout = true; });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subiendo datos a la nube...'), duration: Duration(seconds: 3)),
      );

      int successCount = 0;
      int errorCount = 0;
      try {
        for (var entry in mealLogBox.toMap().entries) {
          try {
            await _logSyncServiceMainLayout.syncMealLog(entry.value, entry.key);
            successCount++;
          } catch (e) { errorCount++; }
        }
        for (var entry in overnightLogBox.toMap().entries) {
          try {
            await _logSyncServiceMainLayout.syncOvernightLog(entry.value, entry.key);
            successCount++;
          } catch (e) { errorCount++; }
        }
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sincronización antes de logout completada. Éxitos: $successCount, Errores: $errorCount'), backgroundColor: errorCount > 0 ? Colors.orange : Colors.green),
          );
        }
      } catch (e) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al subir datos: ${e.toString()}'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() { _isProcessingLogoutMainLayout = false; });
      }
    }

    try {
      await supabase.auth.signOut();
      // La navegación es manejada por GoRouter redirect
    } catch (e) {
      debugPrint("Error signing out desde MainLayout: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al cerrar sesión: ${e.toString()}'))
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        shadowColor: theme.colorScheme.shadow,
        elevation: 5,
        actions: [
          if (_isProcessingLogoutMainLayout) // Mostrar loader en lugar del botón si se está procesando
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))),
            )
          else
            IconButton(
              onPressed: () => _handleLogoutWithPrompt(context), // Llamar al nuevo método
              icon: Icon(
                Icons.logout,
                color: theme.colorScheme.error,
              ),
              tooltip: 'Cerrar Sesión',
            )
        ],
      ),
      body: widget.body,
      drawer: const DrawerApp(),
    );
  }
}