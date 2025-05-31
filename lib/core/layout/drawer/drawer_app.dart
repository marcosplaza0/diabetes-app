// Archivo: lib/core/layout/drawer/drawer_app.dart
// Descripción: Define el widget del Drawer (menú lateral) principal de la aplicación.
// Este Drawer muestra información del perfil del usuario (avatar, nombre, email),
// una lista de items de navegación cargados desde una configuración JSON,
// y una opción para cerrar sesión. Maneja la carga de datos del perfil,
// la lógica de cierre de sesión (incluyendo la sincronización opcional de datos pendientes),
// y reacciona a los cambios en el estado de autenticación.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:flutter/foundation.dart'; // Para Uint8List (bytes del avatar) y debugPrint.
import 'package:flutter/material.dart'; // Framework principal de Flutter para UI.
import 'package:go_router/go_router.dart'; // Para la navegación (ej. al perfil o al cambiar de sección).
import 'package:hive/hive.dart'; // Para acceder a las cajas de Hive (MealLog, OvernightLog) durante el logout.
import 'package:provider/provider.dart'; // Para acceder a UserProfileRepository.
import 'package:supabase_flutter/supabase_flutter.dart'; // Para Supabase (AuthChangeEvent).
import 'package:shared_preferences/shared_preferences.dart'; // Para leer SharedPreferences (ej. preferencia de guardado en nube).

// Importaciones de archivos del proyecto
import 'package:diabetes_2/data/repositories/user_profile_repository.dart'; // Repositorio para obtener datos del perfil.
import 'package:diabetes_2/core/utils/icon_helper.dart'; // Utilidad para obtener iconos por nombre.
import 'package:diabetes_2/main.dart' show supabase, mealLogBoxName, overnightLogBoxName; // Cliente Supabase y nombres de cajas.
import 'package:diabetes_2/core/layout/drawer/drawer_loader.dart'; // Para cargar los items del drawer desde JSON.
import 'package:diabetes_2/data/models/logs/logs.dart'; // Modelos MealLog y OvernightLog, para la lógica de logout.
import 'package:diabetes_2/core/services/supabase_log_sync_service.dart'; // Servicio para sincronizar logs.
import 'package:diabetes_2/core/widgets/loading_or_empty_state_widget.dart'; // Widget para estados de carga/vacío/error.

// Clave para SharedPreferences usada en la lógica de logout para determinar si el guardado en nube está activo.
const String cloudSavePreferenceKey = 'saveToCloudEnabled';

/// Enum LogoutPromptAction: Define las acciones que el usuario puede tomar en el diálogo de logout
/// cuando hay datos locales sin sincronizar y el guardado en la nube está desactivado.
enum LogoutPromptAction {
  uploadAndLogout,         // Subir datos y luego cerrar sesión.
  logoutWithoutUploading,  // Cerrar sesión sin subir datos.
  cancel,                  // Cancelar la operación de cierre de sesión.
}

/// DrawerApp: Un StatefulWidget que construye el Drawer principal de la aplicación.
///
/// Gestiona el estado relacionado con la visualización del perfil del usuario en el header del drawer,
/// la carga de los items de navegación, y el proceso de cierre de sesión.
class DrawerApp extends StatefulWidget {
  const DrawerApp({super.key});

  @override
  State<DrawerApp> createState() => _DrawerAppState();
}

class _DrawerAppState extends State<DrawerApp> {
  // Repositorio para acceder a los datos del perfil del usuario.
  late UserProfileRepository _userProfileRepository;

  // Variables de estado para la información del perfil mostrada en el header del drawer.
  String? _displayName; // Nombre de usuario.
  String? _displayEmail; // Email del usuario.
  Uint8List? _avatarBytes; // Bytes de la imagen del avatar (para MemoryImage).
  bool _initialLoadAttempted = false; // Indica si se ha intentado cargar el perfil al menos una vez.
  bool _isProcessingLogout = false; // Indica si se está procesando el cierre de sesión.

  // Servicio para sincronizar logs con Supabase, usado durante el cierre de sesión si es necesario.
  final SupabaseLogSyncService _logSyncService = SupabaseLogSyncService(); //

