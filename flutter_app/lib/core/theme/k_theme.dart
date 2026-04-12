import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'k_colors.dart';
import 'k_typography.dart';
import 'k_spacing.dart';

/// Builds the Material ThemeData for Katasticho ERP.
///
/// Goals:
///   • Modern, sleek look — flat surfaces, soft tinted shadows
///   • Generous border radii (12 / 16 px)
///   • Crisp white AppBar with brand-colored title (no heavy navy bars)
///   • Buttons feel tactile (subtle shadow, no Material bevel)
///   • Inputs feel calm at rest, snap to brand color on focus
class KTheme {
  KTheme._();

  static ThemeData get light {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: KColors.textPrimary,
      displayColor: KColors.textPrimary,
    );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      colorScheme: const ColorScheme.light(
        primary: KColors.primary,
        onPrimary: KColors.onPrimary,
        primaryContainer: KColors.primarySoft,
        onPrimaryContainer: KColors.primaryPressed,
        secondary: KColors.secondary,
        onSecondary: KColors.onSecondary,
        secondaryContainer: KColors.secondarySoft,
        onSecondaryContainer: KColors.secondaryHover,
        tertiary: KColors.accent,
        tertiaryContainer: KColors.accentSoft,
        error: KColors.error,
        errorContainer: KColors.errorLight,
        surface: KColors.surface,
        onSurface: KColors.textPrimary,
        onSurfaceVariant: KColors.textSecondary,
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: KColors.surfaceVariant,
        surfaceContainer: KColors.backgroundAlt,
        surfaceContainerHigh: KColors.backgroundAlt,
        surfaceContainerHighest: KColors.backgroundAlt,
        outline: KColors.divider,
        outlineVariant: KColors.dividerSoft,
        shadow: Color(0xFF0F172A),
      ),
      scaffoldBackgroundColor: KColors.background,
      canvasColor: KColors.background,
      dividerColor: KColors.divider,
      dividerTheme: const DividerThemeData(
        color: KColors.divider,
        thickness: 1,
        space: 1,
      ),
      splashFactory: InkSparkle.splashFactory,
      highlightColor: KColors.primarySoft,
      hoverColor: KColors.primarySoft,

      // ── AppBar — clean white surface with brand title ──
      appBarTheme: AppBarTheme(
        backgroundColor: KColors.surface,
        foregroundColor: KColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: const Color(0x140F172A),
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        iconTheme: const IconThemeData(color: KColors.textPrimary, size: 22),
        actionsIconTheme: const IconThemeData(
          color: KColors.textSecondary,
          size: 22,
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: KColors.textPrimary,
          letterSpacing: -0.2,
        ),
        toolbarHeight: 64,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        shape: const Border(
          bottom: BorderSide(color: KColors.dividerSoft, width: 1),
        ),
      ),

