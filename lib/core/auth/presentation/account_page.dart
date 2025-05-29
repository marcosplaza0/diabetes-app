// lib/core/auth/presentation/account_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart'; // NUEVO

import 'package:diabetes_2/main.dart' show supabase, userProfileBoxName, mealLogBoxName, overnightLogBoxName; // NUEVO: mealLogBoxName, overnightLogBoxName
import 'package:diabetes_2/core/layout/drawer/avatar.dart';
import 'package:diabetes_2/data/models/profile/user_profile_data.dart';
import 'package:diabetes_2/core/services/image_cache_service.dart';
import 'package:diabetes_2/data/models/logs/logs.dart'; // NUEVO
import 'package:diabetes_2/core/services/supabase_log_sync_service.dart'; // NUEVO

// Clave para SharedPreferences (debería ser global o importada)
const String cloudSavePreferenceKeyFromAccountPage = 'saveToCloudEnabled';

// Enum para las acciones del diálogo de logout (puede estar en un archivo común)
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

  String? _avatarUrl;

  // NUEVO: Estado unificado para operaciones de red/disco
  bool _isProcessing = false;

  late Box<UserProfileData> _userProfileBox;
  final String _userProfileHiveKey = 'currentUserProfile';

  // NUEVO: Para la lógica de logout
  final SupabaseLogSyncService _logSyncServiceAccount = SupabaseLogSyncService();


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

  void _showCustomSnackBar(String message, {bool isError = false}) { /* ... (sin cambios) ... */
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

  Future<void> _getProfile() async { /* ... (sin cambios en lógica, usar _isProcessing para _isLoadingPage) ... */
    if (mounted) setState(() { _isProcessing = true; }); // Usar _isProcessing
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

      final currentUserEmail = supabase.auth.currentUser?.email;
      if (currentUserEmail != null) {
        UserProfileData profileToSync = _userProfileBox.get(_userProfileHiveKey) ?? UserProfileData();
        bool needsUpdate = false;

        if (profileToSync.username != _usernameController.text) {
          profileToSync.username = _usernameController.text;
          needsUpdate = true;
        }
        if (profileToSync.email != currentUserEmail) {
          profileToSync.email = currentUserEmail;
          needsUpdate = true;
        }

        if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
          if(!mounted) return;
          final imageCacheService = Provider.of<ImageCacheService>(context, listen: false);
          final newKey = imageCacheService.extractFilePathFromUrl(_avatarUrl!);
          if (profileToSync.avatarCacheKey != newKey) {
            profileToSync.avatarCacheKey = newKey;
            needsUpdate = true;
          }
        } else if (profileToSync.avatarCacheKey != null) {
          profileToSync.avatarCacheKey = null;
          needsUpdate = true;
        }

        if (needsUpdate || !_userProfileBox.containsKey(_userProfileHiveKey) || profileToSync.email != currentUserEmail) {
          if (profileToSync.email == null || profileToSync.email == currentUserEmail) {
            profileToSync.email = currentUserEmail;
            await _userProfileBox.put(_userProfileHiveKey, profileToSync);
            // debugPrint("AccountPage _getProfile: Perfil de Hive sincronizado/creado. Email: $currentUserEmail");
          }
        }
      }

    } on PostgrestException catch (error) {
      if (mounted) _showCustomSnackBar(error.message, isError: true);
    } catch (error) {
      if (mounted) _showCustomSnackBar('Error inesperado al obtener el perfil.', isError: true);
    } finally {
      if (mounted) setState(() { _isProcessing = false; }); // Usar _isProcessing
    }
  }

  Future<void> _updateProfile() async { /* ... (sin cambios en lógica, usar _isProcessing para _isSavingProfile) ... */
    if(mounted) setState(() { _isProcessing = true; });
    final userName = _usernameController.text.trim();
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (mounted) _showCustomSnackBar('No hay sesión activa.', isError: true);
      if(mounted) setState(() { _isProcessing = false; });
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
      profileToUpdate.email = user.email;
      await _userProfileBox.put(_userProfileHiveKey, profileToUpdate);
      // debugPrint("AccountPage _updateProfile: Username en Hive actualizado a: $userName para ${user.email}");

    } on PostgrestException catch (error) {
      if (mounted) _showCustomSnackBar(error.message, isError: true);
    } catch (error) {
      if (mounted) _showCustomSnackBar('Error inesperado al actualizar el perfil.', isError: true);
    } finally {
      if (mounted) setState(() { _isProcessing = false; });
    }
  }

  Future<void> _onUpload(String imageUrl) async { /* ... (sin cambios en lógica, usar _isProcessing para _isUploadingAvatar) ... */
    if(mounted) setState(() { _isProcessing = true; });
    final imageCacheService = Provider.of<ImageCacheService>(context, listen: false);
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (mounted) _showCustomSnackBar('No hay sesión activa para subir avatar.', isError: true);
      if(mounted) setState(() { _isProcessing = false; });
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
      profileToUpdate.email = user.email;
      if (profileToUpdate.username == null || profileToUpdate.username!.isEmpty) {
        profileToUpdate.username = _usernameController.text.trim();
      }

      await _userProfileBox.put(_userProfileHiveKey, profileToUpdate);
      // debugPrint("AccountPage _onUpload: avatarCacheKey en Hive actualizado a: $newAvatarCacheKey para ${user.email}");

      if (mounted) {
        _showCustomSnackBar('¡Imagen de perfil actualizada!');
        setState(() { _avatarUrl = imageUrl; });
      }
    } on PostgrestException catch (error) {
      if (mounted) _showCustomSnackBar(error.message, isError: true);
    } catch (error) {
      if (mounted) _showCustomSnackBar('Error inesperado al subir la imagen.', isError: true);
    } finally {
      if (mounted) setState(() { _isProcessing = false; });
    }
  }

  // MODIFICADO: _signOut ahora se llama _handleLogoutWithPrompt
  Future<void> _handleLogoutWithPrompt() async {
    if (_isProcessing || !mounted) return; // Usar _isProcessing

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
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Datos Locales Sin Sincronizar'),
            content: const Text('Tienes registros locales que no se han guardado en la nube. ¿Deseas subirlos antes de cerrar sesión?'),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancelar'),
                onPressed: () => Navigator.of(dialogContext).pop(AccountPageLogoutPromptAction.cancel),
              ),
              TextButton(
                child: const Text('Cerrar Sin Subir'),
                onPressed: () => Navigator.of(dialogContext).pop(AccountPageLogoutPromptAction.logoutWithoutUploading),
              ),
              ElevatedButton(
                child: const Text('Subir y Cerrar Sesión'),
                onPressed: () => Navigator.of(dialogContext).pop(AccountPageLogoutPromptAction.uploadAndLogout),
              ),
            ],
          );
        },
      );
    }

    if (!mounted || userAction == AccountPageLogoutPromptAction.cancel) {
      return;
    }

    if (mounted) setState(() { _isProcessing = true; }); // Usar _isProcessing

    if (userAction == AccountPageLogoutPromptAction.uploadAndLogout) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subiendo datos a la nube...'), duration: Duration(seconds: 3)),
      );
      int successCount = 0;
      int errorCount = 0;
      try {
        for (var entry in mealLogBox.toMap().entries) {
          try { await _logSyncServiceAccount.syncMealLog(entry.value, entry.key); successCount++; }
          catch (e) { errorCount++; }
        }
        for (var entry in overnightLogBox.toMap().entries) {
          try { await _logSyncServiceAccount.syncOvernightLog(entry.value, entry.key); successCount++; }
          catch (e) { errorCount++; }
        }
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sincronización completada. Éxitos: $successCount, Errores: $errorCount'), backgroundColor: errorCount > 0 ? Colors.orange : Colors.green),
          );
        }
      } catch (e) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al subir datos: ${e.toString()}'), backgroundColor: Colors.red),
          );
        }
      }
      // _isProcessing se pondrá a false en el finally del logout
    }

    try {
      await supabase.auth.signOut();
      await _userProfileBox.delete(_userProfileHiveKey); // Borrar perfil local al cerrar sesión
      debugPrint("AccountPage _signOut: Perfil de Hive borrado.");
      if (mounted) {
        GoRouter.of(context).go('/login');
      }
    } on AuthException catch (error) {
      if (mounted) _showCustomSnackBar(error.message, isError: true);
    } catch (error) {
      if (mounted) _showCustomSnackBar('Error inesperado al cerrar sesión: ${error.toString()}', isError: true);
    } finally {
      if (mounted) {
        // Solo poner a false si no se ha navegado ya (porque el widget se desmontaría)
        final router = GoRouter.of(context);
        bool stillOnAccountPage = router.routerDelegate.currentConfiguration.matches.last.matchedLocation == '/account';
        if (stillOnAccountPage) {
          setState(() { _isProcessing = false; });
        }
      }
    }
  }

  Widget _buildAvatarDisplay(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) { /* ... (sin cambios) ... */
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

  Widget _buildProfileForm(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) { /* ... (usar _isProcessing en onPressed) ... */
    bool canUpdate = !_isProcessing; // Modificado
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
              enabled: canUpdate, // Modificado
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
              onChanged: canUpdate ? (newValue) { // Modificado
                setState(() { _selectedGender = newValue; });
              } : null,
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
              label: Text(_isProcessing && _usernameController.text.isNotEmpty ? 'Guardando...' : 'Actualizar Perfil'), // Modificado para mostrar guardando si es relevante
              onPressed: canUpdate ? _updateProfile : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14.0),
                textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                elevation: _isProcessing ? 0 : 3, // Modificado
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) { /* ... (usar _isProcessing en onPressed) ... */
    bool canSignOut = !_isProcessing; // Modificado
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 50, thickness: 1, indent: 20, endIndent: 20, color: colorScheme.outlineVariant.withValues(alpha:0.5)),
        TextButton.icon(
          icon: Icon(Icons.logout, color: colorScheme.error),
          label: Text(
            _isProcessing ? 'Procesando...' : 'Cerrar Sesión', // Modificado
            style: textTheme.labelLarge?.copyWith(color: colorScheme.error, fontWeight: FontWeight.bold),
          ),
          onPressed: canSignOut ? _handleLogoutWithPrompt : null, // MODIFICADO para llamar al nuevo handler
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Usar _isProcessing para el loader de página inicial también (si _getProfile está cargando)
    if (_isProcessing && _avatarUrl == null && _usernameController.text.isEmpty) {
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
            if (_isProcessing) // Loader general para cualquier operación
              Container(
                color: colorScheme.scrim.withValues(alpha:0.3),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}