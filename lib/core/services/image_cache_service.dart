// Archivo: lib/core/services/image_cache_service.dart
// Descripción: Servicio para gestionar la caché local de imágenes.
// Actualmente, está enfocado en cachear avatares de usuario para reducir
// las solicitudes de red y mejorar los tiempos de carga. Utiliza Hive para
// almacenar los bytes de las imágenes.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:flutter/foundation.dart'; // Para Uint8List (bytes de la imagen) y debugPrint.
import 'package:hive/hive.dart'; // Para interactuar con la base de datos local Hive (Box).
import 'package:http/http.dart' as http; // Paquete HTTP para realizar solicitudes de red (descargar imágenes).

// Constante que define el nombre de la caja de Hive utilizada para la caché de avatares.
// Es importante que este nombre sea único y consistente.
const String avatarCacheBoxName = 'avatar_cache';

/// ImageCacheService: Clase de servicio para la gestión de la caché de imágenes.
///
/// Proporciona métodos para inicializar la caché, obtener imágenes de la caché,
/// guardar imágenes en la caché, y descargar imágenes de una URL para luego cachearlas.
/// También incluye una utilidad para extraer un identificador de archivo (usado como clave)
/// desde una URL de Supabase Storage.
class ImageCacheService {
  // Instancia de la caja de Hive que almacenará los avatares.
  // Es de tipo Box<Uint8List> porque Hive maneja Uint8List de forma nativa.
  late Box<Uint8List> _avatarCacheBox;

  /// init: Inicializa el servicio de caché abriendo la caja de Hive correspondiente.
  ///
  /// Esta operación es asíncrona y debe completarse antes de que se puedan
  /// realizar operaciones de lectura o escritura en la caché.
  Future<void> init() async {
    // Abre la caja de Hive con el nombre especificado.
    // Hive maneja Uint8List de forma nativa, por lo que no se requiere un adaptador personalizado.
    _avatarCacheBox = await Hive.openBox<Uint8List>(avatarCacheBoxName);
    debugPrint("ImageCacheService: Caja de caché de avatares ('$avatarCacheBoxName') abierta. Está abierta: ${_avatarCacheBox.isOpen}");
  }

  /// getImage: Obtiene los bytes de una imagen desde la caché usando su clave.
  ///
  /// @param key La clave única (generalmente el filePath del avatar) de la imagen en la caché.
  /// @return Un `Future<Uint8List?>` que resuelve a los bytes de la imagen si se encuentra,
  ///         o `null` si no está en caché o si la caja está cerrada y no se puede reabrir.
  Future<Uint8List?> getImage(String key) async {
    // Comprueba si la caja está abierta. Si no, intenta reinicializarla.
    // Esto es una medida de seguridad por si la caja se cierra inesperadamente.
    if (!_avatarCacheBox.isOpen) {
      debugPrint("ImageCacheService: ADVERTENCIA - La caja '$avatarCacheBoxName' intentó leerse mientras estaba cerrada. Clave: $key");
      await init(); // Intenta reabrir la caja.
    }
    // Obtiene los datos (bytes de la imagen) de la caja usando la clave.
    final data = _avatarCacheBox.get(key);
    if (data != null) {
      debugPrint("ImageCacheService: Imagen encontrada en caché para la clave: $key");
    } else {
      debugPrint("ImageCacheService: Imagen NO encontrada en caché para la clave: $key");
    }
    return data;
  }

  /// cacheImage: Guarda los bytes de una imagen en la caché con una clave específica.
  ///
  /// @param key La clave única bajo la cual se guardará la imagen.
  /// @param bytes Los bytes (Uint8List) de la imagen a cachear.
  /// @return Un `Future<void>` que se completa cuando la imagen ha sido guardada.
  Future<void> cacheImage(String key, Uint8List bytes) async {
    // Comprueba si la caja está abierta antes de escribir.
    if (!_avatarCacheBox.isOpen) {
      debugPrint("ImageCacheService: ADVERTENCIA - La caja '$avatarCacheBoxName' intentó escribirse mientras estaba cerrada. Clave: $key");
      await init(); // Intenta reabrir la caja.
    }
    debugPrint("ImageCacheService: Cacheando imagen con clave: $key, tamaño: ${bytes.lengthInBytes} bytes");
    // Guarda los bytes de la imagen en la caja usando la clave.
    await _avatarCacheBox.put(key, bytes);
  }

