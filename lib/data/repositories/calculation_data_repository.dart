// Archivo: lib/data/repositories/calculation_data_repository.dart
// Descripción: Define la interfaz (contrato) para el repositorio de datos de cálculo.
// Esta clase abstracta especifica los métodos que cualquier implementación concreta
// del repositorio de datos de cálculo debe proporcionar. Sirve como una abstracción
// para el acceso y la manipulación de los objetos DailyCalculationData.

// Importaciones de archivos del proyecto
import 'package:DiabetiApp/data/models/calculations/daily_calculation_data.dart'; // Modelo DailyCalculationData.

/// CalculationDataRepository: Clase abstracta que define el contrato para el repositorio de datos de cálculo.
///
/// Un repositorio es responsable de mediar entre el dominio de la aplicación y las
/// fuentes de datos (ej. base de datos local, API de red). Esta interfaz asegura
/// que cualquier parte de la aplicación que necesite interactuar con los datos de cálculo
/// lo haga de una manera consistente, independientemente de la implementación subyacente.
abstract class CalculationDataRepository {
  /// getDailyCalculation: Obtiene los datos de cálculo para una fecha específica.
  ///
  /// @param dateKey La fecha para la cual se solicitan los datos, formateada como 'yyyy-MM-dd'.
  /// @return Un `Future` que resuelve a un objeto `DailyCalculationData?` (puede ser nulo si no existen datos para esa fecha).
  Future<DailyCalculationData?> getDailyCalculation(String dateKey);

  /// saveDailyCalculation: Guarda o actualiza los datos de cálculo para una fecha específica.
  ///
  /// @param dateKey La fecha para la cual se guardan los datos, formateada como 'yyyy-MM-dd'.
  /// @param data El objeto `DailyCalculationData` que se va a guardar.
  /// @return Un `Future<void>` que se completa cuando la operación de guardado ha terminado.
  Future<void> saveDailyCalculation(String dateKey, DailyCalculationData data);

  /// getDailyCalculationsInDateRange: Obtiene una lista de datos de cálculo para un rango de fechas.
  ///
  /// @param startDate La fecha de inicio del rango (inclusiva).
  /// @param endDate La fecha de fin del rango (inclusiva).
  /// @return Un `Future` que resuelve a una `List<DailyCalculationData>` que contiene los datos del rango especificado.
  Future<List<DailyCalculationData>> getDailyCalculationsInDateRange(DateTime startDate, DateTime endDate);

// Se podrían añadir más métodos si fueran necesarios para la gestión de DailyCalculationData,
// como por ejemplo:
// Future<void> deleteAllDailyCalculations();
// Future<void> deleteDailyCalculation(String dateKey);
}