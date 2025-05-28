// Archivo: home_screen.dart
import 'package:flutter/material.dart';
import 'package:diabetes_2/core/layout/main_layout.dart';
import 'package:go_router/go_router.dart';

import 'package:diabetes_2/features/home/widgets/recent_logs_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Acceso fácil al tema

    return MainLayout(
      title: 'Inicio',
      body: Padding( // Añadir un padding general a la pantalla de inicio
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Contenedor para los iconos de logs recientes
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0), // Padding interno
              decoration: BoxDecoration(
                // Usar un color de superficie del tema para el fondo
                color: theme.colorScheme.surfaceContainerHigh, // O surfaceContainer, secondaryContainer si quieres más color
                borderRadius: BorderRadius.circular(12), // Radio M3
                // Considerar un borde sutil si es necesario
                border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.5),
              ),
              child: const RecentLogsWidget(), // El widget de logs recientes
            ),
            const SizedBox(height: 20), // Mayor espaciado M3

            // Gráfica (Contenedor)
            Container(
              height: 200, // Mantener altura o ajustar según necesidad
              padding: const EdgeInsets.all(16.0), // Padding para el contenido interno de la gráfica
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest, // Un color de superficie para la gráfica
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'Aquí irá el widget de la gráfica',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Botón "Añadir Nota"
            ElevatedButton.icon(
              icon: const Icon(Icons.add_comment_rounded),
              label: const Text('Añadir Nota'),
              // El estilo se tomará del ElevatedButtonTheme definido en AppTheme
              // Ya no es necesario especificar backgroundColor o foregroundColor aquí
              // a menos que quieras un estilo muy específico para ESTE botón en particular.
              // Si se deja vacío, usará el tema global de ElevatedButton.
              style: ElevatedButton.styleFrom(
                // Si necesitas forzar el color primario (aunque el tema ya debería hacerlo)
                // backgroundColor: theme.colorScheme.primary,
                // foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16), // Padding M3
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12), // Radio M3
                ),
                // La elevación también se maneja por el tema
              ),
              onPressed: () {
                context.push('/diabetes-log/new');
              },
            ),
          ],
        ),
      ),
    );
  }
}