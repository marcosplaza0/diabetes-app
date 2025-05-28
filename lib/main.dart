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
import 'package:diabetes_2/core/services/image_cache_service.dart';
import 'package:provider/provider.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/theme_provider.dart';

const String mealLogBoxName = 'meal_logs';
const String overnightLogBoxName = 'overnight_logs';
const String userProfileBoxName = "user_profile_box";

/// Función principal que inicia la aplicación
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter('diabetesAppData');

  Hive.registerAdapter(MealLogAdapter());
  Hive.registerAdapter(OvernightLogAdapter());
  Hive.registerAdapter(UserProfileDataAdapter());

  await Hive.openBox<MealLog>(mealLogBoxName);
  await Hive.openBox<OvernightLog>(overnightLogBoxName);
  await Hive.openBox<UserProfileData>(userProfileBoxName);

  final themeProvider = ThemeProvider();
  final imageCacheService = ImageCacheService();
  await imageCacheService.init();

  await Supabase.initialize(
    anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZwanRkZHl5YnhybHhmamhzd256Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDgyOTQwMDAsImV4cCI6MjA2Mzg3MDAwMH0.ABU_Vfh6h9C8iF1MSxAdTyJXX7LufSpQWX58opMKYQ0",
    url: "https://fpjtddyybxrlxfjhswnz.supabase.co",
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => themeProvider),
        Provider<ImageCacheService>(create: (_) => imageCacheService),
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
