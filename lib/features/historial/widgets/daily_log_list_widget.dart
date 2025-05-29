// lib/features/historial/widgets/daily_log_list_widget.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import 'package:diabetes_2/data/models/logs/logs.dart';
import 'package:diabetes_2/main.dart' show mealLogBoxName, overnightLogBoxName; // Nombres de cajas

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
    _mealLogBox = Hive.box<MealLog>(mealLogBoxName);
    _overnightLogBox = Hive.box<OvernightLog>(overnightLogBoxName);
  }

  List<dynamic> _getFilteredAndSortedLogs() {
    List<dynamic> dailyLogs = [];

    for (var mealLog in _mealLogBox.values) {
      if (DateUtils.isSameDay(mealLog.startTime, widget.selectedDate)) {
        dailyLogs.add(mealLog);
      }
    }

    for (var overnightLog in _overnightLogBox.values) {
      if (DateUtils.isSameDay(overnightLog.bedTime, widget.selectedDate)) {
        dailyLogs.add(overnightLog);
      }
    }

    dailyLogs.sort((a, b) {
      DateTime timeA = a is MealLog ? a.startTime : (a as OvernightLog).bedTime;
      DateTime timeB = b is MealLog ? b.startTime : (b as OvernightLog).bedTime;
      return timeA.compareTo(timeB);
    });

    return dailyLogs;
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value, {Color? iconColor}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18.0, color: iconColor ?? theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10.0),
          Text('$label ', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant)),
          Expanded(
              child: Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
                textAlign: TextAlign.end,
                softWrap: true,
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
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // log.key ahora será el String UUID si se guardó con .put(uuid, log)
          if (log.key != null) {
            final String logKeyString = log.key.toString(); // Ya es String (UUID)
            context.pushNamed(
              'diabetesLogEdit',
              pathParameters: {
                'logTypeString': 'meal',
                'logKeyString': logKeyString, // Pasa el UUID String
              },
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Error: No se pudo obtener la clave de la nota."), backgroundColor: Colors.orange)
            );
          }
        },
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    radius: 20,
                    child: Icon(Icons.restaurant_menu_rounded, color: theme.colorScheme.onPrimaryContainer, size: 22),
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
              const SizedBox(height: 12.0),
              _buildInfoRow(context, Icons.opacity_rounded, 'Glucosa Inicial:', '${log.initialBloodSugar.toStringAsFixed(0)} mg/dL', iconColor: Colors.redAccent.shade200),
              _buildInfoRow(context, Icons.bakery_dining_rounded, 'Carbohidratos:', '${log.carbohydrates.toStringAsFixed(0)} g', iconColor: Colors.brown.shade400),
              _buildInfoRow(context, Icons.colorize_rounded, 'Insulina Rápida:', '${log.insulinUnits.toStringAsFixed(1)} U', iconColor: Colors.blueAccent.shade200),
              if (log.finalBloodSugar != null) ...[
                const Divider(height: 20.0, thickness: 0.5),
                _buildInfoRow(context, Icons.opacity_outlined, 'Glucosa Final:', '${log.finalBloodSugar?.toStringAsFixed(0)} mg/dL ${log.endTime != null ? "(${timeFormat.format(log.endTime!)})" : ""}', iconColor: Colors.red.shade300),
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
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // log.key ahora será el String UUID
          if (log.key != null) {
            final String logKeyString = log.key.toString(); // Ya es String (UUID)
            context.pushNamed( // Usar pushNamed para consistencia
              'diabetesLogEdit',
              pathParameters: {
                'logTypeString': 'overnight',
                'logKeyString': logKeyString, // Pasa el UUID String
              },
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Error: No se pudo obtener la clave de la nota."), backgroundColor: Colors.orange)
            );
          }
        },
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    radius: 20,
                    child: Icon(Icons.bedtime_rounded, color: theme.colorScheme.onSecondaryContainer, size: 22),
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
              const SizedBox(height: 12.0),
              _buildInfoRow(context, Icons.nights_stay_rounded, 'Glucosa al dormir:', '${log.beforeSleepBloodSugar.toStringAsFixed(0)} mg/dL', iconColor: Colors.deepPurpleAccent.shade100),
              _buildInfoRow(context, Icons.colorize_outlined, 'Insulina Lenta:', '${log.slowInsulinUnits.toStringAsFixed(1)} U', iconColor: Colors.teal.shade300),
              if (log.afterWakeUpBloodSugar != null) ...[
                const Divider(height: 20.0, thickness: 0.5),
                _buildInfoRow(context, Icons.wb_sunny_rounded, 'Glucosa al despertar:', '${log.afterWakeUpBloodSugar?.toStringAsFixed(0)} mg/dL', iconColor: Colors.orange.shade400),
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
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_note_outlined, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha:0.7)),
                      const SizedBox(height: 20),
                      Text(
                        'No hay notas registradas para el día ${DateFormat('dd MMMM yyyy', Localizations.localeOf(context).toLanguageTag()).format(widget.selectedDate)}.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Puedes añadir nuevas notas desde la pantalla de inicio.",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha:0.8)),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
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