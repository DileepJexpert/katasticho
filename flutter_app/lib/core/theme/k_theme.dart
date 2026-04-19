import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'k_colors.dart';

/// Builds the Material 3 light & dark themes for Katasticho ERP —
/// **Katasticho 2026** design language.
///
/// Both themes are seeded from [KColors.brandSeed] (Indigo-600). Surfaces
/// use FlexColorScheme's tinted blend modes so the UI feels alive without
/// being noisy. Compared to the previous iteration this theme:
///   • Switches the typeface to **Inter** (finance-SaaS standard)
///   • Tightens radii — 8/10/14 instead of 12/16/20
///   • Denser inputs & buttons (~40/38px instead of ~56/48px)
///   • Flatter surfaces — borders over shadows
class KTheme {
  KTheme._();

  static String? get _fontFamily => GoogleFonts.inter().fontFamily;

  static TextTheme _textTheme(Brightness brightness) {
    final base = brightness == Brightness.light
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;
    return GoogleFonts.interTextTheme(base);
  }

  // Shared sub-theme tweaks for both light & dark — tight radii, flat surfaces.
  static const FlexSubThemesData _subThemes = FlexSubThemesData(
    interactionEffects: true,
    tintedDisabledControls: true,
    blendOnLevel: 6,
    blendOnColors: false,
    useM2StyleDividerInM3: false,

    // Inputs — 40px height target, border-based, subtle
    inputDecoratorBorderType: FlexInputBorderType.outline,
    inputDecoratorRadius: 8.0,
    inputDecoratorIsFilled: false,
    inputDecoratorBorderWidth: 1.0,
    inputDecoratorFocusedBorderWidth: 1.5,
    inputDecoratorFocusedHasBorder: true,
    inputDecoratorUnfocusedHasBorder: true,

    // Buttons — 38px default height, 8px radius, flat
    elevatedButtonRadius: 8.0,
    elevatedButtonElevation: 0,
    filledButtonRadius: 8.0,
    outlinedButtonRadius: 8.0,
    outlinedButtonBorderWidth: 1.0,
    outlinedButtonPressedBorderWidth: 1.5,
    textButtonRadius: 8.0,
    toggleButtonsRadius: 8.0,

    // Cards & containers — border-based, no shadow
    cardRadius: 10.0,
    cardElevation: 0,
    chipRadius: 999.0, // fully pill
    popupMenuRadius: 10.0,
    popupMenuElevation: 4.0,
    tooltipRadius: 6,

    // Dialogs / sheets — refined, less chunky
    dialogRadius: 14.0,
    dialogElevation: 6.0,
    bottomSheetRadius: 16.0,
    bottomSheetElevation: 6.0,
    bottomSheetModalElevation: 10.0,
    timePickerDialogRadius: 14.0,
    datePickerDialogRadius: 14.0,
    snackBarRadius: 8,
    snackBarElevation: 3,

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
    drawerRadius: 12.0,
    drawerWidth: 260,
    drawerIndicatorRadius: 8.0,
  );

  /// LIGHT theme — soft slate background, sky-blue primary, white surfaces.
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
      visualDensity: VisualDensity.compact,
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
        toolbarHeight: 56,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF0F172A),
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  /// DARK theme — soft slate-900 background (not pure black), indigo primary.
  static ThemeData get dark {
    final theme = FlexThemeData.dark(
      colors: FlexSchemeColor.from(
        primary: KColors.primaryDark,
        secondary: KColors.secondaryDark,
        tertiary: KColors.accentDark,
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
      visualDensity: VisualDensity.compact,
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
        toolbarHeight: 56,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
