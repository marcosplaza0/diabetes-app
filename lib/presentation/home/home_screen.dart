// Archivo: home_screen.dart
// Descripción: Pantalla principal de la aplicación que muestra un resumen de la información
// más relevante para el usuario, como niveles de azúcar, notas y gráficas.

import 'package:flutter/material.dart';
import '../layout/main_layout.dart';

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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Nivel de Azúcar (Contenedor)
            Container(
              height: 100, // Ajusta la altura según necesites
              decoration: BoxDecoration(
                color: Colors.blue[100], // Color de fondo temporal
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(child: Text('Aquí irá el widget del nivel de azúcar')),
            ),
            const SizedBox(height: 16),

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

            // Botón Añadir Nota (Contenedor)
            Container(
              height: 60, // Ajusta la altura según necesites
              decoration: BoxDecoration(
                color: Colors.grey[300], // Color de fondo temporal
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(child: Text('Aquí irá el botón de añadir nota')),
            ),
          ],
        ),
      ),
    );
  }
}