      // ── Card — flat with hairline border + soft shadow on demand ──
      cardTheme: CardThemeData(
        color: KColors.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x1A0F172A),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: KSpacing.borderRadiusLg,
          side: const BorderSide(color: KColors.dividerSoft, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Elevated Button — primary CTA with tinted shadow ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return KColors.disabled;
            }
            if (states.contains(WidgetState.pressed)) {
              return KColors.primaryPressed;
            }
            if (states.contains(WidgetState.hovered)) {
              return KColors.primaryHover;
            }
            return KColors.primary;
          }),
          foregroundColor: WidgetStateProperty.all(KColors.onPrimary),
          overlayColor: WidgetStateProperty.all(Colors.white24),
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return 0;
            return 0;
          }),
          shadowColor: WidgetStateProperty.all(
            KColors.primary.withValues(alpha: 0.3),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          ),
          minimumSize: WidgetStateProperty.all(const Size(64, 48)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: KSpacing.borderRadiusMd),
          ),
          textStyle: WidgetStateProperty.all(KTypography.button),
          splashFactory: InkSparkle.splashFactory,
        ),
      ),

      // ── Filled Button — alternative primary ──
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: KColors.primary,
          foregroundColor: KColors.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: KSpacing.borderRadiusMd),
          textStyle: KTypography.button,
        ),
      ),

      // ── Outlined Button ──
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: KColors.textPrimary,
          backgroundColor: KColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: KSpacing.borderRadiusMd),
          side: const BorderSide(color: KColors.divider, width: 1.2),
          textStyle: KTypography.button,
        ).copyWith(
          overlayColor: WidgetStateProperty.all(KColors.primarySoft),
        ),
      ),

      // ── Text Button ──
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: KColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(borderRadius: KSpacing.borderRadiusSm),
          textStyle: KTypography.button,
        ),
      ),

      // ── Input Decoration — calm, refined, with brand focus ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: KColors.surface,
        isDense: false,
        contentPadding: KSpacing.inputPadding,
        prefixIconColor: KColors.textTertiary,
        suffixIconColor: KColors.textTertiary,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        border: OutlineInputBorder(
          borderRadius: KSpacing.borderRadiusMd,
          borderSide: const BorderSide(color: KColors.divider, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: KSpacing.borderRadiusMd,
          borderSide: const BorderSide(color: KColors.divider, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: KSpacing.borderRadiusMd,
          borderSide: const BorderSide(color: KColors.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: KSpacing.borderRadiusMd,
          borderSide: const BorderSide(color: KColors.error, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: KSpacing.borderRadiusMd,
          borderSide: const BorderSide(color: KColors.error, width: 1.8),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: KSpacing.borderRadiusMd,
          borderSide: const BorderSide(color: KColors.dividerSoft),
        ),
        labelStyle: KTypography.bodyMedium.copyWith(
          color: KColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: KTypography.labelLarge.copyWith(
          color: KColors.primary,
        ),
        hintStyle: KTypography.bodyMedium.copyWith(color: KColors.textHint),
        helperStyle: KTypography.bodySmall,
        errorStyle: KTypography.bodySmall.copyWith(color: KColors.error),
      ),

      // ── Chip ──
      chipTheme: ChipThemeData(
        backgroundColor: KColors.backgroundAlt,
        selectedColor: KColors.primarySoft,
        disabledColor: KColors.dividerSoft,
        labelStyle: KTypography.labelMedium,
        secondaryLabelStyle: KTypography.labelMedium.copyWith(
          color: KColors.primary,
        ),
        padding: KSpacing.chipPadding,
        side: const BorderSide(color: KColors.divider, width: 1),
        shape: RoundedRectangleBorder(borderRadius: KSpacing.borderRadiusXl),
        showCheckmark: false,
      ),

      // ── Floating Action Button ──
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: KColors.primary,
        foregroundColor: KColors.onPrimary,
        elevation: 4,
        focusElevation: 6,
        hoverElevation: 6,
        highlightElevation: 8,
        shape: RoundedRectangleBorder(borderRadius: KSpacing.borderRadiusLg),
        extendedTextStyle: KTypography.button.copyWith(color: Colors.white),
      ),

      // ── Bottom Navigation ──
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: KColors.surface,
        selectedItemColor: KColors.primary,
        unselectedItemColor: KColors.textHint,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: KColors.surface,
        elevation: 0,
        height: 68,
        indicatorColor: KColors.primarySoft,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return KTypography.labelMedium.copyWith(
              color: KColors.primary,
              fontWeight: FontWeight.w700,
            );
          }
          return KTypography.labelMedium.copyWith(color: KColors.textHint);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: KColors.primary, size: 24);
          }
          return const IconThemeData(color: KColors.textTertiary, size: 24);
        }),
      ),

      // ── Dialog ──
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: KSpacing.borderRadiusXl),
        backgroundColor: KColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: const Color(0x330F172A),
        titleTextStyle: KTypography.h3,
        contentTextStyle: KTypography.bodyMedium,
      ),

      // ── Bottom Sheet ──
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: KColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(KSpacing.radiusXl),
          ),
        ),
        showDragHandle: true,
        dragHandleColor: KColors.divider,
      ),

      // ── Snackbar ──
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: KColors.textPrimary,
        contentTextStyle: KTypography.bodyMedium.copyWith(color: Colors.white),
        actionTextColor: KColors.primaryLight,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: KSpacing.borderRadiusMd),
      ),

      // ── Tab Bar ──
      tabBarTheme: TabBarThemeData(
        labelColor: KColors.primary,
        unselectedLabelColor: KColors.textTertiary,
        indicatorColor: KColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: KTypography.labelLarge,
        unselectedLabelStyle: KTypography.labelLarge.copyWith(
          fontWeight: FontWeight.w500,
          color: KColors.textTertiary,
        ),
        dividerColor: KColors.dividerSoft,
        overlayColor: WidgetStateProperty.all(KColors.primarySoft),
      ),

      // ── List Tile ──
      listTileTheme: const ListTileThemeData(
        iconColor: KColors.textTertiary,
        textColor: KColors.textPrimary,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minVerticalPadding: 12,
        horizontalTitleGap: 12,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: KColors.textPrimary,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: KColors.textSecondary,
        ),
      ),

      // ── Progress Indicator ──
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: KColors.primary,
        linearTrackColor: KColors.dividerSoft,
        circularTrackColor: KColors.dividerSoft,
        linearMinHeight: 4,
      ),

      // ── Switch ──
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return KColors.primary;
          return KColors.divider;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // ── Checkbox ──
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return KColors.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: KColors.disabled, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: KSpacing.borderRadiusXs),
      ),

      // ── Radio ──
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return KColors.primary;
          return KColors.disabled;
        }),
      ),

      // ── Tooltip ──
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: KColors.textPrimary,
          borderRadius: KSpacing.borderRadiusSm,
        ),
        textStyle: KTypography.bodySmall.copyWith(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        waitDuration: const Duration(milliseconds: 400),
      ),

      // ── Popup Menu ──
      popupMenuTheme: PopupMenuThemeData(
        color: KColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: const Color(0x1F0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: KSpacing.borderRadiusMd,
          side: const BorderSide(color: KColors.dividerSoft),
        ),
        textStyle: KTypography.bodyMedium,
      ),

      // ── Icon ──
      iconTheme: const IconThemeData(
        color: KColors.textSecondary,
        size: 22,
      ),
    );
  }
}
