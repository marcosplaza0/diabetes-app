// lib/core/layout/drawer/drawer_app.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Para SharedPreferences en logout
// Ya no se necesita Hive directamente para UserProfileData aquí
// import 'package:hive_flutter/hive_flutter.dart';

import 'package:diabetes_2/data/models/profile/user_profile_data.dart'; // Para el tipo, aunque el repo lo devuelve
import 'package:diabetes_2/data/repositories/user_profile_repository.dart'; // Importar el repositorio
import 'package:diabetes_2/core/utils/icon_helper.dart';
import 'package:diabetes_2/main.dart' show supabase, mealLogBoxName, overnightLogBoxName; // Para supabase y cajas de logs en logout
import 'drawer_loader.dart';
import 'package:diabetes_2/data/models/logs/logs.dart'; // Para logout
import 'package:diabetes_2/core/services/supabase_log_sync_service.dart'; // Para logout

const String cloudSavePreferenceKey = 'saveToCloudEnabled'; // Para logout

enum LogoutPromptAction {
  uploadAndLogout,
  logoutWithoutUploading,
  cancel,
}

class DrawerApp extends StatefulWidget {
  const DrawerApp({super.key});

  @override
  State<DrawerApp> createState() => _DrawerAppState();
}

class _DrawerAppState extends State<DrawerApp> {
  late UserProfileRepository _userProfileRepository;

  String? _displayName;
  String? _displayEmail;
  Uint8List? _avatarBytes;
  bool _initialLoadAttempted = false;
  bool _isProcessingLogout = false;

  // SupabaseLogSyncService se sigue necesitando para la lógica de logout de logs
  final SupabaseLogSyncService _logSyncService = SupabaseLogSyncService();

