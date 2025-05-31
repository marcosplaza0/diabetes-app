// Archivo: lib/features/trends_graphs/presentation/tendencias_graph_screen.dart
// Descripción: Define la interfaz de usuario para la pantalla de Gráficos de Tendencias de Glucemia.
// Esta pantalla muestra cuatro gráficos de líneas, cada uno representando un tramo de 6 horas
// del día (00-06h, 06-12h, 12-18h, 18-24h). Permite al usuario seleccionar el número de días
// de datos históricos a superponer. Cada gráfico tiene su propia escala en el eje Y.
// Interactúa con TendenciasGraphViewModel para obtener los datos y la lógica de los gráficos.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:flutter/material.dart' hide DayPeriod; // Framework principal de Flutter. Se oculta DayPeriod de Material.
import 'package:fl_chart/fl_chart.dart'; // Biblioteca para la creación de gráficos.
import 'package:intl/date_symbol_data_local.dart'; // Para inicializar el formato de fecha localizado.
import 'package:intl/intl.dart'; // Para formateo de fechas y horas (ej. en tooltips).
import 'package:provider/provider.dart'; // Para acceder al TendenciasGraphViewModel.

// Importaciones de archivos del proyecto
import 'package:diabetes_2/core/layout/main_layout.dart'; // Widget de diseño principal de la pantalla.
import 'package:diabetes_2/data/models/logs/logs.dart'; // Modelo MealLog, usado para la información en tooltips.
import 'package:diabetes_2/data/models/calculations/daily_calculation_data.dart' show DayPeriod; // Enum DayPeriod.
import 'package:diabetes_2/features/trends_graphs/presentation/tendencias_graph_view_model.dart'; // ViewModel para esta pantalla.
import 'package:diabetes_2/core/widgets/loading_or_empty_state_widget.dart'; // Widget para estados de carga, vacío o error.


/// TendenciasGraphScreen: Un StatefulWidget que construye la UI para los gráficos de tendencias de glucemia.
class TendenciasGraphScreen extends StatefulWidget {
  const TendenciasGraphScreen({super.key});

  @override
  State<TendenciasGraphScreen> createState() => _TendenciasGraphScreenState();
}

