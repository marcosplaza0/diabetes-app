// Archivo: lib/features/historial/widgets/daily_log_list_widget.dart
// Descripción: Widget que muestra una lista de registros de diabetes (comidas y nocturnos)
// para una fecha seleccionada. Obtiene los datos del LogRepository y reacciona
// a los cambios en las cajas de Hive para actualizar la UI.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:flutter/material.dart'; // Framework principal de Flutter para UI.
import 'package:hive_flutter/hive_flutter.dart'; // Para ValueListenableBuilder y escuchar cambios en Box de Hive.
import 'package:intl/intl.dart'; // Para formateo de fechas y horas.
import 'package:go_router/go_router.dart'; // Para la navegación (ej. al editar un log).
import 'package:provider/provider.dart'; // Para acceder al LogRepository inyectado.

// Importaciones de archivos del proyecto
import 'package:diabetes_2/data/models/logs/logs.dart'; // Modelos MealLog y OvernightLog.
import 'package:diabetes_2/main.dart' show mealLogBoxName, overnightLogBoxName; // Nombres de las cajas de Hive.
import 'package:diabetes_2/data/repositories/log_repository.dart'; // Interfaz del repositorio de logs.
import 'package:diabetes_2/core/widgets/loading_or_empty_state_widget.dart'; // Widget para estados de carga, vacío o error.

/// DailyLogListWidget: Un StatefulWidget que muestra los registros de un día específico.
///
/// Recibe una `selectedDate` y utiliza un `LogRepository` (obtenido vía Provider)
/// para cargar los `MealLog` y `OvernightLog` correspondientes a esa fecha.
/// Usa `FutureBuilder` para manejar la carga asíncrona de datos y
/// `ValueListenableBuilder` para escuchar cambios en las cajas de Hive,
/// lo que permite que la lista se actualice automáticamente si los datos cambian.
class DailyLogListWidget extends StatefulWidget {
  final DateTime selectedDate; // La fecha para la cual se mostrarán los registros.

  const DailyLogListWidget({
    super.key,
    required this.selectedDate,
  });

  @override
  State<DailyLogListWidget> createState() => _DailyLogListWidgetState();
}

class _DailyLogListWidgetState extends State<DailyLogListWidget> {
  late LogRepository _logRepository; // Instancia del repositorio de logs.
  // Listeners para las cajas de Hive. Se usan con ValueListenableBuilder
  // para reconstruir la UI cuando los datos en estas cajas cambian.
  late Box<MealLog> _mealLogBoxListener;
  late Box<OvernightLog> _overnightLogBoxListener;

  @override
  /// initState: Se llama una vez cuando el widget se inserta en el árbol de widgets.
  ///
  /// Inicializa `_logRepository` obteniéndolo del `Provider`.
  /// También obtiene las instancias de las cajas de Hive para `MealLog` y `OvernightLog`
  /// que se usarán con `ValueListenableBuilder`.
  void initState() {
    super.initState();
    // Obtiene la instancia de LogRepository del Provider. listen: false porque
    // la obtención del repositorio solo se necesita una vez durante la inicialización.
    _logRepository = Provider.of<LogRepository>(context, listen: false);
    // Obtiene las instancias de las cajas de Hive.
    _mealLogBoxListener = Hive.box<MealLog>(mealLogBoxName);
    _overnightLogBoxListener = Hive.box<OvernightLog>(overnightLogBoxName);
  }

  /// _getFilteredAndSortedLogs: Obtiene y ordena los registros para la `selectedDate`.
  ///
  /// Llama al método `getFilteredAndSortedLogsForDate` del `_logRepository`
  /// para obtener una lista combinada y ordenada de `MealLog` y `OvernightLog`.
  ///
  /// @return Un Future<List<dynamic>> que resuelve a la lista de logs.
  Future<List<dynamic>> _getFilteredAndSortedLogs() async {
    return await _logRepository.getFilteredAndSortedLogsForDate(widget.selectedDate); //
  }

