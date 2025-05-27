import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

/// Carga la configuración del drawer desde JSON y cachea el resultado
class DrawerLoader {
  static Future<List<Map<String, dynamic>>>? _cache;

  /// Devuelve la lista de elementos (item o divider)
  static Future<List<Map<String, dynamic>>> loadDrawerItems() {
    return _cache ??= _loadFromAsset();
  }

  static Future<List<Map<String, dynamic>>> _loadFromAsset() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/drawer_config.json');
      final raw = json.decode(jsonStr) as List<dynamic>;
      return raw.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('Drawer config load error: $e');
      return [];
    }
  }
}