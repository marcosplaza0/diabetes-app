// Archivo: lib/data/repositories/user_profile_repository_impl.dart
// Descripción: Implementación concreta de la interfaz UserProfileRepository.
// Esta clase maneja la lógica específica para obtener, actualizar y borrar
// los datos del perfil del usuario. Interactúa con Hive para el almacenamiento local,
// Supabase para el backend, e ImageCacheService para la gestión del avatar.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:flutter/foundation.dart'; // Para Uint8List (bytes del avatar) y debugPrint.
import 'package:hive/hive.dart'; // Para interactuar con la base de datos local Hive (Box).
import 'package:supabase_flutter/supabase_flutter.dart'; // Para SupabaseClient y operaciones de autenticación/base de datos.

// Importaciones de archivos del proyecto
import 'package:DiabetiApp/data/models/profile/user_profile_data.dart'; // Modelo UserProfileData.
import 'package:DiabetiApp/data/repositories/user_profile_repository.dart'; // Interfaz que esta clase implementa.
import 'package:DiabetiApp/core/services/image_cache_service.dart'; // Servicio para la caché de imágenes del avatar.

/// UserProfileRepositoryImpl: Implementación de `UserProfileRepository`.
///
/// Gestiona la persistencia y sincronización de `UserProfileData` y el avatar del usuario.
/// Utiliza una caja de Hive para el perfil local, Supabase para el almacenamiento remoto
/// del perfil y del enlace al avatar, e `ImageCacheService` para la caché local del avatar.
class UserProfileRepositoryImpl implements UserProfileRepository {
  // Caja de Hive para almacenar el UserProfileData del usuario actual.
  final Box<UserProfileData> _userProfileBox;
  // Cliente de Supabase para interactuar con el backend (auth y base de datos).
  final SupabaseClient _supabaseClient;
  // Servicio para gestionar la caché de imágenes (específicamente para el avatar).
  final ImageCacheService _imageCacheService;
  // Clave fija utilizada para almacenar/recuperar el perfil del usuario actual en la caja de Hive.
  final String _userProfileHiveKey = 'currentUserProfile';

  /// Constructor: Inyecta las dependencias necesarias.
  ///
  /// @param userProfileBox La caja de Hive donde se almacena UserProfileData.
  /// @param supabaseClient El cliente de Supabase.
  /// @param imageCacheService El servicio de caché de imágenes.
  UserProfileRepositoryImpl({
    required Box<UserProfileData> userProfileBox,
    required SupabaseClient supabaseClient,
    required ImageCacheService imageCacheService,
  })  : _userProfileBox = userProfileBox,
        _supabaseClient = supabaseClient,
        _imageCacheService = imageCacheService;

