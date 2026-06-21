import 'package:flutter/material.dart';
import 'k_colors.dart';

/// Spacing, radius, shadow & elevation constants — based on a 4px grid.
class KSpacing {
  KSpacing._();

  // ── Base Units ──
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  // ── Padding Presets ──
  static const EdgeInsets pagePadding = EdgeInsets.all(12);
  static const EdgeInsets pagePaddingLg = EdgeInsets.all(lg);
  static const EdgeInsets cardPadding = EdgeInsets.all(12);
  static const EdgeInsets cardPaddingLg = EdgeInsets.all(lg);
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: 14,
  );
  static const EdgeInsets chipPadding = EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 4,
  );
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 8,
  );

  // ── Gaps (for Row/Column spacing) ──
  static const SizedBox gapXs = SizedBox(height: xs, width: xs);
  static const SizedBox gapSm = SizedBox(height: sm, width: sm);
  static const SizedBox gapMd = SizedBox(height: md, width: md);
  static const SizedBox gapLg = SizedBox(height: lg, width: lg);
  static const SizedBox gapXl = SizedBox(height: xl, width: xl);

  // ── Vertical Gaps ──
  static const SizedBox vGapXxs = SizedBox(height: xxs);
  static const SizedBox vGapXs = SizedBox(height: xs);
  static const SizedBox vGapSm = SizedBox(height: sm);
  static const SizedBox vGapMd = SizedBox(height: md);
  static const SizedBox vGapLg = SizedBox(height: lg);
  static const SizedBox vGapXl = SizedBox(height: xl);

  // ── Horizontal Gaps ──
  static const SizedBox hGapXs = SizedBox(width: xs);
  static const SizedBox hGapSm = SizedBox(width: sm);
  static const SizedBox hGapMd = SizedBox(width: md);
  static const SizedBox hGapLg = SizedBox(width: lg);
  static const SizedBox hGapXl = SizedBox(width: xl);

  // ── Border Radius — capped at 8 per design-system.md §4 ──
  // "Stay at 6-8px. NOT 16-24px." radiusXl/2xl are kept as token names so the
  // ~5 existing call sites keep compiling, but their VALUE is clamped to 8 so
  // nothing renders the old 14/18px "blobby" corners. radiusLg stays 10 (the
  // largest still-acceptable radius for big drawers/sheets).
  static const double radiusXs = 4;
  static const double radiusSm = 6;
  static const double radiusMd = 8;
  static const double radiusLg = 10;
  static const double radiusXl = 8;   // was 14 — capped
  static const double radius2xl = 8;  // was 18 — capped
  static const double radiusRound = 999;

  static final BorderRadius borderRadiusXs = BorderRadius.circular(radiusXs);
  static final BorderRadius borderRadiusSm = BorderRadius.circular(radiusSm);
  static final BorderRadius borderRadiusMd = BorderRadius.circular(radiusMd);
  static final BorderRadius borderRadiusLg = BorderRadius.circular(radiusLg);
  static final BorderRadius borderRadiusXl = BorderRadius.circular(radiusXl);
  static final BorderRadius borderRadius2xl = BorderRadius.circular(radius2xl);

  // ── Motion (per design-system.md §4 — subtle, finance-grade) ──
  static const Duration durFast = Duration(milliseconds: 120);
  static const Duration durBase = Duration(milliseconds: 180);
  static const Curve ease = Cubic(0.2, 0, 0, 1);

  // ── Density (per design-system.md §4) ──
  static const double rowH = 40;          // table rows, list items
  static const double rowHCompact = 36;
  static const double controlH = 36;      // inputs, buttons, selects

  // ── Responsive Breakpoints ──
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  // ── Sidebar ──
  static const double sidebarWidth = 208;
  static const double sidebarCollapsedWidth = 64;

  // ── Modern Shadow Tokens ─────────────────────────────────────────
  // Soft, layered shadows inspired by Tailwind's shadow scale.
  static const List<BoxShadow> shadowXs = [
    BoxShadow(
      color: Color(0x0F0F172A), // slate-900 @ ~6%
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> shadowSm = [
    BoxShadow(
      color: Color(0x140F172A), // ~8%
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x080F172A), // ~3%
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> shadowMd = [
    BoxShadow(
      color: Color(0x1A0F172A), // ~10%
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
    BoxShadow(
      color: Color(0x0A0F172A),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> shadowLg = [
    BoxShadow(
      color: Color(0x1F0F172A), // ~12%
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
    BoxShadow(
      color: Color(0x0F0F172A),
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  /// Tinted shadow that picks up the brand color — great for primary CTAs.
  static List<BoxShadow> shadowPrimary = [
    BoxShadow(
      color: KColors.primary.withValues(alpha: 0.25),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> shadowSuccess = [
    BoxShadow(
      color: KColors.secondary.withValues(alpha: 0.25),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];
}
