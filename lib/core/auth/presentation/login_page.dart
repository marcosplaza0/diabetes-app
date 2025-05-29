import 'package:flutter/material.dart';
import 'package:diabetes_2/core/auth/auth_service.dart'; // Asegúrate que esta ruta es correcta
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase_auth; // Para AuthException

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // FUNCIÓN PARA MOSTRAR SNACKBAR DE ERROR PERSONALIZADO
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

  // FUNCIÓN PARA PROCESAR EL MENSAJE DE ERROR
  String _processErrorMessage(dynamic error) {
    if (error is supabase_auth.AuthException) {
      switch (error.message.toLowerCase()) {
        case 'invalid login credentials':
          return 'Correo electrónico o contraseña incorrectos. Por favor, verifica tus datos e inténtalo de nuevo.';
        case 'email not confirmed':
          return 'Tu correo electrónico aún no ha sido confirmado. Revisa tu bandeja de entrada para el enlace de confirmación.';
        case 'user not found':
          return 'No se encontró un usuario con ese correo electrónico.';
        case 'network error':
        case 'failed to fetch':
          return 'Error de conexión. Verifica tu conexión a internet e inténtalo de nuevo.';
        default:
          return error.message.isNotEmpty ? error.message : 'Ocurrió un error de autenticación.';
      }
    }

    String errorMessage = error.toString();
    if (errorMessage.startsWith("Exception: ")) {
      errorMessage = errorMessage.replaceFirst("Exception: ", "");
    }

    if (errorMessage.toLowerCase().contains('network') ||
        errorMessage.toLowerCase().contains('socket') ||
        errorMessage.toLowerCase().contains('failed host lookup')) {
      return 'Error de conexión. Verifica tu internet e inténtalo de nuevo.';
    }

    return errorMessage.isNotEmpty ? errorMessage : 'Ha ocurrido un error desconocido.';
  }

  Future<void> _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      try {
        await _authService.signInWithEmailAndPassword(email, password);
        // La navegación en caso de éxito se maneja externamente (ej. AuthWrapper)
        // if (mounted) context.go('/home');
      } catch (e) {
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withValues(alpha:0.1),
              colorScheme.surface,
              colorScheme.surface,
              colorScheme.secondary.withValues(alpha:0.1),
            ],
            stops: const [0.0, 0.4, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Icon(
                    Icons.monitor_heart_outlined,
                    size: 80,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Diabetes App',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bienvenido/a de nuevo',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 40),
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
                            _isLoading
                                ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                                : ElevatedButton.icon(
                              icon: const Icon(Icons.login, color: Colors.white),
                              label: Text('Iniciar Sesión', style: textTheme.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              onPressed: _login,
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
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('¿No tienes una cuenta?', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                      TextButton(
                        onPressed: () {
                          context.go('/register');
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