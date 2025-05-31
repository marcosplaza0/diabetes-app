// lib/features/trends_graphs/presentation/tendencias_graph_screen.dart
import 'dart:math';
import 'package:flutter/material.dart' hide DayPeriod;
import 'package:fl_chart/fl_chart.dart';
// import 'package:hive_flutter/hive_flutter.dart'; // No directamente para la caja, si el repo es suficiente
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:provider/provider.dart'; // Para Provider

import 'package:diabetes_2/core/layout/main_layout.dart';
import 'package:diabetes_2/data/models/logs/logs.dart';
// import 'package:diabetes_2/main.dart' show mealLogBoxName; // Ya no es necesario para el nombre de la caja
import 'package:diabetes_2/core/services/diabetes_calculator_service.dart';
import 'package:diabetes_2/data/models/calculations/daily_calculation_data.dart' show DayPeriod;
import 'package:diabetes_2/data/repositories/log_repository.dart'; // Importar el repositorio

class TendenciasGraphScreen extends StatefulWidget {
  const TendenciasGraphScreen({super.key});

  @override
  State<TendenciasGraphScreen> createState() => _TendenciasGraphScreenState();
}

class _TendenciasGraphScreenState extends State<TendenciasGraphScreen> {
  bool _isLoading = true;

  List<LineChartBarData> _chartBarsGraph1 = [];
  List<LineChartBarData> _chartBarsGraph2 = [];
  List<LineChartBarData> _chartBarsGraph3 = [];

  List<MealLog> _sourceLogsG1 = [], _sourceLogsG2 = [], _sourceLogsG3 = [];

  double _commonMinY = 50;
  double _commonMaxY = 200;

  final double _g1MinX = 0;
  final double _g1MaxX = 8 * 60;
  final double _g2MinX = 8 * 60;
  final double _g2MaxX = 16 * 60;
  final double _g3MinX = 16 * 60;
  final double _g3MaxX = 24 * 60;

  int _numberOfDays = 3;

  late LogRepository _logRepository;
  late DiabetesCalculatorService _calculatorService; // Actualizar si se refactoriza

  final Map<DayPeriod, Color> _periodColors = {
    DayPeriod.P7: Colors.purple.shade300, DayPeriod.P1: Colors.red.shade300,
    DayPeriod.P2: Colors.orange.shade300, DayPeriod.P3: Colors.yellow.shade600,
    DayPeriod.P4: Colors.green.shade400, DayPeriod.P5: Colors.blue.shade300,
    DayPeriod.P6: Colors.indigo.shade300,
  };
  final List<DayPeriod> _orderedPeriodsForLegend = const [
    DayPeriod.P1, DayPeriod.P2, DayPeriod.P3, DayPeriod.P4,
    DayPeriod.P5, DayPeriod.P6, DayPeriod.P7
  ];

  Color _getDotColor(double glucoseValue, ThemeData theme) {
    if (glucoseValue < 70) return theme.colorScheme.error;
    if (glucoseValue > 180) return Colors.red.shade700;
    return Colors.green.shade500;
  }

  @override
  void initState() {
    super.initState();
    _logRepository = Provider.of<LogRepository>(context, listen: false);
    // Asumiendo que DiabetesCalculatorService se instancia aquí o se obtiene de Provider
    // Si se refactoriza DCS para tomar LogRepository, pasarlo aquí.
    _calculatorService = Provider.of<DiabetesCalculatorService>(context, listen: false);
    _initializeAndLoadData();
  }

  Future<void> _initializeAndLoadData() async {
    await initializeDateFormatting('es_ES', null);
    _loadChartData();
  }

  double _interpolateY(double x1, double y1, double x2, double y2, double targetX) {
    if ((x2 - x1).abs() < 1e-6) return y1;
    return y1 + (y2 - y1) * (targetX - x1) / (x2 - x1);
  }

