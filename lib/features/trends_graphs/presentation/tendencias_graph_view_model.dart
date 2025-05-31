// Archivo: lib/features/trends_graphs/presentation/tendencias_graph_view_model.dart
// Descripción: ViewModel para la pantalla de Gráficos de Tendencias de Glucemia (TendenciasGraphScreen).
// Gestiona la lógica para cargar y procesar datos de MealLog, transformándolos en series
// para cuatro gráficos de líneas. Cada gráfico representa un tramo de 6 horas del día:
// 00:00-06:00, 06:00-12:00, 12:00-18:00, y 18:00-24:00.
// Los datos de glucosa de múltiples días (seleccionados por el usuario) se superponen.
// Cada uno de los cuatro gráficos calcula y utiliza su propia escala para el eje Y,
// adaptándose a los datos que contiene.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'dart:math'; // Para funciones matemáticas como min, max, y abs.
import 'package:flutter/material.dart' hide DayPeriod; // Framework principal de Flutter. Se oculta DayPeriod de Material.
import 'package:fl_chart/fl_chart.dart'; // Biblioteca para la creación de gráficos (LineChart).
import 'package:collection/collection.dart'; // Para extensiones de colecciones como .sortedBy.

// Importaciones de archivos del proyecto
import 'package:DiabetiApp/data/models/logs/logs.dart'; // Modelo MealLog.
import 'package:DiabetiApp/core/services/diabetes_calculator_service.dart'; // Servicio para determinar el período del día.
import 'package:DiabetiApp/data/models/calculations/daily_calculation_data.dart' show DayPeriod; // Enum DayPeriod.
import 'package:DiabetiApp/data/repositories/log_repository.dart'; // Repositorio para acceder a los MealLogs.

/// TendenciasGraphViewModel: Gestiona el estado y la lógica para la pantalla de gráficos de tendencias.
class TendenciasGraphViewModel extends ChangeNotifier {
  final LogRepository _logRepository; // Repositorio para el acceso a datos de logs.
  final DiabetesCalculatorService _calculatorService; // Servicio para cálculos auxiliares (ej. DayPeriod).

  /// Constructor: Inyecta las dependencias de LogRepository y DiabetesCalculatorService.
  TendenciasGraphViewModel({
    required LogRepository logRepository,
    required DiabetesCalculatorService calculatorService,
  })  : _logRepository = logRepository,
        _calculatorService = calculatorService;
  // La carga inicial de datos (loadChartData) es invocada por la UI (TendenciasGraphScreen)
  // después de su primer frame, para poder pasar el ThemeData actual si es necesario.

  bool _isLoading = true; // Indica si se están cargando o procesando datos.
  bool get isLoading => _isLoading;

  // --- Propiedades para los datos y ejes Y de los 4 gráficos ---
  // Cada gráfico (G1, G2, G3, G4) tiene su propio conjunto de LineChartBarData,
  // una lista de MealLogs fuente (para tooltips), y sus propios límites para el eje Y.

  // Gráfico 1: Tramo 00:00 - 06:00
  List<LineChartBarData> _chartBarsGraph1 = [];
  List<LineChartBarData> get chartBarsGraph1 => _chartBarsGraph1;
  List<MealLog> _sourceLogsG1 = [];
  List<MealLog> get sourceLogsG1 => _sourceLogsG1;
  double _g1MinY = 50; // Valor Y mínimo inicial para el gráfico 1.
  double get g1MinY => _g1MinY;
  double _g1MaxY = 250; // Valor Y máximo inicial para el gráfico 1.
  double get g1MaxY => _g1MaxY;

  // Gráfico 2: Tramo 06:00 - 12:00
  List<LineChartBarData> _chartBarsGraph2 = [];
  List<LineChartBarData> get chartBarsGraph2 => _chartBarsGraph2;
  List<MealLog> _sourceLogsG2 = [];
  List<MealLog> get sourceLogsG2 => _sourceLogsG2;
  double _g2MinY = 50;
  double get g2MinY => _g2MinY;
  double _g2MaxY = 250;
  double get g2MaxY => _g2MaxY;

  // Gráfico 3: Tramo 12:00 - 18:00
  List<LineChartBarData> _chartBarsGraph3 = [];
  List<LineChartBarData> get chartBarsGraph3 => _chartBarsGraph3;
  List<MealLog> _sourceLogsG3 = [];
  List<MealLog> get sourceLogsG3 => _sourceLogsG3;
  double _g3MinY = 50;
  double get g3MinY => _g3MinY;
  double _g3MaxY = 250;
  double get g3MaxY => _g3MaxY;

