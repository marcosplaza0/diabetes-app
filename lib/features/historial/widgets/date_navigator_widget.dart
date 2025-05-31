// Archivo: lib/features/historial/widgets/date_navigator_widget.dart
// Descripción: Widget que proporciona una interfaz para navegar entre fechas.
// Permite al usuario ir al día anterior, al día siguiente o seleccionar una fecha
// específica mediante un selector de fechas (Date Picker).

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:flutter/material.dart'; // Framework principal de Flutter para UI.
import 'package:intl/intl.dart'; // Para formateo de fechas (ej. 'dd MMM yyyy').

/// DateNavigatorWidget: Un StatefulWidget que gestiona la selección de fechas.
///
/// Muestra la fecha actual y botones para navegar al día anterior/siguiente.
/// También incluye un botón para abrir un selector de fechas.
///
/// Parámetros:
/// - `initialDate`: La fecha que se mostrará inicialmente.
/// - `onDateChanged`: Callback que se invoca cuando la fecha cambia.
/// - `firstDate`: La fecha más temprana seleccionable en el Date Picker.
/// - `lastDate`: La fecha más tardía seleccionable en el Date Picker.
class DateNavigatorWidget extends StatefulWidget {
  final DateTime initialDate; // Fecha inicial con la que se carga el widget.
  final ValueChanged<DateTime> onDateChanged; // Función callback para notificar el cambio de fecha.
  final DateTime firstDate; // Límite inferior para la selección de fecha.
  final DateTime lastDate; // Límite superior para la selección de fecha.

  const DateNavigatorWidget({
    super.key,
    required this.initialDate,
    required this.onDateChanged,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<DateNavigatorWidget> createState() => _DateNavigatorWidgetState();
}

/// _DateNavigatorWidgetState: El estado asociado con DateNavigatorWidget.
///
/// Mantiene `_currentDate` que representa la fecha actualmente seleccionada y mostrada.
class _DateNavigatorWidgetState extends State<DateNavigatorWidget> {
  late DateTime _currentDate; // Almacena la fecha actualmente seleccionada.

  @override
  /// initState: Se llama una vez cuando el widget se inserta en el árbol de widgets.
  ///
  /// Inicializa `_currentDate` con la `initialDate` proporcionada al widget.
  void initState() {
    super.initState();
    _currentDate = widget.initialDate;
  }

  @override
  /// didUpdateWidget: Se llama cuando el widget padre reconstruye este widget con nuevos parámetros.
  ///
  /// Si `initialDate` cambia desde el widget padre, actualiza `_currentDate`
  /// para reflejar este cambio. Esto asegura que si la fecha se modifica externamente
  /// (por ejemplo, al volver a esta pantalla y el padre decide mostrar una fecha diferente),
  /// el `DateNavigatorWidget` la refleje correctamente.
  void didUpdateWidget(covariant DateNavigatorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si la fecha inicial proporcionada al widget cambia, actualizamos _currentDate.
    // Esto es importante para mantener la sincronización si la fecha se establece desde fuera.
    if (widget.initialDate != oldWidget.initialDate) {
      setState(() {
        _currentDate = widget.initialDate;
      });
    }
  }

  /// _isSameDay: Comprueba si dos DateTime corresponden al mismo día (ignorando la hora).
  ///
  /// @param dateA El primer DateTime.
  /// @param dateB El segundo DateTime.
  /// @return true si son el mismo día, false en caso contrario.
  bool _isSameDay(DateTime dateA, DateTime dateB) {
    return dateA.year == dateB.year &&
        dateA.month == dateB.month &&
        dateA.day == dateB.day;
  }

  /// _previousDay: Cambia `_currentDate` al día anterior.
  ///
  /// No permite ir a una fecha anterior a `widget.firstDate`.
  /// Llama a `widget.onDateChanged` con la nueva fecha.
  void _previousDay() {
    // Calcula el día anterior.
    final newDate = _currentDate.subtract(const Duration(days: 1));
    // Comprueba que la nueva fecha no sea anterior a la fecha mínima permitida (firstDate).
    // Se usa _isSameDay para permitir seleccionar firstDate, y !newDate.isBefore(widget.firstDate)
    // para la comparación efectiva del día.
    if (!_isSameDay(newDate, widget.firstDate) && newDate.isBefore(widget.firstDate)) {
      return; // No hacer nada si es anterior a la fecha mínima.
    }
    setState(() {
      _currentDate = newDate;
    });
    widget.onDateChanged(_currentDate); // Notifica al widget padre sobre el cambio de fecha.
  }

  /// _nextDay: Cambia `_currentDate` al día siguiente.
  ///
  /// No permite ir a una fecha posterior a `widget.lastDate`.
  /// Llama a `widget.onDateChanged` con la nueva fecha.
  void _nextDay() {
    // Calcula el día siguiente.
    final newDate = _currentDate.add(const Duration(days: 1));
    // Comprueba que la nueva fecha no sea posterior a la fecha máxima permitida (lastDate).
    // Se usa _isSameDay para permitir seleccionar lastDate, y !newDate.isAfter(widget.lastDate)
    // para la comparación efectiva del día.
    if (!_isSameDay(newDate, widget.lastDate) && newDate.isAfter(widget.lastDate)) {
      return; // No hacer nada si es posterior a la fecha máxima.
    }
    setState(() {
      _currentDate = newDate;
    });
    widget.onDateChanged(_currentDate); // Notifica al widget padre sobre el cambio de fecha.
  }

  /// _selectDate: Muestra un selector de fechas (Date Picker).
  ///
  /// Permite al usuario elegir una fecha. Si se selecciona una fecha,
  /// actualiza `_currentDate` y llama a `widget.onDateChanged`.
  ///
  /// @param context El BuildContext actual.
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _currentDate, // Fecha inicialmente seleccionada en el picker.
      firstDate: widget.firstDate, // Límite inferior de fechas seleccionables.
      lastDate: widget.lastDate, // Límite superior de fechas seleccionables.
      locale: const Locale('es', 'ES'), // Configura el idioma del Date Picker a español.
    );
    // Si el usuario selecciona una fecha y no es la misma que la actual.
    if (picked != null && !_isSameDay(picked, _currentDate)) {
      setState(() {
        _currentDate = DateTime(picked.year, picked.month, picked.day); // Normaliza a medianoche.
      });
      widget.onDateChanged(_currentDate); // Notifica el cambio.
    }
  }

