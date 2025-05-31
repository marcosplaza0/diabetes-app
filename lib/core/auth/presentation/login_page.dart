// Archivo: lib/core/auth/presentation/login_page.dart
// Descripción: Define la interfaz de usuario para la pantalla de inicio de sesión.
// Permite a los usuarios ingresar su correo electrónico y contraseña para acceder a la aplicación.
// Incluye validación de formulario, manejo de errores de autenticación y un enlace
// a la pantalla de registro para nuevos usuarios.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:flutter/material.dart'; // Framework principal de Flutter para UI.
import 'package:go_router/go_router.dart'; // Para la navegación (ej. al registrarse).
import 'package:supabase_flutter/supabase_flutter.dart' as supabase_auth; // Para AuthException, usado en el manejo de errores.

// Importaciones de archivos del proyecto
import 'package:diabetes_2/core/auth/auth_service.dart'; // Servicio de autenticación para interactuar con Supabase Auth.

/// LoginPage: Un StatefulWidget que construye la UI para la pantalla de inicio de sesión.
///
/// Gestiona el estado del formulario (email, contraseña), el estado de carga
/// durante el proceso de login, y la visibilidad de la contraseña.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Instancia del servicio de autenticación.
  final _authService = AuthService(); //
  // Clave global para identificar y gestionar el estado del Form.
  final _formKey = GlobalKey<FormState>();

  // Controladores para los campos de texto de email y contraseña.
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false; // Estado para indicar si se está procesando el inicio de sesión.
  bool _obscurePassword = true; // Estado para controlar la visibilidad de la contraseña.

  @override
  /// dispose: Libera los recursos de los TextEditingController cuando el widget ya no se utiliza.
  /// Es importante para prevenir memory leaks.
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// _showErrorSnackBar: Muestra un SnackBar personalizado con un mensaje de error.
  ///
  /// @param message El mensaje de error a mostrar.
  void _showErrorSnackBar(String message) {
    if (!mounted) return; // No mostrar si el widget no está montado.

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    ScaffoldMessenger.of(context).removeCurrentSnackBar(); // Elimina cualquier SnackBar visible.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row( // Contenido con icono y texto para mejor visualización.
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
        backgroundColor: colorScheme.error, // Color de fondo de error del tema.
        behavior: SnackBarBehavior.floating, // SnackBar flotante.
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 16), // Márgenes.
        shape: RoundedRectangleBorder( // Bordes redondeados.
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 4), // Duración del SnackBar.
        elevation: 4.0,
      ),
    );
  }

  /// _processErrorMessage: Procesa un error (generalmente una AuthException) y devuelve un mensaje amigable para el usuario.
  ///
  /// Traduce mensajes comunes de error de Supabase Auth a español y maneja errores de red.
  ///
  /// @param error El objeto de error capturado.
  /// @return Un String con el mensaje de error formateado para el usuario.
  String _processErrorMessage(dynamic error) {
    if (error is supabase_auth.AuthException) { // Si el error es una AuthException de Supabase.
      // Mapea mensajes de error comunes a mensajes más amigables en español.
      switch (error.message.toLowerCase()) {
        case 'invalid login credentials':
          return 'Correo electrónico o contraseña incorrectos. Por favor, verifica tus datos e inténtalo de nuevo.';
        case 'email not confirmed':
          return 'Tu correo electrónico aún no ha sido confirmado. Revisa tu bandeja de entrada para el enlace de confirmación.';
        case 'user not found': // Aunque 'invalid login credentials' suele cubrir esto.
          return 'No se encontró un usuario con ese correo electrónico.';
        case 'network error': // Errores comunes de red.
        case 'failed to fetch':
          return 'Error de conexión. Verifica tu conexión a internet e inténtalo de nuevo.';
        default:
        // Si el mensaje de error de Supabase es útil, se muestra; sino, un mensaje genérico.
          return error.message.isNotEmpty ? error.message : 'Ocurrió un error de autenticación.';
      }
    }

    // Para otros tipos de excepciones.
    String errorMessage = error.toString();
    if (errorMessage.startsWith("Exception: ")) { // Limpia el prefijo "Exception: ".
      errorMessage = errorMessage.replaceFirst("Exception: ", "");
    }

    // Detección genérica de errores de red.
    if (errorMessage.toLowerCase().contains('network') ||
        errorMessage.toLowerCase().contains('socket') ||
        errorMessage.toLowerCase().contains('failed host lookup')) {
      return 'Error de conexión. Verifica tu internet e inténtalo de nuevo.';
    }

    return errorMessage.isNotEmpty ? errorMessage : 'Ha ocurrido un error desconocido.';
  }

  /// _login: Intenta iniciar sesión con el email y contraseña proporcionados.
  ///
  /// Valida el formulario. Si es válido, llama al `AuthService` para iniciar sesión.
  /// Maneja los errores mostrando un SnackBar. El estado `_isLoading` se usa
  /// para mostrar un indicador de progreso y deshabilitar el botón de login.
  Future<void> _login() async {
    // Valida el formulario usando la _formKey.
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true; // Inicia el estado de carga.
      });

      final email = _emailController.text.trim(); // Obtiene y limpia el email.
      final password = _passwordController.text.trim(); // Obtiene y limpia la contraseña.

      try {
        // Llama al servicio de autenticación para iniciar sesión.
        await _authService.signInWithEmailAndPassword(email, password); //
        // La navegación en caso de éxito es manejada por GoRouter redirect basado en el AuthStateChange.
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
  }

  @override
  /// build: Construye la interfaz de usuario de la pantalla de Login.
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
              colorScheme.primary.withOpacity(0.1),
              colorScheme.surface,
              colorScheme.surface,
              colorScheme.secondary.withOpacity(0.1),
            ],
            stops: const [0.0, 0.4, 0.6, 1.0], // Puntos de parada del degradado.
          ),
        ),
        child: SafeArea( // Asegura que el contenido no se solape con elementos del sistema.
          child: Center( // Centra el contenido en la pantalla.
            child: SingleChildScrollView( // Permite el scroll si el contenido excede la altura.
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch, // Los hijos se estiran horizontalmente.
                children: <Widget>[
                  // Icono y título de la aplicación.
                  Icon(
                    Icons.monitor_heart_outlined, // Icono representativo.
                    size: 80,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Diabetes App', // Nombre de la app.
                    textAlign: TextAlign.center,
                    style: textTheme.headlineLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bienvenido/a de nuevo', // Mensaje de bienvenida.
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 40),

                  // Tarjeta que contiene el formulario de inicio de sesión.
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
                              validator: (value) { // Validación del campo.
                                if (value == null || value.isEmpty) {
                                  return 'Por favor, ingresa tu correo';
                                }
                                if (!value.contains('@') || !value.contains('.')) {
                                  return 'Ingresa un correo válido';
                                }
                                return null; // Válido.
                              },
                            ),
                            const SizedBox(height: 20),
                            // Campo de texto para la Contraseña.
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword, // Oculta/muestra la contraseña.
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon: Icon(Icons.lock_outline, color: colorScheme.primary),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                                suffixIcon: IconButton( // Botón para alternar la visibilidad de la contraseña.
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
                              validator: (value) { // Validación del campo.
                                if (value == null || value.isEmpty) {
                                  return 'Por favor, ingresa tu contraseña';
                                }
                                if (value.length < 6) {
                                  return 'La contraseña debe tener al menos 6 caracteres';
                                }
                                return null; // Válido.
                              },
                            ),
                            const SizedBox(height: 20),
                            // Botón de Iniciar Sesión o Indicador de Progreso.
                            _isLoading
                                ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                                : ElevatedButton.icon(
                              icon: const Icon(Icons.login, color: Colors.white),
                              label: Text('Iniciar Sesión', style: textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              onPressed: _login, // Llama al método _login.
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
                  const SizedBox(height: 32),
                  // Enlace a la pantalla de Registro.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('¿No tienes una cuenta?', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                      TextButton(
                        onPressed: () {
                          // Navega a la pantalla de registro usando GoRouter.
                          context.go('/register'); //
                        },
                        child: Text('Regístrate', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
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