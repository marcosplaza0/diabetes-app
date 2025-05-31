// Archivo: lib/core/utils/go_router.dart
// Descripción: Configuración centralizada de la navegación de la aplicación utilizando el paquete `go_router`.
// Define todas las rutas de la aplicación, la lógica de redirección basada en el estado
// de autenticación del usuario (Supabase Auth), y un stream para refrescar el router
// cuando cambia dicho estado.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'dart:async'; // Para StreamSubscription, usado en GoRouterRefreshStream.
import 'package:flutter/material.dart'; // Framework principal de Flutter para UI.
import 'package:go_router/go_router.dart'; // Paquete para la gestión de rutas (navegación).
import 'package:supabase_flutter/supabase_flutter.dart'; // Para SupabaseClient y escuchar cambios de autenticación.

// Importaciones de las diferentes pantallas/páginas de la aplicación a las que se puede navegar.
import 'package:DiabetiApp/features/home/presentation/home_screen.dart';
import 'package:DiabetiApp/features/historial/presentation/historial_screen.dart';
import 'package:DiabetiApp/features/food_injections/presentation/food_injections_screen.dart';
import 'package:DiabetiApp/features/notes/presentation/log_screen.dart'; // Pantalla para crear/editar logs.
import 'package:DiabetiApp/features/settings/presentation/settings_screen.dart';
import 'package:DiabetiApp/features/trends_graphs/presentation/tendencias_graph_screen.dart';
import 'package:DiabetiApp/features/trends/presentation/tendencias_screen.dart';

// Core (Autenticación y Cuenta):
import 'package:DiabetiApp/core/auth/presentation/login_page.dart';
import 'package:DiabetiApp/core/auth/presentation/register_page.dart';
import 'package:DiabetiApp/core/auth/presentation/account_page.dart'; // Pantalla de gestión de cuenta/perfil.

/// GoRouterUtils: Clase de utilidad que encapsula la configuración de GoRouter.
///
/// Contiene la instancia estática del router (`router`) y la lógica de
/// redirección y refresco basada en el estado de autenticación de Supabase.
class GoRouterUtils {
  // Cliente de Supabase para acceder al estado de autenticación.
  static final SupabaseClient _supabaseClient = Supabase.instance.client;

  // GoRouterRefreshStream: Un Listenable que notifica a GoRouter cuando
  // el estado de autenticación de Supabase cambia. Esto permite que GoRouter
  // re-evalúe la lógica de `redirect`.
  static final _authChangesNotifier = GoRouterRefreshStream(
    _supabaseClient.auth.onAuthStateChange, // Escucha el stream de cambios de autenticación.
  );

