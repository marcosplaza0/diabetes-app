// lib/features/trends_graphs/presentation/tendencias_graph_view_model.dart
import 'dart:math';
import 'package:flutter/material.dart' hide DayPeriod;
import 'package:fl_chart/fl_chart.dart';
import 'package:collection/collection.dart'; // Para .sortedBy
import 'package:intl/intl.dart'; // Para DateFormat y DateUtils

import 'package:diabetes_2/data/models/logs/logs.dart';
import 'package:diabetes_2/core/services/diabetes_calculator_service.dart';
import 'package:diabetes_2/data/models/calculations/daily_calculation_data.dart' show DayPeriod; // Solo el enum
import 'package:diabetes_2/data/repositories/log_repository.dart';

class TendenciasGraphViewModel extends ChangeNotifier {
  final LogRepository _logRepository;
  final DiabetesCalculatorService _calculatorService;

  TendenciasGraphViewModel({
    required LogRepository logRepository,
    required DiabetesCalculatorService calculatorService,
  })  : _logRepository = logRepository,
        _calculatorService = calculatorService {
    loadChartData(); // Cargar datos iniciales
  }

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  List<LineChartBarData> _chartBarsGraph1 = [];
  List<LineChartBarData> get chartBarsGraph1 => _chartBarsGraph1;
  List<MealLog> _sourceLogsG1 = []; // Para tooltips
  List<MealLog> get sourceLogsG1 => _sourceLogsG1;

  List<LineChartBarData> _chartBarsGraph2 = [];
  List<LineChartBarData> get chartBarsGraph2 => _chartBarsGraph2;
  List<MealLog> _sourceLogsG2 = [];
  List<MealLog> get sourceLogsG2 => _sourceLogsG2;

  List<LineChartBarData> _chartBarsGraph3 = [];
  List<LineChartBarData> get chartBarsGraph3 => _chartBarsGraph3;
  List<MealLog> _sourceLogsG3 = [];
  List<MealLog> get sourceLogsG3 => _sourceLogsG3;

  double _commonMinY = 50;
  double get commonMinY => _commonMinY;
  double _commonMaxY = 200;
  double get commonMaxY => _commonMaxY;

  int _numberOfDays = 3; // Valor por defecto
  int get numberOfDays => _numberOfDays;

  // Constantes para los límites X de los gráficos (minutos desde medianoche)
  static const double g1MinX = 0;      // 00:00
  static const double g1MaxX = 8 * 60; // 08:00
  static const double g2MinX = 8 * 60; // 08:00
  static const double g2MaxX = 16 * 60;// 16:00
  static const double g3MinX = 16 * 60;// 16:00
  static const double g3MaxX = 24 * 60;// 24:00

  final Map<DayPeriod, Color> periodColors = { // Exponer para la leyenda en la UI
    DayPeriod.P7: Colors.purple.shade300, DayPeriod.P1: Colors.red.shade300,
    DayPeriod.P2: Colors.orange.shade300, DayPeriod.P3: Colors.yellow.shade600,
    DayPeriod.P4: Colors.green.shade400, DayPeriod.P5: Colors.blue.shade300,
    DayPeriod.P6: Colors.indigo.shade300,
  };

  final List<DayPeriod> orderedPeriodsForLegend = const [ // Exponer para la leyenda
    DayPeriod.P1, DayPeriod.P2, DayPeriod.P3, DayPeriod.P4,
    DayPeriod.P5, DayPeriod.P6, DayPeriod.P7
  ];

  // El servicio de cálculo se expone si la UI lo necesita para helpers (ej. getDayPeriod en tooltips)
  DiabetesCalculatorService get calculatorService => _calculatorService;


  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void updateNumberOfDays(int newDays) {
    if (_numberOfDays == newDays || _isLoading) return;
    _numberOfDays = newDays;
    notifyListeners(); // Notificar cambio de días para la UI del selector
    loadChartData();
  }

  double _interpolateY(double x1, double y1, double x2, double y2, double targetX) {
    if ((x2 - x1).abs() < 1e-6) return y1;
    return y1 + (y2 - y1) * (targetX - x1) / (x2 - x1);
  }

