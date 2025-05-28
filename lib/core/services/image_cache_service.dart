import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

const String avatarCacheBoxName = 'avatar_cache';

class ImageCacheService {
  late Box<Uint8List> _avatarCacheBox;

  Future<void> init() async {
    // Hive maneja Uint8List de forma nativa, no se requiere adaptador.
    _avatarCacheBox = await Hive.openBox<Uint8List>(avatarCacheBoxName);
    debugPrint("Avatar cache box ('$avatarCacheBoxName') abierta. IsOpen: ${_avatarCacheBox.isOpen}");
  }

  Future<Uint8List?> getImage(String key) async {
    if (!_avatarCacheBox.isOpen) {
      debugPrint("ADVERTENCIA: $avatarCacheBoxName intentó leerse mientras estaba cerrada. Clave: $key");
      await init(); // Intenta reabrirla
    }
    final data = _avatarCacheBox.get(key);
    if (data != null) {
      debugPrint("Imagen encontrada en caché para la clave: $key");
    } else {
      debugPrint("Imagen NO encontrada en caché para la clave: $key");
    }
    return data;
  }

  Future<void> cacheImage(String key, Uint8List bytes) async {
    if (!_avatarCacheBox.isOpen) {
      debugPrint("ADVERTENCIA: $avatarCacheBoxName intentó escribirse mientras estaba cerrada. Clave: $key");
      await init(); // Intenta reabrirla
    }
    debugPrint("Cacheando imagen con clave: $key, tamaño: ${bytes.lengthInBytes} bytes");
    await _avatarCacheBox.put(key, bytes);
  }

  Future<Uint8List?> downloadAndCacheImage(String key, String downloadUrl) async {
    debugPrint("Descargando imagen desde: $downloadUrl para cachear con clave: $key");
    try {
      final response = await http.get(Uri.parse(downloadUrl));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        await cacheImage(key, bytes);
        debugPrint("Imagen descargada y cacheada exitosamente: $key");
        return bytes;
      } else {
        debugPrint("Error descargando imagen HTTP ${response.statusCode} desde $downloadUrl");
        return null;
      }
    } catch (e) {
      debugPrint("Excepción al descargar/cachear imagen desde $downloadUrl: $e");
      return null;
    }
  }

  String? extractFilePathFromUrl(String url) {
    if (url.isEmpty) return null;
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;

      // Busca el índice del segmento del bucket 'avatars'
      // Ej: ["storage", "v1", "object", "sign", "avatars", "nombrearchivo.jpg"]
      // Ej: ["storage", "v1", "object", "public", "avatars", "nombrearchivo.jpg"]
      int bucketIndex = pathSegments.indexOf('avatars');

      if (bucketIndex != -1 && pathSegments.length > bucketIndex + 1) {
        // El filePath es la concatenación de todos los segmentos después de 'avatars'
        final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
        debugPrint("FilePath extraído de $url: $filePath");
        return filePath;
      }
    } catch (e) {
      debugPrint("Error extrayendo filePath de URL $url: $e");
      return null;
    }
    debugPrint("No se pudo extraer filePath de URL (estructura no esperada o bucket 'avatars' no encontrado): $url");
    return null;
  }
}