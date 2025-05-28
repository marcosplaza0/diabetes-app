import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

abstract final class AppTheme {
  // Colores base para el nuevo tema
  static const Color _primaryLight = Color(0xFF00796B); // Un verde azulado profundo
  static const Color _primaryContainerLight = Color(0xFFA9E5DE);

  static const Color _secondaryLight = Color(0xFFFFA000); // Un ámbar vibrante
  static const Color _secondaryContainerLight = Color(0xFFFFE0B2);

  static const Color _tertiaryLight = Color(0xFF8D6E63); // Un marrón arena/piedra
  static const Color _tertiaryContainerLight = Color(0xFFD7CCC8);

  // Colores para el tema oscuro (ligeramente ajustados para el contraste y la estética en oscuro)
  static const Color _primaryDark = Color(0xFF4DB6AC); // Teal más claro para modo oscuro
  static const Color _primaryContainerDark = Color(0xFF00897B);

  static const Color _secondaryDark = Color(0xFFFFCA28); // Ámbar más brillante para modo oscuro
  static const Color _secondaryContainerDark = Color(0xFFB28900);

  static const Color _tertiaryDark = Color(0xFFA1887F); // Marrón arena más claro
  static const Color _tertiaryContainerDark = Color(0xFF5D4037);


  /// Tema claro definido con FlexColorScheme.
  static ThemeData light = FlexThemeData.light(
    colors: const FlexSchemeColor(
      primary: _primaryLight,
      primaryContainer: _primaryContainerLight,
      secondary: _secondaryLight,
      secondaryContainer: _secondaryContainerLight,
      tertiary: _tertiaryLight,
      tertiaryContainer: _tertiaryContainerLight,
      // appBarColor se puede omitir para que use los roles de color de M3 (ej. surface o primary)
      // error y errorContainer se generarán bien con M3
    ),
    surfaceMode: FlexSurfaceMode.level, // Superficies M3 con elevación sutil
    blendLevel: 7, // Nivel de mezcla para colores de superficie y combinados
    useMaterial3: true,
    useMaterial3ErrorColors: true,

    // Estilos de Sub-temas para Material 3
    subThemesData: const FlexSubThemesData(
      blendOnLevel: 10,
      useM2StyleDividerInM3: false, // Usar divisores estilo M3

      defaultRadius: 12.0, // Radio de esquina predeterminado para M3

      // Campos de Texto (InputDecorator)
      inputDecoratorSchemeColor: SchemeColor.primary,
      inputDecoratorIsFilled: true,
      inputDecoratorBackgroundAlpha: 0, // El color de relleno viene de SchemeColor.surfaceContainerHighest
      inputDecoratorBorderType: FlexInputBorderType.outline,
      inputDecoratorUnfocusedHasBorder: true,
      inputDecoratorUnfocusedBorderIsColored: false, // Usa SchemeColor.outline
      inputDecoratorFocusedBorderWidth: 2.0,
      inputDecoratorPrefixIconSchemeColor: SchemeColor.primary, // Color del icono prefijo

      // Botones
      // ElevatedButton (FilledButton en M3) se configurará por defecto correctamente.
      // Si quieres personalizar:
      // elevatedButtonSchemeColor: SchemeColor.primary, // Fondo
      // elevatedButtonSecondarySchemeColor: SchemeColor.onPrimary, // Texto/Icono
      // OutlinedButton
      outlinedButtonOutlineSchemeColor: SchemeColor.primary,
      // TextButton
      textButtonSchemeColor: SchemeColor.primary,


      // AppBar
      appBarBackgroundSchemeColor: SchemeColor.surface, // AppBar estándar M3
      appBarScrolledUnderElevation: 4.0,
      appBarCenterTitle: true, // Un toque moderno

      // Navigation Drawer
      drawerBackgroundSchemeColor: SchemeColor.surfaceContainerLow,
      drawerWidth: 280.0, // Ancho ajustado
      drawerIndicatorSchemeColor: SchemeColor.primaryContainer,
      drawerIndicatorOpacity: 1.0,
      drawerSelectedItemSchemeColor: SchemeColor.onPrimaryContainer,
      drawerUnselectedItemSchemeColor: SchemeColor.onSurfaceVariant,

      // FAB (Floating Action Button)
      fabUseShape: true,
      fabAlwaysCircular: true,
      fabSchemeColor: SchemeColor.tertiaryContainer, // Color de FAB M3

      // Tarjetas
      cardRadius: 12.0,

      // Diálogos
      dialogRadius: 28.0,
      timePickerDialogRadius: 28.0, // Consistencia

      // BottomNavigationBar y NavigationBar
      bottomNavigationBarBackgroundSchemeColor: SchemeColor.surfaceContainer,
      bottomNavigationBarSelectedIconSchemeColor: SchemeColor.primary,
      bottomNavigationBarUnselectedIconSchemeColor: SchemeColor.onSurfaceVariant,
      bottomNavigationBarSelectedLabelSchemeColor: SchemeColor.primary,
      bottomNavigationBarUnselectedLabelSchemeColor: SchemeColor.onSurfaceVariant,
      bottomNavigationBarElevation: 2.0,

      navigationBarBackgroundSchemeColor: SchemeColor.surfaceContainer, // Similar a BottomNav
      navigationBarSelectedIconSchemeColor: SchemeColor.onSecondaryContainer, // Usando onSecondaryContainer para el icono
      navigationBarSelectedLabelSchemeColor: SchemeColor.onSurface, // Etiqueta seleccionada
      navigationBarIndicatorSchemeColor: SchemeColor.secondaryContainer, // Indicador de color secundario
      navigationBarUnselectedIconSchemeColor: SchemeColor.onSurfaceVariant,
      navigationBarUnselectedLabelSchemeColor: SchemeColor.onSurfaceVariant,
      navigationBarElevation: 0.0, // Sin elevación por defecto en M3
    ),
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    // Tipografía (opcional, FlexColorScheme usará la tipografía M3 por defecto)
    // fontFamily: GoogleFonts.lato().fontFamily, // Ejemplo si quisieras una fuente específica
    cupertinoOverrideTheme: const CupertinoThemeData(applyThemeToAll: true),
  );

  /// Tema oscuro definido con FlexColorScheme.
  static ThemeData dark = FlexThemeData.dark(
    colors: const FlexSchemeColor(
      primary: _primaryDark,
      primaryContainer: _primaryContainerDark,
      secondary: _secondaryDark,
      secondaryContainer: _secondaryContainerDark,
      tertiary: _tertiaryDark,
      tertiaryContainer: _tertiaryContainerDark,
    ),
    surfaceMode: FlexSurfaceMode.level,
    blendLevel: 13, // Ligeramente más mezcla en modo oscuro
    useMaterial3: true,
    useMaterial3ErrorColors: true,

    subThemesData: const FlexSubThemesData(
      appBarBackgroundSchemeColor: SchemeColor.surface, // AppBar estándar M3
      appBarScrolledUnderElevation: 4.0,
      appBarCenterTitle: true,
      blendOnLevel: 20,
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
    // fontFamily: GoogleFonts.lato().fontFamily, // Ejemplo
    cupertinoOverrideTheme: const CupertinoThemeData(applyThemeToAll: true),
  );
}