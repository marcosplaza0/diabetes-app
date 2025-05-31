// lib/features/trends_graphs/presentation/tendencias_graph_screen.dart
// import 'dart:math'; // No es necesario aquí
import 'package:collection/collection.dart';
import 'package:flutter/material.dart' hide DayPeriod;
import 'package:fl_chart/fl_chart.dart';
// import 'package:hive_flutter/hive_flutter.dart'; // No es necesario
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
// import 'package:collection/collection.dart'; // No es necesario
import 'package:provider/provider.dart';

import 'package:diabetes_2/core/layout/main_layout.dart';
import 'package:diabetes_2/data/models/logs/logs.dart'; // Para el tipo MealLog en tooltips
// import 'package:diabetes_2/main.dart' show mealLogBoxName; // No es necesario
import 'package:diabetes_2/core/services/diabetes_calculator_service.dart'; // Para DayPeriod en tooltips
import 'package:diabetes_2/data/models/calculations/daily_calculation_data.dart' show DayPeriod;
// import 'package:diabetes_2/data/repositories/log_repository.dart'; // No es necesario
import 'package:diabetes_2/features/trends_graphs/presentation/tendencias_graph_view_model.dart';


class TendenciasGraphScreen extends StatefulWidget { // Lo mantenemos StatefulWidget para inicializar dateFormatting
  const TendenciasGraphScreen({super.key});

  @override
  State<TendenciasGraphScreen> createState() => _TendenciasGraphScreenState();
}

