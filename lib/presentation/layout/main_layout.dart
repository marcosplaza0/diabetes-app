// Archivo: main_layout.dart
// Descripción: Define el diseño principal de la aplicación que se utiliza en todas las pantallas.
// Proporciona una estructura común con AppBar, Drawer y área de contenido.

import 'package:flutter/material.dart';
import 'drawer/drawer_app.dart';

/// Widget que implementa el diseño principal de la aplicación.
/// Proporciona una estructura común para todas las pantallas con una barra de navegación
/// superior, un menú lateral y un área de contenido personalizable.
class MainLayout extends StatefulWidget {
  /// Título que se muestra en la barra de navegación superior
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
        backgroundColor: Theme.of(context).colorScheme.onPrimaryFixedVariant,
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 6,
        shadowColor: Theme.of(context).colorScheme.shadow,
        centerTitle: true,
      ),
      body: widget.body,
      drawer: DrawerApp(),
    );
  }

}
