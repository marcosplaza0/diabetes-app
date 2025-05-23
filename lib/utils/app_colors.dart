// Archivo: app_colors.dart
// Descripción: Define los temas claro y oscuro para la aplicación utilizando FlexColorScheme.
// Este archivo contiene todas las configuraciones de colores y estilos para la interfaz de usuario.

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// La clase [AppTheme] define los temas claro y oscuro para la aplicación.
///
/// Configuración de tema para el paquete FlexColorScheme versión 8.
/// Utiliza la misma versión principal del paquete flex_color_scheme. Si utilizas una
/// versión menor, algunas propiedades podrían no ser compatibles.
/// En ese caso, elimínalas después de copiar este tema a tu
/// aplicación o actualiza el paquete a la versión 8.2.0.
///
/// Úsalo en un [MaterialApp] de esta manera:
///
/// MaterialApp(
///   theme: AppTheme.light,
///   darkTheme: AppTheme.dark,
/// );
abstract final class AppTheme {
  /// Tema claro definido con FlexColorScheme.
  /// Contiene todas las configuraciones de colores y estilos para el modo claro de la aplicación.
  static ThemeData light = FlexThemeData.light(
    // Colores personalizados definidos por el usuario con la API FlexSchemeColor().
    colors: const FlexSchemeColor(
      primary: Color(0xFFA5D3F6),
      primaryContainer: Color(0xFFDEFBFF),
      secondary: Color(0xFF90D792),
      secondaryContainer: Color(0xFFC8E6C9),
      tertiary: Color(0xFFFFCC80),
      tertiaryContainer: Color(0xFFFFE0B2),
      appBarColor: Color(0xFFC8E6C9),
      error: Color(0xFFBA1A1A),
      errorContainer: Color(0xFFFFDAD6),
    ),
    // Modificadores de color de entrada.
    useMaterial3ErrorColors: true,
    // Ajustes de color de superficie.
    surfaceMode: FlexSurfaceMode.highBackgroundLowScaffold,
    blendLevel: 1,
    // Propiedades de estilo directo.
    bottomAppBarElevation: 2.0,
    // Configuraciones de tema de componentes para el modo claro.
    subThemesData: const FlexSubThemesData(
      interactionEffects: true,
      tintedDisabledControls: true,
      blendOnLevel: 6,
      useM2StyleDividerInM3: true,
      adaptiveElevationShadowsBack: FlexAdaptive.excludeWebAndroidFuchsia(),
      adaptiveAppBarScrollUnderOff: FlexAdaptive.excludeWebAndroidFuchsia(),
      adaptiveRadius: FlexAdaptive.excludeWebAndroidFuchsia(),
      defaultRadiusAdaptive: 10.0,
      elevatedButtonSchemeColor: SchemeColor.onPrimaryContainer,
      elevatedButtonSecondarySchemeColor: SchemeColor.primaryContainer,
      outlinedButtonOutlineSchemeColor: SchemeColor.primary,
      toggleButtonsBorderSchemeColor: SchemeColor.primary,
      segmentedButtonSchemeColor: SchemeColor.primary,
      segmentedButtonBorderSchemeColor: SchemeColor.primary,
      unselectedToggleIsColored: true,
      sliderValueTinted: true,
      inputDecoratorSchemeColor: SchemeColor.primary,
      inputDecoratorIsFilled: true,
      inputDecoratorBackgroundAlpha: 19,
      inputDecoratorBorderType: FlexInputBorderType.outline,
      inputDecoratorUnfocusedHasBorder: false,
      inputDecoratorFocusedBorderWidth: 1.0,
      inputDecoratorPrefixIconSchemeColor: SchemeColor.primary,
      fabUseShape: true,
      fabAlwaysCircular: true,
      fabSchemeColor: SchemeColor.tertiary,
      cardRadius: 14.0,
      popupMenuRadius: 6.0,
      popupMenuElevation: 3.0,
      alignedDropdown: true,
      dialogRadius: 18.0,
      appBarBackgroundSchemeColor: SchemeColor.primaryFixedDim,
      appBarScrolledUnderElevation: 1.0,
      drawerRadius: 19.0,
      drawerElevation: 7.0,
      drawerBackgroundSchemeColor: SchemeColor.secondaryFixedDim,
      drawerWidth: 268.0,
      drawerIndicatorWidth: 301.0,
      drawerIndicatorSchemeColor: SchemeColor.black,
      drawerIndicatorOpacity: 0.5,
      drawerSelectedItemSchemeColor: SchemeColor.onSecondary,
      bottomSheetRadius: 18.0,
      bottomSheetElevation: 2.0,
      bottomSheetModalElevation: 4.0,
      bottomNavigationBarMutedUnselectedLabel: false,
      bottomNavigationBarMutedUnselectedIcon: false,
      menuRadius: 6.0,
      menuElevation: 3.0,
      menuBarRadius: 0.0,
      menuBarElevation: 1.0,
      menuBarShadowColor: Color(0x00000000),
      searchBarElevation: 4.0,
      searchViewElevation: 4.0,
      searchUseGlobalShape: true,
      navigationBarSelectedLabelSchemeColor: SchemeColor.primary,
      navigationBarSelectedIconSchemeColor: SchemeColor.onPrimary,
      navigationBarIndicatorSchemeColor: SchemeColor.primary,
      navigationBarElevation: 1.0,
      navigationRailSelectedLabelSchemeColor: SchemeColor.primary,
      navigationRailSelectedIconSchemeColor: SchemeColor.onPrimary,
      navigationRailUseIndicator: true,
      navigationRailIndicatorSchemeColor: SchemeColor.primary,
      navigationRailIndicatorOpacity: 1.00,
      navigationRailBackgroundSchemeColor: SchemeColor.surface,
    ),
    // Propiedades directas de ThemeData.
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    cupertinoOverrideTheme: const CupertinoThemeData(applyThemeToAll: true),
  );

