// Archivo: lib/features/home/presentation/home_screen.dart
// Descripción: Define la pantalla principal o de inicio de la aplicación.
// Esta pantalla actúa como un "dashboard", mostrando información relevante de un vistazo,
// como la última lectura de glucosa, una estimación de las necesidades actuales de insulina,
// y accesos directos a registros recientes y la creación de nuevos registros.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:flutter/material.dart'; // Framework principal de Flutter para UI.
import 'package:go_router/go_router.dart'; // Para la navegación entre pantallas.
import 'package:hive_flutter/hive_flutter.dart'; // Para ValueListenableBuilder, escuchando cambios en cajas de Hive.
import 'package:intl/intl.dart'; // Para formateo de fechas y horas.

// Importaciones de archivos del proyecto
import 'package:DiabetiApp/core/layout/main_layout.dart'; // Widget de diseño principal de la pantalla.
import 'package:DiabetiApp/features/home/widgets/recent_logs_widget.dart'; // Widget para mostrar registros recientes.
import 'package:DiabetiApp/features/home/widgets/current_insulin_needs_widget.dart'; // Widget para estimar necesidades de insulina.
import 'package:DiabetiApp/data/models/logs/logs.dart'; // Modelo MealLog, usado por LastGlucoseReadingWidget.
import 'package:DiabetiApp/main.dart' show mealLogBoxName; // Nombre de la caja de Hive para MealLog.

/// HomeScreen: Un StatelessWidget que construye la interfaz de la pantalla de inicio.
///
/// Organiza varios widgets informativos y de acción en un ListView para
/// proporcionar al usuario una visión general rápida y acceso a funciones comunes.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  /// _buildSectionTitle: Widget helper privado para crear títulos de sección estandarizados.
  ///
  /// @param title El texto del título de la sección.
  /// @param theme El ThemeData actual para aplicar estilos.
  /// @param context El BuildContext actual.
  /// @return Un Padding widget que contiene un Text widget estilizado como título.
  Widget _buildSectionTitle(String title, ThemeData theme, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant, // Color semántico para texto menos prominente.
          fontWeight: FontWeight.w600, // Un peso de fuente para destacar el título.
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Obtiene el tema actual para estilos.

    // Utiliza MainLayout como estructura base de la pantalla, proveyendo AppBar y Drawer.
    return MainLayout(
      title: 'Inicio', // Título que aparecerá en la AppBar.
      body: ListView( // Permite el desplazamiento si el contenido excede la pantalla.
        padding: const EdgeInsets.all(16.0), // Padding general para el contenido del ListView.
        children: [
          // Sección "De un Vistazo" con la última lectura de glucosa.
          _buildSectionTitle("De un Vistazo", theme, context),
          const LastGlucoseReadingWidget(), // Muestra la lectura de glucosa más reciente.
          const SizedBox(height: 20), // Espaciador vertical.

          // Sección "Estimación de Insulina".
          _buildSectionTitle("Estimación de Insulina", theme, context),
          Card( // Envuelve CurrentInsulinNeedsWidget en una Card para un mejor diseño visual.
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
            color: theme.colorScheme.surfaceContainerHigh, // Color de superficie de Material 3.
            clipBehavior: Clip.antiAlias, // Para que los bordes redondeados se apliquen correctamente.
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: CurrentInsulinNeedsWidget(), // Widget que estima la necesidad de insulina.
            ),
          ),
          const SizedBox(height: 20),

          // Sección "Registros Recientes".
          _buildSectionTitle("Registros Recientes (Últimas 24h)", theme, context),
          Card( // Envuelve RecentLogsWidget en una Card.
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
            color: theme.colorScheme.surfaceContainer, // Otro tono de superficie de Material 3.
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
              child: RecentLogsWidget(), // Widget que muestra iconos de registros recientes.
            ),
          ),
          const SizedBox(height: 24),

          // Botón para añadir un nuevo registro.
          ElevatedButton.icon(
            icon: const Icon(Icons.note_add_outlined), // Icono para el botón.
            label: const Text('Añadir Nuevo Registro'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary, // Color primario para el botón.
              foregroundColor: theme.colorScheme.onPrimary, // Color del texto e icono sobre el primario.
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              textStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0), // Bordes redondeados consistentes con M3.
              ),
              elevation: 2,
            ),
            onPressed: () {
              // Navega a la pantalla de creación de un nuevo log de diabetes.
              // '/diabetes-log/new' es la ruta definida en GoRouter para esta acción.
              context.push('/diabetes-log/new'); //
            },
          ),
          const SizedBox(height: 20), // Espacio al final del ListView.
        ],
      ),
    );
  }
}

