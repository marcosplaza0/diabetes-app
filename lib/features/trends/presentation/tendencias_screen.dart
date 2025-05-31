// lib/features/trends/presentation/tendencias_screen.dart
// import 'dart:math'; // Ya no es necesario aquí directamente
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // Para PieChartSectionData
// import 'package:hive_flutter/hive_flutter.dart'; // No directamente
// import 'package:intl/intl.dart'; // No directamente
// import 'package:collection/collection.dart'; // No directamente
import 'package:provider/provider.dart';

import 'package:diabetes_2/core/layout/main_layout.dart';
// import 'package:diabetes_2/data/models/logs/logs.dart'; // No directamente
// import 'package:diabetes_2/data/models/calculations/daily_calculation_data.dart'; // No directamente
import 'package:diabetes_2/features/trends/presentation/trends_view_model.dart'; // Importar ViewModel

// DateRangeOption y TrendsSummaryData ahora están en trends_view_model.dart

class TrendsScreen extends StatelessWidget { // Convertido a StatelessWidget
  const TrendsScreen({super.key});

  // Los umbrales ahora están en el ViewModel, pero los necesitamos para el texto de la leyenda.
  // Podríamos pasarlos o definirlos aquí también si son solo para la UI.
  // Para mantener la UI simple, los duplicamos aquí o los exponemos desde el ViewModel si es preferible.
  static const double hypoThreshold = 70;
  static const double hyperThreshold = 180;


