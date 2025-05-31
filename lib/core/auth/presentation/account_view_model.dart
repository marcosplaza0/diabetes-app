// Archivo: lib/core/auth/presentation/account_view_model.dart
// Descripción: ViewModel para la pantalla de gestión de la cuenta del usuario (AccountPage).
// Este archivo contiene la lógica de negocio y el estado para cargar, mostrar y actualizar
// la información del perfil del usuario, incluyendo nombre de usuario, género y avatar.
// También maneja la lógica de cierre de sesión, incluyendo la sincronización opcional
// de datos locales pendientes antes de desloguear.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:flutter/material.dart'; // Para TextEditingController.
import 'package:hive/hive.dart'; // Para Box<MealLog> y Box<OvernightLog> en la lógica de logout.
import 'package:supabase_flutter/supabase_flutter.dart'; // Para SupabaseClient, AuthException.
import 'package:shared_preferences/shared_preferences.dart'; // Para SharedPreferences en la lógica de logout.

// Importaciones de archivos del proyecto
import 'package:diabetes_2/data/repositories/user_profile_repository.dart'; // Repositorio para operaciones del perfil de usuario.
import 'package:diabetes_2/core/services/image_cache_service.dart'; // Servicio para la caché de imágenes (avatar).
import 'package:diabetes_2/data/models/logs/logs.dart'; // Modelos MealLog y OvernightLog, para la sincronización en logout.
import 'package:diabetes_2/core/services/supabase_log_sync_service.dart'; // Servicio para sincronizar logs con Supabase.
import 'package:diabetes_2/main.dart' show mealLogBoxName, overnightLogBoxName; // Nombres de las cajas de Hive para logs.

// Enum para las acciones del diálogo de confirmación de cierre de sesión.
// Podría estar en un archivo de utilidades de la feature si se usa en más lugares.
enum AccountPageLogoutPromptAction {
  uploadAndLogout,         // Subir datos locales y luego cerrar sesión.
  logoutWithoutUploading,  // Cerrar sesión sin subir datos locales.
  cancel,                  // Cancelar la operación de cierre de sesión.
}
// Constante para la clave de SharedPreferences que indica si el guardado en la nube está habilitado.
// Usada para determinar si se debe preguntar al usuario sobre la sincronización de datos locales al cerrar sesión.
const String cloudSavePreferenceKeyFromAccountVM = 'saveToCloudEnabled';


/// AccountViewModel: Gestiona el estado y la lógica para la pantalla de cuenta (AccountPage).
///
/// Responsabilidades:
/// - Cargar los datos del perfil del usuario actual (nombre, género, avatar).
/// - Permitir la actualización de estos datos.
/// - Manejar la subida y actualización de la imagen de perfil (avatar).
/// - Gestionar el proceso de cierre de sesión, incluyendo la sincronización opcional de datos.
/// - Proveer feedback a la UI sobre el estado de las operaciones.
class AccountViewModel extends ChangeNotifier {
  final UserProfileRepository _userProfileRepository; // Repositorio para interactuar con los datos del perfil.
  final ImageCacheService _imageCacheService; // Servicio para la caché de imágenes (avatar).
  final SupabaseClient _supabaseClient; // Cliente de Supabase para operaciones de autenticación y generación de URLs firmadas.
  final SupabaseLogSyncService _logSyncService; // Servicio para sincronizar logs durante el cierre de sesión.
  final SharedPreferences _prefs; // Para leer preferencias (ej. `cloudSavePreferenceKey`).

  /// Constructor: Inyecta las dependencias necesarias.
  /// Llama a `loadProfileData()` para cargar los datos del perfil al instanciar el ViewModel.
  AccountViewModel({
    required UserProfileRepository userProfileRepository,
    required ImageCacheService imageCacheService,
    required SupabaseClient supabaseClient,
    required SupabaseLogSyncService logSyncService,
    required SharedPreferences sharedPreferences,
  })  : _userProfileRepository = userProfileRepository,
        _imageCacheService = imageCacheService,
        _supabaseClient = supabaseClient,
        _logSyncService = logSyncService,
        _prefs = sharedPreferences {
    loadProfileData(); // Carga inicial de los datos del perfil.
  }

  // --- Estado de la UI ---
  // Controlador para el campo de texto del nombre de usuario.
  final TextEditingController usernameController = TextEditingController();

  String? _selectedGender; // Género actualmente seleccionado.
  String? get selectedGender => _selectedGender;

  String? _avatarUrl; // URL del avatar para mostrar en el widget Avatar. Puede ser una URL firmada de Supabase.
  String? get avatarUrl => _avatarUrl;

  bool _isProcessing = false; // Indica si se está realizando una operación asíncrona.
  bool get isProcessing => _isProcessing;

