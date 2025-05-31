// Archivo: lib/core/theme/theme_provider.dart
// Descripción: Proveedor de estado para gestionar el tema de la aplicación.
// Permite al usuario seleccionar entre tema claro, oscuro o el predeterminado del sistema,
// y persiste esta selección utilizando SharedPreferences para que se recuerde
// entre sesiones de la aplicación.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:flutter/material.dart'; // Framework principal de Flutter para UI, necesario para ThemeMode y ChangeNotifier.
import 'package:shared_preferences/shared_preferences.dart'; // Para leer y escribir preferencias simples de forma persistente.

/// ThemeProvider: Una clase que extiende ChangeNotifier para gestionar el estado del tema.
///
/// Almacena el `ThemeMode` actual de la aplicación (Light, Dark, System).
/// Carga la preferencia de tema guardada al iniciarse y permite cambiarla,
/// persistiendo la nueva selección. Los widgets pueden escuchar cambios en este
/// proveedor para actualizar su apariencia cuando el tema cambia.
class ThemeProvider with ChangeNotifier {
  // Clave utilizada para guardar y cargar la preferencia del modo de tema en SharedPreferences.
  static const String _themeModeKey = 'themeMode';
  // Estado interno que almacena el ThemeMode actual. Se inicializa a `ThemeMode.system` por defecto.
  ThemeMode _themeMode = ThemeMode.system;

  /// Constructor de ThemeProvider.
  /// Llama a `_loadThemeMode()` para cargar la preferencia de tema guardada
  /// tan pronto como se crea una instancia del proveedor.
  ThemeProvider() {
    _loadThemeMode();
  }

  /// themeMode (getter): Proporciona acceso de solo lectura al `_themeMode` actual.
  ThemeMode get themeMode => _themeMode;

  /// _loadThemeMode: Carga la preferencia del modo de tema desde SharedPreferences.
  ///
  /// Si se encuentra una preferencia guardada válida, actualiza `_themeMode`.
  /// Notifica a los listeners después de cargar para que la UI pueda reflejar el tema cargado.
  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance(); // Obtiene la instancia de SharedPreferences.
    // Lee el índice del ThemeMode guardado. ThemeMode.values es una lista de [system, light, dark].
    final themeIndex = prefs.getInt(_themeModeKey);
    if (themeIndex != null && themeIndex >= 0 && themeIndex < ThemeMode.values.length) {
      // Si el índice es válido, actualiza _themeMode con el valor correspondiente del enum.
      _themeMode = ThemeMode.values[themeIndex];
    }
    // Notifica a los listeners (ej. MaterialApp) para que se reconstruyan con el tema cargado.
    // Esto es importante para que la app se inicie con el tema correcto si ya fue establecido por el usuario.
    notifyListeners();
  }

  /// setThemeMode: Establece un nuevo modo de tema para la aplicación.
  ///
  /// Actualiza el estado interno `_themeMode`, notifica a los listeners para que la UI
  /// se actualice, y guarda la nueva preferencia en SharedPreferences.
  ///
  /// @param mode El nuevo `ThemeMode` a aplicar.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return; // No hacer nada si el modo es el mismo.

    _themeMode = mode; // Actualiza el estado interno.
    notifyListeners(); // Notifica a los widgets que escuchan para que se reconstruyan con el nuevo tema.

    final prefs = await SharedPreferences.getInstance(); // Obtiene SharedPreferences.
    // Guarda el índice del nuevo modo de tema.
    await prefs.setInt(_themeModeKey, mode.index);
  }

  /// currentThemeModeName (getter): Devuelve un String legible por humanos
  /// que representa el modo de tema actual. Útil para mostrar en la UI (ej. en Ajustes).
  String get currentThemeModeName {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Claro';
      case ThemeMode.dark:
        return 'Oscuro';
      case ThemeMode.system:
        return 'Predeterminado del sistema';
    }
  }
}