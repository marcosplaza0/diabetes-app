// Archivo: lib/features/notes/presentation/log_screen.dart
// Descripción: Define la interfaz de usuario para la pantalla de creación y edición
// de registros de diabetes (comidas y nocturnos).
// Utiliza DiabetesLogViewModel para gestionar el estado y la lógica de negocio.
// Permite al usuario introducir datos como glucemias, carbohidratos, dosis de insulina,
// y seleccionar la fecha y hora del registro.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:flutter/material.dart'; // Framework principal de Flutter para UI.
import 'package:intl/intl.dart'; // Para formateo de fechas (ej. DateFormat.yMMMMd).
import 'package:provider/provider.dart'; // Para acceder al DiabetesLogViewModel.

// Importaciones de archivos del proyecto
import 'package:diabetes_2/features/notes/presentation/diabetes_log_view_model.dart'; // ViewModel para esta pantalla.
import 'package:diabetes_2/core/widgets/custom_numeric_text_field.dart'; // Widget personalizado para campos de entrada numéricos.

// Constantes de estilo para la UI.
// Podrían moverse a un archivo de constantes de UI si se usan en múltiples lugares.
const double kDefaultPadding = 16.0; // Padding estándar.
const double kVerticalSpacerSmall = 8.0; // Espaciador vertical pequeño.
const double kVerticalSpacerMedium = 16.0; // Espaciador vertical mediano.
const double kVerticalSpacerLarge = 24.0; // Espaciador vertical grande.
const double kBorderRadius = 8.0; // Radio de borde estándar para elementos como Cards y botones.
const double kToggleMinHeight = 40.0; // Altura mínima para los ToggleButtons.
const double kButtonVerticalPadding = 12.0; // Padding vertical para botones principales.
const double kButtonFontSize = 16.0; // Tamaño de fuente para botones principales.

/// DiabetesLogScreen: Un StatefulWidget que gestiona la UI para añadir o editar registros.
///
/// Recibe opcionalmente `logKey` y `logTypeString` como parámetros de ruta
/// para determinar si se está editando un log existente o creando uno nuevo.
class DiabetesLogScreen extends StatefulWidget {
  final String? logKey; // Clave del log en Hive (si se está editando).
  final String? logTypeString; // Tipo de log ("meal" o "overnight") como String (si se está editando).

  const DiabetesLogScreen({
    super.key,
    this.logKey, // Opcional: para modo edición.
    this.logTypeString, // Opcional: para modo edición.
  });

  @override
  State<DiabetesLogScreen> createState() => _DiabetesLogScreenState();
}

class _DiabetesLogScreenState extends State<DiabetesLogScreen> {
  // GlobalKeys para los widgets Form, permitiendo la validación y reseteo de los formularios.
  final _mealFormKey = GlobalKey<FormState>();
  final _overnightFormKey = GlobalKey<FormState>();

