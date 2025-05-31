// Archivo: lib/features/home/widgets/recent_logs_widget.dart
// Descripción: Widget que muestra una lista horizontal de los registros de diabetes más recientes
// (últimas 24 horas). Cada registro se representa con un icono que, al ser presionado,
// muestra más detalles en un BottomSheet y permite la edición.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:flutter/material.dart'; // Framework principal de Flutter para UI.
import 'package:hive_flutter/hive_flutter.dart'; // Para ValueListenableBuilder y escuchar cambios en Box de Hive.
import 'package:intl/intl.dart'; // Para formateo de fechas y horas.
import 'package:go_router/go_router.dart'; // Para la navegación (ej. al editar un log).
import 'package:provider/provider.dart'; // Para acceder al LogRepository inyectado.

// Importaciones de archivos del proyecto
import 'package:DiabetiApp/data/models/logs/logs.dart'; // Modelos MealLog y OvernightLog.
import 'package:DiabetiApp/main.dart' show mealLogBoxName, overnightLogBoxName; // Nombres de las cajas de Hive.
import 'package:DiabetiApp/data/repositories/log_repository.dart'; // Interfaz del repositorio de logs.
import 'package:DiabetiApp/core/widgets/loading_or_empty_state_widget.dart'; // Widget para estados de carga, vacío o error.

/// RecentLogsWidget: Un StatefulWidget que muestra los registros recientes.
///
/// Obtiene los logs de las últimas 24 horas del `LogRepository` y los presenta
/// como una fila de iconos clicables. Escucha cambios en las cajas de Hive
/// para actualizarse automáticamente.
class RecentLogsWidget extends StatefulWidget {
  const RecentLogsWidget({super.key});

  @override
  State<RecentLogsWidget> createState() => _RecentLogsWidgetState();
}

class _RecentLogsWidgetState extends State<RecentLogsWidget> {
  // Lista que almacena los logs recientes obtenidos del repositorio.
  // Cada elemento es un Map que contiene el log, su tipo, clave y hora.
  List<Map<String, dynamic>> _sortedRecentLogs = [];
  late LogRepository _logRepository; // Instancia del repositorio de logs.
  bool _isLoading = true; // Estado para controlar la visualización del indicador de carga.

  @override
  /// initState: Se llama una vez cuando el widget se inserta en el árbol de widgets.
  ///
  /// Inicializa `_logRepository` obteniéndolo del `Provider`.
  /// Llama a `_loadRecentLogs()` para cargar los datos iniciales.
  /// Registra listeners a las cajas de `MealLog` y `OvernightLog` de Hive
  /// para recargar los datos si hay cambios.
  void initState() {
    super.initState();
    _logRepository = Provider.of<LogRepository>(context, listen: false);
    _loadRecentLogs(); // Carga inicial de los logs recientes.

    // Escucha cambios en las cajas de MealLog y OvernightLog.
    // Si los datos en estas cajas cambian, se llama a _loadRecentLogs para refrescar la UI.
    Hive.box<MealLog>(mealLogBoxName).listenable().addListener(_loadRecentLogs);
    Hive.box<OvernightLog>(overnightLogBoxName).listenable().addListener(_loadRecentLogs);
  }

  @override
  /// dispose: Se llama cuando el widget se elimina del árbol de widgets.
  ///
  /// Elimina los listeners de las cajas de Hive para evitar memory leaks.
  void dispose() {
    Hive.box<MealLog>(mealLogBoxName).listenable().removeListener(_loadRecentLogs);
    Hive.box<OvernightLog>(overnightLogBoxName).listenable().removeListener(_loadRecentLogs);
    super.dispose();
  }

  /// _loadRecentLogs: Carga los registros de las últimas 24 horas.
  ///
  /// Utiliza `_logRepository` para obtener los logs y actualiza el estado del widget.
  Future<void> _loadRecentLogs() async {
    if (!mounted) return; // No continuar si el widget ya no está montado.
    setState(() {
      _isLoading = true; // Inicia el estado de carga.
    });
    try {
      // Obtiene los logs recientes (últimas 24 horas) del repositorio.
      _sortedRecentLogs = await _logRepository.getRecentLogs(const Duration(hours: 24));
    } catch (e) {
      debugPrint("RecentLogsWidget: Error cargando logs recientes desde el repositorio: $e");
    }
    if (mounted) {
      setState(() {
        _isLoading = false; // Finaliza el estado de carga.
      });
    }
  }

