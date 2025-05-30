// lib/features/home/widgets/current_insulin_needs_widget.dart
import 'package:diabetes_2/data/models/profile/user_profile_data.dart';
import 'package:diabetes_2/main.dart';
import 'package:flutter/material.dart' hide DayPeriod; // Ocultar DayPeriod de Material
import 'package:hive_flutter/hive_flutter.dart';
import 'package:diabetes_2/core/services/diabetes_calculator_service.dart';
import 'package:diabetes_2/data/models/calculations/daily_calculation_data.dart' show DayPeriod, dayPeriodToString; // Usar el DayPeriod de este archivo
import 'package:diabetes_2/data/models/logs/logs.dart';

class CurrentInsulinNeedsWidget extends StatefulWidget {
  const CurrentInsulinNeedsWidget({super.key});

  @override
  State<CurrentInsulinNeedsWidget> createState() => _CurrentInsulinNeedsWidgetState();
}

class _CurrentInsulinNeedsWidgetState extends State<CurrentInsulinNeedsWidget> {
  final DiabetesCalculatorService _calculatorService = DiabetesCalculatorService();
  bool _isLoading = true;
  String? _userName;
  double? _calculatedRatioPer10gCH; // U / 10g CH
  String _ratioSourceInfo = ""; // Para indicar si el ratio es del período actual o interpolado

  // Lista ordenada de períodos para la lógica de fallback
  final List<DayPeriod> _orderedPeriods = const [
    DayPeriod.P1, DayPeriod.P2, DayPeriod.P3, DayPeriod.P4,
    DayPeriod.P5, DayPeriod.P6, DayPeriod.P7
  ];

  @override
  void initState() {
    super.initState();
    _loadWidgetData();
    // Escuchar cambios en la caja de MealLogs para recargar si es necesario
    Hive.box<MealLog>(mealLogBoxName).listenable().addListener(_handleHiveChanges);
  }

  @override
  void dispose() {
    Hive.box<MealLog>(mealLogBoxName).listenable().removeListener(_handleHiveChanges);
    super.dispose();
  }

  void _handleHiveChanges() {
    // Recargar datos si cambian los MealLogs, ya que pueden afectar los promedios
    _loadWidgetData();
  }

  Future<void> _loadWidgetData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    // 1. Cargar nombre de usuario
    final userProfileBox = Hive.box<UserProfileData>(userProfileBoxName);
    // Asumimos una clave fija para el perfil del usuario actual, como en DrawerApp
    final UserProfileData? profile = userProfileBox.get('currentUserProfile');
    _userName = profile?.username ?? supabase.auth.currentUser?.email?.split('@').first ?? "Usuario";

    // 2. Calcular ratio
    final now = DateTime.now();
    final currentPeriod = _calculatorService.getDayPeriod(now);
    double? ratio;
    String sourceInfo = "(Período actual: ${dayPeriodToString(currentPeriod)})";

    ratio = await _calculatorService.getAverageRatioInsulinaCarbohidratosDiv10ForPeriod(period: currentPeriod);

    if (ratio == null) { // Lógica de Fallback
      debugPrint("CurrentInsulinNeeds: No hay datos para el período actual (${dayPeriodToString(currentPeriod)}). Buscando en adyacentes.");
      int currentIndex = _orderedPeriods.indexOf(currentPeriod);
      if (currentIndex == -1) { // No debería pasar si DayPeriod.Unknown no está en _orderedPeriods
        debugPrint("CurrentInsulinNeeds: Período actual desconocido. No se puede aplicar fallback.");
        if (mounted) {
          setState(() {
            _calculatedRatioPer10gCH = null;
            _ratioSourceInfo = "Error: Período actual no reconocido.";
            _isLoading = false;
          });
        }
        return;
      }

      int prevIndex = (currentIndex - 1 + _orderedPeriods.length) % _orderedPeriods.length;
      int nextIndex = (currentIndex + 1) % _orderedPeriods.length;

      DayPeriod prevPeriod = _orderedPeriods[prevIndex];
      DayPeriod nextPeriod = _orderedPeriods[nextIndex];

      double? prevRatio = await _calculatorService.getAverageRatioInsulinaCarbohidratosDiv10ForPeriod(period: prevPeriod);
      double? nextRatio = await _calculatorService.getAverageRatioInsulinaCarbohidratosDiv10ForPeriod(period: nextPeriod);

      debugPrint("CurrentInsulinNeeds: Fallback - PrevP(${dayPeriodToString(prevPeriod)}): $prevRatio, NextP(${dayPeriodToString(nextPeriod)}): $nextRatio");

      if (prevRatio != null && nextRatio != null) {
        ratio = (prevRatio + nextRatio) / 2.0;
        sourceInfo = "(Promedio de ${dayPeriodToString(prevPeriod)} y ${dayPeriodToString(nextPeriod)})";
      } else if (prevRatio != null) {
        ratio = prevRatio;
        sourceInfo = "(Datos del período ${dayPeriodToString(prevPeriod)})";
      } else if (nextRatio != null) {
        ratio = nextRatio;
        sourceInfo = "(Datos del período ${dayPeriodToString(nextPeriod)})";
      } else {
        sourceInfo = "(No hay datos suficientes en períodos cercanos)";
      }
    }

    if (mounted) {
      setState(() {
        _calculatedRatioPer10gCH = ratio;
        _ratioSourceInfo = sourceInfo;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Card(
      elevation: 2,
      surfaceTintColor: colorScheme.surfaceTint, // Efecto M3
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.surfaceContainerHigh, // Un color de fondo sutil
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Para que la card se ajuste al contenido
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isLoading ? "Hola..." : "Hola, ${_userName ?? 'Usuario'}!",
              style: textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: CircularProgressIndicator(),
              ))
            else if (_calculatedRatioPer10gCH != null && _calculatedRatioPer10gCH! > 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Tu ratio Insulina/CH estimado es:",
                    style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _calculatedRatioPer10gCH!.toStringAsFixed(1),
                        style: textTheme.displaySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 6.0),
                        child: Text(
                          "U / 10g CH",
                          style: textTheme.titleSmall?.copyWith(color: colorScheme.primary.withValues(alpha:0.9)),
                        ),
                      ),
                    ],
                  ),
                  if (_ratioSourceInfo.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        _ratioSourceInfo,
                        style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant.withValues(alpha:0.8)),
                      ),
                    ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline_rounded, color: colorScheme.secondary, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    "No hay suficientes datos históricos para estimar tu ratio Insulina/CH en este momento.",
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _ratioSourceInfo, // Mostrará "(No hay datos suficientes...)" si es el caso
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant.withValues(alpha:0.7)),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            Center( // Botón para recargar centrado
              child: TextButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text("Recargar"),
                onPressed: _isLoading ? null : _loadWidgetData,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}