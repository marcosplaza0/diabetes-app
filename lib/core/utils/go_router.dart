// Archivo: go_router.dart
// Descripción: Configuración de rutas de navegación para la aplicación.
// Este archivo define todas las rutas disponibles y las pantallas asociadas a cada ruta.


import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:diabetes_2/features/home/presentation/home_screen.dart';
import 'package:diabetes_2/features/historial/presentation/historial_screen.dart';
import 'package:diabetes_2/features/food_injections/presentation/food_injections.dart';
import 'package:diabetes_2/features/notes/presentation/log_screen.dart';
import 'package:diabetes_2/core/auth/presentation/login_page.dart';
import 'package:diabetes_2/core/auth/presentation/register_page.dart';
import 'package:diabetes_2/core/auth/presentation/account_page.dart';
import 'package:diabetes_2/features/settings/presentation/settings_screen.dart';


/// Clase de utilidad que proporciona la configuración del enrutador para la navegación en la aplicación
class GoRouterUtils {

  static final SupabaseClient _supabaseClient = Supabase.instance.client;

  static final _authChangesNotifier = GoRouterRefreshStream(
    _supabaseClient.auth.onAuthStateChange,
  );  /// Configuración del enrutador principal de la aplicación


  /// Define todas las rutas disponibles y las pantallas correspondientes
  static final GoRouter router = GoRouter(
    refreshListenable: _authChangesNotifier,
    redirect: (BuildContext cotext, GoRouterState state) {
      final sessiona = _supabaseClient.auth.currentSession;
      final bool loggedIn = sessiona != null;

      final bool loggingIn = state.matchedLocation == '/login';
      final bool signingUp = state.matchedLocation == '/register';
      if (!loggedIn && !loggingIn && !signingUp) {
        return '/login';
      }

      // Si está logueado y está intentando acceder a login (o signup), redirige a la pantalla principal
      if (loggedIn && (loggingIn /* || signingUp */)) {
        return '/'; // Redirige a HomeScreen
      }

      // No se necesita redirección en otros casos
      return null;
    },

    routes: <RouteBase>[
      /// Ruta principal que muestra la pantalla de inicio
      GoRoute(
        path: '/',
        name: 'home',
        builder: (BuildContext context, GoRouterState state) {
          return HomeScreen();
        },
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (BuildContext context, GoRouterState state) {
          return LoginPage();
        }
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (BuildContext context, GoRouterState state) {
          return RegisterPage();
        }
      ),
      GoRoute(
        path: '/account',
        name: 'account',
        builder: (context, state) => const AccountPage(),
      ),
      /// Ruta para acceder a la pantalla de historial
      GoRoute(
          path: '/history',
          name: 'history',
          builder: (BuildContext context, GoRouterState state) {
            return HistorialScreen();
          }
      ),
      GoRoute(
        path: '/diabetes-log/new',
        name: 'diabetesLogNew',
        builder: (context, state) => const DiabetesLogScreen(),
      ),
      GoRoute(
        name: 'diabetesLogEdit',
        path: '/diabetes-log/edit/:logTypeString/:logKeyString',
        builder: (context, state) {
          final logTypeString = state.pathParameters['logTypeString'];
          final logKeyString = state.pathParameters['logKeyString'];
          dynamic logKey;

          if(logKeyString != null) {
            logKey = int.tryParse(logKeyString);
            if(logKey == null) {
              print("Error: logKeyString is not an integer: $logKeyString");
            }
          }
          return DiabetesLogScreen(
            logTypeString: logTypeString,
            logKey: logKey,
          );
        }
      ),
      /// Ruta para acceder a la pantalla de alimentos e inyecciones
      GoRoute(
          path: '/food_injections',
          builder: (BuildContext context, GoRouterState state) {
            return FoodInjectionsScreen();
          }
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (BuildContext context, GoRouterState state) {
          return SettingsScreen();
        }
      ),
    ]
  );

}

class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
