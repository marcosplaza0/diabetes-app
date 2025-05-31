// Archivo: lib/core/layout/drawer/avatar.dart
// Descripción: Widget que muestra el avatar del usuario y permite la subida de una nueva imagen de perfil.
// Utiliza ImagePicker para seleccionar imágenes de la galería, Supabase Storage para almacenarlas
// y ImageCacheService para cachear las imágenes localmente.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:flutter/material.dart'; // Framework principal de Flutter para UI.
import 'package:image_picker/image_picker.dart'; // Para seleccionar imágenes de la galería o cámara.
import 'package:supabase_flutter/supabase_flutter.dart'; // Para interactuar con Supabase Storage (StorageException).
import 'package:provider/provider.dart'; // Para acceder a ImageCacheService mediante Provider.

// Importaciones de archivos del proyecto
import 'package:diabetes_2/main.dart' show supabase, ContextExtension; // Acceso global al cliente de Supabase.
import 'package:diabetes_2/core/services/image_cache_service.dart'; // Servicio para la caché de imágenes.

/// Avatar: Un StatefulWidget que muestra la imagen de perfil del usuario y un botón para subir una nueva.
///
/// Parámetros:
/// - `imageUrl`: La URL de la imagen del avatar actual a mostrar. Puede ser nula o vacía.
/// - `onUpload`: Callback que se invoca después de que una nueva imagen ha sido subida exitosamente.
///               Recibe la URL de la imagen recién subida y firmada por Supabase.
class Avatar extends StatefulWidget {
  final String? imageUrl; // URL del avatar actual.
  final void Function(String) onUpload; // Callback con la nueva URL de la imagen.

  const Avatar({
    super.key,
    required this.imageUrl,
    required this.onUpload,
  });

  @override
  State<Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<Avatar> {
  bool _isLoading = false; // Estado para controlar la visualización del indicador de carga durante la subida.

  // Constantes de estilo para el avatar.
  final double avatarRadius = 75; // Radio del CircleAvatar.
  final double borderWidth = 2.0; // Ancho del borde alrededor del avatar.
  final double elevation = 4.0; // Elevación para la sombra del avatar.
  final Color shadowColor = Colors.black.withOpacity(0.4); // Color de la sombra.

  @override
  /// build: Construye la interfaz de usuario del widget Avatar.
  Widget build(BuildContext context) {
    final Color borderColor = Theme.of(context).colorScheme.primary; // Color del borde obtenido del tema.

    return Column(
      children: [
        // Muestra un placeholder o la imagen del avatar.
        if (widget.imageUrl == null || widget.imageUrl!.isEmpty)
        // Placeholder si no hay imageUrl.
          Material( // Widget Material para aplicar elevación (sombra) y forma.
            shape: CircleBorder(side: BorderSide(color: borderColor , width: borderWidth, strokeAlign: BorderSide.strokeAlignOutside)), // Borde circular.
            elevation: elevation,
            shadowColor: shadowColor,
            child: CircleAvatar( // Avatar circular.
              radius: avatarRadius,
              backgroundColor: Colors.grey[300], // Color de fondo del placeholder.
              child: const Center( // Texto centrado dentro del placeholder.
                child: Text(
                  'No Image',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ),
          )
        else
        // Muestra la imagen del avatar desde la URL.
          Material(
            shape: CircleBorder(side: BorderSide(color: borderColor , width: borderWidth, strokeAlign: BorderSide.strokeAlignOutside)),
            elevation: elevation,
            shadowColor: shadowColor,
            child: CircleAvatar(
              radius: avatarRadius,
              backgroundImage: NetworkImage(widget.imageUrl!), // Carga la imagen desde la red.
            ),
          ),
        const SizedBox(height: 12), // Espaciador.
        // Botón para subir una nueva imagen.
        ElevatedButton(
          onPressed: _isLoading ? null : _upload, // Deshabilitado si _isLoading es true.
          child: const Text('Upload'),
        ),
      ],
    );
  }

  /// _upload: Maneja el proceso de selección y subida de una nueva imagen de perfil.
  ///
  /// 1. Usa `ImagePicker` para que el usuario seleccione una imagen de la galería.
  /// 2. Lee los bytes de la imagen y determina su extensión.
  /// 3. Sube los bytes de la imagen a Supabase Storage en el bucket 'avatars'.
  /// 4. Si la subida es exitosa, cachea la imagen localmente usando `ImageCacheService`.
  /// 5. Obtiene una URL firmada de larga duración para la imagen subida desde Supabase.
  /// 6. Invoca el callback `widget.onUpload` con la nueva URL.
  /// 7. Maneja errores (StorageException y otros) mostrando un SnackBar.
  Future<void> _upload() async {
    final picker = ImagePicker(); // Instancia de ImagePicker.
    // Pide al usuario que seleccione una imagen de la galería.
    // Se establecen restricciones de tamaño para optimizar la imagen.
    final imageFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 300,
      maxHeight: 300,
    );

    if (imageFile == null) {
      return; // El usuario canceló la selección.
    }
    if (!mounted) return; // Comprueba si el widget sigue montado antes de operaciones asíncronas.
    setState(() => _isLoading = true); // Inicia el estado de carga.

    // Obtiene la instancia de ImageCacheService del Provider.
    final imageCacheService = Provider.of<ImageCacheService>(context, listen: false); //

    try {
      final bytes = await imageFile.readAsBytes(); // Lee los bytes de la imagen seleccionada.
      final fileExt = imageFile.path.split('.').last; // Obtiene la extensión del archivo.
      // Crea un nombre de archivo único basado en la fecha y hora actual. Este será el `filePath` en Supabase.
      final fileName = '${DateTime.now().toIso8601String()}.$fileExt';
      final filePath = fileName; // `filePath` se usará también como clave para la caché local.

      // Sube los bytes de la imagen a Supabase Storage.
      await supabase.storage.from('avatars').uploadBinary( //
        filePath, // Ruta/nombre del archivo en el bucket 'avatars'.
        bytes, // Bytes de la imagen.
        fileOptions: FileOptions(contentType: imageFile.mimeType), // Opciones de archivo, incluyendo el tipo MIME.
      );
      debugPrint("Avatar subido a Supabase: $filePath");

      // Cachea la imagen localmente después de una subida exitosa.
      await imageCacheService.cacheImage(filePath, bytes); //
      debugPrint("Avatar cacheado localmente con clave: $filePath");

      // Obtiene una URL firmada de Supabase para la imagen subida.
      // Esta URL permite el acceso a la imagen y tiene una duración larga (10 años en este caso).
      final imageUrlResponse = await supabase.storage //
          .from('avatars')
          .createSignedUrl(filePath, 60 * 60 * 24 * 365 * 10); // URL válida por 10 años.
      widget.onUpload(imageUrlResponse); // Llama al callback con la nueva URL.

    } on StorageException catch (error) { // Manejo específico de errores de Supabase Storage.
      if (mounted) {
        // Muestra un SnackBar con el mensaje de error de Supabase.
        // Se asume que ContextExtension.showSnackBar está disponible (definido en main.dart).
        context.showSnackBar(error.message, isError: true); //
      }
    } catch (error) { // Manejo de otros errores.
      if (mounted) {
        context.showSnackBar('Unexpected error occurred: ${error.toString()}', isError: true); //
      }
    } finally {
      // Asegura que el estado de carga se desactive, incluso si hay un error.
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}