  @override
  /// build: Construye la interfaz de usuario del widget de navegación de fechas.
  ///
  /// Muestra botones para día anterior/siguiente y un botón de texto con la fecha actual
  /// que, al ser presionado, abre el selector de fechas.
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Obtiene el tema actual.
    // Formatea la fecha actual para mostrarla, ej: "Sábado, 30 May 2025".
    // El idioma se toma del Localizations.localeOf(context) para internacionalización.
    final String formattedDate = DateFormat('EEE, dd MMM yyyy', Localizations.localeOf(context).languageCode).format(_currentDate);

    // Determina si el botón "anterior" debe estar deshabilitado.
    // Compara _currentDate (normalizada a medianoche) con widget.firstDate (también se asume normalizada).
    final bool isAtFirstDate = _isSameDay(_currentDate, widget.firstDate);

    // Determina si el botón "siguiente" debe estar deshabilitado.
    final bool isAtLastDate = _isSameDay(_currentDate, widget.lastDate);

    return Material( // Envoltura con Material para asegurar que los InkWell y temas funcionen correctamente.
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha:0.5), // Color de fondo sutil.
      elevation: 0, // Sin elevación para una apariencia plana.
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribuye el espacio entre los elementos.
          children: <Widget>[
            // Botón para ir al día anterior.
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              iconSize: 28.0,
              color: isAtFirstDate ? theme.disabledColor : theme.colorScheme.primary, // Cambia color si está deshabilitado.
              tooltip: 'Día anterior',
              onPressed: isAtFirstDate ? null : _previousDay, // Deshabilitado si es la primera fecha.
            ),
            // Botón de texto que muestra la fecha actual y abre el selector de fechas.
            Expanded(
              child: TextButton(
                onPressed: () => _selectDate(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  foregroundColor: theme.colorScheme.onSurface, // Color del texto.
                ),
                child: Text(
                  formattedDate,
                  style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis, // Evita desbordamiento de texto.
                ),
              ),
            ),
            // Botón para ir al día siguiente.
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              iconSize: 28.0,
              color: isAtLastDate ? theme.disabledColor : theme.colorScheme.primary, // Cambia color si está deshabilitado.
              tooltip: 'Día siguiente',
              onPressed: isAtLastDate ? null : _nextDay, // Deshabilitado si es la última fecha.
            ),
          ],
        ),
      ),
    );
  }
}