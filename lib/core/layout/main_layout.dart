// Archivo: lib/core/layout/main_layout.dart
// Descripción: Define el widget de diseño principal (MainLayout) que proporciona
// una estructura consistente para las pantallas de la aplicación. Incluye una AppBar
// con un título y un botón de cierre de sesión, y un Drawer (menú lateral) común.
// También maneja la lógica de cierre de sesión, incluyendo un diálogo de confirmación
// si hay datos locales sin sincronizar.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:flutter/material.dart'; // Framework principal de Flutter para UI.
import 'package:shared_preferences/shared_preferences.dart'; // Para leer/escribir preferencias (ej. guardado en nube).
import 'package:hive_flutter/hive_flutter.dart'; // Para acceder a las cajas de Hive (logs).

// Importaciones de archivos del proyecto
import 'package:DiabetiApp/core/layout/drawer/drawer_app.dart'; // Widget del Drawer de la aplicación.
import 'package:DiabetiApp/main.dart' show supabase, mealLogBoxName, overnightLogBoxName; // Cliente Supabase y nombres de cajas Hive.
import 'package:DiabetiApp/data/models/logs/logs.dart'; // Modelos MealLog y OvernightLog para la lógica de logout.
import 'package:DiabetiApp/core/services/supabase_log_sync_service.dart'; // Servicio para sincronizar logs con Supabase.

// Clave para SharedPreferences usada para la preferencia de guardado en la nube.
// Debería ser consistente con la usada en otros lugares (ej. DrawerApp, ViewModels).
const String cloudSavePreferenceKeyFromMainLayout = 'saveToCloudEnabled';

// Enum para las acciones del diálogo de confirmación de cierre de sesión.
// Similar al LogoutPromptAction en DrawerApp, idealmente se unificarían.
enum MainLayoutLogoutPromptAction {
  uploadAndLogout,         // Subir datos y luego cerrar sesión.
  logoutWithoutUploading,  // Cerrar sesión sin subir datos.
  cancel,                  // Cancelar la operación de cierre de sesión.
}


/// MainLayout: Un StatefulWidget que proporciona la estructura base para las pantallas.
///
/// Parámetros:
/// - `title`: El título a mostrar en la AppBar.
/// - `body`: El widget principal que se mostrará como contenido de la pantalla.
class MainLayout extends StatefulWidget {
  final String title; // Título de la AppBar.
  final Widget body;  // Contenido principal de la pantalla.

