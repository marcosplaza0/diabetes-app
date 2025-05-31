// Archivo: lib/features/trends/presentation/trends_view_model.dart
// Descripción: ViewModel para la pantalla de Resumen de Tendencias (TrendsScreen).
// Este archivo contiene la lógica de negocio y el estado para calcular y mostrar
// estadísticas clave sobre el control glucémico del usuario, como la glucosa promedio,
// el Tiempo en Rango (TIR), la HbA1c estimada y el índice de corrección promedio.
// Obtiene datos de LogRepository y CalculationDataRepository.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:flutter/foundation.dart'; // Para ChangeNotifier y utilidades de Flutter.
import 'package:collection/collection.dart'; // Para extensiones de colecciones como .average y .averageOrNull.

// Importaciones de archivos del proyecto
import 'package:DiabetiApp/data/models/logs/logs.dart'; // Modelo MealLog.
import 'package:DiabetiApp/data/models/calculations/daily_calculation_data.dart'; // Modelo DailyCalculationData.
import 'package:DiabetiApp/data/repositories/log_repository.dart'; // Repositorio para acceder a los logs.
import 'package:DiabetiApp/data/repositories/calculation_data_repository.dart'; // Repositorio para acceder a los datos de cálculo.

// Definiciones relacionadas con las opciones de rango de fechas.
// Podrían moverse a un archivo de utilidades o modelos si se usan en más lugares.

/// Enum DateRangeOption: Define las opciones de rango de fechas disponibles para el análisis de tendencias.
enum DateRangeOption {
  last7Days,   // Últimos 7 días.
  last30Days,  // Últimos 30 días.
  last90Days,  // Últimos 90 días.
}

/// Extensión sobre DateRangeOption para añadir propiedades útiles.
extension DateRangeOptionExtension on DateRangeOption {
  /// displayName: Devuelve un texto descriptivo para cada opción de rango.
  String get displayName {
    switch (this) {
      case DateRangeOption.last7Days: return '7 Días';
      case DateRangeOption.last30Days: return '30 Días';
      case DateRangeOption.last90Days: return '90 Días';
    }
  }

  /// days: Devuelve el número de días correspondiente a cada opción de rango.
  int get days {
    switch (this) {
      case DateRangeOption.last7Days: return 7;
      case DateRangeOption.last30Days: return 30;
      case DateRangeOption.last90Days: return 90;
    }
  }
}

/// TrendsSummaryData: Clase contenedora para los datos de resumen de tendencias.
///
/// Agrupa las diferentes métricas calculadas para facilitar su paso y acceso.
class TrendsSummaryData {
  final double? averageGlucose; // Glucosa promedio en el período.
  final Map<String, double> tirPercentages; // Porcentajes de Tiempo en Rango (hipo, en rango, hiper).
  final double? estimatedA1c; // HbA1c estimada.
  final int glucoseReadingsCount; // Número total de lecturas de glucosa consideradas.
  final double? averageDailyCorrectionIndex; // Promedio del índice de corrección diario.

  TrendsSummaryData({
    this.averageGlucose,
    required this.tirPercentages,
    this.estimatedA1c,
    required this.glucoseReadingsCount,
    this.averageDailyCorrectionIndex,
  });
}

/// TrendsViewModel: Gestiona el estado y la lógica para la pantalla de Resumen de Tendencias.
///
/// Expone:
/// - El estado de carga (`isLoading`).
/// - El rango de fechas seleccionado (`selectedRange`).
/// - Los datos de resumen calculados (`summaryData`).
/// - Métodos para cambiar el rango de fechas y recargar los datos.
class TrendsViewModel extends ChangeNotifier {
  final LogRepository _logRepository; // Repositorio para acceder a los MealLogs.
  final CalculationDataRepository _calculationDataRepository; // Repositorio para DailyCalculationData.

  /// Constructor: Requiere instancias de los repositorios.
  /// Llama a `loadData()` para cargar los datos iniciales al crear el ViewModel.
  TrendsViewModel({
    required LogRepository logRepository,
    required CalculationDataRepository calculationDataRepository,
  })  : _logRepository = logRepository,
        _calculationDataRepository = calculationDataRepository {
    loadData(); // Carga los datos iniciales.
  }

  bool _isLoading = true; // Indica si se están cargando datos.
  bool get isLoading => _isLoading;

  DateRangeOption _selectedRange = DateRangeOption.last30Days; // Rango de fechas seleccionado por defecto.
  DateRangeOption get selectedRange => _selectedRange;

  TrendsSummaryData? _summaryData; // Almacena los datos de resumen calculados.
  TrendsSummaryData? get summaryData => _summaryData;

  // Constantes para los umbrales de glucosa utilizados en el cálculo del Tiempo en Rango (TIR).
  // Podrían ser configurables en el futuro.
  static const double _hypoThreshold = 70;  // Límite para considerar hipoglucemia.
  static const double _hyperThreshold = 180; // Límite para considerar hiperglucemia.

