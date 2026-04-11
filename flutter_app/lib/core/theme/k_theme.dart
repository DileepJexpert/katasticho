import 'package:flutter/material.dart';
import 'k_colors.dart';
import 'k_typography.dart';
import 'k_spacing.dart';

/// Builds the Material ThemeData for Katasticho ERP.
class KTheme {
  KTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: KColors.primary,
        onPrimary: KColors.onPrimary,
        primaryContainer: KColors.primaryLight,
        secondary: KColors.secondary,
        onSecondary: KColors.onSecondary,
        secondaryContainer: KColors.secondaryLight,
        tertiary: KColors.accent,
        error: KColors.error,
        surface: KColors.surface,
        onSurface: KColors.textPrimary,
        surfaceContainerHighest: KColors.surfaceVariant,
        outline: KColors.divider,
      ),
      scaffoldBackgroundColor: KColors.background,
      dividerColor: KColors.divider,

      // ── AppBar ──
      appBarTheme: const AppBarTheme(
        backgroundColor: KColors.primary,
        foregroundColor: KColors.onPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: KColors.onPrimary,
        ),
      ),

      // ── Card ──
      cardTheme: CardTheme(
        color: KColors.surface,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: KSpacing.borderRadiusMd,
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Elevated Button ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: KColors.primary,
          foregroundColor: KColors.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: KSpacing.borderRadiusMd,
          ),
          textStyle: KTypography.button,
        ),
      ),

      // ── Outlined Button ──
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: KColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: KSpacing.borderRadiusMd,
          ),
          side: const BorderSide(color: KColors.primary),
          textStyle: KTypography.button,
        ),
      ),

      // ── Text Button ──
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: KColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: KTypography.button,
        ),
      ),

      // ── Input Decoration ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: KColors.surface,
        contentPadding: KSpacing.inputPadding,
        border: OutlineInputBorder(
          borderRadius: KSpacing.borderRadiusMd,
          borderSide: const BorderSide(color: KColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: KSpacing.borderRadiusMd,
          borderSide: const BorderSide(color: KColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: KSpacing.borderRadiusMd,
          borderSide: const BorderSide(color: KColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: KSpacing.borderRadiusMd,
          borderSide: const BorderSide(color: KColors.error),
        ),
        labelStyle: KTypography.bodyMedium.copyWith(color: KColors.textSecondary),
        hintStyle: KTypography.bodyMedium.copyWith(color: KColors.textHint),
      ),

      // ── Chip ──
      chipTheme: ChipThemeData(
        backgroundColor: KColors.surfaceVariant,
        labelStyle: KTypography.labelMedium,
        padding: KSpacing.chipPadding,
        shape: RoundedRectangleBorder(
          borderRadius: KSpacing.borderRadiusMd,
        ),
      ),

      // ── Floating Action Button ──
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: KColors.primary,
        foregroundColor: KColors.onPrimary,
        elevation: 4,
      ),

      // ── Bottom Navigation ──
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: KColors.surface,
        selectedItemColor: KColors.primary,
        unselectedItemColor: KColors.textHint,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // ── Dialog ──
      dialogTheme: DialogTheme(
        shape: RoundedRectangleBorder(
          borderRadius: KSpacing.borderRadiusLg,
        ),
        backgroundColor: KColors.surface,
      ),

      // ── Bottom Sheet ──
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: KColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(KSpacing.radiusXl),
          ),
        ),
      ),

      // ── Snackbar ──
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: KSpacing.borderRadiusMd,
        ),
      ),

      // ── Tab Bar ──
      tabBarTheme: const TabBarTheme(
        labelColor: KColors.primary,
        unselectedLabelColor: KColors.textSecondary,
        indicatorColor: KColors.primary,
        labelStyle: KTypography.labelLarge,
        unselectedLabelStyle: KTypography.bodyMedium,
      ),
    );
  }
}
