// Archivo: lib/features/historial/presentation/historial_screen.dart
// Descripción: Define la pantalla de historial de la aplicación.
// Esta pantalla permite a los usuarios visualizar los registros de comidas y nocturnos
// organizados por fecha. Incluye un navegador de fechas para seleccionar el día
// y muestra los registros correspondientes a la fecha seleccionada.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:flutter/material.dart'; // Framework principal de Flutter para UI.
import 'package:intl/date_symbol_data_local.dart'; // Necesario para inicializar el formato de fecha localizado (ej. 'es_ES').

// Importaciones de archivos del proyecto
import 'package:diabetes_2/core/layout/main_layout.dart'; // Widget de diseño principal de la pantalla.
import 'package:diabetes_2/features/historial/widgets/date_navigator_widget.dart'; // Widget para la navegación entre fechas.
import 'package:diabetes_2/features/historial/widgets/daily_log_list_widget.dart'; // Widget para mostrar la lista de logs diarios.

/// HistorialScreen: Un StatefulWidget que representa la pantalla de historial.
///
/// Gestiona la selección de la fecha y muestra los registros correspondientes
/// a esa fecha. Utiliza `DateNavigatorWidget` para la selección de fecha y
/// `DailyLogListWidget` para mostrar los registros.
class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

/// _HistorialScreenState: El estado asociado con HistorialScreen.
///
/// Mantiene la fecha seleccionada (`_selectedDate`) y un indicador para
/// saber si la inicialización del formato de fecha ha concluido (`_isDateFormattingInitialized`).
class _HistorialScreenState extends State<HistorialScreen> {
  /// _selectedDate: La fecha actualmente seleccionada por el usuario para mostrar los registros.
  /// Se inicializa con la fecha actual.
  late DateTime _selectedDate;

  /// _isDateFormattingInitialized: Booleano que indica si la inicialización
  /// de `initializeDateFormatting` para 'es_ES' ha terminado. Esto es crucial
  /// para asegurar que los formatos de fecha se muestren correctamente.
  bool _isDateFormattingInitialized = false;

  @override
  /// initState: Se llama una vez cuando el widget se inserta en el árbol de widgets.
  ///
  /// Aquí se inicializa `_selectedDate` a la medianoche del día actual para
  /// asegurar consistencia al comparar fechas. También se inicia la
  /// inicialización del formato de fecha para español ('es_ES').
  void initState() {
    super.initState();
    // Inicializa _selectedDate al día de hoy, normalizando la hora a medianoche.
    // Esto es importante para que las comparaciones de fechas (ej. en filtros)
    // no se vean afectadas por el componente de tiempo.
    DateTime now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);

    // Inicializa el formateo de fechas para el idioma español.
    // Es una operación asíncrona. Una vez completada, se actualiza el estado
    // para indicar que la UI puede proceder a renderizar contenido que dependa de formatos de fecha.
    initializeDateFormatting('es_ES', null).then((_) {
      if (mounted) { // Verifica si el widget todavía está montado antes de llamar a setState.
        setState(() {
          _isDateFormattingInitialized = true;
        });
      }
    }).catchError((error) {
      // En caso de error durante la inicialización del formato de fecha,
      // se imprime un mensaje en la consola y se marca como inicializado
      // para evitar un estado de carga indefinido.
      debugPrint("HistorialScreen: Error al inicializar el formato de fecha: $error");
      if (mounted) {
        setState(() {
          _isDateFormattingInitialized = true; // Permite continuar para no bloquear la UI.
        });
      }
    });
  }

  /// _onDateChangedByNavigator: Callback que se ejecuta cuando el usuario cambia la fecha
  /// en el `DateNavigatorWidget`.
  ///
  /// Actualiza `_selectedDate` con la nueva fecha (normalizada a medianoche)
  /// y redibuja el widget para mostrar los registros de la nueva fecha.
  ///
  /// @param newDate La nueva fecha seleccionada en el `DateNavigatorWidget`.
  void _onDateChangedByNavigator(DateTime newDate) {
    setState(() {
      // Asegura que la nueva fecha también esté normalizada a medianoche.
      _selectedDate = DateTime(newDate.year, newDate.month, newDate.day);
      // Al cambiar _selectedDate y llamar a setState, el widget DailyLogListWidget
      // se reconstruirá con la nueva fecha, lo que provocará que cargue y muestre
      // los registros correspondientes a esa nueva fecha.
    });
  }

  @override
  /// build: Construye la interfaz de usuario de la pantalla de historial.
  ///
  /// Muestra un indicador de progreso circular mientras `_isDateFormattingInitialized`
  /// es falso. Una vez inicializado, muestra el `DateNavigatorWidget` y
  /// el `DailyLogListWidget` dentro de un `MainLayout`.
  Widget build(BuildContext context) {
    // Muestra un indicador de carga hasta que el formateo de fecha esté listo.
    // Esto previene errores o UI incorrecta si se intentan formatear fechas antes
    // de que la localización esté completamente cargada.
    if (!_isDateFormattingInitialized) {
      return MainLayout(
        title: 'Historial',
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Una vez inicializado el formato de fecha, construye la UI principal.
    return MainLayout(
      title: 'Historial', // Título de la AppBar.
      body: Column(
        children: [
          // Widget para seleccionar la fecha (día anterior, día siguiente, selector de fecha).
          DateNavigatorWidget(
            initialDate: _selectedDate, // La fecha actualmente seleccionada.
            onDateChanged: _onDateChangedByNavigator, // Callback para cuando cambia la fecha.
            firstDate: DateTime(2000), // Límite inferior para el selector de fecha.
            lastDate: DateTime.now(), // Límite superior (hoy) para el selector de fecha. //
          ),

          // Widget que muestra la lista de registros para la `_selectedDate`.
          // Se expande para ocupar el espacio restante en la columna.
          Expanded(
            child: DailyLogListWidget(selectedDate: _selectedDate),
          ),
        ],
      ),
    );
  }
}