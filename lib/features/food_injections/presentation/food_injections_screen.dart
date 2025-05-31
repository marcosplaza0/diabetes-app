// lib/features/food_injections/presentation/food_injections_screen.dart
import 'package:diabetes_2/features/food_injections/presentation/food_injections_view_model.dart'; // Importar ViewModel
import 'package:flutter/material.dart'; // Ya no se esconde DayPeriod aquí
import 'package:diabetes_2/core/layout/main_layout.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart'; // Para Provider

// CalculationMode ahora está en el ViewModel, no es necesario aquí si no se referencia directamente.

class FoodInjectionsScreen extends StatelessWidget { // Convertido a StatelessWidget
  const FoodInjectionsScreen({super.key});

  // El método _buildInputFields ahora puede ser parte del build o un widget privado
  Widget _buildInputFields(BuildContext context, FoodInjectionsViewModel viewModel) {
    bool showCarbs = viewModel.currentMode == CalculationMode.insulinFromCarbs || viewModel.currentMode == CalculationMode.predictBGChange;
    bool showInsulin = viewModel.currentMode == CalculationMode.carbsFromInsulin || viewModel.currentMode == CalculationMode.predictBGChange;
    bool showCurrentBG = viewModel.currentMode == CalculationMode.predictBGChange;

    return Column(
      children: [
        if (showCarbs)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: TextField(
              controller: viewModel.carbsController, // Usar controller del ViewModel
              decoration: const InputDecoration(labelText: 'Carbohidratos a consumir (g)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.bakery_dining_outlined)),
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ),
        if (showInsulin)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: TextField(
              controller: viewModel.insulinController, // Usar controller del ViewModel
              decoration: const InputDecoration(labelText: 'Insulina a inyectar (U)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.colorize_outlined)),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            ),
          ),
        if (showCurrentBG)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: TextField(
              controller: viewModel.currentBGController, // Usar controller del ViewModel
              decoration: const InputDecoration(labelText: 'Glucemia Actual (mg/dL) (Opcional)', hintText: 'Dejar vacío para ver solo el cambio', border: OutlineInputBorder(), prefixIcon: Icon(Icons.bloodtype_outlined)),
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
    // Escuchar/Obtener el ViewModel
    final viewModel = Provider.of<FoodInjectionsViewModel>(context);
    // Alternativamente, para solo llamar métodos y no reconstruir en cada cambio de dato menor:
    // final viewModelReader = context.read<FoodInjectionsViewModel>();
    // Y para valores que deben reconstruir la UI:
    // final isLoading = context.select((FoodInjectionsViewModel vm) => vm.isLoading);
    // final resultText = context.select((FoodInjectionsViewModel vm) => vm.resultText);
    // Por simplicidad inicial, Provider.of o context.watch son comunes.

    return MainLayout(
      title: 'Calculadora de Dosis',
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<CalculationMode>(
                segments: const <ButtonSegment<CalculationMode>>[
                  ButtonSegment<CalculationMode>(value: CalculationMode.insulinFromCarbs, label: Text('Insulina?'), tooltip: "Calcular insulina basada en carbohidratos", icon: Icon(Icons.arrow_downward_rounded)),
                  ButtonSegment<CalculationMode>(value: CalculationMode.carbsFromInsulin, label: Text('CH?'), tooltip: "Calcular carbohidratos basada en insulina", icon: Icon(Icons.arrow_upward_rounded)),
                  ButtonSegment<CalculationMode>(value: CalculationMode.predictBGChange, label: Text('Predicción'), tooltip: "Predecir cambio de glucosa", icon: Icon(Icons.show_chart_rounded)),
                ],
                selected: {viewModel.currentMode}, // Usar valor del ViewModel
                onSelectionChanged: (Set<CalculationMode> newSelection) {
                  viewModel.updateCalculationMode(newSelection.first); // Llamar método del ViewModel
                },
                style: SegmentedButton.styleFrom(selectedForegroundColor: theme.colorScheme.onPrimary, selectedBackgroundColor: theme.colorScheme.primary),
              ),
              const SizedBox(height: 20),
              _buildInputFields(context, viewModel), // Pasar el viewModel
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: viewModel.isLoading // Usar valor del ViewModel
                    ? const SizedBox(width:18, height:18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.calculate_rounded),
                label: Text(viewModel.isLoading ? 'Cargando datos...' : 'Calcular'), // Usar valor del ViewModel
                onPressed: viewModel.isLoading ? null : viewModel.calculate, // Llamar método del ViewModel
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Recargar Promedios Históricos'),
                onPressed: viewModel.isLoading ? null : viewModel.loadAverages, // Llamar método del ViewModel
              ),
              const SizedBox(height: 24),
              if (viewModel.resultText != null && viewModel.resultText!.isNotEmpty) // Usar valor del ViewModel
                Card(
                  elevation: 2,
                  color: viewModel.resultText!.toLowerCase().contains("error") || viewModel.resultText!.toLowerCase().contains("no hay datos")
                      ? theme.colorScheme.errorContainer.withOpacity(0.7)
                      : theme.colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      viewModel.resultText!, // Usar valor del ViewModel
                      style: theme.textTheme.titleMedium?.copyWith(
                          color: viewModel.resultText!.toLowerCase().contains("error") || viewModel.resultText!.toLowerCase().contains("no hay datos")
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