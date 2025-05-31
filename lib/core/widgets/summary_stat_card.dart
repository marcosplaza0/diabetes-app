// lib/core/widgets/summary_stat_card.dart
import 'package:flutter/material.dart';

class SummaryStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData? icon; // Icono es opcional
  final Color cardBackgroundColor;
  final Color onCardColor; // Color para el texto y el icono
  final bool isWide;
  final VoidCallback? onTap; // Para hacerla pulsable

  const SummaryStatCard({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    required this.cardBackgroundColor,
    required this.onCardColor,
    this.isWide = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: isWide ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, color: onCardColor.withOpacity(0.8), size: 28), // Icono más prominente
            const SizedBox(height: 8),
          ],
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: onCardColor.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6), // Espacio ajustado
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: onCardColor,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    return Card(
      elevation: 1.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      color: cardBackgroundColor,
      clipBehavior: Clip.antiAlias, // Importante si onTap no es null
      child: onTap != null
          ? InkWell(onTap: onTap, child: content)
          : content,
    );
  }
}