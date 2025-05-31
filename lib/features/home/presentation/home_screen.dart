// lib/features/home/presentation/home_screen.dart
import 'package:flutter/material.dart';
import 'package:diabetes_2/core/layout/main_layout.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Necesario para ValueListenableBuilder
import 'package:intl/intl.dart'; // Para formatear fechas y horas
import 'package:collection/collection.dart'; // Para .sortedBy y .lastOrNull


import 'package:diabetes_2/features/home/widgets/recent_logs_widget.dart';
import 'package:diabetes_2/features/home/widgets/current_insulin_needs_widget.dart';
import 'package:diabetes_2/data/models/logs/logs.dart'; // Para MealLog
import 'package:diabetes_2/main.dart' show mealLogBoxName; // Para el nombre de la caja

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Widget _buildSectionTitle(String title, ThemeData theme, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0), // Ajusta según sea necesario
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MainLayout(
      title: 'Inicio',
      body: ListView( // Usar ListView para contenido potencialmente desplazable
        padding: const EdgeInsets.all(16.0), // Padding general para el contenido del ListView
        children: [
          // Widget opcional de Bienvenida Personalizada (ejemplo conceptual)
          // Padding(
          //   padding: const EdgeInsets.only(bottom: 16.0),
          //   child: Text(
          //     "¡Hola, [NombreUsuario]!", // Reemplazar con el nombre real del usuario
          //     style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary),
          //   ),
          // ),

          _buildSectionTitle("De un Vistazo", theme, context),
          const LastGlucoseReadingWidget(), // Nuevo widget
          const SizedBox(height: 20),

          _buildSectionTitle("Estimación de Insulina", theme, context),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
            color: theme.colorScheme.surfaceContainerHigh, // Color de superficie M3
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: CurrentInsulinNeedsWidget(),
            ),
          ),
          const SizedBox(height: 20),

          _buildSectionTitle("Registros Recientes (Últimas 24h)", theme, context),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
            color: theme.colorScheme.surfaceContainer, // Otro tono de superficie M3
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
              child: RecentLogsWidget(),
            ),
          ),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            icon: const Icon(Icons.note_add_outlined), // Icono actualizado
            label: const Text('Añadir Nuevo Registro'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              textStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0), // Radio M3 consistente
              ),
              elevation: 2,
            ),
            onPressed: () {
              context.push('/diabetes-log/new'); //
            },
          ),
          const SizedBox(height: 20), // Espacio al final si es un ListView
        ],
      ),
    );
  }
}

// Widget para mostrar la última lectura de glucosa
class LastGlucoseReadingWidget extends StatelessWidget {
  const LastGlucoseReadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mealLogBox = Hive.box<MealLog>(mealLogBoxName);

    return ValueListenableBuilder<Box<MealLog>>(
      valueListenable: mealLogBox.listenable(),
      builder: (context, box, _) {
        DateTime? latestTime;
        double? latestGlucose;
        String latestType = "";

        if (box.values.isNotEmpty) {
          var allGlucoseEvents = <Map<String, dynamic>>[];
          for (var log in box.values) {
            allGlucoseEvents.add({'time': log.startTime, 'value': log.initialBloodSugar, 'type': 'Inicial'});
            if (log.endTime != null && log.finalBloodSugar != null) {
              allGlucoseEvents.add({'time': log.endTime!, 'value': log.finalBloodSugar!, 'type': 'Final'});
            }
          }
          // Ordenar para obtener el evento más reciente
          allGlucoseEvents.sort((a, b) => (b['time'] as DateTime).compareTo(a['time'] as DateTime));

          if (allGlucoseEvents.isNotEmpty) {
            latestTime = allGlucoseEvents.first['time'] as DateTime;
            latestGlucose = allGlucoseEvents.first['value'] as double;
            latestType = allGlucoseEvents.first['type'] as String;
          }
        }

        Color glucoseColor = theme.colorScheme.onSurface;
        if (latestGlucose != null) {
          if (latestGlucose < 70) glucoseColor = theme.colorScheme.error;
          else if (latestGlucose > 180) glucoseColor = Colors.orange.shade700; // Un color distintivo para hiper
          else glucoseColor = Colors.green.shade600;
        }

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          color: theme.colorScheme.surfaceContainerHigh,
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Icon(Icons.water_drop_outlined, color: glucoseColor, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        latestGlucose != null ? "${latestGlucose.toStringAsFixed(0)} mg/dL" : "-- mg/dL",
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: glucoseColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        latestTime != null ? "${latestType} - ${DateFormat('HH:mm', 'es_ES').format(latestTime)}" : "Sin registros recientes",
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (latestTime != null)
                  Text(
                    DateFormat('dd MMM', 'es_ES').format(latestTime), // Solo fecha para no sobrecargar
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Helper para calcular promedio de una lista de doubles (si no lo tienes ya)
extension DoubleListAverage on List<double> {
  double? get averageOrNull => isEmpty ? null : reduce((a, b) => a + b) / length;
}