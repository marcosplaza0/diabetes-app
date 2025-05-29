// lib/core/layout/drawer/drawer_app.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:diabetes_2/data/models/profile/user_profile_data.dart';
import 'package:diabetes_2/core/services/image_cache_service.dart';
import 'package:diabetes_2/core/utils/icon_helper.dart';
import 'package:diabetes_2/main.dart' show supabase, userProfileBoxName, mealLogBoxName, overnightLogBoxName;
import 'drawer_loader.dart';
import 'package:diabetes_2/data/models/logs/logs.dart';
import 'package:diabetes_2/core/services/supabase_log_sync_service.dart';

// Clave para SharedPreferences (debería ser global o importada)
const String cloudSavePreferenceKey = 'saveToCloudEnabled';

// Enum para las acciones del diálogo de logout
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
  late Box<UserProfileData> _userProfileBox;
  final String _userProfileHiveKey = 'currentUserProfile';

  String? _displayName;
  String? _displayEmail;
  Uint8List? _avatarBytes;
  bool _initialLoadAttempted = false;
  // ignore: unused_field
  Future<void>? _profileSyncFuture;

  bool _isProcessingLogout = false;
  final SupabaseLogSyncService _logSyncService = SupabaseLogSyncService();

  @override
  void initState() {
    super.initState();
    _userProfileBox = Hive.box<UserProfileData>(userProfileBoxName);
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
          _loadInitialDataFromHiveAndUpdateState();
          _profileSyncFuture = _syncProfileWithSupabaseInBackground();
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
        _initialLoadAttempted = true;
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

      if (hiveProfile != null && hiveProfile.email != currentUser.email) {
        debugPrint("Drawer (InitialLoad): Perfil en Hive (${hiveProfile.email}) no coincide con usuario actual (${currentUser.email}). Se ignorará.");
        _userProfileBox.delete(_userProfileHiveKey);
        hiveProfile = null;
      }

      if (hiveProfile != null) {
        nameFromHive = hiveProfile.username;
        emailFromHive = hiveProfile.email;
        if (hiveProfile.avatarCacheKey != null && hiveProfile.avatarCacheKey!.isNotEmpty) {
          avatarFromHiveCache = await imageCacheService.getImage(hiveProfile.avatarCacheKey!);
        }
        // debugPrint("Drawer (InitialLoad): Datos de Hive: Nombre='$nameFromHive', Email='$emailFromHive', AvatarKey='${hiveProfile.avatarCacheKey}', AvatarCargado=${avatarFromHiveCache != null}");
      } else {
        // debugPrint("Drawer (InitialLoad): No hay perfil en Hive para ${currentUser.email} o no coincide.");
      }
    } else {
      _clearLocalProfileDataAndState();
      return;
    }

    if(mounted){ // Comprobación adicional
      setState(() {
        _displayName = nameFromHive ?? currentUser.email?.split('@').first ?? 'Usuario';
        _displayEmail = emailFromHive ?? currentUser.email;
        _avatarBytes = avatarFromHiveCache;
        _initialLoadAttempted = true;
      });
    }
  }

  Future<void> _syncProfileWithSupabaseInBackground() async {
    if (!mounted) return;
    final imageCacheService = Provider.of<ImageCacheService>(context, listen: false);
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      debugPrint("Drawer (Sync): No hay usuario para sincronizar.");
      if (_displayName != null || _displayEmail != null || _avatarBytes != null) {
        _clearLocalProfileDataAndState();
      }
      return;
    }

    try {
      // debugPrint("Drawer (Sync): Sincronizando perfil con Supabase para ${currentUser.id}...");
      final dbProfileData = await supabase
          .from('profiles')
          .select('username, avatar_url')
          .eq('id', currentUser.id)
          .single();

      String supabaseUsername = dbProfileData['username'] as String? ?? currentUser.email?.split('@').first ?? 'Usuario';
      String supabaseUserEmail = currentUser.email!;
      String? supabaseAvatarUrl = dbProfileData['avatar_url'] as String?;
      String? newAvatarCacheKey;
      Uint8List? newAvatarBytes = _avatarBytes;

      if (supabaseAvatarUrl != null && supabaseAvatarUrl.isNotEmpty) {
        newAvatarCacheKey = imageCacheService.extractFilePathFromUrl(supabaseAvatarUrl);
        if (newAvatarCacheKey != null) {
          final currentHiveProfile = _userProfileBox.get(_userProfileHiveKey);
          if (currentHiveProfile?.avatarCacheKey != newAvatarCacheKey || newAvatarBytes == null) {
            newAvatarBytes = await imageCacheService.getImage(newAvatarCacheKey);
            newAvatarBytes ??= await imageCacheService.downloadAndCacheImage(newAvatarCacheKey, supabaseAvatarUrl);
          }
        }
      } else {
        newAvatarCacheKey = null;
        newAvatarBytes = null;
      }

      UserProfileData profileToSaveInHive = UserProfileData(
        username: supabaseUsername,
        email: supabaseUserEmail,
        avatarCacheKey: newAvatarCacheKey,
      );
      await _userProfileBox.put(_userProfileHiveKey, profileToSaveInHive);
      // debugPrint("Drawer (Sync): Perfil de Hive actualizado. Email: $supabaseUserEmail, Username: $supabaseUsername, AvatarKey: $newAvatarCacheKey");

      bool uiNeedsUpdate = false;
      if (_displayName != supabaseUsername) {
        _displayName = supabaseUsername;
        uiNeedsUpdate = true;
      }
      if (_displayEmail != supabaseUserEmail) {
        _displayEmail = supabaseUserEmail;
        uiNeedsUpdate = true;
      }

      bool avatarChanged = false;
      if ((_avatarBytes == null && newAvatarBytes != null) || (_avatarBytes != null && newAvatarBytes == null)) {
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
          // debugPrint("Drawer (Sync): UI actualizada con datos de Supabase.");
        });
      }

    } catch (e, stackTrace) {
      debugPrint('Drawer (Sync): Error al sincronizar perfil con Supabase: $e\n$stackTrace');
    }
  }

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
      if (!mounted) return;
      userAction = await showDialog<LogoutPromptAction>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Datos Locales Sin Sincronizar'),
            content: const Text('Tienes registros locales que no se han guardado en la nube. ¿Deseas subirlos antes de cerrar sesión?'),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancelar'),
                onPressed: () => Navigator.of(dialogContext).pop(LogoutPromptAction.cancel),
              ),
              TextButton(
                child: const Text('Cerrar Sin Subir'),
                onPressed: () => Navigator.of(dialogContext).pop(LogoutPromptAction.logoutWithoutUploading),
              ),
              ElevatedButton(
                child: const Text('Subir y Cerrar Sesión'),
                onPressed: () => Navigator.of(dialogContext).pop(LogoutPromptAction.uploadAndLogout),
              ),
            ],
          );
        },
      );
    }

    if (!mounted || userAction == LogoutPromptAction.cancel) {
      return;
    }

    if (userAction == LogoutPromptAction.uploadAndLogout) {
      if (!mounted) return;
      setState(() { _isProcessingLogout = true; });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subiendo datos a la nube...'), duration: Duration(seconds: 3)),
      );

      int successCount = 0;
      int errorCount = 0;
      try {
        for (var entry in mealLogBox.toMap().entries) {
          try {
            await _logSyncService.syncMealLog(entry.value, entry.key);
            successCount++;
          } catch (e) { errorCount++; }
        }
        for (var entry in overnightLogBox.toMap().entries) {
          try {
            await _logSyncService.syncOvernightLog(entry.value, entry.key);
            successCount++;
          } catch (e) { errorCount++; }
        }
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sincronización antes de logout completada. Éxitos: $successCount, Errores: $errorCount'), backgroundColor: errorCount > 0 ? Colors.orange : Colors.green),
          );
        }
      } catch (e) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al subir datos: ${e.toString()}'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() { _isProcessingLogout = false; });
      }
    }

    try {
      await supabase.auth.signOut();
    } catch (e) {
      debugPrint("Error signing out desde Drawer: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cerrar sesión: $e'), backgroundColor: Colors.red),
        );
      }
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
    } else {
      avatarDisplayWidget = CircleAvatar(
        radius: 30,
        backgroundColor: theme.colorScheme.primaryContainer,
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
            accountName: Text(
              nameForDisplay,
              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(
              emailForDisplay,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            currentAccountPicture: avatarDisplayWidget,
            decoration: BoxDecoration(color: theme.colorScheme.surface),
            otherAccountsPictures: [
              IconButton(
                icon: Icon(Icons.edit_outlined, color: theme.colorScheme.onSurfaceVariant),
                tooltip: 'Editar Perfil',
                onPressed: _isProcessingLogout ? null : () {
                  Navigator.of(context).pop();
                  context.push('/account').then((_) {
                    if (mounted) {
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
                if (snapshot.connectionState == ConnectionState.waiting && !_isProcessingLogout) {
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
                          onTap: _isProcessingLogout ? null : () {
                            Navigator.of(context).pop();
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
              leading: _isProcessingLogout
                  ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: drawerUnselectedItemColor))
                  : Icon(Icons.logout, color: drawerUnselectedItemColor),
              title: Text(
                  _isProcessingLogout ? 'Cerrando Sesión...' : 'Cerrar Sesión',
                  style: theme.textTheme.labelLarge?.copyWith(color: drawerUnselectedItemColor)
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
              onTap: _isProcessingLogout ? null : () {
                Navigator.of(context).pop();
                _handleLogout();
              },
            ),
          )
        ],
      ),
    );
  }
}