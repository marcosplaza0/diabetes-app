// Archivo: lib/data/models/profile/user_profile_data.dart
// Descripción: Define el modelo de datos para el perfil del usuario.
// Esta clase almacena información del usuario como nombre de usuario, email,
// clave de caché para el avatar y género. Está preparada para ser almacenada
// localmente usando Hive.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:hive/hive.dart'; // Necesario para las anotaciones de Hive (@HiveType, @HiveField) y HiveObject.

// Declaración de 'part' para el archivo generado por build_runner.
// Este archivo (`user_profile_data.g.dart`) contendrá el TypeAdapter generado por Hive.
part 'user_profile_data.g.dart';

/// UserProfileData: Clase modelo para almacenar los datos del perfil del usuario.
///
/// Contiene campos como el nombre de usuario, email, la clave utilizada para
/// cachear la imagen del avatar localmente, y el género del usuario.
/// Extiende `HiveObject` para facilitar su uso con la base de datos Hive.
/// El `typeId` debe ser único entre todos los `HiveType`s registrados en la aplicación.
@HiveType(typeId: 2) // typeId=0 para MealLog, typeId=1 para OvernightLog. Este es 2.
class UserProfileData extends HiveObject {
  /// username: Nombre de usuario elegido por el usuario.
  /// Puede ser nulo si el usuario no ha establecido uno.
  @HiveField(0)
  String? username;

  /// email: Dirección de correo electrónico del usuario.
  /// Usualmente se obtiene del proveedor de autenticación (ej. Supabase Auth).
  /// Puede ser nulo si el perfil se crea localmente antes de la sincronización.
  @HiveField(1)
  String? email;

  /// avatarCacheKey: Clave utilizada por `ImageCacheService` para almacenar y recuperar
  /// la imagen del avatar del usuario de la caché local.
  /// Corresponde generalmente al `filePath` en Supabase Storage.
  /// Puede ser nulo si el usuario no ha subido un avatar.
  @HiveField(2)
  String? avatarCacheKey;

  /// gender: Género seleccionado por el usuario.
  /// Este es un campo más reciente añadido al modelo.
  /// Puede ser nulo si el usuario no ha especificado su género.
  @HiveField(3) // Nuevo índice para el nuevo campo.
  String? gender;

  /// Constructor de UserProfileData.
  /// Todos los campos son opcionales para permitir la creación de un objeto
  /// incluso si no toda la información está disponible inicialmente.
  UserProfileData({
    this.username,
    this.email,
    this.avatarCacheKey,
    this.gender, // Añadido al constructor.
  });
}