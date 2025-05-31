// Archivo: lib/core/widgets/loading_or_empty_state_widget.dart
// Descripción: Define un widget reutilizable para manejar y mostrar diferentes estados de la UI,
// como carga, error, vacío, o el contenido principal cuando los datos están disponibles.
// Ayuda a estandarizar la retroalimentación al usuario en diversas partes de la aplicación.

// Importaciones del SDK de Flutter
import 'package:flutter/material.dart'; // Framework principal de Flutter para UI.

/// LoadingOrEmptyStateWidget: Un StatelessWidget que muestra una UI diferente
/// según el estado de carga, error, o si no hay datos (vacío).
///
/// Este widget es útil para envolver contenido que depende de datos asíncronos
/// o que puede no tener nada que mostrar.
///
/// Parámetros:
/// - `isLoading`: Booleano que indica si se está cargando contenido.
/// - `loadingText`: Texto opcional a mostrar debajo del indicador de carga.
/// - `hasError`: Booleano que indica si ha ocurrido un error.
/// - `error`: El objeto de error original (opcional, para debugging o mostrar detalles).
/// - `errorMessage`: Mensaje de error personalizado a mostrar (opcional).
/// - `errorIcon`: Icono a mostrar en el estado de error (por defecto `Icons.error_outline_rounded`).
/// - `genericErrorMessage`: Mensaje de error genérico si no se provee `errorMessage` y `error` es nulo.
/// - `isEmpty`: Booleano que indica si no hay datos para mostrar (estado vacío).
/// - `emptyMessage`: Mensaje a mostrar en el estado vacío.
/// - `emptyIcon`: Icono a mostrar en el estado vacío (por defecto `Icons.inbox_outlined`).
/// - `childIfData`: El widget a mostrar si no se está cargando, no hay error, y no está vacío (es decir, hay datos).
/// - `onRetry`: Callback opcional para un botón de "Reintentar" que se muestra en el estado de error.
class LoadingOrEmptyStateWidget extends StatelessWidget {
  final bool isLoading; // True si se está cargando.
  final String? loadingText; // Texto opcional durante la carga.

  final bool hasError; // True si hay un error.
  final Object? error; // El objeto de error (ej. Exception).
  final String? errorMessage; // Mensaje de error personalizado.
  final IconData errorIcon; // Icono para el estado de error.
  final String genericErrorMessage; // Mensaje de error por defecto.

  final bool isEmpty; // True si no hay datos para mostrar.
  final String emptyMessage; // Mensaje para el estado vacío.
  final IconData emptyIcon; // Icono para el estado vacío.

  final Widget childIfData; // Widget a mostrar cuando hay datos.
  final VoidCallback? onRetry; // Callback para el botón de reintentar.

  const LoadingOrEmptyStateWidget({
    super.key,
    required this.isLoading,
    required this.isEmpty,
    required this.childIfData,
    this.loadingText,
    this.hasError = false, // Por defecto, no hay error.
    this.error,
    this.errorMessage,
    this.errorIcon = Icons.error_outline_rounded, // Icono de error por defecto.
    this.genericErrorMessage = "Ocurrió un error al cargar los datos.", // Mensaje de error genérico.
    this.emptyMessage = "No hay datos disponibles.", // Mensaje de vacío por defecto.
    this.emptyIcon = Icons.inbox_outlined, // Icono de vacío por defecto.
    this.onRetry, // Callback para reintentar, opcional.
  });

  @override
  /// build: Construye la interfaz de usuario del widget según el estado actual.
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Obtiene el tema actual para estilos.

    // 1. Estado de Carga: Muestra un indicador de progreso y un texto opcional.
    if (isLoading) {
      return Center( // Centra el contenido de carga.
        child: Padding(
          padding: const EdgeInsets.all(32.0), // Padding alrededor del contenido.
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const CircularProgressIndicator(), // Indicador de progreso estándar.
              // Muestra el texto de carga si se proporcionó.
              if (loadingText != null && loadingText!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(loadingText!, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
              ]
            ],
          ),
        ),
      );
    }

    // 2. Estado de Error: Muestra un icono de error, un mensaje y un botón de reintento opcional.
    if (hasError) {
      // Determina el mensaje de error a mostrar:
      // Prioridad: `errorMessage` > `error.toString()` > `genericErrorMessage`.
      String displayErrorMessage = errorMessage ?? error?.toString() ?? genericErrorMessage;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(errorIcon, size: 72, color: theme.colorScheme.error.withOpacity(0.7)), // Icono de error.
              const SizedBox(height: 20),
              Text(
                "¡Ups!", // Título genérico para el estado de error.
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                displayErrorMessage, // Mensaje de error.
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onErrorContainer.withOpacity(0.9)),
              ),
              // Muestra el botón de reintentar si se proporcionó el callback `onRetry`.
              if (onRetry != null) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text("Reintentar"),
                  onPressed: onRetry, // Llama al callback `onRetry`.
                  style: ElevatedButton.styleFrom( // Estilo del botón.
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

    // 3. Estado Vacío: Muestra un icono y un mensaje indicando que no hay datos.
    if (isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(emptyIcon, size: 72, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4)), // Icono de estado vacío.
              const SizedBox(height: 20),
              Text(
                emptyMessage, // Mensaje de estado vacío.
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8)),
              ),
            ],
          ),
        ),
      );
    }

    // 4. Estado con Datos: Si no está cargando, no hay error y no está vacío, muestra el widget hijo (`childIfData`).
    return childIfData;
  }
}