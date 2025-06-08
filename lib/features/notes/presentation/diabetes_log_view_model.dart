// Archivo: lib/features/notes/presentation/diabetes_log_view_model.dart
// Descripción: ViewModel para la pantalla de registro de notas de diabetes (DiabetesLogScreen).
// Gestiona el estado y la lógica para crear nuevos registros de comidas o nocturnos,
// así como para editar los existentes. Interactúa con LogRepository para guardar y
// cargar logs, y con DiabetesCalculatorService para actualizar los cálculos diarios
// después de guardar un log. También puede interactuar con SupabaseLogSyncService
// para la sincronización de datos de cálculo diario.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:flutter/material.dart'; // Framework principal de Flutter para UI.
import 'package:hive/hive.dart'; // Para Box<DailyCalculationData> y operaciones con Hive.
import 'package:intl/intl.dart'; // Para formateo de fechas (ej. para claves de DailyCalculationData).
import 'package:uuid/uuid.dart'; // Para generar identificadores únicos para nuevos logs.
import 'package:shared_preferences/shared_preferences.dart'; // Para leer la preferencia de guardado en la nube.

// Importaciones de archivos del proyecto
import 'package:DiabetiApp/data/models/logs/logs.dart'; // Modelos MealLog y OvernightLog.
import 'package:DiabetiApp/data/models/calculations/daily_calculation_data.dart'; // Modelo DailyCalculationData.
import 'package:DiabetiApp/data/repositories/log_repository.dart'; // Repositorio para operaciones con logs.
import 'package:DiabetiApp/core/services/diabetes_calculator_service.dart'; // Servicio para cálculos de diabetes.
import 'package:DiabetiApp/core/services/supabase_log_sync_service.dart'; // Servicio para sincronizar con Supabase.
import 'package:DiabetiApp/main.dart' show supabase; // Para cliente Supabase y nombre de caja.

/// Enum LogType: Define los tipos de registros que se pueden crear o editar.
enum LogType {
  meal,      // Registro de comida.
  overnight, // Registro nocturno.
}

// Constante para la clave de SharedPreferences que indica si el guardado en la nube está habilitado.
// Idealmente, esta constante estaría centralizada si se usa en múltiples ViewModels.
const String cloudSavePreferenceKeyFromLogVM = 'saveToCloudEnabled';

/// DiabetesLogViewModel: Gestiona el estado y la lógica para DiabetesLogScreen.
///
/// Permite:
/// - Inicializar la pantalla para un nuevo log o para editar uno existente.
/// - Cambiar entre tipo de log (comida/noche) si es un nuevo log.
/// - Manejar la selección de fecha y hora para los logs.
/// - Validar y guardar los datos del formulario de log.
/// - Interactuar con los servicios y repositorios para la persistencia y cálculo de datos.
class DiabetesLogViewModel extends ChangeNotifier {
  final LogRepository _logRepository;
  final DiabetesCalculatorService _calculatorService;
  final SupabaseLogSyncService _supabaseLogSyncService; // Para sincronizar DailyCalculationData.
  final Box<DailyCalculationData> _dailyCalculationsBox; // Para acceder a DailyCalculationData al sincronizar.

  /// Constructor: Inicializa los servicios y repositorios necesarios.
  /// Establece valores por defecto para la fecha y hora de los logs.
  DiabetesLogViewModel({
    required LogRepository logRepository,
    required DiabetesCalculatorService calculatorService,
    required SupabaseLogSyncService supabaseLogSyncService,
    required Box<DailyCalculationData> dailyCalculationsBox,
  })  : _logRepository = logRepository,
        _calculatorService = calculatorService,
        _supabaseLogSyncService = supabaseLogSyncService,
        _dailyCalculationsBox = dailyCalculationsBox {
    // Inicializa la fecha del log a la medianoche del día actual.
    _selectedLogDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    // Inicializa la hora de inicio de comida a la hora actual.
    _selectedMealStartTime = TimeOfDay.fromDateTime(DateTime.now());
    // Inicializa la hora de acostarse a la hora actual.
    _selectedBedTime = TimeOfDay.fromDateTime(DateTime.now());
  }

