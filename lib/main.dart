// Archivo: main.dart
// Descripción: Punto de entrada principal de la aplicación de diabetes. 
// Este archivo configura la aplicación Flutter, incluyendo el tema, 
// la navegación y las configuraciones de localización.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:diabetes_2/core/utils/go_router.dart';
import 'package:diabetes_2/core/theme/app_colors.dart';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:diabetes_2/data/transfer_objects/logs.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

const String mealLogBoxName = 'meal_logs';
const String overnightLogBoxName = 'overnight_logs';
late Box<Uint8List> avatarCacheBox;

/// Función principal que inicia la aplicación
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter('diabetesAppData');

  Hive.registerAdapter(MealLogAdapter());
  Hive.registerAdapter(OvernightLogAdapter());

  await Hive.openBox<MealLog>(mealLogBoxName);
  await Hive.openBox<OvernightLog>(overnightLogBoxName);
  final appDocumentDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDir.path);
  avatarCacheBox = await Hive.openBox<Uint8List>('avatarCache');

  await Supabase.initialize(
    anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZwanRkZHl5YnhybHhmamhzd256Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDgyOTQwMDAsImV4cCI6MjA2Mzg3MDAwMH0.ABU_Vfh6h9C8iF1MSxAdTyJXX7LufSpQWX58opMKYQ0",
    url: "https://fpjtddyybxrlxfjhswnz.supabase.co",
  );

  runApp(const DiabetesApp());
}

final supabase = Supabase.instance.client;

/// Clase principal de la aplicación que configura el tema, 
/// el enrutador y las configuraciones de localización
class DiabetesApp extends StatelessWidget {
  const DiabetesApp({super.key});

  @override
  /// Construye la interfaz de usuario principal de la aplicación
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'App Diabetes',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
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