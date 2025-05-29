import 'package:flutter/material.dart';
import 'package:diabetes_2/core/auth/auth_service.dart'; // Asegúrate que esta ruta es correcta
import 'package:go_router/go_router.dart'; // Para la navegación
import 'package:supabase_flutter/supabase_flutter.dart' as supabase_auth; // Para AuthException

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // FUNCIÓN PARA MOSTRAR SNACKBAR DE ERROR PERSONALIZADO (REUTILIZADA)
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 4),
        elevation: 4.0,
      ),
    );
  }

  // NUEVA FUNCIÓN PARA MOSTRAR SNACKBAR DE ÉXITO PERSONALIZADO
  void _showSuccessSnackBar(String message) {
    if (!mounted) return;

    final successBackgroundColor = Colors.green.shade700; // Puedes ajustar esto
    final onSuccessColor = Colors.white; // Color para el texto y el icono sobre el fondo de éxito

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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 6), // Un poco más largo para mensajes informativos importantes
        elevation: 4.0,
      ),
    );
  }

  // FUNCIÓN PARA PROCESAR EL MENSAJE DE ERROR (ADAPTADA PARA REGISTRO)
  String _processErrorMessage(dynamic error) {
    if (error is supabase_auth.AuthException) {
      // Mensajes específicos para errores de registro de Supabase
      // Los mensajes exactos de Supabase pueden variar. Revisa tu consola para ajustarlos.
      String errorMessage = error.message.toLowerCase();
      if (errorMessage.contains('user already registered') || errorMessage.contains('user already exists')) {
        return 'Este correo electrónico ya está registrado. Por favor, intenta iniciar sesión.';
      }
      if (errorMessage.contains('email rate limit exceeded')) {
        return 'Se han enviado demasiadas solicitudes para este correo. Por favor, inténtalo más tarde.';
      }
      if (errorMessage.contains('password should be at least 6 characters')) {
        return 'La contraseña es demasiado corta. Debe tener al menos 6 caracteres.';
      }
      // Fallback para otros errores de AuthException
      return error.message.isNotEmpty ? error.message : 'Ocurrió un error durante el registro.';
    }

    // Manejo para otros tipos de errores
    String generalErrorMessage = error.toString();
    if (generalErrorMessage.startsWith("Exception: ")) {
      generalErrorMessage = generalErrorMessage.replaceFirst("Exception: ", "");
    }

    if (generalErrorMessage.toLowerCase().contains('network') ||
        generalErrorMessage.toLowerCase().contains('socket') ||
        generalErrorMessage.toLowerCase().contains('failed host lookup')) {
      return 'Error de conexión. Verifica tu conexión a internet e inténtalo de nuevo.';
    }

    return generalErrorMessage.isNotEmpty ? generalErrorMessage : 'Ha ocurrido un error desconocido.';
  }

  Future<void> _signUp() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.signUpWithEmailAndPassword(email, password);

      if (mounted) {
        // USA LA NUEVA FUNCIÓN DE SNACKBAR DE ÉXITO
        _showSuccessSnackBar( '¡Registro casi completo! Se ha enviado un correo de confirmación a $email. Por favor, verifica tu email para activar tu cuenta.');

        // Retraso opcional antes de navegar para dar tiempo a leer el SnackBar
        await Future.delayed(const Duration(seconds: 1));

        if(!mounted) return;

        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/login');
        }
      }
    } catch (e) {
      // USA LAS FUNCIONES DE PROCESAMIENTO Y MUESTRA DE ERROR
      final String friendlyErrorMessage = _processErrorMessage(e);
      _showErrorSnackBar(friendlyErrorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration( // Mismo degradado que el login para consistencia
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
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Icon(
                    Icons.person_add_alt_1_outlined, // Icono para registro
                    size: 70,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Crear Cuenta',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Únete a nuestra comunidad',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 32),

                  Card(
                    elevation: 8.0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: <Widget>[
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Correo Electrónico',
                                hintText: 'tuemail@ejemplo.com',
                                prefixIcon: Icon(Icons.email_outlined, color: colorScheme.primary),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                              ),
                              validator: (value) {
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
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon: Icon(Icons.lock_outline, color: colorScheme.primary),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                                suffixIcon: IconButton(
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
                              validator: (value) {
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
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              decoration: InputDecoration(
                                labelText: 'Confirmar Contraseña',
                                prefixIcon: Icon(Icons.lock_reset_outlined, color: colorScheme.primary),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                                suffixIcon: IconButton(
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
                              validator: (value) {
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
                            _isLoading
                                ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                                : ElevatedButton.icon(
                              icon: const Icon(Icons.app_registration, color: Colors.white),
                              label: Text('Registrarse', style: textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              onPressed: _signUp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 24.0),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                                elevation: 4.0,
                                minimumSize: const Size(double.infinity, 50),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('¿Ya tienes una cuenta?', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                      TextButton(
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/login');
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