  final Uuid _uuid = const Uuid(); // Generador de IDs únicos para nuevos logs.

  // --- Estado de la UI ---
  LogType _currentLogType = LogType.meal; // Tipo de log actual (comida por defecto).
  LogType get currentLogType => _currentLogType;

  bool _isEditMode = false; // Indica si la pantalla está en modo edición.
  bool get isEditMode => _isEditMode;

  String? _editingLogKey; // Clave de Hive del log que se está editando.

  late DateTime _selectedLogDate; // Fecha seleccionada para el log.
  DateTime get selectedLogDate => _selectedLogDate;

  late TimeOfDay _selectedMealStartTime; // Hora de inicio seleccionada para el log de comida.
  TimeOfDay get selectedMealStartTime => _selectedMealStartTime;

  late TimeOfDay _selectedBedTime; // Hora de acostarse seleccionada para el log nocturno.
  TimeOfDay get selectedBedTime => _selectedBedTime;

  bool _isSaving = false; // Indica si se está guardando un log.
  bool get isSaving => _isSaving;

  bool _initialized = false; // Flag para controlar la inicialización única.

  // --- Controladores de Texto para los formularios ---
  // Controladores para el formulario de MealLog
  final TextEditingController initialBloodSugarController = TextEditingController();
  final TextEditingController carbohydratesController = TextEditingController();
  final TextEditingController fastInsulinController = TextEditingController();
  final TextEditingController finalBloodSugarController = TextEditingController();

  // Controladores para el formulario de OvernightLog
  final TextEditingController beforeSleepBloodSugarController = TextEditingController();
  final TextEditingController slowInsulinController = TextEditingController();
  final TextEditingController afterWakeUpBloodSugarController = TextEditingController();

  // --- Métodos de Inicialización y Carga ---

  /// initialize: Prepara el ViewModel para mostrar un nuevo log o editar uno existente.
  ///
  /// Si se proporcionan `logKey` y `logTypeString`, entra en modo edición y carga los datos del log.
  /// Si no, configura la pantalla para un nuevo log, reseteando los formularios.
  /// Utiliza un flag `_initialized` para evitar reinicializaciones innecesarias si se llama múltiples veces
  /// con los mismos parámetros (ej. por reconstrucciones de la UI).
  ///
  /// @param logKey La clave de Hive del log a editar (si aplica).
  /// @param logTypeString El tipo de log como string ("meal" o "overnight") (si aplica).
  Future<void> initialize({String? logKey, String? logTypeString}) async {
    // Evita la reinicialización si ya se inicializó para el mismo log en modo edición.
    if (_initialized && _isEditMode && logKey == _editingLogKey) return;

    _isEditMode = (logKey != null && logTypeString != null);
    _editingLogKey = logKey;

    if (_isEditMode) {
      _currentLogType = logTypeString == 'meal' ? LogType.meal : LogType.overnight;
      await _loadLogForEditing(); // Carga los datos del log a editar.
    } else {
      // Configuración para un nuevo log.
      _currentLogType = LogType.meal; // Por defecto, o podría guardarse la última preferencia.
      final now = DateTime.now();
      _selectedLogDate = DateTime(now.year, now.month, now.day);
      _selectedMealStartTime = TimeOfDay.fromDateTime(now);
      _selectedBedTime = TimeOfDay.fromDateTime(now.subtract(const Duration(hours: 1)));
      _clearAllForms(); // Limpia los campos del formulario.
    }
    _initialized = true; // Marca como inicializado.
    notifyListeners(); // Notifica a la UI para que se actualice.
  }

