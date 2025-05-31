// Archivo: lib/core/theme/app_colors.dart
// Descripción: Define los temas claro y oscuro de la aplicación utilizando el paquete FlexColorScheme.
// Esta clase centraliza la configuración de la paleta de colores, los estilos de los componentes
// de Material 3 y otras propiedades visuales para asegurar una apariencia consistente.

// Importaciones del SDK de Flutter y paquetes de terceros
import 'package:flex_color_scheme/flex_color_scheme.dart'; // Paquete para crear temas de Flutter de forma avanzada y sencilla.
import 'package:flutter/cupertino.dart'; // Para CupertinoOverrideTheme, si se desea aplicar estilos a widgets de iOS.
import 'package:flutter/material.dart'; // Framework principal de Flutter para UI y ThemeData.

/// AppTheme: Clase abstracta y final que contiene las definiciones de los temas de la aplicación.
///
/// No se puede instanciar (`abstract final class`). Se utiliza para agrupar las
/// propiedades estáticas `light` y `dark` que representan los ThemeData de la aplicación.
abstract final class AppTheme {
  // --- Definición de Colores Base para los Temas ---
  // Estos colores primarios, secundarios y terciarios forman la base de los esquemas de color.
  // Se definen variantes para el tema claro y oscuro.

  // Colores base para el tema CLARO.
  static const Color _primaryLight = Color(0xFF00796B); // Verde azulado profundo (Teal oscuro).
  static const Color _primaryContainerLight = Color(0xFFA9E5DE); // Un tono más claro de _primaryLight para contenedores.

  static const Color _secondaryLight = Color(0xFFFFA000); // Ámbar vibrante.
  static const Color _secondaryContainerLight = Color(0xFFFFE0B2); // Un tono más claro de _secondaryLight para contenedores.

  static const Color _tertiaryLight = Color(0xFF8D6E63); // Marrón arena/piedra.
  static const Color _tertiaryContainerLight = Color(0xFFD7CCC8); // Un tono más claro de _tertiaryLight para contenedores.

  // Colores base para el tema OSCURO.
  static const Color _primaryDark = Color(0xFF4DB6AC); // Teal más claro para modo oscuro.
  static const Color _primaryContainerDark = Color(0xFF00897B); // Un tono más oscuro y saturado para contenedores en modo oscuro.

  static const Color _secondaryDark = Color(0xFFFFCA28); // Ámbar más brillante para modo oscuro.
  static const Color _secondaryContainerDark = Color(0xFFB28900); // Un tono ámbar más oscuro para contenedores en modo oscuro.

  static const Color _tertiaryDark = Color(0xFFA1887F); // Marrón arena más claro para modo oscuro.
  static const Color _tertiaryContainerDark = Color(0xFF5D4037); // Un tono marrón más oscuro para contenedores en modo oscuro.


