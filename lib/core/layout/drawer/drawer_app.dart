import 'package:flutter/foundation.dart'; // Para debugPrint y listEquals (opcional)
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';

import 'package:diabetes_2/data/models/profile/user_profile_data.dart';
import 'package:diabetes_2/core/services/image_cache_service.dart';
import 'package:diabetes_2/core/utils/icon_helper.dart';
import 'package:diabetes_2/main.dart' show supabase, userProfileBoxName;
import 'drawer_loader.dart';

class DrawerApp extends StatefulWidget {
  const DrawerApp({super.key});

  @override
  State<DrawerApp> createState() => _DrawerAppState();
}

class _DrawerAppState extends State<DrawerApp> {
  late Box<UserProfileData> _userProfileBox;
  final String _userProfileHiveKey = 'currentUserProfile';

  // Estado local para la UI instantánea
  String? _displayName;
  String? _displayEmail;
  Uint8List? _avatarBytes;
  bool _initialLoadAttempted = false; // Para saber si ya intentamos la carga síncrona de Hive

  // Futuro para la sincronización en segundo plano
  Future<void>? _profileSyncFuture;

  @override
  void initState() {
    super.initState();
    _userProfileBox = Hive.box<UserProfileData>(userProfileBoxName);

    // Carga inicial síncrona (o lo más rápido posible) y luego inicia la sincronización
    _loadInitialDataFromHiveAndUpdateState();
    _profileSyncFuture = _syncProfileWithSupabaseInBackground();

    supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      debugPrint("Drawer: AuthChangeEvent - $event");
      if (mounted) {
        if (event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.userUpdated ||
            event == AuthChangeEvent.initialSession ||
            event == AuthChangeEvent.tokenRefreshed) {
          _loadInitialDataFromHiveAndUpdateState(); // Recargar datos de Hive para la UI
          _profileSyncFuture = _syncProfileWithSupabaseInBackground(); // Reiniciar sincronización
        } else if (event == AuthChangeEvent.signedOut) {
          _clearLocalProfileDataAndState();
        }
      }
    });
  }

  void _clearLocalProfileDataAndState() {
    _userProfileBox.delete(_userProfileHiveKey).then((_) {
      debugPrint("Drawer: Perfil de Hive borrado.");
    });
    if (mounted) {
      setState(() {
        _displayName = null;
        _displayEmail = null;
        _avatarBytes = null;
        _initialLoadAttempted = true; // Marcamos que se intentó (y ahora está vacío)
      });
    }
  }

  Future<void> _loadInitialDataFromHiveAndUpdateState() async {
    if (!mounted) return;
    final imageCacheService = Provider.of<ImageCacheService>(context, listen: false);
    final currentUser = supabase.auth.currentUser;

    String? nameFromHive;
    String? emailFromHive;
    Uint8List? avatarFromHiveCache;

    if (currentUser != null) {
      UserProfileData? hiveProfile = _userProfileBox.get(_userProfileHiveKey);

      // Validar que el perfil en Hive corresponde al usuario actual
      if (hiveProfile != null && hiveProfile.email != currentUser.email) {
        debugPrint("Drawer (InitialLoad): Perfil en Hive (${hiveProfile.email}) no coincide con usuario actual (${currentUser.email}). Se ignorará.");
        _userProfileBox.delete(_userProfileHiveKey); // Limpiar perfil obsoleto
        hiveProfile = null;
      }

      if (hiveProfile != null) {
        nameFromHive = hiveProfile.username;
        emailFromHive = hiveProfile.email; // Debería coincidir con currentUser.email
        if (hiveProfile.avatarCacheKey != null && hiveProfile.avatarCacheKey!.isNotEmpty) {
          // .getImage() es síncrono si la imagen está en la caché de Hive
          avatarFromHiveCache = await imageCacheService.getImage(hiveProfile.avatarCacheKey!);
        }
        debugPrint("Drawer (InitialLoad): Datos de Hive: Nombre='${nameFromHive}', Email='${emailFromHive}', AvatarKey='${hiveProfile.avatarCacheKey}', AvatarCargado=${avatarFromHiveCache != null}");
      } else {
        debugPrint("Drawer (InitialLoad): No hay perfil en Hive para ${currentUser.email} o no coincide.");
      }
    } else {
      // No hay usuario, asegurarse que el estado local esté limpio
      _clearLocalProfileDataAndState();
      return; // Salir si no hay usuario
    }

    // Actualizar el estado de la UI con los datos obtenidos (o fallbacks)
    // Esto debería causar una reconstrucción casi inmediata si los datos están en Hive
    setState(() {
      _displayName = nameFromHive ?? currentUser.email?.split('@').first ?? 'Usuario';
      _displayEmail = emailFromHive ?? currentUser.email;
      _avatarBytes = avatarFromHiveCache;
      _initialLoadAttempted = true;
    });
  }

  Future<void> _syncProfileWithSupabaseInBackground() async {
    if (!mounted) return;
    final imageCacheService = Provider.of<ImageCacheService>(context, listen: false);
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      debugPrint("Drawer (Sync): No hay usuario para sincronizar.");
      // Asegurarse de que si no hay usuario, los datos locales también se limpien
      // _loadInitialDataFromHiveAndUpdateState ya debería haber manejado esto si se llama en auth change.
      if (_displayName != null || _displayEmail != null || _avatarBytes != null) {
        _clearLocalProfileDataAndState();
      }
      return;
    }

    try {
      debugPrint("Drawer (Sync): Sincronizando perfil con Supabase para ${currentUser.id}...");
      final dbProfileData = await supabase
          .from('profiles')
          .select('username, avatar_url')
          .eq('id', currentUser.id)
          .single();

      String supabaseUsername = dbProfileData['username'] as String? ?? currentUser.email?.split('@').first ?? 'Usuario';
      String supabaseUserEmail = currentUser.email!; // Sabemos que no es null aquí
      String? supabaseAvatarUrl = dbProfileData['avatar_url'] as String?;
      String? newAvatarCacheKey;
      Uint8List? newAvatarBytes = _avatarBytes; // Empezar con los bytes actuales

      if (supabaseAvatarUrl != null && supabaseAvatarUrl.isNotEmpty) {
        newAvatarCacheKey = imageCacheService.extractFilePathFromUrl(supabaseAvatarUrl);
        if (newAvatarCacheKey != null) {
          // Comprobar si la clave del avatar ha cambiado o si no teníamos bytes antes
          final currentHiveProfile = _userProfileBox.get(_userProfileHiveKey);
          if (currentHiveProfile?.avatarCacheKey != newAvatarCacheKey || newAvatarBytes == null) {
            newAvatarBytes = await imageCacheService.getImage(newAvatarCacheKey); // Intenta síncrono primero
            if (newAvatarBytes == null) { // Si no está en caché, descarga
              debugPrint("Drawer (Sync): Avatar no en caché ('$newAvatarCacheKey'), descargando de Supabase...");
              newAvatarBytes = await imageCacheService.downloadAndCacheImage(newAvatarCacheKey, supabaseAvatarUrl);
            }
          }
        }
      } else { // No hay avatar_url en Supabase, así que no debería haber avatar localmente
        newAvatarCacheKey = null;
        newAvatarBytes = null;
      }

      // Guardar los datos actualizados de Supabase en Hive
      UserProfileData profileToSaveInHive = UserProfileData(
        username: supabaseUsername,
        email: supabaseUserEmail,
        avatarCacheKey: newAvatarCacheKey,
      );
      await _userProfileBox.put(_userProfileHiveKey, profileToSaveInHive);
      debugPrint("Drawer (Sync): Perfil de Hive actualizado. Email: $supabaseUserEmail, Username: $supabaseUsername, AvatarKey: $newAvatarCacheKey");

      // Comparar con el estado actual y actualizar la UI solo si hay cambios
      bool uiNeedsUpdate = false;
      if (_displayName != supabaseUsername) {
        _displayName = supabaseUsername;
        uiNeedsUpdate = true;
      }
      if (_displayEmail != supabaseUserEmail) { // Aunque debería ser el mismo de la sesión
        _displayEmail = supabaseUserEmail;
        uiNeedsUpdate = true;
      }

      // Comparación de bytes del avatar
      // Usar listEquals para comparar contenido si son diferentes instancias pero mismo contenido
      bool avatarChanged = false;
      if (_avatarBytes == null && newAvatarBytes != null || _avatarBytes != null && newAvatarBytes == null) {
        avatarChanged = true;
      } else if (_avatarBytes != null && newAvatarBytes != null && !listEquals(_avatarBytes, newAvatarBytes)) {
        avatarChanged = true;
      }

      if (avatarChanged) {
        _avatarBytes = newAvatarBytes;
        uiNeedsUpdate = true;
      }

      if (uiNeedsUpdate && mounted) {
        setState(() {
          // El estado ya se actualizó arriba, setState solo notifica a Flutter.
          debugPrint("Drawer (Sync): UI actualizada con datos de Supabase.");
        });
      }

    } catch (e, stackTrace) {
      debugPrint('Drawer (Sync): Error al sincronizar perfil con Supabase: $e\n$stackTrace');
      // En caso de error de red, la UI se queda con los datos de Hive que ya se cargaron.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final drawerSelectedItemColor = theme.colorScheme.onPrimaryContainer;
    final drawerIndicatorColor = theme.colorScheme.primaryContainer;
    final drawerUnselectedItemColor = theme.colorScheme.onSurfaceVariant;

    Widget avatarDisplayWidget;
    // Usar los datos de estado local para la UI
    String nameForDisplay = _displayName ?? 'Usuario';
    String emailForDisplay = _displayEmail ?? ' '; // Evitar 'null' literal

    // Mostrar un loader solo si no se ha intentado la carga inicial y hay un usuario
    // O si el email (dato clave) aún no está disponible.
    if (!_initialLoadAttempted && supabase.auth.currentUser != null || (_initialLoadAttempted && _displayEmail == null && supabase.auth.currentUser != null) ) {
      nameForDisplay = 'Cargando...';
      emailForDisplay = ' ';
      avatarDisplayWidget = const CircleAvatar(radius: 30, child: CircularProgressIndicator(strokeWidth: 2.0));
    } else if (_avatarBytes != null) {
      avatarDisplayWidget = CircleAvatar(
        radius: 30,
        backgroundImage: MemoryImage(_avatarBytes!),
        backgroundColor: Colors.transparent,
      );
    } else { // Placeholder si no hay avatarBytes o no hay usuario
      avatarDisplayWidget = CircleAvatar(
        radius: 30,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          nameForDisplay.isNotEmpty ? nameForDisplay[0].toUpperCase() : (supabase.auth.currentUser != null ? 'U' : ''),
          style: TextStyle(fontSize: 28, color: theme.colorScheme.onPrimaryContainer),
        ),
      );
    }

    return Drawer(
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(
              nameForDisplay,
              style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(
              emailForDisplay,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            currentAccountPicture: avatarDisplayWidget,
            decoration: BoxDecoration(color: theme.colorScheme.surface),
            otherAccountsPictures: [
              IconButton(
                icon: Icon(Icons.edit_outlined, color: theme.colorScheme.onSurfaceVariant),
                tooltip: 'Editar Perfil',
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/account').then((_) {
                    if (mounted) {
                      debugPrint("Drawer: Regresando de /account, recargando datos y reiniciando sincronización.");
                      _loadInitialDataFromHiveAndUpdateState();
                      _profileSyncFuture = _syncProfileWithSupabaseInBackground();
                    }
                  });
                },
              ),
            ],
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: DrawerLoader.loadDrawerItems(),
              builder: (context, snapshot) {
                // ... (esta parte no cambia)
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error al cargar el menú: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No hay elementos en el menú.'));
                }
                final items = snapshot.data!;
                final goRouter = GoRouter.of(context);
                final currentLocation = Uri.parse(goRouter.routerDelegate.currentConfiguration.uri.toString()).path;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    if (item['type'] == 'divider') {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(
                          height: 1,
                          color: theme.colorScheme.outlineVariant,
                        ),
                      );
                    } else if (item['type'] == 'padding') {
                      return SizedBox(height: item['value'] as double? ?? 0.0);
                    } else if (item['type'] == 'item') {
                      final label = item['label'] as String? ?? 'Unnamed Item';
                      final iconKey = item['icon'] as String? ?? 'default_icon';
                      final route = item['route'] as String? ?? '/';
                      final selected = currentLocation == route;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: ListTile(
                          leading: Icon(
                            IconHelper.getIcon(iconKey),
                            color: selected ? drawerSelectedItemColor : drawerUnselectedItemColor,
                          ),
                          title: Text(
                            label,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: selected ? drawerSelectedItemColor : drawerUnselectedItemColor,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          selected: selected,
                          selectedTileColor: drawerIndicatorColor,
                          onTap: () {
                            Navigator.of(context).pop(); // Close drawer
                            if (!selected) context.go(route);
                          },
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
              leading: Icon(Icons.logout, color: drawerUnselectedItemColor),
              title: Text('Cerrar Sesión', style: theme.textTheme.labelLarge?.copyWith(color: drawerUnselectedItemColor)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
              onTap: () async {
                Navigator.of(context).pop(); // Close drawer
                try {
                  await supabase.auth.signOut();
                } catch (e) {
                  debugPrint("Error signing out desde Drawer: $e");
                  if(mounted) {
                    // Usar el context.showSnackBar de main.dart si lo tienes como extensión
                    // o el ScaffoldMessenger local.
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al cerrar sesión: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
          )
        ],
      ),
    );
  }
}