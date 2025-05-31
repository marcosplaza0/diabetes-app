// Archivo: lib/main.dart
// Descripción: Punto de entrada principal de la aplicación Diabetes App.
// Este archivo es responsable de inicializar la aplicación Flutter, configurar
// los servicios esenciales como Hive para almacenamiento local, Supabase para la
// conexión con la base de datos en la nube, SharedPreferences para datos simples,
// y los proveedores de estado (Providers) para la inyección de dependencias.
// También configura el tema de la aplicación, la navegación (GoRouter) y la localización.

// Importaciones del SDK de Flutter y paquetes fundamentales
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // Para localización
import 'package:provider/provider.dart'; // Para la gestión de estado e inyección de dependencias
import 'package:hive_flutter/hive_flutter.dart'; // Para el almacenamiento local NoSQL
import 'package:supabase_flutter/supabase_flutter.dart'; // Para la integración con Supabase (backend)
import 'package:shared_preferences/shared_preferences.dart'; // Para almacenamiento simple de clave-valor

// Importaciones de configuración y utilidades del proyecto
import 'package:diabetes_2/core/utils/go_router.dart'; // Configuración de rutas de navegación
import 'package:diabetes_2/core/theme/app_colors.dart'; // Define los temas claro y oscuro (AppTheme)
import 'package:diabetes_2/core/theme/theme_provider.dart'; // Gestor del tema actual (claro/oscuro/sistema)

// Importaciones de modelos de datos de la aplicación
import 'package:diabetes_2/data/models/logs/logs.dart'; // Modelos para registros de comida y noche
import 'package:diabetes_2/data/models/profile/user_profile_data.dart'; // Modelo para datos del perfil de usuario
import 'package:diabetes_2/data/models/calculations/daily_calculation_data.dart'; // Modelo para cálculos diarios

// Importaciones de servicios de la aplicación
import 'package:diabetes_2/core/services/image_cache_service.dart'; // Servicio para la caché de imágenes
import 'package:diabetes_2/core/services/diabetes_calculator_service.dart'; // Servicio para cálculos relacionados con la diabetes
import 'package:diabetes_2/core/services/supabase_log_sync_service.dart'; // Servicio para sincronizar logs con Supabase

// Importaciones de repositorios (abstracciones para el acceso a datos)
import 'package:diabetes_2/data/repositories/log_repository.dart'; // Interfaz del repositorio de logs
import 'package:diabetes_2/data/repositories/log_repository_impl.dart'; // Implementación del repositorio de logs
import 'package:diabetes_2/data/repositories/calculation_data_repository.dart'; // Interfaz del repositorio de datos de cálculo
import 'package:diabetes_2/data/repositories/calculation_data_repository_impl.dart'; // Implementación del repositorio de datos de cálculo
import 'package:diabetes_2/data/repositories/user_profile_repository.dart'; // Interfaz del repositorio de perfil de usuario
import 'package:diabetes_2/data/repositories/user_profile_repository_impl.dart'; // Implementación del repositorio de perfil de usuario

// Importaciones de ViewModels para las diferentes features/pantallas
import 'package:diabetes_2/features/food_injections/presentation/food_injections_view_model.dart'; // VM para la calculadora de dosis
import 'package:diabetes_2/features/notes/presentation/diabetes_log_view_model.dart'; // VM para la pantalla de registro de notas
import 'package:diabetes_2/features/trends/presentation/trends_view_model.dart'; // VM para la pantalla de resumen de tendencias
import 'package:diabetes_2/features/trends_graphs/presentation/tendencias_graph_view_model.dart'; // VM para los gráficos de tendencias
import 'package:diabetes_2/features/settings/presentation/settings_view_model.dart'; // VM para la pantalla de ajustes
import 'package:diabetes_2/core/auth/presentation/account_view_model.dart'; // VM para la pantalla de gestión de cuenta

