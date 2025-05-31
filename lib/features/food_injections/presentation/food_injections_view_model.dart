// lib/features/food_injections/presentation/food_injections_view_model.dart
import 'package:flutter/material.dart' hide DayPeriod; // Esconder DayPeriod de Material si hay conflicto
import 'package:diabetes_2/core/services/diabetes_calculator_service.dart';
import 'package:diabetes_2/data/models/calculations/daily_calculation_data.dart' show DayPeriod, dayPeriodToString;

// El enum CalculationMode podría vivir aquí o en un archivo de modelo/utilidades de la feature
enum CalculationMode {
  insulinFromCarbs,
  carbsFromInsulin,
  predictBGChange,
}

class FoodInjectionsViewModel extends ChangeNotifier {
  final DiabetesCalculatorService _calculatorService;

  FoodInjectionsViewModel({required DiabetesCalculatorService calculatorService})
      : _calculatorService = calculatorService {
    // Cargar los promedios iniciales al crear el ViewModel
    loadAverages();
  }

  // Controllers para los TextFields
  final TextEditingController carbsController = TextEditingController();
  final TextEditingController insulinController = TextEditingController();
  final TextEditingController currentBGController = TextEditingController();

  CalculationMode _currentMode = CalculationMode.insulinFromCarbs;
  CalculationMode get currentMode => _currentMode;

  String? _resultText;
  String? get resultText => _resultText;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Promedios cacheados
  double? _avgRatioInsCarbDiv10ForCurrentPeriod;
  double? _avgPeriodRatioFinalForCurrentPeriod;
  double? _avgDailyCorrectionIndex;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void updateCalculationMode(CalculationMode newMode) {
    if (_currentMode == newMode) return;
    _currentMode = newMode;
    _resultText = null; // Limpiar resultado anterior
    carbsController.clear();
    insulinController.clear();
    currentBGController.clear();
    // Volver a cargar promedios podría ser necesario si el mensaje inicial depende del modo
    loadAverages();
    notifyListeners();
  }

  Future<void> loadAverages() async {
    _setLoading(true);
    _resultText = null; // Limpiar resultado mientras se cargan nuevos promedios

    try {
      final now = DateTime.now();
      final currentPeriod = _calculatorService.getDayPeriod(now);

      _avgRatioInsCarbDiv10ForCurrentPeriod = await _calculatorService
          .getAverageRatioInsulinaCarbohidratosDiv10ForPeriod(period: currentPeriod);

      _avgPeriodRatioFinalForCurrentPeriod = await _calculatorService
          .getAverageOfDailyPeriodAvgRatioFinal(period: currentPeriod);

      _avgDailyCorrectionIndex = await _calculatorService.getAverageDailyCorrectionIndex();

      debugPrint("ViewModel Promedios: ratioICDiv10: $_avgRatioInsCarbDiv10ForCurrentPeriod, ratioFinalPeriodo: $_avgPeriodRatioFinalForCurrentPeriod, correccionIndex: $_avgDailyCorrectionIndex");

      // Preparar mensaje inicial si faltan datos
      String initialMessage = "";
      if (_avgRatioInsCarbDiv10ForCurrentPeriod == null && currentMode != CalculationMode.predictBGChange) {
        initialMessage = "No hay suficientes datos de comidas anteriores para calcular el ratio insulina/carbohidratos para el período actual. ";
      }
      if ((_avgPeriodRatioFinalForCurrentPeriod == null || _avgDailyCorrectionIndex == null) && currentMode == CalculationMode.predictBGChange) {
        initialMessage += "No hay suficientes datos (promedio ratio final o índice corrección) para predecir el cambio de glucosa.";
      }
      if (initialMessage.isNotEmpty) {
        _resultText = initialMessage.trim();
      }

    } catch (e) {
      _resultText = "Error cargando promedios: ${e.toString()}";
      debugPrint("FoodInjectionsViewModel Error en loadAverages: $e");
    } finally {
      _setLoading(false);
    }
  }

