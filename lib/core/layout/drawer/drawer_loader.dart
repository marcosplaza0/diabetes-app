// Archivo: lib/core/layout/drawer/drawer_loader.dart
// Descripción: Clase de utilidad para cargar la configuración de los ítems del Drawer
// desde un archivo JSON ubicado en los assets de la aplicación.
// Implementa un mecanismo de caché simple para evitar recargar y parsear el JSON
// repetidamente si ya ha sido cargado una vez.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'dart:convert'; // Para decodificar la cadena JSON (json.decode).
import 'package:flutter/services.dart'; // Para rootBundle, usado para cargar archivos de assets.
import 'package:flutter/material.dart'; // Para debugPrint, en caso de errores.

/// DrawerLoader: Clase de utilidad para cargar la configuración de los ítems del Drawer.
///
/// Proporciona un método estático `loadDrawerItems` que lee un archivo JSON
///
/// Utiliza una caché estática (`_cache`) para almacenar el resultado de la primera carga,
/// de modo que las llamadas subsiguientes a `loadDrawerItems` devuelvan los datos
/// cacheados instantáneamente sin releer el archivo.
class DrawerLoader {
  // Caché estático para almacenar la lista de items del drawer una vez cargada.
  // Es un `Future` porque la carga inicial es asíncrona.
  static Future<List<Map<String, dynamic>>>? _cache;

  /// loadDrawerItems: Carga y devuelve la lista de ítems para el Drawer.
  ///
  /// Si los ítems ya han sido cargados y están en caché, los devuelve directamente.
  /// Si no, llama a `_loadFromAsset` para cargarlos desde el archivo JSON,
  /// los guarda en la caché y luego los devuelve.
  ///
  /// @return Un `Future<List<Map<String, dynamic>>>` que resuelve a la lista de
  ///         configuraciones de los ítems del drawer. Cada mapa en la lista
  ///         representa un ítem (ej. {'type': 'item', 'label': 'Inicio', 'icon': 'home', 'route': '/'})
  ///         o un divisor (ej. {'type': 'divider'}).
  static Future<List<Map<String, dynamic>>> loadDrawerItems() {
    // Si la caché no es nula, devuelve el Future cacheado.
    // Si es nula, llama a _loadFromAsset, asigna el resultado a _cache y lo devuelve.
    // El operador `??=` asegura que `_loadFromAsset` solo se llame una vez.
    return _cache ??= _loadFromAsset();
  }

  /// _loadFromAsset: Método privado que realiza la carga real desde el archivo JSON de assets.
  ///
  /// Lee el archivo 'assets/drawer_config.json', lo decodifica de JSON a una lista de mapas,
  /// y la devuelve. Maneja posibles errores durante la carga o el parseo.
  ///
  /// @return Un `Future<List<Map<String, dynamic>>>` con los datos del drawer,
  ///         o una lista vacía si ocurre un error.
  static Future<List<Map<String, dynamic>>> _loadFromAsset() async {
    try {
      // Carga el contenido del archivo JSON como un String.
      // Se asume que el archivo se llama 'drawer_config.json' y está en la carpeta 'assets'.
      // Este path debe estar declarado en el archivo pubspec.yaml.
      final jsonStr = await rootBundle.loadString('assets/drawer_config.json');
      // Decodifica la cadena JSON a una lista dinámica.
      final rawList = json.decode(jsonStr) as List<dynamic>;
      // Mapea cada elemento de la lista dinámica a un Map<String, dynamic>.
      // Esto asume que el JSON es una lista de objetos.
      return rawList.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      // Si ocurre un error durante la carga o el parseo (ej. archivo no encontrado, JSON mal formado),
      // se imprime un mensaje de error en la consola y se devuelve una lista vacía
      // para evitar que la aplicación falle.
      debugPrint('DrawerLoader: Error al cargar la configuración del drawer: $e');
      return []; // Devuelve una lista vacía en caso de error.
    }
  }
}