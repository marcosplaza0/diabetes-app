// Archivo: lib/features/trends_graphs/presentation/tendencias_graph_view_model.dart
// Descripción: ViewModel para la pantalla de Gráficos de Tendencias de Glucemia (TendenciasGraphScreen).
// Este archivo contiene la lógica de negocio y el estado para cargar, procesar y preparar
// los datos de glucosa para ser mostrados en tres gráficos de líneas separados,
// cada uno representando un tramo de 8 horas del día (0-8h, 8-16h, 16-24h).
// Superpone los datos de glucosa de varios días seleccionados por el usuario.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'dart:math'; // Para funciones matemáticas como min, max, y abs.
import 'package:flutter/material.dart' hide DayPeriod; // Framework principal de Flutter para UI. Se oculta DayPeriod de Material.
import 'package:fl_chart/fl_chart.dart'; // Biblioteca para la creación de gráficos.
import 'package:collection/collection.dart'; // Para extensiones de colecciones como .sortedBy.

// Importaciones de archivos del proyecto
import 'package:diabetes_2/data/models/logs/logs.dart'; // Modelo MealLog para obtener los datos de glucosa.
import 'package:diabetes_2/core/services/diabetes_calculator_service.dart'; // Para determinar el período del día de un log.
import 'package:diabetes_2/data/models/calculations/daily_calculation_data.dart' show DayPeriod; // Enum DayPeriod.
import 'package:diabetes_2/data/repositories/log_repository.dart'; // Repositorio para acceder a los MealLogs.

/// TendenciasGraphViewModel: Gestiona el estado y la lógica para TendenciasGraphScreen.
///
/// Responsabilidades:
/// - Cargar los `MealLog`s para el número de días seleccionado.
/// - Procesar estos logs para generar series de puntos (`FlSpot`) para cada uno de los tres gráficos.
/// - Manejar la lógica de interpolación y división de líneas de glucosa que cruzan los límites de los tramos horarios.
/// - Calcular los límites comunes del eje Y para todos los gráficos para una escala consistente.
/// - Exponer los datos del gráfico (`LineChartBarData`) y los logs fuente (para tooltips) a la UI.
class TendenciasGraphViewModel extends ChangeNotifier {
  final LogRepository _logRepository; // Repositorio para acceder a los datos de logs.
  final DiabetesCalculatorService _calculatorService; // Servicio para cálculos (ej. obtener DayPeriod).

  /// Constructor: Requiere instancias de LogRepository y DiabetesCalculatorService.
  /// Llama a `loadChartData()` para la carga inicial de datos.
  TendenciasGraphViewModel({
    required LogRepository logRepository,
    required DiabetesCalculatorService calculatorService,
  })  : _logRepository = logRepository,
        _calculatorService = calculatorService {
    // No se llama a loadChartData aquí directamente porque puede depender de `ThemeData`
    // que se pasa desde la UI después del primer frame. La UI se encarga de la llamada inicial.
  }

  bool _isLoading = true; // Indica si se están cargando o procesando datos.
  bool get isLoading => _isLoading;

  // Listas para almacenar los datos de las barras de los gráficos y los logs fuente para los tooltips.
  // Hay un conjunto para cada uno de los tres gráficos (G1: 0-8h, G2: 8-16h, G3: 16-24h).
  List<LineChartBarData> _chartBarsGraph1 = [];
  List<LineChartBarData> get chartBarsGraph1 => _chartBarsGraph1;
  List<MealLog> _sourceLogsG1 = []; // Logs originales para el gráfico 1 (tooltips).
  List<MealLog> get sourceLogsG1 => _sourceLogsG1;

  List<LineChartBarData> _chartBarsGraph2 = [];
  List<LineChartBarData> get chartBarsGraph2 => _chartBarsGraph2;
  List<MealLog> _sourceLogsG2 = [];
  List<MealLog> get sourceLogsG2 => _sourceLogsG2;

  List<LineChartBarData> _chartBarsGraph3 = [];
  List<LineChartBarData> get chartBarsGraph3 => _chartBarsGraph3;
  List<MealLog> _sourceLogsG3 = [];
  List<MealLog> get sourceLogsG3 => _sourceLogsG3;

