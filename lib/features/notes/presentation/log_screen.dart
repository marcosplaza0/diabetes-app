// lib/features/notes/presentation/log_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:diabetes_2/data/models/logs/logs.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:diabetes_2/main.dart' show supabase, dailyCalculationsBoxName;
import 'package:diabetes_2/data/models/calculations/daily_calculation_data.dart';
import 'package:diabetes_2/core/services/diabetes_calculator_service.dart';
import 'package:diabetes_2/data/repositories/log_repository.dart'; // Importa el repositorio
import 'package:diabetes_2/core/services/supabase_log_sync_service.dart'; // Para sincronizar DailyCalculationData
import 'package:shared_preferences/shared_preferences.dart'; // Para verificar cloudSaveEnabled

// Nombres de las cajas de Hive y clave de SharedPreferences
// (Estas constantes podrían moverse a un archivo central si se usan en muchos lugares)
// const String mealLogBoxNameFromScreen = 'meal_logs'; // Ya no es necesario aquí
// const String overnightLogBoxNameFromScreen = 'overnight_logs'; // Ya no es necesario aquí
const String cloudSavePreferenceKeyFromLogScreen = 'saveToCloudEnabled'; // Usado para DailyCalcData sync

enum LogType { meal, overnight }

const double kDefaultPadding = 16.0;
const double kVerticalSpacerSmall = 8.0;
const double kVerticalSpacerMedium = 16.0;
const double kVerticalSpacerLarge = 24.0;
const double kBorderRadius = 8.0;
const double kToggleMinHeight = 40.0;
const double kButtonVerticalPadding = 12.0;
const double kButtonFontSize = 16.0;

class DiabetesLogScreen extends StatefulWidget {
  final String? logKey;
  final String? logTypeString;

  const DiabetesLogScreen({
    super.key,
    this.logKey,
    this.logTypeString,
  });

  @override
  State<StatefulWidget> createState() => _DiabetesLogScreenState();
}

class _DiabetesLogScreenState extends State<DiabetesLogScreen> {
  LogType _currentLogType = LogType.meal;
  bool _isEditMode = false;

  DateTime _selectedLogDate = DateTime.now();
  TimeOfDay _selectedMealStartTime = TimeOfDay.now();
  TimeOfDay _selectedBedTime = TimeOfDay.now();

  final _mealFormKey = GlobalKey<FormState>();
  final _initialBloodSugarController = TextEditingController();
  final _carbohydratesController = TextEditingController();
  final _fastInsulinController = TextEditingController();
  final _finalBloodSugarController = TextEditingController();

  final _overnightFormKey = GlobalKey<FormState>();
  final _beforeSleepBloodSugarController = TextEditingController();
  final _slowInsulinController = TextEditingController();
  final _afterWakeUpBloodSugarController = TextEditingController();

  late Box<DailyCalculationData> _dailyCalculationsBox;
  late LogRepository _logRepository;
  late SupabaseLogSyncService _supabaseLogSyncService; // Para DailyCalculationData sync

  final Uuid _uuid = const Uuid();
  // DiabetesCalculatorService se instanciará donde se necesite, o se puede proveer si es más complejo.
  // Por ahora, lo instanciamos directamente. Si se refactoriza para no depender de cajas, mejor.
  // De hecho, DiabetesCalculatorService SÍ necesitará ser refactorizado para usar LogRepository.
  // Para este ejemplo, asumiremos que aún no lo está, pero lo ideal es que SÍ lo esté.
  // Si DiabetesCalculatorService es refactorizado, podría ser inyectado también.
  late DiabetesCalculatorService _calculatorService;