  /// _loadLogForEditing: Carga los datos de un log existente en los controladores de formulario.
  ///
  /// Este método se llama cuando `initialize` determina que se está en modo edición.
  /// Obtiene el log del `_logRepository` usando `_editingLogKey` y `_currentLogType`.
  Future<void> _loadLogForEditing() async {
    if (!_isEditMode || _editingLogKey == null) return; // Asegura que estemos en modo edición con una clave válida.

    _setSaving(true); // Reutiliza _isSaving para indicar un estado de carga.
    dynamic logToEdit;
    if (_currentLogType == LogType.meal) {
      logToEdit = await _logRepository.getMealLog(_editingLogKey!);
    } else {
      logToEdit = await _logRepository.getOvernightLog(_editingLogKey!);
    }

    if (logToEdit == null) {
      debugPrint("DiabetesLogViewModel: Error - Nota no encontrada para editar con clave: $_editingLogKey.");
      // Aquí se podría establecer un mensaje de error para la UI.
      _setSaving(false);
      _isEditMode = false; // Salir del modo edición si el log no se encuentra.
      _editingLogKey = null;
      _clearAllForms(); // Limpiar formularios
      // Podría ser útil navegar hacia atrás o mostrar un diálogo.
      return;
    }

    // Popula los campos del formulario y el estado del ViewModel con los datos del log cargado.
    if (logToEdit is MealLog) {
      _selectedLogDate = DateTime(logToEdit.startTime.year, logToEdit.startTime.month, logToEdit.startTime.day);
      _selectedMealStartTime = TimeOfDay.fromDateTime(logToEdit.startTime);
      initialBloodSugarController.text = logToEdit.initialBloodSugar.toStringAsFixed(0);
      carbohydratesController.text = logToEdit.carbohydrates.toStringAsFixed(0);
      fastInsulinController.text = logToEdit.insulinUnits.toStringAsFixed(1);
      finalBloodSugarController.text = logToEdit.finalBloodSugar?.toStringAsFixed(0) ?? '';
    } else if (logToEdit is OvernightLog) {
      _selectedLogDate = DateTime(logToEdit.bedTime.year, logToEdit.bedTime.month, logToEdit.bedTime.day);
      _selectedBedTime = TimeOfDay.fromDateTime(logToEdit.bedTime);
      beforeSleepBloodSugarController.text = logToEdit.beforeSleepBloodSugar.toStringAsFixed(0);
      slowInsulinController.text = logToEdit.slowInsulinUnits.toStringAsFixed(1);
      afterWakeUpBloodSugarController.text = logToEdit.afterWakeUpBloodSugar?.toStringAsFixed(0) ?? '';
    }
    _setSaving(false); // Finaliza el estado de carga.
    // Si la carga es muy rápida, es necesario para asegurar que la UI se actualice con los valores de los controladores.
  }

  // --- Métodos de interacción con la UI ---

  /// updateLogType: Cambia el tipo de log actual (comida/noche) si no se está en modo edición.
  void updateLogType(LogType newType) {
    if (_currentLogType == newType || _isEditMode) return; // No permitir cambio si es el mismo tipo o en modo edición.
    _currentLogType = newType;
    notifyListeners();
  }

