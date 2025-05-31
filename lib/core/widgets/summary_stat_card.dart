// Archivo: lib/core/widgets/summary_stat_card.dart
// Descripción: Define un widget reutilizable en forma de tarjeta (Card)
// para mostrar una estadística resumida de manera prominente.
// Incluye un título, un valor, un icono opcional, y permite personalizar
// los colores de fondo y del contenido. También puede ser interactivo (pulsable).

// Importaciones del SDK de Flutter
import 'package:flutter/material.dart'; // Framework principal de Flutter para UI.

/// SummaryStatCard: Un StatelessWidget que muestra una estadística clave en una tarjeta.
///
/// Es útil para dashboards o pantallas de resumen donde se necesita destacar
/// métricas importantes.
///
/// Parámetros:
/// - `title`: El título o etiqueta de la estadística (ej. "Glucosa Promedio").
/// - `value`: El valor de la estadística a mostrar (ej. "120 mg/dL").
/// - `icon`: Icono opcional a mostrar junto a la estadística.
/// - `cardBackgroundColor`: Color de fondo de la tarjeta.
/// - `onCardColor`: Color para el texto (título, valor) y el icono dentro de la tarjeta.
/// - `isWide`: Booleano opcional (defecto `false`). Si es `true`, el contenido se centra
///            horizontalmente, útil si la tarjeta ocupa todo el ancho.
/// - `onTap`: Callback opcional que se ejecuta cuando se pulsa la tarjeta, haciéndola interactiva.
class SummaryStatCard extends StatelessWidget {
  final String title; // Título de la estadística.
  final String value; // Valor de la estadística.
  final IconData? icon; // Icono opcional.
  final Color cardBackgroundColor; // Color de fondo de la Card.
  final Color onCardColor; // Color para el texto e icono sobre `cardBackgroundColor`.
  final bool isWide; // Si es true, el contenido se centra; si no, se alinea a la izquierda.
  final VoidCallback? onTap; // Callback para cuando se pulsa la tarjeta.

  const SummaryStatCard({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    required this.cardBackgroundColor,
    required this.onCardColor, // Asegura que el color del contenido contraste bien con el fondo.
    this.isWide = false, // Por defecto, no es ancha (contenido alineado a la izquierda).
    this.onTap, // Opcional, para hacer la tarjeta pulsable.
  });

  @override
  /// build: Construye la interfaz de usuario de la tarjeta de estadística.
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Obtiene el tema actual para estilos de texto.

    // Contenido interno de la tarjeta.
    Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0), // Padding interno.
      child: Column(
        // Alineación horizontal del contenido: centrado si `isWide` es true, sino a la izquierda.
        crossAxisAlignment: isWide ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center, // Centra el contenido verticalmente.
        children: [
          // Muestra el icono si se proporcionó.
          if (icon != null) ...[
            Icon(icon, color: onCardColor.withValues(alpha:0.8), size: 28), // Icono con opacidad y tamaño.
            const SizedBox(height: 8), // Espaciador.
          ],
          // Título de la estadística.
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: onCardColor.withValues(alpha:0.9), // Color del título con opacidad.
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1, // Evita que el título ocupe múltiples líneas.
            overflow: TextOverflow.ellipsis, // Añade "..." si el título es muy largo.
          ),
          const SizedBox(height: 6), // Espaciador.
          // Valor de la estadística.
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: onCardColor, // Color del valor.
              fontWeight: FontWeight.bold, // Texto en negrita para destacar el valor.
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    // Devuelve el widget Card.
    return Card(
      elevation: 1.0, // Elevación sutil para la tarjeta.
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)), // Bordes redondeados.
      color: cardBackgroundColor, // Color de fondo de la tarjeta.
      clipBehavior: Clip.antiAlias, // Importante si `onTap` no es nulo, para que el InkWell respete los bordes.
      // Si se proporciona un callback `onTap`, envuelve el contenido en un InkWell para hacerlo pulsable.
      // Si no, solo muestra el contenido.
      child: onTap != null
          ? InkWell(onTap: onTap, child: content) // Contenido interactivo.
          : content, // Contenido no interactivo.
    );
  }
}