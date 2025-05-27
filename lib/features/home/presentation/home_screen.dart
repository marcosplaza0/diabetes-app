// Archivo: home_screen.dart
// Descripción: Pantalla principal de la aplicación que muestra un resumen de la información
// más relevante para el usuario, como niveles de azúcar, notas y gráficas.

import 'package:flutter/material.dart';

import 'package:diabetes_2/core/layout/main_layout.dart';
import 'package:go_router/go_router.dart';
import '../widgets/glucose_lever_indicator.dart';

/// Widget que representa la pantalla de inicio de la aplicación.
/// Muestra un resumen de la información más importante para el usuario.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  /// Construye la interfaz de usuario de la pantalla de inicio.
  /// Organiza los diferentes widgets informativos en una columna vertical.
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Inicio',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlucoseLevelIndicator(glucoseLevel: 100),

          // Notas (Contenedor)
          Container(
            height: 100, // Ajusta la altura según necesites
            decoration: BoxDecoration(
              color: Colors.green[100], // Color de fondo temporal
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(child: Text('Aquí irá el widget de las notas')),
          ),
          const SizedBox(height: 16),

          // Gráfica (Contenedor)
          Container(
            height: 200, // Ajusta la altura según necesites
            decoration: BoxDecoration(
              color: Colors.orange[100], // Color de fondo temporal
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(child: Text('Aquí irá el widget de la gráfica')),
          ),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child:
            // Botón Añadir Nota (Contenedor)
            ElevatedButton.icon(
              icon: const Icon(Icons.add_comment_rounded), // Icono para el botón
              label: const Text('Añadir Nota'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor, // Color primario del tema
                foregroundColor: Colors.white, // Color del texto e icono
                padding: const EdgeInsets.symmetric(vertical: 16), // Padding interno
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10), // Bordes redondeados
                ),
                elevation: 4, // Elevación para efecto de sombra
              ),
              onPressed: () {
                context.push('/diabetes-log/new');
              },
            ),
          )
        ],
      ),
    );
  }
}