  void calculate() {
    _resultText = null; // Limpiar resultado anterior
    notifyListeners(); // Para que la UI se actualice si había un resultado previo

    final double? carbs = carbsController.text.isNotEmpty ? double.tryParse(carbsController.text) : null;
    final double? insulin = insulinController.text.isNotEmpty ? double.tryParse(insulinController.text) : null;
    final double? currentBG = currentBGController.text.isNotEmpty ? double.tryParse(currentBGController.text) : null;

    DayPeriod currentPeriodEnum = _calculatorService.getDayPeriod(DateTime.now());
    String periodName = dayPeriodToString(currentPeriodEnum);

    switch (_currentMode) {
      case CalculationMode.insulinFromCarbs:
        if (carbs == null || carbs <= 0) {
          _resultText = "Por favor, introduce una cantidad válida de carbohidratos.";
        } else if (_avgRatioInsCarbDiv10ForCurrentPeriod == null || _avgRatioInsCarbDiv10ForCurrentPeriod! <= 0) {
          _resultText = "No hay datos suficientes para el ratio Insulina/CH en el período '$periodName'.";
        } else {
          final double suggestedInsulin = carbs * (_avgRatioInsCarbDiv10ForCurrentPeriod! / 10.0);
          _resultText = "Insulina sugerida: ${suggestedInsulin.toStringAsFixed(1)} unidades.";
        }
        break;

      case CalculationMode.carbsFromInsulin:
        if (insulin == null || insulin <= 0) {
          _resultText = "Por favor, introduce una cantidad válida de insulina.";
        } else if (_avgRatioInsCarbDiv10ForCurrentPeriod == null || _avgRatioInsCarbDiv10ForCurrentPeriod! <= 0) {
          _resultText = "No hay datos suficientes para el ratio Insulina/CH en el período '$periodName'.";
        } else {
          final double suggestedCarbs = insulin / (_avgRatioInsCarbDiv10ForCurrentPeriod! / 10.0);
          _resultText = "Carbohidratos sugeridos: ${suggestedCarbs.toStringAsFixed(0)} gramos.";
        }
        break;

      case CalculationMode.predictBGChange:
        if (carbs == null || carbs <= 0 || insulin == null || insulin < 0) {
          _resultText = "Por favor, introduce carbohidratos e insulina válidos.";
        } else if (_avgPeriodRatioFinalForCurrentPeriod == null || _avgDailyCorrectionIndex == null || _avgDailyCorrectionIndex! <= 0) {
          _resultText = "No hay datos suficientes (promedio ratio final o índice corrección) para el período '$periodName'.";
        } else if (currentBGController.text.isNotEmpty && currentBG == null) {
          _resultText = "Glucemia actual no válida. Por favor, introduce un número o deja el campo vacío.";
        } else {
          final double currentMealRatioICDiv10 = carbs > 0 ? (insulin / (carbs / 10.0)) : 0;
          final double predictedBGChange = (_avgPeriodRatioFinalForCurrentPeriod! - currentMealRatioICDiv10) * _avgDailyCorrectionIndex!;
          if (currentBG != null) {
            final double finalBG = currentBG + predictedBGChange;
            _resultText = "Glucosa final predicha: ${finalBG.toStringAsFixed(0)} mg/dL.";
          } else {
            String changeDirection = predictedBGChange > 0 ? "subirá" : (predictedBGChange < 0 ? "bajará" : "se mantendrá estable");
            _resultText = "Se predice que tu glucosa $changeDirection aprox. ${predictedBGChange.abs().toStringAsFixed(0)} mg/dL.";
          }
        }
        break;
    }
    notifyListeners(); // Notificar para mostrar el resultado
  }

  @override
  void dispose() {
    carbsController.dispose();
    insulinController.dispose();
    currentBGController.dispose();
    super.dispose();
  }
}