  /// Tema oscuro definido con FlexColorScheme.
  /// Contiene todas las configuraciones de colores y estilos para el modo oscuro de la aplicación.
  static ThemeData dark = FlexThemeData.dark(
    // Colores personalizados definidos por el usuario con la API FlexSchemeColor().
    colors: const FlexSchemeColor(
      primary: Color(0xFF88B2F8),
      primaryContainer: Color(0xFF5DB3D5),
      primaryLightRef: Color(0xFFA5D3F6), // El color del primario en modo claro
      secondary: Color(0xFFFFD682),
      secondaryContainer: Color(0xFFFFDFA0),
      secondaryLightRef: Color(0xFF90D792), // El color del secundario en modo claro
      tertiary: Color(0xFF519E67),
      tertiaryContainer: Color(0xFF7AB893),
      tertiaryLightRef: Color(0xFFFFCC80), // El color del terciario en modo claro
      appBarColor: Color(0xFFC8E6C9),
      error: Color(0xFF9D3F51),
      errorContainer: Color(0xFF93000A),
    ),
    // Modificadores de color de entrada.
    useMaterial3ErrorColors: true,
    // Ajustes de color de superficie.
    surfaceMode: FlexSurfaceMode.highBackgroundLowScaffold,
    blendLevel: 2,
    // Configuraciones de tema de componentes para el modo oscuro.
    subThemesData: const FlexSubThemesData(
      interactionEffects: true,
      tintedDisabledControls: true,
      blendOnLevel: 8,
      blendOnColors: true,
      useM2StyleDividerInM3: true,
      adaptiveElevationShadowsBack: FlexAdaptive.all(),
      adaptiveAppBarScrollUnderOff: FlexAdaptive.excludeWebAndroidFuchsia(),
      adaptiveRadius: FlexAdaptive.excludeWebAndroidFuchsia(),
      defaultRadiusAdaptive: 10.0,
      elevatedButtonSchemeColor: SchemeColor.onPrimaryContainer,
      elevatedButtonSecondarySchemeColor: SchemeColor.primaryContainer,
      outlinedButtonOutlineSchemeColor: SchemeColor.primary,
      toggleButtonsBorderSchemeColor: SchemeColor.primary,
      segmentedButtonSchemeColor: SchemeColor.primary,
      segmentedButtonBorderSchemeColor: SchemeColor.primary,
      unselectedToggleIsColored: true,
      sliderValueTinted: true,
      inputDecoratorSchemeColor: SchemeColor.primary,
      inputDecoratorIsFilled: true,
      inputDecoratorBackgroundAlpha: 22,
      inputDecoratorBorderType: FlexInputBorderType.outline,
      inputDecoratorUnfocusedHasBorder: false,
      inputDecoratorFocusedBorderWidth: 1.0,
      inputDecoratorPrefixIconSchemeColor: SchemeColor.primary,
      fabUseShape: true,
      fabAlwaysCircular: true,
      fabSchemeColor: SchemeColor.tertiary,
      cardRadius: 14.0,
      popupMenuRadius: 6.0,
      popupMenuElevation: 3.0,
      alignedDropdown: true,
      dialogRadius: 18.0,
      appBarBackgroundSchemeColor: SchemeColor.primary,
      appBarScrolledUnderElevation: 3.0,
      drawerRadius: 19.0,
      drawerElevation: 7.0,
      drawerBackgroundSchemeColor: SchemeColor.secondaryFixedDim,
      drawerWidth: 268.0,
      drawerIndicatorWidth: 301.0,
      drawerIndicatorSchemeColor: SchemeColor.black,
      drawerIndicatorOpacity: 0.5,
      drawerSelectedItemSchemeColor: SchemeColor.onSecondary,
      bottomSheetRadius: 18.0,
      bottomSheetElevation: 2.0,
      bottomSheetModalElevation: 4.0,
      bottomNavigationBarMutedUnselectedLabel: false,
      bottomNavigationBarMutedUnselectedIcon: false,
      menuRadius: 6.0,
      menuElevation: 3.0,
      menuBarRadius: 0.0,
      menuBarElevation: 1.0,
      menuBarShadowColor: Color(0x00000000),
      searchBarElevation: 4.0,
      searchViewElevation: 4.0,
      searchUseGlobalShape: true,
      navigationBarSelectedLabelSchemeColor: SchemeColor.primary,
      navigationBarSelectedIconSchemeColor: SchemeColor.onPrimary,
      navigationBarIndicatorSchemeColor: SchemeColor.primary,
      navigationBarElevation: 1.0,
      navigationRailSelectedLabelSchemeColor: SchemeColor.primary,
      navigationRailSelectedIconSchemeColor: SchemeColor.onPrimary,
      navigationRailUseIndicator: true,
      navigationRailIndicatorSchemeColor: SchemeColor.primary,
      navigationRailIndicatorOpacity: 1.00,
      navigationRailBackgroundSchemeColor: SchemeColor.surface,
    ),
    // Propiedades directas de ThemeData.
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    cupertinoOverrideTheme: const CupertinoThemeData(applyThemeToAll: true),
  );
}
