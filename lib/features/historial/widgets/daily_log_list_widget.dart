// lib/features/historial/widgets/daily_log_list_widget.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import 'package:diabetes_2/data/models/logs/logs.dart';
import 'package:diabetes_2/main.dart' show mealLogBoxName, overnightLogBoxName;

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
    _mealLogBox = Hive.box<MealLog>(mealLogBoxName); //
    _overnightLogBox = Hive.box<OvernightLog>(overnightLogBoxName); //
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

  Color _getGlucoseColor(double? bG, ThemeData theme) {
    if (bG == null) return theme.colorScheme.onSurfaceVariant.withOpacity(0.7);
    if (bG < 70) return theme.colorScheme.error; // Hypo
    if (bG > 180) return Colors.red.shade700; // Hyper - Strong Red
    return Colors.green.shade600; // In range
  }

  Widget _buildDetailItem(BuildContext context, IconData icon, String label, String value, {Color? valueColor, Color? iconColor}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18.0, color: iconColor ?? theme.colorScheme.onSurfaceVariant.withOpacity(0.9)),
          const SizedBox(width: 10.0),
          Expanded(
              child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)
              )
          ),
          const SizedBox(width: 8.0),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor ?? theme.colorScheme.onSurface
            ),
            textAlign: TextAlign.end,
          ),
        ],
      ),
    );
  }

  Widget _buildGlucoseDetailItem(BuildContext context, String label, double? glucoseValue, IconData icon) {
    final theme = Theme.of(context);
    final Color glucoseColor = _getGlucoseColor(glucoseValue, theme);
    return _buildDetailItem(
        context,
        icon,
        label,
        glucoseValue != null ? '${glucoseValue.toStringAsFixed(0)} mg/dL' : '-- mg/dL',
        valueColor: glucoseColor,
        iconColor: glucoseColor.withOpacity(0.85)
    );
  }


  Widget _buildMealLogTile(MealLog log, ThemeData theme) {
    final timeFormat = DateFormat.Hm(Localizations.localeOf(context).languageCode); //

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)), // Enhanced radius
      color: theme.colorScheme.surfaceContainer, // M3 Surface color
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (log.key != null) {
            final String logKeyString = log.key.toString();
            context.pushNamed( //
              'diabetesLogEdit', //
              pathParameters: {
                'logTypeString': 'meal',
                'logKeyString': logKeyString,
              },
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Error: No se pudo obtener la clave de la nota."), backgroundColor: Colors.orange)
            );
          }
        },
        borderRadius: BorderRadius.circular(16.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    radius: 22, // Slightly larger
                    child: Icon(Icons.restaurant_menu_rounded, color: theme.colorScheme.onPrimaryContainer, size: 22),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Text(
                      'Comida - ${timeFormat.format(log.startTime)}',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                    ),
                  ),
                  Icon(Icons.edit_note_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7))
                ],
              ),
              const Divider(height: 20.0, thickness: 0.5),
              _buildGlucoseDetailItem(context, 'Glucosa Inicial:', log.initialBloodSugar, Icons.arrow_upward_rounded),
              _buildDetailItem(context, Icons.lunch_dining_outlined, 'Carbohidratos:', '${log.carbohydrates.toStringAsFixed(0)} g', iconColor: theme.colorScheme.tertiary),
              _buildDetailItem(context, Icons.opacity_rounded, 'Insulina Rápida:', '${log.insulinUnits.toStringAsFixed(1)} U', iconColor: theme.colorScheme.secondary),
              if (log.finalBloodSugar != null) ...[
                const SizedBox(height: 6),
                _buildGlucoseDetailItem(context, 'Glucosa Final ${log.endTime != null ? "(${timeFormat.format(log.endTime!)})" : ""}:', log.finalBloodSugar, Icons.arrow_downward_rounded),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOvernightLogTile(OvernightLog log, ThemeData theme) {
    final timeFormat = DateFormat.Hm(Localizations.localeOf(context).languageCode); //
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      color: theme.colorScheme.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (log.key != null) {
            final String logKeyString = log.key.toString();
            context.pushNamed( //
              'diabetesLogEdit', //
              pathParameters: {
                'logTypeString': 'overnight',
                'logKeyString': logKeyString,
              },
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Error: No se pudo obtener la clave de la nota."), backgroundColor: Colors.orange)
            );
          }
        },
        borderRadius: BorderRadius.circular(16.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    radius: 22,
                    child: Icon(Icons.bedtime_rounded, color: theme.colorScheme.onSecondaryContainer, size: 22),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Text(
                      'Noche - ${timeFormat.format(log.bedTime)}',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                    ),
                  ),
                  Icon(Icons.edit_note_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7))
                ],
              ),
              const Divider(height: 20.0, thickness: 0.5),
              _buildGlucoseDetailItem(context, 'Glucosa al Dormir:', log.beforeSleepBloodSugar, Icons.nights_stay_rounded),
              _buildDetailItem(context, Icons.medication_liquid_outlined, 'Insulina Lenta:', '${log.slowInsulinUnits.toStringAsFixed(1)} U', iconColor: theme.colorScheme.tertiary),
              if (log.afterWakeUpBloodSugar != null) ...[
                const SizedBox(height: 6),
                _buildGlucoseDetailItem(context, 'Glucosa al Despertar:', log.afterWakeUpBloodSugar, Icons.wb_sunny_rounded),
              ]
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  padding: const EdgeInsets.all(32.0), // More padding
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.forum_outlined, size: 72, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4)), // Changed icon
                      const SizedBox(height: 20),
                      Text(
                        'No hay registros para el', // Changed text
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8)),
                      ),
                      Text(
                        DateFormat('EEEE dd MMMM', 'es_ES').format(widget.selectedDate), // Format date more nicely
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Puedes añadir nuevas notas desde la pantalla de inicio o usando el botón '+' en algunas pantallas.", // Updated guidance
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6)),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), // Added scroll physics
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              itemCount: logsToShow.length,
              itemBuilder: (context, index) {
                final log = logsToShow[index];
                if (log is MealLog) {
                  return _buildMealLogTile(log, theme);
                } else if (log is OvernightLog) {
                  return _buildOvernightLogTile(log, theme);
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