/// LastGlucoseReadingWidget: Un StatelessWidget que muestra la última lectura de glucosa registrada.
///
/// Escucha cambios en la caja de `MealLog` de Hive usando `ValueListenableBuilder`.
/// Procesa los logs para encontrar el evento de glucosa más reciente (ya sea inicial o final)
/// y lo muestra junto con la hora y un indicador de color según el valor de la glucosa.
class LastGlucoseReadingWidget extends StatelessWidget {
  const LastGlucoseReadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mealLogBox = Hive.box<MealLog>(mealLogBoxName); // Accede a la caja de MealLog.

    // ValueListenableBuilder reconstruye este widget cuando hay cambios en mealLogBox.
    return ValueListenableBuilder<Box<MealLog>>(
      valueListenable: mealLogBox.listenable(),
      builder: (context, box, _) { // `box` es la instancia actualizada de MealLogBox.
        DateTime? latestTime; // Hora del último evento de glucosa.
        double? latestGlucose; // Valor de la última glucosa.
        String latestType = ""; // Tipo de evento ("Inicial" o "Final").

        // Procesa los logs si la caja no está vacía.
        if (box.values.isNotEmpty) {
          var allGlucoseEvents = <Map<String, dynamic>>[]; // Lista para almacenar todos los eventos de glucosa.
          // Itera sobre todos los MealLog en la caja.
          for (var log in box.values) {
            // Añade la glucosa inicial y su hora.
            allGlucoseEvents.add({'time': log.startTime, 'value': log.initialBloodSugar, 'type': 'Inicial'}); //
            // Si existe glucosa final y hora final, también se añaden.
            if (log.endTime != null && log.finalBloodSugar != null) { //
              allGlucoseEvents.add({'time': log.endTime!, 'value': log.finalBloodSugar!, 'type': 'Final'}); //
            }
          }
          // Ordena todos los eventos de glucosa por hora en orden descendente (más reciente primero).
          allGlucoseEvents.sort((a, b) => (b['time'] as DateTime).compareTo(a['time'] as DateTime));

          // Si hay eventos, toma el primero (el más reciente).
          if (allGlucoseEvents.isNotEmpty) {
            latestTime = allGlucoseEvents.first['time'] as DateTime;
            latestGlucose = allGlucoseEvents.first['value'] as double;
            latestType = allGlucoseEvents.first['type'] as String;
          }
        }

        // Determina el color del texto de la glucosa según su valor.
        Color glucoseColor = theme.colorScheme.onSurface; // Color por defecto.
        if (latestGlucose != null) {
          if (latestGlucose < 70) glucoseColor = theme.colorScheme.error; // Hipoglucemia.
          else if (latestGlucose > 180) glucoseColor = Colors.orange.shade700; // Hiperglucemia.
          else glucoseColor = Colors.green.shade600; // En rango.
        }

        // Construye la Card que muestra la información.
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          color: theme.colorScheme.surfaceContainerHigh,
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Icon(Icons.water_drop_outlined, color: glucoseColor, size: 36), // Icono con el color de la glucosa.
                const SizedBox(width: 12),
                Expanded( // Para que la columna de texto ocupe el espacio disponible.
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        latestGlucose != null ? "${latestGlucose.toStringAsFixed(0)} mg/dL" : "-- mg/dL",
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: glucoseColor, // Aplica el color determinado.
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        latestTime != null ? "$latestType - ${DateFormat('HH:mm', 'es_ES').format(latestTime)}" : "Sin registros recientes",
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                // Muestra la fecha del último registro si existe.
                if (latestTime != null)
                  Text(
                    DateFormat('dd MMM', 'es_ES').format(latestTime), // Formato corto de fecha.
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

// Extensión para calcular el promedio de una lista de doubles.
// Útil si no se importa 'package:collection/collection.dart' que ya tiene 'average'.
// Nota: Esta extensión podría moverse a un archivo de utilidades si se usa en múltiples lugares.
extension DoubleListAverage on List<double> {
  /// Retorna el promedio de los elementos de la lista, o null si la lista está vacía.
  double? get averageOrNull => isEmpty ? null : reduce((a, b) => a + b) / length;
}