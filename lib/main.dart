// Archivo: main.dart
// Descripción: Punto de entrada principal de la aplicación de diabetes. 
// Este archivo configura la aplicación Flutter, incluyendo el tema, 
// la navegación y las configuraciones de localización.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:diabetes_2/core/utils/go_router.dart';
import 'package:diabetes_2/core/theme/app_colors.dart';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:diabetes_2/data/models/logs/logs.dart';
import 'package:diabetes_2/data/models/profile/user_profile_data.dart';
import 'package:diabetes_2/data/models/calculations/daily_calculation_data.dart';
import 'package:diabetes_2/core/services/image_cache_service.dart';
import 'package:provider/provider.dart';
import 'package:diabetes_2/core/services/diabetes_calculator_service.dart'; // Importa el servicio


import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/theme_provider.dart';


import 'package:diabetes_2/data/repositories/log_repository.dart';
import 'package:diabetes_2/data/repositories/log_repository_impl.dart';
import 'package:diabetes_2/data/repositories/calculation_data_repository.dart';
import 'package:diabetes_2/data/repositories/calculation_data_repository_impl.dart';

import 'package:diabetes_2/data/repositories/user_profile_repository.dart';
import 'package:diabetes_2/data/repositories/user_profile_repository_impl.dart';

import 'package:diabetes_2/core/services/supabase_log_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:diabetes_2/features/food_injections/presentation/food_injections_view_model.dart'; // Importar el ViewModel
import 'package:diabetes_2/features/notes/presentation/diabetes_log_view_model.dart';
import 'package:diabetes_2/features/trends/presentation/trends_view_model.dart'; // Importar el ViewModel
import 'package:diabetes_2/features/trends_graphs/presentation/tendencias_graph_view_model.dart'; // Importar ViewModel
import 'package:diabetes_2/features/settings/presentation/settings_view_model.dart'; // Importar ViewModel



const String mealLogBoxName = 'meal_logs';
const String overnightLogBoxName = 'overnight_logs';
const String userProfileBoxName = "user_profile_box";
const String dailyCalculationsBoxName = 'daily_calculations_box';

/// Función principal que inicia la aplicación
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter('diabetesAppData');

  Hive.registerAdapter(MealLogAdapter());
  Hive.registerAdapter(OvernightLogAdapter());
  Hive.registerAdapter(UserProfileDataAdapter());
  Hive.registerAdapter(DailyCalculationDataAdapter());

  final mealLogBox = await Hive.openBox<MealLog>(mealLogBoxName);
  final overnightLogBox = await Hive.openBox<OvernightLog>(overnightLogBoxName);
  final userProfileBox = await Hive.openBox<UserProfileData>(userProfileBoxName);
  final dailyCalculationsBox = await Hive.openBox<DailyCalculationData>(dailyCalculationsBoxName);


  final themeProvider = ThemeProvider();
  final imageCacheService = ImageCacheService();
  await imageCacheService.init();

  // Inicializar SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();

  await Supabase.initialize(
    anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZwanRkZHl5YnhybHhmamhzd256Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDgyOTQwMDAsImV4cCI6MjA2Mzg3MDAwMH0.ABU_Vfh6h9C8iF1MSxAdTyJXX7LufSpQWX58opMKYQ0",
    url: "https://fpjtddyybxrlxfjhswnz.supabase.co",
  );

  final supabaseClient = Supabase.instance.client; // Obtener el cliente de Supabase
  final supabaseLogSyncService = SupabaseLogSyncService();

  // Crear la instancia de LogRepository que DiabetesCalculatorService necesitará
  final logRepository = LogRepositoryImpl(
    mealLogBox: mealLogBox,
    overnightLogBox: overnightLogBox,
    supabaseLogSyncService: supabaseLogSyncService,
    sharedPreferences: sharedPreferences,
  );

  // Crear la instancia de CalculationDataRepository
  final calculationDataRepository = CalculationDataRepositoryImpl(
    dailyCalculationsBox: dailyCalculationsBox, // Pasar la instancia abierta
    supabaseLogSyncService: supabaseLogSyncService,
    sharedPreferences: sharedPreferences,
  );

  final diabetesCalculatorService = DiabetesCalculatorService(
    logRepository: logRepository,
    calculationDataRepository: calculationDataRepository, // <-- Pasar la nueva dependencia
  );

  final userProfileRepository = UserProfileRepositoryImpl(
    userProfileBox: userProfileBox, // Pasar la instancia abierta
    supabaseClient: supabaseClient, // Pasar el cliente de Supabase
    imageCacheService: imageCacheService, // Pasar el ImageCacheService
  );


  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => themeProvider),
        Provider<ImageCacheService>(create: (_) => imageCacheService),
        Provider<SharedPreferences>(create: (_) => sharedPreferences), // Proveer SharedPreferences
        Provider<SupabaseLogSyncService>(create: (_) => supabaseLogSyncService), // Proveer el servicio de sync
        Provider<LogRepository>(create: (_) => logRepository),
        Provider<DiabetesCalculatorService>(create: (_) => diabetesCalculatorService),
        Provider<CalculationDataRepository>(create: (_) => calculationDataRepository),
        Provider<UserProfileRepository>(create: (_) => userProfileRepository),
        ChangeNotifierProvider(
          create: (context) => FoodInjectionsViewModel(
            // Obtener DiabetesCalculatorService de los providers ya existentes
            calculatorService: Provider.of<DiabetesCalculatorService>(context, listen: false),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => DiabetesLogViewModel(
            logRepository: Provider.of<LogRepository>(context, listen: false),
            calculatorService: Provider.of<DiabetesCalculatorService>(context, listen: false),
            supabaseLogSyncService: Provider.of<SupabaseLogSyncService>(context, listen: false), // Para DailyCalcData sync
            dailyCalculationsBox: dailyCalculationsBox, // Pasar la caja directamente
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
            themeProvider: Provider.of<ThemeProvider>(context, listen: false), // Pasar ThemeProvider
          ),
        ),
      ],
      child: const DiabetesApp(),
    )
  );
}

final supabase = Supabase.instance.client;

/// Clase principal de la aplicación que configura el tema, 
/// el enrutador y las configuraciones de localización
class DiabetesApp extends StatelessWidget {
  const DiabetesApp({super.key});

  @override
  /// Construye la interfaz de usuario principal de la aplicación
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp.router(
      title: 'App Diabetes',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeProvider.themeMode,
      routerConfig: GoRouterUtils.router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
    );
  }
}

extension ContextExtension on BuildContext {
  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(this).colorScheme.error
            : Theme.of(this).snackBarTheme.backgroundColor,
      ),
    );
  }
}
