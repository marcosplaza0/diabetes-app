// Archivo: main_layout.dart
import 'package:flutter/material.dart';
import 'drawer/drawer_app.dart'; // Asegúrate que esta ruta es correcta
import 'package:diabetes_2/core/auth/auth_service.dart'; // Asegúrate que esta ruta es correcta


class MainLayout extends StatefulWidget {
  final String title;
  final Widget body;

  const MainLayout({
    super.key,
    required this.title,
    required this.body
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final authService = AuthService(); // Instancia del servicio de autenticación

  void _logout() async {
    try {
      await authService.signOut();
      // Después de cerrar sesión, es común navegar a la pantalla de login.
      // Si estás usando GoRouter y quieres asegurarte de que se reconstruye la pila:
      // while (context.canPop()) {
      //   context.pop();
      // }
      // context.go('/login'); // O la ruta que tengas para el login
      //
      // Si no usas GoRouter para esto o el AuthStateListener se encarga,
      // la lógica de redirección puede estar en otro lugar (ej. en el listener de auth).
      // Por ahora, solo se hace el signOut. La redirección debe manejarse
      // de acuerdo a tu flujo de autenticación global.
    } catch (e) {
      // Manejar errores de logout si es necesario
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al cerrar sesión: ${e.toString()}'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Acceder al tema actual

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true, // O quitarlo si appBarCenterTitle: true está en AppTheme.subThemesData
        shadowColor: theme.colorScheme.shadow,
        elevation: 5,

        actions: [
          IconButton(
            onPressed: _logout,
            icon: Icon(
              Icons.logout,
              color: theme.colorScheme.error,
            ),
            tooltip: 'Cerrar Sesión',
          )
        ],
      ),
      body: widget.body,
      drawer: const DrawerApp(), // DrawerApp se estilizará según el tema también
    );
  }
}