# Katasticho Theme Guide

## Quick Theme Change

All brand colors are controlled by **3 seed constants** in:

```
lib/core/theme/k_colors.dart
```

```dart
static const Color brandSeed     = Color(0xFF4F46E5); // primary (buttons, links, active nav)
static const Color secondarySeed = Color(0xFF0EA5E9); // secondary (POS, secondary actions)
static const Color accentSeed    = Color(0xFFF59E0B); // tertiary (reports, AI, accents)
```

Change any hex value, hot-restart the app, done. ~170 colors across the app update automatically.

---

## Sidebar Theme (Independent)

The sidebar runs on its own palette, separate from the app brand:

```dart
static const Color sidebarSeed       = Color(0xFF0F172A); // slate-900
static const Brightness sidebarBrightness = Brightness.dark;
```

- Change `sidebarSeed` to change sidebar color (1 line).
- Set `sidebarBrightness = Brightness.light` for a light sidebar.
- Set `sidebarSeed = brandSeed` to make sidebar match the app brand.

---

## Popular Color Options

### Blues (recommended for ERP/finance)

Visual comparison: [`docs/blue_palette_comparison.png`](docs/blue_palette_comparison.png)

| Name           | Hex       | Use case                    |
|----------------|-----------|-----------------------------|
| Sky 300        | `#93C5FD` | Very light, soft            |
| Blue 400       | `#60A5FA` | Light, friendly             |
| Cornflower     | `#6495ED` | Soft, airy (low contrast)   |
| Cornflower+    | `#4A7FE0` | Accessible version of above |
| Blue 500       | `#3B82F6` | Balanced mid-blue           |
| Slate Blue     | `#4361EE` | Modern SaaS                 |
| Royal Blue     | `#3B5BDB` | Fintech classic             |
| Indigo 600     | `#4F46E5` | **Current default**         |
| Blue 600       | `#2563EB` | Classic enterprise          |
| Cobalt         | `#1D4ED8` | Bold, trustworthy           |
| Blue 800       | `#1E40AF` | Deep corporate              |
| Navy           | `#1E3A8A` | Premium/luxury              |

> **Tip:** Lighter shades (top row) struggle with WCAG contrast on white-text
> buttons. For primary action buttons, prefer mid/deep shades (rows 2-3).

### Greens

| Name         | Hex       | Use case                    |
|--------------|-----------|-----------------------------|
| Teal 600     | `#0D9488` | Fresh, modern               |
| Emerald 600  | `#059669` | Growth, money               |
| Green 600    | `#16A34A` | Nature, organic             |

### Warm

| Name         | Hex       | Use case                    |
|--------------|-----------|-----------------------------|
| Violet 500   | `#8B5CF6` | Creative, bold              |
| Pink 500     | `#EC4899` | Playful, retail             |
| Rose 600     | `#E11D48` | Energetic, CTA-heavy        |
| Amber 500    | `#F59E0B` | Warm, friendly              |
| Orange 500   | `#F97316` | Energetic, attention        |

### Sidebar options

| Name         | Hex       | Result                      |
|--------------|-----------|-----------------------------|
| Slate 900    | `#0F172A` | Dark navy (default)         |
| Gray 900     | `#111827` | Near-black, minimal         |
| Zinc 900     | `#18181B` | True dark, Vercel-style     |
| Slate 800    | `#1E293B` | Softer dark                 |
| Blue 950     | `#172554` | Dark navy-blue              |

---

## What Changes Automatically

When you edit `brandSeed`:

- All primary buttons, links, focus rings
- Active sidebar nav items + indicator bar
- KPI card icon tints
- Invoice/contact detail accents
- Input field focus borders
- Loading spinners
- Toggle/checkbox/radio selected states
- Gradient starts (K logo, Ask AI)
- Status chip for "Sent" invoices

When you edit `sidebarSeed`:

- Sidebar background color
- Nav item text/icon colors
- Section label colors ("WORKSPACE", "SALES")
- User avatar background
- Divider colors inside sidebar
- Tablet navigation rail

## What Does NOT Change (by design)

These are **semantic colors** — fixed regardless of brand:

- Green: success, paid invoices, ageing "Current"
- Red: error, overdue, ageing "90+"
- Amber: warning, partially paid
- Blue: info, ageing "1-30 days"

---

## File Map

| File | Role |
|------|------|
| `lib/core/theme/k_colors.dart` | Seeds, semantic colors, ageing palette |
| `lib/core/theme/k_theme.dart` | FlexColorScheme light/dark ThemeData |
| `lib/core/theme/k_typography.dart` | Inter font scale |
| `lib/core/theme/k_spacing.dart` | Spacing, radii, breakpoints |
| `lib/routing/shell_screen.dart` | `_SidebarTheme` wrapper |
