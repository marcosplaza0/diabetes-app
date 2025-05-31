// Archivo: lib/features/food_injections/presentation/food_injections_view_model.dart
// Descripción: ViewModel para la pantalla de cálculo de dosis (FoodInjectionsScreen).
// Este archivo contiene la lógica de negocio y el estado para la funcionalidad de
// calcular la insulina necesaria, los carbohidratos correspondientes a una dosis de insulina,
// o predecir el cambio en la glucemia. Interactúa con DiabetesCalculatorService para
// obtener los promedios históricos y realizar los cálculos.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:flutter/material.dart' hide DayPeriod; // Se oculta DayPeriod de Material si existe conflicto con el DayPeriod propio.

// Importaciones de archivos del proyecto
import 'package:diabetes_2/core/services/diabetes_calculator_service.dart'; // Servicio para cálculos relacionados con la diabetes.
import 'package:diabetes_2/data/models/calculations/daily_calculation_data.dart' show DayPeriod, dayPeriodToString; // Enum DayPeriod y helper para convertirlo a String.

/// Enum CalculationMode: Define los diferentes modos de cálculo disponibles en la pantalla.
enum CalculationMode {
  insulinFromCarbs,   // Calcular la insulina necesaria a partir de los carbohidratos.
  carbsFromInsulin,   // Calcular los carbohidratos que se pueden consumir con una dosis de insulina.
  predictBGChange,    // Predecir el cambio en la glucemia basado en carbohidratos e insulina.
}

/// FoodInjectionsViewModel: Gestiona el estado y la lógica para FoodInjectionsScreen.
///
/// Expone:
/// - Controladores de texto para los campos de entrada (carbohidratos, insulina, glucemia actual).
/// - El modo de cálculo actual (`currentMode`).
/// - El texto del resultado del cálculo (`resultText`).
/// - Un indicador de estado de carga (`isLoading`).
/// - Métodos para actualizar el modo, cargar promedios históricos y realizar cálculos.
class FoodInjectionsViewModel extends ChangeNotifier {
  final DiabetesCalculatorService _calculatorService; // Servicio para realizar los cálculos y obtener promedios.

  // Controladores para los campos de texto de la UI.
  final TextEditingController carbsController = TextEditingController();
  final TextEditingController insulinController = TextEditingController();
  final TextEditingController currentBGController = TextEditingController();

  CalculationMode _currentMode = CalculationMode.insulinFromCarbs; // Modo de cálculo inicial.
  CalculationMode get currentMode => _currentMode;

  String? _resultText; // Texto para mostrar el resultado del cálculo o mensajes de error/informativos.
  String? get resultText => _resultText;

  bool _isLoading = false; // Indica si se está realizando una operación asíncrona (ej. cargando promedios).
  bool get isLoading => _isLoading;

  // Variables para almacenar los promedios históricos cacheados.
  // Estos se obtienen de DiabetesCalculatorService y se usan en los cálculos.
  double? _avgRatioInsCarbDiv10ForCurrentPeriod; // Promedio del ratio Insulina/(CH/10) para el período actual.
  double? _avgPeriodRatioFinalForCurrentPeriod;   // Promedio del Ratio Final para el período actual.
  double? _avgDailyCorrectionIndex;               // Promedio del Índice de Corrección Diario.

  /// Constructor: Requiere una instancia de DiabetesCalculatorService.
  /// Llama a `loadAverages()` para cargar los promedios iniciales al crear el ViewModel.
  FoodInjectionsViewModel({required DiabetesCalculatorService calculatorService})
      : _calculatorService = calculatorService {
    loadAverages();
  }

