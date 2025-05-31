// Archivo: lib/core/auth/presentation/register_page.dart
// Descripción: Define la interfaz de usuario para la pantalla de registro de nuevos usuarios.
// Permite a los usuarios crear una nueva cuenta proporcionando su correo electrónico y una contraseña.
// Incluye validación de formulario (incluyendo confirmación de contraseña), manejo de errores
// de registro, y muestra un mensaje de éxito pidiendo la confirmación por correo electrónico.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:flutter/material.dart'; // Framework principal de Flutter para UI.
import 'package:go_router/go_router.dart'; // Para la navegación (ej. al iniciar sesión o después del registro).
import 'package:supabase_flutter/supabase_flutter.dart' as supabase_auth; // Para AuthException, usado en el manejo de errores.

// Importaciones de archivos del proyecto
import 'package:diabetes_2/core/auth/auth_service.dart'; // Servicio de autenticación para interactuar con Supabase Auth.

/// RegisterPage: Un StatefulWidget que construye la UI para la pantalla de registro.
///
/// Gestiona el estado del formulario (email, contraseña, confirmación de contraseña),
/// el estado de carga durante el proceso de registro, y la visibilidad de las contraseñas.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Instancia del servicio de autenticación.
  final _authService = AuthService(); //
  // Clave global para identificar y gestionar el estado del Form.
  final _formKey = GlobalKey<FormState>();

  // Controladores para los campos de texto.
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController(); // Para confirmar la contraseña.

  bool _isLoading = false; // Estado para indicar si se está procesando el registro.
  bool _obscurePassword = true; // Estado para controlar la visibilidad de la contraseña principal.
  bool _obscureConfirmPassword = true; // Estado para controlar la visibilidad de la contraseña de confirmación.

  @override
  /// dispose: Libera los recursos de los TextEditingController cuando el widget ya no se utiliza.
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// _showErrorSnackBar: Muestra un SnackBar personalizado con un mensaje de error.
  /// (Reutilizada y similar a la de LoginPage)
  ///
  /// @param message El mensaje de error a mostrar.
  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: colorScheme.onError),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colorScheme.onError, fontSize: 15),
              ),
            ),
          ],
        ),
        backgroundColor: colorScheme.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
        elevation: 4.0,
      ),
    );
  }

  /// _showSuccessSnackBar: Muestra un SnackBar personalizado con un mensaje de éxito.
  ///
  /// @param message El mensaje de éxito a mostrar (ej. confirmación de registro).
  void _showSuccessSnackBar(String message) {
    if (!mounted) return;

    // Colores personalizados para el SnackBar de éxito.
    final successBackgroundColor = Colors.green.shade700;
    final onSuccessColor = Colors.white;

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: onSuccessColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: onSuccessColor, fontSize: 15),
              ),
            ),
          ],
        ),
        backgroundColor: successBackgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 6), // Duración un poco más larga para mensajes importantes.
        elevation: 4.0,
      ),
    );
  }

  /// _processErrorMessage: Procesa un error (generalmente una AuthException) y devuelve un mensaje amigable para el usuario.
  ///
  /// Adaptado para errores comunes durante el proceso de registro en Supabase Auth.
  ///
  /// @param error El objeto de error capturado.
  /// @return Un String con el mensaje de error formateado para el usuario.
  String _processErrorMessage(dynamic error) {
    if (error is supabase_auth.AuthException) {
      String message = error.message.toLowerCase();
      if (message.contains('user already registered') || message.contains('user already exists')) {
        return 'Este correo electrónico ya está registrado. Por favor, intenta iniciar sesión.';
      } else if (message.contains('email rate limit exceeded')) {
        return 'Se han enviado demasiadas solicitudes para este correo. Por favor, inténtalo más tarde.';
      } else if (message.contains('password should be at least 6 characters')) {
        return 'La contraseña es demasiado corta. Debe tener al menos 6 caracteres.';
      } else if (message.contains('network request failed') || message.contains('failed host lookup') || message.contains('socketexception')) {
        return 'Error de conexión. Verifica tu conexión a internet e inténtalo de nuevo.';
      }
      // Para otros errores de AuthException específicos del registro, se podría añadir más lógica aquí.
      // Si no es uno de los anteriores, se devuelve el mensaje original o uno genérico.
      return error.message.isNotEmpty ? error.message : 'Ocurrió un error durante el registro.';
    }

    // Manejo para otros tipos de errores (no AuthException)
    String errorMessage = error.toString().toLowerCase();
    if (errorMessage.contains('network request failed') ||
        errorMessage.contains('failed host lookup') ||
        errorMessage.contains('socketexception') ||
        errorMessage.contains('handshake failed') ||
        errorMessage.contains('connection timed out')) {
      return 'Error de conexión. Verifica tu conexión a internet e inténtalo de nuevo.';
    }

    return 'Ha ocurrido un error desconocido durante el registro. Por favor, inténtalo más tarde.';
  }


  /// _signUp: Intenta registrar un nuevo usuario con el email y contraseña proporcionados.
  ///
  /// Valida el formulario. Si es válido, llama al `AuthService` para registrar al usuario.
  /// En caso de éxito, muestra un mensaje pidiendo la confirmación por email y navega.
  /// Maneja los errores mostrando un SnackBar. El estado `_isLoading` se usa
  /// para mostrar un indicador de progreso y deshabilitar el botón de registro.
  Future<void> _signUp() async {
    // Valida el formulario. Si no es válido, no continuar.
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final email = _emailController.text.trim(); // Obtiene y limpia el email.
    final password = _passwordController.text.trim(); // Obtiene y limpia la contraseña.

    setState(() {
      _isLoading = true; // Inicia el estado de carga.
    });

    try {
      // Llama al servicio de autenticación para registrar al nuevo usuario.
      await _authService.signUpWithEmailAndPassword(email, password); //

      if (mounted) {
        // Muestra un mensaje de éxito indicando que se envió un correo de confirmación.
        _showSuccessSnackBar( '¡Registro casi completo! Se ha enviado un correo de confirmación a $email. Por favor, verifica tu email para activar tu cuenta.');

        // Retraso opcional para dar tiempo al usuario a leer el SnackBar antes de navegar.
        await Future.delayed(const Duration(seconds: 1)); // Reducido para una experiencia más ágil.

        if(!mounted) return;

        // Navega a la pantalla de login o cierra la pantalla actual si es posible.
        // GoRouter se encargará de la redirección principal basada en el estado de autenticación.
        if (context.canPop()) { // Si se puede volver a la pantalla anterior (ej. Login).
          context.pop();
        } else { // Sino, navega a /login.
          context.go('/login'); //
        }
      }
    } catch (e) {
      // Procesa el error y muestra un mensaje amigable en un SnackBar.
      final String friendlyErrorMessage = _processErrorMessage(e);
      _showErrorSnackBar(friendlyErrorMessage);
    } finally {
      // Asegura que el estado de carga se desactive, incluso si hay un error.
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  /// build: Construye la interfaz de usuario de la pantalla de Registro.
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      body: Container( // Contenedor principal con un degradado de fondo.
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withValues(alpha:0.05),
              colorScheme.surface,
              colorScheme.surface,
              colorScheme.secondary.withValues(alpha:0.05),
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea( // Asegura que el contenido no se solape con elementos del sistema.
          child: Center( // Centra el contenido.
            child: SingleChildScrollView( // Permite el scroll.
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Icono y título de la pantalla.
                  Icon(
                    Icons.person_add_alt_1_outlined, // Icono para registro.
                    size: 70,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Crear Cuenta', // Título.
                    textAlign: TextAlign.center,
                    style: textTheme.headlineLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Únete a nuestra comunidad', // Subtítulo.
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 32),

                  // Tarjeta que contiene el formulario de registro.
                  Card(
                    elevation: 8.0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey, // Asocia la clave global al formulario.
                        child: Column(
                          children: <Widget>[
                            // Campo de texto para el Correo Electrónico.
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Correo Electrónico',
                                hintText: 'tuemail@ejemplo.com',
                                prefixIcon: Icon(Icons.email_outlined, color: colorScheme.primary),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                              ),
                              validator: (value) { // Validación.
                                if (value == null || value.isEmpty) {
                                  return 'Por favor, ingresa tu correo';
                                }
                                if (!value.contains('@') || !value.contains('.')) {
                                  return 'Ingresa un correo válido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            // Campo de texto para la Contraseña.
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword, // Visibilidad de la contraseña.
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon: Icon(Icons.lock_outline, color: colorScheme.primary),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                                suffixIcon: IconButton( // Botón para alternar visibilidad.
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) { // Validación.
                                if (value == null || value.isEmpty) {
                                  return 'Por favor, ingresa tu contraseña';
                                }
                                if (value.length < 6) {
                                  return 'La contraseña debe tener al menos 6 caracteres';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            // Campo de texto para Confirmar Contraseña.
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword, // Visibilidad.
                              decoration: InputDecoration(
                                labelText: 'Confirmar Contraseña',
                                prefixIcon: Icon(Icons.lock_reset_outlined, color: colorScheme.primary),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                                suffixIcon: IconButton( // Botón para alternar visibilidad.
                                  icon: Icon(
                                    _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword = !_obscureConfirmPassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) { // Validación (debe coincidir con la contraseña).
                                if (value == null || value.isEmpty) {
                                  return 'Por favor, confirma tu contraseña';
                                }
                                if (value != _passwordController.text) {
                                  return 'Las contraseñas no coinciden';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 30),
                            // Botón de Registrarse o Indicador de Progreso.
                            _isLoading
                                ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                                : ElevatedButton.icon(
                              icon: const Icon(Icons.app_registration, color: Colors.white),
                              label: Text('Registrarse', style: textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              onPressed: _signUp, // Llama al método _signUp.
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 24.0),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                                elevation: 4.0,
                                minimumSize: const Size(double.infinity, 50), // Ocupa todo el ancho.
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Enlace a la pantalla de Inicio de Sesión.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('¿Ya tienes una cuenta?', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                      TextButton(
                        onPressed: () {
                          // Navega a la pantalla de login.
                          if (context.canPop()) { // Si se puede volver (ej. vino de Login).
                            context.pop();
                          } else { // Sino, navega directamente.
                            context.go('/login'); //
                          }
                        },
                        child: Text('Inicia Sesión', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}