  const MainLayout({
    super.key,
    required this.title,
    required this.body
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  // Estado para manejar el proceso de cierre de sesión desde la AppBar.
  bool _isProcessingLogoutMainLayout = false;
  // Instancia del servicio de sincronización de logs, usada si el usuario decide subir datos antes de desloguearse.
  final SupabaseLogSyncService _logSyncServiceMainLayout = SupabaseLogSyncService(); //


  /// _handleLogoutWithPrompt: Gestiona el proceso de cierre de sesión, mostrando un diálogo de confirmación
  /// si es necesario (similar a la lógica en DrawerApp).
  ///
  /// @param context El BuildContext actual, necesario para mostrar el diálogo y SnackBars.
  Future<void> _handleLogoutWithPrompt(BuildContext context) async {
    if (_isProcessingLogoutMainLayout || !mounted) return; // Evita múltiples llamadas o si el widget no está montado.

    final prefs = await SharedPreferences.getInstance();
    // Verifica si el guardado en la nube está habilitado y si hay datos locales.
    final bool cloudSaveCurrentlyEnabled = prefs.getBool(cloudSavePreferenceKeyFromMainLayout) ?? false;

    final mealLogBox = Hive.box<MealLog>(mealLogBoxName); //
    final overnightLogBox = Hive.box<OvernightLog>(overnightLogBoxName); //
    final bool hasLocalData = mealLogBox.isNotEmpty || overnightLogBox.isNotEmpty;
    final bool isLoggedIn = supabase.auth.currentUser != null; //

    MainLayoutLogoutPromptAction? userAction = MainLayoutLogoutPromptAction.logoutWithoutUploading; // Acción por defecto.

    // Si el usuario está logueado, el guardado en nube está DESACTIVADO, y hay datos locales:
    if (isLoggedIn && !cloudSaveCurrentlyEnabled && hasLocalData) {
      if (!mounted) return;
      // Muestra un diálogo al usuario.
      userAction = await showDialog<MainLayoutLogoutPromptAction>(
        context: context, // Usa el context pasado al método.
        barrierDismissible: false, // No permitir cerrar tocando fuera.
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

    if (!mounted || userAction == MainLayoutLogoutPromptAction.cancel) { // Si el usuario cancela o el widget se desmonta.
      return;
    }

    // Si el usuario elige subir datos.
    if (userAction == MainLayoutLogoutPromptAction.uploadAndLogout) {
      if (!mounted) return;
      setState(() { _isProcessingLogoutMainLayout = true; }); // Inicia estado de procesamiento.

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subiendo datos a la nube...'), duration: Duration(seconds: 3)),
      );

      int successCount = 0; int errorCount = 0;
      try {
        // Sincroniza MealLogs.
        for (var entry in mealLogBox.toMap().entries) {
          try {
            await _logSyncServiceMainLayout.syncMealLog(entry.value, entry.key); //
            successCount++;
          } catch (e) { errorCount++; }
        }
        // Sincroniza OvernightLogs.
        for (var entry in overnightLogBox.toMap().entries) {
          try {
            await _logSyncServiceMainLayout.syncOvernightLog(entry.value, entry.key); //
            successCount++;
          } catch (e) { errorCount++; }
        }
        if(mounted) { // Muestra feedback de la sincronización.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sincronización antes de logout completada. Éxitos: $successCount, Errores: $errorCount'), backgroundColor: errorCount > 0 ? Colors.orange : Colors.green),
          );
        }
      } catch (e) { // Error general durante la sincronización.
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al subir datos: ${e.toString()}'), backgroundColor: Colors.red),
          );
        }
      } finally { // Asegura que el estado de procesamiento se desactive.
        if (mounted) setState(() { _isProcessingLogoutMainLayout = false; });
      }
    }

    // Procede a cerrar la sesión en Supabase.
    try {
      await supabase.auth.signOut(); //
      // La navegación a la pantalla de login es manejada por el redirect de GoRouter
      // basado en el cambio de estado de autenticación.
    } catch (e) {
      debugPrint("Error signing out desde MainLayout: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al cerrar sesión: ${e.toString()}'))
        );
      }
    }
    // No es necesario setState para _isProcessingLogoutMainLayout aquí si la sincronización no se hizo,
    // ya que ya estaría en false o se manejó en el bloque `finally` de la sincronización.
    // Si `uploadAndLogout` no se ejecutó, `_isProcessingLogoutMainLayout` no se puso a true aquí.
    // Podríamos asegurar que esté en false si es necesario, pero la lógica actual parece cubrirlo.
  }


  @override
  /// build: Construye la interfaz de usuario del MainLayout.
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Obtiene el tema actual.

    return Scaffold(
      // AppBar: Barra superior de la aplicación.
      appBar: AppBar(
        title: Text(widget.title), // Título de la pantalla, pasado como parámetro.
        centerTitle: true, // Centra el título en la AppBar.
        shadowColor: theme.colorScheme.shadow, // Color de la sombra de la AppBar.
        elevation: 5, // Elevación de la AppBar.
        actions: [ // Acciones a la derecha de la AppBar.
          // Muestra un indicador de progreso o el botón de logout.
          if (_isProcessingLogoutMainLayout)
            const Padding( // Indicador de progreso si se está cerrando sesión.
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))),
            )
          else
          // Botón de IconButton para cerrar sesión.
            IconButton(
              onPressed: () => _handleLogoutWithPrompt(context), // Llama al método de logout.
              icon: Icon(
                Icons.logout,
                color: theme.colorScheme.error, // Color de error para el icono de logout.
              ),
              tooltip: 'Cerrar Sesión', // Texto de ayuda al mantener presionado.
            )
        ],
      ),
      // Body: Contenido principal de la pantalla, pasado como parámetro.
      body: widget.body,
      // Drawer: Menú lateral de la aplicación.
      drawer: const DrawerApp(), //
    );
  }
}