  Widget _buildDateRangeSelector(BuildContext context, TrendsViewModel viewModel, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SegmentedButton<DateRangeOption>(
        segments: DateRangeOption.values.map((option) {
          return ButtonSegment<DateRangeOption>(
            value: option,
            label: Text(option.displayName, style: const TextStyle(fontSize: 11.5)),
            icon: Icon(
                option == DateRangeOption.last7Days ? Icons.view_week_outlined
                    : option == DateRangeOption.last30Days ? Icons.calendar_today_outlined
                    : Icons.event_note_outlined, size: 18),
          );
        }).toList(),
        selected: {viewModel.selectedRange}, // Usar del ViewModel
        onSelectionChanged: (Set<DateRangeOption> newSelection) {
          if (newSelection.isNotEmpty && !viewModel.isLoading) {
            viewModel.updateSelectedRange(newSelection.first); // Llamar al ViewModel
          }
        },
        style: SegmentedButton.styleFrom(
          selectedForegroundColor: theme.colorScheme.onPrimary, selectedBackgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onSurfaceVariant, backgroundColor: theme.colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        ),
      ),
    );
  }

  Widget _buildSummarySection(BuildContext context, TrendsViewModel viewModel, ThemeData theme) {
    if (viewModel.summaryData == null) return const SizedBox.shrink();

    return Column(
      children: [
        _buildTIRCard(context, viewModel, theme), // Pasar viewModel
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildSummaryCard(
                title: "Glucosa Promedio",
                value: "${viewModel.summaryData!.averageGlucose?.toStringAsFixed(0) ?? '--'} mg/dL",
                icon: Icons.show_chart_rounded,
                cardBackgroundColor: theme.colorScheme.primaryContainer,
                onCardColor: theme.colorScheme.onPrimaryContainer,
                theme: theme)),
            const SizedBox(width: 10),
            Expanded(child: _buildSummaryCard(
                title: "HbA1c Estimada",
                value: "${viewModel.summaryData!.estimatedA1c?.toStringAsFixed(1) ?? '--'}%",
                icon: Icons.bloodtype_outlined,
                cardBackgroundColor: theme.colorScheme.secondaryContainer,
                onCardColor: theme.colorScheme.onSecondaryContainer,
                theme: theme)),
          ],
        ),
        const SizedBox(height: 16),
        if (viewModel.summaryData!.averageDailyCorrectionIndex != null)
          _buildSummaryCard(
            title: "Índice Corrección Prom.",
            value: viewModel.summaryData!.averageDailyCorrectionIndex!.toStringAsFixed(1),
            icon: Icons.settings_ethernet_rounded,
            cardBackgroundColor: theme.colorScheme.tertiaryContainer,
            onCardColor: theme.colorScheme.onTertiaryContainer,
            theme: theme,
            isWide: true,
          ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title, required String value, required IconData icon,
    required Color cardBackgroundColor, required Color onCardColor,
    required ThemeData theme, bool isWide = false
  }) {
    return Card(
      elevation: 1.0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      color: cardBackgroundColor, clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: isWide ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: theme.textTheme.titleSmall?.copyWith(color: onCardColor.withOpacity(0.9), fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            Text(value, style: theme.textTheme.headlineMedium?.copyWith(color: onCardColor, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildTIRCard(BuildContext context, TrendsViewModel viewModel, ThemeData theme) {
    final summary = viewModel.summaryData;
    if (summary == null) return const SizedBox.shrink();

    final tir = summary.tirPercentages;
    final hypo = tir["hypo"] ?? 0;
    final inRange = tir["inRange"] ?? 0;
    final hyper = tir["hyper"] ?? 0;

    final Color tirHypoColor = theme.colorScheme.error;
    final Color tirInRangeColor = Colors.green.shade600;
    final Color tirHyperColor = Colors.orange.shade700;

    List<PieChartSectionData> sections = [
      PieChartSectionData(value: hypo, color: tirHypoColor, title: "${hypo.toStringAsFixed(0)}%", radius: 24, titleStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.onError, shadows: [Shadow(color: Colors.black.withOpacity(0.4), blurRadius: 1)])),
      PieChartSectionData(value: inRange, color: tirInRangeColor, title: "${inRange.toStringAsFixed(0)}%", radius: 30, titleStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black.withOpacity(0.4), blurRadius: 1)])),
      PieChartSectionData(value: hyper, color: tirHyperColor, title: "${hyper.toStringAsFixed(0)}%", radius: 24, titleStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black.withOpacity(0.4), blurRadius: 1)])),
    ];
    bool noDataForPie = hypo == 0 && inRange == 0 && hyper == 0 && summary.glucoseReadingsCount == 0;

    return Card(
      elevation: 1.5, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      color: theme.colorScheme.surfaceContainerHigh, clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text("Tiempo en Rango (TIR)", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            if (noDataForPie)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Text("No hay lecturas para calcular TIR.", style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              )
            else
              Row( crossAxisAlignment: CrossAxisAlignment.center, children: [
                SizedBox(height: 120, width: 120, child: PieChart(PieChartData(sections: sections, centerSpaceRadius: 30, sectionsSpace: 3, pieTouchData: PieTouchData(enabled: false)))),
                const SizedBox(width: 20),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildLegendItem(tirHypoColor, "Bajo (<${hypoThreshold.toInt()}): ${hypo.toStringAsFixed(1)}%", theme),
                  _buildLegendItem(tirInRangeColor, "En Rango (${hypoThreshold.toInt()}-${hyperThreshold.toInt()}): ${inRange.toStringAsFixed(1)}%", theme),
                  _buildLegendItem(tirHyperColor, "Alto (>${hyperThreshold.toInt()}): ${hyper.toStringAsFixed(1)}%", theme),
                ])),
              ]),
            if (!noDataForPie)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text("Basado en ${summary.glucoseReadingsCount} lecturas", style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8), fontStyle: FontStyle.italic), textAlign: TextAlign.center,),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3.0))),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 13), overflow: TextOverflow.ellipsis, maxLines: 2,)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Usar context.watch para que la UI se reconstruya cuando cambien los datos del ViewModel
    final viewModel = context.watch<TrendsViewModel>();

    return MainLayout(
      title: "Resumen de Tendencias",
      body: RefreshIndicator(
        onRefresh: viewModel.loadData, // Llamar al ViewModel
        color: theme.colorScheme.primary,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildDateRangeSelector(context, viewModel, theme), // Pasar viewModel
            const SizedBox(height: 20),
            if (viewModel.isLoading)
              const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 40.0), child:CircularProgressIndicator()))
            else if (viewModel.summaryData == null || viewModel.summaryData!.glucoseReadingsCount < 5)
              Center(
                child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 16),
                    child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.data_exploration_outlined, size: 60, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text("No hay suficientes datos en el rango seleccionado para un resumen detallado.", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
                    ])
                ),
              )
            else ...[
                _buildSummarySection(context, viewModel, theme), // Pasar viewModel
                const SizedBox(height: 24),
                Text("La HbA1c estimada es solo una aproximación y puede diferir de los resultados de laboratorio. Consulta siempre a tu médico.", textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.75), fontStyle: FontStyle.italic)),
                const SizedBox(height: 24),
              ]
          ],
        ),
      ),
    );
  }
}
