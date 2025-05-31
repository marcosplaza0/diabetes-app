// lib/features/trends/presentation/trends_view_model.dart
import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart'; // Para .average y .averageOrNull
import 'package:diabetes_2/data/models/logs/logs.dart';
import 'package:diabetes_2/data/models/calculations/daily_calculation_data.dart';
import 'package:diabetes_2/data/repositories/log_repository.dart';
import 'package:diabetes_2/data/repositories/calculation_data_repository.dart';

// Mantenemos estas definiciones aquí por ahora, ya que son específicas de esta feature.
// Si se usan en más sitios, podrían ir a un archivo de utilidades/modelos compartidos.
enum DateRangeOption { last7Days, last30Days, last90Days }

extension DateRangeOptionExtension on DateRangeOption {
  String get displayName {
    switch (this) {
      case DateRangeOption.last7Days: return '7 Días';
      case DateRangeOption.last30Days: return '30 Días';
      case DateRangeOption.last90Days: return '90 Días';
    }
  }

  int get days {
    switch (this) {
      case DateRangeOption.last7Days: return 7;
      case DateRangeOption.last30Days: return 30;
      case DateRangeOption.last90Days: return 90;
    }
  }
}

class TrendsSummaryData {
  final double? averageGlucose;
  final Map<String, double> tirPercentages;
  final double? estimatedA1c;
  final int glucoseReadingsCount;
  final double? averageDailyCorrectionIndex;

  TrendsSummaryData({
    this.averageGlucose,
    required this.tirPercentages,
    this.estimatedA1c,
    required this.glucoseReadingsCount,
    this.averageDailyCorrectionIndex,
  });
}

class TrendsViewModel extends ChangeNotifier {
  final LogRepository _logRepository;
  final CalculationDataRepository _calculationDataRepository;

  TrendsViewModel({
    required LogRepository logRepository,
    required CalculationDataRepository calculationDataRepository,
  })  : _logRepository = logRepository,
        _calculationDataRepository = calculationDataRepository {
    loadData(); // Cargar datos iniciales al crear el ViewModel
  }

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  DateRangeOption _selectedRange = DateRangeOption.last30Days; // Valor por defecto
  DateRangeOption get selectedRange => _selectedRange;

  TrendsSummaryData? _summaryData;
  TrendsSummaryData? get summaryData => _summaryData;

  // Constantes para los umbrales, podrían ser configurables en el futuro
  static const double _hypoThreshold = 70;
  static const double _hyperThreshold = 180;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void updateSelectedRange(DateRangeOption newRange) {
    if (_selectedRange == newRange) return;
    _selectedRange = newRange;
    notifyListeners(); // Notificar para que la UI actualice el SegmentedButton inmediatamente
    loadData(); // Cargar nuevos datos para el nuevo rango
  }

  Future<void> loadData() async {
    _setLoading(true);
    _summaryData = null; // Limpiar datos anteriores mientras se carga

    final endDate = DateTime.now();
    // Ajuste para que el rango sea inclusivo del día de inicio
    final startDate = DateTime(endDate.year, endDate.month, endDate.day - (_selectedRange.days - 1), 0, 0, 0);
    // Para la query de logs, endDate debe cubrir todo el día final
    final queryEndDate = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);


    try {
      List<MealLog> relevantMealLogs = await _logRepository.getMealLogsInDateRange(startDate, queryEndDate);

      List<DailyCalculationData> relevantDailyCalculations =
      await _calculationDataRepository.getDailyCalculationsInDateRange(startDate, endDate);

      List<double> glucoseValues = [];
      for (var log in relevantMealLogs) {
        glucoseValues.add(log.initialBloodSugar);
        if (log.finalBloodSugar != null) {
          glucoseValues.add(log.finalBloodSugar!);
        }
      }

      double? avgGlucose = glucoseValues.isNotEmpty ? glucoseValues.average : null;
      double? eA1c = avgGlucose != null ? (avgGlucose + 46.7) / 28.7 : null;

      int hypoCount = 0;
      int inRangeCount = 0;
      int hyperCount = 0;
      if (glucoseValues.isNotEmpty) {
        for (var val in glucoseValues) {
          if (val < _hypoThreshold) hypoCount++;
          else if (val > _hyperThreshold) hyperCount++;
          else inRangeCount++;
        }
      }
      Map<String, double> tir = {
        "hypo": glucoseValues.isNotEmpty ? (hypoCount / glucoseValues.length) * 100 : 0,
        "inRange": glucoseValues.isNotEmpty ? (inRangeCount / glucoseValues.length) * 100 : 0,
        "hyper": glucoseValues.isNotEmpty ? (hyperCount / glucoseValues.length) * 100 : 0,
      };

      double? avgCorrectionIndexOverall = relevantDailyCalculations
          .where((d) => d.dailyCorrectionIndex != null && d.dailyCorrectionIndex! > 0)
          .map((d) => d.dailyCorrectionIndex!)
          .toList()
          .averageOrNull;

      _summaryData = TrendsSummaryData(
          averageGlucose: avgGlucose,
          tirPercentages: tir,
          estimatedA1c: eA1c,
          glucoseReadingsCount: glucoseValues.length,
          averageDailyCorrectionIndex: avgCorrectionIndexOverall);

      debugPrint("TrendsViewModel: Datos cargados. Glucosa Promedio: ${avgGlucose?.toStringAsFixed(1)}, Lecturas: ${glucoseValues.length}");

    } catch (e) {
      debugPrint("TrendsViewModel: Error cargando datos: $e");
      _summaryData = TrendsSummaryData( // Podrías tener un estado de error más explícito
        tirPercentages: {"hypo": 0, "inRange": 0, "hyper": 0},
        glucoseReadingsCount: 0,
      );
    } finally {
      _setLoading(false);
    }
  }
}

// Helper para calcular promedio, podría moverse a un archivo de utilidades si se usa en más sitios
extension DoubleListAverageExtension on List<double> {
  double? get averageOrNull => isEmpty ? null : reduce((a, b) => a + b) / length;
// 'average' ya existe en collection.dart, pero averageOrNull es más seguro.
// Si no importas 'package:collection/collection.dart', puedes usar esta implementación de 'average'
// double get average => isEmpty ? 0 : reduce((a, b) => a + b) / length;
}