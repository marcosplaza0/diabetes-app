// lib/data/repositories/user_profile_repository.dart
import 'package:diabetes_2/data/models/profile/user_profile_data.dart';
import 'package:flutter/foundation.dart'; // Para Uint8List

abstract class UserProfileRepository {
  /// Obtiene el perfil del usuario actual.
  /// Primero intenta desde la caché local (Hive).
  /// Si no existe o se considera obsoleto (o `forceRemote` es true),
  /// intenta sincronizar/obtener desde Supabase y actualiza la caché local.
  /// Devuelve el UserProfileData y los bytes del avatar si están cacheados.
  Future<({UserProfileData? profile, Uint8List? avatarBytes})> getCurrentUserProfile({bool forceRemote = false});

  /// Actualiza los detalles del perfil del usuario (ej. nombre de usuario).
  /// Guarda localmente y sincroniza con Supabase.
  Future<void> updateProfileDetails({String? username, String? gender /* otros campos si los tienes */});

  /// Actualiza la URL del avatar del usuario en Supabase y la clave de caché local.
  /// Los bytes de la imagen ya deberían estar cacheados por ImageCacheService
  /// antes de llamar a este método (generalmente después de una subida exitosa).
  Future<void> updateUserAvatar({required String avatarUrl, required String? newAvatarCacheKey});

  /// Limpia los datos del perfil del usuario almacenados localmente (en Hive).
  Future<void> clearLocalUserProfile();

  /// Obtiene los bytes del avatar desde la caché usando su clave.
  Future<Uint8List?> getAvatarBytes(String? avatarCacheKey);
}