// lib/core/auth/presentation/account_view_model.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // Para TextEditingController
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Para SupabaseClient, AuthException
import 'package:shared_preferences/shared_preferences.dart'; // Para SharedPreferences en logout

import 'package:diabetes_2/data/repositories/user_profile_repository.dart';
import 'package:diabetes_2/core/services/image_cache_service.dart';
import 'package:diabetes_2/data/models/logs/logs.dart'; // Para MealLog, OvernightLog en logout
import 'package:diabetes_2/core/services/supabase_log_sync_service.dart'; // Para logout
import 'package:diabetes_2/main.dart' show mealLogBoxName, overnightLogBoxName; // Para logout

// Mover el enum y la constante aquí o a un archivo de utilidades de la feature
enum AccountPageLogoutPromptAction {
  uploadAndLogout,
  logoutWithoutUploading,
  cancel,
}
const String cloudSavePreferenceKeyFromAccountVM = 'saveToCloudEnabled';


class AccountViewModel extends ChangeNotifier {
  final UserProfileRepository _userProfileRepository;
  final ImageCacheService _imageCacheService;
  final SupabaseClient _supabaseClient; // Para generar signedURL y operaciones de auth
  final SupabaseLogSyncService _logSyncService; // Para sincronizar logs al cerrar sesión
  final SharedPreferences _prefs; // Para leer preferencias en logout

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
    loadProfileData();
  }

  // --- Estado de la UI ---
  final TextEditingController usernameController = TextEditingController();

  String? _selectedGender;
  String? get selectedGender => _selectedGender;

  String? _avatarUrl; // Para el widget Avatar
  String? get avatarUrl => _avatarUrl;

  // Uint8List? _avatarBytes; // Podría usarse si Avatar se modifica
  // Uint8List? get avatarBytes => _avatarBytes;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  String _feedbackMessage = '';
  String get feedbackMessage => _feedbackMessage;
  bool _isErrorFeedback = false;
  bool get isErrorFeedback => _isErrorFeedback;

  void _setProcessing(bool processing) {
    _isProcessing = processing;
    notifyListeners();
  }

  void _setFeedback(String message, {bool isError = false}) {
    _feedbackMessage = message;
    _isErrorFeedback = isError;
    // Notificar si se quiere mostrar feedback inmediatamente, o dejar que el siguiente notifyListeners lo haga.
    // Por ahora, asumimos que un método que establece feedback también llamará a notifyListeners al final.
  }
  void clearFeedback() {
    _feedbackMessage = '';
    _isErrorFeedback = false;
    notifyListeners();
  }


  // --- Métodos de Lógica ---
  Future<void> loadProfileData() async {
    _setProcessing(true);
    try {
      final result = await _userProfileRepository.getCurrentUserProfile(forceRemote: true);
      if (result.profile != null) {
        usernameController.text = result.profile!.username ?? '';
        // _avatarBytes = result.avatarBytes;

        if (result.profile!.avatarCacheKey != null && result.profile!.avatarCacheKey!.isNotEmpty) {
          try {
            final signedUrl = await _supabaseClient.storage
                .from('avatars')
                .createSignedUrl(result.profile!.avatarCacheKey!, 60 * 60 * 24 * 7); // 7 días
            _avatarUrl = signedUrl;
          } catch (e) {
            debugPrint("AccountViewModel: Error creando URL firmada para avatar: $e");
            _avatarUrl = null;
          }
        } else {
          _avatarUrl = null;
        }
        _selectedGender = result.profile!.gender;
      } else {
        // Si no hay perfil (ej. nuevo usuario o deslogueado y luego relogueado antes de que el repo limpie)
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

  void updateSelectedGender(String? newGender) {
    _selectedGender = newGender;
    notifyListeners(); // Notificar para que la UI (Dropdown) se actualice si es necesario
  }

  Future<bool> updateProfileDetails() async {
    _setProcessing(true);
    final userName = usernameController.text.trim();
    try {
      await _userProfileRepository.updateProfileDetails(
        username: userName,
        gender: _selectedGender,
      );
      _setFeedback("¡Perfil actualizado correctamente!");
      _setProcessing(false);
      return true;
    } catch (e) {
      _setFeedback("Error al actualizar el perfil: ${e.toString()}", isError: true);
      _setProcessing(false);
      return false;
    }
  }

  Future<bool> onAvatarUploaded(String supabaseStorageUrl) async {
    _setProcessing(true);
    final String? newAvatarCacheKey = _imageCacheService.extractFilePathFromUrl(supabaseStorageUrl);

    if (newAvatarCacheKey == null) {
      _setFeedback('Error procesando la URL de la imagen.', isError: true);
      _setProcessing(false);
      return false;
    }

    try {
      await _userProfileRepository.updateUserAvatar(
        avatarUrl: supabaseStorageUrl,
        newAvatarCacheKey: newAvatarCacheKey,
      );
      // Actualizar la URL local para la UI inmediatamente
      _avatarUrl = supabaseStorageUrl;
      // Opcional: recargar _avatarBytes si Avatar se actualiza para usar MemoryImage
      // final bytes = await _userProfileRepository.getAvatarBytes(newAvatarCacheKey);
      // _avatarBytes = bytes;
      _setFeedback('¡Imagen de perfil actualizada!');
      _setProcessing(false);
      return true;
    } catch (e) {
      _setFeedback('Error inesperado al actualizar la imagen: ${e.toString()}', isError: true);
      _setProcessing(false);
      return false;
    }
  }

  Future<({bool success, String message})> handleLogout(
      Future<AccountPageLogoutPromptAction?> Function() promptUserFunction
      ) async {
    _setProcessing(true);

    final bool cloudSaveCurrentlyEnabled = _prefs.getBool(cloudSavePreferenceKeyFromAccountVM) ?? false;
    final mealLogBox = Hive.box<MealLog>(mealLogBoxName);
    final overnightLogBox = Hive.box<OvernightLog>(overnightLogBoxName);
    final bool hasLocalData = mealLogBox.isNotEmpty || overnightLogBox.isNotEmpty;
    final bool isLoggedIn = _supabaseClient.auth.currentUser != null;

    AccountPageLogoutPromptAction? userAction = AccountPageLogoutPromptAction.logoutWithoutUploading;

    if (isLoggedIn && !cloudSaveCurrentlyEnabled && hasLocalData) {
      _setProcessing(false); // Permitir interacción con el diálogo
      userAction = await promptUserFunction();
      _setProcessing(true); // Reanudar estado de procesamiento
    }

    if (userAction == AccountPageLogoutPromptAction.cancel) {
      _setProcessing(false);
      return (success: false, message: "Logout cancelado.");
    }

    if (userAction == AccountPageLogoutPromptAction.uploadAndLogout) {
      int successCount = 0; int errorCount = 0;
      try {
        for (var entry in mealLogBox.toMap().entries) {
          try { await _logSyncService.syncMealLog(entry.value, entry.key); successCount++; } catch (e) { errorCount++; }
        }
        for (var entry in overnightLogBox.toMap().entries) {
          try { await _logSyncService.syncOvernightLog(entry.value, entry.key); successCount++; } catch (e) { errorCount++; }
        }
        _setFeedback('Sincronización completada. Éxitos: $successCount, Errores: $errorCount');
      } catch (e) {
        _setFeedback('Error al subir datos: ${e.toString()}', isError: true);
        // No continuar con el logout si la subida falla y era la intención del usuario?
        // Por ahora, continuamos con el logout.
      }
    }

    try {
      await _supabaseClient.auth.signOut();
      await _userProfileRepository.clearLocalUserProfile();
      _setProcessing(false);
      return (success: true, message: "Sesión cerrada correctamente.");
    } on AuthException catch (e) {
      _setFeedback("Error al cerrar sesión: ${e.message}", isError: true);
      _setProcessing(false);
      return (success: false, message: "Error al cerrar sesión: ${e.message}");
    } catch (e) {
      _setFeedback("Error inesperado al cerrar sesión: ${e.toString()}", isError: true);
      _setProcessing(false);
      return (success: false, message: "Error inesperado: ${e.toString()}");
    }
  }


  @override
  void dispose() {
    usernameController.dispose();
    super.dispose();
  }
}