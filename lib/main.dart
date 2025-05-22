// Archivo: main.dart
// Descripción: Punto de entrada principal de la aplicación de diabetes. 
// Este archivo configura la aplicación Flutter, incluyendo el tema, 
// la navegación y las configuraciones de localización.

import 'package:flutter/material.dart';
import 'utils/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:diabetes_2/utils/app_colors.dart';

/// Función principal que inicia la aplicación
void main() {
  runApp(const DiabetesApp());
}

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
