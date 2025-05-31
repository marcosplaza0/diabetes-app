// Archivo: lib/features/home/widgets/current_insulin_needs_widget.dart
// Descripción: Widget que muestra una estimación de las necesidades actuales de insulina del usuario.
// Calcula y muestra un ratio Insulina/Carbohidratos (CH) estimado para el período del día actual,
// basándose en datos históricos. También incluye un saludo personalizado.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:flutter/material.dart' hide DayPeriod; // Se oculta DayPeriod de Material si existe conflicto.
import 'package:hive_flutter/hive_flutter.dart'; // Para ValueListenableBuilder y escuchar cambios en Box de Hive.
import 'package:provider/provider.dart'; // Para acceder a servicios inyectados, como DiabetesCalculatorService.

// Importaciones de archivos del proyecto
import 'package:diabetes_2/data/models/profile/user_profile_data.dart'; // Modelo para datos del perfil de usuario.
import 'package:diabetes_2/main.dart' show supabase, userProfileBoxName, mealLogBoxName; // Para acceso a Supabase auth, nombres de cajas.
import 'package:diabetes_2/core/services/diabetes_calculator_service.dart'; // Servicio para cálculos de diabetes.
import 'package:diabetes_2/data/models/calculations/daily_calculation_data.dart' show DayPeriod, dayPeriodToString; // Enum DayPeriod y helper.
import 'package:diabetes_2/data/models/logs/logs.dart'; // Modelo MealLog, para el listener de Hive.

/// CurrentInsulinNeedsWidget: Un StatefulWidget que muestra la estimación de necesidades de insulina.
///
/// Obtiene datos del perfil del usuario y utiliza `DiabetesCalculatorService` para
/// calcular el ratio Insulina/CH. Reacciona a cambios en los `MealLog` para
/// actualizar la estimación si es necesario.
class CurrentInsulinNeedsWidget extends StatefulWidget {
  const CurrentInsulinNeedsWidget({super.key});

  @override
  State<CurrentInsulinNeedsWidget> createState() => _CurrentInsulinNeedsWidgetState();
}

class _CurrentInsulinNeedsWidgetState extends State<CurrentInsulinNeedsWidget> {
  late DiabetesCalculatorService _calculatorService; // Servicio para realizar los cálculos.

  bool _isLoading = true; // Estado para controlar la visualización del indicador de carga.
  String? _userName; // Nombre del usuario para el saludo.
  double? _calculatedRatioPer10gCH; // Ratio Insulina / 10g CH calculado.
  String _ratioSourceInfo = ""; // Información sobre cómo se obtuvo el ratio (ej. período actual, fallback).

  // Lista ordenada de períodos del día, usada para la lógica de fallback.
  final List<DayPeriod> _orderedPeriods = const [
    DayPeriod.P1, DayPeriod.P2, DayPeriod.P3, DayPeriod.P4,
    DayPeriod.P5, DayPeriod.P6, DayPeriod.P7
  ];

  @override
  /// initState: Se llama una vez cuando el widget se inserta en el árbol de widgets.
  ///
  /// Inicializa `_calculatorService` obteniéndolo del `Provider`.
  /// Llama a `_loadWidgetData()` para cargar los datos iniciales.
  /// Registra un listener a la caja de `MealLog` de Hive para recargar los datos
  /// si hay cambios en los registros de comidas.
  void initState() {
    super.initState();
    // Obtiene la instancia de DiabetesCalculatorService del Provider.
    // listen: false porque solo se necesita la instancia, no escuchar cambios en el servicio mismo aquí.
    _calculatorService = Provider.of<DiabetesCalculatorService>(context, listen: false);
    _loadWidgetData(); // Carga los datos iniciales del widget.

    // Escucha cambios en la caja de MealLog. Si hay cambios (ej. se añade un nuevo log),
    // se llama a _handleHiveChanges para potencialmente recargar los datos y actualizar la UI.
    Hive.box<MealLog>(mealLogBoxName).listenable().addListener(_handleHiveChanges);
  }

  @override
  /// dispose: Se llama cuando el widget se elimina del árbol de widgets.
  ///
  /// Elimina el listener de la caja de `MealLog` para evitar memory leaks.
  void dispose() {
    Hive.box<MealLog>(mealLogBoxName).listenable().removeListener(_handleHiveChanges);
    super.dispose();
  }

  /// _handleHiveChanges: Callback que se ejecuta cuando hay cambios en la caja de MealLog.
  ///
  /// Llama a `_loadWidgetData()` para recargar y potencialmente actualizar la estimación.
  void _handleHiveChanges() {
    _loadWidgetData();
  }