  /// downloadAndCacheImage: Descarga una imagen desde una URL y la guarda en la caché.
  ///
  /// @param key La clave que se usará para guardar la imagen en la caché.
  /// @param downloadUrl La URL desde la cual se descargará la imagen.
  /// @return Un `Future<Uint8List?>` que resuelve a los bytes de la imagen descargada si la operación
  ///         es exitosa, o `null` si ocurre un error durante la descarga o el cacheo.
  Future<Uint8List?> downloadAndCacheImage(String key, String downloadUrl) async {
    debugPrint("ImageCacheService: Descargando imagen desde: $downloadUrl para cachear con clave: $key");
    try {
      // Realiza una solicitud GET a la URL para obtener la imagen.
      final response = await http.get(Uri.parse(downloadUrl));
      // Si la respuesta HTTP es exitosa (código 200).
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes; // Obtiene los bytes de la respuesta.
        await cacheImage(key, bytes); // Cachea la imagen.
        debugPrint("ImageCacheService: Imagen descargada y cacheada exitosamente: $key");
        return bytes; // Devuelve los bytes de la imagen.
      } else {
        // Si la descarga falla (código HTTP no es 200).
        debugPrint("ImageCacheService: Error descargando imagen HTTP ${response.statusCode} desde $downloadUrl");
        return null;
      }
    } catch (e) {
      // Si ocurre una excepción durante la descarga o el cacheo.
      debugPrint("ImageCacheService: Excepción al descargar/cachear imagen desde $downloadUrl: $e");
      return null;
    }
  }

  /// extractFilePathFromUrl: Extrae el "file path" (ruta de archivo) de una URL de Supabase Storage.
  ///
  /// Este "file path" se utiliza comúnmente como la clave para la caché de imágenes,
  /// ya que es único para cada archivo en un bucket de Supabase.
  /// La URL de Supabase Storage suele tener una estructura como:
  /// `.../storage/v1/object/public/avatars/nombrearchivo.jpg` o
  /// `.../storage/v1/object/sign/avatars/subcarpeta/nombrearchivo.jpg?token=...`
  /// Este método busca el segmento 'avatars' y toma todo lo que sigue como el filePath.
  ///
  /// @param url La URL completa del archivo en Supabase Storage.
  /// @return Un `String?` con el filePath extraído, o `null` si la URL no tiene el formato esperado
  ///         o si ocurre un error durante el parseo.
  String? extractFilePathFromUrl(String url) {
    if (url.isEmpty) return null; // Devuelve nulo si la URL está vacía.
    try {
      final uri = Uri.parse(url); // Parsea la URL a un objeto Uri.
      final pathSegments = uri.pathSegments; // Obtiene los segmentos de la ruta de la URL.

      // Busca el índice del segmento del bucket 'avatars'.
      // Ejemplos de pathSegments:
      // ["storage", "v1", "object", "sign", "avatars", "nombrearchivo.jpg"]
      // ["storage", "v1", "object", "public", "avatars", "nombrearchivo.jpg"]
      // ["storage", "v1", "object", "sign", "avatars", "sub", "carpeta", "nombrearchivo.jpg"]
      int bucketIndex = pathSegments.indexOf('avatars');

      // Si se encuentra el segmento 'avatars' y hay segmentos después de él.
      if (bucketIndex != -1 && pathSegments.length > bucketIndex + 1) {
        // El filePath es la concatenación de todos los segmentos *después* de 'avatars'.
        // Esto asegura que si hay subcarpetas dentro de 'avatars', se incluyan en el filePath.
        final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
        debugPrint("ImageCacheService: FilePath extraído de $url: $filePath");
        return filePath;
      }
    } catch (e) {
      // Si ocurre un error durante el parseo de la URL.
      debugPrint("ImageCacheService: Error extrayendo filePath de URL $url: $e");
      return null;
    }
    // Si no se pudo extraer el filePath (estructura no esperada o bucket 'avatars' no encontrado).
    debugPrint("ImageCacheService: No se pudo extraer filePath de URL (estructura no esperada o bucket 'avatars' no encontrado): $url");
    return null;
  }
}