// Archivo: daily_log_list_widget.dart
// Descripción: Widget que muestra una lista de notas de comida y noche
// para una fecha específica, obtenidas de Hive, con diseño Material y navegación para editar.

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Para ValueListenableBuilder y Box.listenable()
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart'; // Para la navegación

// Asegúrate que estas rutas sean correctas según tu estructura de proyecto
import 'package:diabetes_2/data/transfer_objects/logs.dart';
// Asumimos que mealLogBoxName y overnightLogBoxName están definidos en tu main.dart o en un archivo de constantes importable.
// Si los definiste en main.dart y no son accesibles globalmente, puedes pasarlos como parámetros
// o definirlos en un archivo de constantes e importarlo aquí y en main.dart.
// Por ahora, asumiré que están disponibles globalmente o los puedes importar desde una ubicación centralizada.
// Ejemplo: import 'package:diabetes_2/core/constants/hive_box_names.dart';
// O, si están en main.dart y los exportaste o son globales:
import 'package:diabetes_2/main.dart';


class DailyLogListWidget extends StatefulWidget {
  final DateTime selectedDate;

  const DailyLogListWidget({
    super.key,
    required this.selectedDate,
  });

  @override
  State<DailyLogListWidget> createState() => _DailyLogListWidgetState();
}

class _DailyLogListWidgetState extends State<DailyLogListWidget> {
  late Box<MealLog> _mealLogBox;
  late Box<OvernightLog> _overnightLogBox;

  @override
  void initState() {
    super.initState();
    // Acceder a las cajas de Hive. Deben estar abiertas desde main.dart
    _mealLogBox = Hive.box<MealLog>(mealLogBoxName); // Usa el nombre de caja definido globalmente/importado
    _overnightLogBox = Hive.box<OvernightLog>(overnightLogBoxName); // Usa el nombre de caja definido globalmente/importado
  }

  List<dynamic> _getFilteredAndSortedLogs() {
    List<dynamic> dailyLogs = [];

    // Filtrar MealLogs para la fecha seleccionada
    for (var mealLog in _mealLogBox.values) {
      // Comparamos solo año, mes y día usando DateUtils.isSameDay
      if (DateUtils.isSameDay(mealLog.startTime, widget.selectedDate)) {
        dailyLogs.add(mealLog);
      }
    }

    // Filtrar OvernightLogs para la fecha seleccionada
    for (var overnightLog in _overnightLogBox.values) {
      if (DateUtils.isSameDay(overnightLog.bedTime, widget.selectedDate)) {
        dailyLogs.add(overnightLog);
      }
    }

    // Ordenar los logs por su hora principal (startTime para MealLog, bedTime para OvernightLog)
    dailyLogs.sort((a, b) {
      DateTime timeA = a is MealLog ? a.startTime : (a as OvernightLog).bedTime;
      DateTime timeB = b is MealLog ? b.startTime : (b as OvernightLog).bedTime;
      return timeA.compareTo(timeB);
    });

    return dailyLogs;
  }

