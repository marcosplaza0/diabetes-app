// lib/features/food_injections/presentation/food_injections.dart
import 'package:diabetes_2/core/services/diabetes_calculator_service.dart';
import 'package:diabetes_2/data/models/calculations/daily_calculation_data.dart'; // Para DayPeriod y dayPeriodToString
import 'package:flutter/material.dart' hide DayPeriod;
import 'package:diabetes_2/core/layout/main_layout.dart';
import 'package:flutter/services.dart';

enum CalculationMode {
  insulinFromCarbs,
  carbsFromInsulin,
  predictBGChange,
}

class FoodInjectionsScreen extends StatefulWidget {
  const FoodInjectionsScreen({super.key});

  @override
  State<FoodInjectionsScreen> createState() => _FoodInjectionsScreenState();
}

class _FoodInjectionsScreenState extends State<FoodInjectionsScreen> {
  final DiabetesCalculatorService _calculatorService = DiabetesCalculatorService();

  CalculationMode _currentMode = CalculationMode.insulinFromCarbs;

  final _carbsController = TextEditingController();
  final _insulinController = TextEditingController();
  final _currentBGController = TextEditingController(); // NUEVO: Para glucemia actual

  String? _resultText;
  bool _isLoading = false;

  double? _avgRatioInsCarbDiv10ForCurrentPeriod;
  double? _avgPeriodRatioFinalForCurrentPeriod;
  double? _avgDailyCorrectionIndex;

  @override
  void initState() {
    super.initState();
    _loadAverages();
  }

  @override
  void dispose() {
    _carbsController.dispose();
    _insulinController.dispose();
    _currentBGController.dispose(); // NUEVO: Dispose del nuevo controller
    super.dispose();
  }