class _TendenciasGraphScreenState extends State<TendenciasGraphScreen> {
  @override
  void initState() {
    super.initState();
    _initializeDateFormatting();
    // La carga inicial de datos ahora la hace el ViewModel en su constructor.
    // Si necesitas pasar el ThemeData actual para los puntos del gráfico la primera vez:
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<TendenciasGraphViewModel>(context, listen: false)
            .loadChartData(themeDataForDots: Theme.of(context));
      }
    });
  }

  Future<void> _initializeDateFormatting() async {
    // Asegúrate que esto solo se llama si es necesario o está protegido.
    // Si ya se inicializó en otro lado (ej. HistorialScreen), podría ser redundante.
    try {
      await initializeDateFormatting('es_ES', null);
    } catch (e) {
      debugPrint("Error inicializando date formatting para es_ES (puede que ya esté inicializado): $e");
    }
  }

  Widget _buildDaysSelector(BuildContext context, TendenciasGraphViewModel viewModel, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.7))
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: viewModel.numberOfDays,
          icon: Icon(Icons.expand_more_rounded, color: theme.colorScheme.onSurfaceVariant),
          elevation: 3, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface),
          dropdownColor: theme.colorScheme.surfaceContainerHigh,
          onChanged: viewModel.isLoading ? null : (int? newValue) {
            if (newValue != null) {
              viewModel.updateNumberOfDays(newValue);
            }
          },
          items: <int>[1, 2, 3, 5, 7].map<DropdownMenuItem<int>>((int value) {
            return DropdownMenuItem<int>(value: value, child: Text('$value día${value == 1 ? '' : 's'}'));
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLegend(BuildContext context, TendenciasGraphViewModel viewModel, ThemeData theme) {
    if (viewModel.periodColors.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
      child: Wrap(
        spacing: 5.0, runSpacing: 2.0, alignment: WrapAlignment.center,
        children: viewModel.orderedPeriodsForLegend.map((period) {
          final color = viewModel.periodColors[period] ?? Colors.transparent;
          final periodName = period.toString().split('.').last;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(periodName, style: theme.textTheme.labelSmall?.copyWith(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
            ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChartSection(
      BuildContext context,
      TendenciasGraphViewModel viewModel,
      String title,
      List<LineChartBarData> chartBars,
      List<MealLog> sourceLogs, // Necesario para el tooltip
      double minX,
      double maxX,
      ThemeData theme
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 18.0, bottom: 6.0, left: 6.0),
          child: Text(title, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
        ),
        SizedBox(height: 280, child: Card(
          elevation: 2.0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          color: theme.colorScheme.surfaceContainer, clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 10, left: 8, right: 12),
            child: chartBars.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.hourglass_empty_rounded, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5), size: 32),
              const SizedBox(height: 8),
              Text('Sin datos en este tramo horario', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7))),
            ]))
                : LineChart(
              _buildTimeSlicedChartData(context, viewModel, chartBars, sourceLogs, minX, maxX, theme), // Pasar viewModel
              duration: const Duration(milliseconds: 300),
            ),
          ),
        )),
      ],
    );
  }

  LineChartData _buildTimeSlicedChartData(
      BuildContext context, // Necesario para el tooltip
      TendenciasGraphViewModel viewModel, // Para acceder al calculatorService
      List<LineChartBarData> chartBars,
      List<MealLog> sourceLogs,
      double minX,
      double maxX,
      ThemeData theme
      ) {
    double yRange = viewModel.commonMaxY - viewModel.commonMinY;
    double intervalY = (yRange / 4).clamp(10.0, 50.0);
    if (yRange <= 20) intervalY = 5; else if (yRange <= 50) intervalY = 10;
    if(intervalY <= 0) intervalY = 20;
    double xRange = maxX - minX;
    double intervalX = (xRange <= 240) ? 60 : 120;

    return LineChartData(
      lineTouchData: LineTouchData(
        enabled: true, handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          tooltipRoundedRadius: 10, getTooltipColor: (touchedSpot) => theme.colorScheme.secondaryContainer.withOpacity(0.92),
          getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
            return touchedBarSpots.map((barSpot) {
              // El barIndex en LineChartBarData puede no corresponder directamente al índice de sourceLogs
              // si los logs se filtraron o procesaron. Es más seguro encontrar el log por proximidad o ID si es posible.
              // Por ahora, asumimos una correspondencia simple o que el barData tiene metadatos.
              // Si barData.tag o similar se pudiera usar para almacenar el log.key, sería ideal.
              // Como no tenemos eso, intentaremos encontrar el log más cercano por `barSpot.x` y `barSpot.barIndex`
              // Esto es una simplificación y podría no ser 100% preciso si hay muchos logs superpuestos.
              MealLog? sourceLog;
              if (barSpot.barIndex < sourceLogs.length) {
                sourceLog = sourceLogs[barSpot.barIndex];
                // Podríamos añadir una comprobación de que el X del log coincide aproximadamente con barSpot.x
              }
              // Alternativa más robusta (pero más lenta):
              // sourceLog = sourceLogs.firstWhereOrNull((log) =>
              //    (log.startTime.hour * 60 + log.startTime.minute - barSpot.x).abs() < 5 || // Punto inicial
              //    (log.endTime != null && (log.endTime!.hour * 60 + log.endTime!.minute - barSpot.x).abs() < 5 ) // Punto final
              // );


              if (sourceLog == null) return null;

              final DayPeriod period = viewModel.calculatorService.getDayPeriod(sourceLog.startTime);
              final String periodName = period.toString().split('.').last;
              final int minutesFromMidnight = barSpot.x.toInt();
              final int hour = (minutesFromMidnight ~/ 60) % 24;
              final int minute = minutesFromMidnight % 60;
              final String timeStr = DateFormat('HH:mm', 'es_ES').format(DateTime(2000,1,1,hour,minute));
              final String dateStr = DateFormat('E dd MMM', 'es_ES').format(sourceLog.startTime);
              return LineTooltipItem(
                '$dateStr ($periodName)\n',
                TextStyle(color: viewModel.periodColors[period]?.withAlpha(230) ?? theme.colorScheme.onSecondaryContainer, fontWeight: FontWeight.bold, fontSize: 11.5),
                children: [
                  TextSpan(text: '$timeStr: ', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 10.5, color: theme.colorScheme.onSecondaryContainer)),
                  TextSpan(text: '${barSpot.y.toStringAsFixed(0)} mg/dL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: theme.colorScheme.onSecondaryContainer)),
                ], textAlign: TextAlign.left,
              );
            }).nonNulls.toList();
          },
        ),
      ),
      gridData: FlGridData(show: true, drawVerticalLine: true, drawHorizontalLine: true,
        horizontalInterval: intervalY, verticalInterval: intervalX,
        getDrawingHorizontalLine: (_) => FlLine(color: theme.colorScheme.outlineVariant.withOpacity(0.3), strokeWidth: 0.8),
        getDrawingVerticalLine: (_) => FlLine(color: theme.colorScheme.outlineVariant.withOpacity(0.3), strokeWidth: 0.8),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, interval: intervalY, getTitlesWidget: (v, m) => _axisTitleWidgets(v, m, theme, isXaxis: false))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: intervalX, getTitlesWidget: (v, m) => _axisTitleWidgets(v, m, theme, isXaxis: true))),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: true, border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5), width: 1)),
      minX: minX, maxX: maxX, minY: viewModel.commonMinY, maxY: viewModel.commonMaxY, // Usar del ViewModel
      lineBarsData: chartBars,
    );
  }

  Widget _axisTitleWidgets(double value, TitleMeta meta, ThemeData theme, {required bool isXaxis}) {
    final style = theme.textTheme.labelSmall?.copyWith(fontSize: 9, color: theme.colorScheme.onSurfaceVariant);
    String text = "";
    if (isXaxis) {
      int minutes = value.toInt();
      bool isMin = (value - meta.min).abs() < 1;
      bool isMax = (value - meta.max).abs() < 1;
      bool isIntervalMultiple = meta.appliedInterval > 0 && ((minutes - meta.min) % meta.appliedInterval.round()).abs() < 1;
      if (isMin || isMax || isIntervalMultiple ) {
        final int hour = (minutes ~/ 60) % 24; text = hour.toString().padLeft(2,'0');
      }
    } else { text = meta.formattedValue; }
    return SideTitleWidget(axisSide: meta.axisSide, space: 5, child: Text(text, style: style));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewModel = context.watch<TendenciasGraphViewModel>();

    return MainLayout(
      title: 'Glucemia en 24 Horas',
      body: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6.0, left: 4, right: 4),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: theme.colorScheme.outline.withOpacity(0.4), width: 1),
                  color: theme.cardColor.withOpacity(0.8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(children: [_buildDaysSelector(context, viewModel, theme), const SizedBox(width: 10), Text("Registros", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))]),
                    IconButton(
                      icon: Icon(Icons.refresh_rounded, color: theme.colorScheme.primary, size: 26),
                      onPressed: viewModel.isLoading ? null : () => viewModel.loadChartData(themeDataForDots: theme), // Pasar theme
                      tooltip: 'Recargar datos',
                    )
                  ],
                ),
              ),
            ),
            if (!viewModel.isLoading) _buildLegend(context, viewModel, theme),
            if (viewModel.isLoading) const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (viewModel.chartBarsGraph1.isEmpty && viewModel.chartBarsGraph2.isEmpty && viewModel.chartBarsGraph3.isEmpty)
              Expanded(child: Center(child: Padding(padding: const EdgeInsets.all(24.0),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.bar_chart_rounded, size: 72, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.35)),
                  const SizedBox(height: 20),
                  Text('No hay registros de comidas', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.9)), textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text('en los últimos ${viewModel.numberOfDays} día${viewModel.numberOfDays == 1 ? '' : 's'}.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7)), textAlign: TextAlign.center),
                ]),
              )))
            else Expanded(child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(children: [
                  _buildChartSection(context, viewModel, "Madrugada (00:00 - 08:00)", viewModel.chartBarsGraph1, viewModel.sourceLogsG1, TendenciasGraphViewModel.g1MinX, TendenciasGraphViewModel.g1MaxX, theme),
                  _buildChartSection(context, viewModel, "Mañana/Tarde (08:00 - 16:00)", viewModel.chartBarsGraph2, viewModel.sourceLogsG2, TendenciasGraphViewModel.g2MinX, TendenciasGraphViewModel.g2MaxX, theme),
                  _buildChartSection(context, viewModel, "Tarde/Noche (16:00 - 24:00)", viewModel.chartBarsGraph3, viewModel.sourceLogsG3, TendenciasGraphViewModel.g3MinX, TendenciasGraphViewModel.g3MaxX, theme),
                ]),
              )),
          ],
        ),
      ),
    );
  }
}