  // Gráfico 4: Tramo 18:00 - 24:00
  List<LineChartBarData> _chartBarsGraph4 = [];
  List<LineChartBarData> get chartBarsGraph4 => _chartBarsGraph4;
  List<MealLog> _sourceLogsG4 = [];
  List<MealLog> get sourceLogsG4 => _sourceLogsG4;
  double _g4MinY = 50;
  double get g4MinY => _g4MinY;
  double _g4MaxY = 250;
  double get g4MaxY => _g4MaxY;
  // --- Fin de propiedades para gráficos ---

  int _numberOfDays = 5; // Número de días de datos a mostrar por defecto.
  int get numberOfDays => _numberOfDays;

  // Constantes para los límites del eje X (en minutos desde la medianoche) para cada gráfico.
  // Cada tramo es de 6 horas (360 minutos).
  static const double g1MinX = 0;        // Gráfico 1: 00:00
  static const double g1MaxX = 6 * 60;   // Gráfico 1: 06:00 (360 min)
  static const double g2MinX = 6 * 60;   // Gráfico 2: 06:00 (360 min)
  static const double g2MaxX = 12 * 60;  // Gráfico 2: 12:00 (720 min)
  static const double g3MinX = 12 * 60;  // Gráfico 3: 12:00 (720 min)
  static const double g3MaxX = 18 * 60;  // Gráfico 3: 18:00 (1080 min)
  static const double g4MinX = 18 * 60;  // Gráfico 4: 18:00 (1080 min)
  static const double g4MaxX = 24 * 60;  // Gráfico 4: 24:00 (1440 min)

  // Mapa de colores para cada período del día, usado para las líneas del gráfico.
  final Map<DayPeriod, Color> periodColors = {
    DayPeriod.P7: Colors.purple.shade300, DayPeriod.P1: Colors.red.shade300,
    DayPeriod.P2: Colors.orange.shade300, DayPeriod.P3: Colors.yellow.shade600,
    DayPeriod.P4: Colors.green.shade400, DayPeriod.P5: Colors.blue.shade300,
    DayPeriod.P6: Colors.indigo.shade300,
  };

  // Lista ordenada de períodos para la leyenda en la UI.
  final List<DayPeriod> orderedPeriodsForLegend = const [
    DayPeriod.P1, DayPeriod.P2, DayPeriod.P3, DayPeriod.P4,
    DayPeriod.P5, DayPeriod.P6, DayPeriod.P7
  ];

  DiabetesCalculatorService get calculatorService => _calculatorService;

  /// _setLoading: Actualiza el estado de carga y notifica a los listeners.
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// updateNumberOfDays: Actualiza el número de días para el análisis y recarga los datos.
  void updateNumberOfDays(int newDays) {
    if (_numberOfDays == newDays || _isLoading) return;
    _numberOfDays = newDays;
    notifyListeners();
    loadChartData(); // El ThemeData se pasará desde la UI.
  }

  /// _interpolateY: Interpola linealmente un valor Y para un targetX dados dos puntos.
  double _interpolateY(double x1, double y1, double x2, double y2, double targetX) {
    if ((x2 - x1).abs() < 1e-6) return y1; // Evita división por cero.
    return y1 + (y2 - y1) * (targetX - x1) / (x2 - x1);
  }

  /// _calculateYAxisLimits: Calcula y establece los límites del eje Y para un gráfico específico.
  /// Aplica padding y redondeo para una visualización óptima.
  void _calculateYAxisLimits(List<double> yValues, Function(double) setMinY, Function(double) setMaxY) {
    if (yValues.isNotEmpty) {
      double minY = yValues.reduce(min).floorToDouble();
      double maxY = yValues.reduce(max).ceilToDouble();
      double yRange = maxY - minY;
      double padding = (yRange == 0) ? 25 : (yRange * 0.20).clamp(15.0, 50.0); // Padding dinámico.

      minY = max(0, minY - padding); // El mínimo no puede ser menor que 0.
      maxY = maxY + padding;

      // Asegura un rango visual mínimo (ej. 60 unidades) y un límite inferior práctico (ej. 40 mg/dL).
      if (maxY - minY < 60) {
        double mid = (minY + maxY) / 2.0;
        minY = max(0, mid - 30);
        maxY = mid + 30;
      }
      if (minY < 40) minY = 40;

      // Redondea los límites a la decena más cercana para etiquetas de eje más limpias.
      minY = (minY / 10).floorToDouble() * 10;
      maxY = (maxY / 10).ceilToDouble() * 10;

      if (minY < 0) minY = 0; // Re-asegura que minY no sea negativo.
      if (maxY <= minY) maxY = minY + 60; // Asegura un rango si maxY termina siendo <= minY.
      if (minY == maxY) {minY = max(0, minY-30); maxY +=30;} // Caso extremo si todos los Y son iguales.

      setMinY(minY); // Establece el minY calculado.
      setMaxY(maxY); // Establece el maxY calculado.
    } else {
      // Valores por defecto si no hay datos para este gráfico específico.
      setMinY(40);
      setMaxY(250);
    }
  }