  @override
  /// getCurrentUserProfile: Obtiene el perfil del usuario actual y los bytes de su avatar.
  ///
  /// Lógica principal:
  /// 1. Verifica si hay un usuario autenticado en Supabase. Si no, limpia el perfil local y devuelve nulo.
  /// 2. Intenta cargar el perfil desde Hive. Si el email en Hive no coincide con el del usuario actual, limpia el perfil local.
  /// 3. Si `forceRemote` es true o no hay perfil en Hive, sincroniza con Supabase:
  ///    a. Obtiene 'username', 'avatar_url', 'gender' de la tabla 'profiles' en Supabase.
  ///    b. Actualiza o crea el perfil en Hive con estos datos.
  ///    c. Si hay un 'avatar_url', intenta obtener la imagen de la caché local usando `ImageCacheService`.
  ///    d. Si no está en caché, la descarga, la cachea y actualiza `avatarCacheKey` en el perfil de Hive.
  /// 4. Si no se forzó la sincronización remota y ya existía un perfil en Hive con `avatarCacheKey`, intenta cargar los bytes del avatar desde la caché.
  ///
  /// @param forceRemote Si es `true`, fuerza la obtención de datos desde Supabase.
  /// @return Un `Future` que resuelve a un registro con `profile: UserProfileData?` y `avatarBytes: Uint8List?`.
  Future<({UserProfileData? profile, Uint8List? avatarBytes})> getCurrentUserProfile({bool forceRemote = false}) async {
    final currentUser = _supabaseClient.auth.currentUser; // Obtiene el usuario actual de Supabase Auth.
    if (currentUser == null) {
      // Si no hay usuario autenticado, limpia cualquier perfil local y devuelve nulo.
      await clearLocalUserProfile();
      return (profile: null, avatarBytes: null);
    }

    UserProfileData? hiveProfile = _userProfileBox.get(_userProfileHiveKey); // Intenta cargar el perfil desde Hive.
    Uint8List? avatarBytes;

    // Comprueba si el perfil en Hive pertenece al usuario actualmente autenticado.
    if (hiveProfile != null && hiveProfile.email != currentUser.email) { //
      debugPrint("UserProfileRepository: Perfil en Hive (${hiveProfile.email}) no coincide con usuario actual (${currentUser.email}). Se limpiará."); //
      await clearLocalUserProfile(); // Limpia el perfil si no coincide.
      hiveProfile = null;
    }

    // Determina si se necesita una sincronización con la red.
    bool needsNetworkSync = forceRemote || hiveProfile == null;

    if (needsNetworkSync) {
      try {
        debugPrint("UserProfileRepository: Sincronizando perfil con Supabase para ${currentUser.id}...");
        // Obtiene los datos del perfil desde la tabla 'profiles' de Supabase.
        final dbProfileData = await _supabaseClient
            .from('profiles')
            .select('username, avatar_url, gender') // Selecciona los campos necesarios, incluyendo 'gender'.
            .eq('id', currentUser.id) // Filtra por el ID del usuario actual.
            .single(); // Espera un único resultado.

        // Extrae los datos del perfil de Supabase.
        String supabaseUsername = dbProfileData['username'] as String? ?? currentUser.email?.split('@').first ?? 'Usuario'; // Nombre de usuario.
        String? supabaseAvatarUrl = dbProfileData['avatar_url'] as String?; // URL del avatar.
        String? supabaseGender = dbProfileData['gender'] as String?; // Género.

        hiveProfile ??= UserProfileData(); // Si no había perfil en Hive, crea uno nuevo.
        hiveProfile.email = currentUser.email!; //
        hiveProfile.username = supabaseUsername; //
        hiveProfile.gender = supabaseGender; // Actualiza el género. //

        // Manejo del avatar.
        if (supabaseAvatarUrl != null && supabaseAvatarUrl.isNotEmpty) {
          // Extrae la clave de caché (filePath) de la URL del avatar.
          final newCacheKey = _imageCacheService.extractFilePathFromUrl(supabaseAvatarUrl); //
          // Si la clave de caché ha cambiado o si se fuerza remoto y necesitamos los bytes.
          if (hiveProfile.avatarCacheKey != newCacheKey) { //
            if (newCacheKey != null) {
              // Intenta obtener la imagen de la caché.
              avatarBytes = await _imageCacheService.getImage(newCacheKey); //
              // Si no está en caché, la descarga y la cachea.
              avatarBytes ??= await _imageCacheService.downloadAndCacheImage(newCacheKey, supabaseAvatarUrl); //
              hiveProfile.avatarCacheKey = newCacheKey; //
            }
          } else if (newCacheKey != null) { // Si la clave es la misma pero no tenemos los bytes (ej. se limpió la caché de memoria).
            avatarBytes = await _imageCacheService.getImage(newCacheKey); //
          }
        } else {
          // Si no hay URL de avatar, limpia la clave de caché y los bytes.
          hiveProfile.avatarCacheKey = null; //
          avatarBytes = null;
        }
        // Guarda el perfil actualizado en Hive.
        await _userProfileBox.put(_userProfileHiveKey, hiveProfile);
        debugPrint("UserProfileRepository: Perfil de Hive actualizado/creado desde Supabase. Gender: ${hiveProfile.gender}"); //

      } catch (e, stackTrace) {
        debugPrint('UserProfileRepository: Error al sincronizar perfil con Supabase: $e\n$stackTrace');
        // Si falla la sincronización, se continuará con el perfil de Hive si existe, o nulo si no.
      }
    }

    // Si, después de todo, tenemos un perfil en Hive con una clave de avatar pero no los bytes,
    // intentamos cargarlos de la caché una última vez.
    if (hiveProfile != null && avatarBytes == null && hiveProfile.avatarCacheKey != null) { //
      avatarBytes = await _imageCacheService.getImage(hiveProfile.avatarCacheKey!); // //
    }

    return (profile: hiveProfile, avatarBytes: avatarBytes);
  }