class _TendenciasGraphScreenState extends State<TendenciasGraphScreen> {
  @override
  /// initState: Se llama una vez cuando el widget se inserta en el árbol de widgets.
  /// Inicializa el formato de fecha y pide al ViewModel que cargue los datos del gráfico.
  void initState() {
    super.initState();
    _initializeDateFormatting(); // Inicializa el formato de fecha para 'es_ES'.
    // Después del primer frame, se carga los datos del gráfico desde el ViewModel.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<TendenciasGraphViewModel>(context, listen: false)
            .loadChartData(themeDataForDots: Theme.of(context)); // Pasa el tema actual.
      }
    });
  }

  /// _initializeDateFormatting: Inicializa el formato de fecha para el locale 'es_ES'.
  Future<void> _initializeDateFormatting() async {
    try {
      await initializeDateFormatting('es_ES', null);
    } catch (e) {
      debugPrint("TendenciasGraphScreen: Error inicializando date formatting para es_ES (puede que ya esté inicializado): $e");
    }
  }

  /// _buildDaysSelector: Construye el DropdownButton para seleccionar el número de días.
  Widget _buildDaysSelector(BuildContext context, TendenciasGraphViewModel viewModel, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.7))
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: viewModel.numberOfDays, // Valor actual del ViewModel.
          icon: Icon(Icons.expand_more_rounded, color: theme.colorScheme.onSurfaceVariant),
          elevation: 3, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface),
          dropdownColor: theme.colorScheme.surfaceContainerHigh,
          onChanged: viewModel.isLoading ? null : (int? newValue) { // Deshabilitado si está cargando.
            if (newValue != null) {
              viewModel.updateNumberOfDays(newValue); // Actualiza en el ViewModel.
            }
          },
          items: <int>[5, 10, 15, 30, 60, 90].map<DropdownMenuItem<int>>((int value) {
            return DropdownMenuItem<int>(value: value, child: Text('$value día${value == 1 ? '' : 's'}'));
          }).toList(),
        ),
      ),
    );
  }

  /// _buildLegend: Construye la leyenda de colores para los períodos del día.
  Widget _buildLegend(BuildContext context, TendenciasGraphViewModel viewModel, ThemeData theme) {
    if (viewModel.periodColors.isEmpty) return const SizedBox.shrink(); // No mostrar si no hay colores.
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
      child: Wrap( // Wrap para que los ítems fluyan.
        spacing: 5.0, runSpacing: 2.0, alignment: WrapAlignment.center,
        children: viewModel.orderedPeriodsForLegend.map((period) { // Itera sobre los períodos.
          final color = viewModel.periodColors[period] ?? Colors.transparent;
          final periodName = period.toString().split('.').last;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), // Indicador de color.
              const SizedBox(width: 4),
              Text(periodName, style: theme.textTheme.labelSmall?.copyWith(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)), // Nombre del período.
            ]),
          );
        }).toList(),
      ),
    );
  }

  /// _buildChartSection: Construye una sección individual de gráfico (título y el gráfico).
  /// Ahora acepta `minY` y `maxY` para la escala Y específica de este gráfico.
  Widget _buildChartSection(
      BuildContext context,
      TendenciasGraphViewModel viewModel,
      String title, // Título de la sección del gráfico.
      List<LineChartBarData> chartBars, // Datos de las líneas para este gráfico.
      List<MealLog> sourceLogs, // Logs fuente para los tooltips.
      double minX, double maxX, // Límites X para este gráfico.
      double minY, double maxY, // Límites Y específicos para este gráfico.
      ThemeData theme
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 18.0, bottom: 6.0, left: 6.0),
          child: Text(title, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
        ),
        SizedBox(height: 280, child: Card( // Contenedor del gráfico.
          elevation: 2.0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          color: theme.colorScheme.surfaceContainer, clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 10, left: 8, right: 12),
            child: chartBars.isEmpty // Si no hay datos para este tramo.
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.hourglass_empty_rounded, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5), size: 32),
              const SizedBox(height: 8),
              Text('Sin datos en este tramo horario', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7))),
            ]))
                : LineChart( // Widget LineChart.
              // Pasa los límites minY y maxY específicos.
              _buildTimeSlicedChartData(context, viewModel, chartBars, sourceLogs, minX, maxX, minY, maxY, theme),
              duration: const Duration(milliseconds: 300), // Animación al cambiar datos.
            ),
          ),
        )),
      ],
    );
  }

  /// _buildTimeSlicedChartData: Configura y devuelve los datos para un LineChart.
  /// Ahora utiliza los `minY` y `maxY` específicos pasados como parámetros.
  LineChartData _buildTimeSlicedChartData(
      BuildContext context,
      TendenciasGraphViewModel viewModel,
      List<LineChartBarData> chartBars,
      List<MealLog> sourceLogs,
      double minX, double maxX, // Límites X.
      double minY, double maxY, // Límites Y específicos para este gráfico.
      ThemeData theme
      ) {
    // Cálculo de intervalos para los ejes Y y X.
    // El intervalo Y se basa en el rango (maxY - minY) específico de este gráfico.
    double yRange = maxY - minY;
    double intervalY = (yRange / 4).clamp(10.0, 50.0);
    if (yRange <= 20) intervalY = 5; else if (yRange <= 50) intervalY = 10;
    if(intervalY <= 0) intervalY = 20; // Asegura un intervalo Y positivo.

    double xRange = maxX - minX; // Para tramos de 6 horas, xRange será 360.
    double intervalX = (xRange <= 360) ? 60 : 120; // Marcas cada hora (60 min).

    return LineChartData(
      // Configuración de tooltips al tocar el gráfico.
      lineTouchData: LineTouchData(
        enabled: true, handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          tooltipRoundedRadius: 10, getTooltipColor: (touchedSpot) => theme.colorScheme.secondaryContainer.withOpacity(0.92),
          getTooltipItems: (List<LineBarSpot> touchedBarSpots) { // Construye el contenido del tooltip.
            return touchedBarSpots.map((barSpot) {
              MealLog? sourceLog; // Log original asociado al punto tocado.
              // Intenta obtener el log fuente. Esta lógica puede necesitar ajustes si el índice no es directo.
              if (barSpot.barIndex >= 0 && barSpot.barIndex < sourceLogs.length) {
                sourceLog = sourceLogs[barSpot.barIndex];
              } else { // Fallback si el índice no es directo.
                double minDistance = double.infinity;
                for (final log in sourceLogs) {
                  final logTimeX = log.startTime.hour * 60 + log.startTime.minute;
                  final distance = (logTimeX - barSpot.x).abs();
                  if (distance < minDistance && distance < 30) { // Umbral de proximidad.
                    minDistance = distance;
                    sourceLog = log;
                  }
                  if (log.endTime != null) {
                    final logEndTimeX = log.endTime!.hour*60 + log.endTime!.minute;
                    final endDistance = (logEndTimeX - barSpot.x).abs();
                    if (endDistance < minDistance && endDistance < 30) {
                      minDistance = endDistance;
                      sourceLog = log;
                    }
                  }
                }
              }
              if (sourceLog == null) return null; // No mostrar tooltip si no se encuentra el log.

              final DayPeriod period = viewModel.calculatorService.getDayPeriod(sourceLog.startTime);
              final String periodName = period.toString().split('.').last;
              final int minutesFromMidnight = barSpot.x.toInt(); // Valor X (minutos desde medianoche global).
              final int hour = (minutesFromMidnight ~/ 60) % 24;
              final int minute = minutesFromMidnight % 60;
              final String timeStr = DateFormat('HH:mm', 'es_ES').format(DateTime(2000,1,1,hour,minute));
              final String dateStr = DateFormat('E dd MMM', 'es_ES').format(sourceLog.startTime);
              return LineTooltipItem(
                '$dateStr ($periodName)\n',
                TextStyle(color: viewModel.periodColors[period]?.withAlpha(230) ?? theme.colorScheme.onSecondaryContainer, fontWeight: FontWeight.bold, fontSize: 11.5),
                children: [
                  TextSpan(text: '$timeStr: ', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 10.5, color: theme.colorScheme.onSecondaryContainer)),
                  TextSpan(text: '${barSpot.y.toStringAsFixed(0)} mg/dL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: theme.colorScheme.onSecondaryContainer)),
                ], textAlign: TextAlign.left,
              );
            }).nonNulls.toList();
          },
        ),
      ),
      // Configuración de la cuadrícula.
      gridData: FlGridData(show: true, drawVerticalLine: true, drawHorizontalLine: true,
        horizontalInterval: intervalY, verticalInterval: intervalX,
        getDrawingHorizontalLine: (_) => FlLine(color: theme.colorScheme.outlineVariant.withOpacity(0.3), strokeWidth: 0.8),
        getDrawingVerticalLine: (_) => FlLine(color: theme.colorScheme.outlineVariant.withOpacity(0.3), strokeWidth: 0.8),
      ),
      // Configuración de los títulos de los ejes.
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, interval: intervalY, getTitlesWidget: (v, m) => _axisTitleWidgets(v, m, theme, isXaxis: false))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: intervalX, getTitlesWidget: (v, m) => _axisTitleWidgets(v, m, theme, isXaxis: true, minChartX: minX))),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      // Borde del gráfico.
      borderData: FlBorderData(show: true, border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5), width: 1)),
      // Límites X e Y del gráfico. minY y maxY son ahora específicos de este gráfico.
      minX: minX, maxX: maxX, minY: minY, maxY: maxY,
      lineBarsData: chartBars, // Datos de las líneas.
    );
  }

  /// _axisTitleWidgets: Helper para formatear los textos de los títulos de los ejes.
  /// Se añade `minChartX` para ayudar a formatear las horas del eje X relativas al inicio del tramo del gráfico.
  Widget _axisTitleWidgets(double value, TitleMeta meta, ThemeData theme, {required bool isXaxis, double? minChartX}) {
    final style = theme.textTheme.labelSmall?.copyWith(fontSize: 9, color: theme.colorScheme.onSurfaceVariant);
    String text = "";
    if (isXaxis) { // Para el eje X (horas).
      int minutes = value.toInt();
      // Muestra la etiqueta si es un múltiplo del intervalo aplicado (relativo a minChartX) o si es el inicio/fin del eje.
      if (meta.appliedInterval > 0 && ((minutes - (minChartX ?? meta.min)) % meta.appliedInterval.round()).abs() < 1 || (minutes - meta.min).abs() < 1 || (minutes - meta.max).abs() <1 ) {
        final int hour = (minutes ~/ 60) % 24; // Convierte minutos desde medianoche global a hora.
        text = hour.toString().padLeft(2,'0'); // Muestra la hora formateada (ej. "06", "12").
      }
    } else { // Para el eje Y (glucosa).
      text = meta.formattedValue; // Usa el valor formateado por fl_chart.
    }
    return SideTitleWidget(axisSide: meta.axisSide, space: 5, child: Text(text, style: style));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewModel = context.watch<TendenciasGraphViewModel>();

    return MainLayout(
      title: 'Glucemia en 24 Horas',
      body: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          children: [
            Padding( // Selector de días y botón de refresco.
              padding: const EdgeInsets.only(bottom: 6.0, left: 4, right: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(children: [_buildDaysSelector(context, viewModel, theme), const SizedBox(width: 10), Text("Registros", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))]),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, color: theme.colorScheme.primary, size: 26),
                    onPressed: viewModel.isLoading ? null : () => viewModel.loadChartData(themeDataForDots: theme),
                    tooltip: 'Recargar datos',
                  )
                ],
              ),
            ),
            if (!viewModel.isLoading) _buildLegend(context, viewModel, theme), // Leyenda de períodos.

            Expanded( // Contenedor principal para los gráficos.
              child: LoadingOrEmptyStateWidget(
                isLoading: viewModel.isLoading,
                loadingText: "Cargando gráficos...",
                // Verifica si todos los conjuntos de datos de los 4 gráficos están vacíos.
                isEmpty: !viewModel.isLoading && viewModel.chartBarsGraph1.isEmpty && viewModel.chartBarsGraph2.isEmpty && viewModel.chartBarsGraph3.isEmpty && viewModel.chartBarsGraph4.isEmpty,
                emptyMessage: 'No hay registros de comidas en los últimos ${viewModel.numberOfDays} día${viewModel.numberOfDays == 1 ? '' : 's'}.',
                emptyIcon: Icons.bar_chart_rounded,
                childIfData: SingleChildScrollView( // Permite scroll si los 4 gráficos exceden la altura.
                  physics: const BouncingScrollPhysics(),
                  child: Column(children: [
                    // Construye cada una de las 4 secciones de gráfico, pasando los límites Y específicos.
                    _buildChartSection(context, viewModel, "Madrugada (00:00 - 06:00)", viewModel.chartBarsGraph1, viewModel.sourceLogsG1, TendenciasGraphViewModel.g1MinX, TendenciasGraphViewModel.g1MaxX, viewModel.g1MinY, viewModel.g1MaxY, theme),
                    _buildChartSection(context, viewModel, "Mañana (06:00 - 12:00)", viewModel.chartBarsGraph2, viewModel.sourceLogsG2, TendenciasGraphViewModel.g2MinX, TendenciasGraphViewModel.g2MaxX, viewModel.g2MinY, viewModel.g2MaxY, theme),
                    _buildChartSection(context, viewModel, "Tarde (12:00 - 18:00)", viewModel.chartBarsGraph3, viewModel.sourceLogsG3, TendenciasGraphViewModel.g3MinX, TendenciasGraphViewModel.g3MaxX, viewModel.g3MinY, viewModel.g3MaxY, theme),
                    _buildChartSection(context, viewModel, "Noche (18:00 - 24:00)", viewModel.chartBarsGraph4, viewModel.sourceLogsG4, TendenciasGraphViewModel.g4MinX, TendenciasGraphViewModel.g4MaxX, viewModel.g4MinY, viewModel.g4MaxY, theme),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}