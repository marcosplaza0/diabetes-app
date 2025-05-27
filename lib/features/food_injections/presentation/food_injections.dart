// Archivo: food_injections.dart
// Descripción: Pantalla que muestra y gestiona los registros de comidas e inyecciones del usuario.
// Permite navegar entre diferentes fechas para ver y editar los registros.

import 'package:flutter/material.dart';
import 'package:diabetes_2/core/layout/main_layout.dart';

/// Widget que representa la pantalla de comidas e inyecciones de la aplicación.
/// Permite al usuario ver y gestionar los registros de comidas e inyecciones organizados por fecha.
class FoodInjectionsScreen extends StatelessWidget {
  const FoodInjectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Comida / Inyecciones',
      body: Text("hola mundo")
    );
  }

}