  @override
  /// initState: Se llama una vez cuando el widget se inserta en el árbol de widgets.
  ///
  /// Inicializa `_userProfileRepository` desde Provider.
  /// Llama a `_loadUserProfileData()` para cargar los datos del perfil.
  /// Se suscribe a `onAuthStateChange` de Supabase para reaccionar a cambios en el estado
  /// de autenticación (ej. inicio de sesión, cierre de sesión, actualización de usuario).
  void initState() {
    super.initState();
    // Obtiene la instancia de UserProfileRepository del Provider.
    _userProfileRepository = Provider.of<UserProfileRepository>(context, listen: false);
    _loadUserProfileData(); // Carga inicial de los datos del perfil.

    // Escucha los cambios en el estado de autenticación de Supabase.
    supabase.auth.onAuthStateChange.listen((data) { //
      final event = data.event; // Tipo de evento de autenticación (ej. signedIn, signedOut).
      debugPrint("Drawer: AuthChangeEvent - $event");
      if (mounted) { // Verifica si el widget sigue montado.
        // Si el evento indica un inicio de sesión, actualización de usuario, o sesión inicial/refrescada,
        // se recargan los datos del perfil.
        if (event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.userUpdated ||
            event == AuthChangeEvent.initialSession ||
            event == AuthChangeEvent.tokenRefreshed) {
          _loadUserProfileData();
        } else if (event == AuthChangeEvent.signedOut) {
          // Si el evento es un cierre de sesión, se limpian los datos del perfil en la UI.
          _handleUserSignedOut();
        }
      }
    });
  }

  /// _loadUserProfileData: Carga los datos del perfil del usuario (nombre, email, avatar).
  ///
  /// Utiliza `_userProfileRepository` para obtener los datos.
  /// Actualiza las variables de estado correspondientes para refrescar la UI del header del drawer.
  Future<void> _loadUserProfileData() async {
    if (!mounted) return;
    setState(() {
      _initialLoadAttempted = false; // Indica que se está intentando una nueva carga.
    });

    try {
      // Obtiene el perfil y los bytes del avatar desde el repositorio.
      final result = await _userProfileRepository.getCurrentUserProfile(); //
      if (mounted) {
        setState(() {
          _displayName = result.profile?.username; //
          _displayEmail = result.profile?.email; //
          _avatarBytes = result.avatarBytes;
          _initialLoadAttempted = true; // Marca que el intento de carga ha finalizado.
          debugPrint("Drawer: Perfil cargado desde repo. Nombre: $_displayName, Email: $_displayEmail, Avatar: ${result.avatarBytes != null}");
        });
      }
    } catch (e) {
      debugPrint("Drawer: Error cargando perfil desde repositorio: $e");
      if (mounted) {
        setState(() {
          // Muestra un estado de error si la carga falla.
          _displayName = "Error";
          _displayEmail = "No se pudo cargar el perfil";
          _avatarBytes = null;
          _initialLoadAttempted = true;
        });
      }
    }
  }

  /// _handleUserSignedOut: Limpia los datos del perfil en la UI cuando el usuario cierra sesión.
  ///
  /// Esto asegura que la información del usuario anterior no persista en el header del drawer.
  Future<void> _handleUserSignedOut() async {
    if (mounted) {
      setState(() {
        _displayName = null;
        _displayEmail = null;
        _avatarBytes = null;
        _initialLoadAttempted = true; // Importante para que no muestre "Cargando..." indefinidamente.
        debugPrint("Drawer: UI de perfil limpiada por deslogueo.");
      });
    }
  }

