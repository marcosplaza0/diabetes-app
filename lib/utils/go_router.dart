// Archivo: go_router.dart
// Descripción: Configuración de rutas de navegación para la aplicación.
// Este archivo define todas las rutas disponibles y las pantallas asociadas a cada ruta.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../presentation/home/home_screen.dart';
import '../presentation/historial/historial_screen.dart';
import '../presentation/food_injections/food_injections.dart';

/// Clase de utilidad que proporciona la configuración del enrutador para la navegación en la aplicación
class GoRouterUtils {
  /// Configuración del enrutador principal de la aplicación
  /// Define todas las rutas disponibles y las pantallas correspondientes
  static final GoRouter router = GoRouter(
    routes: <RouteBase>[
      /// Ruta principal que muestra la pantalla de inicio
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) {
          return HomeScreen();
        },
      ),
      /// Ruta para acceder a la pantalla de historial
      GoRoute(
          path: '/history',
          builder: (BuildContext context, GoRouterState state) {
            return HistorialScreen();
          }
      ),
      /// Ruta para acceder a la pantalla de alimentos e inyecciones
      GoRoute(
          path: '/food_injections',
          builder: (BuildContext context, GoRouterState state) {
            return FoodInjectionsScreen();
          }
      ),
    ]
  );

}