  Future<void> _loadAverages() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _resultText = null; });

    try {
      final now = DateTime.now();
      final currentPeriod = _calculatorService.getDayPeriod(now);

      _avgRatioInsCarbDiv10ForCurrentPeriod = await _calculatorService
          .getAverageRatioInsulinaCarbohidratosDiv10ForPeriod(period: currentPeriod);

      _avgPeriodRatioFinalForCurrentPeriod = await _calculatorService
          .getAverageOfDailyPeriodAvgRatioFinal(period: currentPeriod);

      _avgDailyCorrectionIndex = await _calculatorService.getAverageDailyCorrectionIndex();

      debugPrint("Promedios cargados: ratioICDiv10: $_avgRatioInsCarbDiv10ForCurrentPeriod, ratioFinalPeriodo: $_avgPeriodRatioFinalForCurrentPeriod, correccionIndex: $_avgDailyCorrectionIndex");

      if (!mounted) return;
      String initialMessage = "";
      if (_avgRatioInsCarbDiv10ForCurrentPeriod == null && _currentMode != CalculationMode.predictBGChange) {
        initialMessage = "No hay suficientes datos de comidas anteriores para calcular el ratio insulina/carbohidratos para el período actual. ";
      }
      if ((_avgPeriodRatioFinalForCurrentPeriod == null || _avgDailyCorrectionIndex == null) && _currentMode == CalculationMode.predictBGChange) {
        initialMessage += "No hay suficientes datos (promedio ratio final o índice corrección) para predecir el cambio de glucosa.";
      }
      if (initialMessage.isNotEmpty) {
        setState(() {
          _resultText = initialMessage.trim();
        });
      }


    } catch (e) {
      if (mounted) {
        setState(() {
          _resultText = "Error cargando promedios: ${e.toString()}";
        });
      }
      debugPrint("Error en _loadAverages: $e");
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  void _calculate() {
    if (!mounted) return;
    setState(() { _resultText = null; });

    final double? carbs = _carbsController.text.isNotEmpty ? double.tryParse(_carbsController.text) : null;
    final double? insulin = _insulinController.text.isNotEmpty ? double.tryParse(_insulinController.text) : null;
    // NUEVO: Parsear glucemia actual
    final double? currentBG = _currentBGController.text.isNotEmpty ? double.tryParse(_currentBGController.text) : null;


    DayPeriod currentPeriod = _calculatorService.getDayPeriod(DateTime.now());
    String periodName = dayPeriodToString(currentPeriod);

    switch (_currentMode) {
      case CalculationMode.insulinFromCarbs:
        if (carbs == null || carbs <= 0) {
          setState(() { _resultText = "Por favor, introduce una cantidad válida de carbohidratos."; });
          return;
        }
        if (_avgRatioInsCarbDiv10ForCurrentPeriod == null || _avgRatioInsCarbDiv10ForCurrentPeriod! <= 0) {
          setState(() { _resultText = "No hay datos suficientes para el ratio Insulina/CH en el período '$periodName'."; });
          return;
        }
        final double suggestedInsulin = carbs * (_avgRatioInsCarbDiv10ForCurrentPeriod! / 10.0);
        setState(() { _resultText = "Insulina sugerida: ${suggestedInsulin.toStringAsFixed(1)} unidades."; });
        break;

      case CalculationMode.carbsFromInsulin:
        if (insulin == null || insulin <= 0) {
          setState(() { _resultText = "Por favor, introduce una cantidad válida de insulina."; });
          return;
        }
        if (_avgRatioInsCarbDiv10ForCurrentPeriod == null || _avgRatioInsCarbDiv10ForCurrentPeriod! <= 0) {
          setState(() { _resultText = "No hay datos suficientes para el ratio Insulina/CH en el período '$periodName'."; });
          return;
        }
        final double suggestedCarbs = insulin / (_avgRatioInsCarbDiv10ForCurrentPeriod! / 10.0);
        setState(() { _resultText = "Carbohidratos sugeridos: ${suggestedCarbs.toStringAsFixed(0)} gramos."; });
        break;

      case CalculationMode.predictBGChange:
        if (carbs == null || carbs <= 0 || insulin == null || insulin < 0) { // Permitir insulina 0 para predicción
          setState(() { _resultText = "Por favor, introduce carbohidratos e insulina válidos."; });
          return;
        }
        if (_avgPeriodRatioFinalForCurrentPeriod == null || _avgDailyCorrectionIndex == null || _avgDailyCorrectionIndex! <= 0) {
          setState(() { _resultText = "No hay datos suficientes (promedio ratio final o índice corrección) para el período '$periodName'."; });
          return;
        }
        // NUEVO: Validar glucemia actual si se introdujo incorrectamente
        if (_currentBGController.text.isNotEmpty && currentBG == null) {
          setState(() { _resultText = "Glucemia actual no válida. Por favor, introduce un número o deja el campo vacío."; });
          return;
        }

        final double currentMealRatioICDiv10 = carbs > 0 ? (insulin / (carbs / 10.0)) : 0; // Evitar división por cero si carbs es 0

        final double predictedBGChange =
            (_avgPeriodRatioFinalForCurrentPeriod! - currentMealRatioICDiv10) * _avgDailyCorrectionIndex!;

        // NUEVO: Lógica para mostrar resultado final o cambio
        if (currentBG != null) {
          final double finalBG = currentBG + predictedBGChange;
          setState(() {
            _resultText = "Glucosa final predicha: ${finalBG.toStringAsFixed(0)} mg/dL.";
          });
        } else {
          String changeDirection = predictedBGChange > 0
              ? "subirá"
              : (predictedBGChange < 0 ? "bajará" : "se mantendrá estable");
          setState(() {
            _resultText = "Se predice que tu glucosa ${changeDirection} aprox. ${predictedBGChange.abs().toStringAsFixed(0)} mg/dL.";
          });
        }
        break;
    }
  }

  Widget _buildInputFields() {
    bool showCarbs = _currentMode == CalculationMode.insulinFromCarbs || _currentMode == CalculationMode.predictBGChange;
    bool showInsulin = _currentMode == CalculationMode.carbsFromInsulin || _currentMode == CalculationMode.predictBGChange;
    bool showCurrentBG = _currentMode == CalculationMode.predictBGChange; // NUEVO: Condición para mostrar campo BG

    return Column(
      children: [
        if (showCarbs)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: TextField(
              controller: _carbsController,
              decoration: const InputDecoration(
                labelText: 'Carbohidratos a consumir (g)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.bakery_dining_outlined),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ),
        if (showInsulin)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: TextField(
              controller: _insulinController,
              decoration: const InputDecoration(
                labelText: 'Insulina a inyectar (U)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.colorize_outlined),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            ),
          ),
        // NUEVO: Campo para Glucemia Actual
        if (showCurrentBG)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: TextField(
              controller: _currentBGController,
              decoration: const InputDecoration(
                labelText: 'Glucemia Actual (mg/dL) (Opcional)',
                hintText: 'Dejar vacío para ver solo el cambio',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.bloodtype_outlined),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MainLayout(
      title: 'Calculadora de Dosis', // Título más específico
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<CalculationMode>(
                segments: const <ButtonSegment<CalculationMode>>[
                  ButtonSegment<CalculationMode>(
                      value: CalculationMode.insulinFromCarbs,
                      label: Text('Insulina?'), // Más corto
                      tooltip: "Calcular insulina basada en carbohidratos",
                      icon: Icon(Icons.arrow_downward_rounded)),
                  ButtonSegment<CalculationMode>(
                      value: CalculationMode.carbsFromInsulin,
                      label: Text('CH?'), // Más corto
                      tooltip: "Calcular carbohidratos basada en insulina",
                      icon: Icon(Icons.arrow_upward_rounded)),
                  ButtonSegment<CalculationMode>(
                      value: CalculationMode.predictBGChange,
                      label: Text('Predicción'), // Más corto
                      tooltip: "Predecir cambio de glucosa",
                      icon: Icon(Icons.show_chart_rounded)),
                ],
                selected: {_currentMode},
                onSelectionChanged: (Set<CalculationMode> newSelection) {
                  setState(() {
                    _currentMode = newSelection.first;
                    _resultText = null;
                    // Limpiar todos los campos al cambiar de modo para evitar confusión
                    _carbsController.clear();
                    _insulinController.clear();
                    _currentBGController.clear();
                    _loadAverages(); // Recargar promedios ya que el mensaje inicial puede cambiar
                  });
                },
                style: SegmentedButton.styleFrom(
                  selectedForegroundColor: theme.colorScheme.onPrimary,
                  selectedBackgroundColor: theme.colorScheme.primary,
                  // foregroundColor: theme.colorScheme.primary, // Color para no seleccionados
                  // backgroundColor: theme.colorScheme.surfaceVariant, // Fondo para no seleccionados
                ),
              ),
              const SizedBox(height: 20),
              _buildInputFields(),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: _isLoading
                    ? const SizedBox(width:18, height:18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.calculate_rounded),
                label: Text(_isLoading ? 'Cargando datos...' : 'Calcular'),
                onPressed: _isLoading ? null : _calculate,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16), // Más padding
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold) // Texto más grande
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Recargar Promedios Históricos'),
                onPressed: _isLoading ? null : _loadAverages,
              ),
              const SizedBox(height: 24),
              if (_resultText != null && _resultText!.isNotEmpty)
                Card(
                  elevation: 2,
                  color: _resultText!.toLowerCase().contains("error") || _resultText!.toLowerCase().contains("no hay datos")
                      ? theme.colorScheme.errorContainer.withValues(alpha:0.7)
                      : theme.colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _resultText!,
                      style: theme.textTheme.titleMedium?.copyWith(
                          color: _resultText!.toLowerCase().contains("error") || _resultText!.toLowerCase().contains("no hay datos")
                              ? theme.colorScheme.onErrorContainer
                              : theme.colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}