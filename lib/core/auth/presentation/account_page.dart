// lib/core/auth/presentation/account_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Para Uint8List, aunque no se use directamente en la UI
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
// import 'package:shared_preferences/shared_preferences.dart'; // Ya no es necesario aquí
// import 'package:supabase_flutter/supabase_flutter.dart'; // No se usa SupabaseClient directamente aquí

import 'package:diabetes_2/core/layout/drawer/avatar.dart';
import 'package:diabetes_2/core/auth/presentation/account_view_model.dart'; // Importar ViewModel
// import 'package:diabetes_2/data/repositories/user_profile_repository.dart'; // Acceso via VM
// import 'package:diabetes_2/core/services/image_cache_service.dart'; // Acceso via VM
// import 'package:diabetes_2/data/models/logs/logs.dart'; // No directamente
// import 'package:diabetes_2/core/services/supabase_log_sync_service.dart'; // Acceso via VM
// import 'package:diabetes_2/main.dart' show supabase, mealLogBoxName, overnightLogBoxName; // No directamente

// AccountPageLogoutPromptAction y cloudSavePreferenceKeyFromAccountPage ahora están en el ViewModel o son importados de allí.


class AccountPage extends StatefulWidget { // Mantener StatefulWidget para mostrar Snackbars
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {

  // Los controladores de texto y estados ahora están en el ViewModel.
  // _usernameController, _selectedGender, _avatarUrl, _isProcessing...

  // Los servicios y repositorios se usan a través del ViewModel.

  // Lista de géneros para el Dropdown, puede ser estática o parte del ViewModel si se quiere
  final List<String> _genderOptions = ['Masculino', 'Femenino', 'Otro', 'Prefiero no decirlo'];


  @override
  void initState() {
    super.initState();
    // La carga inicial de datos la hace el ViewModel en su constructor.
    // Si hay un mensaje de feedback del ViewModel de una operación previa, limpiarlo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AccountViewModel>(context, listen: false).clearFeedback();
      // Opcional: Forzar una recarga si se vuelve a esta página y se quiere asegurar datos frescos
      // Provider.of<AccountViewModel>(context, listen: false).loadProfileData();
    });
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