// Constantes para los nombres de las cajas de Hive (almacenamiento local)
// Estas constantes aseguran que los nombres de las cajas sean consistentes a lo largo de la app.
const String mealLogBoxName = 'meal_logs'; // Caja para los registros de comidas (MealLog)
const String overnightLogBoxName = 'overnight_logs'; // Caja para los registros nocturnos (OvernightLog)
const String userProfileBoxName = "user_profile_box"; // Caja para el perfil del usuario (UserProfileData)
const String dailyCalculationsBoxName = 'daily_calculations_box'; // Caja para los cálculos diarios (DailyCalculationData)

/// Función principal `main`: Punto de entrada de la aplicación Flutter.
///
/// Realiza las siguientes tareas de inicialización de forma asíncrona:
/// 1.  Asegura la inicialización de los bindings de Flutter.
/// 2.  Inicializa Hive para el almacenamiento local, especificando un subdirectorio.
/// 3.  Registra los adaptadores de Hive para los modelos de datos personalizados.
/// 4.  Abre todas las cajas de Hive necesarias para la aplicación.
/// 5.  Inicializa `ThemeProvider` e `ImageCacheService`.
/// 6.  Inicializa `SharedPreferences`.
/// 7.  Inicializa Supabase con la URL y la clave anónima.
/// 8.  Crea instancias de los servicios y repositorios.
/// 9.  Configura `MultiProvider` para la inyección de dependencias de los ViewModels y servicios.
/// 10. Ejecuta la aplicación principal `DiabetesApp`.
Future<void> main() async {
  // Asegura que el motor de Flutter esté completamente inicializado antes de continuar.
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Hive en un subdirectorio específico para organizar los datos de la app.
  await Hive.initFlutter('diabetesAppData');

  // Registra los adaptadores generados por Hive para cada modelo de datos personalizado.
  // Esto permite a Hive entender cómo serializar y deserializar estos objetos.
  Hive.registerAdapter(MealLogAdapter());
  Hive.registerAdapter(OvernightLogAdapter());
  Hive.registerAdapter(UserProfileDataAdapter());
  Hive.registerAdapter(DailyCalculationDataAdapter());

  // Abre las cajas de Hive. Es una operación asíncrona.
  // Se especifica el tipo de dato que contendrá cada caja para seguridad de tipos.
  final mealLogBox = await Hive.openBox<MealLog>(mealLogBoxName);
  final overnightLogBox = await Hive.openBox<OvernightLog>(overnightLogBoxName);
  final userProfileBox = await Hive.openBox<UserProfileData>(userProfileBoxName);
  final dailyCalculationsBox = await Hive.openBox<DailyCalculationData>(dailyCalculationsBoxName);

  // Crea instancias de servicios que se inicializan una vez.
  final themeProvider = ThemeProvider(); // Gestiona el tema de la aplicación.
  final imageCacheService = ImageCacheService(); // Gestiona la caché de imágenes.
  await imageCacheService.init(); // Inicializa el servicio de caché de imágenes (puede ser asíncrono).

  // Inicializa SharedPreferences para almacenar datos simples persistentes.
  final sharedPreferences = await SharedPreferences.getInstance();

  // Inicializa Supabase, el backend como servicio (BaaS).
  // Se proporcionan la URL del proyecto Supabase y la clave anónima (anon key).
  // Estas claves son sensibles y normalmente se gestionarían a través de variables de entorno
  // o un sistema de configuración más seguro en un proyecto productivo.
  await Supabase.initialize(
    anonKey: "",
    url: "",
  );

  // Obtiene el cliente de Supabase para interactuar con el backend.
  final supabaseClient = Supabase.instance.client;
  // Inicializa el servicio de sincronización de logs con Supabase.
  final supabaseLogSyncService = SupabaseLogSyncService();

  // Crea las instancias de los repositorios, inyectando sus dependencias (cajas de Hive, servicios).
  // Los repositorios abstraen la lógica de acceso y manipulación de datos.
  final logRepository = LogRepositoryImpl(
    mealLogBox: mealLogBox,
    overnightLogBox: overnightLogBox,
    supabaseLogSyncService: supabaseLogSyncService,
    sharedPreferences: sharedPreferences,
  );

  final calculationDataRepository = CalculationDataRepositoryImpl(
    dailyCalculationsBox: dailyCalculationsBox,
    supabaseLogSyncService: supabaseLogSyncService,
    sharedPreferences: sharedPreferences,
  );

  // El servicio de calculadora depende de los repositorios para acceder a los datos necesarios para los cálculos.
  final diabetesCalculatorService = DiabetesCalculatorService(
    logRepository: logRepository,
    calculationDataRepository: calculationDataRepository,
  );

  final userProfileRepository = UserProfileRepositoryImpl(
    userProfileBox: userProfileBox,
    supabaseClient: supabaseClient,
    imageCacheService: imageCacheService,
  );

  // Ejecuta la aplicación Flutter, envolviéndola con `MultiProvider`.
  // `MultiProvider` permite inyectar múltiples dependencias (ViewModels, servicios, repositorios)
  // en el árbol de widgets, haciéndolos accesibles a los widgets descendientes que los necesiten.
  runApp(
      MultiProvider(
        providers: [
          // Proveedores para servicios y configuración global
          ChangeNotifierProvider(create: (_) => themeProvider), // Para cambiar el tema dinámicamente
          Provider<ImageCacheService>(create: (_) => imageCacheService), // Servicio de caché de imágenes
          Provider<SharedPreferences>(create: (_) => sharedPreferences), // Acceso a SharedPreferences
          Provider<SupabaseLogSyncService>(create: (_) => supabaseLogSyncService), // Servicio de sincronización con Supabase

          // Proveedores para repositorios
          Provider<LogRepository>(create: (_) => logRepository), // Repositorio de logs
          Provider<DiabetesCalculatorService>(create: (_) => diabetesCalculatorService), // Servicio de cálculos
          Provider<CalculationDataRepository>(create: (_) => calculationDataRepository), // Repositorio de datos de cálculo
          Provider<UserProfileRepository>(create: (_) => userProfileRepository), // Repositorio de perfil de usuario

          // Proveedores para ViewModels (usando `ChangeNotifierProvider` para aquellos que notifican cambios)
          // Los ViewModels obtienen sus dependencias (otros servicios o repositorios) del `context`
          // usando `Provider.of<T>(context, listen: false)` para evitar escuchas innecesarias durante la creación.
          ChangeNotifierProvider(
            create: (context) => FoodInjectionsViewModel(
              calculatorService: Provider.of<DiabetesCalculatorService>(context, listen: false),
            ),
          ),
          ChangeNotifierProvider(
            create: (context) => DiabetesLogViewModel(
              logRepository: Provider.of<LogRepository>(context, listen: false),
              calculatorService: Provider.of<DiabetesCalculatorService>(context, listen: false),
              supabaseLogSyncService: Provider.of<SupabaseLogSyncService>(context, listen: false),
              dailyCalculationsBox: dailyCalculationsBox, // Pasa la caja directamente si es necesario para operaciones específicas
            ),
          ),
          ChangeNotifierProvider(
            create: (context) => TrendsViewModel(
              logRepository: Provider.of<LogRepository>(context, listen: false),
              calculationDataRepository: Provider.of<CalculationDataRepository>(context, listen: false),
            ),
          ),
          ChangeNotifierProvider(
            create: (context) => TendenciasGraphViewModel(
              logRepository: Provider.of<LogRepository>(context, listen: false),
              calculatorService: Provider.of<DiabetesCalculatorService>(context, listen: false),
            ),
          ),
          ChangeNotifierProvider(
            create: (context) => SettingsViewModel(
              sharedPreferences: Provider.of<SharedPreferences>(context, listen: false),
              logSyncService: Provider.of<SupabaseLogSyncService>(context, listen: false),
              logRepository: Provider.of<LogRepository>(context, listen: false),
              themeProvider: Provider.of<ThemeProvider>(context, listen: false),
            ),
          ),
          ChangeNotifierProvider(
            create: (context) => AccountViewModel(
              userProfileRepository: Provider.of<UserProfileRepository>(context, listen: false),
              imageCacheService: Provider.of<ImageCacheService>(context, listen: false),
              supabaseClient: supabaseClient, // Pasa el cliente de Supabase directamente
              logSyncService: Provider.of<SupabaseLogSyncService>(context, listen: false),
              sharedPreferences: sharedPreferences, // Pasa SharedPreferences
            ),
          ),
        ],
        // El widget raíz de la aplicación.
        child: const DiabetesApp(),
      )
  );
}

