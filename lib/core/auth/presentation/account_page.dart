// lib/core/auth/presentation/account_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Para Uint8List
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Para AuthException y supabase client global
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:diabetes_2/main.dart' show supabase, mealLogBoxName, overnightLogBoxName; // Para supabase client y cajas de logs
import 'package:diabetes_2/core/layout/drawer/avatar.dart';
import 'package:diabetes_2/data/repositories/user_profile_repository.dart';
import 'package:diabetes_2/core/services/image_cache_service.dart';
import 'package:diabetes_2/data/models/logs/logs.dart';
import 'package:diabetes_2/core/services/supabase_log_sync_service.dart';
// Asegúrate de que UserProfileData se importa si necesitas el tipo explícitamente, aunque el repo lo abstrae
// import 'package:diabetes_2/data/models/profile/user_profile_data.dart';


const String cloudSavePreferenceKeyFromAccountPage = 'saveToCloudEnabled';

enum AccountPageLogoutPromptAction {
  uploadAndLogout,
  logoutWithoutUploading,
  cancel,
}

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _usernameController = TextEditingController();
  String? _selectedGender;
  final List<String> _genderOptions = ['Masculino', 'Femenino', 'Otro', 'Prefiero no decirlo'];

  String? _avatarUrl; // Para el widget Avatar que actualmente usa URL
  // Uint8List? _avatarBytes; // Podría usarse si Avatar se modifica para tomar bytes

  bool _isProcessing = false; // Estado unificado para operaciones

  late UserProfileRepository _userProfileRepository;
  late ImageCacheService _imageCacheService; // Para extraer filePath en _onUpload

  // SupabaseLogSyncService se sigue necesitando para la lógica de logout de logs
  final SupabaseLogSyncService _logSyncServiceAccount = SupabaseLogSyncService();


  @override
  void initState() {
    super.initState();
    _userProfileRepository = Provider.of<UserProfileRepository>(context, listen: false);
    _imageCacheService = Provider.of<ImageCacheService>(context, listen: false);
    _loadProfileData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  void _showCustomSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  Future<void> _loadProfileData() async {
    if (mounted) setState(() { _isProcessing = true; });
    try {
      // forceRemote: true para asegurar que obtenemos los datos más frescos de Supabase
      final result = await _userProfileRepository.getCurrentUserProfile(forceRemote: true);

      if (mounted) {
        if (result.profile != null) {
          _usernameController.text = result.profile!.username ?? '';
          // _avatarBytes = result.avatarBytes; // Guardar bytes por si Avatar se actualiza

          // Para el widget Avatar actual, necesitamos construir la URL firmada si existe una clave de caché
          if (result.profile!.avatarCacheKey != null && result.profile!.avatarCacheKey!.isNotEmpty) {
            try {
              // Usamos la instancia global de supabase client definida en main.dart
              final signedUrl = await supabase.storage
                  .from('avatars')
                  .createSignedUrl(result.profile!.avatarCacheKey!, 60 * 60 * 24 * 7); // URL válida por 7 días
              _avatarUrl = signedUrl;
            } catch (e) {
              debugPrint("AccountPage: Error creando URL firmada para avatar: $e");
              _avatarUrl = null;
            }
          } else {
            _avatarUrl = null;
          }

          final String? fetchedGender = result.profile!.gender;
          if (fetchedGender != null && fetchedGender.isNotEmpty && _genderOptions.contains(fetchedGender)) {
            _selectedGender = fetchedGender;
          } else if (fetchedGender != null && fetchedGender.isNotEmpty) {
            _selectedGender = null;
            debugPrint("AccountPage: Género '${fetchedGender}' de la base de datos no está en las opciones locales.");
          } else {
            _selectedGender = null;
          }
          debugPrint("AccountPage: Perfil cargado. Username: ${result.profile!.username}, Gender DB: ${result.profile!.gender}, SelectedGender UI: $_selectedGender, AvatarURL: $_avatarUrl");

        } else {
          // Si result.profile es null, podría ser que no hay usuario logueado o error.
          // El repositorio ya maneja el caso de no usuario.
          // Si hay usuario pero no perfil (ej. nuevo usuario), los campos estarán vacíos/default.
          _usernameController.text = supabase.auth.currentUser?.email?.split('@').first ?? '';
          _avatarUrl = null;
          _selectedGender = null;
          debugPrint("AccountPage: No se encontró perfil en el repositorio, usando defaults.");
        }
      }
    } catch (error) {
      if (mounted) _showCustomSnackBar('Error inesperado al obtener el perfil: ${error.toString()}', isError: true);
      debugPrint("AccountPage: Error en _loadProfileData: $error");
    } finally {
      if (mounted) setState(() { _isProcessing = false; });
    }
  }

  Future<void> _updateProfile() async {
    if(mounted) setState(() { _isProcessing = true; });
    final userName = _usernameController.text.trim();

    try {
      await _userProfileRepository.updateProfileDetails(
        username: userName,
        gender: _selectedGender, // _selectedGender se actualiza por el DropdownButtonFormField
      );
      if (mounted) _showCustomSnackBar('¡Perfil actualizado correctamente!');
      debugPrint("AccountPage: Perfil actualizado con Username: $userName, Gender: $_selectedGender");
    } on PostgrestException catch (error) {
      if (mounted) _showCustomSnackBar(error.message, isError: true);
    } catch (error) {
      if (mounted) _showCustomSnackBar('Error inesperado al actualizar el perfil: ${error.toString()}', isError: true);
    } finally {
      if (mounted) setState(() { _isProcessing = false; });
    }
  }

  Future<void> _onUpload(String imageUrl) async { // imageUrl es la de Supabase Storage
    if(mounted) setState(() { _isProcessing = true; });

    // _imageCacheService se obtiene de Provider en initState
    final String? newAvatarCacheKey = _imageCacheService.extractFilePathFromUrl(imageUrl);
    // El widget Avatar ya habrá cacheado la imagen usando ImageCacheService con este filePath (newAvatarCacheKey)

    if (newAvatarCacheKey == null) {
      if (mounted) _showCustomSnackBar('Error procesando la URL de la imagen.', isError: true);
      if (mounted) setState(() { _isProcessing = false; });
      return;
    }

    try {
      await _userProfileRepository.updateUserAvatar(
        avatarUrl: imageUrl, // La URL completa de Supabase Storage
        newAvatarCacheKey: newAvatarCacheKey, // El path/key usado en ImageCacheService y Supabase Storage
      );

      if (mounted) {
        _showCustomSnackBar('¡Imagen de perfil actualizada!');
        setState(() {
          _avatarUrl = imageUrl; // Actualizar la URL para el widget Avatar
        });
      }
    } on PostgrestException catch (error) {
      if (mounted) _showCustomSnackBar(error.message, isError: true);
    } catch (error) {
      if (mounted) _showCustomSnackBar('Error inesperado al actualizar la imagen: ${error.toString()}', isError: true);
    } finally {
      if (mounted) setState(() { _isProcessing = false; });
    }
  }

  Future<void> _handleLogoutWithPrompt() async {
    // ... (la lógica interna del diálogo y sincronización de logs se mantiene igual) ...
    if (_isProcessing || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final bool cloudSaveCurrentlyEnabled = prefs.getBool(cloudSavePreferenceKeyFromAccountPage) ?? false;

    final mealLogBox = Hive.box<MealLog>(mealLogBoxName);
    final overnightLogBox = Hive.box<OvernightLog>(overnightLogBoxName);
    final bool hasLocalData = mealLogBox.isNotEmpty || overnightLogBox.isNotEmpty;
    final bool isLoggedIn = supabase.auth.currentUser != null;

    AccountPageLogoutPromptAction? userAction = AccountPageLogoutPromptAction.logoutWithoutUploading;

    if (isLoggedIn && !cloudSaveCurrentlyEnabled && hasLocalData) {
      if (!mounted) return;
      userAction = await showDialog<AccountPageLogoutPromptAction>(
        context: context, barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Datos Locales Sin Sincronizar'),
            content: const Text('Tienes registros locales que no se han guardado en la nube. ¿Deseas subirlos antes de cerrar sesión?'),
            actions: <Widget>[
              TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(dialogContext).pop(AccountPageLogoutPromptAction.cancel)),
              TextButton(child: const Text('Cerrar Sin Subir'), onPressed: () => Navigator.of(dialogContext).pop(AccountPageLogoutPromptAction.logoutWithoutUploading)),
              ElevatedButton(child: const Text('Subir y Cerrar Sesión'), onPressed: () => Navigator.of(dialogContext).pop(AccountPageLogoutPromptAction.uploadAndLogout)),
            ],
          );
        },
      );
    }

    if (!mounted || userAction == AccountPageLogoutPromptAction.cancel) return;
    if (mounted) setState(() { _isProcessing = true; });

    if (userAction == AccountPageLogoutPromptAction.uploadAndLogout) {
      // ... (lógica de sincronización de logs sin cambios) ...
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subiendo datos a la nube...'), duration: Duration(seconds: 3)));
      int successCount = 0; int errorCount = 0;
      try {
        for (var entry in mealLogBox.toMap().entries) {
          try { await _logSyncServiceAccount.syncMealLog(entry.value, entry.key); successCount++; } catch (e) { errorCount++; }
        }
        for (var entry in overnightLogBox.toMap().entries) {
          try { await _logSyncServiceAccount.syncOvernightLog(entry.value, entry.key); successCount++; } catch (e) { errorCount++; }
        }
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sincronización completada. Éxitos: $successCount, Errores: $errorCount'), backgroundColor: errorCount > 0 ? Colors.orange : Colors.green));
      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al subir datos: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }

    try {
      await supabase.auth.signOut();
      // Limpiar el perfil local usando el repositorio
      await _userProfileRepository.clearLocalUserProfile(); // <--- CAMBIO AQUÍ
      debugPrint("AccountPage _signOut: Perfil de Hive local borrado via repo.");
      if (mounted) GoRouter.of(context).go('/login');
    } on AuthException catch (error) {
      if (mounted) _showCustomSnackBar(error.message, isError: true);
    } catch (error) {
      if (mounted) _showCustomSnackBar('Error inesperado al cerrar sesión: ${error.toString()}', isError: true);
    } finally {
      if (mounted) {
        final router = GoRouter.of(context);
        if (router.routerDelegate.currentConfiguration.matches.last.matchedLocation == '/account') {
          setState(() { _isProcessing = false; });
        }
      }
    }
  }

  Widget _buildAvatarDisplay(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    Widget avatarWidget;
    // Usamos _avatarUrl porque el widget Avatar espera una URL.
    // _avatarBytes podría usarse si Avatar se actualizara para tomar MemoryImage.
    if (_isProcessing && _avatarUrl == null && _usernameController.text.isEmpty) {
      avatarWidget = const CircleAvatar(radius: 75, child: CircularProgressIndicator());
    } else {
      // Avatar widget usa imageUrl. _avatarUrl se llena en _loadProfileData
      avatarWidget = Avatar(imageUrl: _avatarUrl, onUpload: _onUpload);
    }

    return Column(
      children: [
        Center(child: avatarWidget),
        const SizedBox(height: 16),
        if (_usernameController.text.isNotEmpty)
          Text(_usernameController.text, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface), textAlign: TextAlign.center),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildProfileForm(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    bool canUpdate = !_isProcessing;
    return Card(
      elevation: 2, surfaceTintColor: colorScheme.surfaceTint, margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _usernameController, enabled: canUpdate,
              decoration: InputDecoration(labelText: 'Nombre de Usuario', hintText: 'Ingresa tu nombre de usuario', prefixIcon: Icon(Icons.person_outline, color: colorScheme.primary), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: colorScheme.primary, width: 2)), floatingLabelBehavior: FloatingLabelBehavior.auto),
              style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedGender, // Controlado por _selectedGender
              items: _genderOptions.map((String gender) => DropdownMenuItem<String>(value: gender, child: Text(gender, style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant)))).toList(),
              onChanged: canUpdate ? (newValue) { setState(() { _selectedGender = newValue; }); } : null,
              decoration: InputDecoration(labelText: 'Género', prefixIcon: Icon(Icons.wc_outlined, color: colorScheme.primary), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: colorScheme.primary, width: 2)), floatingLabelBehavior: FloatingLabelBehavior.auto),
              style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface), dropdownColor: colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.save_alt_outlined),
              label: Text(_isProcessing && _usernameController.text.isNotEmpty ? 'Guardando...' : 'Actualizar Perfil'),
              onPressed: canUpdate ? _updateProfile : null, // _updateProfile ahora usa el repo con gender
              style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary, padding: const EdgeInsets.symmetric(vertical: 14.0), textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)), elevation: _isProcessing ? 0 : 3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    bool canSignOut = !_isProcessing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 50, thickness: 1, indent: 20, endIndent: 20, color: colorScheme.outlineVariant.withOpacity(0.5)),
        TextButton.icon(
          icon: Icon(Icons.logout, color: colorScheme.error),
          label: Text(_isProcessing ? 'Procesando...' : 'Cerrar Sesión', style: textTheme.labelLarge?.copyWith(color: colorScheme.error, fontWeight: FontWeight.bold)),
          onPressed: canSignOut ? _handleLogoutWithPrompt : null, // _handleLogoutWithPrompt ahora usa el repo para limpiar perfil
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12.0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0))),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isProcessing && _avatarUrl == null && _usernameController.text.isEmpty /*&& _avatarBytes == null*/) {
      return Scaffold(appBar: AppBar(title: const Text('Perfil')), body: const Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Perfil'), elevation: 0, backgroundColor: Colors.transparent, foregroundColor: colorScheme.onSurface),
      backgroundColor: colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: Stack(children: [
          ListView(padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0), children: [
            _buildAvatarDisplay(context, colorScheme, textTheme), const SizedBox(height: 24),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0), child: Text('Información Personal', style: textTheme.titleMedium?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w600))),
            const SizedBox(height: 12),
            _buildProfileForm(context, colorScheme, textTheme), const SizedBox(height: 24),
            _buildActionButtons(context, colorScheme, textTheme), const SizedBox(height: 20),
          ]),
          if (_isProcessing) Container(color: colorScheme.scrim.withOpacity(0.3), child: const Center(child: CircularProgressIndicator())),
        ]),
      ),
    );
  }
}