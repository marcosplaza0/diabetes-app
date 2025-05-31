// lib/features/notes/presentation/diabetes_log_view_model.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:diabetes_2/data/models/logs/logs.dart';
import 'package:diabetes_2/data/models/calculations/daily_calculation_data.dart';
import 'package:diabetes_2/data/repositories/log_repository.dart';
import 'package:diabetes_2/core/services/diabetes_calculator_service.dart';
import 'package:diabetes_2/core/services/supabase_log_sync_service.dart'; // Para DailyCalcData sync
import 'package:diabetes_2/main.dart' show supabase, dailyCalculationsBoxName; // Para auth y nombre de caja
import 'package:shared_preferences/shared_preferences.dart'; // Para cloudSavePreferenceKey

// Mover el enum LogType aquí o a un archivo de modelos de esta feature si es más específico
enum LogType { meal, overnight }

const String cloudSavePreferenceKeyFromLogVM = 'saveToCloudEnabled'; // Reusar o centralizar esta constante

class DiabetesLogViewModel extends ChangeNotifier {
  final LogRepository _logRepository;
  final DiabetesCalculatorService _calculatorService;
  final SupabaseLogSyncService _supabaseLogSyncService; // Para sincronizar DailyCalculationData
  final Box<DailyCalculationData> _dailyCalculationsBox; // Para obtener DailyCalculationData a sincronizar

  DiabetesLogViewModel({
    required LogRepository logRepository,
    required DiabetesCalculatorService calculatorService,
    required SupabaseLogSyncService supabaseLogSyncService,
    required Box<DailyCalculationData> dailyCalculationsBox,
  })  : _logRepository = logRepository,
        _calculatorService = calculatorService,
        _supabaseLogSyncService = supabaseLogSyncService,
        _dailyCalculationsBox = dailyCalculationsBox {
    // Inicializar valores por defecto
    _selectedLogDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    _selectedMealStartTime = TimeOfDay.fromDateTime(DateTime.now());
    _selectedBedTime = TimeOfDay.fromDateTime(DateTime.now().subtract(const Duration(hours: 1))); // Un poco antes por defecto
  }

  final Uuid _uuid = const Uuid();

  // --- Estado de la UI ---
  LogType _currentLogType = LogType.meal;
  LogType get currentLogType => _currentLogType;

  bool _isEditMode = false;
  bool get isEditMode => _isEditMode;

  String? _editingLogKey; // Clave del log que se está editando

  DateTime _selectedLogDate = DateTime.now();
  DateTime get selectedLogDate => _selectedLogDate;

  TimeOfDay _selectedMealStartTime = TimeOfDay.now();
  TimeOfDay get selectedMealStartTime => _selectedMealStartTime;

  TimeOfDay _selectedBedTime = TimeOfDay.now();
  TimeOfDay get selectedBedTime => _selectedBedTime;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  bool _initialized = false; // Para controlar la inicialización única

  // --- Controladores de Texto ---
  final TextEditingController initialBloodSugarController = TextEditingController();
  final TextEditingController carbohydratesController = TextEditingController();
  final TextEditingController fastInsulinController = TextEditingController();
  final TextEditingController finalBloodSugarController = TextEditingController();

  final TextEditingController beforeSleepBloodSugarController = TextEditingController();
  final TextEditingController slowInsulinController = TextEditingController();
  final TextEditingController afterWakeUpBloodSugarController = TextEditingController();

  // --- Métodos de Inicialización y Carga ---
  Future<void> initialize({String? logKey, String? logTypeString}) async {
    if (_initialized && logKey == _editingLogKey) return; // Evitar reinicialización innecesaria

    _isEditMode = (logKey != null && logTypeString != null);
    _editingLogKey = logKey;

    if (_isEditMode) {
      _currentLogType = logTypeString == 'meal' ? LogType.meal : LogType.overnight;
      await _loadLogForEditing();
    } else {
      // Resetea a valores por defecto para un nuevo log
      _currentLogType = LogType.meal; // O el último tipo usado, si se guarda preferencia
      final now = DateTime.now();
      _selectedLogDate = DateTime(now.year, now.month, now.day);
      _selectedMealStartTime = TimeOfDay.fromDateTime(now);
      _selectedBedTime = TimeOfDay.fromDateTime(now.subtract(const Duration(hours: 1)));
      _clearAllForms();
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> _loadLogForEditing() async {
    if (!_isEditMode || _editingLogKey == null) return;

    _setSaving(true); // Usar _isSaving para indicar carga
    dynamic logToEdit;
    if (_currentLogType == LogType.meal) {
      logToEdit = await _logRepository.getMealLog(_editingLogKey!);
    } else {
      logToEdit = await _logRepository.getOvernightLog(_editingLogKey!);
    }

    if (logToEdit == null) {
      // Manejar error, quizás con un mensaje en la UI a través de una propiedad en el VM
      debugPrint("DiabetesLogViewModel: Error - Nota no encontrada para editar.");
      _setSaving(false);
      return;
    }

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
    _setSaving(false);
    notifyListeners(); // Notificar después de cargar y antes de _setSaving(false) si es necesario
  }

  // --- Métodos de UI ---
  void updateLogType(LogType newType) {
    if (_currentLogType == newType) return;
    _currentLogType = newType;
    notifyListeners();
  }

  Future<void> selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedLogDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedLogDate) {
      _selectedLogDate = picked;
      notifyListeners();
    }
  }

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

