import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'k_colors.dart';

/// Builds the Material 3 light & dark themes for Katasticho ERP using
/// [FlexColorScheme] — a battle-tested theming library that gives us
/// professional, fluidic, accessible Material 3 themes with minimal code.
///
/// Both themes are seeded from [KColors.brandSeed] (Indigo 600). Surfaces
/// use FlexColorScheme's tinted blend modes so the UI feels alive without
/// being noisy.
///
/// Font: **Plus Jakarta Sans** — modern, fluidic, geometric, professional.
class KTheme {
  KTheme._();

  static String? get _fontFamily => GoogleFonts.plusJakartaSans().fontFamily;

  static TextTheme _textTheme(Brightness brightness) {
    final base = brightness == Brightness.light
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;
    return GoogleFonts.plusJakartaSansTextTheme(base);
  }

  // Shared sub-theme tweaks for both light & dark — fluidic, generous radii.
  static const FlexSubThemesData _subThemes = FlexSubThemesData(
    interactionEffects: true,
    tintedDisabledControls: true,
    blendOnLevel: 8,
    blendOnColors: false,
    useM2StyleDividerInM3: false,

    // Inputs
    inputDecoratorBorderType: FlexInputBorderType.outline,
    inputDecoratorRadius: 12.0,
    inputDecoratorIsFilled: true,
    inputDecoratorBorderWidth: 1.2,
    inputDecoratorFocusedBorderWidth: 1.8,
    inputDecoratorFocusedHasBorder: true,
    inputDecoratorUnfocusedHasBorder: true,

    // Buttons
    elevatedButtonRadius: 12.0,
    elevatedButtonElevation: 0,
    filledButtonRadius: 12.0,
    outlinedButtonRadius: 12.0,
    outlinedButtonBorderWidth: 1.2,
    outlinedButtonPressedBorderWidth: 1.5,
    textButtonRadius: 10.0,
    toggleButtonsRadius: 12.0,

    // Cards & containers
    cardRadius: 16.0,
    cardElevation: 0,
    chipRadius: 20.0,
    popupMenuRadius: 12.0,
    popupMenuElevation: 4.0,
    tooltipRadius: 8,

    // Dialogs / sheets
    dialogRadius: 20.0,
    dialogElevation: 8.0,
    bottomSheetRadius: 24.0,
    bottomSheetElevation: 8.0,
    bottomSheetModalElevation: 12.0,
    timePickerDialogRadius: 20.0,
    datePickerDialogRadius: 20.0,
    snackBarRadius: 12,
    snackBarElevation: 4,

    // Navigation
    navigationBarSelectedLabelSchemeColor: SchemeColor.primary,
    navigationBarSelectedIconSchemeColor: SchemeColor.primary,
    navigationBarIndicatorSchemeColor: SchemeColor.primaryContainer,
    navigationBarIndicatorOpacity: 1.0,
    navigationBarBackgroundSchemeColor: SchemeColor.surface,
    navigationBarElevation: 0.0,
    navigationBarHeight: 72,
    navigationBarLabelBehavior:
        NavigationDestinationLabelBehavior.alwaysShow,

    navigationRailSelectedLabelSchemeColor: SchemeColor.primary,
    navigationRailSelectedIconSchemeColor: SchemeColor.primary,
    navigationRailIndicatorSchemeColor: SchemeColor.primaryContainer,
    navigationRailIndicatorOpacity: 1.0,
    navigationRailBackgroundSchemeColor: SchemeColor.surface,
    navigationRailLabelType: NavigationRailLabelType.all,

    // AppBar
    appBarBackgroundSchemeColor: SchemeColor.surface,
    appBarScrolledUnderElevation: 0.5,
    appBarCenterTitle: false,

    // Drawer
    drawerRadius: 16.0,
    drawerWidth: 280,
    drawerIndicatorRadius: 12.0,
  );

  /// LIGHT theme — soft slate background, indigo primary, white surfaces.
  static ThemeData get light {
    final theme = FlexThemeData.light(
      colors: FlexSchemeColor.from(
        primary: KColors.brandSeed,
        secondary: KColors.secondary,
        tertiary: KColors.accent,
        error: KColors.error,
        brightness: Brightness.light,
      ),
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 6,
      appBarStyle: FlexAppBarStyle.surface,
      appBarOpacity: 1.0,
      appBarElevation: 0.0,
      transparentStatusBar: true,
      tabBarStyle: FlexTabBarStyle.forBackground,
      tooltipsMatchBackground: true,
      subThemesData: _subThemes,
      keyColors: const FlexKeyColors(
        useKeyColors: true,
        useSecondary: true,
        useTertiary: true,
        keepPrimary: true,
        keepSecondary: true,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      fontFamily: _fontFamily,
      useMaterial3: true,
      swapLegacyOnMaterial3: true,
      scaffoldBackground: const Color(0xFFF8FAFC),
    );

    return theme.copyWith(
      textTheme: _textTheme(Brightness.light),
      primaryTextTheme: _textTheme(Brightness.light),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        },
      ),
      appBarTheme: theme.appBarTheme.copyWith(
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        toolbarHeight: 64,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF0F172A),
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  /// DARK theme — soft slate-900 background (not pure black), same brand seed.
  static ThemeData get dark {
    final theme = FlexThemeData.dark(
      colors: FlexSchemeColor.from(
        primary: const Color(0xFF818CF8), // indigo-400 reads better on dark
        secondary: const Color(0xFF2DD4BF),
        tertiary: const Color(0xFFFBBF24),
        error: const Color(0xFFF87171),
        brightness: Brightness.dark,
      ),
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 12,
      appBarStyle: FlexAppBarStyle.surface,
      appBarOpacity: 1.0,
      appBarElevation: 0.0,
      transparentStatusBar: true,
      tabBarStyle: FlexTabBarStyle.forBackground,
      tooltipsMatchBackground: true,
      subThemesData: _subThemes,
      keyColors: const FlexKeyColors(
        useKeyColors: true,
        useSecondary: true,
        useTertiary: true,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      fontFamily: _fontFamily,
      useMaterial3: true,
      swapLegacyOnMaterial3: true,
      scaffoldBackground: const Color(0xFF0B1120),
    );

    return theme.copyWith(
      textTheme: _textTheme(Brightness.dark),
      primaryTextTheme: _textTheme(Brightness.dark),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        },
      ),
      appBarTheme: theme.appBarTheme.copyWith(
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        toolbarHeight: 64,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
