// lib/features/trends_graphs/presentation/tendencias_graph_screen.dart
import 'dart:math';
import 'package:flutter/material.dart' hide DayPeriod;
import 'package:fl_chart/fl_chart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

import 'package:diabetes_2/core/layout/main_layout.dart';
import 'package:diabetes_2/data/models/logs/logs.dart';
import 'package:diabetes_2/main.dart' show mealLogBoxName;
import 'package:diabetes_2/core/services/diabetes_calculator_service.dart';
import 'package:diabetes_2/data/models/calculations/daily_calculation_data.dart' show DayPeriod;

class TendenciasGraphScreen extends StatefulWidget {
  const TendenciasGraphScreen({super.key});

  @override
  State<TendenciasGraphScreen> createState() => _TendenciasGraphScreenState();
}

class _TendenciasGraphScreenState extends State<TendenciasGraphScreen> {
  bool _isLoading = true;

  List<LineChartBarData> _chartBarsGraph1 = []; // 00:00 - 08:00
  List<LineChartBarData> _chartBarsGraph2 = []; // 08:00 - 16:00
  List<LineChartBarData> _chartBarsGraph3 = []; // 16:00 - 24:00

  List<MealLog> _sourceLogsG1 = [], _sourceLogsG2 = [], _sourceLogsG3 = [];

  double _commonMinY = 50; // Ajustado en _loadChartData
  double _commonMaxY = 200; // Ajustado en _loadChartData

  // X-axis boundaries for each graph (minutes from midnight)
  // These define the *range* of data for each chart.
  // A point at _g1MaxX would be the very first point of _g2MinX.
  final double _g1MinX = 0;        // 00:00
  final double _g1MaxX = 8 * 60;   // 08:00
  final double _g2MinX = 8 * 60;   // 08:00
  final double _g2MaxX = 16 * 60;  // 16:00
  final double _g3MinX = 16 * 60;  // 16:00
  final double _g3MaxX = 24 * 60;  // 24:00 (1440 minutes)

  int _numberOfDays = 3; // Default to 3 days for better clarity with overlays

  late Box<MealLog> _mealLogBox;
  final DiabetesCalculatorService _calculatorService = DiabetesCalculatorService();

  final Map<DayPeriod, Color> _periodColors = {
    DayPeriod.P7: Colors.purple.shade300, // Lighter shades for lines can be nicer
    DayPeriod.P1: Colors.red.shade300,
    DayPeriod.P2: Colors.orange.shade300,
    DayPeriod.P3: Colors.yellow.shade600, // Keep darker yellow for visibility
    DayPeriod.P4: Colors.green.shade400,
    DayPeriod.P5: Colors.blue.shade300,
    DayPeriod.P6: Colors.indigo.shade300,
  };

  final List<DayPeriod> _orderedPeriodsForLegend = const [
    DayPeriod.P1, DayPeriod.P2, DayPeriod.P3, DayPeriod.P4,
    DayPeriod.P5, DayPeriod.P6, DayPeriod.P7
  ];

  Color _getDotColor(double glucoseValue, ThemeData theme) {
    if (glucoseValue < 70) {
      return theme.colorScheme.error;
    } else if (glucoseValue > 180) {
      return Colors.red.shade700;
    } else {
      return Colors.green.shade500; // Slightly darker green for dots
    }
  }

  @override
  void initState() {
    super.initState();
    _mealLogBox = Hive.box<MealLog>(mealLogBoxName);
    _initializeAndLoadData();
  }

  Future<void> _initializeAndLoadData() async {
    await initializeDateFormatting('es_ES', null);
    _loadChartData();
  }