  /// _getGlucoseColor: Determina el color a usar para mostrar un valor de glucosa.
  ///
  /// Cambia de color según si el valor es hipoglucémico, hiperglucémico o está en rango.
  ///
  /// @param bG El valor de glucosa sanguínea.
  /// @param theme El ThemeData actual para acceder a los colores del esquema.
  /// @return Un Color para el texto del valor de glucosa.
  Color _getGlucoseColor(double? bG, ThemeData theme) {
    if (bG == null) return theme.colorScheme.onSurfaceVariant.withOpacity(0.7); // Color por defecto si es nulo.
    if (bG < 70) return theme.colorScheme.error; // Color para hipoglucemia.
    if (bG > 180) return Colors.red.shade700; // Color para hiperglucemia (ligeramente diferente del error).
    return Colors.green.shade600; // Color para glucosa en rango.
  }

  /// _buildDetailItem: Widget helper para construir una fila de detalle (icono, etiqueta, valor).
  ///
  /// @param context El BuildContext.
  /// @param icon El IconData para el icono.
  /// @param label El texto de la etiqueta.
  /// @param value El texto del valor.
  /// @param valueColor Color opcional para el texto del valor.
  /// @param iconColor Color opcional para el icono.
  /// @return Un Padding widget que contiene un Row con el detalle.
  Widget _buildDetailItem(BuildContext context, IconData icon, String label, String value, {Color? valueColor, Color? iconColor}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18.0, color: iconColor ?? theme.colorScheme.onSurfaceVariant.withOpacity(0.9)),
          const SizedBox(width: 10.0),
          Expanded(
              child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)
              )
          ),
          const SizedBox(width: 8.0),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor ?? theme.colorScheme.onSurface
            ),
            textAlign: TextAlign.end,
          ),
        ],
      ),
    );
  }

  /// _buildGlucoseDetailItem: Widget helper específico para detalles de glucosa.
  ///
  /// Utiliza `_buildDetailItem` y `_getGlucoseColor` para mostrar el valor de glucosa con el color apropiado.
  ///
  /// @param context El BuildContext.
  /// @param label La etiqueta para el valor de glucosa.
  /// @param glucoseValue El valor numérico de la glucosa.
  /// @param icon El IconData para el ítem.
  /// @return Un widget que muestra el detalle de la glucosa.
  Widget _buildGlucoseDetailItem(BuildContext context, String label, double? glucoseValue, IconData icon) {
    final theme = Theme.of(context);
    final Color glucoseColor = _getGlucoseColor(glucoseValue, theme); // Determina el color basado en el valor.
    return _buildDetailItem(
        context,
        icon,
        label,
        glucoseValue != null ? '${glucoseValue.toStringAsFixed(0)} mg/dL' : '-- mg/dL', // Formatea el valor.
        valueColor: glucoseColor, // Aplica el color al valor.
        iconColor: glucoseColor.withOpacity(0.85) // Aplica una versión ligeramente transparente del color al icono.
    );
  }


  /// _buildMealLogTile: Construye el widget para mostrar un `MealLog`.
  ///
  /// Muestra los detalles de un registro de comida en una tarjeta interactiva.
  /// Al tocar la tarjeta, navega a la pantalla de edición del log.
  ///
  /// @param log El objeto MealLog a mostrar.
  /// @param theme El ThemeData actual.
  /// @return Un Card widget representando el MealLog.
  Widget _buildMealLogTile(MealLog log, ThemeData theme) {
    // Formateador de hora localizado.
    final timeFormat = DateFormat.Hm(Localizations.localeOf(context).languageCode);

    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      color: theme.colorScheme.surfaceContainer, // Color de fondo de la tarjeta.
      clipBehavior: Clip.antiAlias, // Para que el InkWell respete los bordes redondeados.
      child: InkWell(
        onTap: () {
          // Navegación a la pantalla de edición.
          // Se pasa el tipo de log ('meal') y su clave (Hive key) como parámetros de ruta.
          if (log.key != null) { // `log.key` es la clave de Hive del objeto.
            final String logKeyString = log.key.toString();
            context.pushNamed(
              'diabetesLogEdit', // Nombre de la ruta definida en GoRouter.
              pathParameters: {
                'logTypeString': 'meal',
                'logKeyString': logKeyString,
              },
            );
          } else {
            // Muestra un error si la clave del log es nula, lo que no debería ocurrir.
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Error: No se pudo obtener la clave de la nota."), backgroundColor: Colors.orange)
            );
          }
        },
        borderRadius: BorderRadius.circular(16.0), // Para el efecto de tinta del InkWell.
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado de la tarjeta (icono, título, icono de edición).
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    radius: 22,
                    child: Icon(Icons.restaurant_menu_rounded, color: theme.colorScheme.onPrimaryContainer, size: 22),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Text(
                      'Comida - ${timeFormat.format(log.startTime)}', // Título con la hora de inicio.
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                    ),
                  ),
                  Icon(Icons.edit_note_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7)) // Indicador visual de edición.
                ],
              ),
              const Divider(height: 20.0, thickness: 0.5), // Separador visual.
              // Detalles del MealLog.
              _buildGlucoseDetailItem(context, 'Glucosa Inicial:', log.initialBloodSugar, Icons.arrow_upward_rounded), //
              _buildDetailItem(context, Icons.lunch_dining_outlined, 'Carbohidratos:', '${log.carbohydrates.toStringAsFixed(0)} g', iconColor: theme.colorScheme.tertiary), //
              _buildDetailItem(context, Icons.opacity_rounded, 'Insulina Rápida:', '${log.insulinUnits.toStringAsFixed(1)} U', iconColor: theme.colorScheme.secondary), //
              // Muestra la glucosa final y hora final si están disponibles.
              if (log.finalBloodSugar != null) ...[ //
                const SizedBox(height: 6),
                _buildGlucoseDetailItem(context, 'Glucosa Final ${log.endTime != null ? "(${timeFormat.format(log.endTime!)})" : ""}:', log.finalBloodSugar, Icons.arrow_downward_rounded), //
              ]
            ],
          ),
        ),
      ),
    );
  }

  /// _buildOvernightLogTile: Construye el widget para mostrar un `OvernightLog`.
  ///
  /// Similar a `_buildMealLogTile`, pero para registros nocturnos.
  ///
  /// @param log El objeto OvernightLog a mostrar.
  /// @param theme El ThemeData actual.
  /// @return Un Card widget representando el OvernightLog.
  Widget _buildOvernightLogTile(OvernightLog log, ThemeData theme) {
    final timeFormat = DateFormat.Hm(Localizations.localeOf(context).languageCode);
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      color: theme.colorScheme.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (log.key != null) {
            final String logKeyString = log.key.toString();
            context.pushNamed(
              'diabetesLogEdit',
              pathParameters: {
                'logTypeString': 'overnight',
                'logKeyString': logKeyString,
              },
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Error: No se pudo obtener la clave de la nota."), backgroundColor: Colors.orange)
            );
          }
        },
        borderRadius: BorderRadius.circular(16.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    radius: 22,
                    child: Icon(Icons.bedtime_rounded, color: theme.colorScheme.onSecondaryContainer, size: 22),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Text(
                      'Noche - ${timeFormat.format(log.bedTime)}', //
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                    ),
                  ),
                  Icon(Icons.edit_note_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7))
                ],
              ),
              const Divider(height: 20.0, thickness: 0.5),
              _buildGlucoseDetailItem(context, 'Glucosa al Dormir:', log.beforeSleepBloodSugar, Icons.nights_stay_rounded), //
              _buildDetailItem(context, Icons.medication_liquid_outlined, 'Insulina Lenta:', '${log.slowInsulinUnits.toStringAsFixed(1)} U', iconColor: theme.colorScheme.tertiary), //
              if (log.afterWakeUpBloodSugar != null) ...[ //
                const SizedBox(height: 6),
                _buildGlucoseDetailItem(context, 'Glucosa al Despertar:', log.afterWakeUpBloodSugar, Icons.wb_sunny_rounded), //
              ]
            ],
          ),
        ),
      ),
    );
  }


  @override
  /// build: Construye la interfaz de usuario del widget.
  ///
  /// Utiliza `ValueListenableBuilder` anidados para escuchar cambios en las cajas
  /// de `MealLog` y `OvernightLog`. Dentro, un `FutureBuilder` se encarga de
  /// llamar a `_getFilteredAndSortedLogs` y mostrar la UI correspondiente
  /// (carga, error, vacío, o la lista de logs) usando `LoadingOrEmptyStateWidget`.
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // ValueListenableBuilder se usa para que el FutureBuilder se reconstruya (y por lo tanto,
    // vuelva a llamar a `_getFilteredAndSortedLogs`) si los datos en las cajas de Hive cambian.
    // Esto es útil si un log se añade, modifica o elimina desde otra parte de la app
    // mientras esta pantalla está visible, o si se vuelve a esta pantalla.
    return ValueListenableBuilder<Box<MealLog>>(
      valueListenable: _mealLogBoxListener.listenable(), // Escucha la caja de MealLog.
      builder: (context, _, __) { // Los argumentos `_` y `__` son la caja y el widget hijo, no usados aquí.
        return ValueListenableBuilder<Box<OvernightLog>>(
          valueListenable: _overnightLogBoxListener.listenable(), // Escucha la caja de OvernightLog.
          builder: (context, ___, ____) {
            // FutureBuilder maneja la carga asíncrona de los logs.
            // El `future` se vuelve a ejecutar si `widget.selectedDate` cambia (porque el widget se reconstruye)
            // o si los `ValueListenableBuilder` causan una reconstrucción.
            return FutureBuilder<List<dynamic>>(
              future: _getFilteredAndSortedLogs(), // Llama al método que obtiene los datos.
              builder: (context, snapshot) {
                // LoadingOrEmptyStateWidget gestiona la UI para los diferentes estados del snapshot.
                return LoadingOrEmptyStateWidget(
                  isLoading: snapshot.connectionState == ConnectionState.waiting,
                  loadingText: "Cargando registros...",
                  hasError: snapshot.hasError,
                  error: snapshot.error, // Pasa el objeto de error para posible logging o display.
                  errorMessage: snapshot.hasError ? "No se pudieron cargar los registros." : null,
                  onRetry: () {
                    // Permite al usuario reintentar la carga si falla.
                    // Simplemente llamando a setState() aquí, si la dependencia del Future (widget.selectedDate)
                    // no ha cambiado, puede que no re-ejecute el future directamente sin cambiar la 'key'
                    // del FutureBuilder o alguna otra estrategia. Sin embargo, dado que los ValueListenableBuilders
                    // ya están escuchando, un cambio en los datos de Hive sí dispararía la reconstrucción.
                    setState(() {});
                  },
                  isEmpty: !snapshot.hasData || snapshot.data!.isEmpty, // Considera vacío si no hay datos o la lista está vacía.
                  emptyMessage: "No hay registros para el\n${DateFormat('EEEE dd MMMM', 'es_ES').format(widget.selectedDate)}",
                  emptyIcon: Icons.forum_outlined, // Icono para el estado vacío.
                  childIfData: ListView.builder( // Si hay datos, muestra la lista.
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), // Efecto de rebote al hacer scroll.
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    itemCount: snapshot.hasData ? snapshot.data!.length : 0,
                    itemBuilder: (context, index) {
                      final log = snapshot.data![index];
                      // Determina qué tipo de tile construir basado en el tipo de log.
                      if (log is MealLog) {
                        return _buildMealLogTile(log, theme);
                      } else if (log is OvernightLog) {
                        return _buildOvernightLogTile(log, theme);
                      }
                      return const SizedBox.shrink(); // En caso de un tipo de log inesperado.
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}