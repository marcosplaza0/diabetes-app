import 'package:flutter/material.dart';

class GlucoseLevelIndicator extends StatelessWidget {
  final int glucoseLevel;

  const GlucoseLevelIndicator({
    super.key,
    required this.glucoseLevel,
  });

  Color _getBackgroundColor() {
    if (glucoseLevel < 70) {
      return Color(0xFFFF0000); // Un rojo más intenso
    } else if (glucoseLevel >= 70 && glucoseLevel <= 180) {
      return Color(0xFF6AD56F); // Un verde agradable
    } else if (glucoseLevel > 180 && glucoseLevel <= 240) {
      return Colors.yellow.shade700; // Un amarillo más visible
    } else { // Mayor de 240
      return Colors.orange.shade800; // Un naranja rojizo oscuro
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = _getBackgroundColor();
    final Color textColor = Colors.black.withValues(alpha: 0.8);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20.0), // Ajuste de padding
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.15),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Para que la columna ocupe el mínimo espacio vertical
        crossAxisAlignment: CrossAxisAlignment.center, // Centrar horizontalmente el contenido de la columna
        children: <Widget>[
          Text(
            "Nivel de glucosa",
            style: TextStyle(
              fontSize: 23, // Tamaño para el título
              fontWeight: FontWeight.bold, // Un poco menos bold que el número
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center, // Centrar el número y las unidades
            crossAxisAlignment: CrossAxisAlignment.baseline, // Alinear por la base del texto
            textBaseline: TextBaseline.alphabetic, // Necesario para CrossAxisAlignment.baseline
            children: <Widget>[
              Text(
                glucoseLevel.toString(),
                style: TextStyle(
                  fontSize: 80,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 6), // Espacio entre el número y las unidades
              Text(
                "mg/dL",
                style: TextStyle(
                  fontSize: 16, // Tamaño más pequeño para las unidades
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}