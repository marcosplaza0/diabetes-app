// lib/core/widgets/custom_numeric_text_field.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomNumericTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final IconData icon;
  final bool isOptional;
  final String? hintText;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;
  final String? Function(String?)? validator; // Para validación personalizada adicional

  const CustomNumericTextField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.icon,
    this.isOptional = false,
    this.hintText,
    this.keyboardType = const TextInputType.numberWithOptions(decimal: true),
    this.inputFormatters = const [], // Por defecto vacío, se pueden añadir más
    this.validator,
  });

  // Constantes de estilo que estaban en DiabetesLogScreen
  static const double kBorderRadius = 8.0;
  static const double kVerticalSpacerSmall = 8.0;


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Formateadores por defecto para números decimales o enteros
    List<TextInputFormatter> effectiveFormatters = [
      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ...inputFormatters, // Añadir formateadores adicionales pasados como parámetro
    ];
    if (keyboardType == TextInputType.number || keyboardType == const TextInputType.numberWithOptions(decimal:false)) {
      effectiveFormatters = [
        FilteringTextInputFormatter.digitsOnly,
        ...inputFormatters,
      ];
    }


    return Padding(
      padding: const EdgeInsets.symmetric(vertical: kVerticalSpacerSmall),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          prefixIcon: Icon(icon, color: theme.colorScheme.primary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(kBorderRadius)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(kBorderRadius),
              borderSide: BorderSide(color: theme.colorScheme.primary, width: 2.0)
          ),
          floatingLabelStyle: TextStyle(color: theme.colorScheme.primary),
        ),
        keyboardType: keyboardType,
        inputFormatters: effectiveFormatters,
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
          // Ejecutar validador personalizado si se proporciona
          if (validator != null) {
            return validator!(value);
          }
          return null;
        },
      ),
    );
  }
}