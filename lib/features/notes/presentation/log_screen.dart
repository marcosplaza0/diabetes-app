// lib/features/notes/presentation/log_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:diabetes_2/features/notes/presentation/diabetes_log_view_model.dart'; // Importar ViewModel
import 'package:diabetes_2/core/widgets/custom_numeric_text_field.dart';

// Las constantes de estilo podrían moverse a un archivo de utilidades de UI
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
  State<DiabetesLogScreen> createState() => _DiabetesLogScreenState();
}

class _DiabetesLogScreenState extends State<DiabetesLogScreen> {
  // Las FormKeys se pueden mantener aquí para pasarlas al ViewModel si es necesario,
  // o el ViewModel podría crearlas (aunque es menos común para FormKeys).
  // Por ahora, las mantenemos aquí para controlar la validación desde la UI.
  final _mealFormKey = GlobalKey<FormState>();
  final _overnightFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Inicializar el ViewModel con los parámetros de la ruta
    // Se hace 'listen: false' porque la inicialización solo debe ocurrir una vez.
    // La UI escuchará los cambios a través de context.watch o Provider.of en el build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DiabetesLogViewModel>(context, listen: false).initialize(
        logKey: widget.logKey,
        logTypeString: widget.logTypeString,
      );
    });
  }

  Widget _buildDateTimePickerTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    required BuildContext context, // Pasar context para Theme
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label),
      subtitle: Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
      onTap: onTap,
      trailing: const Icon(Icons.edit_calendar_outlined),
    );
  }


  @override
  Widget build(BuildContext context) {
    // Escuchar cambios en el ViewModel
    final viewModel = context.watch<DiabetesLogViewModel>();
    final theme = Theme.of(context); // Para no llamar a Theme.of(context) múltiples veces

    final DateFormat dateFormat = DateFormat.yMMMMd(Localizations.localeOf(context).languageCode);
    final String appBarTitle = viewModel.isEditMode ? 'Editar Registro' : 'Nuevo Registro de Diabetes';

    return Scaffold(
      appBar: AppBar(title: Text(appBarTitle), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(kDefaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Card(
              elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kBorderRadius)),
              child: _buildDateTimePickerTile(
                context: context, label: "Fecha del Registro",
                value: dateFormat.format(viewModel.selectedLogDate),
                icon: Icons.calendar_today_outlined,
                onTap: () => viewModel.selectDate(context), // Llamar método del VM
              ),
            ),
            const Divider(height: kVerticalSpacerLarge),

            // Selector de Tipo de Log
            if (!viewModel.isEditMode) // Solo mostrar si no está en modo edición
              Padding(
                padding: const EdgeInsets.symmetric(vertical: kDefaultPadding),
                child: ToggleButtons(
                  isSelected: [viewModel.currentLogType == LogType.meal, viewModel.currentLogType == LogType.overnight],
                  onPressed: viewModel.isSaving ? null : (int index) => viewModel.updateLogType(index == 0 ? LogType.meal : LogType.overnight),
                  borderRadius: BorderRadius.circular(kBorderRadius),
                  selectedBorderColor: theme.colorScheme.primary, selectedColor: theme.colorScheme.onPrimary,
                  fillColor: theme.colorScheme.primary, color: theme.colorScheme.primary,
                  constraints: BoxConstraints(minHeight: kToggleMinHeight, minWidth: (MediaQuery.of(context).size.width - (kDefaultPadding * 2) - kDefaultPadding) / 2),
                  children: const <Widget>[Padding(padding: EdgeInsets.symmetric(horizontal: kDefaultPadding), child: Text('COMIDA')), Padding(padding: EdgeInsets.symmetric(horizontal: kDefaultPadding), child: Text('NOCHE'))],
                ),
              )
            else // Mostrar título si está en modo edición
              Padding(
                padding: const EdgeInsets.symmetric(vertical: kDefaultPadding),
                child: Text(
                  viewModel.currentLogType == LogType.meal ? "Editando Nota de Comida" : "Editando Nota de Noche",
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: kVerticalSpacerMedium),

            Card(
              elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kBorderRadius)),
              child: Padding(
                padding: const EdgeInsets.all(kDefaultPadding),
                child: viewModel.currentLogType == LogType.meal
                    ? Form( // Formulario de Comida
                  key: _mealFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _buildDateTimePickerTile(
                        context: context, label: "Hora de Inicio Comida",
                        value: viewModel.selectedMealStartTime.format(context),
                        icon: Icons.access_time_filled_outlined,
                        onTap: () => viewModel.selectMealStartTime(context),
                      ),
                      const SizedBox(height: kVerticalSpacerSmall),
                      Text("Detalles de la Comida", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.secondary)),
                      const SizedBox(height: kVerticalSpacerSmall),
                      CustomNumericTextField(
                        // context: context, // Ya no se pasa context directamente, el widget lo obtiene
                        controller: viewModel.initialBloodSugarController,
                        labelText: 'Glucemia Inicial (mg/dL)',
                        icon: Icons.bloodtype_outlined,
                        keyboardType: TextInputType.number, // Solo enteros si es necesario
                      ),
                      CustomNumericTextField(
                        controller: viewModel.carbohydratesController,
                        labelText: 'Hidratos de Carbono (g)',
                        icon: Icons.egg_outlined,
                        keyboardType: TextInputType.number, // Solo enteros si es necesario
                      ),
                      CustomNumericTextField(
                        controller: viewModel.fastInsulinController,
                        labelText: 'Insulina Rápida (U)',
                        icon: Icons.colorize_outlined,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true), // Permite decimales
                      ),
                      const SizedBox(height: kVerticalSpacerMedium),
                      Text("Post-Comida (opcional, ~3 horas después)", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.secondary)),
                      const SizedBox(height: kVerticalSpacerSmall),
                      CustomNumericTextField(
                        controller: viewModel.finalBloodSugarController,
                        labelText: 'Glucemia Final (mg/dL)',
                        icon: Icons.bloodtype_outlined,
                        isOptional: true,
                        keyboardType: TextInputType.number, // Solo enteros si es necesario
                      ),
                      const SizedBox(height: kVerticalSpacerLarge),
                      ElevatedButton.icon(
                        icon: viewModel.isSaving ? const SizedBox(width:18, height:18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(viewModel.isEditMode ? Icons.sync_alt_outlined : Icons.save_alt_outlined),
                        label: Text(viewModel.isSaving ? 'Guardando...' : (viewModel.isEditMode ? 'Actualizar Nota de Comida' : 'Guardar Nota de Comida')),
                        onPressed: viewModel.isSaving ? null : () async {
                          bool success = await viewModel.saveMealLog(_mealFormKey);
                          if (success && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(viewModel.isEditMode ? 'Nota de comida actualizada' : 'Nota de comida guardada'), backgroundColor: Colors.green));
                            if (Navigator.canPop(context)) Navigator.pop(context);
                          } else if (!success && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al guardar. Revisa los campos.'), backgroundColor: Colors.red));
                          }
                        },
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: kButtonVerticalPadding), textStyle: const TextStyle(fontSize: kButtonFontSize, fontWeight: FontWeight.bold), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kBorderRadius))),
                      ),
                    ],
                  ),
                )
                    : Form( // Formulario de Noche
                  key: _overnightFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _buildDateTimePickerTile(
                        context: context, label: "Hora de Acostarse",
                        value: viewModel.selectedBedTime.format(context),
                        icon: Icons.bedtime_outlined,
                        onTap: () => viewModel.selectBedTime(context),
                      ),
                      const SizedBox(height: kVerticalSpacerSmall),
                      Text("Detalles Nocturnos", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.secondary)),
                      const SizedBox(height: kVerticalSpacerSmall),
                      CustomNumericTextField(
                        controller: viewModel.beforeSleepBloodSugarController,
                        labelText: 'Glucemia antes de dormir (mg/dL)',
                        icon: Icons.nightlight_round_outlined,
                        isOptional: false,
                        keyboardType: TextInputType.number, // Solo enteros si es necesario
                      ),
                      CustomNumericTextField(
                        controller: viewModel.slowInsulinController,
                        labelText: 'Insulina lenta (U)',
                        icon: Icons.colorize_outlined,
                        isOptional: false,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true), // Permite decimales
                      ),
                      const SizedBox(height: kVerticalSpacerMedium),
                      Text("Al Despertar (opcional)", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.secondary)),
                      const SizedBox(height: kVerticalSpacerSmall),
                      CustomNumericTextField(
                        controller: viewModel.afterWakeUpBloodSugarController,
                        labelText: 'Glucemia al levantarse (mg/dL)',
                        icon: Icons.wb_sunny_outlined,
                        keyboardType: TextInputType.number, // Solo enteros si es necesario
                      ),
                      const SizedBox(height: kVerticalSpacerLarge),
                      ElevatedButton.icon(
                        icon: viewModel.isSaving ? const SizedBox(width:18, height:18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(viewModel.isEditMode ? Icons.sync_alt_outlined : Icons.save_alt_outlined),
                        label: Text(viewModel.isSaving ? 'Guardando...' : (viewModel.isEditMode ? 'Actualizar Nota de Noche' : 'Guardar Nota de Noche')),
                        onPressed: viewModel.isSaving ? null : () async {
                          bool success = await viewModel.saveOvernightLog(_overnightFormKey);
                          if (success && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(viewModel.isEditMode ? 'Nota de noche actualizada' : 'Nota de noche guardada'), backgroundColor: Colors.green));
                            if (Navigator.canPop(context)) Navigator.pop(context);
                          } else if (!success && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al guardar. Revisa los campos.'), backgroundColor: Colors.red));
                          }
                        },
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: kButtonVerticalPadding), textStyle: const TextStyle(fontSize: kButtonFontSize, fontWeight: FontWeight.bold), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kBorderRadius))),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: kVerticalSpacerLarge),
          ],
        ),
      ),
    );
  }
}