  // Función para mostrar el diálogo de logout y devolver la elección del usuario
  Future<AccountPageLogoutPromptAction?> _showLogoutPromptDialog(BuildContext context) async {
    return await showDialog<AccountPageLogoutPromptAction>(
      context: context,
      barrierDismissible: false, // No permitir cerrar tocando fuera mientras se procesa
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


  Widget _buildAvatarDisplay(BuildContext context, AccountViewModel viewModel, ColorScheme colorScheme, TextTheme textTheme) {
    Widget avatarWidget;
    if (viewModel.isProcessing && viewModel.avatarUrl == null && viewModel.usernameController.text.isEmpty) {
      avatarWidget = const CircleAvatar(radius: 75, child: CircularProgressIndicator());
    } else {
      avatarWidget = Avatar(
          imageUrl: viewModel.avatarUrl,
          onUpload: (imageUrl) async { // onUpload ahora es async
            bool success = await viewModel.onAvatarUploaded(imageUrl);
            if (mounted && viewModel.feedbackMessage.isNotEmpty) {
              _showCustomSnackBar(viewModel.feedbackMessage, isError: viewModel.isErrorFeedback);
              viewModel.clearFeedback(); // Limpiar mensaje después de mostrarlo
            }
          }
      );
    }

    return Column(
      children: [
        Center(child: avatarWidget),
        const SizedBox(height: 16),
        // Usar el controller del ViewModel para el nombre de usuario
        // ya que _usernameController en el ViewModel se actualiza en loadProfileData
        // Si se quiere mostrar el nombre aquí directamente del ViewModel (si tuviera una propiedad para ello)
        // en lugar de del controller, se podría. Por ahora, el controller es la fuente.
        ValueListenableBuilder<TextEditingValue>(
            valueListenable: viewModel.usernameController,
            builder: (context, value, child) {
              if (value.text.isNotEmpty) {
                return Text(value.text, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface), textAlign: TextAlign.center);
              }
              return const SizedBox.shrink();
            }
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildProfileForm(BuildContext context, AccountViewModel viewModel, ColorScheme colorScheme, TextTheme textTheme) {
    bool canUpdate = !viewModel.isProcessing;
    return Card(
      elevation: 2, surfaceTintColor: colorScheme.surfaceTint, margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: viewModel.usernameController, // Usar controller del VM
              enabled: canUpdate,
              decoration: InputDecoration(labelText: 'Nombre de Usuario', hintText: 'Ingresa tu nombre de usuario', prefixIcon: Icon(Icons.person_outline, color: colorScheme.primary), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: colorScheme.primary, width: 2)), floatingLabelBehavior: FloatingLabelBehavior.auto),
              style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: viewModel.selectedGender, // Usar valor del VM
              items: _genderOptions.map((String gender) => DropdownMenuItem<String>(value: gender, child: Text(gender, style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant)))).toList(),
              onChanged: canUpdate ? (newValue) => viewModel.updateSelectedGender(newValue) : null, // Llamar método del VM
              decoration: InputDecoration(labelText: 'Género', prefixIcon: Icon(Icons.wc_outlined, color: colorScheme.primary), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: colorScheme.primary, width: 2)), floatingLabelBehavior: FloatingLabelBehavior.auto),
              style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface), dropdownColor: colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.save_alt_outlined),
              label: Text(viewModel.isProcessing ? 'Guardando...' : 'Actualizar Perfil'),
              onPressed: canUpdate ? () async {
                bool success = await viewModel.updateProfileDetails();
                if (mounted && viewModel.feedbackMessage.isNotEmpty) {
                  _showCustomSnackBar(viewModel.feedbackMessage, isError: viewModel.isErrorFeedback);
                  viewModel.clearFeedback();
                }
              } : null,
              style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary, padding: const EdgeInsets.symmetric(vertical: 14.0), textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)), elevation: viewModel.isProcessing ? 0 : 3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, AccountViewModel viewModel, ColorScheme colorScheme, TextTheme textTheme) {
    bool canSignOut = !viewModel.isProcessing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 50, thickness: 1, indent: 20, endIndent: 20, color: colorScheme.outlineVariant.withOpacity(0.5)),
        TextButton.icon(
          icon: Icon(Icons.logout, color: colorScheme.error),
          label: Text(viewModel.isProcessing ? 'Procesando...' : 'Cerrar Sesión', style: textTheme.labelLarge?.copyWith(color: colorScheme.error, fontWeight: FontWeight.bold)),
          onPressed: canSignOut ? () async {
            final result = await viewModel.handleLogout(() => _showLogoutPromptDialog(context));
            if (mounted) {
              if (result.message.isNotEmpty) {
                _showCustomSnackBar(result.message, isError: !result.success);
                viewModel.clearFeedback();
              }
              if (result.success) {
                // Navegación si el logout fue exitoso (ViewModel ya no puede hacerlo)
                // GoRouter se encargará de la redirección basada en el estado de autenticación.
                // Si se necesita navegación explícita aquí:
                if(context.mounted) GoRouter.of(context).go('/login');
              }
            }
          } : null,
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12.0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0))),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // Escuchar/Obtener el ViewModel
    final viewModel = context.watch<AccountViewModel>();

    // Mostrar SnackBar si hay un mensaje de feedback del ViewModel
    // Esto es una forma de hacerlo. Otra es que los métodos del VM devuelvan el mensaje
    // y la UI lo muestre. Aquí, el VM tiene una propiedad de feedback.
    // Se necesita un listener si el feedback se establece sin un rebuild directo de este widget.
    // Pero como usamos context.watch, si feedbackMessage cambia, se reconstruirá.
    // Es mejor mostrar el SnackBar en respuesta a la finalización del Future de la acción.

    // Si está cargando el perfil inicial y no hay datos para mostrar (ej. avatarUrl o usernameController vacío)
    if (viewModel.isProcessing && viewModel.avatarUrl == null && viewModel.usernameController.text.isEmpty) {
      return Scaffold(appBar: AppBar(title: const Text('Perfil')), body: const Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Perfil'), elevation: 0, backgroundColor: Colors.transparent, foregroundColor: colorScheme.onSurface),
      backgroundColor: colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: Stack(children: [
          ListView(padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0), children: [
            _buildAvatarDisplay(context, viewModel, colorScheme, textTheme), const SizedBox(height: 24),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0), child: Text('Información Personal', style: textTheme.titleMedium?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w600))),
            const SizedBox(height: 12),
            _buildProfileForm(context, viewModel, colorScheme, textTheme), const SizedBox(height: 24),
            _buildActionButtons(context, viewModel, colorScheme, textTheme), const SizedBox(height: 20),
          ]),
          if (viewModel.isProcessing) Container(color: colorScheme.scrim.withOpacity(0.3), child: const Center(child: CircularProgressIndicator())),
        ]),
      ),
    );
  }
}