  Future<void> _loadChartData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _chartBarsGraph1 = []; _chartBarsGraph2 = []; _chartBarsGraph3 = [];
      _sourceLogsG1 = []; _sourceLogsG2 = []; _sourceLogsG3 = [];
    });

    final List<double> allYValues = [];
    final today = DateTime.now();
    final theme = Theme.of(context);
    final endDateForQuery = DateTime(today.year, today.month, today.day, 23, 59, 59);
    final startDateForQuery = DateTime(today.year, today.month, today.day - (_numberOfDays - 1), 0, 0, 0);

    // Obtener todos los logs necesarios para el rango de días una sola vez
    final List<MealLog> allRelevantLogs = await _logRepository.getMealLogsInDateRange(startDateForQuery, endDateForQuery);

    FlDotPainter getDynamicDotPainter(FlSpot spot, ThemeData currentTheme) {
      Color dotFillColor = _getDotColor(spot.y, currentTheme);
      return FlDotCirclePainter(
        radius: 2.6, color: dotFillColor,
        strokeColor: currentTheme.colorScheme.surfaceContainerLowest.withOpacity(0.8),
        strokeWidth: 1.0,
      );
    }
    FlDotData getGenericDotData(ThemeData currentTheme) => FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) => getDynamicDotPainter(spot, currentTheme)
    );

    for (int dayIndex = 0; dayIndex < _numberOfDays; dayIndex++) {
      final loopDate = DateTime(today.year, today.month, today.day - dayIndex);
      // Filtrar los logs ya obtenidos para el día actual del bucle
      final List<MealLog> logsForDay = allRelevantLogs
          .where((log) => DateUtils.isSameDay(log.startTime, loopDate))
          .sortedBy((log) => log.startTime)
          .toList();

      for (final mealLog in logsForDay) {
        DayPeriod period = _calculatorService.getDayPeriod(mealLog.startTime);
        Color periodLineColor = _periodColors[period] ?? Colors.grey.shade300;

        final double xInitial = mealLog.startTime.hour.toDouble() * 60 + mealLog.startTime.minute.toDouble();
        final double yInitial = mealLog.initialBloodSugar;
        allYValues.add(yInitial);
        FlSpot spotInitial = FlSpot(xInitial, yInitial);

        LineChartBarData createSegment(List<FlSpot> spots) => LineChartBarData(
            spots: spots, color: periodLineColor, barWidth: 2.2, isCurved: true,
            isStrokeCapRound: true, dotData: getGenericDotData(theme));
        LineChartBarData createSinglePoint(FlSpot spot) => LineChartBarData(
            spots: [spot], color: periodLineColor, barWidth:0, dotData: getGenericDotData(theme));

        if (mealLog.finalBloodSugar != null && mealLog.endTime != null) {
          double xFinal = mealLog.endTime!.hour.toDouble() * 60 + mealLog.endTime!.minute.toDouble();
          final double yFinal = mealLog.finalBloodSugar!;
          allYValues.add(yFinal);
          FlSpot spotFinal = FlSpot(xFinal, yFinal);

          if (xFinal < xInitial && (xInitial - xFinal).abs() > 12*60 ) { // Cruza medianoche
            double yAtDayEnd = _interpolateY(xInitial, yInitial, xInitial + (1440.0 - xInitial + xFinal) , yFinal, _g3MaxX);
            FlSpot endOfDaySpot = FlSpot(_g3MaxX, yAtDayEnd);
            if (spotInitial.x < _g3MaxX) {
              _chartBarsGraph3.add(createSegment([spotInitial, endOfDaySpot])); _sourceLogsG3.add(mealLog);
            }
            FlSpot startOfNextDaySpot = FlSpot(_g1MinX, yAtDayEnd);
            if (spotFinal.x >= _g1MinX) {
              _chartBarsGraph1.add(createSegment([startOfNextDaySpot, spotFinal])); _sourceLogsG1.add(mealLog);
            }
            continue;
          }

          double currentX1 = xInitial; double currentY1 = yInitial;
          double currentX2 = xFinal;   double currentY2 = yFinal;

          if (currentX1 < _g1MaxX) {
            FlSpot s1_g1 = FlSpot(currentX1, currentY1);
            if (currentX2 <= _g1MaxX) {
              _chartBarsGraph1.add(createSegment([s1_g1, FlSpot(currentX2, currentY2)])); _sourceLogsG1.add(mealLog);
            } else {
              double yAtBoundary = _interpolateY(currentX1, currentY1, currentX2, currentY2, _g1MaxX);
              _chartBarsGraph1.add(createSegment([s1_g1, FlSpot(_g1MaxX, yAtBoundary)])); _sourceLogsG1.add(mealLog);
              currentX1 = _g1MaxX; currentY1 = yAtBoundary;
            }
          }
          if (currentX1 < _g2MaxX && currentX2 >= _g2MinX && currentX1 < currentX2) {
            FlSpot s1_g2 = (currentX1 >= _g2MinX) ? FlSpot(currentX1, currentY1) : FlSpot(_g2MinX, _interpolateY(xInitial,yInitial, xFinal, yFinal, _g2MinX));
            if (currentX2 <= _g2MaxX) {
              _chartBarsGraph2.add(createSegment([s1_g2, FlSpot(currentX2, currentY2)])); _sourceLogsG2.add(mealLog);
            } else {
              double yAtBoundary = _interpolateY(xInitial, yInitial, xFinal, yFinal, _g2MaxX);
              _chartBarsGraph2.add(createSegment([s1_g2, FlSpot(_g2MaxX, yAtBoundary)])); _sourceLogsG2.add(mealLog);
              currentX1 = _g2MaxX; currentY1 = yAtBoundary;
            }
          }
          if (currentX1 < _g3MaxX && currentX2 >= _g3MinX && currentX1 < currentX2) {
            FlSpot s1_g3 = (currentX1 >= _g3MinX) ? FlSpot(currentX1, currentY1) : FlSpot(_g3MinX, _interpolateY(xInitial,yInitial, xFinal, yFinal, _g3MinX));
            FlSpot s2_g3 = FlSpot(min(_g3MaxX, currentX2), currentY2);
            if (currentX2 > _g3MaxX) s2_g3 = FlSpot(_g3MaxX, _interpolateY(xInitial, yInitial, xFinal, yFinal, _g3MaxX));
            if ((s2_g3.x - s1_g3.x).abs() > 1e-3) {
              _chartBarsGraph3.add(createSegment([s1_g3,s2_g3])); _sourceLogsG3.add(mealLog);
            } else if (s1_g3.x <= _g3MaxX) {
              _chartBarsGraph3.add(createSinglePoint(s1_g3)); _sourceLogsG3.add(mealLog);
            }
          }
        } else { // Single point (only initial BG)
          if (xInitial < _g1MaxX) {
            _chartBarsGraph1.add(createSinglePoint(spotInitial)); _sourceLogsG1.add(mealLog);
          } else if (xInitial < _g2MaxX) {
            _chartBarsGraph2.add(createSinglePoint(spotInitial)); _sourceLogsG2.add(mealLog);
          } else if (xInitial <= _g3MaxX) {
            _chartBarsGraph3.add(createSinglePoint(spotInitial)); _sourceLogsG3.add(mealLog);
          }
        }
      }
    }

    if (allYValues.isNotEmpty) {
      _commonMinY = allYValues.reduce(min).floorToDouble(); _commonMaxY = allYValues.reduce(max).ceilToDouble();
      double yRange = _commonMaxY - _commonMinY;
      double padding = (yRange == 0) ? 15 : (yRange * 0.20).clamp(10.0, 40.0);
      _commonMinY = max(0, _commonMinY - padding); _commonMaxY = _commonMaxY + padding;
      if (_commonMaxY - _commonMinY < 50) { double mid = (_commonMinY + _commonMaxY) / 2.0; _commonMinY = max(0, mid - 25); _commonMaxY = mid + 25; }
      if(_commonMinY < 50) _commonMinY = 50;
      _commonMinY = _commonMinY.floorToDouble(); _commonMaxY = _commonMaxY.ceilToDouble();
      const double snapStep = 10.0;
      if (_commonMaxY % snapStep != 0) _commonMaxY = ((_commonMaxY / snapStep).ceil() * snapStep);
      if (_commonMinY % snapStep != 0) _commonMinY = ((_commonMinY / snapStep).floor() * snapStep);
      if (_commonMinY < 0) _commonMinY = 0; if (_commonMaxY <= _commonMinY) _commonMaxY = _commonMinY + 50;
    } else { _commonMinY = 50; _commonMaxY = 250; }
    if (_commonMinY == _commonMaxY) { _commonMinY = max(0, _commonMinY -25); _commonMaxY = _commonMaxY + 25; }
    if (mounted) { setState(() { _isLoading = false; });}
  }

  Widget _buildDaysSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.7))
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _numberOfDays,
          icon: Icon(Icons.expand_more_rounded, color: theme.colorScheme.onSurfaceVariant),
          elevation: 3, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface),
          dropdownColor: theme.colorScheme.surfaceContainerHigh,
          onChanged: (int? newValue) {
            if (newValue != null && !_isLoading) {
              setState(() { _numberOfDays = newValue; });
              _loadChartData();
            }
          },
          items: <int>[1, 2, 3, 5, 7].map<DropdownMenuItem<int>>((int value) {
            return DropdownMenuItem<int>(value: value, child: Text('$value día${value == 1 ? '' : 's'}'));
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLegend(ThemeData theme) {
    if (_periodColors.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
      child: Wrap(
        spacing: 5.0, runSpacing: 2.0, alignment: WrapAlignment.center,
        children: _orderedPeriodsForLegend.map((period) {
          final color = _periodColors[period] ?? Colors.transparent;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(children: [_buildDaysSelector(theme), const SizedBox(width: 10), Text("Registros", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))]),
                    IconButton(icon: Icon(Icons.refresh_rounded, color: theme.colorScheme.primary, size: 26), onPressed: _isLoading ? null : _loadChartData, tooltip: 'Recargar datos')
                  ],
                ),
              ),
            ),
            if (!_isLoading) _buildLegend(theme),
            if (_isLoading) const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_chartBarsGraph1.isEmpty && _chartBarsGraph2.isEmpty && _chartBarsGraph3.isEmpty)
              Expanded(child: Center(child: Padding(padding: const EdgeInsets.all(24.0),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.bar_chart_rounded, size: 72, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.35)),
                  const SizedBox(height: 20),
                  Text('No hay registros de comidas', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.9)), textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text('en los últimos $_numberOfDays día${_numberOfDays == 1 ? '' : 's'}.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7)), textAlign: TextAlign.center),
                ]),
              )))
            else Expanded(child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(children: [
                  _buildChartSection("Madrugada (00:00 - 08:00)", _chartBarsGraph1, _sourceLogsG1, _g1MinX, _g1MaxX, theme),
                  _buildChartSection("Mañana/Tarde (08:00 - 16:00)", _chartBarsGraph2, _sourceLogsG2, _g2MinX, _g2MaxX, theme),
                  _buildChartSection("Tarde/Noche (16:00 - 24:00)", _chartBarsGraph3, _sourceLogsG3, _g3MinX, _g3MaxX, theme),
                ]),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection(String title, List<LineChartBarData> chartBars, List<MealLog> sourceLogs, double minX, double maxX, ThemeData theme) {
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
                : LineChart(_buildTimeSlicedChartData(chartBars, sourceLogs, minX, maxX, theme), duration: const Duration(milliseconds: 300)),
          ),
        )),
      ],
    );
  }

  LineChartData _buildTimeSlicedChartData(List<LineChartBarData> chartBars, List<MealLog> sourceLogs, double minX, double maxX, ThemeData theme) {
    double yRange = _commonMaxY - _commonMinY;
    double intervalY = (yRange / 4).clamp(10.0, 50.0);
    if (yRange <= 20) intervalY = 5; else if (yRange <= 50) intervalY = 10;
    if(intervalY <= 0) intervalY = 20;
    double xRange = maxX - minX;
    double intervalX = (xRange <= 240) ? 60 : 120;

    return LineChartData(
      lineTouchData: LineTouchData(enabled: true, handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          tooltipRoundedRadius: 10, getTooltipColor: (spot) => theme.colorScheme.secondaryContainer.withOpacity(0.92),
          getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
            return touchedBarSpots.map((barSpot) {
              final MealLog? sourceLog = sourceLogs.elementAtOrNull(barSpot.barIndex);
              if (sourceLog == null) return null;
              final DayPeriod period = _calculatorService.getDayPeriod(sourceLog.startTime);
              final String periodName = period.toString().split('.').last;
              final int minutesFromMidnight = barSpot.x.toInt();
              final int hour = (minutesFromMidnight ~/ 60) % 24;
              final int minute = minutesFromMidnight % 60;
              final String timeStr = DateFormat('HH:mm', 'es_ES').format(DateTime(2000,1,1,hour,minute));
              final String dateStr = DateFormat('E dd MMM', 'es_ES').format(sourceLog.startTime);
              return LineTooltipItem(
                '$dateStr ($periodName)\n',
                TextStyle(color: _periodColors[period]?.withAlpha(230) ?? theme.colorScheme.onSecondaryContainer, fontWeight: FontWeight.bold, fontSize: 11.5),
                children: [
                  TextSpan(text: '$timeStr: ', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 10.5, color: theme.colorScheme.onSecondaryContainer)),
                  TextSpan(text: '${barSpot.y.toStringAsFixed(0)} mg/dL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: theme.colorScheme.onSecondaryContainer)),
                ], textAlign: TextAlign.left,
              );
            }).whereNotNull().toList();
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
      minX: minX, maxX: maxX, minY: _commonMinY, maxY: _commonMaxY,
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
}