// File: date_navigator_widget.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// IMPORTANTE: Cambia 'tu_proyecto' por el nombre real de tu proyecto.
// Asumiendo que app_colors.dart está en lib/utils/app_colors.dart

class DateNavigatorWidget extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onDateChanged;
  final DateTime firstDate;
  final DateTime lastDate; // Expected to be DateTime.now() or similar from parent

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

class _DateNavigatorWidgetState extends State<DateNavigatorWidget> {
  late DateTime _currentDisplayDate;

  @override
  void initState() {
    super.initState();
    // Normalize initial date to remove time component
    _currentDisplayDate = DateTime(widget.initialDate.year, widget.initialDate.month, widget.initialDate.day);
    // Date formatting ('es_ES') is assumed to be initialized by the parent screen (e.g., HistorialScreen)
  }

  @override
  void didUpdateWidget(DateNavigatorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    DateTime normalizedNewInitialDate = DateTime(widget.initialDate.year, widget.initialDate.month, widget.initialDate.day);
    if (widget.initialDate != oldWidget.initialDate && normalizedNewInitialDate != _currentDisplayDate) {
      setState(() {
        _currentDisplayDate = normalizedNewInitialDate;
      });
    }
  }

  void _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _currentDisplayDate,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate, // Use widget.lastDate passed from parent
      locale: const Locale('es', 'ES'),
      builder: (BuildContext context, Widget? child) { // Aplicar tema al DatePicker
        return Theme(
          data: ThemeData.light().copyWith( // Puedes usar ThemeData.dark() como base si tu app tiene modo oscuro
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onPrimary, // Color para "ACEPTAR", "CANCELAR"
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _currentDisplayDate) {
      // showDatePicker returns date with time at midnight (normalized)
      setState(() {
        _currentDisplayDate = picked;
      });
      widget.onDateChanged(picked);
    }
  }

  void _goToPreviousDay() {
    if (_canGoToPreviousDay()) {
      final newDate = _currentDisplayDate.subtract(const Duration(days: 1));
      setState(() {
        _currentDisplayDate = newDate;
      });
      widget.onDateChanged(newDate);
    }
  }

  void _goToNextDay() {
    if (_canGoToNextDay()) {
      final newDate = _currentDisplayDate.add(const Duration(days: 1));
      setState(() {
        _currentDisplayDate = newDate;
      });
      widget.onDateChanged(newDate);
    }
  }

  bool _canGoToPreviousDay() {
    DateTime normalizedCurrentDisplayDate = _currentDisplayDate; // Already normalized
    DateTime normalizedFirstDate = DateTime(widget.firstDate.year, widget.firstDate.month, widget.firstDate.day);
    return normalizedCurrentDisplayDate.isAfter(normalizedFirstDate);
  }

  bool _canGoToNextDay() {
    // Lógica proporcionada por el usuario
    DateTime normalizedCurrentDisplayDate = _currentDisplayDate; // Already normalized
    DateTime normalizedLastDate = DateTime(widget.lastDate.year, widget.lastDate.month, widget.lastDate.day);

    DateTime boundaryForEnablingNext = normalizedLastDate;

    bool isBeforeBoundary = normalizedCurrentDisplayDate.isBefore(boundaryForEnablingNext);

    DateTime nextPotentialDay = normalizedCurrentDisplayDate.add(const Duration(days: 1));
    bool nextDayIsValid = !nextPotentialDay.isAfter(normalizedLastDate);

    return isBeforeBoundary && nextDayIsValid;
  }

  @override
  Widget build(BuildContext context) {
    bool canGoPrev = _canGoToPreviousDay();
    bool canGoNext = _canGoToNextDay();

    // Opacidad estándar de Material Design para elementos deshabilitados
    const double disabledOpacity = 0.38;
    final theme = Theme.of(context);


    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      color: theme.colorScheme.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: canGoPrev ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withValues(alpha:disabledOpacity),
            ),
            onPressed: canGoPrev ? _goToPreviousDay : null,
          ),
          GestureDetector(
            onTap: () => _pickDate(context),
            child: Chip(
              label: Text(
                DateFormat('dd/MM/yyyy', 'es_ES').format(_currentDisplayDate),
                style: TextStyle(
                  fontSize: 18,
                  color: theme.colorScheme.onSurface, // Color de texto para la etiqueta del chip
                ),
              ),
              avatar: Icon(
                Icons.calendar_today,
                color: theme.colorScheme.onSurface, // Color del icono para el avatar del chip
              ),
              shape: RoundedRectangleBorder( // Opcional: esquinas más suaves
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.arrow_forward,
              color: canGoNext ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withValues(alpha: disabledOpacity),
            ),
            onPressed: canGoNext ? _goToNextDay : null,
          ),
        ],
      ),
    );
  }
}