  // Límites comunes para el eje Y, para asegurar que todos los gráficos tengan la misma escala vertical.
  double _commonMinY = 50; // Valor mínimo por defecto para el eje Y.
  double get commonMinY => _commonMinY;
  double _commonMaxY = 200; // Valor máximo por defecto para el eje Y.
  double get commonMaxY => _commonMaxY;

  int _numberOfDays = 3; // Número de días de datos a mostrar por defecto.
  int get numberOfDays => _numberOfDays;

  // Constantes para los límites del eje X (en minutos desde la medianoche) para cada gráfico.
  static const double g1MinX = 0;      // Gráfico 1: 00:00
  static const double g1MaxX = 8 * 60; // Gráfico 1: 08:00
  static const double g2MinX = 8 * 60; // Gráfico 2: 08:00
  static const double g2MaxX = 16 * 60;// Gráfico 2: 16:00
  static const double g3MinX = 16 * 60;// Gráfico 3: 16:00
  static const double g3MaxX = 24 * 60;// Gráfico 3: 24:00 (o 1440 minutos)

  // Mapa de colores para cada período del día, usado para colorear las líneas del gráfico.
  // Se expone para que la leyenda en la UI pueda usar los mismos colores.
  final Map<DayPeriod, Color> periodColors = {
    DayPeriod.P7: Colors.purple.shade300, DayPeriod.P1: Colors.red.shade300,
    DayPeriod.P2: Colors.orange.shade300, DayPeriod.P3: Colors.yellow.shade600,
    DayPeriod.P4: Colors.green.shade400, DayPeriod.P5: Colors.blue.shade300,
    DayPeriod.P6: Colors.indigo.shade300,
  };

  // Lista ordenada de períodos para mostrar en la leyenda de la UI.
  final List<DayPeriod> orderedPeriodsForLegend = const [
    DayPeriod.P1, DayPeriod.P2, DayPeriod.P3, DayPeriod.P4,
    DayPeriod.P5, DayPeriod.P6, DayPeriod.P7
  ];

  DiabetesCalculatorService get calculatorService => _calculatorService;