  // Necesitamos el ThemeData para los colores de los puntos
  Future<void> loadChartData({ThemeData? themeDataForDots}) async {
    _setLoading(true);
    _chartBarsGraph1 = []; _chartBarsGraph2 = []; _chartBarsGraph3 = [];
    _sourceLogsG1 = []; _sourceLogsG2 = []; _sourceLogsG3 = [];

    final List<double> allYValues = [];
    final today = DateTime.now();

    // Si no se pasa themeDataForDots, usamos uno por defecto (esto es un fallback)
    final currentTheme = themeDataForDots ?? ThemeData.light(); // O ThemeData.dark()

    Color getDotColor(double glucoseValue) {
      if (glucoseValue < 70) return currentTheme.colorScheme.error;
      if (glucoseValue > 180) return Colors.red.shade700;
      return Colors.green.shade500;
    }

    FlDotPainter getDynamicDotPainter(FlSpot spot) {
      Color dotFillColor = getDotColor(spot.y);
      return FlDotCirclePainter(
        radius: 2.6, color: dotFillColor,
        strokeColor: currentTheme.colorScheme.surfaceContainerLowest.withOpacity(0.8),
        strokeWidth: 1.0,
      );
    }
    FlDotData getGenericDotData() => FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) => getDynamicDotPainter(spot)
    );


    final endDateForQuery = DateTime(today.year, today.month, today.day, 23, 59, 59);
    final startDateForQuery = DateTime(today.year, today.month, today.day - (_numberOfDays - 1), 0, 0, 0);
    final List<MealLog> allRelevantLogs = await _logRepository.getMealLogsInDateRange(startDateForQuery, endDateForQuery);

    for (int dayIndex = 0; dayIndex < _numberOfDays; dayIndex++) {
      final loopDate = DateTime(today.year, today.month, today.day - dayIndex);
      final List<MealLog> logsForDay = allRelevantLogs
          .where((log) => DateUtils.isSameDay(log.startTime, loopDate))
          .sortedBy((log) => log.startTime)
          .toList();

      for (final mealLog in logsForDay) {
        DayPeriod period = _calculatorService.getDayPeriod(mealLog.startTime);
        Color periodLineColor = periodColors[period] ?? Colors.grey.shade300;

        final double xInitial = mealLog.startTime.hour.toDouble() * 60 + mealLog.startTime.minute.toDouble();
        final double yInitial = mealLog.initialBloodSugar;
        allYValues.add(yInitial);
        FlSpot spotInitial = FlSpot(xInitial, yInitial);

        LineChartBarData createSegment(List<FlSpot> spots) => LineChartBarData(
            spots: spots, color: periodLineColor, barWidth: 2.2, isCurved: true,
            isStrokeCapRound: true, dotData: getGenericDotData());
        LineChartBarData createSinglePoint(FlSpot spot) => LineChartBarData(
            spots: [spot], color: periodLineColor, barWidth:0, dotData: getGenericDotData());

        if (mealLog.finalBloodSugar != null && mealLog.endTime != null) {
          double xFinal = mealLog.endTime!.hour.toDouble() * 60 + mealLog.endTime!.minute.toDouble();
          final double yFinal = mealLog.finalBloodSugar!;
          allYValues.add(yFinal);
          // FlSpot spotFinal = FlSpot(xFinal, yFinal); // No se usa directamente aquí

          if (xFinal < xInitial && (xInitial - xFinal).abs() > 12*60 ) { // Cruza medianoche
            double yAtDayEnd = _interpolateY(xInitial, yInitial, xInitial + (1440.0 - xInitial + xFinal) , yFinal, g3MaxX);
            FlSpot endOfDaySpot = FlSpot(g3MaxX, yAtDayEnd);
            if (spotInitial.x < g3MaxX) {
              _chartBarsGraph3.add(createSegment([spotInitial, endOfDaySpot])); _sourceLogsG3.add(mealLog);
            }
            FlSpot startOfNextDaySpot = FlSpot(g1MinX, yAtDayEnd);
            if (FlSpot(xFinal, yFinal).x >= g1MinX) { // Corregido: usar FlSpot(xFinal, yFinal)
              _chartBarsGraph1.add(createSegment([startOfNextDaySpot, FlSpot(xFinal, yFinal)])); _sourceLogsG1.add(mealLog);
            }
            continue;
          }
          double currentX1 = xInitial; double currentY1 = yInitial;
          double currentX2 = xFinal;   double currentY2 = yFinal;

          if (currentX1 < g1MaxX) {
            FlSpot s1_g1 = FlSpot(currentX1, currentY1);
            if (currentX2 <= g1MaxX) {
              _chartBarsGraph1.add(createSegment([s1_g1, FlSpot(currentX2, currentY2)])); _sourceLogsG1.add(mealLog);
            } else {
              double yAtBoundary = _interpolateY(currentX1, currentY1, currentX2, currentY2, g1MaxX);
              _chartBarsGraph1.add(createSegment([s1_g1, FlSpot(g1MaxX, yAtBoundary)])); _sourceLogsG1.add(mealLog);
              currentX1 = g1MaxX; currentY1 = yAtBoundary;
            }
          }
          if (currentX1 < g2MaxX && currentX2 >= g2MinX && currentX1 < currentX2) {
            FlSpot s1_g2 = (currentX1 >= g2MinX) ? FlSpot(currentX1, currentY1) : FlSpot(g2MinX, _interpolateY(xInitial,yInitial, xFinal, yFinal, g2MinX));
            if (currentX2 <= g2MaxX) {
              _chartBarsGraph2.add(createSegment([s1_g2, FlSpot(currentX2, currentY2)])); _sourceLogsG2.add(mealLog);
            } else {
              double yAtBoundary = _interpolateY(xInitial, yInitial, xFinal, yFinal, g2MaxX);
              _chartBarsGraph2.add(createSegment([s1_g2, FlSpot(g2MaxX, yAtBoundary)])); _sourceLogsG2.add(mealLog);
              currentX1 = g2MaxX; currentY1 = yAtBoundary;
            }
          }
          if (currentX1 < g3MaxX && currentX2 >= g3MinX && currentX1 < currentX2) {
            FlSpot s1_g3 = (currentX1 >= g3MinX) ? FlSpot(currentX1, currentY1) : FlSpot(g3MinX, _interpolateY(xInitial,yInitial, xFinal, yFinal, g3MinX));
            FlSpot s2_g3 = FlSpot(min(g3MaxX, currentX2), currentY2);
            if (currentX2 > g3MaxX) s2_g3 = FlSpot(g3MaxX, _interpolateY(xInitial, yInitial, xFinal, yFinal, g3MaxX));
            if ((s2_g3.x - s1_g3.x).abs() > 1e-3) {
              _chartBarsGraph3.add(createSegment([s1_g3,s2_g3])); _sourceLogsG3.add(mealLog);
            } else if (s1_g3.x <= g3MaxX) {
              _chartBarsGraph3.add(createSinglePoint(s1_g3)); _sourceLogsG3.add(mealLog);
            }
          }
        } else { // Single point
          if (xInitial < g1MaxX) {
            _chartBarsGraph1.add(createSinglePoint(spotInitial)); _sourceLogsG1.add(mealLog);
          } else if (xInitial < g2MaxX) {
            _chartBarsGraph2.add(createSinglePoint(spotInitial)); _sourceLogsG2.add(mealLog);
          } else if (xInitial <= g3MaxX) {
            _chartBarsGraph3.add(createSinglePoint(spotInitial)); _sourceLogsG3.add(mealLog);
          }
        }
      }
    }

    if (allYValues.isNotEmpty) {
      _commonMinY = allYValues.reduce(min).floorToDouble(); _commonMaxY = allYValues.reduce(max).ceilToDouble();
      double yRange = _commonMaxY - _commonMinY;
      double padding = (yRange == 0) ? 25 : (yRange * 0.20).clamp(15.0, 50.0); // Ajustado para asegurar rango visual
      _commonMinY = max(0, _commonMinY - padding); _commonMaxY = _commonMaxY + padding;
      if (_commonMaxY - _commonMinY < 60) { double mid = (_commonMinY + _commonMaxY) / 2.0; _commonMinY = max(0, mid - 30); _commonMaxY = mid + 30; }
      if(_commonMinY < 40) _commonMinY = 40; // Límite inferior visual mínimo
      _commonMinY = (_commonMinY / 10).floorToDouble() * 10; // Redondear a la decena inferior
      _commonMaxY = (_commonMaxY / 10).ceilToDouble() * 10;   // Redondear a la decena superior
      if (_commonMinY < 0) _commonMinY = 0;
      if (_commonMaxY <= _commonMinY) _commonMaxY = _commonMinY + 60; // Asegurar un rango mínimo
    } else { _commonMinY = 40; _commonMaxY = 250; }
    if (_commonMinY == _commonMaxY) { _commonMinY = max(0, _commonMinY -30); _commonMaxY = _commonMaxY + 30; }

    _setLoading(false);
  }
}