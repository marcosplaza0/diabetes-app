// lib/core/widgets/loading_or_empty_state_widget.dart
import 'package:flutter/material.dart';

class LoadingOrEmptyStateWidget extends StatelessWidget {
  final bool isLoading;
  final String? loadingText;

  final bool hasError;
  final Object? error; // El objeto de error original, por si se quiere mostrar
  final String? errorMessage; // Un mensaje de error personalizado opcional
  final IconData errorIcon;
  final String genericErrorMessage; // Mensaje si no se provee errorMessage y error es null

  final bool isEmpty;
  final String emptyMessage;
  final IconData emptyIcon;

  final Widget childIfData;
  final VoidCallback? onRetry; // Callback para un botón de reintentar en caso de error

  const LoadingOrEmptyStateWidget({
    super.key,
    required this.isLoading,
    required this.isEmpty,
    required this.childIfData,
    this.loadingText,
    this.hasError = false, // Por defecto no hay error
    this.error,
    this.errorMessage,
    this.errorIcon = Icons.error_outline_rounded, // Icono de error por defecto
    this.genericErrorMessage = "Ocurrió un error al cargar los datos.",
    this.emptyMessage = "No hay datos disponibles.",
    this.emptyIcon = Icons.inbox_outlined,
    this.onRetry, // Callback para reintentar
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              if (loadingText != null && loadingText!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(loadingText!, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
              ]
            ],
          ),
        ),
      );
    }

    if (hasError) {
      String displayErrorMessage = errorMessage ?? error?.toString() ?? genericErrorMessage;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(errorIcon, size: 72, color: theme.colorScheme.error.withOpacity(0.7)),
              const SizedBox(height: 20),
              Text(
                "¡Ups!", // Título genérico para error
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                displayErrorMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onErrorContainer.withOpacity(0.9)),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text("Reintentar"),
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.errorContainer,
                    foregroundColor: theme.colorScheme.onErrorContainer,
                  ),
                )
              ]
            ],
          ),
        ),
      );
    }

    if (isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(emptyIcon, size: 72, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4)),
              const SizedBox(height: 20),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8)),
              ),
            ],
          ),
        ),
      );
    }

    return childIfData;
  }
}