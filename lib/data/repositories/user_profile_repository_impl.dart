// lib/data/repositories/user_profile_repository_impl.dart
import 'package:diabetes_2/data/models/profile/user_profile_data.dart';
import 'package:diabetes_2/data/repositories/user_profile_repository.dart';
import 'package:diabetes_2/core/services/image_cache_service.dart';
// import 'package:diabetes_2/main.dart' show userProfileBoxName; // No es necesario aquí si la caja se inyecta
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfileRepositoryImpl implements UserProfileRepository {
  final Box<UserProfileData> _userProfileBox;
  final SupabaseClient _supabaseClient;
  final ImageCacheService _imageCacheService;
  final String _userProfileHiveKey = 'currentUserProfile';

  UserProfileRepositoryImpl({
    required Box<UserProfileData> userProfileBox,
    required SupabaseClient supabaseClient,
    required ImageCacheService imageCacheService,
  })  : _userProfileBox = userProfileBox,
        _supabaseClient = supabaseClient,
        _imageCacheService = imageCacheService;

  @override
  Future<({UserProfileData? profile, Uint8List? avatarBytes})> getCurrentUserProfile({bool forceRemote = false}) async {
    final currentUser = _supabaseClient.auth.currentUser;
    if (currentUser == null) {
      await clearLocalUserProfile();
      return (profile: null, avatarBytes: null);
    }

    UserProfileData? hiveProfile = _userProfileBox.get(_userProfileHiveKey);
    Uint8List? avatarBytes;

    if (hiveProfile != null && hiveProfile.email != currentUser.email) {
      debugPrint("UserProfileRepository: Perfil en Hive (${hiveProfile.email}) no coincide con usuario actual (${currentUser.email}). Se limpiará.");
      await clearLocalUserProfile();
      hiveProfile = null;
    }

    bool needsNetworkSync = forceRemote || hiveProfile == null;

    if (needsNetworkSync) {
      try {
        debugPrint("UserProfileRepository: Sincronizando perfil con Supabase para ${currentUser.id}...");
        final dbProfileData = await _supabaseClient
            .from('profiles')
            .select('username, avatar_url, gender') // <-- AÑADIR 'gender' AL SELECT
            .eq('id', currentUser.id)
            .single();

        String supabaseUsername = dbProfileData['username'] as String? ?? currentUser.email?.split('@').first ?? 'Usuario';
        String? supabaseAvatarUrl = dbProfileData['avatar_url'] as String?;
        String? supabaseGender = dbProfileData['gender'] as String?; // <-- OBTENER gender

        hiveProfile ??= UserProfileData();
        hiveProfile.email = currentUser.email!;
        hiveProfile.username = supabaseUsername;
        hiveProfile.gender = supabaseGender; // <-- ASIGNAR gender

        if (supabaseAvatarUrl != null && supabaseAvatarUrl.isNotEmpty) {
          final newCacheKey = _imageCacheService.extractFilePathFromUrl(supabaseAvatarUrl);
          if (hiveProfile.avatarCacheKey != newCacheKey /* || avatarBytes == null // No necesitamos cargar bytes si ya los tenemos de una sincronización previa no forzada */) {
            // Si forzamos remoto o la clave es diferente, intentamos obtener/descargar
            avatarBytes = await _imageCacheService.getImage(newCacheKey!);
            avatarBytes ??= await _imageCacheService.downloadAndCacheImage(newCacheKey!, supabaseAvatarUrl);
            hiveProfile.avatarCacheKey = newCacheKey;
          } else if (newCacheKey != null) { // La clave es la misma, intentar cargar desde caché si no hay bytes
            avatarBytes ??= await _imageCacheService.getImage(newCacheKey);
          }
        } else {
          hiveProfile.avatarCacheKey = null;
          avatarBytes = null;
        }
        await _userProfileBox.put(_userProfileHiveKey, hiveProfile);
        debugPrint("UserProfileRepository: Perfil de Hive actualizado/creado desde Supabase. Gender: ${hiveProfile.gender}");

      } catch (e, stackTrace) {
        debugPrint('UserProfileRepository: Error al sincronizar perfil con Supabase: $e\n$stackTrace');
      }
    }

    if (hiveProfile != null && avatarBytes == null && hiveProfile.avatarCacheKey != null) {
      avatarBytes = await _imageCacheService.getImage(hiveProfile.avatarCacheKey!);
    }

    return (profile: hiveProfile, avatarBytes: avatarBytes);
  }

  @override
  Future<void> updateProfileDetails({String? username, String? gender}) async {
    final currentUser = _supabaseClient.auth.currentUser;
    if (currentUser == null) throw Exception("Usuario no autenticado.");

    // Obtener el perfil existente o crear uno nuevo si no existe
    UserProfileData profileToUpdate = _userProfileBox.get(_userProfileHiveKey) ?? UserProfileData(email: currentUser.email); // Asegurar email si es nuevo
    profileToUpdate.email = currentUser.email; // Re-asegurar email por si acaso

    bool changedInHive = false;
    Map<String, dynamic> supabaseUpdates = {'id': currentUser.id, 'updated_at': DateTime.now().toIso8601String()};
    bool changedForSupabase = false;

    if (username != null && profileToUpdate.username != username) {
      profileToUpdate.username = username;
      supabaseUpdates['username'] = username;
      changedInHive = true;
      changedForSupabase = true;
    }

    if (gender != null && profileToUpdate.gender != gender) { // <-- MANEJAR gender
      profileToUpdate.gender = gender;
      supabaseUpdates['gender'] = gender; // <-- AÑADIR gender A SUPABASE
      changedInHive = true;
      changedForSupabase = true;
    }

    if (changedInHive) {
      await _userProfileBox.put(_userProfileHiveKey, profileToUpdate);
      debugPrint("UserProfileRepository: Detalles del perfil actualizados localmente (Hive). Gender: ${profileToUpdate.gender}");
    }
    if (changedForSupabase) {
      await _supabaseClient.from('profiles').upsert(supabaseUpdates);
      debugPrint("UserProfileRepository: Detalles del perfil sincronizados con Supabase.");
    }
  }

  @override
  Future<void> updateUserAvatar({required String avatarUrl, required String? newAvatarCacheKey}) async {
    final currentUser = _supabaseClient.auth.currentUser;
    if (currentUser == null) throw Exception("Usuario no autenticado.");

    UserProfileData profileToUpdate = _userProfileBox.get(_userProfileHiveKey) ?? UserProfileData();
    profileToUpdate.email = currentUser.email;
    profileToUpdate.avatarCacheKey = newAvatarCacheKey;

    profileToUpdate.username ??= currentUser.email?.split('@').first ?? 'Usuario';

    await _userProfileBox.put(_userProfileHiveKey, profileToUpdate);
    await _supabaseClient.from('profiles').upsert({
      'id': currentUser.id,
      'avatar_url': avatarUrl,
      'updated_at': DateTime.now().toIso8601String(),
    });
    debugPrint("UserProfileRepository: Avatar del perfil actualizado local y remotamente. Nueva clave de caché: $newAvatarCacheKey");
  }

  @override
  Future<Uint8List?> getAvatarBytes(String? avatarCacheKey) async {
    if (avatarCacheKey == null || avatarCacheKey.isEmpty) return null;
    return await _imageCacheService.getImage(avatarCacheKey);
  }

  @override
  Future<void> clearLocalUserProfile() async {
    await _userProfileBox.delete(_userProfileHiveKey);
    debugPrint("UserProfileRepository: Perfil de Hive local borrado.");
  }
}