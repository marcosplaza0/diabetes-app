// diabetes_log_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:diabetes_2/data/models/logs/logs.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

// ... (constantes y nombres de cajas como antes) ...
const String mealLogBoxNameFromScreen = 'meal_logs';
const String overnightLogBoxNameFromScreen = 'overnight_logs';

enum LogType { meal, overnight }

const double kDefaultPadding = 16.0;
const double kVerticalSpacerSmall = 8.0;
const double kVerticalSpacerMedium = 16.0;
const double kVerticalSpacerLarge = 24.0;
const double kBorderRadius = 8.0;
const double kToggleMinHeight = 40.0;
const double kButtonVerticalPadding = 12.0;
const double kButtonFontSize = 16.0;
// ... (resto de tus constantes k...)

class DiabetesLogScreen extends StatefulWidget {
  final dynamic logKey; // Clave de Hive (puede ser int o String si usas claves personalizadas)
  final String? logTypeString; // 'meal' o 'overnight', vendrá de GoRouter

  const DiabetesLogScreen({
    super.key,
    this.logKey,
    this.logTypeString,
  });

  @override
  State<StatefulWidget> createState() => _DiabetesLogScreenState();
}

class _DiabetesLogScreenState extends State<DiabetesLogScreen> {
  LogType _currentLogType = LogType.meal; // Tipo de log actual, inicializado o cargado
  bool _isEditMode = false; // Indica si estamos en modo edición

  // Estado para fecha y hora seleccionadas
  DateTime _selectedLogDate = DateTime.now();
  TimeOfDay _selectedMealStartTime = TimeOfDay.now();
  TimeOfDay _selectedBedTime = TimeOfDay.now();

  // ... (Controladores de TextEditingController como antes) ...
  final _mealFormKey = GlobalKey<FormState>();
  final _initialBloodSugarController = TextEditingController();
  final _carbohydratesController = TextEditingController();
  final _fastInsulinController = TextEditingController();
  final _finalBloodSugarController = TextEditingController();

  final _overnightFormKey = GlobalKey<FormState>();
  final _beforeSleepBloodSugarController = TextEditingController();
  final _slowInsulinController = TextEditingController();
  final _afterWakeUpBloodSugarController = TextEditingController();


  late Box<MealLog> _mealLogBox;
  late Box<OvernightLog> _overnightLogBox;

  @override
  void initState() {
    super.initState();
    _mealLogBox = Hive.box<MealLog>(mealLogBoxNameFromScreen);
    _overnightLogBox = Hive.box<OvernightLog>(overnightLogBoxNameFromScreen);

    if (widget.logKey != null && widget.logTypeString != null) {
      _isEditMode = true;
      _currentLogType = widget.logTypeString == 'meal' ? LogType.meal : LogType.overnight;
      _loadLogForEditing();
    } else {
      // Modo creación: inicializar con valores por defecto
      final now = DateTime.now();
      _selectedLogDate = DateTime(now.year, now.month, now.day);
      _selectedMealStartTime = TimeOfDay.fromDateTime(now);
      _currentLogType = LogType.meal; // O el último tipo seleccionado si lo guardas
    }
  }