  /// _loadWidgetData: Carga los datos necesarios para el widget.
  ///
  /// Obtiene el nombre del perfil del usuario y calcula el ratio Insulina/CH
  /// para el período actual del día. Implementa una lógica de fallback para usar
  /// datos de períodos adyacentes si no hay suficientes datos para el actual.
  Future<void> _loadWidgetData() async {
    if (!mounted) return; // No continuar si el widget ya no está montado.
    setState(() { _isLoading = true; }); // Inicia el estado de carga.

    // Carga el perfil del usuario desde Hive para obtener el nombre.
    final userProfileBox = Hive.box<UserProfileData>(userProfileBoxName);
    final UserProfileData? profile = userProfileBox.get('currentUserProfile');
    // Si no hay perfil o nombre, usa el email del usuario de Supabase o un valor por defecto.
    _userName = profile?.username ?? supabase.auth.currentUser?.email?.split('@').first ?? "Usuario";

    final now = DateTime.now();
    final currentPeriod = _calculatorService.getDayPeriod(now); // Determina el período del día actual.
    double? ratio; // Ratio calculado.
    String sourceInfo = "(Período actual: ${dayPeriodToString(currentPeriod)})"; // Información base de la fuente.

    // Intenta obtener el ratio para el período actual.
    ratio = await _calculatorService.getAverageRatioInsulinaCarbohidratosDiv10ForPeriod(period: currentPeriod); //

    // Lógica de fallback si no hay datos para el período actual.
    if (ratio == null) {
      debugPrint("CurrentInsulinNeeds: No hay datos para el período actual (${dayPeriodToString(currentPeriod)}). Buscando en adyacentes.");
      int currentIndex = _orderedPeriods.indexOf(currentPeriod);
      if (currentIndex == -1) { // Si el período actual no es reconocido.
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
      // Índices para los períodos anterior y siguiente, con manejo de circularidad.
      int prevIndex = (currentIndex - 1 + _orderedPeriods.length) % _orderedPeriods.length;
      int nextIndex = (currentIndex + 1) % _orderedPeriods.length;
      DayPeriod prevPeriod = _orderedPeriods[prevIndex];
      DayPeriod nextPeriod = _orderedPeriods[nextIndex];

      // Obtiene ratios para los períodos adyacentes.
      double? prevRatio = await _calculatorService.getAverageRatioInsulinaCarbohidratosDiv10ForPeriod(period: prevPeriod);
      double? nextRatio = await _calculatorService.getAverageRatioInsulinaCarbohidratosDiv10ForPeriod(period: nextPeriod);
      debugPrint("CurrentInsulinNeeds: Fallback - PrevP(${dayPeriodToString(prevPeriod)}): $prevRatio, NextP(${dayPeriodToString(nextPeriod)}): $nextRatio");

      // Decide qué ratio usar basado en la disponibilidad de datos de fallback.
      if (prevRatio != null && nextRatio != null) {
        ratio = (prevRatio + nextRatio) / 2.0; // Promedio de ambos.
        sourceInfo = "(Promedio de ${dayPeriodToString(prevPeriod)} y ${dayPeriodToString(nextPeriod)})";
      } else if (prevRatio != null) {
        ratio = prevRatio; // Usa el del período anterior.
        sourceInfo = "(Datos del período ${dayPeriodToString(prevPeriod)})";
      } else if (nextRatio != null) {
        ratio = nextRatio; // Usa el del período siguiente.
        sourceInfo = "(Datos del período ${dayPeriodToString(nextPeriod)})";
      } else {
        // Si no hay datos en períodos cercanos.
        sourceInfo = "(No hay datos suficientes en períodos cercanos)";
      }
    }

    // Actualiza el estado del widget con los datos cargados/calculados.
    if (mounted) {
      setState(() {
        _calculatedRatioPer10gCH = ratio;
        _ratioSourceInfo = sourceInfo;
        _isLoading = false; // Finaliza el estado de carga.
      });
    }
  }

  @override
  /// build: Construye la interfaz de usuario del widget.
  ///
  /// Muestra un saludo personalizado y la estimación del ratio Insulina/CH.
  /// Presenta un estado de carga o un mensaje si no hay suficientes datos.
  /// Incluye un botón para recargar los datos manualmente.
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Card(
      elevation: 2, surfaceTintColor: colorScheme.surfaceTint, // Efectos visuales de Material 3.
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.surfaceContainerHigh, // Color de fondo de la tarjeta.
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min, // La columna ocupa el mínimo espacio vertical necesario.
          crossAxisAlignment: CrossAxisAlignment.start, // Alinea el contenido a la izquierda.
          children: [
            // Saludo al usuario.
            Text(
                _isLoading ? "Hola..." : "Hola, ${_userName ?? 'Usuario'}!", // Muestra "Hola..." mientras carga.
                style: textTheme.headlineSmall?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 12),

            // Muestra el indicador de carga o el contenido principal.
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: CircularProgressIndicator()))
            // Si hay un ratio calculado y es positivo.
            else if (_calculatedRatioPer10gCH != null && _calculatedRatioPer10gCH! > 0)
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Tu ratio Insulina/CH estimado es:", style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Row( // Muestra el valor del ratio y las unidades.
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic, // Alinea el texto por la línea base.
                        children: [
                          Text(_calculatedRatioPer10gCH!.toStringAsFixed(1), style: textTheme.displaySmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w700)),
                          Padding(
                            padding: const EdgeInsets.only(left: 6.0),
                            child: Text("U / 10g CH", style: textTheme.titleSmall?.copyWith(color: colorScheme.primary.withValues(alpha:0.9))),
                          ),
                        ]
                    ),
                    // Muestra información sobre cómo se obtuvo el ratio.
                    if (_ratioSourceInfo.isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(_ratioSourceInfo, style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant.withValues(alpha:0.8)))
                      ),
                  ]
              )
            // Si no hay suficientes datos para calcular el ratio.
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
                        style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)
                    ),
                    const SizedBox(height: 8),
                    Text(
                        _ratioSourceInfo, // Muestra la razón por la que no se pudo calcular (ej. falta de datos en períodos cercanos).
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant.withValues(alpha:0.7))
                    ),
                  ]
              ),
            const SizedBox(height: 16),

            // Botón para recargar los datos manualmente.
            Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text("Recargar"),
                  onPressed: _isLoading ? null : _loadWidgetData, // Deshabilitado mientras carga.
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                )
            ),
          ],
        ),
      ),
    );
  }
}