  /// _setLoading: Método privado para actualizar el estado de carga y notificar a los listeners.
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners(); // Notifica a la UI para que se reconstruya.
  }

  /// updateNumberOfDays: Actualiza el número de días para el análisis y recarga los datos del gráfico.
  ///
  /// @param newDays El nuevo número de días seleccionado por el usuario.
  void updateNumberOfDays(int newDays) {
    if (_numberOfDays == newDays || _isLoading) return; // No hacer nada si no hay cambio o ya está cargando.
    _numberOfDays = newDays;
    notifyListeners(); // Notifica para que la UI del selector se actualice.
    loadChartData();   // Recarga los datos del gráfico para el nuevo número de días.
    // El ThemeData para los puntos se obtendrá del tema actual en la UI si es necesario,
    // o se podría pasar aquí si la UI lo gestiona.
  }

  /// _interpolateY: Realiza una interpolación lineal para encontrar un valor Y en un targetX
  /// dados dos puntos (x1, y1) y (x2, y2).
  ///
  /// @param x1 Coordenada X del primer punto.
  /// @param y1 Coordenada Y del primer punto.
  /// @param x2 Coordenada X del segundo punto.
  /// @param y2 Coordenada Y del segundo punto.
  /// @param targetX La coordenada X para la cual se quiere interpolar Y.
  /// @return El valor Y interpolado.
  double _interpolateY(double x1, double y1, double x2, double y2, double targetX) {
    if ((x2 - x1).abs() < 1e-6) return y1; // Evita división por cero si los puntos X son iguales.
    return y1 + (y2 - y1) * (targetX - x1) / (x2 - x1);
  }

  /// loadChartData: Carga los datos de MealLog, los procesa y prepara las series para los tres gráficos.
  ///
  /// Procesa cada `MealLog` para generar segmentos de línea (`LineChartBarData`) que se distribuirán
  /// entre los tres gráficos según el tramo horario. Maneja la interpolación de líneas
  /// que cruzan los límites de estos tramos. También calcula los límites comunes del eje Y.
  ///
  /// @param themeDataForDots ThemeData opcional para aplicar estilos a los puntos del gráfico.
  ///                        Si no se provee, se usará un tema por defecto (ej. `ThemeData.light()`).
  Future<void> loadChartData({ThemeData? themeDataForDots}) async {
    _setLoading(true);
    // Limpia los datos de gráficos anteriores.
    _chartBarsGraph1 = []; _chartBarsGraph2 = []; _chartBarsGraph3 = [];
    _sourceLogsG1 = []; _sourceLogsG2 = []; _sourceLogsG3 = [];

    final List<double> allYValues = []; // Para calcular min/max Y comunes.
    final today = DateTime.now();

    // Si no se pasa themeDataForDots, usamos uno por defecto (esto es un fallback).
    final currentTheme = themeDataForDots ?? ThemeData.light();

    // Determina el color del punto basado en el valor de glucosa.
    Color getDotColor(double glucoseValue) {
      if (glucoseValue < 70) return currentTheme.colorScheme.error;
      if (glucoseValue > 180) return Colors.red.shade700; // Un rojo más intenso para hiper.
      return Colors.green.shade500; // Verde para en rango.
    }
    // Define cómo se dibujarán los puntos en el gráfico.
    FlDotPainter getDynamicDotPainter(FlSpot spot) {
      Color dotFillColor = getDotColor(spot.y); // Color del relleno del punto.
      return FlDotCirclePainter(
        radius: 2.6, // Radio del punto.
        color: dotFillColor, // Color de relleno.
        strokeColor: currentTheme.colorScheme.surfaceContainerLowest.withOpacity(0.8), // Color del borde del punto.
        strokeWidth: 1.0, // Ancho del borde del punto.
      );
    }
    // Configuración genérica para los datos de los puntos.
    FlDotData getGenericDotData() => FlDotData(
        show: true, // Mostrar puntos.
        getDotPainter: (spot, percent, barData, index) => getDynamicDotPainter(spot) // Usa el painter dinámico.
    );

    // Define el rango de fechas para la consulta de logs.
    final endDateForQuery = DateTime(today.year, today.month, today.day, 23, 59, 59);
    final startDateForQuery = DateTime(today.year, today.month, today.day - (_numberOfDays - 1), 0, 0, 0);
    // Obtiene todos los MealLogs relevantes del repositorio.
    final List<MealLog> allRelevantLogs = await _logRepository.getMealLogsInDateRange(startDateForQuery, endDateForQuery); //

    // Itera sobre el número de días seleccionados, desde hoy hacia atrás.
    for (int dayIndex = 0; dayIndex < _numberOfDays; dayIndex++) {
      final loopDate = DateTime(today.year, today.month, today.day - dayIndex);
      // Filtra los logs para el día actual del bucle y los ordena por hora de inicio.
      final List<MealLog> logsForDay = allRelevantLogs
          .where((log) => DateUtils.isSameDay(log.startTime, loopDate)) //
          .sortedBy((log) => log.startTime) //
          .toList();

      // Procesa cada log del día.
      for (final mealLog in logsForDay) {
        DayPeriod period = _calculatorService.getDayPeriod(mealLog.startTime); // Determina el período del día. //
        Color periodLineColor = periodColors[period] ?? Colors.grey.shade300; // Color de la línea según el período.

        // Convierte la hora de inicio a minutos desde la medianoche (eje X).
        final double xInitial = mealLog.startTime.hour.toDouble() * 60 + mealLog.startTime.minute.toDouble(); //
        final double yInitial = mealLog.initialBloodSugar; // Valor de glucosa (eje Y). //
        allYValues.add(yInitial); // Añade a la lista para calcular Y min/max.
        FlSpot spotInitial = FlSpot(xInitial, yInitial); // Punto inicial.

        // Funciones helper para crear segmentos de línea o puntos individuales.
        LineChartBarData createSegment(List<FlSpot> spots) => LineChartBarData(
            spots: spots, color: periodLineColor, barWidth: 2.2, isCurved: true,
            isStrokeCapRound: true, dotData: getGenericDotData());
        LineChartBarData createSinglePoint(FlSpot spot) => LineChartBarData(
            spots: [spot], color: periodLineColor, barWidth:0, // barWidth 0 para que solo se vea el punto.
            dotData: getGenericDotData());

        // Si el log tiene glucosa final y hora final, se crea un segmento de línea.
        if (mealLog.finalBloodSugar != null && mealLog.endTime != null) { //
          double xFinal = mealLog.endTime!.hour.toDouble() * 60 + mealLog.endTime!.minute.toDouble(); //
          final double yFinal = mealLog.finalBloodSugar!; //
          allYValues.add(yFinal);

          // --- Lógica para dividir líneas que cruzan los límites de los gráficos ---
          // Caso especial: la línea cruza la medianoche (ej. empieza a las 23:00 y termina a las 02:00 del día siguiente).
          // (xInitial - xFinal).abs() > 12*60 es una heurística para detectar cruce de medianoche hacia adelante.
          if (xFinal < xInitial && (xInitial - xFinal).abs() > 12*60 ) {
            // Calcula el valor Y interpolado al final del día (g3MaxX).
            double yAtDayEnd = _interpolateY(xInitial, yInitial, xInitial + (1440.0 - xInitial + xFinal) , yFinal, g3MaxX);
            FlSpot endOfDaySpot = FlSpot(g3MaxX, yAtDayEnd);
            // Si el punto inicial está dentro del gráfico 3, dibuja el segmento hasta el final del día.
            if (spotInitial.x < g3MaxX) {
              _chartBarsGraph3.add(createSegment([spotInitial, endOfDaySpot])); _sourceLogsG3.add(mealLog);
            }
            // El punto de inicio para el día siguiente será el valor Y interpolado al principio del día (g1MinX).
            FlSpot startOfNextDaySpot = FlSpot(g1MinX, yAtDayEnd);
            // Si el punto final original (ya en el día siguiente) está dentro del gráfico 1, dibuja el segmento.
            if (FlSpot(xFinal, yFinal).x >= g1MinX) {
              _chartBarsGraph1.add(createSegment([startOfNextDaySpot, FlSpot(xFinal, yFinal)])); _sourceLogsG1.add(mealLog);
            }
            continue; // Pasa al siguiente log.
          }

          // Lógica general para dividir un segmento de línea (xInitial,yInitial) -> (xFinal,yFinal)
          // entre los tres gráficos G1, G2, G3.
          double currentX1 = xInitial; double currentY1 = yInitial; // Punto de inicio del segmento actual.
          double currentX2 = xFinal;   double currentY2 = yFinal;   // Punto final del segmento original.

          // Procesamiento para el Gráfico 1 (00:00 - 08:00)
          if (currentX1 < g1MaxX) { // Si el segmento empieza antes del fin de G1.
            FlSpot s1_g1 = FlSpot(currentX1, currentY1);
            if (currentX2 <= g1MaxX) { // Si el segmento termina dentro de G1.
              _chartBarsGraph1.add(createSegment([s1_g1, FlSpot(currentX2, currentY2)])); _sourceLogsG1.add(mealLog);
            } else { // Si el segmento cruza el límite de G1.
              double yAtBoundary = _interpolateY(currentX1, currentY1, currentX2, currentY2, g1MaxX); // Interpola Y en el límite.
              _chartBarsGraph1.add(createSegment([s1_g1, FlSpot(g1MaxX, yAtBoundary)])); _sourceLogsG1.add(mealLog);
              // Actualiza el punto de inicio para el siguiente tramo de gráfico.
              currentX1 = g1MaxX; currentY1 = yAtBoundary;
            }
          }
          // Procesamiento para el Gráfico 2 (08:00 - 16:00)
          // Si el segmento (o lo que queda de él) entra en G2.
          if (currentX1 < g2MaxX && currentX2 >= g2MinX && currentX1 < currentX2) {
            // Determina el punto de entrada a G2. Si ya estaba en G2, usa (currentX1, currentY1).
            // Si viene de G1, interpola en g2MinX.
            FlSpot s1_g2 = (currentX1 >= g2MinX) ? FlSpot(currentX1, currentY1) : FlSpot(g2MinX, _interpolateY(xInitial,yInitial, xFinal, yFinal, g2MinX));
            if (currentX2 <= g2MaxX) { // Si el segmento termina dentro de G2.
              _chartBarsGraph2.add(createSegment([s1_g2, FlSpot(currentX2, currentY2)])); _sourceLogsG2.add(mealLog);
            } else { // Si el segmento cruza el límite de G2.
              double yAtBoundary = _interpolateY(xInitial, yInitial, xFinal, yFinal, g2MaxX);
              _chartBarsGraph2.add(createSegment([s1_g2, FlSpot(g2MaxX, yAtBoundary)])); _sourceLogsG2.add(mealLog);
              currentX1 = g2MaxX; currentY1 = yAtBoundary;
            }
          }
          // Procesamiento para el Gráfico 3 (16:00 - 24:00)
          if (currentX1 < g3MaxX && currentX2 >= g3MinX && currentX1 < currentX2) {
            FlSpot s1_g3 = (currentX1 >= g3MinX) ? FlSpot(currentX1, currentY1) : FlSpot(g3MinX, _interpolateY(xInitial,yInitial, xFinal, yFinal, g3MinX));
            // El punto final del segmento en G3 es el mínimo entre el final del gráfico (g3MaxX) y el final real del log (currentX2).
            // Si currentX2 es más allá de g3MaxX, se interpola.
            FlSpot s2_g3 = FlSpot(min(g3MaxX, currentX2), currentY2);
            if (currentX2 > g3MaxX) s2_g3 = FlSpot(g3MaxX, _interpolateY(xInitial, yInitial, xFinal, yFinal, g3MaxX));

            if ((s2_g3.x - s1_g3.x).abs() > 1e-3) { // Asegura que haya una longitud mínima para dibujar un segmento.
              _chartBarsGraph3.add(createSegment([s1_g3,s2_g3])); _sourceLogsG3.add(mealLog);
            } else if (s1_g3.x <= g3MaxX) { // Si es prácticamente un punto, dibuja solo el punto.
              _chartBarsGraph3.add(createSinglePoint(s1_g3)); _sourceLogsG3.add(mealLog);
            }
          }
        } else { // Si el log solo tiene glucosa inicial (es un punto único).
          if (xInitial < g1MaxX) {
            _chartBarsGraph1.add(createSinglePoint(spotInitial)); _sourceLogsG1.add(mealLog);
          } else if (xInitial < g2MaxX) {
            _chartBarsGraph2.add(createSinglePoint(spotInitial)); _sourceLogsG2.add(mealLog);
          } else if (xInitial <= g3MaxX) { // Incluye el límite exacto de 24:00.
            _chartBarsGraph3.add(createSinglePoint(spotInitial)); _sourceLogsG3.add(mealLog);
          }
        }
      }
    }

    // Calcula los límites comunes del eje Y después de procesar todos los puntos.
    if (allYValues.isNotEmpty) {
      _commonMinY = allYValues.reduce(min).floorToDouble();
      _commonMaxY = allYValues.reduce(max).ceilToDouble();
      double yRange = _commonMaxY - _commonMinY;
      // Añade un padding al rango Y para que los puntos no queden en los bordes.
      double padding = (yRange == 0) ? 25 : (yRange * 0.20).clamp(15.0, 50.0);
      _commonMinY = max(0, _commonMinY - padding); // El mínimo no puede ser menor que 0.
      _commonMaxY = _commonMaxY + padding;
      // Asegura un rango visual mínimo y redondea a decenas.
      if (_commonMaxY - _commonMinY < 60) { double mid = (_commonMinY + _commonMaxY) / 2.0; _commonMinY = max(0, mid - 30); _commonMaxY = mid + 30; }
      if(_commonMinY < 40) _commonMinY = 40; // Límite inferior visual práctico.
      _commonMinY = (_commonMinY / 10).floorToDouble() * 10; // Redondea a la decena inferior.
      _commonMaxY = (_commonMaxY / 10).ceilToDouble() * 10;   // Redondea a la decena superior.
      if (_commonMinY < 0) _commonMinY = 0; // Re-asegura que no sea negativo.
      if (_commonMaxY <= _commonMinY) _commonMaxY = _commonMinY + 60; // Asegura un rango mínimo si los valores son muy cercanos.
    } else { // Valores por defecto si no hay datos.
      _commonMinY = 40; _commonMaxY = 250;
    }
    if (_commonMinY == _commonMaxY) { // Caso extremo: todos los puntos Y son iguales.
      _commonMinY = max(0, _commonMinY -30); _commonMaxY = _commonMaxY + 30;
    }

    _setLoading(false); // Finaliza el estado de carga.
  }
}