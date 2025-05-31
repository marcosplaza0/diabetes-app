// Archivo: lib/core/auth/auth_service.dart
// Descripción: Servicio de autenticación que encapsula la lógica para interactuar
// con el sistema de autenticación de Supabase. Proporciona métodos para iniciar sesión,
// registrar nuevos usuarios, cerrar sesión y obtener información del usuario actual.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:supabase_flutter/supabase_flutter.dart'; // Necesario para AuthResponse y el cliente de Supabase.

/// AuthService: Clase que gestiona las operaciones de autenticación.
///
/// Esta clase actúa como una capa de abstracción sobre el cliente de autenticación
/// de Supabase (`Supabase.instance.client.auth`), simplificando las llamadas
/// de autenticación desde otras partes de la aplicación (ej. ViewModels, pantallas de login/registro).
class AuthService {
  // Instancia del cliente de Supabase, específicamente su módulo de autenticación.
  final SupabaseClient _supabase = Supabase.instance.client;

  /// signInWithEmailAndPassword: Inicia sesión de un usuario existente con su email y contraseña.
  ///
  /// @param email El correo electrónico del usuario.
  /// @param password La contraseña del usuario.
  /// @return Un `Future<AuthResponse>` que contiene la respuesta de Supabase a la solicitud de inicio de sesión.
  ///         Esta respuesta puede incluir la sesión del usuario, el usuario mismo, o un error si falla.
  Future<AuthResponse> signInWithEmailAndPassword(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// signUpWithEmailAndPassword: Registra un nuevo usuario con un email y contraseña.
  ///
  /// Por defecto, Supabase puede estar configurado para enviar un correo de confirmación
  /// al usuario para verificar su dirección de email antes de que pueda iniciar sesión.
  ///
  /// @param email El correo electrónico para el nuevo usuario.
  /// @param password La contraseña para el nuevo usuario.
  /// @return Un `Future<AuthResponse>` que contiene la respuesta de Supabase al intento de registro.
  ///         Puede incluir información del usuario recién creado (aunque aún no confirmado) o un error.
  Future<AuthResponse> signUpWithEmailAndPassword(String email, String password) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
    );
  }

  /// signOut: Cierra la sesión del usuario actualmente autenticado.
  ///
  /// Invalida la sesión actual del usuario en el cliente de Supabase.
  ///
  /// @return Un `Future<void>` que se completa cuando la operación de cierre de sesión ha terminado.
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  /// getCurrentUserEmail: Obtiene el email del usuario actualmente autenticado.
  ///
  /// @return Un `String?` con el email del usuario si hay una sesión activa y un usuario,
  ///         o `null` si no hay ningún usuario autenticado.
  String? getCurrentUserEmail(){
    final session = _supabase.auth.currentSession; // Obtiene la sesión actual.
    final user = session?.user; // Obtiene el objeto User de la sesión.
    return user?.email; // Devuelve el email del usuario.
  }

// Se podrían añadir otros métodos relacionados con la autenticación si fueran necesarios, como:
// - reauthenticate()
// - sendPasswordResetEmail()
// - updateUserPassword()
// - signInWithOAuth() (para login con Google, Facebook, etc.)
}