  /// router: La instancia principal y estática de GoRouter para toda la aplicación.
  static final GoRouter router = GoRouter(
    // refreshListenable: Permite a GoRouter escuchar cambios (ej. estado de login)
    // y re-evaluar las rutas si es necesario.
    refreshListenable: _authChangesNotifier,

    // redirect: Lógica de redirección global que se ejecuta antes de cada navegación.
    // Protege rutas y maneja el flujo de autenticación.
    redirect: (BuildContext context, GoRouterState state) {
      final session = _supabaseClient.auth.currentSession; // Obtiene la sesión actual de Supabase.
      final bool loggedIn = session != null; // Determina si el usuario está logueado.

      // Obtiene la ruta a la que el usuario intenta navegar.
      final String location = state.matchedLocation; // Anteriormente state.location, ahora state.matchedLocation es más preciso.

      // Comprueba si el usuario está intentando acceder a las páginas de login o registro.
      final bool loggingIn = location == '/login';
      final bool signingUp = location == '/register';

      // --- Lógica de Redirección ---
      // 1. Si el usuario NO está logueado Y NO está intentando acceder a /login o /register:
      //    Redirige a /login.
      if (!loggedIn && !loggingIn && !signingUp) {
        return '/login';
      }

      // 2. Si el usuario SÍ está logueado Y está intentando acceder a /login o /register:
      //    Redirige a la página principal ('/').
      if (loggedIn && (loggingIn || signingUp)) {
        return '/';
      }

      // 3. En cualquier otro caso (ej. usuario logueado accediendo a una ruta protegida,
      //    o usuario no logueado accediendo a /login o /register), no se redirige.
      return null; // Permite la navegación a la ruta solicitada.
    },

    // routes: Define todas las rutas disponibles en la aplicación.
    routes: <RouteBase>[
      // Ruta Principal (Home)
      GoRoute(
        path: '/', // Path de la ruta.
        name: 'home', // Nombre único para la ruta (útil para navegación nombrada).
        builder: (BuildContext context, GoRouterState state) {
          return const HomeScreen(); // Widget a construir para esta ruta.
        },
      ),
      // Ruta de Login
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (BuildContext context, GoRouterState state) {
          return const LoginPage();
        },
      ),
      // Ruta de Registro
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (BuildContext context, GoRouterState state) {
          return const RegisterPage();
        },
      ),
      // Ruta de Cuenta/Perfil del Usuario
      GoRoute(
        path: '/account',
        name: 'account',
        builder: (context, state) => const AccountPage(),
      ),
      // Ruta de Historial
      GoRoute(
          path: '/history',
          name: 'history',
          builder: (BuildContext context, GoRouterState state) {
            return const HistorialScreen();
          }),
      // Ruta para Crear un Nuevo Log de Diabetes
      GoRoute(
        path: '/diabetes-log/new', // Ruta específica para un nuevo log.
        name: 'diabetesLogNew',
        builder: (context, state) => const DiabetesLogScreen(),
      ),
      // Ruta para Editar un Log de Diabetes Existente
      GoRoute(
          name: 'diabetesLogEdit',
          // Define parámetros de ruta para el tipo de log y la clave del log.
          // :logTypeString y :logKeyString son los nombres de los parámetros.
          path: '/diabetes-log/edit/:logTypeString/:logKeyString',
          builder: (context, state) {
            // Extrae los parámetros de la ruta del GoRouterState.
            final logTypeString = state.pathParameters['logTypeString'];
            final String? logKey = state.pathParameters['logKeyString']; // La clave del log (UUID como String).

            // Pasa los parámetros extraídos a la pantalla DiabetesLogScreen.
            return DiabetesLogScreen(
              logTypeString: logTypeString,
              logKey: logKey, // logKey es String? y se pasa directamente.
            );
          }
      ),
      // Ruta de Calculadora de Dosis (Food Injections)
      GoRoute(
          path: '/food_injections',
          name: 'food_injections',
          builder: (BuildContext context, GoRouterState state) {
            return const FoodInjectionsScreen();
          }),
      // Ruta de Ajustes
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (BuildContext context, GoRouterState state) {
          return const SettingsScreen();
        },
      ),
      // Ruta de Resumen de Tendencias
      GoRoute(
        path: '/data/trends',
        name: 'trends',
        builder: (BuildContext context, GoRouterState state) {
          return const TrendsScreen();
        },
      ),
      // Ruta de Gráficos de Tendencias
      GoRoute(
          path: '/data/trend_graph',
          name: 'trendsGraph',
          builder: (BuildContext context, GoRouterState state) {
            return const TendenciasGraphScreen();
          }
      ),
    ],
  );
}

/// GoRouterRefreshStream: Una clase que extiende ChangeNotifier para ser usada con `refreshListenable`.
///
/// Escucha un `Stream` (en este caso, el stream de cambios de estado de autenticación de Supabase)
/// y llama a `notifyListeners()` cada vez que el stream emite un evento. Esto hace que
/// GoRouter re-evalúe su lógica de `redirect`.
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription; // Suscripción al stream.

  /// Constructor: Se suscribe al stream provisto.
  ///
  /// @param stream El stream a escuchar (ej. `Supabase.instance.client.auth.onAuthStateChange`).
  GoRouterRefreshStream(Stream<dynamic> stream) {
    // Se suscribe al stream. El stream se convierte a `asBroadcastStream()`
    // si se espera que múltiples listeners puedan suscribirse (aunque aquí solo es GoRouter).
    // Cada vez que el stream emite un evento (`_`), se llama a `notifyListeners()`.
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  @override
  /// dispose: Cancela la suscripción al stream cuando el `GoRouterRefreshStream` ya no se necesita.
  /// Esto es crucial para prevenir memory leaks.
  void dispose() {
    _subscription.cancel(); // Cancela la suscripción.
    super.dispose(); // Llama al dispose de la clase base (ChangeNotifier).
  }
}