// Archivo: lib/data/repositories/log_repository.dart
// Descripción: Define la interfaz (contrato) para el repositorio de logs de diabetes.
// Esta clase abstracta especifica los métodos que cualquier implementación concreta
// del repositorio de logs debe proporcionar. Sirve como una abstracción para
// el acceso y la manipulación de los objetos MealLog y OvernightLog.

// Importaciones de archivos del proyecto
import 'package:diabetes_2/data/models/logs/logs.dart'; // Modelos MealLog y OvernightLog.

/// LogRepository: Clase abstracta que define el contrato para el repositorio de logs.
///
/// Un repositorio es responsable de mediar entre el dominio de la aplicación y las
/// fuentes de datos (ej. base de datos local Hive, API de red para Supabase).
/// Esta interfaz asegura que cualquier parte de la aplicación que necesite interactuar
/// con los logs (MealLog, OvernightLog) lo haga de una manera consistente,
/// independientemente de la implementación subyacente (ej. LogRepositoryImpl).
abstract class LogRepository {
  // --- Operaciones para MealLog (Registros de Comida) ---

  /// saveMealLog: Guarda o actualiza un registro de comida.
  ///
  /// @param log El objeto `MealLog` a guardar.
  /// @param hiveKey La clave única (generalmente un UUID String) para almacenar el log en Hive.
  /// @return Un `Future<void>` que se completa cuando la operación de guardado ha terminado.
  Future<void> saveMealLog(MealLog log, String hiveKey);

  /// getMealLog: Obtiene un registro de comida específico por su clave de Hive.
  ///
  /// @param hiveKey La clave del `MealLog` a recuperar.
  /// @return Un `Future` que resuelve a un objeto `MealLog?` (puede ser nulo si no se encuentra).
  Future<MealLog?> getMealLog(String hiveKey);

  /// getMealLogsForDate: Obtiene todos los registros de comida para una fecha específica.
  ///
  /// @param date La fecha para la cual se solicitan los registros.
  /// @return Un `Future` que resuelve a una `List<MealLog>`.
  Future<List<MealLog>> getMealLogsForDate(DateTime date);

  /// getMealLogsInDateRange: Obtiene todos los registros de comida dentro de un rango de fechas.
  ///
  /// @param startDate La fecha de inicio del rango (inclusiva).
  /// @param endDate La fecha de fin del rango (inclusiva).
  /// @return Un `Future` que resuelve a una `List<MealLog>`.
  Future<List<MealLog>> getMealLogsInDateRange(DateTime startDate, DateTime endDate);

  /// getAllMealLogsMappedByKey: Obtiene todos los registros de comida almacenados, mapeados por su clave de Hive.
  /// Útil para operaciones de sincronización o migración de datos.
  ///
  /// @return Un `Future` que resuelve a un `Map<String, MealLog>`, donde la clave es la `hiveKey`.
  Future<Map<String, MealLog>> getAllMealLogsMappedByKey();

  /// deleteMealLog: Elimina un registro de comida específico por su clave de Hive.
  /// La implementación decidirá si esto también implica un borrado en la nube.
  ///
  /// @param hiveKey La clave del `MealLog` a eliminar.
  /// @return Un `Future<void>` que se completa cuando la operación de borrado ha terminado.
  Future<void> deleteMealLog(String hiveKey);

  /// clearAllLocalMealLogs: Elimina todos los registros de comida almacenados localmente en Hive.
  /// Esta operación generalmente no afecta a los datos en la nube a menos que la implementación lo especifique.
  ///
  /// @return Un `Future<void>` que se completa cuando todos los logs locales de comida han sido borrados.
  Future<void> clearAllLocalMealLogs();

  // --- Operaciones para OvernightLog (Registros Nocturnos) ---

  /// saveOvernightLog: Guarda o actualiza un registro nocturno.
  ///
  /// @param log El objeto `OvernightLog` a guardar.
  /// @param hiveKey La clave única para almacenar el log en Hive.
  /// @return Un `Future<void>` que se completa cuando la operación de guardado ha terminado.
  Future<void> saveOvernightLog(OvernightLog log, String hiveKey);

  /// getOvernightLog: Obtiene un registro nocturno específico por su clave de Hive.
  ///
  /// @param hiveKey La clave del `OvernightLog` a recuperar.
  /// @return Un `Future` que resuelve a un objeto `OvernightLog?` (puede ser nulo si no se encuentra).
  Future<OvernightLog?> getOvernightLog(String hiveKey);

  /// getOvernightLogsForDate: Obtiene todos los registros nocturnos para una fecha específica.
  /// (Generalmente basado en `bedTime`).
  ///
  /// @param date La fecha para la cual se solicitan los registros.
  /// @return Un `Future` que resuelve a una `List<OvernightLog>`.
  Future<List<OvernightLog>> getOvernightLogsForDate(DateTime date);

  /// getOvernightLogsInDateRange: Obtiene todos los registros nocturnos dentro de un rango de fechas.
  ///
  /// @param startDate La fecha de inicio del rango (inclusiva).
  /// @param endDate La fecha de fin del rango (inclusiva).
  /// @return Un `Future` que resuelve a una `List<OvernightLog>`.
  Future<List<OvernightLog>> getOvernightLogsInDateRange(DateTime startDate, DateTime endDate);

  /// getAllOvernightLogsMappedByKey: Obtiene todos los registros nocturnos almacenados, mapeados por su clave de Hive.
  ///
  /// @return Un `Future` que resuelve a un `Map<String, OvernightLog>`.
  Future<Map<String, OvernightLog>> getAllOvernightLogsMappedByKey();

  /// deleteOvernightLog: Elimina un registro nocturno específico por su clave de Hive.
  ///
  /// @param hiveKey La clave del `OvernightLog` a eliminar.
  /// @return Un `Future<void>` que se completa cuando la operación de borrado ha terminado.
  Future<void> deleteOvernightLog(String hiveKey);

  /// clearAllLocalOvernightLogs: Elimina todos los registros nocturnos almacenados localmente en Hive.
  ///
  /// @return Un `Future<void>` que se completa cuando todos los logs locales nocturnos han sido borrados.
  Future<void> clearAllLocalOvernightLogs();

  // --- Operaciones Combinadas (MealLog y OvernightLog) ---

  /// getRecentLogs: Obtiene una lista de logs recientes (comidas y nocturnos) dentro de una duración específica desde ahora.
  /// Los logs se devuelven como una lista de Mapas, donde cada mapa contiene el log, su tipo, clave y hora.
  /// La lista resultante está ordenada por hora, los más recientes primero.
  ///
  /// @param duration La duración hacia atrás desde el momento actual para buscar logs (ej. `Duration(hours: 24)`).
  /// @return Un `Future` que resuelve a una `List<Map<String, dynamic>>`.
  Future<List<Map<String, dynamic>>> getRecentLogs(Duration duration);

  /// getFilteredAndSortedLogsForDate: Obtiene una lista combinada de todos los logs (comidas y nocturnos)
  /// para una fecha específica, ordenados cronológicamente por su hora de inicio/hora de dormir.
  ///
  /// @param date La fecha para la cual se filtran los logs.
  /// @return Un `Future` que resuelve a una `List<dynamic>` (conteniendo objetos MealLog o OvernightLog).
  Future<List<dynamic>> getFilteredAndSortedLogsForDate(DateTime date);
}