  @override
  void initState() {
    super.initState();
    _logRepository = Provider.of<LogRepository>(context, listen: false);
    _supabaseLogSyncService = Provider.of<SupabaseLogSyncService>(context, listen: false);
    _dailyCalculationsBox = Hive.box<DailyCalculationData>(dailyCalculationsBoxName);

    // Idealmente, DiabetesCalculatorService también se obtendría de Provider si se refactoriza
    // para no depender directamente de las cajas de Hive.
    // Si DiabetesCalculatorService se refactoriza, se le pasaría _logRepository.
    _calculatorService = Provider.of<DiabetesCalculatorService>(context, listen: false);
    // Si YA USA repo: _calculatorService = DiabetesCalculatorService(logRepository: _logRepository);


    if (widget.logKey != null && widget.logTypeString != null) {
      _isEditMode = true;
      _currentLogType = widget.logTypeString == 'meal' ? LogType.meal : LogType.overnight;
      _loadLogForEditing();
    } else {
      final now = DateTime.now();
      _selectedLogDate = DateTime(now.year, now.month, now.day);
      _selectedMealStartTime = TimeOfDay.fromDateTime(now);
      _currentLogType = LogType.meal; // Valor por defecto
    }
  }

  @override
  void dispose() {
    _initialBloodSugarController.dispose();
    _carbohydratesController.dispose();
    _fastInsulinController.dispose();
    _finalBloodSugarController.dispose();
    _beforeSleepBloodSugarController.dispose();
    _slowInsulinController.dispose();
    _afterWakeUpBloodSugarController.dispose();
    super.dispose();
  }