  @override
  /// updateProfileDetails: Actualiza los detalles del perfil del usuario (nombre, género, etc.).
  ///
  /// Guarda los cambios en Hive y luego los sincroniza con Supabase.
  ///
  /// @param username El nuevo nombre de usuario (opcional).
  /// @param gender El nuevo género (opcional).
  Future<void> updateProfileDetails({String? username, String? gender}) async {
    final currentUser = _supabaseClient.auth.currentUser;
    if (currentUser == null) throw Exception("Usuario no autenticado.");

    // Obtiene el perfil de Hive o crea uno nuevo si no existe (asegurando que tenga el email).
    UserProfileData profileToUpdate = _userProfileBox.get(_userProfileHiveKey) ?? UserProfileData(email: currentUser.email);
    profileToUpdate.email = currentUser.email; // Reasegura el email por si era un perfil nuevo sin él. //

    bool changedInHive = false; // Flag para saber si hubo cambios en los datos de Hive.
    Map<String, dynamic> supabaseUpdates = {'id': currentUser.id, 'updated_at': DateTime.now().toIso8601String()}; // Datos a enviar a Supabase.
    bool changedForSupabase = false; // Flag para saber si hay que actualizar en Supabase.

    // Actualiza el nombre de usuario si se proporcionó y es diferente.
    if (username != null && profileToUpdate.username != username) { //
      profileToUpdate.username = username; //
      supabaseUpdates['username'] = username;
      changedInHive = true;
      changedForSupabase = true;
    }

    // Actualiza el género si se proporcionó y es diferente.
    if (gender != null && profileToUpdate.gender != gender) { //
      profileToUpdate.gender = gender; //
      supabaseUpdates['gender'] = gender; // Añade 'gender' a los datos para Supabase.
      changedInHive = true;
      changedForSupabase = true;
    }

    // Si hubo cambios, guarda en Hive.
    if (changedInHive) {
      await _userProfileBox.put(_userProfileHiveKey, profileToUpdate);
      debugPrint("UserProfileRepository: Detalles del perfil actualizados localmente (Hive). Gender: ${profileToUpdate.gender}"); //
    }
    // Si hubo cambios para Supabase, actualiza (upsert) en la tabla 'profiles'.
    if (changedForSupabase) {
      await _supabaseClient.from('profiles').upsert(supabaseUpdates);
      debugPrint("UserProfileRepository: Detalles del perfil sincronizados con Supabase.");
    }
  }

  @override
  /// updateUserAvatar: Actualiza la URL del avatar en Supabase y la clave de caché en Hive.
  ///
  /// @param avatarUrl La URL del avatar ya subido a Supabase Storage.
  /// @param newAvatarCacheKey La clave de caché (filePath) del nuevo avatar.
  Future<void> updateUserAvatar({required String avatarUrl, required String? newAvatarCacheKey}) async {
    final currentUser = _supabaseClient.auth.currentUser;
    if (currentUser == null) throw Exception("Usuario no autenticado.");

    // Obtiene el perfil de Hive o crea uno nuevo.
    UserProfileData profileToUpdate = _userProfileBox.get(_userProfileHiveKey) ?? UserProfileData();
    profileToUpdate.email = currentUser.email; // Asegura el email. //
    profileToUpdate.avatarCacheKey = newAvatarCacheKey; // Actualiza la clave de caché del avatar. //

    // Asegura que el nombre de usuario exista, por si era un perfil nuevo.
    profileToUpdate.username ??= currentUser.email?.split('@').first ?? 'Usuario'; //

    // Guarda el perfil actualizado en Hive.
    await _userProfileBox.put(_userProfileHiveKey, profileToUpdate);
    // Actualiza (upsert) la URL del avatar en la tabla 'profiles' de Supabase.
    await _supabaseClient.from('profiles').upsert({
      'id': currentUser.id,
      'avatar_url': avatarUrl, // La nueva URL del avatar.
      'updated_at': DateTime.now().toIso8601String(),
    });
    debugPrint("UserProfileRepository: Avatar del perfil actualizado local y remotamente. Nueva clave de caché: $newAvatarCacheKey");
  }

  @override
  /// getAvatarBytes: Obtiene los bytes del avatar desde ImageCacheService.
  ///
  /// @param avatarCacheKey La clave de caché del avatar.
  /// @return Un `Future<Uint8List?>` con los bytes, o nulo si no se encuentra.
  Future<Uint8List?> getAvatarBytes(String? avatarCacheKey) async {
    if (avatarCacheKey == null || avatarCacheKey.isEmpty) return null;
    return await _imageCacheService.getImage(avatarCacheKey); //
  }

  @override
  /// clearLocalUserProfile: Elimina el perfil del usuario de la caja local de Hive.
  Future<void> clearLocalUserProfile() async {
    await _userProfileBox.delete(_userProfileHiveKey);
    debugPrint("UserProfileRepository: Perfil de Hive local borrado.");
  }
}