  @override
  /// initState: Se llama una vez cuando el widget se inserta en el árbol de widgets.
  ///
  /// Llama al método `initialize` del `DiabetesLogViewModel` para configurar el estado
  /// inicial de la pantalla, ya sea para un nuevo log o para editar uno existente,
  /// basándose en los parámetros `widget.logKey` y `widget.logTypeString`.
  /// Se usa `WidgetsBinding.instance.addPostFrameCallback` para asegurar que la
  /// inicialización del ViewModel (que podría llamar a `notifyListeners`) ocurra
  /// después de que el primer frame haya sido construido, evitando errores comunes.
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Inicializa el ViewModel con los parámetros de la ruta.
      // `listen: false` se usa aquí porque la inicialización solo debe ocurrir una vez
      // y no queremos que este callback se suscriba a cambios del ViewModel.
      // La UI se suscribirá a los cambios a través de `context.watch` o `Provider.of` en el método `build`.
      Provider.of<DiabetesLogViewModel>(context, listen: false).initialize( //
        logKey: widget.logKey,
        logTypeString: widget.logTypeString,
      );
    });
  }

  /// _buildDateTimePickerTile: Widget helper para construir un ListTile interactivo
  /// que muestra una fecha o hora y permite al usuario cambiarla mediante un selector.
  ///
  /// @param label El texto descriptivo para el ListTile (ej. "Fecha del Registro").
  /// @param value El valor actual de la fecha/hora formateado como String.
  /// @param icon El IconData a mostrar a la izquierda del texto.
  /// @param onTap El callback que se ejecuta cuando el usuario toca el ListTile (debería abrir el selector).
  /// @param context El BuildContext para acceder al Theme.
  /// @return Un ListTile configurado para mostrar y permitir la edición de fecha/hora.
  Widget _buildDateTimePickerTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    final theme = Theme.of(context); // Obtiene el tema para estilos.
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary), // Icono a la izquierda.
      title: Text(label), // Etiqueta principal.
      subtitle: Text( // Valor actual (fecha/hora formateada).
          value,
          style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)
      ),
      onTap: onTap, // Acción al tocar (abrir selector).
      trailing: const Icon(Icons.edit_calendar_outlined), // Icono a la derecha como indicador de edición.
    );
  }


  @override
  /// build: Construye la interfaz de usuario de la pantalla de registro/edición.
  ///
  /// Utiliza `DiabetesLogViewModel` (obtenido de `Provider`) para obtener el estado
  /// actual y realizar acciones. La UI se adapta según si se está creando un nuevo log
  /// o editando uno existente, y según el tipo de log (comida o nocturno).
  Widget build(BuildContext context) {
    // Obtiene la instancia del ViewModel. `context.watch` se suscribe a los cambios
    // del ViewModel, haciendo que este widget se reconstruya cuando el VM notifica cambios.
    final viewModel = context.watch<DiabetesLogViewModel>();
    final theme = Theme.of(context); // Obtiene el tema actual para estilos.

    // Formateador de fecha localizado.
    final DateFormat dateFormat = DateFormat.yMMMMd(Localizations.localeOf(context).languageCode);
    // Título de la AppBar, cambia si es modo edición o nuevo registro.
    final String appBarTitle = viewModel.isEditMode ? 'Editar Registro' : 'Nuevo Registro de Diabetes'; //

    return Scaffold(
      appBar: AppBar(title: Text(appBarTitle), centerTitle: true),
      body: SingleChildScrollView( // Permite el desplazamiento si el contenido excede la pantalla.
        padding: const EdgeInsets.all(kDefaultPadding), // Padding general.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, // Los hijos ocupan todo el ancho.
          children: <Widget>[
            // Selector de Fecha del Registro.
            Card(
              elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kBorderRadius)),
              child: _buildDateTimePickerTile(
                context: context,
                label: "Fecha del Registro",
                value: dateFormat.format(viewModel.selectedLogDate), // Fecha del VM. //
                icon: Icons.calendar_today_outlined,
                onTap: () => viewModel.selectDate(context), // Llama al método del VM para seleccionar fecha. //
              ),
            ),
            const Divider(height: kVerticalSpacerLarge), // Separador visual.

            // Selector de Tipo de Log (Comida/Noche).
            // Solo se muestra si no se está en modo edición (es decir, al crear un nuevo log).
            if (!viewModel.isEditMode) //
              Padding(
                padding: const EdgeInsets.symmetric(vertical: kDefaultPadding),
                child: ToggleButtons(
                  isSelected: [
                    viewModel.currentLogType == LogType.meal, // Estado de selección para "COMIDA". //
                    viewModel.currentLogType == LogType.overnight // Estado de selección para "NOCHE". //
                  ],
                  onPressed: viewModel.isSaving ? null : (int index) => viewModel.updateLogType(index == 0 ? LogType.meal : LogType.overnight), // Actualiza el tipo en el VM. //
                  borderRadius: BorderRadius.circular(kBorderRadius),
                  selectedBorderColor: theme.colorScheme.primary,
                  selectedColor: theme.colorScheme.onPrimary,
                  fillColor: theme.colorScheme.primary,
                  color: theme.colorScheme.primary,
                  constraints: BoxConstraints(minHeight: kToggleMinHeight, minWidth: (MediaQuery.of(context).size.width - (kDefaultPadding * 2) - kDefaultPadding) / 2),
                  children: const <Widget>[
                    Padding(padding: EdgeInsets.symmetric(horizontal: kDefaultPadding), child: Text('COMIDA')),
                    Padding(padding: EdgeInsets.symmetric(horizontal: kDefaultPadding), child: Text('NOCHE'))
                  ],
                ),
              )
            else // Si está en modo edición, muestra un título indicando el tipo de log que se edita.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: kDefaultPadding),
                child: Text(
                  viewModel.currentLogType == LogType.meal ? "Editando Nota de Comida" : "Editando Nota de Noche",
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: kVerticalSpacerMedium),

            // Formulario dinámico (Comida o Noche)
            Card(
              elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kBorderRadius)),
              child: Padding(
                padding: const EdgeInsets.all(kDefaultPadding),
                child: viewModel.currentLogType == LogType.meal // Determina qué formulario mostrar. //
                    ? Form( // Formulario para MealLog
                  key: _mealFormKey, // Asocia la GlobalKey.
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // Selector de Hora de Inicio Comida.
                      _buildDateTimePickerTile(
                        context: context,
                        label: "Hora de Inicio Comida",
                        value: viewModel.selectedMealStartTime.format(context), // Hora del VM. //
                        icon: Icons.access_time_filled_outlined,
                        onTap: () => viewModel.selectMealStartTime(context), // Llama al método del VM. //
                      ),
                      const SizedBox(height: kVerticalSpacerSmall),
                      Text("Detalles de la Comida", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.secondary)),
                      const SizedBox(height: kVerticalSpacerSmall),
                      // Campos numéricos personalizados.
                      CustomNumericTextField( //
                        controller: viewModel.initialBloodSugarController, // Controlador del VM. //
                        labelText: 'Glucemia Inicial (mg/dL)',
                        icon: Icons.bloodtype_outlined,
                      ),
                      CustomNumericTextField( //
                        controller: viewModel.carbohydratesController, //
                        labelText: 'Hidratos de Carbono (g)',
                        icon: Icons.egg_outlined,
                      ),
                      CustomNumericTextField( //
                        controller: viewModel.fastInsulinController, //
                        labelText: 'Insulina Rápida (U)',
                        icon: Icons.colorize_outlined,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true), // Permite decimales.
                      ),
                      const SizedBox(height: kVerticalSpacerMedium),
                      Text("Post-Comida ~3 horas después", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.secondary)),
                      const SizedBox(height: kVerticalSpacerSmall),
                      CustomNumericTextField( //
                        controller: viewModel.finalBloodSugarController, //
                        labelText: 'Glucemia Final (mg/dL)',
                        icon: Icons.bloodtype_outlined,
                        isOptional: true, // Este campo es opcional.
                      ),
                      const SizedBox(height: kVerticalSpacerLarge),
                      // Botón de Guardar/Actualizar para MealLog.
                      ElevatedButton.icon(
                        icon: viewModel.isSaving // Muestra un indicador de progreso si está guardando. //
                            ? const SizedBox(width:18, height:18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Icon(viewModel.isEditMode ? Icons.sync_alt_outlined : Icons.save_alt_outlined), // Icono cambia si es edición o nuevo. //
                        label: Text(viewModel.isSaving ? 'Guardando...' : (viewModel.isEditMode ? 'Actualizar Nota de Comida' : 'Guardar Nota de Comida')), // Texto del botón cambia. //
                        onPressed: viewModel.isSaving ? null : () async { // Deshabilitado si está guardando. //
                          bool success = await viewModel.saveMealLog(_mealFormKey); // Llama al método de guardado del VM. //
                          if (success && mounted) { // Si es exitoso y el widget está montado.
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(viewModel.isEditMode ? 'Nota de comida actualizada' : 'Nota de comida guardada'), backgroundColor: Colors.green)); //
                            if (Navigator.canPop(context)) Navigator.pop(context); // Vuelve a la pantalla anterior.
                          } else if (!success && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al guardar. Revisa los campos.'), backgroundColor: Colors.red));
                          }
                        },
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: kButtonVerticalPadding), textStyle: const TextStyle(fontSize: kButtonFontSize, fontWeight: FontWeight.bold), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kBorderRadius))),
                      ),
                    ],
                  ),
                )
                    : Form( // Formulario para OvernightLog
                  key: _overnightFormKey, // Asocia la GlobalKey.
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // Selector de Hora de Acostarse.
                      _buildDateTimePickerTile(
                        context: context,
                        label: "Hora de Acostarse",
                        value: viewModel.selectedBedTime.format(context), // Hora del VM. //
                        icon: Icons.bedtime_outlined,
                        onTap: () => viewModel.selectBedTime(context), // Llama al método del VM. //
                      ),
                      const SizedBox(height: kVerticalSpacerSmall),
                      Text("Detalles Nocturnos", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.secondary)),
                      const SizedBox(height: kVerticalSpacerSmall),
                      CustomNumericTextField( //
                        controller: viewModel.beforeSleepBloodSugarController, // Controlador del VM. //
                        labelText: 'Glucemia antes de dormir (mg/dL)',
                        icon: Icons.nightlight_round_outlined,
                      ),
                      CustomNumericTextField( //
                        controller: viewModel.slowInsulinController, //
                        labelText: 'Insulina lenta (U)',
                        icon: Icons.colorize_outlined,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true), // Permite decimales.
                      ),
                      const SizedBox(height: kVerticalSpacerMedium),
                      Text("Al Despertar (opcional)", style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.secondary)),
                      const SizedBox(height: kVerticalSpacerSmall),
                      CustomNumericTextField( //
                        controller: viewModel.afterWakeUpBloodSugarController, //
                        labelText: 'Glucemia al levantarse (mg/dL)',
                        icon: Icons.wb_sunny_outlined,
                        isOptional: true, // Este campo es opcional.
                      ),
                      const SizedBox(height: kVerticalSpacerLarge),
                      // Botón de Guardar/Actualizar para OvernightLog.
                      ElevatedButton.icon(
                        icon: viewModel.isSaving // Muestra indicador de progreso. //
                            ? const SizedBox(width:18, height:18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Icon(viewModel.isEditMode ? Icons.sync_alt_outlined : Icons.save_alt_outlined), // Icono cambia. //
                        label: Text(viewModel.isSaving ? 'Guardando...' : (viewModel.isEditMode ? 'Actualizar Nota de Noche' : 'Guardar Nota de Noche')), // Texto del botón cambia. //
                        onPressed: viewModel.isSaving ? null : () async { // Deshabilitado si está guardando. //
                          bool success = await viewModel.saveOvernightLog(_overnightFormKey); // Llama al método de guardado del VM. //
                          if (success && mounted) { // Si es exitoso y el widget está montado.
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(viewModel.isEditMode ? 'Nota de noche actualizada' : 'Nota de noche guardada'), backgroundColor: Colors.green)); //
                            if (Navigator.canPop(context)) Navigator.pop(context); // Vuelve a la pantalla anterior.
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
            const SizedBox(height: kVerticalSpacerLarge), // Espacio al final.
          ],
        ),
      ),
    );
  }
}