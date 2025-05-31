// Archivo: lib/core/auth/presentation/account_page.dart
// Descripción: Define la interfaz de usuario para la pantalla de gestión de la cuenta del usuario.
// En esta pantalla, el usuario puede ver y editar su nombre de usuario, género,
// y actualizar su imagen de perfil (avatar). También proporciona la opción de cerrar sesión.
// La lógica de negocio y el estado son gestionados por AccountViewModel.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:flutter/material.dart'; // Framework principal de Flutter para UI.
import 'package:provider/provider.dart'; // Para acceder al AccountViewModel.
import 'package:go_router/go_router.dart'; // Para la navegación (ej. después de cerrar sesión).

// Importaciones de archivos del proyecto
import 'package:DiabetiApp/core/layout/drawer/avatar.dart'; // Widget para mostrar y actualizar el avatar.
import 'package:DiabetiApp/core/auth/presentation/account_view_model.dart'; // ViewModel para esta pantalla.

/// AccountPage: Un StatefulWidget que construye la UI para la pantalla de cuenta.
///
/// Aunque gran parte del estado se maneja en `AccountViewModel`, se mantiene como
/// StatefulWidget para poder mostrar SnackBars de forma controlada y manejar
/// diálogos que podrían depender del ciclo de vida del widget o del `BuildContext`
/// de una manera más directa si fuera necesario (aunque aquí los diálogos son simples).
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  // Los controladores de texto (ej. para username) y el estado de la UI
  // (ej. _selectedGender, _avatarUrl, _isProcessing) ahora residen en AccountViewModel.

  // Lista de opciones para el selector de género. Podría ser estática o parte del ViewModel
  // si se quisiera cargar dinámicamente o localizar.
  final List<String> _genderOptions = ['Masculino', 'Femenino', 'Otro', 'Prefiero no decirlo'];


  @override
  /// initState: Se llama una vez cuando el widget se inserta en el árbol de widgets.
  ///
  /// La carga inicial de datos del perfil la realiza el `AccountViewModel` en su constructor
  /// o en un método llamado por él. Aquí, se asegura que cualquier mensaje de feedback
  /// persistente del ViewModel (de una operación anterior en otra pantalla, por ejemplo)
  /// se limpie al entrar en esta pantalla.
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Limpia cualquier mensaje de feedback previo en el ViewModel.
      // `listen: false` porque solo queremos llamar al método.
      Provider.of<AccountViewModel>(context, listen: false).clearFeedback(); //
    });
  }

  /// _showCustomSnackBar: Muestra un SnackBar personalizado con un mensaje.
  ///
  /// @param message El texto a mostrar.
  /// @param isError Indica si el mensaje es de error (para cambiar el color de fondo).
  void _showCustomSnackBar(String message, {bool isError = false}) {
    if (!mounted) return; // No mostrar si el widget no está montado.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating, // SnackBar flotante.
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Bordes redondeados.
        margin: const EdgeInsets.all(10), // Margen alrededor del SnackBar.
      ),
    );
  }

  /// _showLogoutPromptDialog: Muestra un diálogo de confirmación antes de cerrar sesión si hay datos sin sincronizar.
  ///
  /// Este método es pasado como una función al `handleLogout` del ViewModel.
  /// El ViewModel decide si llamar a esta función basado en su propia lógica
  /// (ej. si el guardado en la nube está deshabilitado pero hay datos locales).
  ///
  /// @param context El BuildContext para mostrar el diálogo.
  /// @return Un `Future` que resuelve a `AccountPageLogoutPromptAction?`, indicando la elección del usuario.
  Future<AccountPageLogoutPromptAction?> _showLogoutPromptDialog(BuildContext context) async { //
    return await showDialog<AccountPageLogoutPromptAction>( //
      context: context,
      barrierDismissible: false, // No permitir cerrar tocando fuera mientras se procesa.
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Datos Locales Sin Sincronizar'),
          content: const Text('Tienes registros locales que no se han guardado en la nube. ¿Deseas subirlos antes de cerrar sesión?'),
          actions: <Widget>[
            TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(dialogContext).pop(AccountPageLogoutPromptAction.cancel)), //
            TextButton(child: const Text('Cerrar Sin Subir'), onPressed: () => Navigator.of(dialogContext).pop(AccountPageLogoutPromptAction.logoutWithoutUploading)), //
            ElevatedButton(child: const Text('Subir y Cerrar Sesión'), onPressed: () => Navigator.of(dialogContext).pop(AccountPageLogoutPromptAction.uploadAndLogout)), //
          ],
        );
      },
    );
  }

  /// _buildAvatarDisplay: Construye la sección de visualización y carga del avatar.
  ///
  /// Utiliza el widget `Avatar` y se conecta con los métodos del `AccountViewModel`
  /// para manejar la subida de una nueva imagen de perfil.
  ///
  /// @param context El BuildContext.
  /// @param viewModel La instancia de `AccountViewModel`.
  /// @param colorScheme El esquema de colores del tema actual.
  /// @param textTheme Los estilos de texto del tema actual.
  /// @return Un Column widget con el avatar y el nombre de usuario.
  Widget _buildAvatarDisplay(BuildContext context, AccountViewModel viewModel, ColorScheme colorScheme, TextTheme textTheme) {
    Widget avatarWidget;
    // Muestra un indicador de progreso si se está cargando el perfil inicial y no hay datos de avatar/nombre.
    if (viewModel.isProcessing && viewModel.avatarUrl == null && viewModel.usernameController.text.isEmpty) { //
      avatarWidget = const CircleAvatar(radius: 75, child: CircularProgressIndicator());
    } else {
      // Utiliza el widget Avatar, pasándole la URL del avatar desde el ViewModel.
      avatarWidget = Avatar( //
          imageUrl: viewModel.avatarUrl, //
          onUpload: (imageUrl) async { // Callback cuando se sube una nueva imagen. //
            // Llama al método del ViewModel para manejar la URL de la imagen subida.
            bool success = await viewModel.onAvatarUploaded(imageUrl); //
            // Muestra feedback (SnackBar) si el ViewModel ha establecido un mensaje.
            if (mounted && viewModel.feedbackMessage.isNotEmpty) { //
              _showCustomSnackBar(viewModel.feedbackMessage, isError: viewModel.isErrorFeedback); //
              viewModel.clearFeedback(); // Limpia el mensaje del ViewModel después de mostrarlo. //
            }
          }
      );
    }

    return Column(
      children: [
        Center(child: avatarWidget), // Avatar centrado.
        const SizedBox(height: 16),
        // Muestra el nombre de usuario obtenido del controlador de texto en el ViewModel.
        // ValueListenableBuilder escucha cambios en el controlador para actualizar el nombre dinámicamente.
        ValueListenableBuilder<TextEditingValue>(
            valueListenable: viewModel.usernameController, //
            builder: (context, value, child) {
              if (value.text.isNotEmpty) {
                return Text(value.text, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface), textAlign: TextAlign.center);
              }
              return const SizedBox.shrink(); // No mostrar nada si el nombre está vacío.
            }
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  /// _buildProfileForm: Construye el formulario para editar los detalles del perfil (nombre, género).
  ///
  /// @param context El BuildContext.
  /// @param viewModel La instancia de `AccountViewModel`.
  /// @param colorScheme El esquema de colores del tema.
  /// @param textTheme Los estilos de texto del tema.
  /// @return Un Card widget con los campos del formulario y el botón de actualizar.
  Widget _buildProfileForm(BuildContext context, AccountViewModel viewModel, ColorScheme colorScheme, TextTheme textTheme) {
    // Los campos y el botón se deshabilitan si el ViewModel está procesando una operación.
    bool canUpdate = !viewModel.isProcessing; //
    return Card(
      elevation: 2, surfaceTintColor: colorScheme.surfaceTint, margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Campo para el Nombre de Usuario.
            TextFormField(
              controller: viewModel.usernameController, // Vinculado al controlador del ViewModel. //
              enabled: canUpdate, // Habilitado/deshabilitado según `canUpdate`.
              decoration: InputDecoration(labelText: 'Nombre de Usuario', hintText: 'Ingresa tu nombre de usuario', prefixIcon: Icon(Icons.person_outline, color: colorScheme.primary), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: colorScheme.primary, width: 2)), floatingLabelBehavior: FloatingLabelBehavior.auto),
              style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
            ),
            const SizedBox(height: 20),
            // Campo para seleccionar el Género (Dropdown).
            DropdownButtonFormField<String>(
              value: viewModel.selectedGender, // Valor actual del género desde el ViewModel. //
              items: _genderOptions.map((String gender) => DropdownMenuItem<String>(value: gender, child: Text(gender, style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant)))).toList(),
              onChanged: canUpdate ? (newValue) => viewModel.updateSelectedGender(newValue) : null, // Llama al método del VM para actualizar el género. //
              decoration: InputDecoration(labelText: 'Género', prefixIcon: Icon(Icons.wc_outlined, color: colorScheme.primary), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0), borderSide: BorderSide(color: colorScheme.primary, width: 2)), floatingLabelBehavior: FloatingLabelBehavior.auto),
              style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface), dropdownColor: colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 24),
            // Botón para Actualizar Perfil.
            ElevatedButton.icon(
              icon: const Icon(Icons.save_alt_outlined),
              label: Text(viewModel.isProcessing ? 'Guardando...' : 'Actualizar Perfil'), // Texto dinámico según estado de procesamiento. //
              onPressed: canUpdate ? () async {
                // Llama al método de actualización del perfil en el ViewModel.
                bool success = await viewModel.updateProfileDetails(); //
                // Muestra feedback.
                if (mounted && viewModel.feedbackMessage.isNotEmpty) { //
                  _showCustomSnackBar(viewModel.feedbackMessage, isError: viewModel.isErrorFeedback); //
                  viewModel.clearFeedback(); //
                }
              } : null,
              style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary, padding: const EdgeInsets.symmetric(vertical: 14.0), textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)), elevation: viewModel.isProcessing ? 0 : 3), //
            ),
          ],
        ),
      ),
    );
  }

  /// _buildActionButtons: Construye los botones de acción (ej. Cerrar Sesión).
  ///
  /// @param context El BuildContext.
  /// @param viewModel La instancia de `AccountViewModel`.
  /// @param colorScheme El esquema de colores del tema.
  /// @param textTheme Los estilos de texto del tema.
  /// @return Un Column widget con los botones de acción.
  Widget _buildActionButtons(BuildContext context, AccountViewModel viewModel, ColorScheme colorScheme, TextTheme textTheme) {
    // El botón de cerrar sesión se deshabilita si el ViewModel está procesando.
    bool canSignOut = !viewModel.isProcessing; //
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 50, thickness: 1, indent: 20, endIndent: 20, color: colorScheme.outlineVariant.withValues(alpha:0.5)), // Separador visual.
        // Botón para Cerrar Sesión.
        TextButton.icon(
          icon: Icon(Icons.logout, color: colorScheme.error), // Icono de cerrar sesión.
          label: Text(viewModel.isProcessing ? 'Procesando...' : 'Cerrar Sesión', style: textTheme.labelLarge?.copyWith(color: colorScheme.error, fontWeight: FontWeight.bold)), //
          onPressed: canSignOut ? () async {
            // Llama al método de logout del ViewModel.
            // Pasa la función `_showLogoutPromptDialog` para que el ViewModel la invoque si es necesario.
            final result = await viewModel.handleLogout(() => _showLogoutPromptDialog(context)); //
            if (mounted) { // Si el widget sigue montado después de la operación.
              // Muestra feedback del resultado del logout.
              if (result.message.isNotEmpty) {
                _showCustomSnackBar(result.message, isError: !result.success);
                viewModel.clearFeedback(); // Limpia el mensaje del ViewModel. //
              }
              if (result.success) { // Si el logout fue exitoso.
                // GoRouter se encargará de la redirección a /login basado en el estado de autenticación.
                // Si se necesitara navegación explícita aquí (poco común con GoRouter redirect):
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
  /// build: Construye la interfaz de usuario principal de la pantalla de Cuenta.
  ///
  /// Utiliza `Consumer` (o `context.watch`) para escuchar cambios en `AccountViewModel`
  /// y reconstruir la UI cuando sea necesario.
  /// Organiza las secciones de avatar, formulario de perfil y botones de acción.
  /// Muestra un indicador de progreso global si el ViewModel está en estado de carga inicial.
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // `context.watch` se suscribe a los cambios del AccountViewModel.
    final viewModel = context.watch<AccountViewModel>();

    // Muestra un indicador de progreso si se está cargando el perfil inicial y no hay datos para mostrar.
    if (viewModel.isProcessing && viewModel.avatarUrl == null && viewModel.usernameController.text.isEmpty) { //
      return Scaffold(appBar: AppBar(title: const Text('Perfil')), body: const Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Perfil'), elevation: 0, backgroundColor: Colors.transparent, foregroundColor: colorScheme.onSurface),
      backgroundColor: colorScheme.surfaceContainerLowest, // Color de fondo de la pantalla.
      body: SafeArea( // Asegura que el contenido no se solape con elementos del sistema (ej. notch).
        child: Stack(children: [ // Stack para superponer el indicador de progreso global si es necesario.
          ListView( // Contenido principal desplazable.
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0),
              children: [
                _buildAvatarDisplay(context, viewModel, colorScheme, textTheme), // Sección del avatar.
                const SizedBox(height: 24),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text('Información Personal', style: textTheme.titleMedium?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w600))
                ),
                const SizedBox(height: 12),
                _buildProfileForm(context, viewModel, colorScheme, textTheme), // Formulario de perfil.
                const SizedBox(height: 24),
                _buildActionButtons(context, viewModel, colorScheme, textTheme), // Botones de acción (cerrar sesión).
                const SizedBox(height: 20),
              ]
          ),
          // Muestra un overlay de carga si el ViewModel está procesando una operación.
          if (viewModel.isProcessing) //
            Container(
                color: colorScheme.scrim.withValues(alpha:0.3), // Fondo semi-transparente.
                child: const Center(child: CircularProgressIndicator()) // Indicador de progreso centrado.
            ),
        ]),
      ),
    );
  }
}