  /// _handleLogout: Gestiona el proceso de cierre de sesión.
  ///
  /// Lógica principal:
  /// 1. Comprueba si el guardado en la nube está activado (`cloudSavePreferenceKey`) y si hay datos locales sin sincronizar.
  /// 2. Si ambas condiciones se cumplen (guardado en nube OFF, datos locales PENDIENTES), muestra un diálogo al usuario
  ///    preguntando si desea subir los datos antes de cerrar sesión (`LogoutPromptAction`).
  /// 3. Si el usuario elige subir datos, los sincroniza usando `_logSyncService`.
  /// 4. Llama a `supabase.auth.signOut()` para cerrar la sesión en Supabase.
  /// 5. El evento `AuthChangeEvent.signedOut` (escuchado en `initState`) se encargará de llamar a `_handleUserSignedOut`
  ///    para limpiar la UI del perfil.
  Future<void> _handleLogout() async {
    if (_isProcessingLogout || !mounted) return; // Evita múltiples llamadas o si el widget no está montado.

    final prefs = await SharedPreferences.getInstance();
    // Obtiene la preferencia de guardado en la nube.
    final bool cloudSaveCurrentlyEnabled = prefs.getBool(cloudSavePreferenceKey) ?? false;

    // Accede a las cajas de Hive para verificar si hay datos locales.
    final mealLogBox = Hive.box<MealLog>(mealLogBoxName); //
    final overnightLogBox = Hive.box<OvernightLog>(overnightLogBoxName); //
    final bool hasLocalData = mealLogBox.isNotEmpty || overnightLogBox.isNotEmpty;
    final bool isLoggedIn = supabase.auth.currentUser != null; //

    LogoutPromptAction? userAction = LogoutPromptAction.logoutWithoutUploading; // Acción por defecto.

    // Si el usuario está logueado, el guardado en nube está DESACTIVADO, y hay datos locales:
    if (isLoggedIn && !cloudSaveCurrentlyEnabled && hasLocalData) {
      if (!mounted) return;
      // Muestra un diálogo al usuario.
      userAction = await showDialog<LogoutPromptAction>(
        context: context,
        barrierDismissible: false, // No permitir cerrar tocando fuera.
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Datos Locales Sin Sincronizar'),
            content: const Text('Tienes registros locales que no se han guardado en la nube. ¿Deseas subirlos antes de cerrar sesión?'),
            actions: <Widget>[
              TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(dialogContext).pop(LogoutPromptAction.cancel)),
              TextButton(child: const Text('Cerrar Sin Subir'), onPressed: () => Navigator.of(dialogContext).pop(LogoutPromptAction.logoutWithoutUploading)),
              ElevatedButton(child: const Text('Subir y Cerrar Sesión'), onPressed: () => Navigator.of(dialogContext).pop(LogoutPromptAction.uploadAndLogout)),
            ],
          );
        },
      );
    }

    if (!mounted || userAction == LogoutPromptAction.cancel) return; // Si el usuario cancela, no hacer nada.

    if (mounted) setState(() { _isProcessingLogout = true; }); // Inicia estado de procesamiento de logout.

    // Si el usuario eligió subir datos.
    if (userAction == LogoutPromptAction.uploadAndLogout) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subiendo datos a la nube...'), duration: Duration(seconds: 3)));
      }
      int successCount = 0; int errorCount = 0;
      try {
        // Sincroniza MealLogs.
        for (var entry in mealLogBox.toMap().entries) {
          try { await _logSyncService.syncMealLog(entry.value, entry.key); successCount++; } catch (e) { errorCount++; } //
        }
        // Sincroniza OvernightLogs.
        for (var entry in overnightLogBox.toMap().entries) {
          try { await _logSyncService.syncOvernightLog(entry.value, entry.key); successCount++; } catch (e) { errorCount++; } //
        }
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sincronización antes de logout completada. Éxitos: $successCount, Errores: $errorCount'), backgroundColor: errorCount > 0 ? Colors.orange : Colors.green));
      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al subir datos: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }

    // Procede a cerrar la sesión en Supabase.
    try {
      await supabase.auth.signOut(); //
      // El AuthStateChange listener se encargará de llamar a _handleUserSignedOut.
    } catch (e) {
      debugPrint("Error signing out desde Drawer: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cerrar sesión: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isProcessingLogout = false; }); // Finaliza estado de procesamiento.
    }
  }

  @override
  /// build: Construye la interfaz de usuario del Drawer.
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Colores para los items seleccionados y no seleccionados del drawer, según el tema.
    final drawerSelectedItemColor = theme.colorScheme.onPrimaryContainer;
    final drawerIndicatorColor = theme.colorScheme.primaryContainer;
    final drawerUnselectedItemColor = theme.colorScheme.onSurfaceVariant;

    Widget avatarDisplayWidget; // Widget para mostrar el avatar (o placeholder/loader).
    String nameForDisplay = _displayName ?? 'Usuario'; // Nombre a mostrar.
    String emailForDisplay = _displayEmail ?? ' '; // Email a mostrar.

    // Determina si se debe mostrar un estado de carga para el perfil.
    bool shouldShowLoading = (!_initialLoadAttempted && supabase.auth.currentUser != null) || //
        (_initialLoadAttempted && _displayName == null && supabase.auth.currentUser != null && !_isProcessingLogout); //


    if (shouldShowLoading) { // Si está cargando el perfil.
      nameForDisplay = 'Cargando...';
      emailForDisplay = ' ';
      avatarDisplayWidget = const CircleAvatar(radius: 30, child: CircularProgressIndicator(strokeWidth: 2.0));
    } else if (_avatarBytes != null) { // Si hay bytes de avatar, muéstralos.
      avatarDisplayWidget = CircleAvatar(radius: 30, backgroundImage: MemoryImage(_avatarBytes!), backgroundColor: Colors.transparent);
    } else { // Si no hay avatar, muestra un placeholder con la inicial del nombre.
      avatarDisplayWidget = CircleAvatar(
        radius: 30, backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          nameForDisplay.isNotEmpty ? nameForDisplay[0].toUpperCase() : (supabase.auth.currentUser != null ? 'U' : ''), //
          style: TextStyle(fontSize: 28, color: theme.colorScheme.onPrimaryContainer),
        ),
      );
    }

    // Si se está procesando el logout, muestra un loader en lugar del avatar.
    if (_isProcessingLogout) {
      avatarDisplayWidget = const CircleAvatar(radius: 30, child: CircularProgressIndicator(strokeWidth: 2.0));
    }

    return Drawer(
      backgroundColor: theme.colorScheme.surfaceContainerLow, // Color de fondo del drawer.
      child: Column(
        children: [
          // Header del Drawer con la información del usuario.
          UserAccountsDrawerHeader(
            accountName: Text(nameForDisplay, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
            accountEmail: Text(emailForDisplay, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            currentAccountPicture: avatarDisplayWidget, // El avatar (o placeholder/loader).
            decoration: BoxDecoration(color: theme.colorScheme.surface), // Color de fondo del header.
            otherAccountsPictures: [ // Botón para editar el perfil.
              IconButton(
                icon: Icon(Icons.edit_outlined, color: theme.colorScheme.onSurfaceVariant),
                tooltip: 'Editar Perfil',
                onPressed: _isProcessingLogout ? null : () {
                  Navigator.of(context).pop(); // Cierra el drawer.
                  // Navega a la pantalla de cuenta y, al volver, recarga los datos del perfil.
                  context.push('/account').then((_) { //
                    if (mounted) _loadUserProfileData();
                  });
                },
              ),
            ],
          ),
          // Cuerpo del Drawer con la lista de items de navegación.
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: DrawerLoader.loadDrawerItems(), // Carga los items del drawer desde JSON. //
              builder: (context, snapshot) {
                // Utiliza LoadingOrEmptyStateWidget para manejar los diferentes estados del FutureBuilder.
                return LoadingOrEmptyStateWidget( //
                  isLoading: snapshot.connectionState == ConnectionState.waiting && !_isProcessingLogout,
                  loadingText: "Cargando menú...",
                  hasError: snapshot.hasError,
                  error: snapshot.error,
                  errorMessage: snapshot.hasError ? "Error al cargar el menú." : null,
                  isEmpty: (!snapshot.hasData || snapshot.data!.isEmpty) && !(snapshot.connectionState == ConnectionState.waiting) && !snapshot.hasError,
                  emptyMessage: "No hay elementos en el menú.",
                  emptyIcon: Icons.list_alt_outlined,
                  childIfData: Builder( // Se usa Builder para asegurar que snapshot.data no es nulo aquí.
                      builder: (context) {
                        final items = snapshot.data!; // Lista de items del drawer.
                        final goRouter = GoRouter.of(context); // Instancia de GoRouter para obtener la ruta actual.
                        // Obtiene la URI actual para marcar el item seleccionado.
                        final currentUri = Uri.tryParse(goRouter.routerDelegate.currentConfiguration.uri.toString());
                        final currentLocation = currentUri?.path ?? '/';


                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            // Construye el item según su tipo (divider, padding, item de navegación).
                            if (item['type'] == 'divider') { // Divisor.
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Divider(height: 1, color: theme.colorScheme.outlineVariant),
                              );
                            } else if (item['type'] == 'padding') { // Espaciador.
                              return SizedBox(height: item['value'] as double? ?? 0.0);
                            } else if (item['type'] == 'item') { // Item de navegación.
                              final label = item['label'] as String? ?? 'Unnamed Item';
                              final iconKey = item['icon'] as String? ?? 'default_icon'; // Clave para IconHelper.
                              final route = item['route'] as String? ?? '/'; // Ruta de GoRouter.
                              final selected = currentLocation == route; // Determina si el item está seleccionado.

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.0),
                                child: ListTile(
                                  leading: Icon(
                                    IconHelper.getIcon(iconKey), // Obtiene el icono. //
                                    color: selected ? drawerSelectedItemColor : drawerUnselectedItemColor,
                                  ),
                                  title: Text(
                                    label,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: selected ? drawerSelectedItemColor : drawerUnselectedItemColor,
                                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)), // Forma M3.
                                  selected: selected,
                                  selectedTileColor: drawerIndicatorColor, // Color de fondo cuando está seleccionado.
                                  onTap: _isProcessingLogout ? null : () { // Deshabilitado si se está cerrando sesión.
                                    Navigator.of(context).pop(); // Cierra el drawer.
                                    if (!selected) context.go(route); // Navega si no es la ruta actual.
                                  },
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
                                ),
                              );
                            }
                            return const SizedBox.shrink(); // Si el tipo de item no es reconocido.
                          },
                        );
                      }
                  ),
                );
              },
            ),
          ),
          // Pie del Drawer con la opción de Cerrar Sesión.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal:12.0, vertical: 8.0),
            child: ListTile(
              leading: _isProcessingLogout // Muestra un loader o el icono de logout.
                  ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: drawerUnselectedItemColor))
                  : Icon(Icons.logout, color: drawerUnselectedItemColor),
              title: Text(
                  _isProcessingLogout ? 'Cerrando Sesión...' : 'Cerrar Sesión',
                  style: theme.textTheme.labelLarge?.copyWith(color: drawerUnselectedItemColor)
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
              onTap: _isProcessingLogout ? null : () { Navigator.of(context).pop(); _handleLogout(); }, // Llama a _handleLogout.
            ),
          )
        ],
      ),
    );
  }
}