  /// light: ThemeData para el modo claro de la aplicación.
  /// Configurado con `FlexThemeData.light` de FlexColorScheme.
  static ThemeData light = FlexThemeData.light(
    // Define el esquema de color base utilizando los colores primarios, secundarios y terciarios definidos arriba.
    colors: const FlexSchemeColor( //
      primary: _primaryLight, //
      primaryContainer: _primaryContainerLight, //
      secondary: _secondaryLight, //
      secondaryContainer: _secondaryContainerLight, //
      tertiary: _tertiaryLight, //
      tertiaryContainer: _tertiaryContainerLight, //
      // appBarColor y error/errorContainer se pueden omitir para que FlexColorScheme
      // los genere automáticamente según las directrices de Material 3.
    ),
    surfaceMode: FlexSurfaceMode.level, // Define cómo se generan los colores de superficie y fondo con elevación sutil (estilo M3).
    blendLevel: 7, // Nivel de mezcla para generar colores armonizados a partir de los colores base.
    useMaterial3: true, // Habilita el uso completo de Material 3.
    useMaterial3ErrorColors: true, // Utiliza los colores de error definidos por Material 3.

    // Configuración detallada para sub-temas de componentes específicos de Material 3.
    subThemesData: const FlexSubThemesData(
      blendOnLevel: 10, // Nivel de mezcla adicional para superficies con mayor énfasis.
      useM2StyleDividerInM3: false, // Asegura que los divisores usen el estilo de Material 3.

      defaultRadius: 12.0, // Radio de esquina predeterminado para la mayoría de los componentes M3 (Cards, Buttons, Dialogs).

      // Configuración para Campos de Texto (InputDecorator).
      inputDecoratorSchemeColor: SchemeColor.primary, // El color principal (borde, icono, etiqueta flotante) se basa en el primario del tema.
      inputDecoratorIsFilled: true, // Indica que los campos de texto tendrán un color de relleno.
      inputDecoratorBackgroundAlpha: 0, // Alfa del color de relleno. Un valor bajo o 0 usualmente significa que el color se tomará de roles como surfaceContainerHighest.
      inputDecoratorBorderType: FlexInputBorderType.outline, // Tipo de borde (outline, underline).
      inputDecoratorUnfocusedHasBorder: true, // Muestra el borde incluso cuando el campo no está enfocado.
      inputDecoratorUnfocusedBorderIsColored: false, // El borde no enfocado usa el color 'outline' del tema, no el 'primary'.
      inputDecoratorFocusedBorderWidth: 2.0, // Ancho del borde cuando el campo está enfocado.
      inputDecoratorPrefixIconSchemeColor: SchemeColor.primary, // Color para los iconos de prefijo.

      // Configuración para Botones.
      // ElevatedButton (equivalente a FilledButton en M3) se configura bien por defecto.
      // OutlinedButton: usa el color primario del tema para su borde.
      outlinedButtonOutlineSchemeColor: SchemeColor.primary,
      // TextButton: usa el color primario del tema para su texto.
      textButtonSchemeColor: SchemeColor.primary,


      // Configuración para AppBar.
      appBarBackgroundSchemeColor: SchemeColor.surface, // Color de fondo estándar de AppBar en M3.
      appBarScrolledUnderElevation: 4.0, // Elevación que aparece cuando hay contenido detrás de la AppBar haciendo scroll.
      appBarCenterTitle: true, // Centra el título en la AppBar.

      // Configuración para Navigation Drawer (Menú Lateral).
      drawerBackgroundSchemeColor: SchemeColor.surfaceContainerLow, // Color de fondo del Drawer.
      drawerWidth: 280.0, // Ancho del Drawer.
      drawerIndicatorSchemeColor: SchemeColor.primaryContainer, // Color del indicador del item seleccionado.
      drawerIndicatorOpacity: 1.0, // Opacidad del indicador.
      drawerSelectedItemSchemeColor: SchemeColor.onPrimaryContainer, // Color del texto/icono del item seleccionado.
      drawerUnselectedItemSchemeColor: SchemeColor.onSurfaceVariant, // Color del texto/icono de items no seleccionados.

      // Configuración para Floating Action Button (FAB).
      fabUseShape: true, // Usa la forma definida por el tema (generalmente circular o rounded rectangle).
      fabAlwaysCircular: true, // Fuerza que el FAB sea siempre circular.
      fabSchemeColor: SchemeColor.tertiaryContainer, // Color de fondo del FAB según las guías de M3.

      // Configuración para Cards.
      cardRadius: 12.0, // Radio de esquina para las tarjetas, consistente con `defaultRadius`.

      // Configuración para Diálogos.
      dialogRadius: 28.0, // Radio de esquina para diálogos.
      timePickerDialogRadius: 28.0, // Radio para el selector de hora, manteniendo consistencia.

      // Configuración para BottomNavigationBar (Barra de Navegación Inferior).
      bottomNavigationBarBackgroundSchemeColor: SchemeColor.surfaceContainer, // Color de fondo.
      bottomNavigationBarSelectedIconSchemeColor: SchemeColor.primary, // Color del icono seleccionado.
      bottomNavigationBarUnselectedIconSchemeColor: SchemeColor.onSurfaceVariant, // Color del icono no seleccionado.
      bottomNavigationBarSelectedLabelSchemeColor: SchemeColor.primary, // Color de la etiqueta seleccionada.
      bottomNavigationBarUnselectedLabelSchemeColor: SchemeColor.onSurfaceVariant, // Color de la etiqueta no seleccionada.
      bottomNavigationBarElevation: 2.0, // Elevación de la barra.

      // Configuración para NavigationBar (Widget de navegación principal de M3, a menudo usado en la parte inferior).
      navigationBarBackgroundSchemeColor: SchemeColor.surfaceContainer, // Color de fondo.
      navigationBarSelectedIconSchemeColor: SchemeColor.onSecondaryContainer, // Color del icono seleccionado.
      navigationBarSelectedLabelSchemeColor: SchemeColor.onSurface, // Color de la etiqueta seleccionada.
      navigationBarIndicatorSchemeColor: SchemeColor.secondaryContainer, // Color del indicador del item seleccionado.
      navigationBarUnselectedIconSchemeColor: SchemeColor.onSurfaceVariant, // Color del icono no seleccionado.
      navigationBarUnselectedLabelSchemeColor: SchemeColor.onSurfaceVariant, // Color de la etiqueta no seleccionada.
      navigationBarElevation: 0.0, // Sin elevación por defecto en M3.
    ),
    visualDensity: FlexColorScheme.comfortablePlatformDensity, // Adapta la densidad visual a la plataforma.
    // fontFamily: GoogleFonts.lato().fontFamily, // Ejemplo si se quisiera usar una fuente específica de Google Fonts.
    // Permite aplicar estilos del tema de Flutter a widgets de Cupertino (iOS).
    cupertinoOverrideTheme: const CupertinoThemeData(applyThemeToAll: true),
  );