  void _setSaving(bool saving) {
    _isSaving = saving;
    notifyListeners();
  }

  // --- Métodos de Guardado ---
  Future<bool> saveMealLog(GlobalKey<FormState> formKey) async {
    if (!(formKey.currentState?.validate() ?? false)) {
      // Podrías exponer un mensaje de error a la UI a través de una propiedad del VM
      return false;
    }
    _setSaving(true);

    final DateTime mealEventStartTime = DateTime(
      _selectedLogDate.year, _selectedLogDate.month, _selectedLogDate.day,
      _selectedMealStartTime.hour, _selectedMealStartTime.minute,
    );
    final double? initialBloodSugar = double.tryParse(initialBloodSugarController.text);
    final double? carbohydrates = double.tryParse(carbohydratesController.text);
    final double? fastInsulin = double.tryParse(fastInsulinController.text);

    if (initialBloodSugar == null || carbohydrates == null || fastInsulin == null) {
      _setSaving(false);
      // Exponer error
      return false;
    }
    final double? finalBloodSugar = finalBloodSugarController.text.isNotEmpty
        ? double.tryParse(finalBloodSugarController.text) : null;
    DateTime? mealEventEndTime = (finalBloodSugar != null && finalBloodSugarController.text.isNotEmpty)
        ? mealEventStartTime.add(const Duration(hours: 3)) : null;

    MealLog mealLog = MealLog(
      startTime: mealEventStartTime,
      initialBloodSugar: initialBloodSugar, carbohydrates: carbohydrates, insulinUnits: fastInsulin,
      finalBloodSugar: finalBloodSugar, endTime: mealEventEndTime,
    );

    try {
      String currentHiveKey = _isEditMode ? _editingLogKey! : _uuid.v4();
      await _logRepository.saveMealLog(mealLog, currentHiveKey);

      final dateOfLog = DateTime(_selectedLogDate.year, _selectedLogDate.month, _selectedLogDate.day);
      await _calculatorService.updateCalculationsForDay(dateOfLog);
      // La sincronización del MealLog actualizado y DailyCalculationData ocurre dentro de los repositorios
      // si _calculatorService usa los repositorios para guardar.

      // Sincronizar DailyCalculationData si es necesario (si _calculatorService no lo hizo via repo)
      // Esta parte es redundante si DiabetesCalculatorService usa CalculationDataRepository para guardar,
      // ya que el repositorio se encargaría de la sincronización.
      final prefs = await SharedPreferences.getInstance();
      final bool cloudSaveEnabled = prefs.getBool(cloudSavePreferenceKeyFromLogVM) ?? false;
      final bool isLoggedIn = supabase.auth.currentUser != null;

      if (cloudSaveEnabled && isLoggedIn) {
        final dailyCalcKey = DateFormat('yyyy-MM-dd').format(dateOfLog);
        final DailyCalculationData? dailyCalcData = _dailyCalculationsBox.get(dailyCalcKey);
        if (dailyCalcData != null) {
          // Esta llamada podría ser redundante si CalculationDataRepository ya lo hizo.
          // Es más limpio si _calculatorService se encarga de guardar DailyCalculationData
          // a través de CalculationDataRepository, y este último sincroniza.
          await _supabaseLogSyncService.syncDailyCalculation(dailyCalcData);
          debugPrint("DiabetesLogViewModel: DailyCalculationData para $dailyCalcKey sincronizado (posiblemente redundante).");
        }
      }

      _clearMealForm();
      _setSaving(false);
      return true; // Éxito
    } catch (e) {
      debugPrint('DiabetesLogViewModel: Error al guardar MealLog: $e');
      _setSaving(false);
      return false; // Fracaso
    }
  }

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
      String currentHiveKey = _isEditMode ? _editingLogKey! : _uuid.v4();
      await _logRepository.saveOvernightLog(overnightLog, currentHiveKey);
      // La sincronización ocurre dentro del repositorio.
      _clearOvernightForm();
      _setSaving(false);
      return true; // Éxito
    } catch (e) {
      debugPrint('DiabetesLogViewModel: Error al guardar OvernightLog: $e');
      _setSaving(false);
      return false; // Fracaso
    }
  }


  // --- Métodos de Limpieza ---
  void _clearMealForm() {
    initialBloodSugarController.clear();
    carbohydratesController.clear();
    fastInsulinController.clear();
    finalBloodSugarController.clear();
    if (!_isEditMode) {
      _selectedMealStartTime = TimeOfDay.fromDateTime(DateTime.now());
      // No notificamos aquí, se hará después de guardar si es exitoso
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

  void _clearAllForms() {
    _clearMealForm();
    _clearOvernightForm();
  }


  @override
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