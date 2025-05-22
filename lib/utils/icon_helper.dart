// Archivo: icon_helper.dart
// Descripción: Proporciona acceso centralizado a los iconos utilizados en la aplicación.
// Este archivo contiene un mapa de nombres de iconos a objetos IconData y métodos para recuperarlos.

import 'package:flutter/material.dart';

/// Clase de utilidad que proporciona acceso a los iconos de la aplicación
/// mediante nombres de cadena, facilitando la gestión y coherencia de los iconos.
class IconHelper {

  /// Mapa que asocia nombres de iconos (cadenas) con objetos IconData de Flutter.
  /// Contiene todos los iconos utilizados en la aplicación para facilitar su referencia.
  static final Map<String, IconData> icons = {
    'home': Icons.home_rounded,
    'history': Icons.history_rounded,
    'settings': Icons.settings_rounded,
    'help_outline': Icons.help_outline_rounded,
    'restaurant': Icons.restaurant_rounded,
    'timeline': Icons.timeline_rounded,
    'bar_chart': Icons.bar_chart_rounded,
    'trending_up': Icons.trending_up_rounded,
    'show_chart': Icons.show_chart_rounded,
    'arrow_upward': Icons.arrow_upward_rounded,
    'arrow_downward': Icons.arrow_downward_rounded,
    'info': Icons.info_outline_rounded,
    'language': Icons.language,
    'brightness_6': Icons.brightness_6,
    'lock': Icons.lock,
    'logout': Icons.logout,
    'dark_mode': Icons.dark_mode,
    'text_format': Icons.text_format,
    'notifications': Icons.notifications,
    'volume_up': Icons.volume_up,
    'vibration': Icons.vibration,
    'alarm': Icons.alarm,
    'monitor': Icons.monitor_heart_outlined,
    'warning': Icons.warning,
    'analytics': Icons.analytics,
    'sync': Icons.sync,
    'backup': Icons.backup,
    'restore': Icons.restore,
    'delete': Icons.delete,
    'bluetooth': Icons.bluetooth,
    'person': Icons.person,
    'security': Icons.security,
    'fingerprint': Icons.fingerprint,
    'star': Icons.star,
  };

  /// Recupera un objeto IconData basado en su nombre.
  /// 
  /// @param name El nombre del icono a recuperar.
  /// @return El objeto IconData correspondiente, o null si no se encuentra.
  static IconData? getIcon(String name) => icons[name];
}