  String _feedbackMessage = ''; // Mensaje de feedback para la UI (éxito o error).
  String get feedbackMessage => _feedbackMessage;
  bool _isErrorFeedback = false; // Indica si el `_feedbackMessage` es un mensaje de error.
  bool get isErrorFeedback => _isErrorFeedback;

  /// _setProcessing: Método privado para actualizar el estado de procesamiento y notificar a los listeners.
  void _setProcessing(bool processing) {
    _isProcessing = processing;
    notifyListeners(); // Notifica a la UI para que se reconstruya si es necesario.
  }

  /// _setFeedback: Método privado para establecer un mensaje de feedback y su tipo (error o no).
  void _setFeedback(String message, {bool isError = false}) {
    _feedbackMessage = message;
    _isErrorFeedback = isError;
    // Se asume que el método que llama a _setFeedback también llamará a notifyListeners()
    // al final de su operación, o se podría llamar aquí si se desea feedback inmediato.
  }
  /// clearFeedback: Limpia el mensaje de feedback y notifica a los listeners.
  void clearFeedback() {
    _feedbackMessage = '';
    _isErrorFeedback = false;
    notifyListeners();
  }


  // --- Métodos de Lógica de Negocio ---

  /// loadProfileData: Carga los datos del perfil del usuario actual desde el repositorio.
  ///
  /// Obtiene el nombre de usuario, género y la URL del avatar.
  /// Si existe una clave de caché para el avatar, genera una URL firmada de Supabase para mostrarla.
  /// `forceRemote: true` se usa para asegurar que se obtienen los datos más recientes del backend.
  Future<void> loadProfileData() async {
    _setProcessing(true);
    try {
      // Obtiene el perfil y los bytes del avatar del repositorio. `forceRemote: true` asegura datos frescos.
      final result = await _userProfileRepository.getCurrentUserProfile(forceRemote: true); //
      if (result.profile != null) {
        usernameController.text = result.profile!.username ?? ''; //
        _selectedGender = result.profile!.gender; //

        // Si hay una clave de caché para el avatar, intenta generar una URL firmada para mostrarlo.
        if (result.profile!.avatarCacheKey != null && result.profile!.avatarCacheKey!.isNotEmpty) { //
          try {
            // Genera una URL firmada de Supabase Storage que es válida por un tiempo limitado (ej. 7 días).
            final signedUrl = await _supabaseClient.storage
                .from('avatars') // Nombre del bucket en Supabase Storage.
                .createSignedUrl(result.profile!.avatarCacheKey!, 60 * 60 * 24 * 7); //
            _avatarUrl = signedUrl;
          } catch (e) {
            debugPrint("AccountViewModel: Error creando URL firmada para avatar: $e");
            _avatarUrl = null; // Si falla, no se muestra avatar.
          }
        } else {
          _avatarUrl = null; // No hay avatar.
        }
      } else {
        // Si no hay perfil (ej. nuevo usuario), se puede intentar pre-rellenar el nombre de usuario.
        usernameController.text = _supabaseClient.auth.currentUser?.email?.split('@').first ?? '';
        _avatarUrl = null;
        _selectedGender = null;
      }
    } catch (e) {
      _setFeedback("Error cargando perfil: ${e.toString()}", isError: true);
    } finally {
      _setProcessing(false);
    }
  }

  /// updateSelectedGender: Actualiza el género seleccionado por el usuario y notifica a la UI.
  void updateSelectedGender(String? newGender) {
    _selectedGender = newGender;
    notifyListeners(); // Para que la UI (Dropdown) se actualice.
  }

  /// updateProfileDetails: Actualiza los detalles del perfil del usuario (nombre, género).
  ///
  /// Llama al método correspondiente en `_userProfileRepository`.
  /// @return `true` si la actualización fue exitosa, `false` en caso contrario.
  Future<bool> updateProfileDetails() async {
    _setProcessing(true);
    final userName = usernameController.text.trim(); // Nombre de usuario limpio.
    try {
      // Llama al repositorio para actualizar los detalles.
      await _userProfileRepository.updateProfileDetails( //
        username: userName,
        gender: _selectedGender,
      );
      _setFeedback("¡Perfil actualizado correctamente!");
      _setProcessing(false);
      return true; // Éxito.
    } catch (e) {
      _setFeedback("Error al actualizar el perfil: ${e.toString()}", isError: true);
      _setProcessing(false);
      return false; // Fracaso.
    }
  }