// Instancia global del cliente de Supabase.
// Es accesible en toda la aplicación para operaciones directas con Supabase si es necesario,
// aunque se prefiere el uso a través de repositorios o servicios.
final supabase = Supabase.instance.client;

/// Clase principal de la aplicación `DiabetesApp`.
///
/// Es un `StatelessWidget` que configura `MaterialApp.router`.
/// Utiliza `Provider.of<ThemeProvider>` para obtener el estado del tema actual
/// y lo aplica a la aplicación. También configura el sistema de enrutamiento
/// (`GoRouterUtils.router`) y los delegados de localización.
class DiabetesApp extends StatelessWidget {
  const DiabetesApp({super.key});

  @override
  /// Construye la interfaz de usuario principal de la aplicación.
  ///
  /// Retorna un `MaterialApp.router` configurado con:
  /// - Título de la aplicación.
  /// - Temas claro (`AppTheme.light`) y oscuro (`AppTheme.dark`).
  /// - Modo de tema actual (`themeProvider.themeMode`).
  /// - Configuración de rutas (`GoRouterUtils.router`).
  /// - Delegados de localización para soportar múltiples idiomas (aunque aquí solo se configuran los globales).
  /// - Oculta el banner de "debug" en la esquina superior derecha.
  Widget build(BuildContext context) {
    // Obtiene el ThemeProvider del contexto para acceder al modo de tema actual.
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp.router(
      title: 'App Diabetes', // Título de la aplicación que aparece, por ejemplo, en la lista de apps recientes.
      theme: AppTheme.light, // Tema claro de la aplicación.
      darkTheme: AppTheme.dark, // Tema oscuro de la aplicación.
      themeMode: themeProvider.themeMode, // Determina qué tema usar (claro, oscuro o el del sistema).
      routerConfig: GoRouterUtils.router, // Configuración de las rutas de navegación de la app.
      localizationsDelegates: const [ // Configuración para la internacionalización y localización.
        GlobalMaterialLocalizations.delegate, // Localizaciones para widgets de Material Design.
        GlobalWidgetsLocalizations.delegate, // Localizaciones para widgets básicos de Flutter.
        GlobalCupertinoLocalizations.delegate, // Localizaciones para widgets de estilo Cupertino (iOS).
      ],
      debugShowCheckedModeBanner: false, // Oculta la cinta "DEBUG" en la esquina de la app.
    );
  }
}

/// Extensión sobre `BuildContext` para añadir funcionalidades útiles.
extension ContextExtension on BuildContext {
  /// Muestra un `SnackBar` con un mensaje.
  ///
  /// [message]: El texto a mostrar en el SnackBar.
  /// [isError]: Booleano opcional (default `false`). Si es `true`,
  ///            el SnackBar usará el color de error del tema; de lo contrario,
  ///            usará el color de fondo predeterminado del SnackBar del tema.
  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(this).colorScheme.error // Color de error si `isError` es true.
            : Theme.of(this).snackBarTheme.backgroundColor, // Color por defecto del SnackBar.
      ),
    );
  }
}