  Future<void> _loadLogForEditing() async {
    if (!_isEditMode || widget.logKey == null) return;

    dynamic logToEdit;
    if (_currentLogType == LogType.meal) {
      logToEdit = await _logRepository.getMealLog(widget.logKey!);
    } else {
      logToEdit = await _logRepository.getOvernightLog(widget.logKey!);
    }

    if (logToEdit == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Error: Nota no encontrada."), backgroundColor: Colors.red)
          );
          if (Navigator.canPop(context)) Navigator.pop(context);
        }
      });
      return;
    }

    if (logToEdit is MealLog) {
      final mealLog = logToEdit;
      setState(() {
        _selectedLogDate = DateTime(mealLog.startTime.year, mealLog.startTime.month, mealLog.startTime.day);
        _selectedMealStartTime = TimeOfDay.fromDateTime(mealLog.startTime);
        _initialBloodSugarController.text = mealLog.initialBloodSugar.toStringAsFixed(0);
        _carbohydratesController.text = mealLog.carbohydrates.toStringAsFixed(0);
        _fastInsulinController.text = mealLog.insulinUnits.toStringAsFixed(1);
        _finalBloodSugarController.text = mealLog.finalBloodSugar?.toStringAsFixed(0) ?? '';
      });
    } else if (logToEdit is OvernightLog) {
      final overnightLog = logToEdit;
      setState(() {
        _selectedLogDate = DateTime(overnightLog.bedTime.year, overnightLog.bedTime.month, overnightLog.bedTime.day);
        _selectedBedTime = TimeOfDay.fromDateTime(overnightLog.bedTime);
        _beforeSleepBloodSugarController.text = overnightLog.beforeSleepBloodSugar.toStringAsFixed(0);
        _slowInsulinController.text = overnightLog.slowInsulinUnits.toStringAsFixed(1);
        _afterWakeUpBloodSugarController.text = overnightLog.afterWakeUpBloodSugar?.toStringAsFixed(0) ?? '';
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedLogDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101), // O DateTime.now() si no se permiten fechas futuras
    );
    if (picked != null && picked != _selectedLogDate) {
      setState(() {
        _selectedLogDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context, TimeOfDay initialTime, ValueChanged<TimeOfDay> onTimeChanged) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null) {
      onTimeChanged(picked);
    }
  }

  Widget _buildDateTimePickerTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label),
      subtitle: Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
      onTap: onTap,
      trailing: const Icon(Icons.edit_calendar_outlined),
    );
  }

  Widget _buildLogTypeSelector() {
    if (_isEditMode) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: kDefaultPadding),
        child: Text(
          _currentLogType == LogType.meal ? "Editando Nota de Comida" : "Editando Nota de Noche",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: kDefaultPadding),
      child: ToggleButtons(
        isSelected: [
          _currentLogType == LogType.meal,
          _currentLogType == LogType.overnight
        ],
        onPressed: (int index) {
          setState(() {
            _currentLogType = index == 0 ? LogType.meal : LogType.overnight;
          });
        },
        borderRadius: BorderRadius.circular(kBorderRadius),
        selectedBorderColor: Theme.of(context).colorScheme.primary,
        selectedColor: Theme.of(context).colorScheme.onPrimary,
        fillColor: Theme.of(context).colorScheme.primary,
        color: Theme.of(context).colorScheme.primary,
        constraints: BoxConstraints(
            minHeight: kToggleMinHeight,
            minWidth: (MediaQuery.of(context).size.width - (kDefaultPadding * 2) - kDefaultPadding) / 2),
        children: const <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: kDefaultPadding),
            child: Text('COMIDA'),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: kDefaultPadding),
            child: Text('NOCHE'),
          ),
        ],
      ),
    );
  }

  Widget _buildNumericTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    bool isOptional = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: kVerticalSpacerSmall),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(kBorderRadius)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kBorderRadius),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2.0)
          ),
          floatingLabelStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        ],
        validator: (value) {
          if (!isOptional && (value == null || value.isEmpty)) {
            return 'Este campo es obligatorio';
          }
          if (value != null && value.isNotEmpty) {
            final number = double.tryParse(value);
            if (number == null) {
              return 'Introduce un número válido';
            }
            if (number < 0) {
              return 'El valor no puede ser negativo';
            }
          }
          return null;
        },
      ),
    );
  }

  Widget _buildMealForm() {
    return Form(
      key: _mealFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildDateTimePickerTile(
            label: "Hora de Inicio Comida",
            value: _selectedMealStartTime.format(context),
            icon: Icons.access_time_filled_outlined,
            onTap: () => _selectTime(context, _selectedMealStartTime, (newTime) {
              setState(() => _selectedMealStartTime = newTime);
            }),
          ),
          const SizedBox(height: kVerticalSpacerSmall),
          Text("Detalles de la Comida", style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.secondary)),
          const SizedBox(height: kVerticalSpacerSmall),
          _buildNumericTextField(
            controller: _initialBloodSugarController,
            labelText: 'Glucemia Inicial (mg/dL)',
            icon: Icons.bloodtype_outlined,
          ),
          _buildNumericTextField(
            controller: _carbohydratesController,
            labelText: 'Hidratos de Carbono (g)',
            icon: Icons.egg_outlined,
          ),
          _buildNumericTextField(
            controller: _fastInsulinController,
            labelText: 'Insulina Rápida (U)',
            icon: Icons.colorize_outlined,
          ),
          const SizedBox(height: kVerticalSpacerMedium),
          Text("Post-Comida (opcional, ~3 horas después)", style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.secondary)),
          const SizedBox(height: kVerticalSpacerSmall),
          _buildNumericTextField(
            controller: _finalBloodSugarController,
            labelText: 'Glucemia Final (mg/dL)',
            icon: Icons.bloodtype_outlined,
            isOptional: true,
          ),
          const SizedBox(height: kVerticalSpacerLarge),
          ElevatedButton.icon(
            icon: Icon(_isEditMode ? Icons.sync_alt_outlined : Icons.save_alt_outlined),
            label: Text(_isEditMode ? 'Actualizar Nota de Comida' : 'Guardar Nota de Comida'),
            onPressed: _saveMealLog,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: kButtonVerticalPadding),
              textStyle: const TextStyle(fontSize: kButtonFontSize, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kBorderRadius)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOvernightForm() {
    return Form(
      key: _overnightFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildDateTimePickerTile(
            label: "Hora de Acostarse",
            value: _selectedBedTime.format(context),
            icon: Icons.bedtime_outlined,
            onTap: () => _selectTime(context, _selectedBedTime, (newTime) {
              setState(() => _selectedBedTime = newTime);
            }),
          ),
          const SizedBox(height: kVerticalSpacerSmall),
          Text("Detalles Nocturnos", style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.secondary)),
          const SizedBox(height: kVerticalSpacerSmall),
          _buildNumericTextField(
            controller: _beforeSleepBloodSugarController,
            labelText: 'Glucemia antes de dormir (mg/dL)',
            icon: Icons.nightlight_round_outlined,
          ),
          _buildNumericTextField(
            controller: _slowInsulinController,
            labelText: 'Insulina Lenta (U)',
            icon: Icons.colorize_outlined,
          ),
          const SizedBox(height: kVerticalSpacerMedium),
          Text("Al Despertar (opcional)", style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.secondary)),
          const SizedBox(height: kVerticalSpacerSmall),
          _buildNumericTextField(
            controller: _afterWakeUpBloodSugarController,
            labelText: 'Glucemia al levantarse (mg/dL)',
            icon: Icons.wb_sunny_outlined,
            isOptional: true,
          ),
          const SizedBox(height: kVerticalSpacerLarge),
          ElevatedButton.icon(
            icon: Icon(_isEditMode ? Icons.sync_alt_outlined : Icons.save_alt_outlined),
            label: Text(_isEditMode ? 'Actualizar Nota de Noche' : 'Guardar Nota de Noche'),
            onPressed: _saveOvernightLog,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: kButtonVerticalPadding),
              textStyle: const TextStyle(fontSize: kButtonFontSize, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kBorderRadius)),
            ),
          ),
        ],
      ),
    );
  }

  void _clearMealForm() {
    _mealFormKey.currentState?.reset();
    _initialBloodSugarController.clear();
    _carbohydratesController.clear();
    _fastInsulinController.clear();
    _finalBloodSugarController.clear();
    if (!_isEditMode) {
      setState(() {
        _selectedMealStartTime = TimeOfDay.fromDateTime(DateTime.now());
      });
    }
  }

  void _clearOvernightForm() {
    _overnightFormKey.currentState?.reset();
    _beforeSleepBloodSugarController.clear();
    _slowInsulinController.clear();
    _afterWakeUpBloodSugarController.clear();
    if (!_isEditMode) {
      setState(() {
        _selectedBedTime = TimeOfDay.now(); // O la hora por defecto que prefieras
      });
    }
  }

  Future<void> _saveMealLog() async {
    if (!(_mealFormKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, corrige los errores en el formulario.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final DateTime mealEventStartTime = DateTime(
      _selectedLogDate.year, _selectedLogDate.month, _selectedLogDate.day,
      _selectedMealStartTime.hour, _selectedMealStartTime.minute,
    );
    final double? initialBloodSugar = double.tryParse(_initialBloodSugarController.text);
    final double? carbohydrates = double.tryParse(_carbohydratesController.text);
    final double? fastInsulin = double.tryParse(_fastInsulinController.text);

    if (initialBloodSugar == null || carbohydrates == null || fastInsulin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error en los datos numéricos obligatorios.'), backgroundColor: Colors.red),
      );
      return;
    }
    final double? finalBloodSugar = _finalBloodSugarController.text.isNotEmpty
        ? double.tryParse(_finalBloodSugarController.text)
        : null;
    DateTime? mealEventEndTime;
    if (finalBloodSugar != null && _finalBloodSugarController.text.isNotEmpty) {
      mealEventEndTime = mealEventStartTime.add(const Duration(hours: 3)); // Asumiendo 3 horas después
    }

    MealLog mealLog = MealLog(
      startTime: mealEventStartTime,
      initialBloodSugar: initialBloodSugar,
      carbohydrates: carbohydrates,
      insulinUnits: fastInsulin,
      finalBloodSugar: finalBloodSugar,
      endTime: mealEventEndTime,
      // Campos calculados como ratioFinal se actualizarán por DiabetesCalculatorService
    );

    try {
      String message;
      String currentHiveKey = _isEditMode ? widget.logKey! : _uuid.v4();

      // 1. Guardar/Actualizar el log inicial en Hive y (si está activado) en Supabase via Repositorio
      await _logRepository.saveMealLog(mealLog, currentHiveKey);
      message = _isEditMode ? 'Nota de comida actualizada' : 'Nota de comida guardada';
      debugPrint('$message localmente y (si aplica) sincronización inicial disparada por repo (clave: $currentHiveKey)');

      final dateOfLog = DateTime(_selectedLogDate.year, _selectedLogDate.month, _selectedLogDate.day);
      try {
        await _calculatorService.updateCalculationsForDay(dateOfLog);
        debugPrint("Cálculos actualizados para el día del MealLog: $dateOfLog. DailyCalcData también debería estar guardado/sincronizado.");
        message += ' y cálculos diarios procesados.';

      } catch (e) {
        debugPrint("Error actualizando cálculos para $dateOfLog o sincronizando DailyCalcData: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error actualizando estadísticas diarias: ${e.toString()}'), backgroundColor: Colors.amber.shade800),
          );
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green));
      _clearMealForm();
      if (Navigator.canPop(context)) Navigator.pop(context);

    } catch (e) {
      debugPrint('Error al guardar/actualizar MealLog (paso principal): $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar/actualizar: ${e.toString()}'), backgroundColor: Colors.red));
    }
  }

  Future<void> _saveOvernightLog() async {
    if (!(_overnightFormKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, corrige los errores en el formulario.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final DateTime bedEventTime = DateTime(
      _selectedLogDate.year, _selectedLogDate.month, _selectedLogDate.day,
      _selectedBedTime.hour, _selectedBedTime.minute,
    );
    final double? beforeSleepBloodSugar = double.tryParse(_beforeSleepBloodSugarController.text);
    final double? slowInsulinUnits = double.tryParse(_slowInsulinController.text);

    if (beforeSleepBloodSugar == null || slowInsulinUnits == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error en los datos numéricos obligatorios.'), backgroundColor: Colors.red),
      );
      return;
    }
    final double? afterWakeUpBloodSugar = _afterWakeUpBloodSugarController.text.isNotEmpty
        ? double.tryParse(_afterWakeUpBloodSugarController.text)
        : null;

    final overnightLog = OvernightLog(
      bedTime: bedEventTime,
      beforeSleepBloodSugar: beforeSleepBloodSugar,
      slowInsulinUnits: slowInsulinUnits,
      afterWakeUpBloodSugar: afterWakeUpBloodSugar,
    );

    try {
      String message;
      String currentHiveKey = _isEditMode ? widget.logKey! : _uuid.v4();

      await _logRepository.saveOvernightLog(overnightLog, currentHiveKey);
      message = _isEditMode ? 'Nota de noche actualizada' : 'Nota de noche guardada';
      // La sincronización con Supabase (si está activada) ocurre dentro de saveOvernightLog del repositorio.
      debugPrint('$message localmente y (si aplica) sincronización disparada por repo (clave: $currentHiveKey)');


      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green));
      _clearOvernightForm();
      if (Navigator.canPop(context)) Navigator.pop(context);

    } catch (e) {
      debugPrint('Error al guardar/actualizar OvernightLog: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar/actualizar: ${e.toString()}'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateFormat dateFormat = DateFormat.yMMMMd(Localizations.localeOf(context).languageCode); // 'es_ES'
    final String appBarTitle = _isEditMode ? 'Editar Registro' : 'Nuevo Registro de Diabetes';

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(kDefaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kBorderRadius)),
              child: _buildDateTimePickerTile(
                label: "Fecha del Registro",
                value: dateFormat.format(_selectedLogDate),
                icon: Icons.calendar_today_outlined,
                onTap: () => _selectDate(context),
              ),
            ),
            const Divider(height: kVerticalSpacerLarge),
            _buildLogTypeSelector(),
            const SizedBox(height: kVerticalSpacerMedium),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kBorderRadius)),
              child: Padding(
                padding: const EdgeInsets.all(kDefaultPadding),
                child: _currentLogType == LogType.meal
                    ? _buildMealForm()
                    : _buildOvernightForm(),
              ),
            ),
            const SizedBox(height: kVerticalSpacerLarge),
          ],
        ),
      ),
    );
  }
}