import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:diabetes_2/main.dart';

class Avatar extends StatefulWidget {
  const Avatar({
    super.key,
    required this.imageUrl,
    required this.onUpload,
  });

  final String? imageUrl;
  final void Function(String) onUpload;

  @override
  State<Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<Avatar> {
  bool _isLoading = false;
  final double avatarRadius = 75;
  final double borderWidth = 2.0; // Ancho del borde
  final Color borderColor = Colors.blueAccent; // Color del borde
  final double elevation = 4.0; // Nivel de elevación para la sombra
  final Color shadowColor = Colors.black.withValues(alpha:0.4); // Color de la sombra

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.imageUrl == null || widget.imageUrl!.isEmpty)
          Material(
            shape: const CircleBorder(),
            elevation: elevation,
            shadowColor: shadowColor,
            color: Colors.transparent, // El color del Material no interfiere con el borde
            child: CircleAvatar( // Avatar exterior para el borde
              radius: avatarRadius + borderWidth,
              backgroundColor: borderColor,
              child: CircleAvatar( // Avatar interior para el contenido
                radius: avatarRadius,
                backgroundColor: Colors.grey[300],
                child: const Center(
                  child: Text(
                    'No Image',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              ),
            ),
          )
// Caso 2: Imagen con borde y sombra
        else
          Material(
            shape: const CircleBorder(),
            elevation: elevation,
            shadowColor: shadowColor,
            color: Colors.transparent,
            child: CircleAvatar( // Avatar exterior para el borde
              radius: avatarRadius + borderWidth,
              backgroundColor: borderColor,
              child: CircleAvatar( // Avatar interior para la imagen
                radius: avatarRadius,
                backgroundImage: NetworkImage(widget.imageUrl!),
              ),
            ),
          ),
        const SizedBox(height: 12), // Añade un poco de espacio antes del botón
        ElevatedButton(
          onPressed: _isLoading ? null : _upload,
          child: const Text('Upload'),
        ),
      ],
    );  }

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
    setState(() => _isLoading = true);

    try {
      final bytes = await imageFile.readAsBytes();
      final fileExt = imageFile.path.split('.').last;
      final fileName = '${DateTime.now().toIso8601String()}.$fileExt';
      final filePath = fileName;
      await supabase.storage.from('avatars').uploadBinary(
        filePath,
        bytes,
        fileOptions: FileOptions(contentType: imageFile.mimeType),
      );
      final imageUrlResponse = await supabase.storage
          .from('avatars')
          .createSignedUrl(filePath, 60 * 60 * 24 * 365 * 10);
      widget.onUpload(imageUrlResponse);
    } on StorageException catch (error) {
      if (mounted) {
        context.showSnackBar(error.message, isError: true);
      }
    } catch (error) {
      if (mounted) {
        context.showSnackBar('Unexpected error occurred', isError: true);
      }
    }

    setState(() => _isLoading = false);
  }
}