  /// selectDate: Muestra un selector de fecha y actualiza `_selectedLogDate`.
  Future<void> selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedLogDate,
      firstDate: DateTime(2000), // Límite inferior.
      lastDate: DateTime(2101), // Límite superior (futuro lejano).
    );
    if (picked != null && picked != _selectedLogDate) {
      _selectedLogDate = picked;
      notifyListeners();
    }
  }

  /// selectMealStartTime: Muestra un selector de hora y actualiza `_selectedMealStartTime`.
  Future<void> selectMealStartTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedMealStartTime,
    );
    if (picked != null && picked != _selectedMealStartTime) {
      _selectedMealStartTime = picked;
      notifyListeners();
    }
  }

  /// selectBedTime: Muestra un selector de hora y actualiza `_selectedBedTime`.
  Future<void> selectBedTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedBedTime,
    );
    if (picked != null && picked != _selectedBedTime) {
      _selectedBedTime = picked;
      notifyListeners();
    }
  }

  /// _setSaving: Método privado para actualizar el estado de guardado y notificar a los listeners.
  void _setSaving(bool saving) {
    _isSaving = saving;
    notifyListeners();
  }

  // --- Métodos de Guardado de Logs ---

  /// saveMealLog: Valida y guarda un registro de comida.
  ///
  /// @param formKey La GlobalKey del Form para validación.
  /// @return Un `Future<bool>` que indica si el guardado fue exitoso.
  Future<bool> saveMealLog(GlobalKey<FormState> formKey) async {
    // Valida el formulario. Si no es válido, no continuar.
    if (!(formKey.currentState?.validate() ?? false)) return false;
    _setSaving(true); // Inicia el estado de guardado.

    // Construye el objeto DateTime para la hora de inicio de la comida.
    final DateTime mealEventStartTime = DateTime(
      _selectedLogDate.year, _selectedLogDate.month, _selectedLogDate.day,
      _selectedMealStartTime.hour, _selectedMealStartTime.minute,
    );
    // Parsea los valores de los controladores.
    final double? initialBloodSugar = double.tryParse(initialBloodSugarController.text);
    final double? carbohydrates = double.tryParse(carbohydratesController.text);
    final double? fastInsulin = double.tryParse(fastInsulinController.text);

    // Comprobación básica de nulidad para campos obligatorios.
    if (initialBloodSugar == null || carbohydrates == null || fastInsulin == null) {
      _setSaving(false);
      // Exponer error a la UI (ej. a través de una propiedad de mensaje de error en el VM).
      return false;
    }
    // Parsea la glucemia final si se proporcionó.
    final double? finalBloodSugar = finalBloodSugarController.text.isNotEmpty
        ? double.tryParse(finalBloodSugarController.text) : null;
    // Establece la hora de finalización (ej. 3 horas después) solo si hay glucemia final.
    DateTime? mealEventEndTime = (finalBloodSugar != null && finalBloodSugarController.text.isNotEmpty)
        ? mealEventStartTime.add(const Duration(hours: 3)) : null;

    // Crea el objeto MealLog.
    MealLog mealLog = MealLog(
      startTime: mealEventStartTime,
      initialBloodSugar: initialBloodSugar, carbohydrates: carbohydrates, insulinUnits: fastInsulin,
      finalBloodSugar: finalBloodSugar, endTime: mealEventEndTime,
    );

    try {
      // Determina la clave de Hive: usa la existente si está en modo edición, o genera una nueva.
      String currentHiveKey = _isEditMode && _editingLogKey != null ? _editingLogKey! : _uuid.v4();
      // Guarda el log usando el repositorio. El repositorio se encargará de la sincronización con Supabase si está activada.
      await _logRepository.saveMealLog(mealLog, currentHiveKey);

      // Actualiza los cálculos diarios para la fecha del log.
      // Esto recalculará índices como el de corrección diario y promedios por período.
      final dateOfLog = DateTime(_selectedLogDate.year, _selectedLogDate.month, _selectedLogDate.day);
      await _calculatorService.updateCalculationsForDay(dateOfLog);
      final prefs = await SharedPreferences.getInstance();
      final bool cloudSaveEnabled = prefs.getBool(cloudSavePreferenceKeyFromLogVM) ?? false;
      final bool isLoggedIn = supabase.auth.currentUser != null;

      if (cloudSaveEnabled && isLoggedIn) {
        final dailyCalcKey = DateFormat('yyyy-MM-dd').format(dateOfLog);
        final DailyCalculationData? dailyCalcData = _dailyCalculationsBox.get(dailyCalcKey);
        if (dailyCalcData != null) {
          // Esta llamada sería redundante si CalculationDataRepository.saveDailyCalculation ya sincroniza.
          await _supabaseLogSyncService.syncDailyCalculation(dailyCalcData);
          debugPrint("DiabetesLogViewModel: DailyCalculationData para $dailyCalcKey sincronizado (posiblemente de forma redundante).");
        }
      }

      _clearMealForm(); // Limpia el formulario de comida.
      _setSaving(false); // Finaliza el estado de guardado.
      return true; // Guardado exitoso.
    } catch (e) {
      debugPrint('DiabetesLogViewModel: Error al guardar MealLog: $e');
      _setSaving(false);
      return false; // Guardado fallido.
    }
  }

  /// saveOvernightLog: Valida y guarda un registro nocturno.
  ///
  /// @param formKey La GlobalKey del Form para validación.
  /// @return Un `Future<bool>` que indica si el guardado fue exitoso.
  Future<bool> saveOvernightLog(GlobalKey<FormState> formKey) async {
    if (!(formKey.currentState?.validate() ?? false)) {
      return false;
    }
    _setSaving(true);

    final DateTime bedEventTime = DateTime(
      _selectedLogDate.year, _selectedLogDate.month, _selectedLogDate.day,
      _selectedBedTime.hour, _selectedBedTime.minute,
    );
    final double? beforeSleepBloodSugar = double.tryParse(beforeSleepBloodSugarController.text);
    final double? slowInsulinUnits = double.tryParse(slowInsulinController.text);

    if (beforeSleepBloodSugar == null || slowInsulinUnits == null) {
      _setSaving(false);
      return false;
    }
    final double? afterWakeUpBloodSugar = afterWakeUpBloodSugarController.text.isNotEmpty
        ? double.tryParse(afterWakeUpBloodSugarController.text) : null;

    final overnightLog = OvernightLog(
      bedTime: bedEventTime, beforeSleepBloodSugar: beforeSleepBloodSugar,
      slowInsulinUnits: slowInsulinUnits, afterWakeUpBloodSugar: afterWakeUpBloodSugar,
    );

    try {
      String currentHiveKey = _isEditMode && _editingLogKey != null ? _editingLogKey! : _uuid.v4();
      await _logRepository.saveOvernightLog(overnightLog, currentHiveKey);
      // La sincronización con Supabase ocurre dentro del repositorio si está habilitada.
      // No se necesitan cálculos adicionales de `DiabetesCalculatorService` para OvernightLog en este momento.

      _clearOvernightForm(); // Limpia el formulario nocturno.
      _setSaving(false);
      return true; // Éxito.
    } catch (e) {
      debugPrint('DiabetesLogViewModel: Error al guardar OvernightLog: $e');
      _setSaving(false);
      return false; // Fracaso.
    }
  }


  // --- Métodos de Limpieza de Formularios ---
  void _clearMealForm() {
    initialBloodSugarController.clear();
    carbohydratesController.clear();
    fastInsulinController.clear();
    finalBloodSugarController.clear();
    // Si no se está editando, resetea la hora de inicio de comida a la actual.
    if (!_isEditMode) {
      _selectedMealStartTime = TimeOfDay.fromDateTime(DateTime.now());
      // No se notifica aquí, ya que la UI se actualizará después de un guardado exitoso
      // o al cambiar de modo si es un nuevo log.
    }
  }

  void _clearOvernightForm() {
    beforeSleepBloodSugarController.clear();
    slowInsulinController.clear();
    afterWakeUpBloodSugarController.clear();
    if (!_isEditMode) {
      _selectedBedTime = TimeOfDay.fromDateTime(DateTime.now().subtract(const Duration(hours: 1)));
    }
  }

  /// _clearAllForms: Limpia todos los controladores de texto de ambos formularios.
  void _clearAllForms() {
    _clearMealForm();
    _clearOvernightForm();
  }


  @override
  /// dispose: Libera los recursos de los TextEditingController cuando el ViewModel ya no se necesita.
  void dispose() {
    initialBloodSugarController.dispose();
    carbohydratesController.dispose();
    fastInsulinController.dispose();
    finalBloodSugarController.dispose();
    beforeSleepBloodSugarController.dispose();
    slowInsulinController.dispose();
    afterWakeUpBloodSugarController.dispose();
    super.dispose();
  }
}