  /// dark: ThemeData para el modo oscuro de la aplicación.
  /// Configurado con `FlexThemeData.dark`, similar al tema claro pero con colores base oscuros.
  static ThemeData dark = FlexThemeData.dark(
    colors: const FlexSchemeColor( //
      primary: _primaryDark, //
      primaryContainer: _primaryContainerDark, //
      secondary: _secondaryDark, //
      secondaryContainer: _secondaryContainerDark, //
      tertiary: _tertiaryDark, //
      tertiaryContainer: _tertiaryContainerDark, //
    ),
    surfaceMode: FlexSurfaceMode.level,
    blendLevel: 13, // Nivel de mezcla ligeramente mayor para el tema oscuro, para suavizar contrastes.
    useMaterial3: true,
    useMaterial3ErrorColors: true,

    // La configuración de subThemesData es muy similar a la del tema claro,
    // FlexColorScheme adapta los SchemeColors automáticamente para el modo oscuro.
    // Se repiten aquí para claridad y por si se necesitaran ajustes específicos para el modo oscuro.
    subThemesData: const FlexSubThemesData(
      appBarBackgroundSchemeColor: SchemeColor.surface,
      appBarScrolledUnderElevation: 4.0,
      appBarCenterTitle: true,
      blendOnLevel: 20, // Mayor nivel de mezcla para superficies en modo oscuro.
      useM2StyleDividerInM3: false,

      defaultRadius: 12.0,

      inputDecoratorSchemeColor: SchemeColor.primary,
      inputDecoratorIsFilled: true,
      inputDecoratorBackgroundAlpha: 0,
      inputDecoratorBorderType: FlexInputBorderType.outline,
      inputDecoratorUnfocusedHasBorder: true,
      inputDecoratorUnfocusedBorderIsColored: false,
      inputDecoratorFocusedBorderWidth: 2.0,
      inputDecoratorPrefixIconSchemeColor: SchemeColor.primary,

      outlinedButtonOutlineSchemeColor: SchemeColor.primary,
      textButtonSchemeColor: SchemeColor.primary,

      drawerBackgroundSchemeColor: SchemeColor.surfaceContainerLow,
      drawerWidth: 280.0,
      drawerIndicatorSchemeColor: SchemeColor.primaryContainer,
      drawerIndicatorOpacity: 1.0,
      drawerSelectedItemSchemeColor: SchemeColor.onPrimaryContainer,
      drawerUnselectedItemSchemeColor: SchemeColor.onSurfaceVariant,

      fabUseShape: true,
      fabAlwaysCircular: true,
      fabSchemeColor: SchemeColor.tertiaryContainer,

      cardRadius: 12.0,
      dialogRadius: 28.0,
      timePickerDialogRadius: 28.0,

      bottomNavigationBarBackgroundSchemeColor: SchemeColor.surfaceContainer,
      bottomNavigationBarSelectedIconSchemeColor: SchemeColor.primary,
      bottomNavigationBarUnselectedIconSchemeColor: SchemeColor.onSurfaceVariant,
      bottomNavigationBarSelectedLabelSchemeColor: SchemeColor.primary,
      bottomNavigationBarUnselectedLabelSchemeColor: SchemeColor.onSurfaceVariant,
      bottomNavigationBarElevation: 2.0,

      navigationBarBackgroundSchemeColor: SchemeColor.surfaceContainer,
      navigationBarSelectedIconSchemeColor: SchemeColor.onSecondaryContainer,
      navigationBarSelectedLabelSchemeColor: SchemeColor.onSurface,
      navigationBarIndicatorSchemeColor: SchemeColor.secondaryContainer,
      navigationBarUnselectedIconSchemeColor: SchemeColor.onSurfaceVariant,
      navigationBarUnselectedLabelSchemeColor: SchemeColor.onSurfaceVariant,
      navigationBarElevation: 0.0,
    ),
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    cupertinoOverrideTheme: const CupertinoThemeData(applyThemeToAll: true),
  );
}