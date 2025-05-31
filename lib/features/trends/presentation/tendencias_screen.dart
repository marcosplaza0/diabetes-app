// Archivo: lib/features/trends/presentation/tendencias_screen.dart
// Descripción: Define la interfaz de usuario para la pantalla de Resumen de Tendencias.
// Esta pantalla muestra estadísticas clave sobre el control glucémico del usuario
// durante un período seleccionable (ej. 7, 30, 90 días), incluyendo glucosa promedio,
// HbA1c estimada, y Tiempo en Rango (TIR) visualizado con un gráfico de tarta.
// Interactúa con TrendsViewModel para la lógica de negocio y el estado.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:flutter/material.dart'; // Framework principal de Flutter para UI.
import 'package:fl_chart/fl_chart.dart'; // Para PieChartSectionData, usado en el gráfico de TIR.
import 'package:provider/provider.dart'; // Para acceder al TrendsViewModel.

// Importaciones de archivos del proyecto
import 'package:DiabetiApp/core/layout/main_layout.dart'; // Widget de diseño principal de la pantalla.
import 'package:DiabetiApp/features/trends/presentation/trends_view_model.dart'; // ViewModel para esta pantalla.
import 'package:DiabetiApp/core/widgets/summary_stat_card.dart'; // Widget para mostrar estadísticas en tarjetas.
import 'package:DiabetiApp/core/widgets/loading_or_empty_state_widget.dart'; // Widget para estados de carga, vacío o error.

/// TrendsScreen: Un StatelessWidget que construye la UI para la pantalla de Resumen de Tendencias.
///
/// La lógica de estado y las operaciones se delegan a `TrendsViewModel`.
/// La pantalla incluye un selector de rango de fechas, tarjetas de estadísticas y un gráfico de TIR.
class TrendsScreen extends StatelessWidget {
  const TrendsScreen({super.key});

  // Umbrales para hipoglucemia e hiperglucemia.
  // Aunque también están en el ViewModel, se replican aquí o se exponen desde el VM
  // si son necesarios puramente para la construcción de la UI (ej. texto de la leyenda).
  // Para este caso, se usan para la leyenda del gráfico de TIR.
  static const double hypoThreshold = 70;  // Límite inferior para "En Rango".
  static const double hyperThreshold = 180; // Límite superior para "En Rango".


