// Archivo: main_layout.dart
import 'package:flutter/material.dart';
import 'drawer/drawer_app.dart'; // Asumo que esta ruta es correcta

import 'package:diabetes_2/core/auth/auth_service.dart';

class MainLayout extends StatefulWidget {
  final String title;
  final Widget body;
  // Si tu GoRouter pasa un `StatefulNavigationShell` como body, podría ser Widget en lugar de Widget?
  // O si siempre es un Widget, está bien.

  const MainLayout({
    super.key,
    required this.title,
    required this.body
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {

  final authService = AuthService();
  void logout() async {
    await authService.signOut();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
        backgroundColor: Theme.of(context).colorScheme.onPrimaryFixedVariant,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 6,
        shadowColor: Theme.of(context).colorScheme.shadow,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: logout,
              icon: Icon(Icons.logout, color: Theme.of(context).colorScheme.onPrimaryFixedVariant),
          )
        ],
      ),
      body: widget.body,
      drawer: DrawerApp(), // Asumo que DrawerApp está definido
    );
  }
}