  void _loadLogForEditing() {
    if (!_isEditMode) return;

    dynamic logToEdit;
    if (_currentLogType == LogType.meal) {
      logToEdit = _mealLogBox.get(widget.logKey);
    } else {
      logToEdit = _overnightLogBox.get(widget.logKey);
    }

    if (logToEdit == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Error: Nota no encontrada."), backgroundColor: Colors.red)
        );
        if (Navigator.canPop(context)) Navigator.pop(context);
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
        if (mealLog.finalBloodSugar != null) {
          _finalBloodSugarController.text = mealLog.finalBloodSugar!.toStringAsFixed(0);
        }
      });
    } else if (logToEdit is OvernightLog) {
      final overnightLog = logToEdit;
      setState(() {
        _selectedLogDate = DateTime(overnightLog.bedTime.year, overnightLog.bedTime.month, overnightLog.bedTime.day);
        _selectedBedTime = TimeOfDay.fromDateTime(overnightLog.bedTime);
        _beforeSleepBloodSugarController.text = overnightLog.beforeSleepBloodSugar.toStringAsFixed(0);
        _slowInsulinController.text = overnightLog.slowInsulinUnits.toStringAsFixed(1);
        if (overnightLog.afterWakeUpBloodSugar != null) {
          _afterWakeUpBloodSugarController.text = overnightLog.afterWakeUpBloodSugar!.toStringAsFixed(0);
        }
      });
    }
  }


  // ... (dispose, _selectDate, _selectTime, _buildDateTimePickerTile como antes) ...
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedLogDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101), // Permitir fechas futuras si es necesario para editar
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
    // En modo edición, no permitimos cambiar el tipo de log.
    if (_isEditMode) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: kDefaultPadding),
        child: Text(
          _currentLogType == LogType.meal ? "Editando Nota de Comida" : "Editando Nota de Noche",
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
      );
    }
    // ... (el ToggleButtons como antes)
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
        // ... (resto de propiedades de ToggleButtons)
        borderRadius: BorderRadius.circular(kBorderRadius),
        selectedBorderColor: Theme.of(context).colorScheme.primary,
        selectedColor: Colors.white,
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

  // --- _buildMealForm y _buildOvernightForm (sin cambios en su estructura interna, solo en cómo se muestran) ---
  // ... (estos métodos permanecen como antes, definiendo los campos del formulario) ...
  Widget _buildMealForm() {
    // Contenido idéntico al de la versión anterior
    return Form(
      key: _mealFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildDateTimePickerTile(
            label: "Hora de Inicio Comida",
            value: _selectedMealStartTime.format(context),
            icon: Icons.access_time,
            onTap: () => _selectTime(context, _selectedMealStartTime, (newTime) {
              setState(() => _selectedMealStartTime = newTime);
            }),
          ),
          const SizedBox(height: kVerticalSpacerSmall),
          Text("Inicio de Comida", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: kVerticalSpacerSmall),
          _buildNumericTextField(
            controller: _initialBloodSugarController,
            labelText: 'Glucemia Inicial (mg/dL)',
            icon: Icons.bloodtype,
          ),
          _buildNumericTextField(
            controller: _carbohydratesController,
            labelText: 'Hidratos de Carbono (g)',
            icon: Icons.local_dining,
          ),
          _buildNumericTextField(
            controller: _fastInsulinController,
            labelText: 'Unidades de Insulina Rápida (U)',
            icon: Icons.opacity,
          ),
          const SizedBox(height: kVerticalSpacerLarge),
          Text("Final de Comida (después de 3 horas)", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: kVerticalSpacerSmall),
          _buildNumericTextField(
            controller: _finalBloodSugarController,
            labelText: 'Glucemia Final (mg/dL)',
            icon: Icons.bloodtype_outlined,
            isOptional: true,
          ),
          const SizedBox(height: kVerticalSpacerLarge),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: Text(_isEditMode ? 'Actualizar Nota de Comida' : 'Guardar Nota de Comida'),
            onPressed: _saveMealLog,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: kButtonVerticalPadding),
              textStyle: const TextStyle(fontSize: kButtonFontSize),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOvernightForm() {
    // Contenido idéntico al de la versión anterior
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
          _buildNumericTextField(
            controller: _beforeSleepBloodSugarController,
            labelText: 'Glucemia antes de dormir (mg/dL)',
            icon: Icons.nightlight_round,
          ),
          _buildNumericTextField(
            controller: _slowInsulinController,
            labelText: 'Unidades de Insulina Lenta (U)',
            icon: Icons.opacity,
          ),
          _buildNumericTextField(
            controller: _afterWakeUpBloodSugarController,
            labelText: 'Glucemia al levantarse (mg/dL)',
            icon: Icons.wb_sunny,
            isOptional: true,
          ),
          const SizedBox(height: kVerticalSpacerLarge),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: Text(_isEditMode ? 'Actualizar Nota de Noche' : 'Guardar Nota de Noche'),
            onPressed: _saveOvernightLog,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: kButtonVerticalPadding),
              textStyle: const TextStyle(fontSize: kButtonFontSize),
            ),
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
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(kBorderRadius)),
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


  void _saveMealLog() async {
    if (!(_mealFormKey.currentState?.validate() ?? false)) { /* ... */ return; }

    final DateTime mealEventStartTime = DateTime(
      _selectedLogDate.year, _selectedLogDate.month, _selectedLogDate.day,
      _selectedMealStartTime.hour, _selectedMealStartTime.minute,
    );
    // ... (parseo de controladores como antes) ...
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
      mealEventEndTime = mealEventStartTime.add(const Duration(hours: 3));
    }

    final mealLog = MealLog(
      startTime: mealEventStartTime,
      initialBloodSugar: initialBloodSugar,
      carbohydrates: carbohydrates,
      insulinUnits: fastInsulin,
      finalBloodSugar: finalBloodSugar,
      endTime: mealEventEndTime,
    );

    try {
      String message;
      if (_isEditMode) {
        await _mealLogBox.put(widget.logKey, mealLog);
        message = 'Nota de comida actualizada en Hive';
      } else {
        await _mealLogBox.add(mealLog);
        message = 'Nota de comida guardada en Hive';
      }
      print('$message: $mealLog');

      if (!mounted) return; // <-- ADD THIS CHECK

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
      _clearMealForm(); // This is fine as it doesn't use context

      if (Navigator.canPop(context)) {
        if (!mounted) return; // <-- ADD THIS CHECK (before Navigator)
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error al guardar/actualizar MealLog en Hive: $e');
      if (!mounted) return; // <-- ADD THIS CHECK
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar/actualizar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _saveOvernightLog() async {
    if (!(_overnightFormKey.currentState?.validate() ?? false)) { /* ... */ return; }

    final DateTime bedEventTime = DateTime(
      _selectedLogDate.year, _selectedLogDate.month, _selectedLogDate.day,
      _selectedBedTime.hour, _selectedBedTime.minute,
    );
    // ... (parseo de controladores como antes) ...
    final double? beforeSleepBloodSugar = double.tryParse(_beforeSleepBloodSugarController.text);
    final double? slowInsulinUnits = double.tryParse(_slowInsulinController.text);

    if (beforeSleepBloodSugar == null || slowInsulinUnits == null) {
      // ... (snackbar de error)
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
      if (_isEditMode) {
        await _overnightLogBox.put(widget.logKey, overnightLog);
        message = 'Nota de noche actualizada en Hive';
      } else {
        await _overnightLogBox.add(overnightLog);
        message = 'Nota de noche guardada en Hive';
      }
      print('$message: $overnightLog');

      if (!mounted) return; // <-- ADD THIS CHECK

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
      _clearOvernightForm(); // This is fine

      if (Navigator.canPop(context)) {
        if (!mounted) return; // <-- ADD THIS CHECK (before Navigator)
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error al guardar/actualizar OvernightLog en Hive: $e');
      if (!mounted) return; // <-- ADD THIS CHECK
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar/actualizar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _clearMealForm() {
    // ... (código de clear como antes)
    _mealFormKey.currentState?.reset();
    _initialBloodSugarController.clear();
    _carbohydratesController.clear();
    _fastInsulinController.clear();
    _finalBloodSugarController.clear();
    if (!_isEditMode) { // Solo resetea la hora si no está en modo edición
      setState(() {
        _selectedMealStartTime = TimeOfDay.fromDateTime(DateTime.now());
      });
    }
  }

  void _clearOvernightForm() {
    // ... (código de clear como antes)
    _overnightFormKey.currentState?.reset();
    _beforeSleepBloodSugarController.clear();
    _slowInsulinController.clear();
    _afterWakeUpBloodSugarController.clear();
    if (!_isEditMode) { // Solo resetea la hora si no está en modo edición
      setState(() {
        _selectedBedTime = TimeOfDay.now();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateFormat dateFormat = DateFormat.yMMMMd(Localizations.localeOf(context).languageCode);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Editar Registro' : 'Nuevo Registro'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(kDefaultPadding),
        child: Column(
          children: <Widget>[
            _buildDateTimePickerTile(
              label: "Fecha del Registro",
              value: dateFormat.format(_selectedLogDate),
              icon: Icons.calendar_today,
              onTap: () => _selectDate(context),
            ),
            const Divider(),
            _buildLogTypeSelector(), // Se deshabilita en modo edición
            const SizedBox(height: kVerticalSpacerMedium),
            // Mostrar el formulario correspondiente al tipo de log actual
            if (_currentLogType == LogType.meal)
              _buildMealForm()
            else
              _buildOvernightForm(),
          ],
        ),
      ),
    );
  }
}