  double _interpolateY(double x1, double y1, double x2, double y2, double targetX) {
    if ((x2 - x1).abs() < 1e-6) return y1; // Avoid division by zero or very small diff
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

    FlDotPainter getDynamicDotPainter(FlSpot spot, ThemeData currentTheme) {
      Color dotFillColor = _getDotColor(spot.y, currentTheme);
      return FlDotCirclePainter(
        radius: 2.6, // Fixed radius as there is no `bar` property on FlSpot
        color: dotFillColor,
        strokeColor: currentTheme.colorScheme.surfaceContainerLowest.withOpacity(0.8), // Use card bg for stroke
        strokeWidth: 1.0,
      );
    }

    FlDotData getGenericDotData(ThemeData currentTheme) => FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) => getDynamicDotPainter(spot, currentTheme)
    );

    for (int dayIndex = 0; dayIndex < _numberOfDays; dayIndex++) {
      final loopDate = DateTime(today.year, today.month, today.day - dayIndex);
      final List<MealLog> logsForDay = _mealLogBox.values
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

        LineChartBarData createSegment(List<FlSpot> spots) {
          return LineChartBarData(
              spots: spots, color: periodLineColor, barWidth: 2.2, // Slightly thinner line
              isCurved: true, // Make lines curved for a softer look
              isStrokeCapRound: true,
              dotData: getGenericDotData(theme)
          );
        }
        LineChartBarData createSinglePoint(FlSpot spot) {
          return LineChartBarData(
              spots: [spot], color: periodLineColor, barWidth:0, // No line for single point
              dotData: getGenericDotData(theme)
          );
        }


        if (mealLog.finalBloodSugar != null && mealLog.endTime != null) {
          double xFinal = mealLog.endTime!.hour.toDouble() * 60 + mealLog.endTime!.minute.toDouble();
          final double yFinal = mealLog.finalBloodSugar!;
          allYValues.add(yFinal);
          FlSpot spotFinal = FlSpot(xFinal, yFinal);

          // Handle segments crossing midnight for the 24h cycle display logic
          if (xFinal < xInitial && (xInitial - xFinal).abs() > 12*60 ) {
            double yAtDayEnd = _interpolateY(xInitial, yInitial, xInitial + (1440.0 - xInitial + xFinal) , yFinal, _g3MaxX);
            FlSpot endOfDaySpot = FlSpot(_g3MaxX, yAtDayEnd); // Point exactly at the boundary
            if (spotInitial.x < _g3MaxX) {
              _chartBarsGraph3.add(createSegment([spotInitial, endOfDaySpot]));
              _sourceLogsG3.add(mealLog);
            }

            FlSpot startOfNextDaySpot = FlSpot(_g1MinX, yAtDayEnd);
            if (spotFinal.x >= _g1MinX) {
              _chartBarsGraph1.add(createSegment([startOfNextDaySpot, spotFinal]));
              _sourceLogsG1.add(mealLog);
            }
            continue;
          }

          double currentX1 = xInitial; double currentY1 = yInitial;
          double currentX2 = xFinal;   double currentY2 = yFinal;

          // Segment for Graph 1
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

          // Segment for Graph 2
          if (currentX1 < _g2MaxX && currentX2 >= _g2MinX && currentX1 < currentX2) {
            FlSpot s1_g2;
            if(currentX1 >= _g2MinX) s1_g2 = FlSpot(currentX1, currentY1);
            else s1_g2 = FlSpot(_g2MinX, _interpolateY(xInitial,yInitial, xFinal, yFinal, _g2MinX));

            if (currentX2 <= _g2MaxX) {
              _chartBarsGraph2.add(createSegment([s1_g2, FlSpot(currentX2, currentY2)])); _sourceLogsG2.add(mealLog);
            } else {
              double yAtBoundary = _interpolateY(xInitial, yInitial, xFinal, yFinal, _g2MaxX);
              _chartBarsGraph2.add(createSegment([s1_g2, FlSpot(_g2MaxX, yAtBoundary)])); _sourceLogsG2.add(mealLog);
              currentX1 = _g2MaxX; currentY1 = yAtBoundary;
            }
          }

          // Segment for Graph 3
          if (currentX1 < _g3MaxX && currentX2 >= _g3MinX && currentX1 < currentX2) {
            FlSpot s1_g3;
            if(currentX1 >= _g3MinX) s1_g3 = FlSpot(currentX1, currentY1);
            else s1_g3 = FlSpot(_g3MinX, _interpolateY(xInitial,yInitial, xFinal, yFinal, _g3MinX));

            FlSpot s2_g3 = FlSpot(min(_g3MaxX, currentX2), currentY2);
            if (currentX2 > _g3MaxX) s2_g3 = FlSpot(_g3MaxX, _interpolateY(xInitial, yInitial, xFinal, yFinal, _g3MaxX));

            // Ensure s1_g3.x is not equal to s2_g3.x to avoid issues with FlChart if they are identical due to boundary conditions
            if ((s2_g3.x - s1_g3.x).abs() > 1e-3) { // Only add if there's some length
              _chartBarsGraph3.add(createSegment([s1_g3,s2_g3])); _sourceLogsG3.add(mealLog);
            } else if (s1_g3.x <= _g3MaxX) { // If it's effectively a single point at the boundary start
              _chartBarsGraph3.add(createSinglePoint(s1_g3)); _sourceLogsG3.add(mealLog);
            }
          }
        } else {
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
      _commonMinY = allYValues.reduce(min).floorToDouble();
      _commonMaxY = allYValues.reduce(max).ceilToDouble();
      double yRange = _commonMaxY - _commonMinY;
      double padding = (yRange == 0) ? 15 : (yRange * 0.20).clamp(10.0, 40.0); // Increased padding slightly
      _commonMinY = max(0, _commonMinY - padding);
      _commonMaxY = _commonMaxY + padding;
      if (_commonMaxY - _commonMinY < 50) { // Ensure larger min visual range
        double midPoint = (_commonMinY + _commonMaxY) / 2.0;
        _commonMinY = max(0, midPoint - 25);
        _commonMaxY = midPoint + 25;
      }
      if(_commonMinY< 50) _commonMinY = 50;
      _commonMinY = _commonMinY.floorToDouble();
      _commonMaxY = _commonMaxY.ceilToDouble();
      const double snapStep = 10.0; // Snap to multiples of 10 for Y axis
      if (_commonMaxY % snapStep != 0) { _commonMaxY = ((_commonMaxY / snapStep).ceil() * snapStep); }
      if (_commonMinY % snapStep != 0) { _commonMinY = ((_commonMinY / snapStep).floor() * snapStep); }

      if (_commonMinY < 0) _commonMinY = 0;
      if (_commonMaxY <= _commonMinY) _commonMaxY = _commonMinY + 50;
    } else {
      _commonMinY = 50; _commonMaxY = 250; // Adjusted default
    }
    if (_commonMinY == _commonMaxY) {
      _commonMinY = max(0, _commonMinY -25);
      _commonMaxY = _commonMaxY + 25;
    }
    if (mounted) { setState(() { _isLoading = false; });}
  }

  Widget _buildDaysSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer, // Changed for subtlety
          borderRadius: BorderRadius.circular(10.0), // M3 Radius
          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.7))
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _numberOfDays,
          icon: Icon(Icons.expand_more_rounded, color: theme.colorScheme.onSurfaceVariant),
          elevation: 3, // M3 Elevation
          style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface),
          dropdownColor: theme.colorScheme.surfaceContainerHigh,
          onChanged: (int? newValue) {
            if (newValue != null && !_isLoading) {
              setState(() { _numberOfDays = newValue; });
              _loadChartData();
            }
          },
          items: <int>[1, 2, 3, 5, 7] // Adjusted options for overlay clarity
              .map<DropdownMenuItem<int>>((int value) {
            return DropdownMenuItem<int>(
              value: value,
              child: Text('$value día${value == 1 ? '' : 's'}'),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLegend(ThemeData theme) {
    if (_periodColors.isEmpty) return const SizedBox.shrink();
    List<Widget> legendItems = [];
    for (var period in _orderedPeriodsForLegend) {
      final color = _periodColors[period] ?? Colors.transparent;
      final periodName = period.toString().split('.').last;
      legendItems.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0), // Tighter spacing
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(periodName, style: theme.textTheme.labelSmall?.copyWith(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)), // labelSmall
            ]),
          ));
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
      child: Wrap(spacing: 5.0, runSpacing: 2.0, alignment: WrapAlignment.center, children: legendItems),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MainLayout(
      title: 'Glucemia en 24 Horas', // Title more descriptive
      body: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8), // Reduced padding slightly
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6.0, left: 4, right: 4),
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.4), width: 1),
                  color: theme.cardColor.withValues(alpha:0.8),
                ),
                child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      _buildDaysSelector(theme),
                      const SizedBox(width: 10),
                      Text("Registros", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, color: theme.colorScheme.primary, size: 26),
                    onPressed: _isLoading ? null : _loadChartData,
                    tooltip: 'Recargar datos',
                  )
                ],
              ),
              ),
            ),
            if (!_isLoading) _buildLegend(theme),

            if (_isLoading)
              const Expanded(child: Center(child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              )))
            else if (_chartBarsGraph1.isEmpty && _chartBarsGraph2.isEmpty && _chartBarsGraph3.isEmpty)
              Expanded( child: Center( child: Padding( padding: const EdgeInsets.all(24.0),
                child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.bar_chart_rounded, size: 72, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.35)),
                  const SizedBox(height: 20),
                  Text( 'No hay registros de comidas', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.9)), textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text( 'en los últimos $_numberOfDays día${_numberOfDays == 1 ? '' : 's'}.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7)), textAlign: TextAlign.center),
                ],
                ),
              ),
              ))
            else
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(), // Added bouncing physics to main scroll
                  child: Column(
                    children: [
                      _buildChartSection("Madrugada (00:00 - 08:00)", _chartBarsGraph1, _sourceLogsG1, _g1MinX, _g1MaxX, theme),
                      _buildChartSection("Mañana/Tarde (08:00 - 16:00)", _chartBarsGraph2, _sourceLogsG2, _g2MinX, _g2MaxX, theme),
                      _buildChartSection("Tarde/Noche (16:00 - 24:00)", _chartBarsGraph3, _sourceLogsG3, _g3MinX, _g3MaxX, theme),
                    ],
                  ),
                ),
              ),
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
        SizedBox(
          height: 280, // Increased height applied here
          child: Card(
            elevation: 2.0, // M3 standard elevation
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)), // Modern M3 radius
            color: theme.colorScheme.surfaceContainer, // M3 surface color
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 10, left: 8, right: 12), // Adjusted padding
              child: chartBars.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.hourglass_empty_rounded, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5), size: 32),
                const SizedBox(height: 8),
                Text('Sin datos en este tramo horario', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7))),
              ]))
                  : LineChart(
                _buildTimeSlicedChartData(chartBars, sourceLogs, minX, maxX, theme),
                duration: const Duration(milliseconds: 300), // Smooth animation
              ),
            ),
          ),
        ),
      ],
    );
  }

  LineChartData _buildTimeSlicedChartData(List<LineChartBarData> chartBars, List<MealLog> sourceLogs, double minX, double maxX, ThemeData theme) {
    double yRange = _commonMaxY - _commonMinY;
    double intervalY = (yRange / 4).clamp(10.0, 50.0);
    if (yRange <= 20) intervalY = 5; else if (yRange <= 50) intervalY = 10;
    if(intervalY <= 0) intervalY = 20;

    double xRange = maxX - minX; // Should be 8*60 = 480
    double intervalX = 120; // Every 2 hours for an 8-hour slice (0, 2, 4, 6, 8)
    if (xRange <= 240) intervalX = 60; // If slice somehow becomes <= 4h, label hourly

    return LineChartData(
      lineTouchData: LineTouchData(
        enabled: true,
        handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          tooltipRoundedRadius: 10, // Softer radius
          getTooltipColor: (touchedSpot) => theme.colorScheme.secondaryContainer.withOpacity(0.92),
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
              final String dateStr = DateFormat('E dd MMM', 'es_ES').format(sourceLog.startTime); // More readable date

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
      gridData: FlGridData(
        show: true, drawVerticalLine: true, drawHorizontalLine: true,
        horizontalInterval: intervalY, verticalInterval: intervalX,
        getDrawingHorizontalLine: (_) => FlLine(color: theme.colorScheme.outlineVariant.withOpacity(0.3), strokeWidth: 0.8), // M3 outlineVariant
        getDrawingVerticalLine: (_) => FlLine(color: theme.colorScheme.outlineVariant.withOpacity(0.3), strokeWidth: 0.8),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, interval: intervalY, // Increased reservedSize
            getTitlesWidget: (value, meta) => _axisTitleWidgets(value, meta, theme, isXaxis: false)
        )),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: intervalX,
            getTitlesWidget: (value, meta) => _axisTitleWidgets(value, meta, theme, isXaxis: true)
        )),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: true, border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5), width: 1)), // M3 outline
      minX: minX,
      maxX: maxX,
      minY: _commonMinY,
      maxY: _commonMaxY,
      lineBarsData: chartBars,
    );
  }

  Widget _axisTitleWidgets(double value, TitleMeta meta, ThemeData theme, {required bool isXaxis}) {
    final style = theme.textTheme.labelSmall?.copyWith(fontSize: 9, color: theme.colorScheme.onSurfaceVariant); // Consistent font size
    String text = "";

    if (isXaxis) {
      int minutes = value.toInt();
      // Show labels at exact interval stops, plus min and max if they don't coincide
      bool isMin = (value - meta.min).abs() < 1; // Check if it's the min value of axis
      bool isMax = (value - meta.max).abs() < 1; // Check if it's the max value of axis
      bool isIntervalMultiple = meta.appliedInterval > 0 && ((minutes - meta.min) % meta.appliedInterval.round()).abs() < 1;

      if (isMin || isMax || isIntervalMultiple ) {
        final int hour = (minutes ~/ 60) % 24;
        text = hour.toString().padLeft(2,'0'); // Just the hour for brevity
      }
    } else {
      text = meta.formattedValue;
    }
    return SideTitleWidget(axisSide: meta.axisSide, space: 5, child: Text(text, style: style));
  }
}