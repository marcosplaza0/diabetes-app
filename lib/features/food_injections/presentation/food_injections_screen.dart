// Archivo: lib/features/food_injections/presentation/food_injections_screen.dart
// Descripción: Define la interfaz de usuario para la pantalla de cálculo de dosis de insulina y carbohidratos.
// Esta pantalla permite al usuario calcular la insulina necesaria basada en carbohidratos,
// los carbohidratos que puede consumir con una dosis de insulina, o predecir el cambio
// en la glucosa sanguínea. Interactúa con FoodInjectionsViewModel para la lógica de negocio y el estado.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:flutter/material.dart'; // Framework principal de Flutter para UI.
import 'package:flutter/services.dart'; // Para TextInputFormatter (formateadores de texto).
import 'package:provider/provider.dart'; // Para la gestión de estado y acceso al ViewModel.

// Importaciones de archivos del proyecto
import 'package:diabetes_2/core/layout/main_layout.dart'; // Widget de diseño principal de la pantalla.
import 'package:diabetes_2/features/food_injections/presentation/food_injections_view_model.dart'; // ViewModel para esta pantalla.

/// FoodInjectionsScreen: Un StatelessWidget que construye la UI para la calculadora de dosis.
///
/// La pantalla se divide en:
/// 1. Un selector de modo de cálculo (SegmentedButton).
/// 2. Campos de entrada dinámicos según el modo seleccionado.
/// 3. Un botón para ejecutar el cálculo.
/// 4. Un botón para recargar los promedios históricos usados en los cálculos.
/// 5. Un área para mostrar los resultados del cálculo.
///
/// Esta clase es StatelessWidget porque la gestión del estado y la lógica
/// se delegan a `FoodInjectionsViewModel`, al que se accede mediante `Provider`.
class FoodInjectionsScreen extends StatelessWidget {
  const FoodInjectionsScreen({super.key});

