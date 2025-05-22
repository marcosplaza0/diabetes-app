// Archivo: food_injections.dart
// Descripción: Pantalla que muestra y gestiona los registros de comidas e inyecciones del usuario.
// Permite navegar entre diferentes fechas para ver y editar los registros.

import 'package:flutter/material.dart';
import '../layout/main_layout.dart';
import '../historial/widgets/date_navigator_widget.dart'; // Widget para navegación de fechas
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart'; // Necesario para inicializar el formato de fecha

/// Widget que representa la pantalla de comidas e inyecciones de la aplicación.
/// Permite al usuario ver y gestionar los registros de comidas e inyecciones organizados por fecha.
class FoodInjectionsScreen extends StatefulWidget {
  const FoodInjectionsScreen({super.key});

  @override
  State<FoodInjectionsScreen> createState() => _FoodInjectionsScreenState();
}

/// Estado interno para la pantalla de comidas e inyecciones.
/// Gestiona la fecha seleccionada y la inicialización del formato de fecha.
class _FoodInjectionsScreenState extends State<FoodInjectionsScreen> {
  /// Fecha actualmente seleccionada para mostrar registros
  late DateTime _selectedDate;

  /// Indica si la inicialización del formato de fecha ha sido completada
  bool _isDateFormattingInitialized = false;

  @override
  /// Inicializa el estado del widget.
  /// Configura la fecha seleccionada al día actual y inicializa el formato de fecha español.
  void initState() {
    super.initState();
    // Inicializa _selectedDate al día de hoy sin componente de tiempo para consistencia
    DateTime now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);

    // Inicializa el formato de fecha para español
    initializeDateFormatting('es_ES', null).then((_) {
      if (mounted) {
        setState(() {
          _isDateFormattingInitialized = true;
        });
      }
    }).catchError((error) {
      // print("Error al inicializar el formato de fecha: $error");
      if (mounted) {
        setState(() {
          // Maneja el error o marca como inicializado para evitar carga infinita
          _isDateFormattingInitialized = true;
        });
      }
    });
  }

  /// Maneja el cambio de fecha desde el navegador de fechas.
  /// Actualiza la fecha seleccionada y podría desencadenar la carga de datos para esa fecha.
  /// 
  /// @param newDate La nueva fecha seleccionada por el usuario
  void _onDateChangedByNavigator(DateTime newDate) {
    setState(() {
      // La nueva fecha del navegador debe normalizarse (tiempo a medianoche)
      _selectedDate = DateTime(newDate.year, newDate.month, newDate.day);
      // Típicamente aquí se desencadenaría la carga de datos para la nueva fecha, por ejemplo:
      // _cargarRegistrosParaFecha(_selectedDate);
    });
  }

  @override
  /// Construye la interfaz de usuario de la pantalla de comidas e inyecciones.
  /// Muestra un indicador de carga mientras se inicializa el formato de fecha,
  /// y luego muestra el navegador de fechas y el contenido de comidas e inyecciones.
  Widget build(BuildContext context) {
    if (!_isDateFormattingInitialized) {
      // Muestra un indicador de carga hasta que el formato de fecha esté listo
      return MainLayout(
        title: 'Comida / Inyecciones',
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return MainLayout(
      title: 'Comida / Inyecciones',
      body: Column(
        children: [
          // Widget de selección y navegación de fechas
          DateNavigatorWidget(
            initialDate: _selectedDate,
            onDateChanged: _onDateChangedByNavigator,
            firstDate: DateTime(2000),      // Fecha mínima seleccionable
            lastDate: DateTime.now(),       // Fecha máxima seleccionable (hoy)
          ),

          // Contenedor para los registros de comidas e inyecciones (usa _selectedDate del estado)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
              ),
              child: Center(
                child: Text(
                  // Ejemplo de uso de la fecha seleccionada
                    'Aquí irán los registros del día: ${DateFormat('dd/MM/yyyy', 'es_ES').format(_selectedDate)}',
                    style: const TextStyle(fontSize: 16)
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