  // Helper widget para mostrar una fila de información con icono, etiqueta y valor
  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value, {Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0), // Un poco más de espacio vertical
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18.0, color: iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8.0),
          Text('$label ', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
          Expanded(
              child: Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.end,
                softWrap: true, // Permite que el texto se ajuste si es muy largo
              )
          ),
        ],
      ),
    );
  }

  Widget _buildMealLogTile(MealLog log) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat.Hm(Localizations.localeOf(context).languageCode);
    final titleStyle = theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface);

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 0), // Ajuste de margen horizontal a 0 si el ListView ya tiene padding
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      clipBehavior: Clip.antiAlias, // Para que el InkWell respete los bordes redondeados
      child: InkWell(
        onTap: () {
          if (log.key != null) {
            final String logKeyString = log.key.toString();
            // USA PUSH O PUSHNAMED
            context.pushNamed(
              'diabetesLogEdit',
              pathParameters: {
                'logTypeString': 'meal',
                'logKeyString': logKeyString,
              },
            );
            // Alternativamente, si prefieres usar el path directamente:
            // context.push('/diabetes-log/edit/meal/$logKeyString');
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Error: No se pudo obtener la clave de la nota."), backgroundColor: Colors.orange)
            );
          }
        },
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer.withOpacity(0.7),
                    radius: 18,
                    child: Icon(Icons.restaurant_menu, color: theme.colorScheme.onPrimaryContainer, size: 20),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Text(
                      'Comida - ${timeFormat.format(log.startTime)}',
                      style: titleStyle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10.0),
              _buildInfoRow(
                  context,
                  Icons.opacity,
                  'Glucosa Inicial:',
                  '${log.initialBloodSugar.toStringAsFixed(0)} mg/dL',
                  iconColor: Colors.redAccent
              ),
              _buildInfoRow(
                  context,
                  Icons.bakery_dining_outlined,
                  'Carbohidratos:',
                  '${log.carbohydrates.toStringAsFixed(0)} g',
                  iconColor: Colors.brown[400]
              ),
              _buildInfoRow(
                  context,
                  Icons.colorize_outlined,
                  'Insulina Rápida:',
                  '${log.insulinUnits.toStringAsFixed(1)} U',
                  iconColor: Colors.blueAccent
              ),
              if (log.finalBloodSugar != null) ...[
                const Divider(height: 16.0, thickness: 0.5, indent: 2, endIndent: 2,),
                _buildInfoRow(
                    context,
                    Icons.opacity_outlined,
                    'Glucosa Final:',
                    '${log.finalBloodSugar?.toStringAsFixed(0)} mg/dL ${log.endTime != null ? "(${timeFormat.format(log.endTime!)})" : ""}',
                    iconColor: Colors.red[300]
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOvernightLogTile(OvernightLog log) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat.Hm(Localizations.localeOf(context).languageCode);
    final titleStyle = theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface);

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 0), // Ajuste de margen horizontal
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (log.key != null) {
            final String logKeyString = log.key.toString();
            context.go('/diabetes-log/edit/overnight/$logKeyString');
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Error: No se pudo obtener la clave de la nota."), backgroundColor: Colors.orange)
            );
          }
        },
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.secondaryContainer.withOpacity(0.7),
                    radius: 18,
                    child: Icon(Icons.bedtime_outlined, color: theme.colorScheme.onSecondaryContainer, size: 20),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Text(
                      'Noche - ${timeFormat.format(log.bedTime)}',
                      style: titleStyle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10.0),
              _buildInfoRow(
                  context,
                  Icons.nights_stay_outlined,
                  'Glucosa al dormir:',
                  '${log.beforeSleepBloodSugar.toStringAsFixed(0)} mg/dL',
                  iconColor: Colors.purpleAccent
              ),
              _buildInfoRow(
                  context,
                  Icons.colorize,
                  'Insulina Lenta:',
                  '${log.slowInsulinUnits.toStringAsFixed(1)} U',
                  iconColor: Colors.teal
              ),
              if (log.afterWakeUpBloodSugar != null) ...[
                const Divider(height: 16.0, thickness: 0.5, indent: 2, endIndent: 2,),
                _buildInfoRow(
                    context,
                    Icons.wb_sunny_outlined,
                    'Glucosa al despertar:',
                    '${log.afterWakeUpBloodSugar?.toStringAsFixed(0)} mg/dL ', // Asumiendo que wakeUpTime puede ser null ahora
                    iconColor: Colors.amber[700]
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<MealLog>>(
      valueListenable: _mealLogBox.listenable(),
      builder: (context, mealBox, _) {
        return ValueListenableBuilder<Box<OvernightLog>>(
          valueListenable: _overnightLogBox.listenable(),
          builder: (context, overnightBox, _) {
            final List<dynamic> logsToShow = _getFilteredAndSortedLogs();

            if (logsToShow.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_note_outlined, size: 60, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(height: 16),
                      Text(
                        // Asegúrate que 'es_ES' esté inicializado si lo usas explícitamente.
                        // Si tu app ya usa Localizations.localeOf(context).languageCode para 'es', no es necesario.
                        'No hay notas registradas para el día ${DateFormat('dd MMMM yyyy', Localizations.localeOf(context).toLanguageTag()).format(widget.selectedDate)}.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0), // Padding general para el ListView
              itemCount: logsToShow.length,
              itemBuilder: (context, index) {
                final log = logsToShow[index];
                if (log is MealLog) {
                  return _buildMealLogTile(log);
                } else if (log is OvernightLog) {
                  return _buildOvernightLogTile(log);
                }
                return const SizedBox.shrink();
              },
            );
          },
        );
      },
    );
  }
}