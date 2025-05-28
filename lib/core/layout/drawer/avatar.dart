import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:diabetes_2/main.dart'; // para supabase client
import 'package:provider/provider.dart'; // para Provider
import 'package:diabetes_2/core/services/image_cache_service.dart'; // Ajusta la ruta
import 'package:flutter/foundation.dart'; // para debugPrint

class Avatar extends StatefulWidget {
  const Avatar({
    super.key,
    required this.imageUrl,
    required this.onUpload,
  });

  final String? imageUrl;
  final void Function(String) onUpload; // onUpload sigue recibiendo solo la URL

  @override
  State<Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<Avatar> {
  bool _isLoading = false;
  final double avatarRadius = 75;
  final double borderWidth = 2.0; // Ancho del borde
  final double elevation = 4.0; // Nivel de elevación para la sombra
  final Color shadowColor = Colors.black.withValues(alpha:0.4); // Color de la sombra

  @override
  Widget build(BuildContext context) {
    final Color borderColor = Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        if (widget.imageUrl == null || widget.imageUrl!.isEmpty)
          Material(
            shape: CircleBorder(side: BorderSide(color: borderColor , width: borderWidth, strokeAlign: BorderSide.strokeAlignOutside)),
            elevation: elevation,
            shadowColor: shadowColor,
            child: CircleAvatar(
              radius: avatarRadius,
              backgroundColor: Colors.grey[300],
              child: const Center(
                child: Text(
                  'No Image',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ),
          )
        else
          Material(
            shape: CircleBorder(side: BorderSide(color: borderColor , width: borderWidth, strokeAlign: BorderSide.strokeAlignOutside)),
            elevation: elevation,
            shadowColor: shadowColor,
            child: CircleAvatar(
              radius: avatarRadius,
              backgroundImage: NetworkImage(widget.imageUrl!),
            ),
          ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _isLoading ? null : _upload,
          child: const Text('Upload'),
        ),
      ],
    );
  }

  Future<void> _upload() async {
    final picker = ImagePicker();
    final imageFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 300,
      maxHeight: 300,
    );
    if (imageFile == null) {
      return;
    }
    if (!mounted) return; // Comprobar si el widget sigue montado
    setState(() => _isLoading = true);

    final imageCacheService = Provider.of<ImageCacheService>(context, listen: false);

    try {
      final bytes = await imageFile.readAsBytes();
      final fileExt = imageFile.path.split('.').last;
      final fileName = '${DateTime.now().toIso8601String()}.$fileExt'; // Este es el filePath
      final filePath = fileName; // Usaremos filePath como clave de caché

      await supabase.storage.from('avatars').uploadBinary(
        filePath,
        bytes,
        fileOptions: FileOptions(contentType: imageFile.mimeType),
      );
      debugPrint("Avatar subido a Supabase: $filePath");

      // Cachear la imagen localmente después de subirla exitosamente
      await imageCacheService.cacheImage(filePath, bytes);
      debugPrint("Avatar cacheado localmente con clave: $filePath");

      final imageUrlResponse = await supabase.storage
          .from('avatars')
          .createSignedUrl(filePath, 60 * 60 * 24 * 365 * 10); // URL de larga duración
      widget.onUpload(imageUrlResponse);

    } on StorageException catch (error) {
      if (mounted) {
        // Utiliza el showSnackBar del ContextExtension
        context.showSnackBar(error.message, isError: true);
      }
    } catch (error) {
      if (mounted) {
        context.showSnackBar('Unexpected error occurred: ${error.toString()}', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}