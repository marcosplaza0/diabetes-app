// lib/core/utils/go_router.dart
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

class GoRouterUtils {
  static final SupabaseClient _supabaseClient = Supabase.instance.client;

  static final _authChangesNotifier = GoRouterRefreshStream(
    _supabaseClient.auth.onAuthStateChange,
  );

  static final GoRouter router = GoRouter(
    refreshListenable: _authChangesNotifier,
    redirect: (BuildContext context, GoRouterState state) {
      final session = _supabaseClient.auth.currentSession;
      final bool loggedIn = session != null;

      final bool loggingIn = state.matchedLocation == '/login';
      final bool signingUp = state.matchedLocation == '/register';
      if (!loggedIn && !loggingIn && !signingUp) {
        return '/login';
      }

      if (loggedIn && (loggingIn || signingUp)) { // Modificado para incluir signingUp en la redirección si está logueado
        return '/';
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        name: 'home',
        builder: (BuildContext context, GoRouterState state) {
          return const HomeScreen(); // Usar const si es posible
        },
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (BuildContext context, GoRouterState state) {
          return const LoginPage(); // Usar const si es posible
        },
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (BuildContext context, GoRouterState state) {
          return const RegisterPage(); // Usar const si es posible
        },
      ),
      GoRoute(
        path: '/account',
        name: 'account',
        builder: (context, state) => const AccountPage(),
      ),
      GoRoute(
          path: '/history',
          name: 'history',
          builder: (BuildContext context, GoRouterState state) {
            return const HistorialScreen(); // Usar const si es posible
          }),
      GoRoute(
        path: '/diabetes-log/new',
        name: 'diabetesLogNew',
        builder: (context, state) => const DiabetesLogScreen(), // Para nueva nota, logKey es null
      ),
      GoRoute(
          name: 'diabetesLogEdit',
          path: '/diabetes-log/edit/:logTypeString/:logKeyString', // logKeyString será el UUID
          builder: (context, state) {
            final logTypeString = state.pathParameters['logTypeString'];
            // logKeyString es el UUID String directamente del path parameter.
            final String? logKey = state.pathParameters['logKeyString'];

            // debugPrint("GoRouter: Editando log. Tipo: $logTypeString, Clave (UUID): $logKey");

            return DiabetesLogScreen(
              logTypeString: logTypeString,
              logKey: logKey, // logKey es String? y se pasa directamente
            );
          }
      ),
      GoRoute(
          path: '/food_injections',
          name: 'food_injections', // Es buena práctica nombrar todas las rutas
          builder: (BuildContext context, GoRouterState state) {
            return const FoodInjectionsScreen(); // Usar const si es posible
          }),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (BuildContext context, GoRouterState state) {
          return const SettingsScreen(); // Usar const si es posible
        },
      ),
    ],
  );
}

class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;
  GoRouterRefreshStream(Stream<dynamic> stream) {
    // notifyListeners(); // No es necesario notificar en el constructor
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}