  /// onAvatarUploaded: Maneja la URL del avatar después de que ha sido subido a Supabase Storage.
  ///
  /// Extrae la clave de caché de la URL, y luego llama al repositorio para actualizar
  /// la referencia del avatar en el perfil del usuario.
  ///
  /// @param supabaseStorageUrl La URL del avatar en Supabase Storage (puede ser una URL pública o una referencia al path).
  /// @return `true` si la actualización fue exitosa, `false` en caso contrario.
  Future<bool> onAvatarUploaded(String supabaseStorageUrl) async {
    _setProcessing(true);
    // Extrae el filePath (que se usará como clave de caché) de la URL.
    final String? newAvatarCacheKey = _imageCacheService.extractFilePathFromUrl(supabaseStorageUrl); //

    if (newAvatarCacheKey == null) {
      _setFeedback('Error procesando la URL de la imagen.', isError: true);
      _setProcessing(false);
      return false;
    }

    try {
      // Llama al repositorio para actualizar la información del avatar.
      await _userProfileRepository.updateUserAvatar( //
        avatarUrl: supabaseStorageUrl, // La URL para guardar en la base de datos de Supabase.
        newAvatarCacheKey: newAvatarCacheKey, // La clave para la caché local de Hive.
      );
      // Actualiza la URL local para que la UI refleje el nuevo avatar inmediatamente.
      // Esto podría ser una URL firmada si la `supabaseStorageUrl` era solo un path.
      // Para simplificar, si `supabaseStorageUrl` ya es una URL mostrable (ej. firmada de larga duración),
      // se puede usar directamente.
      _avatarUrl = supabaseStorageUrl;
      _setFeedback('¡Imagen de perfil actualizada!');
      _setProcessing(false);
      return true; // Éxito.
    } catch (e) {
      _setFeedback('Error inesperado al actualizar la imagen: ${e.toString()}', isError: true);
      _setProcessing(false);
      return false; // Fracaso.
    }
  }

  /// handleLogout: Gestiona el proceso de cierre de sesión.
  ///
  /// Incluye la lógica para preguntar al usuario si desea sincronizar datos locales no guardados
  /// antes de cerrar sesión, si aplica.
  ///
  /// @param promptUserFunction Una función (generalmente provista por la UI) que muestra
  ///                           un diálogo al usuario y devuelve su elección (`AccountPageLogoutPromptAction`).
  /// @return Un `Future` que resuelve a un registro (tupla) con `success: bool` y `message: String`.
  Future<({bool success, String message})> handleLogout(
      Future<AccountPageLogoutPromptAction?> Function() promptUserFunction //
      ) async {
    _setProcessing(true);

    // Comprueba si el guardado en la nube está habilitado y si hay datos locales.
    final bool cloudSaveCurrentlyEnabled = _prefs.getBool(cloudSavePreferenceKeyFromAccountVM) ?? false;
    final mealLogBox = Hive.box<MealLog>(mealLogBoxName); //
    final overnightLogBox = Hive.box<OvernightLog>(overnightLogBoxName); //
    final bool hasLocalData = mealLogBox.isNotEmpty || overnightLogBox.isNotEmpty;
    final bool isLoggedIn = _supabaseClient.auth.currentUser != null;

    AccountPageLogoutPromptAction? userAction = AccountPageLogoutPromptAction.logoutWithoutUploading; //

    // Si el usuario está logueado, el guardado en nube está DESACTIVADO, y hay datos locales,
    // se le pregunta al usuario qué hacer.
    if (isLoggedIn && !cloudSaveCurrentlyEnabled && hasLocalData) {
      _setProcessing(false); // Permite interacción con el diálogo.
      userAction = await promptUserFunction(); // Llama a la función provista por la UI para mostrar el diálogo.
      _setProcessing(true); // Reanuda estado de procesamiento.
    }

    if (userAction == AccountPageLogoutPromptAction.cancel) { //
      _setProcessing(false);
      return (success: false, message: "Logout cancelado.");
    }

    // Si el usuario elige subir datos antes de cerrar sesión.
    if (userAction == AccountPageLogoutPromptAction.uploadAndLogout) { //
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
        _setFeedback('Sincronización completada. Éxitos: $successCount, Errores: $errorCount');
      } catch (e) {
        _setFeedback('Error al subir datos: ${e.toString()}', isError: true);
        // Considerar si se debe continuar con el logout si la subida falla. Actualmente, sí continúa.
      }
    }

    // Procede a cerrar la sesión en Supabase y limpiar el perfil local.
    try {
      await _supabaseClient.auth.signOut(); // Cierra sesión en Supabase.
      await _userProfileRepository.clearLocalUserProfile(); // Limpia el perfil local. //
      _setProcessing(false);
      return (success: true, message: "Sesión cerrada correctamente.");
    } on AuthException catch (e) { // Manejo específico de errores de autenticación de Supabase.
      _setFeedback("Error al cerrar sesión: ${e.message}", isError: true);
      _setProcessing(false);
      return (success: false, message: "Error al cerrar sesión: ${e.message}");
    } catch (e) { // Manejo de otros errores.
      _setFeedback("Error inesperado al cerrar sesión: ${e.toString()}", isError: true);
      _setProcessing(false);
      return (success: false, message: "Error inesperado: ${e.toString()}");
    }
  }


  @override
  /// dispose: Libera los recursos de los TextEditingController cuando el ViewModel ya no se necesita.
  void dispose() {
    usernameController.dispose();
    super.dispose();
  }
}