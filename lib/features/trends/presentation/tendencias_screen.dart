// lib/features/trends/presentation/trends_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart'; // Para DateFormat, asegúrate que initializeDateFormatting se llama si usas formatos localizados extensivamente.
import 'package:collection/collection.dart';

import 'package:diabetes_2/core/layout/main_layout.dart';
import 'package:diabetes_2/data/models/logs/logs.dart';
import 'package:diabetes_2/data/models/calculations/daily_calculation_data.dart';
import 'package:diabetes_2/main.dart' show mealLogBoxName, dailyCalculationsBoxName;

enum DateRangeOption { last7Days, last30Days, last90Days }

extension DateRangeOptionExtension on DateRangeOption {
  String get displayName {
    switch (this) {
      case DateRangeOption.last7Days: return '7 Días'; // Más corto
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

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  bool _isLoading = true;
  DateRangeOption _selectedRange = DateRangeOption.last30Days;
  TrendsSummaryData? _summaryData;

  late Box<MealLog> _mealLogBox;
  late Box<DailyCalculationData> _dailyCalculationsBox;

  static const double hypoThreshold = 70;
  static const double hyperThreshold = 180;

  @override
  void initState() {
    super.initState();
    _mealLogBox = Hive.box<MealLog>(mealLogBoxName); //
    _dailyCalculationsBox = Hive.box<DailyCalculationData>(dailyCalculationsBoxName); //
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    final endDate = DateTime.now();
    final startDate = DateTime(endDate.year, endDate.month, endDate.day - (_selectedRange.days -1) , 0, 0, 0);

    List<MealLog> relevantMealLogs = _mealLogBox.values.where((log) {
      final logDate = log.startTime;
      return !logDate.isBefore(startDate) && logDate.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();

    List<DailyCalculationData> relevantDailyCalculations = _dailyCalculationsBox.values.where((calc) {
      return !calc.date.isBefore(startDate) && !calc.date.isAfter(endDate);
    }).toList();

    List<double> glucoseValues = [];
    for (var log in relevantMealLogs) {
      glucoseValues.add(log.initialBloodSugar);
      if (log.finalBloodSugar != null) {
        glucoseValues.add(log.finalBloodSugar!);
      }
    }

    double? avgGlucose = glucoseValues.isNotEmpty ? glucoseValues.average : null;
    double? eA1c = avgGlucose != null ? (avgGlucose + 46.7) / 28.7 : null;

    int hypoCount = 0; int inRangeCount = 0; int hyperCount = 0;
    if (glucoseValues.isNotEmpty) {
      for (var val in glucoseValues) {
        if (val < hypoThreshold) hypoCount++;
        else if (val > hyperThreshold) hyperCount++;
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
        averageDailyCorrectionIndex: avgCorrectionIndexOverall
    );

    if(mounted) setState(() { _isLoading = false; });
  }

  Widget _buildDateRangeSelector(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SegmentedButton<DateRangeOption>(
        segments: DateRangeOption.values.map((option) {
          return ButtonSegment<DateRangeOption>(
            value: option,
            label: Text(option.displayName, style: const TextStyle(fontSize: 11.5)), // Ajustado para M3
            icon: Icon(
                option == DateRangeOption.last7Days ? Icons.view_week_outlined // Iconos más M3
                    : option == DateRangeOption.last30Days ? Icons.calendar_today_outlined
                    : Icons.event_note_outlined, // Iconos más M3
                size: 18),
          );
        }).toList(),
        selected: {_selectedRange},
        onSelectionChanged: (Set<DateRangeOption> newSelection) {
          if (newSelection.isNotEmpty && !_isLoading) {
            setState(() { _selectedRange = newSelection.first; });
            _loadData();
          }
        },
        style: SegmentedButton.styleFrom(
          selectedForegroundColor: theme.colorScheme.onPrimary,
          selectedBackgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), // Ajustado
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)), // M3 Shape
        ),
      ),
    );
  }

  Widget _buildSummarySection(ThemeData theme) {
    if (_summaryData == null) return const SizedBox.shrink();

    return Column(
      children: [
        _buildTIRCard(theme),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start, // Alinea las tarjetas si tienen alturas diferentes
          children: [
            Expanded(child: _buildSummaryCard(
                title: "Glucosa Promedio",
                value: "${_summaryData!.averageGlucose?.toStringAsFixed(0) ?? '--'} mg/dL",
                icon: Icons.show_chart_rounded,
                cardBackgroundColor: theme.colorScheme.primaryContainer,
                onCardColor: theme.colorScheme.onPrimaryContainer,
                theme: theme)),
            const SizedBox(width: 10), // Espaciado M3
            Expanded(child: _buildSummaryCard(
                title: "HbA1c Estimada",
                value: "${_summaryData!.estimatedA1c?.toStringAsFixed(1) ?? '--'}%",
                icon: Icons.bloodtype_outlined, // Icono más M3
                cardBackgroundColor: theme.colorScheme.secondaryContainer,
                onCardColor: theme.colorScheme.onSecondaryContainer,
                theme: theme)),
          ],
        ),
        const SizedBox(height: 16), // Espaciado M3
        if (_summaryData!.averageDailyCorrectionIndex != null)
          _buildSummaryCard(
            title: "Índice Corrección Prom.",
            value: _summaryData!.averageDailyCorrectionIndex!.toStringAsFixed(1),
            icon: Icons.settings_ethernet_rounded, // Icono más M3
            cardBackgroundColor: theme.colorScheme.tertiaryContainer,
            onCardColor: theme.colorScheme.onTertiaryContainer,
            theme: theme,
            isWide: true,
          ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color cardBackgroundColor,
    required Color onCardColor,
    required ThemeData theme,
    bool isWide = false
  }) {
    return Card(
      elevation: 1.0, // Elevación sutil M3
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)), // Radios M3
      color: cardBackgroundColor, // Color de fondo sólido
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0), // Padding generoso
        child: Column(
          crossAxisAlignment: isWide ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: theme.textTheme.titleSmall?.copyWith(color: onCardColor.withOpacity(0.9), fontWeight: FontWeight.w500)), // titleSmall para encabezados de tarjeta
            const SizedBox(height: 10),
            Text(value, style: theme.textTheme.headlineMedium?.copyWith(color: onCardColor, fontWeight: FontWeight.bold)), // headlineMedium para valor destacado
          ],
        ),
      ),
    );
  }

  Widget _buildTIRCard(ThemeData theme) {
    final tir = _summaryData!.tirPercentages;
    final hypo = tir["hypo"] ?? 0;
    final inRange = tir["inRange"] ?? 0;
    final hyper = tir["hyper"] ?? 0;

    // Colores para TIR, asegurando buen contraste sobre surfaceContainerHigh
    final Color tirHypoColor = theme.colorScheme.error;
    final Color tirInRangeColor = Colors.green.shade600; // Un verde vibrante
    final Color tirHyperColor = Colors.orange.shade700; // Un naranja/ámbar vibrante

    List<PieChartSectionData> sections = [
      PieChartSectionData(value: hypo, color: tirHypoColor, title: "${hypo.toStringAsFixed(0)}%", radius: 24, titleStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.onError, shadows: [Shadow(color: Colors.black.withOpacity(0.4), blurRadius: 1)])),
      PieChartSectionData(value: inRange, color: tirInRangeColor, title: "${inRange.toStringAsFixed(0)}%", radius: 30, titleStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black.withOpacity(0.4), blurRadius: 1)])),
      PieChartSectionData(value: hyper, color: tirHyperColor, title: "${hyper.toStringAsFixed(0)}%", radius: 24, titleStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black.withOpacity(0.4), blurRadius: 1)])),
    ];

    bool noDataForPie = hypo == 0 && inRange == 0 && hyper == 0 && _summaryData!.glucoseReadingsCount == 0;

    return Card(
      elevation: 1.5, // M3 elevation
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      color: theme.colorScheme.surfaceContainerHigh, // Color de tarjeta base para TIR
      clipBehavior: Clip.antiAlias,
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 120, width: 120,
                    child: PieChart(PieChartData(
                        sections: sections, centerSpaceRadius: 30, sectionsSpace: 3,
                        pieTouchData: PieTouchData(enabled: false)
                    )),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLegendItem(tirHypoColor, "Bajo (<${hypoThreshold.toInt()}): ${hypo.toStringAsFixed(1)}%", theme),
                        _buildLegendItem(tirInRangeColor, "En Rango (${hypoThreshold.toInt()}-${hyperThreshold.toInt()}): ${inRange.toStringAsFixed(1)}%", theme),
                        _buildLegendItem(tirHyperColor, "Alto (>${hyperThreshold.toInt()}): ${hyper.toStringAsFixed(1)}%", theme),
                      ],
                    ),
                  )
                ],
              ),
            if (!noDataForPie)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text("Basado en ${_summaryData?.glucoseReadingsCount ?? 0} lecturas", style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8), fontStyle: FontStyle.italic), textAlign: TextAlign.center,),
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
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3.0))), // Cuadrado redondeado M3
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 13), overflow: TextOverflow.ellipsis, maxLines: 2,)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MainLayout(
      title: "Resumen de Tendencias",
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: theme.colorScheme.primary,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: ListView(
          padding: const EdgeInsets.all(16.0), // Buen padding general
          children: [
            _buildDateRangeSelector(theme),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 40.0), child:CircularProgressIndicator()))
            else if (_summaryData == null || _summaryData!.glucoseReadingsCount < 5) // Requerir al menos 5 lecturas
              Center(
                child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.data_exploration_outlined, size: 60, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)), // Icono más M3
                        const SizedBox(height: 16),
                        Text("No hay suficientes datos en el rango seleccionado para un resumen detallado.",
                          style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                ),
              )
            else ...[
                _buildSummarySection(theme),
                const SizedBox(height: 24),
                Text(
                  "La HbA1c estimada es solo una aproximación y puede diferir de los resultados de laboratorio. Consulta siempre a tu médico.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.75), fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 24),
              ]
          ],
        ),
      ),
    );
  }
}

extension DoubleListAverage on List<double> {
  double? get averageOrNull => isEmpty ? null : reduce((a, b) => a + b) / length;
}