  /// _setLoading: Método privado para actualizar el estado de carga y notificar a los listeners.
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners(); // Notifica a la UI para que se reconstruya si es necesario.
  }

  /// updateSelectedRange: Actualiza el rango de fechas seleccionado y recarga los datos.
  ///
  /// @param newRange El nuevo DateRangeOption seleccionado por el usuario.
  void updateSelectedRange(DateRangeOption newRange) {
    if (_selectedRange == newRange) return; // No hacer nada si el rango no cambia.
    _selectedRange = newRange;
    notifyListeners(); // Notifica a la UI para actualizar el selector de rango inmediatamente.
    loadData(); // Carga los datos correspondientes al nuevo rango.
  }

  /// loadData: Carga y procesa los datos de logs y cálculos para generar el resumen de tendencias.
  ///
  /// Obtiene los `MealLog` y `DailyCalculationData` relevantes para el `_selectedRange`.
  /// Calcula:
  /// - Todas las lecturas de glucosa (iniciales y finales de MealLogs).
  /// - Glucosa promedio.
  /// - HbA1c estimada (basada en la glucosa promedio).
  /// - Porcentajes de Tiempo en Rango (TIR).
  /// - Promedio del índice de corrección diario.
  /// Actualiza `_summaryData` con los resultados.
  Future<void> loadData() async {
    _setLoading(true);
    _summaryData = null; // Limpiar datos anteriores mientras se carga.

    final endDate = DateTime.now(); // Fecha final del rango (hoy).
    // Calcula la fecha de inicio del rango, asegurando que sea inclusiva.
    final startDate = DateTime(endDate.year, endDate.month, endDate.day - (_selectedRange.days - 1), 0, 0, 0);
    // Para la consulta de logs, endDate debe cubrir todo el día final.
    final queryEndDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);


    try {
      // Obtiene los MealLogs relevantes del repositorio.
      List<MealLog> relevantMealLogs = await _logRepository.getMealLogsInDateRange(startDate, queryEndDate);

      // Obtiene los DailyCalculationData relevantes del repositorio.
      List<DailyCalculationData> relevantDailyCalculations =
      await _calculationDataRepository.getDailyCalculationsInDateRange(startDate, endDate);

      // Extrae todos los valores de glucosa de los MealLogs (iniciales y finales).
      List<double> glucoseValues = [];
      for (var log in relevantMealLogs) {
        glucoseValues.add(log.initialBloodSugar);
        if (log.finalBloodSugar != null) {
          glucoseValues.add(log.finalBloodSugar!);
        }
      }

      // Calcula la glucosa promedio.
      double? avgGlucose = glucoseValues.isNotEmpty ? glucoseValues.average : null; // `average` de `package:collection/collection.dart`.
      // Estima la HbA1c usando la fórmula estándar (ADAG).
      double? eA1c = avgGlucose != null ? (avgGlucose + 46.7) / 28.7 : null;

      // Calcula los porcentajes de Tiempo en Rango (TIR).
      int hypoCount = 0;
      int inRangeCount = 0;
      int hyperCount = 0;
      if (glucoseValues.isNotEmpty) {
        for (var val in glucoseValues) {
          if (val < _hypoThreshold) hypoCount++; // Tiempo por debajo del rango.
          else if (val > _hyperThreshold) hyperCount++; // Tiempo por encima del rango.
          else inRangeCount++; // Tiempo en rango.
        }
      }
      Map<String, double> tir = {
        "hypo": glucoseValues.isNotEmpty ? (hypoCount / glucoseValues.length) * 100 : 0,
        "inRange": glucoseValues.isNotEmpty ? (inRangeCount / glucoseValues.length) * 100 : 0,
        "hyper": glucoseValues.isNotEmpty ? (hyperCount / glucoseValues.length) * 100 : 0,
      };

      // Calcula el promedio del índice de corrección diario.
      // Se filtran valores nulos o no positivos.
      double? avgCorrectionIndexOverall = relevantDailyCalculations
          .where((d) => d.dailyCorrectionIndex != null && d.dailyCorrectionIndex! > 0)
          .map((d) => d.dailyCorrectionIndex!)
          .toList()
          .averageOrNull; // `averageOrNull` es una extensión personalizada o de `collection`.

      // Crea el objeto TrendsSummaryData con todos los resultados.
      _summaryData = TrendsSummaryData(
          averageGlucose: avgGlucose,
          tirPercentages: tir,
          estimatedA1c: eA1c,
          glucoseReadingsCount: glucoseValues.length,
          averageDailyCorrectionIndex: avgCorrectionIndexOverall);

      debugPrint("TrendsViewModel: Datos cargados. Glucosa Promedio: ${avgGlucose?.toStringAsFixed(1)}, Lecturas: ${glucoseValues.length}");

    } catch (e) {
      debugPrint("TrendsViewModel: Error cargando datos: $e");
      // En caso de error, se podría establecer un estado de error más explícito
      // o simplemente mostrar datos vacíos/nulos.
      _summaryData = TrendsSummaryData(
        tirPercentages: {"hypo": 0, "inRange": 0, "hyper": 0},
        glucoseReadingsCount: 0,
      );
    } finally {
      _setLoading(false); // Finaliza el estado de carga.
    }
  }
}

// Extensión para calcular el promedio de una lista de doubles.
// `averageOrNull` devuelve null si la lista está vacía, evitando división por cero.
extension DoubleListAverageExtension on List<double> {
  double? get averageOrNull => isEmpty ? null : reduce((a, b) => a + b) / length;
}