  /// _buildDateRangeSelector: Widget helper para construir el selector de rango de fechas.
  ///
  /// Utiliza un `SegmentedButton` para permitir al usuario elegir entre diferentes
  /// períodos de tiempo (ej. 7, 30, 90 días) para el análisis de tendencias.
  ///
  /// @param context El BuildContext actual.
  /// @param viewModel La instancia de `TrendsViewModel`.
  /// @param theme El ThemeData actual para aplicar estilos.
  /// @return Un Padding widget que contiene el `SegmentedButton`.
  Widget _buildDateRangeSelector(BuildContext context, TrendsViewModel viewModel, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SegmentedButton<DateRangeOption>(
        segments: DateRangeOption.values.map((option) { // Itera sobre las opciones de rango de fecha. //
          return ButtonSegment<DateRangeOption>(
            value: option,
            label: Text(option.displayName, style: const TextStyle(fontSize: 11.5)), // Texto del botón. //
            // Icono para cada opción de rango.
            icon: Icon(
                option == DateRangeOption.last7Days ? Icons.view_week_outlined
                    : option == DateRangeOption.last30Days ? Icons.calendar_today_outlined
                    : Icons.event_note_outlined, size: 18),
          );
        }).toList(),
        selected: {viewModel.selectedRange}, // Rango actualmente seleccionado en el ViewModel. //
        onSelectionChanged: (Set<DateRangeOption> newSelection) { // Callback cuando cambia la selección. //
          // Actualiza el rango en el ViewModel si la selección no está vacía y no se está cargando.
          if (newSelection.isNotEmpty && !viewModel.isLoading) {
            viewModel.updateSelectedRange(newSelection.first);
          }
        },
        style: SegmentedButton.styleFrom( // Estilos para el SegmentedButton.
          selectedForegroundColor: theme.colorScheme.onPrimary,
          selectedBackgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        ),
      ),
    );
  }

  /// _buildSummarySection: Widget helper para construir la sección de estadísticas resumen.
  ///
  /// Muestra tarjetas (`SummaryStatCard`) con la glucosa promedio, HbA1c estimada,
  /// y el índice de corrección promedio, obtenidos del `TrendsViewModel`.
  /// También incluye la tarjeta de Tiempo en Rango (TIR).
  ///
  /// @param context El BuildContext actual.
  /// @param viewModel La instancia de `TrendsViewModel`.
  /// @param theme El ThemeData actual.
  /// @return Un Column widget con las tarjetas de resumen.
  Widget _buildSummarySection(BuildContext context, TrendsViewModel viewModel, ThemeData theme) {
    // No construir nada si no hay datos de resumen en el ViewModel.
    if (viewModel.summaryData == null) return const SizedBox.shrink();

    return Column(
      children: [
        // Tarjeta de Tiempo en Rango (TIR).
        _buildTIRCard(context, viewModel, theme),
        const SizedBox(height: 16),
        // Fila con glucosa promedio y HbA1c estimada.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: SummaryStatCard(
              title: "Glucosa Promedio",
              value: "${viewModel.summaryData!.averageGlucose?.toStringAsFixed(0) ?? '--'} mg/dL",
              icon: Icons.show_chart_rounded,
              cardBackgroundColor: theme.colorScheme.primaryContainer,
              onCardColor: theme.colorScheme.onPrimaryContainer,
            )),
            const SizedBox(width: 10),
            Expanded(child: SummaryStatCard(
              title: "HbA1c Estimada",
              value: "${viewModel.summaryData!.estimatedA1c?.toStringAsFixed(1) ?? '--'}%",
              icon: Icons.bloodtype_outlined,
              cardBackgroundColor: theme.colorScheme.secondaryContainer,
              onCardColor: theme.colorScheme.onSecondaryContainer,
            )),
          ],
        ),
        const SizedBox(height: 16),
        // Tarjeta para el Índice de Corrección Promedio (si está disponible).
        if (viewModel.summaryData!.averageDailyCorrectionIndex != null)
          SummaryStatCard(
            title: "Índice Corrección Prom.",
            value: viewModel.summaryData!.averageDailyCorrectionIndex!.toStringAsFixed(1),
            icon: Icons.settings_ethernet_rounded,
            cardBackgroundColor: theme.colorScheme.tertiaryContainer,
            onCardColor: theme.colorScheme.onTertiaryContainer,
            isWide: true, // Para que ocupe todo el ancho.
          ),
      ],
    );
  }

  /// _buildTIRCard: Widget helper para construir la tarjeta de Tiempo en Rango (TIR).
  ///
  /// Muestra un gráfico de tarta (`PieChart`) con los porcentajes de tiempo en hipoglucemia,
  /// en rango e hiperglucemia. También incluye una leyenda.
  ///
  /// @param context El BuildContext actual.
  /// @param viewModel La instancia de `TrendsViewModel`.
  /// @param theme El ThemeData actual.
  /// @return Un Card widget con el gráfico y la leyenda de TIR.
  Widget _buildTIRCard(BuildContext context, TrendsViewModel viewModel, ThemeData theme) {
    final summary = viewModel.summaryData;
    if (summary == null) return const SizedBox.shrink();

    // Obtiene los porcentajes de TIR del ViewModel.
    final tir = summary.tirPercentages;
    final hypo = tir["hypo"] ?? 0;
    final inRange = tir["inRange"] ?? 0;
    final hyper = tir["hyper"] ?? 0;

    // Define los colores para cada sección del gráfico de TIR.
    final Color tirHypoColor = theme.colorScheme.error;
    final Color tirInRangeColor = Colors.green.shade600;
    final Color tirHyperColor = Colors.orange.shade700;

    // Crea las secciones para el PieChart.
    List<PieChartSectionData> sections = [
      PieChartSectionData(value: hypo, color: tirHypoColor, title: "${hypo.toStringAsFixed(0)}%", radius: 24, titleStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.onError, shadows: [Shadow(color: Colors.black.withValues(alpha:0.4), blurRadius: 1)])),
      PieChartSectionData(value: inRange, color: tirInRangeColor, title: "${inRange.toStringAsFixed(0)}%", radius: 30, titleStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black.withValues(alpha:0.4), blurRadius: 1)])),
      PieChartSectionData(value: hyper, color: tirHyperColor, title: "${hyper.toStringAsFixed(0)}%", radius: 24, titleStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black.withValues(alpha:0.4), blurRadius: 1)])),
    ];
    // Comprueba si hay datos para el gráfico.
    bool noDataForPie = hypo == 0 && inRange == 0 && hyper == 0 && summary.glucoseReadingsCount == 0; //

    return Card(
      elevation: 1.5, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      color: theme.colorScheme.surfaceContainerHigh, clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text("Tiempo en Rango (TIR)", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            // Muestra mensaje si no hay datos, o el gráfico y leyenda si los hay.
            if (noDataForPie)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Text("No hay lecturas para calcular TIR.", style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              )
            else
              Row( // Organiza el gráfico y la leyenda en una fila.
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Gráfico de Tarta (PieChart).
                    SizedBox(height: 120, width: 120, child: PieChart(PieChartData(sections: sections, centerSpaceRadius: 30, sectionsSpace: 3, pieTouchData: PieTouchData(enabled: false)))), // `pieTouchData` deshabilita interacciones táctiles.
                    const SizedBox(width: 20),
                    // Leyenda del gráfico.
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _buildLegendItem(tirHypoColor, "Bajo (<${hypoThreshold.toInt()}): ${hypo.toStringAsFixed(1)}%", theme),
                      _buildLegendItem(tirInRangeColor, "En Rango (${hypoThreshold.toInt()}-${hyperThreshold.toInt()}): ${inRange.toStringAsFixed(1)}%", theme),
                      _buildLegendItem(tirHyperColor, "Alto (>${hyperThreshold.toInt()}): ${hyper.toStringAsFixed(1)}%", theme),
                    ])),
                  ]),
            // Muestra el número de lecturas en las que se basa el cálculo del TIR.
            if (!noDataForPie)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text("Basado en ${summary.glucoseReadingsCount} lecturas", style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha:0.8), fontStyle: FontStyle.italic), textAlign: TextAlign.center,), //
              ),
          ],
        ),
      ),
    );
  }

  /// _buildLegendItem: Widget helper para construir un item de la leyenda del gráfico de TIR.
  ///
  /// @param color El color del indicador de la leyenda.
  /// @param text El texto descriptivo del item.
  /// @param theme El ThemeData actual.
  /// @return Un Padding widget que contiene una Row con el indicador de color y el texto.
  Widget _buildLegendItem(Color color, String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3.0))), // Indicador de color.
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 13), overflow: TextOverflow.ellipsis, maxLines: 2,)), // Texto, con manejo de desbordamiento.
      ]),
    );
  }

  @override
  /// build: Construye la interfaz de usuario principal de la pantalla de Tendencias.
  ///
  /// Utiliza `RefreshIndicator` para permitir la recarga manual de datos.
  /// Emplea `LoadingOrEmptyStateWidget` para manejar los estados de carga, vacío o error.
  /// El contenido principal es un `ListView` que organiza las diferentes secciones de la pantalla.
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // `context.watch` se suscribe a los cambios del TrendsViewModel.
    final viewModel = context.watch<TrendsViewModel>();

    return MainLayout(
      title: "Resumen de Tendencias", // Título de la AppBar.
      body: RefreshIndicator( // Permite "tirar para refrescar".
        onRefresh: viewModel.loadData, // Llama al método `loadData` del ViewModel para recargar. //
        color: theme.colorScheme.primary, // Color del indicador de refresco.
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: LoadingOrEmptyStateWidget( //
          isLoading: viewModel.isLoading, // Estado de carga del ViewModel. //
          loadingText: "Calculando tendencias...",

          // Considera vacío si no está cargando Y (no hay datos de resumen O hay muy pocas lecturas).
          isEmpty: !viewModel.isLoading && (viewModel.summaryData == null || viewModel.summaryData!.glucoseReadingsCount < 5),
          emptyMessage: "No hay suficientes datos en el rango seleccionado para un resumen detallado.",
          emptyIcon: Icons.data_exploration_outlined, // Icono para el estado vacío.
          childIfData: ListView( // Contenido a mostrar si hay datos y no está cargando/vacío/error.
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildDateRangeSelector(context, viewModel, theme), // Selector de rango de fechas.
              const SizedBox(height: 20),
              _buildSummarySection(context, viewModel, theme), // Sección con estadísticas y TIR.
              const SizedBox(height: 24),
              // Nota informativa sobre la estimación de HbA1c.
              Text(
                "La HbA1c estimada es solo una aproximación y puede diferir de los resultados de laboratorio. Consulta siempre a tu médico.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha:0.75), fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}