  /// _setLoading: Método privado para actualizar el estado de carga y notificar a los listeners.
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners(); // Notifica a la UI para que se reconstruya si es necesario.
  }

  /// updateCalculationMode: Actualiza el modo de cálculo seleccionado.
  ///
  /// Limpia el resultado anterior y los campos de texto.
  /// Vuelve a cargar los promedios, ya que el mensaje inicial o los datos necesarios pueden cambiar.
  /// Notifica a los listeners para actualizar la UI.
  void updateCalculationMode(CalculationMode newMode) {
    if (_currentMode == newMode) return; // No hacer nada si el modo no cambia.
    _currentMode = newMode;
    _resultText = null; // Limpiar el resultado anterior.
    // Limpiar los controladores de texto para la nueva selección.
    carbsController.clear();
    insulinController.clear();
    currentBGController.clear();
    loadAverages(); // Recargar promedios, ya que pueden ser diferentes o mostrar mensajes distintos.
    notifyListeners();
  }

  /// loadAverages: Carga los promedios históricos necesarios para los cálculos.
  ///
  /// Obtiene:
  /// - El ratio promedio Insulina/Carbohidratos (por 10g) para el período actual.
  /// - El promedio del Ratio Final para el período actual.
  /// - El promedio del Índice de Corrección Diario.
  /// Estos valores se obtienen a través de `_calculatorService`.
  /// Muestra mensajes informativos si faltan datos para los cálculos.
  Future<void> loadAverages() async {
    _setLoading(true);
    _resultText = null; // Limpiar el resultado mientras se cargan nuevos promedios.

    try {
      final now = DateTime.now();
      final currentPeriod = _calculatorService.getDayPeriod(now); // Determina el período del día actual.

      // Obtiene los diferentes promedios del servicio de cálculo.
      _avgRatioInsCarbDiv10ForCurrentPeriod = await _calculatorService
          .getAverageRatioInsulinaCarbohidratosDiv10ForPeriod(period: currentPeriod);

      _avgPeriodRatioFinalForCurrentPeriod = await _calculatorService
          .getAverageOfDailyPeriodAvgRatioFinal(period: currentPeriod);

      _avgDailyCorrectionIndex = await _calculatorService.getAverageDailyCorrectionIndex();

      debugPrint("ViewModel Promedios: ratioICDiv10: $_avgRatioInsCarbDiv10ForCurrentPeriod, ratioFinalPeriodo: $_avgPeriodRatioFinalForCurrentPeriod, correccionIndex: $_avgDailyCorrectionIndex");

      // Prepara un mensaje inicial si faltan datos cruciales para el modo actual.
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
      _setLoading(false); // Finaliza el estado de carga.
    }
  }

  /// calculate: Realiza el cálculo según el modo actual y los valores ingresados.
  ///
  /// Valida las entradas y utiliza los promedios cargados para generar un `_resultText`.
  /// Notifica a los listeners para que la UI muestre el resultado.
  void calculate() {
    _resultText = null; // Limpiar el resultado anterior.
    notifyListeners(); // Notificar para limpiar el resultado en la UI inmediatamente.

    // Parsea los valores de los controladores de texto.
    final double? carbs = carbsController.text.isNotEmpty ? double.tryParse(carbsController.text) : null;
    final double? insulin = insulinController.text.isNotEmpty ? double.tryParse(insulinController.text) : null;
    final double? currentBG = currentBGController.text.isNotEmpty ? double.tryParse(currentBGController.text) : null;

    DayPeriod currentPeriodEnum = _calculatorService.getDayPeriod(DateTime.now()); // Obtiene el período del día actual.
    String periodName = dayPeriodToString(currentPeriodEnum); // Nombre del período para mensajes.

    switch (_currentMode) {
      case CalculationMode.insulinFromCarbs:
        if (carbs == null || carbs <= 0) {
          _resultText = "Por favor, introduce una cantidad válida de carbohidratos.";
        } else if (_avgRatioInsCarbDiv10ForCurrentPeriod == null || _avgRatioInsCarbDiv10ForCurrentPeriod! <= 0) {
          _resultText = "No hay datos suficientes para el ratio Insulina/CH en el período '$periodName'.";
        } else {
          // Calcula la insulina sugerida. El ratio está por 10g de CH.
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
          // Calcula los carbohidratos sugeridos.
          final double suggestedCarbs = insulin / (_avgRatioInsCarbDiv10ForCurrentPeriod! / 10.0);
          _resultText = "Carbohidratos sugeridos: ${suggestedCarbs.toStringAsFixed(0)} gramos.";
        }
        break;

      case CalculationMode.predictBGChange:
        if (carbs == null || carbs <= 0 || insulin == null || insulin < 0) { // La insulina puede ser 0 si solo se comen CH sin corregir.
          _resultText = "Por favor, introduce carbohidratos e insulina válidos.";
        } else if (_avgPeriodRatioFinalForCurrentPeriod == null || _avgDailyCorrectionIndex == null || _avgDailyCorrectionIndex! <= 0) {
          _resultText = "No hay datos suficientes (promedio ratio final o índice corrección) para el período '$periodName'.";
        } else if (currentBGController.text.isNotEmpty && currentBG == null) {
          _resultText = "Glucemia actual no válida. Por favor, introduce un número o deja el campo vacío.";
        } else {
          // Calcula el ratio Insulina/CH para la comida actual.
          final double currentMealRatioICDiv10 = carbs > 0 ? (insulin / (carbs / 10.0)) : 0;
          // Predice el cambio en la glucemia. La fórmula es:
          // (RatioFinalEsperadoParaElPeriodo - RatioActualDeLaComida) * IndiceDeCorreccion
          // Un resultado positivo significa que la glucosa subirá (se inyectó menos insulina de la "ideal" para esos CH según el RatioFinal).
          // Un resultado negativo significa que la glucosa bajará (se inyectó más insulina).
          final double predictedBGChange = (_avgPeriodRatioFinalForCurrentPeriod! - currentMealRatioICDiv10) * _avgDailyCorrectionIndex!;

          if (currentBG != null) {
            // Si se proporciona glucemia actual, calcula la glucemia final predicha.
            final double finalBG = currentBG + predictedBGChange;
            _resultText = "Glucosa final predicha: ${finalBG.toStringAsFixed(0)} mg/dL.";
          } else {
            // Si no, solo muestra el cambio predicho.
            String changeDirection = predictedBGChange > 0 ? "subirá" : (predictedBGChange < 0 ? "bajará" : "se mantendrá estable");
            _resultText = "Se predice que tu glucosa $changeDirection aprox. ${predictedBGChange.abs().toStringAsFixed(0)} mg/dL.";
          }
        }
        break;
    }
    notifyListeners(); // Notificar para mostrar el resultado en la UI.
  }

  /// dispose: Limpia los controladores de texto cuando el ViewModel ya no se utiliza.
  /// Esto es importante para liberar recursos.
  @override
  void dispose() {
    carbsController.dispose();
    insulinController.dispose();
    currentBGController.dispose();
    super.dispose();
  }
}