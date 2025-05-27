import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:diabetes_2/main.dart'; // Assuming supabase is initialized here
import 'package:diabetes_2/core/layout/drawer/avatar.dart'; // Your Avatar widget
import 'package:go_router/go_router.dart'; // For navigation on signout

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _usernameController = TextEditingController();
  String? _selectedGender; // For DropdownButtonFormField
  final List<String> _genderOptions = ['Masculino', 'Femenino', 'Otro', 'Prefiero no decirlo'];

  String? _avatarUrl;
  var _loading = true;

  /// Called once a user id is received
  Future<void> _getProfile() async {
    setState(() {
      _loading = true;
    });

    try {
      final userId = supabase.auth.currentSession!.user.id;
      final data =
      await supabase.from('profiles').select().eq('id', userId).single();
      _usernameController.text = (data['username'] ?? '') as String;

      // Fetch and set gender for the DropdownButtonFormField
      final fetchedGender = (data['gender'] ?? '') as String;
      if (fetchedGender.isNotEmpty && _genderOptions.contains(fetchedGender)) {
        _selectedGender = fetchedGender;
      } else if (fetchedGender.isNotEmpty) {
        // If gender exists but not in options, you might want to add it to options,
        // select 'Otro', or leave _selectedGender as null to show hint.
        // For now, if it's not a standard option, it won't be pre-selected.
        _selectedGender = null; // Or handle as 'Otro'
      } else {
        _selectedGender = null; // No gender specified or empty
      }

      _avatarUrl = (data['avatar_url'] ?? '') as String;
    } on PostgrestException catch (error) {
      if (mounted) _showSnackBar(error.message, isError: true);
    } catch (error) {
      if (mounted) {
        _showSnackBar('Error inesperado al obtener el perfil.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  /// Called when user taps `Update` button
  Future<void> _updateProfile() async {
    setState(() {
      _loading = true;
    });
    final userName = _usernameController.text.trim();
    final user = supabase.auth.currentUser;
    final updates = {
      'id': user!.id,
      'username': userName,
      'gender': _selectedGender ?? '', // Store selected gender, or empty string if null
      'updated_at': DateTime.now().toIso8601String(),
    };
    try {
      await supabase.from('profiles').upsert(updates);
      if (mounted) _showSnackBar('¡Perfil actualizado correctamente!');
    } on PostgrestException catch (error) {
      if (mounted) _showSnackBar(error.message, isError: true);
    } catch (error) {
      if (mounted) {
        _showSnackBar('Error inesperado al actualizar el perfil.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    try {
      setState(() { // Show loading indicator for signout as well
        _loading = true;
      });
      await supabase.auth.signOut();
      // Navigation is handled in finally block, even if there's an error
      // The goal is to always attempt to navigate away from the authenticated screen.
    } on AuthException catch (error) {
      if (mounted) _showSnackBar(error.message, isError: true);
    } catch (error) {
      if (mounted) {
        _showSnackBar('Error inesperado al cerrar sesión.', isError: true);
      }
    } finally {
      if (mounted) {
        // Ensure you have a route named '/login' in your GoRouter setup
        context.go('/login');
        // It's usually good practice to also set _loading to false here,
        // but since we are navigating away, it might not be strictly necessary
        // unless the navigation can fail and user stays on page.
        // For robustness:
        // setState(() { _loading = false; });
      }
    }
  }

  /// Called when image has been uploaded to Supabase storage from within Avatar widget
  Future<void> _onUpload(String imageUrl) async {
    setState(() {
      _loading = true;
    });
    try {
      final userId = supabase.auth.currentUser!.id;
      await supabase.from('profiles').upsert({
        'id': userId,
        'avatar_url': imageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        _showSnackBar('¡Imagen de perfil actualizada!');
        setState(() {
          _avatarUrl = imageUrl;
        });
      }
    } on PostgrestException catch (error) {
      if (mounted) _showSnackBar(error.message, isError: true);
    } catch (error) {
      if (mounted) {
        _showSnackBar('Error inesperado al subir la imagen.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary, // Use primary for success
        behavior: SnackBarBehavior.floating, // Modern look
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _getProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Widget _buildAvatarDisplay(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      children: [
        Center(
            child: Avatar(
              imageUrl: _avatarUrl,
              onUpload: _onUpload,
              // Consider adding a size property to your Avatar widget, e.g., radius: 60
            ),
        ),
        const SizedBox(height: 16),
        if (_usernameController.text.isNotEmpty) // Display username if available
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
    return Card(
      elevation: 2,
      surfaceTintColor: colorScheme.surfaceTint, // M3 elevation tint
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: colorScheme.surface, // Using surface or surfaceContainerLow
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
                setState(() {
                  _selectedGender = newValue;
                });
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
              dropdownColor: colorScheme.surfaceContainerHighest, // For dropdown menu background
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.save_alt_outlined), // Changed icon for visual differentiation
              label: Text(_loading && !(_avatarUrl == null && _usernameController.text.isEmpty && _selectedGender == null) // Show "Guardando..." only for actual update operations
                  ? 'Guardando...'
                  : 'Actualizar Perfil'),
              onPressed: _loading ? null : _updateProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14.0),
                textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)), // Slightly more rounded
                elevation: _loading ? 0 : 3, // Material 3 style elevation
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 50, thickness: 1, indent: 20, endIndent: 20, color: colorScheme.outlineVariant.withOpacity(0.5)),
        TextButton.icon(
          icon: Icon(Icons.logout, color: colorScheme.error),
          label: Text(
            'Cerrar Sesión',
            style: textTheme.labelLarge?.copyWith(color: colorScheme.error, fontWeight: FontWeight.bold),
          ),
          onPressed: _loading ? null : _signOut,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
            overlayColor: colorScheme.error.withValues(alpha:1.1),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final isInitialLoading = _loading && _avatarUrl == null && _usernameController.text.isEmpty && _selectedGender == null;

    if (isInitialLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Perfil')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        elevation: 0, // Flatter look for app bar
        backgroundColor: Colors.transparent, // Transparent to blend with body or use surface color
        foregroundColor: colorScheme.onSurface,
      ),
      backgroundColor: colorScheme.surfaceContainerLowest, // Overall page background
      body: SafeArea( // Ensure content is not obscured by system UI
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0), // Adjusted top padding
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
                const SizedBox(height: 20), // Bottom padding
              ],
            ),
            if (_loading && !isInitialLoading)
              Container(
                color: colorScheme.scrim.withOpacity(0.3), // Using scrim color for overlay
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}