  /// loadChartData: Carga los MealLogs, los procesa y genera los datos para los cuatro gráficos.
  ///
  /// Para cada día en el rango seleccionado:
  /// - Obtiene los MealLogs y los ordena.
  /// - Para cada MealLog:
  ///   - Genera puntos (FlSpot) para glucosa inicial y, si existe, final.
  ///   - Distribuye estos puntos y los segmentos de línea resultantes entre los cuatro gráficos
  ///     (00-06h, 06-12h, 12-18h, 18-24h), manejando la interpolación en los límites de los tramos.
  ///   - Maneja logs que cruzan la medianoche.
  ///   - Recopila todos los valores Y que caen en cada gráfico para calcular sus límites de eje Y individuales.
  ///
  /// @param themeDataForDots ThemeData opcional, usado para el estilo de los puntos del gráfico.
  Future<void> loadChartData({ThemeData? themeDataForDots}) async {
    _setLoading(true);
    // Limpia datos de gráficos y logs fuente anteriores.
    _chartBarsGraph1 = []; _chartBarsGraph2 = []; _chartBarsGraph3 = []; _chartBarsGraph4 = [];
    _sourceLogsG1 = []; _sourceLogsG2 = []; _sourceLogsG3 = []; _sourceLogsG4 = [];

    // Listas para recolectar valores Y para cada gráfico, para calcular sus ejes Y individuales.
    List<double> g1YValues = [];
    List<double> g2YValues = [];
    List<double> g3YValues = [];
    List<double> g4YValues = [];

    final today = DateTime.now();
    final currentTheme = themeDataForDots ?? ThemeData.light(); // Tema para los puntos.

    // --- Funciones helper para el estilo de los puntos ---
    Color getDotColor(double glucoseValue) {
      if (glucoseValue < 70) return currentTheme.colorScheme.error;
      if (glucoseValue > 180) return Colors.red.shade700;
      return Colors.green.shade500;
    }
    FlDotPainter getDynamicDotPainter(FlSpot spot) {
      Color dotFillColor = getDotColor(spot.y);
      return FlDotCirclePainter(
        radius: 2.6, color: dotFillColor,
        strokeColor: currentTheme.colorScheme.surfaceContainerLowest.withValues(alpha:0.8),
        strokeWidth: 1.0,
      );
    }
    FlDotData getGenericDotData() => FlDotData(
        show: true, getDotPainter: (spot, percent, barData, index) => getDynamicDotPainter(spot));
    // --- Fin de funciones helper para puntos ---

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

        LineChartBarData createSegment(List<FlSpot> spots) => LineChartBarData(
            spots: spots, color: periodLineColor, barWidth: 2.2, isCurved: true,
            isStrokeCapRound: true, dotData: getGenericDotData());
        LineChartBarData createSinglePoint(FlSpot spot) => LineChartBarData(
            spots: [spot], color: periodLineColor, barWidth:0, dotData: getGenericDotData());

        if (mealLog.finalBloodSugar != null && mealLog.endTime != null) {
          double xFinalOriginal = mealLog.endTime!.hour.toDouble() * 60 + mealLog.endTime!.minute.toDouble();
          final double yFinalOriginal = mealLog.finalBloodSugar!;

          double xCurrentStart = xInitial;
          double yCurrentStart = yInitial;
          // Comprueba si el log cruza la medianoche (endTime es de un día diferente a startTime).
          bool crossesMidnight = mealLog.endTime!.day != mealLog.startTime.day;

          if (crossesMidnight) {
            // El log cruza la medianoche.
            // Parte 1: Desde xCurrentStart hasta el final del día (g4MaxX = 24:00).
            // La X del punto final para interpolación se calcula sumando la duración total del log (en minutos)
            // a xCurrentStart, para que la interpolación sea correcta a través del cambio de día.
            double totalDurationMinutes = ((mealLog.endTime!.millisecondsSinceEpoch - mealLog.startTime.millisecondsSinceEpoch) / 60000);
            double yAtDayEnd = _interpolateY(xCurrentStart, yCurrentStart, xCurrentStart + totalDurationMinutes , yFinalOriginal, g4MaxX);

            if (xCurrentStart < g4MaxX) { // Si el log empieza antes de las 24:00 del día actual.
              FlSpot startSpot = FlSpot(xCurrentStart, yCurrentStart);
              FlSpot endSpot = FlSpot(g4MaxX, yAtDayEnd);
              _chartBarsGraph4.add(createSegment([startSpot, endSpot]));
              _sourceLogsG4.add(mealLog);
              g4YValues.addAll([startSpot.y, endSpot.y]); // Añade valores Y para el escalado de G4.
            }

            // Parte 2: Desde el inicio del "día siguiente" (g1MinX = 00:00) hasta xFinalOriginal.
            // xFinalOriginal ya son los minutos del día siguiente.
            if (xFinalOriginal >= g1MinX) { // Si el punto final cae dentro del rango del día.
              FlSpot startSpotNextDay = FlSpot(g1MinX, yAtDayEnd); // Comienza en 00:00 con el Y interpolado.
              FlSpot endSpotNextDay = FlSpot(xFinalOriginal, yFinalOriginal);
              _chartBarsGraph1.add(createSegment([startSpotNextDay, endSpotNextDay]));
              _sourceLogsG1.add(mealLog);
              g1YValues.addAll([startSpotNextDay.y, endSpotNextDay.y]); // Añade valores Y para G1.
            }
            continue; // Pasa al siguiente log.
          }

          // --- Lógica para segmentos que NO cruzan la medianoche ---
          // Se itera por cada tramo horario para ver si el segmento actual del log
          // (xCurrentStart, yCurrentStart) -> (xFinalOriginal, yFinalOriginal)
          // tiene alguna porción dentro de él.

          // Gráfico 1 (00:00 - 06:00)
          if (xCurrentStart < g1MaxX && xFinalOriginal >= g1MinX) { // El log tiene presencia en este tramo.
            // Interpola Y en los límites del tramo si el log empieza antes o termina después.
            double yAtBoundaryStart = (xCurrentStart < g1MinX) ? _interpolateY(xInitial, yInitial, xFinalOriginal, yFinalOriginal, g1MinX) : yCurrentStart;
            double yAtBoundaryEnd = (xFinalOriginal > g1MaxX) ? _interpolateY(xInitial, yInitial, xFinalOriginal, yFinalOriginal, g1MaxX) : yFinalOriginal;
            // Puntos de inicio y fin del segmento DENTRO de este tramo.
            FlSpot s1 = FlSpot(max(g1MinX, xCurrentStart), yAtBoundaryStart);
            FlSpot s2 = FlSpot(min(g1MaxX, xFinalOriginal), yAtBoundaryEnd);
            // Añade el segmento (o punto) si es válido.
            if ((s2.x - s1.x).abs() > 1e-3 || (s1.x == s2.x && xCurrentStart >= g1MinX && xCurrentStart <= g1MaxX)) {
              _chartBarsGraph1.add((s1.x == s2.x) ? createSinglePoint(s1) : createSegment([s1,s2]));
              _sourceLogsG1.add(mealLog);
              g1YValues.addAll([s1.y, s2.y]);
            }
          }
          // Gráfico 2 (06:00 - 12:00) - Lógica análoga.
          if (xCurrentStart < g2MaxX && xFinalOriginal >= g2MinX) {
            double yAtBoundaryStart = (xCurrentStart < g2MinX) ? _interpolateY(xInitial, yInitial, xFinalOriginal, yFinalOriginal, g2MinX) : yCurrentStart;
            double yAtBoundaryEnd = (xFinalOriginal > g2MaxX) ? _interpolateY(xInitial, yInitial, xFinalOriginal, yFinalOriginal, g2MaxX) : yFinalOriginal;
            FlSpot s1 = FlSpot(max(g2MinX, xCurrentStart), yAtBoundaryStart);
            FlSpot s2 = FlSpot(min(g2MaxX, xFinalOriginal), yAtBoundaryEnd);
            if ((s2.x - s1.x).abs() > 1e-3 || (s1.x == s2.x && xCurrentStart >= g2MinX && xCurrentStart <= g2MaxX) ) {
              _chartBarsGraph2.add((s1.x == s2.x) ? createSinglePoint(s1) : createSegment([s1,s2]));
              _sourceLogsG2.add(mealLog);
              g2YValues.addAll([s1.y, s2.y]);
            }
          }
          // Gráfico 3 (12:00 - 18:00) - Lógica análoga.
          if (xCurrentStart < g3MaxX && xFinalOriginal >= g3MinX) {
            double yAtBoundaryStart = (xCurrentStart < g3MinX) ? _interpolateY(xInitial, yInitial, xFinalOriginal, yFinalOriginal, g3MinX) : yCurrentStart;
            double yAtBoundaryEnd = (xFinalOriginal > g3MaxX) ? _interpolateY(xInitial, yInitial, xFinalOriginal, yFinalOriginal, g3MaxX) : yFinalOriginal;
            FlSpot s1 = FlSpot(max(g3MinX, xCurrentStart), yAtBoundaryStart);
            FlSpot s2 = FlSpot(min(g3MaxX, xFinalOriginal), yAtBoundaryEnd);
            if ((s2.x - s1.x).abs() > 1e-3 || (s1.x == s2.x && xCurrentStart >= g3MinX && xCurrentStart <= g3MaxX) ) {
              _chartBarsGraph3.add((s1.x == s2.x) ? createSinglePoint(s1) : createSegment([s1,s2]));
              _sourceLogsG3.add(mealLog);
              g3YValues.addAll([s1.y, s2.y]);
            }
          }
          // Gráfico 4 (18:00 - 24:00) - Lógica análoga.
          if (xCurrentStart < g4MaxX && xFinalOriginal >= g4MinX) {
            double yAtBoundaryStart = (xCurrentStart < g4MinX) ? _interpolateY(xInitial, yInitial, xFinalOriginal, yFinalOriginal, g4MinX) : yCurrentStart;
            double yAtBoundaryEnd = (xFinalOriginal > g4MaxX) ? _interpolateY(xInitial, yInitial, xFinalOriginal, yFinalOriginal, g4MaxX) : yFinalOriginal;
            FlSpot s1 = FlSpot(max(g4MinX, xCurrentStart), yAtBoundaryStart);
            FlSpot s2 = FlSpot(min(g4MaxX, xFinalOriginal), yAtBoundaryEnd); // El X final no puede pasar de g4MaxX.
            if ((s2.x - s1.x).abs() > 1e-3 || (s1.x == s2.x && xCurrentStart >= g4MinX && xCurrentStart <= g4MaxX) ) {
              _chartBarsGraph4.add((s1.x == s2.x) ? createSinglePoint(s1) : createSegment([s1,s2]));
              _sourceLogsG4.add(mealLog);
              g4YValues.addAll([s1.y, s2.y]);
            }
          }

        } else { // Si el log es un punto único (solo glucosa inicial).
          FlSpot spot = FlSpot(xInitial, yInitial);
          if (xInitial < g1MaxX) { // Pertenece al Gráfico 1.
            _chartBarsGraph1.add(createSinglePoint(spot)); _sourceLogsG1.add(mealLog); g1YValues.add(spot.y);
          } else if (xInitial < g2MaxX) { // Pertenece al Gráfico 2.
            _chartBarsGraph2.add(createSinglePoint(spot)); _sourceLogsG2.add(mealLog); g2YValues.add(spot.y);
          } else if (xInitial < g3MaxX) { // Pertenece al Gráfico 3.
            _chartBarsGraph3.add(createSinglePoint(spot)); _sourceLogsG3.add(mealLog); g3YValues.add(spot.y);
          } else if (xInitial <= g4MaxX) { // Pertenece al Gráfico 4 (hasta 24:00 inclusive).
            _chartBarsGraph4.add(createSinglePoint(spot)); _sourceLogsG4.add(mealLog); g4YValues.add(spot.y);
          }
        }
      }
    }

    // Calcula los límites Y para cada gráfico individualmente.
    _calculateYAxisLimits(g1YValues, (minVal) => _g1MinY = minVal, (maxVal) => _g1MaxY = maxVal);
    _calculateYAxisLimits(g2YValues, (minVal) => _g2MinY = minVal, (maxVal) => _g2MaxY = maxVal);
    _calculateYAxisLimits(g3YValues, (minVal) => _g3MinY = minVal, (maxVal) => _g3MaxY = maxVal);
    _calculateYAxisLimits(g4YValues, (minVal) => _g4MinY = minVal, (maxVal) => _g4MaxY = maxVal);

    _setLoading(false); // Finaliza el estado de carga.
  }
}