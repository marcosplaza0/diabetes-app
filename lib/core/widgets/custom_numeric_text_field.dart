// Archivo: lib/core/widgets/custom_numeric_text_field.dart
// Descripción: Define un widget de campo de texto personalizado y reutilizable,
// específicamente diseñado para la entrada de datos numéricos.
// Incluye formateo, validación y estilización consistentes.

// Importaciones del SDK de Flutter
import 'package:flutter/material.dart'; // Framework principal de Flutter para UI (TextFormField, InputDecoration, etc.).
import 'package:flutter/services.dart'; // Para TextInputFormatter, usado para restringir la entrada de texto.

/// CustomNumericTextField: Un StatelessWidget que encapsula un TextFormField
/// configurado para la entrada numérica.
///
/// Proporciona una interfaz estandarizada para campos numéricos, incluyendo:
/// - Un controlador de texto (`TextEditingController`).
/// - Etiqueta (`labelText`) e icono de prefijo.
/// - Placeholder (`hintText`).
/// - Marcador de opcionalidad (`isOptional`) para la validación.
/// - Tipo de teclado (`keyboardType`) y formateadores de entrada (`inputFormatters`).
/// - Un validador personalizado adicional (`validator`).
class CustomNumericTextField extends StatelessWidget {
  final TextEditingController controller; // Controlador para el valor del campo de texto.
  final String labelText; // Texto que se muestra como etiqueta del campo.
  final IconData icon; // Icono que se muestra como prefijo en el campo.
  final bool isOptional; // Indica si el campo es opcional (afecta la validación).
  final String? hintText; // Texto de placeholder que se muestra cuando el campo está vacío.
  final TextInputType keyboardType; // Tipo de teclado a mostrar (ej. numérico, numérico con decimales).
  final List<TextInputFormatter> inputFormatters; // Lista de formateadores para restringir la entrada.
  final String? Function(String?)? validator; // Función de validación personalizada adicional.

  const CustomNumericTextField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.icon,
    this.isOptional = false, // Por defecto, el campo es obligatorio.
    this.hintText,
    this.keyboardType = const TextInputType.numberWithOptions(decimal: true), // Teclado numérico con decimales por defecto.
    this.inputFormatters = const [], // Lista vacía por defecto, se pueden añadir más formateadores.
    this.validator, // Validador personalizado opcional.
  });

  // Constantes de estilo que podrían haberse usado directamente en DiabetesLogScreen
  // o que se definen aquí para mantener la consistencia si este widget se usa en más lugares.
  static const double kBorderRadius = 8.0; // Radio de borde para el campo de texto.
  static const double kVerticalSpacerSmall = 8.0; // Espaciador vertical.


  @override
  /// build: Construye la interfaz de usuario del campo de texto numérico.
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Obtiene el tema actual para estilos.

    // Determina los formateadores de entrada efectivos.
    // Por defecto, permite números y un punto decimal.
    List<TextInputFormatter> effectiveFormatters = [
      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')), // Permite dígitos y un punto opcional.
      ...inputFormatters, // Añade formateadores adicionales pasados como parámetro.
    ];
    // Si el tipo de teclado es solo para números enteros (sin decimales).
    if (keyboardType == TextInputType.number || keyboardType == const TextInputType.numberWithOptions(decimal:false)) {
      effectiveFormatters = [
        FilteringTextInputFormatter.digitsOnly, // Permite solo dígitos.
        ...inputFormatters,
      ];
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: kVerticalSpacerSmall), // Padding vertical.
      child: TextFormField(
        controller: controller, // Asocia el controlador.
        decoration: InputDecoration(
          labelText: labelText, // Etiqueta del campo.
          hintText: hintText, // Placeholder.
          prefixIcon: Icon(icon, color: theme.colorScheme.primary), // Icono de prefijo.
          // Estilo del borde.
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(kBorderRadius)),
          // Estilo del borde cuando el campo está enfocado.
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kBorderRadius),
              borderSide: BorderSide(color: theme.colorScheme.primary, width: 2.0)
          ),
          // Estilo de la etiqueta cuando está flotando (campo enfocado o con contenido).
          floatingLabelStyle: TextStyle(color: theme.colorScheme.primary),
        ),
        keyboardType: keyboardType, // Tipo de teclado.
        inputFormatters: effectiveFormatters, // Aplica los formateadores.
        validator: (value) { // Lógica de validación.
          // 1. Si el campo no es opcional y está vacío, es un error.
          if (!isOptional && (value == null || value.isEmpty)) {
            return 'Este campo es obligatorio';
          }
          // 2. Si el campo tiene valor:
          if (value != null && value.isNotEmpty) {
            final number = double.tryParse(value); // Intenta convertir el valor a un número.
            // 2a. Si no se puede convertir a número, es un error.
            if (number == null) {
              return 'Introduce un número válido';
            }
            // 2b. Si el número es negativo, es un error (asumiendo que no se permiten negativos).
            if (number < 0) {
              return 'El valor no puede ser negativo';
            }
          }
          // 3. Ejecuta el validador personalizado adicional si se proporcionó.
          if (validator != null) {
            return validator!(value);
          }
          // Si todas las validaciones pasan, devuelve null (sin error).
          return null;
        },
      ),
    );
  }
}