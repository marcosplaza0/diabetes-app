// lib/features/home/widgets/recent_logs_widget.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Para ValueListenableBuilder y Box
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart'; // Para Provider

import 'package:diabetes_2/data/models/logs/logs.dart';
import 'package:diabetes_2/main.dart' show mealLogBoxName, overnightLogBoxName; // Para nombres de cajas (listeners)
import 'package:diabetes_2/data/repositories/log_repository.dart'; // Importar el repositorio

class RecentLogsWidget extends StatefulWidget {
  const RecentLogsWidget({super.key});

  @override
  State<RecentLogsWidget> createState() => _RecentLogsWidgetState();
}

class _RecentLogsWidgetState extends State<RecentLogsWidget> {
  List<Map<String, dynamic>> _sortedRecentLogs = [];
  late LogRepository _logRepository;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _logRepository = Provider.of<LogRepository>(context, listen: false);
    _loadRecentLogs();
    // Escuchar cambios en las cajas de Hive para actualizar la UI
    // El repositorio podría eventualmente ofrecer su propio stream/notifier,
    // pero por ahora, escuchar las cajas directamente y recargar desde el repo es una solución.
    Hive.box<MealLog>(mealLogBoxName).listenable().addListener(_loadRecentLogs);
    Hive.box<OvernightLog>(overnightLogBoxName).listenable().addListener(_loadRecentLogs);
  }

  @override
  void dispose() {
    Hive.box<MealLog>(mealLogBoxName).listenable().removeListener(_loadRecentLogs);
    Hive.box<OvernightLog>(overnightLogBoxName).listenable().removeListener(_loadRecentLogs);
    super.dispose();
  }

  Future<void> _loadRecentLogs() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });
    try {
      _sortedRecentLogs = await _logRepository.getRecentLogs(const Duration(hours: 24));
    } catch (e) {
      debugPrint("Error cargando logs recientes desde el repositorio: $e");
      // Manejar el error como sea apropiado, quizás mostrar un mensaje
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showLogDetails(BuildContext passedContext, dynamic logData) {
    final log = logData['log'];
    final String type = logData['type'];
    final dynamic logKeyFromMap = logData['key'];
    final DateFormat timeFormat = DateFormat.Hm();
    final theme = Theme.of(passedContext);

    showModalBottomSheet(
      context: passedContext,
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28.0),
          topRight: Radius.circular(28.0),
        ),
      ),
      builder: (BuildContext bContext) {
        final bottomSheetTheme = Theme.of(bContext);
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                type == 'meal' ? 'Registro de Comida' : 'Registro Nocturno',
                style: bottomSheetTheme.textTheme.titleLarge?.copyWith(color: bottomSheetTheme.colorScheme.onSurface),
              ),
              const SizedBox(height: 16),
              if (type == 'meal' && log is MealLog) ...[
                Text('Hora de inicio: ${timeFormat.format(log.startTime)}', style: bottomSheetTheme.textTheme.bodyMedium),
                Text('Glucosa inicial: ${log.initialBloodSugar} mg/dL', style: bottomSheetTheme.textTheme.bodyMedium),
                Text('Carbohidratos: ${log.carbohydrates} g', style: bottomSheetTheme.textTheme.bodyMedium),
                Text('Unidades de insulina: ${log.insulinUnits} U', style: bottomSheetTheme.textTheme.bodyMedium),
              ] else if (type == 'overnight' && log is OvernightLog) ...[
                Text('Hora de dormir: ${timeFormat.format(log.bedTime)}', style: bottomSheetTheme.textTheme.bodyMedium),
                Text('Glucosa antes de dormir: ${log.beforeSleepBloodSugar} mg/dL', style: bottomSheetTheme.textTheme.bodyMedium),
                Text('Unidades de insulina lenta: ${log.slowInsulinUnits} U', style: bottomSheetTheme.textTheme.bodyMedium),
              ],
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: Icon(Icons.edit_rounded, color: bottomSheetTheme.colorScheme.primary),
                  tooltip: 'Editar registro',
                  onPressed: () {
                    Navigator.pop(bContext);

                    if (logKeyFromMap != null) {
                      final String logKeyString = logKeyFromMap.toString();
                      final String logTypeString = type;

                      GoRouter.of(passedContext).pushNamed(
                        'diabetesLogEdit',
                        pathParameters: {
                          'logTypeString': logTypeString,
                          'logKeyString': logKeyString,
                        },
                      );
                    } else {
                      ScaffoldMessenger.of(passedContext).showSnackBar(
                        const SnackBar(
                          content: Text('Error: No se pudo obtener la clave del registro para editar.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(strokeWidth: 2)));
    }

    if (_sortedRecentLogs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No hay registros en las últimas 24 horas.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: _sortedRecentLogs.map((logData) {
          final String type = logData['type'];
          final DateTime time = logData['time'];
          IconData iconData = type == 'meal' ? Icons.fastfood_rounded : Icons.bedtime_rounded;
          Color iconBackgroundColor = type == 'meal' ? theme.colorScheme.primaryContainer : theme.colorScheme.secondaryContainer;
          Color onIconBackgroundColor = type == 'meal' ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSecondaryContainer;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: iconBackgroundColor.withAlpha(90),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(iconData, size: 22),
                    color: onIconBackgroundColor,
                    tooltip: '${type == 'meal' ? 'Comida' : 'Noche'} - ${DateFormat.Hm().format(time)}',
                    onPressed: () => _showLogDetails(context, logData),
                    iconSize: 20,
                    padding: const EdgeInsets.all(10),
                    constraints: const BoxConstraints(),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat.Hm().format(time),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                )
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}