  /// _buildInputFields: Widget helper privado para construir los campos de entrada de texto.
  ///
  /// La visibilidad de los campos (carbohidratos, insulina, glucemia actual)
  /// depende del `currentMode` en el `FoodInjectionsViewModel`.
  ///
  /// @param context El BuildContext actual.
  /// @param viewModel La instancia de FoodInjectionsViewModel.
  /// @return Un Column widget con los campos de entrada apropiados.
  Widget _buildInputFields(BuildContext context, FoodInjectionsViewModel viewModel) {
    // Determina qué campos mostrar basado en el modo de cálculo actual del ViewModel.
    bool showCarbs = viewModel.currentMode == CalculationMode.insulinFromCarbs || viewModel.currentMode == CalculationMode.predictBGChange;
    bool showInsulin = viewModel.currentMode == CalculationMode.carbsFromInsulin || viewModel.currentMode == CalculationMode.predictBGChange;
    bool showCurrentBG = viewModel.currentMode == CalculationMode.predictBGChange;

    return Column(
      children: [
        // Campo para Carbohidratos
        if (showCarbs)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: TextField(
              controller: viewModel.carbsController, // Vincula con el controlador del ViewModel. //
              decoration: const InputDecoration(
                  labelText: 'Carbohidratos a consumir (g)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.bakery_dining_outlined)
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: false), // Teclado numérico sin decimales.
              inputFormatters: [FilteringTextInputFormatter.digitsOnly], // Permite solo dígitos.
            ),
          ),
        // Campo para Insulina
        if (showInsulin)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: TextField(
              controller: viewModel.insulinController, // Vincula con el controlador del ViewModel. //
              decoration: const InputDecoration(
                  labelText: 'Insulina a inyectar (U)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.colorize_outlined)
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true), // Teclado numérico con decimales.
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))], // Permite números y un punto decimal.
            ),
          ),
        // Campo para Glucemia Actual
        if (showCurrentBG)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: TextField(
              controller: viewModel.currentBGController, // Vincula con el controlador del ViewModel. //
              decoration: const InputDecoration(
                  labelText: 'Glucemia Actual (mg/dL) (Opcional)',
                  hintText: 'Dejar vacío para ver solo el cambio',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.bloodtype_outlined)
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: false), // Teclado numérico sin decimales.
              inputFormatters: [FilteringTextInputFormatter.digitsOnly], // Permite solo dígitos.
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Obtiene el tema actual para estilos.
    // Accede al FoodInjectionsViewModel usando Provider.
    // context.watch<T>() o Provider.of<T>(context) se suscribe a los cambios del ViewModel,
    // reconstruyendo este widget cuando el ViewModel notifica a sus listeners.
    final viewModel = Provider.of<FoodInjectionsViewModel>(context);

    return MainLayout(
      title: 'Calculadora de Dosis', // Título de la pantalla.
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView( // Permite el desplazamiento si el contenido excede la altura de la pantalla.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // Los hijos ocuparán todo el ancho disponible.
            children: [
              // Selector de Modo de Cálculo
              SegmentedButton<CalculationMode>(
                segments: const <ButtonSegment<CalculationMode>>[
                  ButtonSegment<CalculationMode>(
                      value: CalculationMode.insulinFromCarbs,
                      label: Text('Insulina?'),
                      tooltip: "Calcular insulina basada en carbohidratos",
                      icon: Icon(Icons.arrow_downward_rounded)
                  ),
                  ButtonSegment<CalculationMode>(
                      value: CalculationMode.carbsFromInsulin,
                      label: Text('CH?'),
                      tooltip: "Calcular carbohidratos basada en insulina",
                      icon: Icon(Icons.arrow_upward_rounded)
                  ),
                  ButtonSegment<CalculationMode>(
                      value: CalculationMode.predictBGChange,
                      label: Text('Predicción'),
                      tooltip: "Predecir cambio de glucosa",
                      icon: Icon(Icons.show_chart_rounded)
                  ),
                ],
                selected: {viewModel.currentMode}, // El modo seleccionado actualmente en el ViewModel. //
                onSelectionChanged: (Set<CalculationMode> newSelection) {
                  // Actualiza el modo en el ViewModel cuando el usuario selecciona una nueva opción.
                  viewModel.updateCalculationMode(newSelection.first);
                },
                style: SegmentedButton.styleFrom(
                    selectedForegroundColor: theme.colorScheme.onPrimary, // Color del texto e icono cuando está seleccionado.
                    selectedBackgroundColor: theme.colorScheme.primary // Color de fondo cuando está seleccionado.
                ),
              ),
              const SizedBox(height: 20),

              // Campos de Entrada (construidos por el método helper)
              _buildInputFields(context, viewModel),
              const SizedBox(height: 20),

              // Botón de Calcular
              ElevatedButton.icon(
                icon: viewModel.isLoading // Muestra un indicador de progreso si `isLoading` es true en el ViewModel. //
                    ? const SizedBox(width:18, height:18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.calculate_rounded),
                label: Text(viewModel.isLoading ? 'Cargando datos...' : 'Calcular'), // Texto del botón cambia según `isLoading`. //
                onPressed: viewModel.isLoading ? null : viewModel.calculate, // Deshabilita el botón si `isLoading` es true; sino, llama al método `calculate` del ViewModel. //
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                ),
              ),
              const SizedBox(height: 10),

              // Botón para Recargar Promedios
              TextButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Recargar Promedios Históricos'),
                onPressed: viewModel.isLoading ? null : viewModel.loadAverages, // Llama a `loadAverages` en el ViewModel. //
              ),
              const SizedBox(height: 24),

              // Visualización del Resultado
              // Muestra una tarjeta con el texto del resultado si `resultText` en el ViewModel no es nulo ni está vacío.
              if (viewModel.resultText != null && viewModel.resultText!.isNotEmpty)
                Card(
                  elevation: 2,
                  // Cambia el color de la tarjeta si el resultado es un error o indica falta de datos.
                  color: viewModel.resultText!.toLowerCase().contains("error") || viewModel.resultText!.toLowerCase().contains("no hay datos")
                      ? theme.colorScheme.errorContainer.withOpacity(0.7)
                      : theme.colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      viewModel.resultText!, // Muestra el texto del resultado del ViewModel. //
                      style: theme.textTheme.titleMedium?.copyWith(
                        // Estilo del texto también cambia según si es un error/advertencia.
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