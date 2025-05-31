// Archivo: lib/data/repositories/user_profile_repository.dart
// Descripción: Define la interfaz (contrato) para el repositorio del perfil de usuario.
// Esta clase abstracta especifica los métodos que cualquier implementación concreta
// del repositorio de perfil de usuario debe proporcionar. Sirve como una abstracción
// para el acceso y la manipulación de los datos del perfil del usuario (UserProfileData)
// y los bytes del avatar.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:flutter/foundation.dart'; // Para Uint8List, usado para los bytes del avatar.

// Importaciones de archivos del proyecto
import 'package:DiabetiApp/data/models/profile/user_profile_data.dart'; // Modelo UserProfileData.

/// UserProfileRepository: Clase abstracta que define el contrato para el repositorio de perfil de usuario.
///
/// Un repositorio de perfil de usuario se encarga de gestionar la obtención, actualización
/// y borrado de los datos del perfil del usuario, tanto localmente (caché) como
/// remotamente (backend, ej. Supabase). También puede interactuar con servicios
/// de caché de imágenes para el avatar del usuario.
abstract class UserProfileRepository {
  /// getCurrentUserProfile: Obtiene el perfil del usuario actual y los bytes de su avatar.
  ///
  /// La implementación típicamente intentará obtener el perfil desde una caché local (ej. Hive) primero.
  /// Si no existe, está obsoleto, o si `forceRemote` es `true`, intentará sincronizar
  /// u obtener el perfil desde el backend (ej. Supabase) y actualizará la caché local.
  ///
  /// @param forceRemote Un booleano que, si es `true`, fuerza la obtención de datos
  ///                    directamente del backend, saltándose o actualizando la caché local.
  /// @return Un `Future` que resuelve a un registro (tupla) conteniendo:
  ///         - `profile`: Un objeto `UserProfileData?` (puede ser nulo si no hay perfil o usuario).
  ///         - `avatarBytes`: Un `Uint8List?` con los bytes del avatar (puede ser nulo si no hay avatar o no está cacheado).
  Future<({UserProfileData? profile, Uint8List? avatarBytes})> getCurrentUserProfile({bool forceRemote = false});

  /// updateProfileDetails: Actualiza los detalles del perfil del usuario.
  ///
  /// La implementación debe guardar los cambios localmente y sincronizarlos con el backend.
  /// Los parámetros como `username` y `gender` son opcionales, permitiendo actualizaciones parciales.
  ///
  /// @param username El nuevo nombre de usuario (opcional).
  /// @param gender El nuevo género del usuario (opcional).
  ///               Se pueden añadir otros campos del perfil aquí si es necesario.
  /// @return Un `Future<void>` que se completa cuando la operación de actualización ha terminado.
  Future<void> updateProfileDetails({String? username, String? gender /* otros campos si los tienes */});

  /// updateUserAvatar: Actualiza la URL del avatar del usuario en el backend y la clave de caché local.
  ///
  /// Se asume que los bytes de la imagen del avatar ya han sido subidos al almacenamiento
  /// (ej. Supabase Storage) y que `ImageCacheService` ya ha cacheado los bytes localmente
  /// antes de llamar a este método. Este método se encarga de actualizar las referencias
  /// (URL en el backend, clave de caché en el perfil local) a ese avatar.
  ///
  /// @param avatarUrl La URL pública o firmada del avatar en el almacenamiento remoto (ej. Supabase).
  /// @param newAvatarCacheKey La nueva clave de caché (generalmente el `filePath` del avatar)
  ///                          para ser almacenada en el perfil local.
  /// @return Un `Future<void>` que se completa cuando la actualización ha terminado.
  Future<void> updateUserAvatar({required String avatarUrl, required String? newAvatarCacheKey});

  /// clearLocalUserProfile: Limpia los datos del perfil del usuario almacenados localmente (ej. en Hive).
  ///
  /// Esto se usa típicamente durante el proceso de cierre de sesión (logout) para
  /// asegurar que los datos del usuario anterior no persistan en el dispositivo.
  ///
  /// @return Un `Future<void>` que se completa cuando los datos locales del perfil han sido borrados.
  Future<void> clearLocalUserProfile();

  /// getAvatarBytes: Obtiene los bytes del avatar desde la caché local usando su clave.
  ///
  /// Interactúa con el servicio de caché de imágenes (como `ImageCacheService`)
  /// para recuperar los datos binarios de la imagen del avatar.
  ///
  /// @param avatarCacheKey La clave de caché del avatar a recuperar.
  /// @return Un `Future` que resuelve a un `Uint8List?` con los bytes del avatar,
  ///         o `null` si la clave es nula, vacía o el avatar no se encuentra en caché.
  Future<Uint8List?> getAvatarBytes(String? avatarCacheKey);
}