  @override
  void initState() {
    super.initState();
    _userProfileRepository = Provider.of<UserProfileRepository>(context, listen: false);
    _loadUserProfileData(); // Cargar datos al iniciar

    supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      debugPrint("Drawer: AuthChangeEvent - $event");
      if (mounted) {
        if (event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.userUpdated ||
            event == AuthChangeEvent.initialSession ||
            event == AuthChangeEvent.tokenRefreshed) {
          _loadUserProfileData(); // Recargar datos del perfil
        } else if (event == AuthChangeEvent.signedOut) {
          _handleUserSignedOut(); // Limpiar datos locales del perfil y UI
        }
      }
    });
  }

  Future<void> _loadUserProfileData() async {
    if (!mounted) return;
    setState(() {
      // Opcional: Mostrar un estado de carga si se desea una realimentación más explícita
      // _displayName = 'Cargando...';
      // _displayEmail = '';
      // _avatarBytes = null;
      _initialLoadAttempted = false; // Indicar que se está intentando cargar
    });

    try {
      final result = await _userProfileRepository.getCurrentUserProfile();
      if (mounted) {
        setState(() {
          _displayName = result.profile?.username;
          _displayEmail = result.profile?.email;
          _avatarBytes = result.avatarBytes;
          _initialLoadAttempted = true;
          debugPrint("Drawer: Perfil cargado desde repo. Nombre: ${_displayName}, Email: ${_displayEmail}, Avatar: ${result.avatarBytes != null}");
        });
      }
    } catch (e) {
      debugPrint("Drawer: Error cargando perfil desde repositorio: $e");
      if (mounted) {
        setState(() {
          _displayName = "Error";
          _displayEmail = "No se pudo cargar el perfil";
          _avatarBytes = null;
          _initialLoadAttempted = true;
        });
      }
    }
  }

  Future<void> _handleUserSignedOut() async {
    // El UserProfileRepository ya se encarga de limpiar su parte en getCurrentUserProfile si no hay user.
    // Pero para un logout explícito, podemos llamar a clearLocalUserProfile.
    // La AuthStateChange ya dispara la limpieza de la UI si el usuario es null.
    // await _userProfileRepository.clearLocalUserProfile(); // Opcional, ya que _loadUserProfileData se llamará y no encontrará usuario
    if (mounted) {
      setState(() {
        _displayName = null;
        _displayEmail = null;
        _avatarBytes = null;
        _initialLoadAttempted = true; // Marcar como intentado para que no muestre "Cargando..."
        debugPrint("Drawer: UI de perfil limpiada por deslogueo.");
      });
    }
  }

  // _syncProfileWithSupabaseInBackground y _loadInitialDataFromHiveAndUpdateState
  // son reemplazados por _loadUserProfileData y la lógica dentro del repositorio.

  Future<void> _handleLogout() async {
    if (_isProcessingLogout || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final bool cloudSaveCurrentlyEnabled = prefs.getBool(cloudSavePreferenceKey) ?? false;

    final mealLogBox = Hive.box<MealLog>(mealLogBoxName);
    final overnightLogBox = Hive.box<OvernightLog>(overnightLogBoxName);
    final bool hasLocalData = mealLogBox.isNotEmpty || overnightLogBox.isNotEmpty;
    final bool isLoggedIn = supabase.auth.currentUser != null;

    LogoutPromptAction? userAction = LogoutPromptAction.logoutWithoutUploading;

    if (isLoggedIn && !cloudSaveCurrentlyEnabled && hasLocalData) {
      if (!mounted) return; // Check mounted before showing dialog
      userAction = await showDialog<LogoutPromptAction>(
        context: context, // Use the widget's context
        barrierDismissible: false,
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

    if (!mounted || userAction == LogoutPromptAction.cancel) return;

    if (mounted) setState(() { _isProcessingLogout = true; }); // Mover setState aquí

    if (userAction == LogoutPromptAction.uploadAndLogout) {
      if (mounted) { // Re-check mounted before ScaffoldMessenger
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subiendo datos a la nube...'), duration: Duration(seconds: 3)));
      }
      int successCount = 0; int errorCount = 0;
      try {
        for (var entry in mealLogBox.toMap().entries) {
          try { await _logSyncService.syncMealLog(entry.value, entry.key); successCount++; } catch (e) { errorCount++; }
        }
        for (var entry in overnightLogBox.toMap().entries) {
          try { await _logSyncService.syncOvernightLog(entry.value, entry.key); successCount++; } catch (e) { errorCount++; }
        }
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sincronización antes de logout completada. Éxitos: $successCount, Errores: $errorCount'), backgroundColor: errorCount > 0 ? Colors.orange : Colors.green));
      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al subir datos: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }

    try {
      await supabase.auth.signOut();
      // onAuthStateChange se encargará de llamar a _handleUserSignedOut que limpia la UI.
      // y _userProfileRepository.clearLocalUserProfile() si es necesario.
    } catch (e) {
      debugPrint("Error signing out desde Drawer: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cerrar sesión: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isProcessingLogout = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final drawerSelectedItemColor = theme.colorScheme.onPrimaryContainer;
    final drawerIndicatorColor = theme.colorScheme.primaryContainer;
    final drawerUnselectedItemColor = theme.colorScheme.onSurfaceVariant;

    Widget avatarDisplayWidget;
    String nameForDisplay = _displayName ?? 'Usuario';
    String emailForDisplay = _displayEmail ?? ' ';

    // Si no se ha intentado cargar y hay un usuario, o si se intentó pero no hay email y hay usuario
    bool shouldShowLoading = (!_initialLoadAttempted && supabase.auth.currentUser != null) ||
        (_initialLoadAttempted && _displayName == null && supabase.auth.currentUser != null && !_isProcessingLogout);


    if (shouldShowLoading) {
      nameForDisplay = 'Cargando...';
      emailForDisplay = ' ';
      avatarDisplayWidget = const CircleAvatar(radius: 30, child: CircularProgressIndicator(strokeWidth: 2.0));
    } else if (_avatarBytes != null) {
      avatarDisplayWidget = CircleAvatar(radius: 30, backgroundImage: MemoryImage(_avatarBytes!), backgroundColor: Colors.transparent);
    } else {
      avatarDisplayWidget = CircleAvatar(
        radius: 30, backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          nameForDisplay.isNotEmpty ? nameForDisplay[0].toUpperCase() : (supabase.auth.currentUser != null ? 'U' : ''),
          style: TextStyle(fontSize: 28, color: theme.colorScheme.onPrimaryContainer),
        ),
      );
    }

    if (_isProcessingLogout) {
      avatarDisplayWidget = const CircleAvatar(radius: 30, child: CircularProgressIndicator(strokeWidth: 2.0));
    }

    return Drawer(
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(nameForDisplay, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
            accountEmail: Text(emailForDisplay, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            currentAccountPicture: avatarDisplayWidget,
            decoration: BoxDecoration(color: theme.colorScheme.surface),
            otherAccountsPictures: [
              IconButton(
                icon: Icon(Icons.edit_outlined, color: theme.colorScheme.onSurfaceVariant),
                tooltip: 'Editar Perfil',
                onPressed: _isProcessingLogout ? null : () {
                  Navigator.of(context).pop();
                  context.push('/account').then((_) {
                    // Después de volver de /account, recargar el perfil
                    if (mounted) _loadUserProfileData();
                  });
                },
              ),
            ],
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: DrawerLoader.loadDrawerItems(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !_isProcessingLogout) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) return Center(child: Text('Error al cargar el menú: ${snapshot.error}'));
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('No hay elementos en el menú.'));

                final items = snapshot.data!;
                final goRouter = GoRouter.of(context);
                final currentLocation = Uri.parse(goRouter.routerDelegate.currentConfiguration.uri.toString()).path;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    if (item['type'] == 'divider') return Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Divider(height: 1, color: theme.colorScheme.outlineVariant));
                    if (item['type'] == 'padding') return SizedBox(height: item['value'] as double? ?? 0.0);
                    if (item['type'] == 'item') {
                      final label = item['label'] as String? ?? 'Unnamed Item';
                      final iconKey = item['icon'] as String? ?? 'default_icon';
                      final route = item['route'] as String? ?? '/';
                      final selected = currentLocation == route;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: ListTile(
                          leading: Icon(IconHelper.getIcon(iconKey), color: selected ? drawerSelectedItemColor : drawerUnselectedItemColor),
                          title: Text(label, style: theme.textTheme.labelLarge?.copyWith(color: selected ? drawerSelectedItemColor : drawerUnselectedItemColor, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                          selected: selected, selectedTileColor: drawerIndicatorColor,
                          onTap: _isProcessingLogout ? null : () { Navigator.of(context).pop(); if (!selected) context.go(route); },
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal:12.0, vertical: 8.0),
            child: ListTile(
              leading: _isProcessingLogout ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: drawerUnselectedItemColor)) : Icon(Icons.logout, color: drawerUnselectedItemColor),
              title: Text(_isProcessingLogout ? 'Cerrando Sesión...' : 'Cerrar Sesión', style: theme.textTheme.labelLarge?.copyWith(color: drawerUnselectedItemColor)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
              onTap: _isProcessingLogout ? null : () { Navigator.of(context).pop(); _handleLogout(); },
            ),
          )
        ],
      ),
    );
  }
}