import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import 'package:go_router/go_router.dart';

import 'package:diabetes_2/main.dart' show supabase, userProfileBoxName; // Asegúrate que userProfileBoxName esté exportado
import 'package:diabetes_2/core/layout/drawer/avatar.dart';
import 'package:diabetes_2/data/models/profile/user_profile_data.dart';
import 'package:diabetes_2/core/services/image_cache_service.dart';


class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _usernameController = TextEditingController();
  String? _selectedGender;
  final List<String> _genderOptions = ['Masculino', 'Femenino', 'Otro', 'Prefiero no decirlo'];

  String? _avatarUrl;
  bool _isLoadingPage = true; // Para la carga inicial de la página
  bool _isSavingProfile = false;
  bool _isUploadingAvatar = false;
  bool _isSigningOut = false;

  late Box<UserProfileData> _userProfileBox;
  final String _userProfileHiveKey = 'currentUserProfile';

  @override
  void initState() {
    super.initState();
    _userProfileBox = Hive.box<UserProfileData>(userProfileBoxName);
    _getProfile();
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
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  Future<void> _getProfile() async {
    setState(() { _isLoadingPage = true; });
    try {
      final userId = supabase.auth.currentSession!.user.id;
      final data = await supabase.from('profiles').select().eq('id', userId).single();

      _usernameController.text = (data['username'] ?? '') as String;
      final fetchedGender = (data['gender'] ?? '') as String;
      if (fetchedGender.isNotEmpty && _genderOptions.contains(fetchedGender)) {
        _selectedGender = fetchedGender;
      } else if (fetchedGender.isNotEmpty) {
        _selectedGender = null;
      } else {
        _selectedGender = null;
      }
      _avatarUrl = (data['avatar_url'] ?? '') as String;

      // Sincronizar/crear perfil en Hive con datos de Supabase (si es necesario)
      final currentUserEmail = supabase.auth.currentUser?.email;
      if (currentUserEmail != null) {
        UserProfileData profileToSync = _userProfileBox.get(_userProfileHiveKey) ?? UserProfileData();
        bool needsUpdate = false;

        if (profileToSync.username != _usernameController.text) {
          profileToSync.username = _usernameController.text;
          needsUpdate = true;
        }
        if (profileToSync.email != currentUserEmail) { // Debería ser raro que cambie, pero por consistencia
          profileToSync.email = currentUserEmail;
          needsUpdate = true;
        }

        if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
          final imageCacheService = Provider.of<ImageCacheService>(context, listen: false);
          final newKey = imageCacheService.extractFilePathFromUrl(_avatarUrl!);
          if (profileToSync.avatarCacheKey != newKey) {
            profileToSync.avatarCacheKey = newKey;
            needsUpdate = true;
          }
        } else if (profileToSync.avatarCacheKey != null) { // Si Supabase no tiene avatar pero Hive sí
          profileToSync.avatarCacheKey = null;
          needsUpdate = true;
        }

        if (needsUpdate || !_userProfileBox.containsKey(_userProfileHiveKey) || profileToSync.email != currentUserEmail) {
          // Asegurarse de que solo se guarde para el usuario correcto.
          if (profileToSync.email == null || profileToSync.email == currentUserEmail) {
            profileToSync.email = currentUserEmail; // Confirmar email
            await _userProfileBox.put(_userProfileHiveKey, profileToSync);
            debugPrint("AccountPage _getProfile: Perfil de Hive sincronizado/creado. Email: $currentUserEmail");
          }
        }
      }

    } on PostgrestException catch (error) {
      if (mounted) _showCustomSnackBar(error.message, isError: true);
    } catch (error) {
      if (mounted) _showCustomSnackBar('Error inesperado al obtener el perfil.', isError: true);
    } finally {
      if (mounted) setState(() { _isLoadingPage = false; });
    }
  }

  Future<void> _updateProfile() async {
    setState(() { _isSavingProfile = true; });
    final userName = _usernameController.text.trim();
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (mounted) _showCustomSnackBar('No hay sesión activa.', isError: true);
      setState(() { _isSavingProfile = false; });
      return;
    }

    final updates = {
      'id': user.id,
      'username': userName,
      'gender': _selectedGender ?? '',
      'updated_at': DateTime.now().toIso8601String(),
    };
    try {
      await supabase.from('profiles').upsert(updates);
      if (mounted) _showCustomSnackBar('¡Perfil actualizado correctamente!');

      UserProfileData profileToUpdate = _userProfileBox.get(_userProfileHiveKey) ?? UserProfileData();
      profileToUpdate.username = userName;
      profileToUpdate.email = user.email; // Email de la sesión actual
      await _userProfileBox.put(_userProfileHiveKey, profileToUpdate);
      debugPrint("AccountPage _updateProfile: Username en Hive actualizado a: $userName para ${user.email}");

    } on PostgrestException catch (error) {
      if (mounted) _showCustomSnackBar(error.message, isError: true);
    } catch (error) {
      if (mounted) _showCustomSnackBar('Error inesperado al actualizar el perfil.', isError: true);
    } finally {
      if (mounted) setState(() { _isSavingProfile = false; });
    }
  }

  Future<void> _onUpload(String imageUrl) async {
    setState(() { _isUploadingAvatar = true; });
    final imageCacheService = Provider.of<ImageCacheService>(context, listen: false);
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (mounted) _showCustomSnackBar('No hay sesión activa para subir avatar.', isError: true);
      setState(() { _isUploadingAvatar = false; });
      return;
    }

    try {
      await supabase.from('profiles').upsert({
        'id': user.id,
        'avatar_url': imageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });

      String? newAvatarCacheKey = imageCacheService.extractFilePathFromUrl(imageUrl);
      UserProfileData profileToUpdate = _userProfileBox.get(_userProfileHiveKey) ?? UserProfileData();

      profileToUpdate.avatarCacheKey = newAvatarCacheKey;
      profileToUpdate.email = user.email; // Asegurar email de la sesión actual
      if (profileToUpdate.username == null || profileToUpdate.username!.isEmpty) {
        profileToUpdate.username = _usernameController.text.trim(); // Si no había username, tomar el actual del campo
      }

      await _userProfileBox.put(_userProfileHiveKey, profileToUpdate);
      debugPrint("AccountPage _onUpload: avatarCacheKey en Hive actualizado a: $newAvatarCacheKey para ${user.email}");

      if (mounted) {
        _showCustomSnackBar('¡Imagen de perfil actualizada!');
        setState(() { _avatarUrl = imageUrl; });
      }
    } on PostgrestException catch (error) {
      if (mounted) _showCustomSnackBar(error.message, isError: true);
    } catch (error) {
      if (mounted) _showCustomSnackBar('Error inesperado al subir la imagen.', isError: true);
    } finally {
      if (mounted) setState(() { _isUploadingAvatar = false; });
    }
  }

  Future<void> _signOut() async {
    setState(() { _isSigningOut = true; });
    try {
      await supabase.auth.signOut();
      await _userProfileBox.delete(_userProfileHiveKey);
      debugPrint("AccountPage _signOut: Perfil de Hive borrado.");
      if (mounted) {
        // Asegurar que la navegación ocurra después de que el estado de signOut se haya procesado
        // y que el widget no intente reconstruirse con datos de usuario inválidos.
        GoRouter.of(context).go('/login');
      }
    } on AuthException catch (error) {
      if (mounted) _showCustomSnackBar(error.message, isError: true);
    } catch (error) {
      if (mounted) _showCustomSnackBar('Error inesperado al cerrar sesión.', isError: true);
    } finally {
      // No establecer _isSigningOut a false si la navegación es exitosa,
      // ya que la página se desmontará. Si la navegación falla, sí.
      if (mounted && GoRouter.of(context).routerDelegate.currentConfiguration.uri.toString() != '/login') {
        setState(() { _isSigningOut = false; });
      }
    }
  }

  Widget _buildAvatarDisplay(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      children: [
        Center(
          child: Avatar(
            imageUrl: _avatarUrl,
            onUpload: _onUpload,
          ),
        ),
        const SizedBox(height: 16),
        if (_usernameController.text.isNotEmpty)
          Text(
            _usernameController.text,
            style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildProfileForm(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    bool canUpdate = !_isLoadingPage && !_isSavingProfile && !_isUploadingAvatar && !_isSigningOut;
    return Card(
      elevation: 2,
      surfaceTintColor: colorScheme.surfaceTint,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Nombre de Usuario',
                hintText: 'Ingresa tu nombre de usuario',
                prefixIcon: Icon(Icons.person_outline, color: colorScheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
                floatingLabelBehavior: FloatingLabelBehavior.auto,
              ),
              style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedGender,
              items: _genderOptions.map((String gender) {
                return DropdownMenuItem<String>(
                  value: gender,
                  child: Text(gender, style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() { _selectedGender = newValue; });
              },
              decoration: InputDecoration(
                labelText: 'Género',
                prefixIcon: Icon(Icons.wc_outlined, color: colorScheme.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
                floatingLabelBehavior: FloatingLabelBehavior.auto,
              ),
              style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
              dropdownColor: colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.save_alt_outlined),
              label: Text(_isSavingProfile ? 'Guardando...' : 'Actualizar Perfil'),
              onPressed: canUpdate ? _updateProfile : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14.0),
                textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                elevation: _isSavingProfile ? 0 : 3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    bool canSignOut = !_isLoadingPage && !_isSavingProfile && !_isUploadingAvatar && !_isSigningOut;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 50, thickness: 1, indent: 20, endIndent: 20, color: colorScheme.outlineVariant.withOpacity(0.5)),
        TextButton.icon(
          icon: Icon(Icons.logout, color: colorScheme.error),
          label: Text(
            _isSigningOut ? 'Cerrando Sesión...' : 'Cerrar Sesión',
            style: textTheme.labelLarge?.copyWith(color: colorScheme.error, fontWeight: FontWeight.bold),
          ),
          onPressed: canSignOut ? _signOut : null,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
            // overlayColor: MaterialStateProperty.all(colorScheme.error.withOpacity(0.1)), // M3 style
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Determina si alguna operación principal está en curso
    final isAnyOperationPending = _isSavingProfile || _isUploadingAvatar || _isSigningOut;

    if (_isLoadingPage && !isAnyOperationPending) { // Solo muestra el loader de página si no hay otra operación
      return Scaffold(
        appBar: AppBar(title: const Text('Perfil')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
      ),
      backgroundColor: colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0),
              children: [
                _buildAvatarDisplay(context, colorScheme, textTheme),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    'Información Personal',
                    style: textTheme.titleMedium?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
                _buildProfileForm(context, colorScheme, textTheme),
                const SizedBox(height: 24),
                _buildActionButtons(context, colorScheme, textTheme),
                const SizedBox(height: 20),
              ],
            ),
            if (isAnyOperationPending) // Superposición de loader para operaciones en curso
              Container(
                color: colorScheme.scrim.withOpacity(0.3),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}