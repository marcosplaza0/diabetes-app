// lib/features/historial/widgets/daily_log_list_widget.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:diabetes_2/data/models/logs/logs.dart';
import 'package:diabetes_2/main.dart' show mealLogBoxName, overnightLogBoxName;
import 'package:diabetes_2/data/repositories/log_repository.dart';
import 'package:diabetes_2/core/widgets/loading_or_empty_state_widget.dart'; // Importar el widget mejorado

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
  late LogRepository _logRepository;
  late Box<MealLog> _mealLogBoxListener;
  late Box<OvernightLog> _overnightLogBoxListener;

  // Key para el FutureBuilder, para poder reiniciarlo si es necesario (ej. al cambiar de fecha)
  // O, simplemente, el cambio de widget.selectedDate ya causa un rebuild del FutureBuilder.
  // Si se necesita re-disparar el future por otra razón, se puede usar una key.
  // GlobalKey _futureBuilderKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _logRepository = Provider.of<LogRepository>(context, listen: false);
    _mealLogBoxListener = Hive.box<MealLog>(mealLogBoxName);
    _overnightLogBoxListener = Hive.box<OvernightLog>(overnightLogBoxName);
  }

  Future<List<dynamic>> _getFilteredAndSortedLogs() async {
    return await _logRepository.getFilteredAndSortedLogsForDate(widget.selectedDate);
  }

  // ... (métodos _getGlucoseColor, _buildDetailItem, _buildGlucoseDetailItem, _buildMealLogTile, _buildOvernightLogTile se mantienen igual)
  Color _getGlucoseColor(double? bG, ThemeData theme) {
    if (bG == null) return theme.colorScheme.onSurfaceVariant.withOpacity(0.7);
    if (bG < 70) return theme.colorScheme.error;
    if (bG > 180) return Colors.red.shade700;
    return Colors.green.shade600;
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
    final timeFormat = DateFormat.Hm(Localizations.localeOf(context).languageCode);

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
            context.pushNamed(
              'diabetesLogEdit',
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
                    radius: 22,
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
    final timeFormat = DateFormat.Hm(Localizations.localeOf(context).languageCode);
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
            context.pushNamed(
              'diabetesLogEdit',
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
    // ValueListenableBuilder sigue siendo útil para reaccionar a cambios en Hive
    // que podrían no ser iniciados por este widget (ej. un log añadido en otra pantalla).
    // Esto hará que el FutureBuilder se reconstruya.
    return ValueListenableBuilder<Box<MealLog>>(
      valueListenable: _mealLogBoxListener.listenable(),
      builder: (context, _, __) {
        return ValueListenableBuilder<Box<OvernightLog>>(
          valueListenable: _overnightLogBoxListener.listenable(),
          builder: (context, ___, ____) {
            return FutureBuilder<List<dynamic>>(
              future: _getFilteredAndSortedLogs(),
              // key: _futureBuilderKey, // Descomentar si necesitas reiniciar el future externamente
              builder: (context, snapshot) {
                return LoadingOrEmptyStateWidget(
                  isLoading: snapshot.connectionState == ConnectionState.waiting,
                  loadingText: "Cargando registros...",
                  hasError: snapshot.hasError,
                  error: snapshot.error, // Pasar el objeto de error
                  errorMessage: snapshot.hasError ? "No se pudieron cargar los registros." : null,
                  onRetry: () {
                    // Forzar la reconstrucción del FutureBuilder para reintentar
                    setState(() {
                      // Si usaras una GlobalKey para el FutureBuilder:
                      // _futureBuilderKey = GlobalKey();
                      // O, simplemente, llamar a setState() puede ser suficiente para que
                      // el FutureBuilder re-ejecute su 'future' si la dependencia (widget.selectedDate)
                      // no ha cambiado pero quieres reintentar.
                      // Si la 'selectedDate' cambia, el FutureBuilder se reconstruye automáticamente.
                      // Para un reintento explícito sin cambio de fecha, necesitarías una
                      // estrategia para que el FutureBuilder vuelva a ejecutar el future.
                      // Una forma simple es cambiar una 'key' o llamar a un método que actualice el estado y cause rebuild.
                    });
                  },
                  isEmpty: !snapshot.hasData || snapshot.data!.isEmpty,
                  emptyMessage: "No hay registros para el\n${DateFormat('EEEE dd MMMM', 'es_ES').format(widget.selectedDate)}",
                  emptyIcon: Icons.forum_outlined,
                  childIfData: ListView.builder(
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    itemCount: snapshot.hasData ? snapshot.data!.length : 0,
                    itemBuilder: (context, index) {
                      final log = snapshot.data![index];
                      if (log is MealLog) {
                        return _buildMealLogTile(log, theme);
                      } else if (log is OvernightLog) {
                        return _buildOvernightLogTile(log, theme);
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}