  /// _showLogDetails: Muestra un ModalBottomSheet con los detalles de un log específico.
  ///
  /// Permite al usuario ver la información principal del log y acceder a la pantalla
  /// de edición para ese log.
  ///
  /// @param passedContext El BuildContext desde donde se llama (usualmente el del item de la lista).
  /// @param logData Un Map que contiene el log y metadatos asociados (tipo, clave).
  void _showLogDetails(BuildContext passedContext, dynamic logData) {
    final log = logData['log']; // El objeto MealLog o OvernightLog.
    final String type = logData['type']; // 'meal' o 'overnight'.
    final dynamic logKeyFromMap = logData['key']; // La clave de Hive del log.
    final DateFormat timeFormat = DateFormat.Hm(); // Formato para la hora.
    final theme = Theme.of(passedContext); // Tema del contexto del BottomSheet.

    showModalBottomSheet(
      context: passedContext,
      backgroundColor: theme.colorScheme.surfaceContainerLowest, // Color de fondo del BottomSheet.
      shape: const RoundedRectangleBorder( // Bordes redondeados superiores.
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28.0),
          topRight: Radius.circular(28.0),
        ),
      ),
      builder: (BuildContext bContext) { // `bContext` es el contexto del BottomSheet.
        final bottomSheetTheme = Theme.of(bContext);
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32), // Padding interno.
          child: Column(
            mainAxisSize: MainAxisSize.min, // La columna ocupa el mínimo espacio vertical.
            crossAxisAlignment: CrossAxisAlignment.start, // Alinea el contenido a la izquierda.
            children: <Widget>[
              // Título del BottomSheet.
              Text(
                type == 'meal' ? 'Registro de Comida' : 'Registro Nocturno',
                style: bottomSheetTheme.textTheme.titleLarge?.copyWith(
                    color: bottomSheetTheme.colorScheme.onSurface),
              ),
              const SizedBox(height: 16),
              // Muestra los detalles específicos según el tipo de log.
              if (type == 'meal' && log is MealLog) ...[
                Text('Hora de inicio: ${timeFormat.format(log.startTime)}',
                    style: bottomSheetTheme.textTheme.bodyMedium),
                Text('Glucosa inicial: ${log.initialBloodSugar} mg/dL',
                    style: bottomSheetTheme.textTheme.bodyMedium),
                Text('Carbohidratos: ${log.carbohydrates} g',
                    style: bottomSheetTheme.textTheme.bodyMedium),
                Text('Unidades de insulina: ${log.insulinUnits} U',
                    style: bottomSheetTheme.textTheme.bodyMedium),
              ] else
                if (type == 'overnight' && log is OvernightLog) ...[
                  Text('Hora de dormir: ${timeFormat.format(log.bedTime)}',
                      style: bottomSheetTheme.textTheme.bodyMedium),
                  Text('Glucosa antes de dormir: ${log.beforeSleepBloodSugar} mg/dL',
                      style: bottomSheetTheme.textTheme.bodyMedium),
                  Text('Unidades de insulina lenta: ${log.slowInsulinUnits} U',
                      style: bottomSheetTheme.textTheme.bodyMedium),
                ],
              const SizedBox(height: 24),
              // Botón para editar el registro.
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: Icon(Icons.edit_rounded,
                      color: bottomSheetTheme.colorScheme.primary),
                  tooltip: 'Editar registro',
                  onPressed: () {
                    Navigator.pop(bContext); // Cierra el BottomSheet.

                    if (logKeyFromMap != null) {
                      final String logKeyString = logKeyFromMap.toString();
                      final String logTypeString = type;

                      // Navega a la pantalla de edición del log.
                      GoRouter.of(passedContext).pushNamed(
                        'diabetesLogEdit', // Nombre de la ruta definida en GoRouter. //
                        pathParameters: { // Parámetros de ruta para identificar el log a editar. //
                          'logTypeString': logTypeString,
                          'logKeyString': logKeyString,
                        },
                      );
                    } else {
                      // Muestra un error si la clave del log es nula.
                      ScaffoldMessenger.of(passedContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Error: No se pudo obtener la clave del registro para editar.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  /// build: Construye la interfaz de usuario del widget.
  ///
  /// Utiliza `LoadingOrEmptyStateWidget` para manejar los estados de carga,
  /// vacío o error. Si hay datos, muestra una lista horizontal (`SingleChildScrollView`
  /// con un `Row`) de iconos representando los logs recientes.
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LoadingOrEmptyStateWidget(
      isLoading: _isLoading, // Estado de carga actual.
      loadingText: "Cargando últimos registros...",

      // Considera vacío si no está cargando y la lista de logs está vacía.
      isEmpty: !_isLoading && _sortedRecentLogs.isEmpty,
      emptyMessage: "No hay registros en las últimas 24 horas.",
      emptyIcon: Icons.history_toggle_off_outlined, // Icono para el estado vacío.
      childIfData: SingleChildScrollView( // Permite el desplazamiento horizontal de los iconos.
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row( // Muestra los iconos en una fila.
          children: _sortedRecentLogs.map((logData) {
            final String type = logData['type']; // 'meal' o 'overnight'.
            final DateTime time = logData['time']; // Hora del log.
            // Icono y colores según el tipo de log.
            IconData iconData = type == 'meal' ? Icons.fastfood_rounded : Icons.bedtime_rounded;
            Color iconBackgroundColor = type == 'meal' ? theme.colorScheme.primaryContainer : theme.colorScheme.secondaryContainer;
            Color onIconBackgroundColor = type == 'meal' ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSecondaryContainer;

            // Cada log se representa como una columna con un IconButton y la hora debajo.
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Column(
                mainAxisSize: MainAxisSize.min, // La columna ocupa el mínimo espacio vertical.
                children: [
                  Container( // Contenedor para dar forma circular al fondo del IconButton.
                    decoration: BoxDecoration(
                      color: iconBackgroundColor.withAlpha(90), // Fondo semi-transparente.
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(iconData, size: 22),
                      color: onIconBackgroundColor, // Color del icono.
                      tooltip: '${type == 'meal' ? 'Comida' : 'Noche'} - ${DateFormat.Hm().format(time)}', // Tooltip con tipo y hora.
                      onPressed: () => _showLogDetails(context, logData), // Muestra detalles al presionar.
                      iconSize: 20,
                      padding: const EdgeInsets.all(10),
                      constraints: const BoxConstraints(), // Para controlar el tamaño del área táctil.
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Muestra la hora del log debajo del icono.
                  Text(
                    DateFormat.Hm().format(time),
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  )
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}