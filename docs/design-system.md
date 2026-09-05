# Katixo Design System

> **Rule for the agent: use only the tokens defined here. Never invent colors,
> spacing, or radii. Build screens by composing the primitives in §7 — never
> style raw elements per-screen.**

## 1. North star & principles

Katixo is an accounting / POS / ERP for Indian MSMEs and distributors. Money,
GST, ledgers. The aesthetic target is calm, dense, trustworthy — closest
references are Campfire, Zoho Books, Linear, and the Stripe Dashboard. Not a
consumer app, not a marketing page. Inside the product, restraint is the design.

Five rules that produce the "clean" look:

1. **Borders before shadows.** Separate things with 1px hairline borders and
   background tints, not drop shadows. Elevation is reserved for things that
   truly float (menus, popovers, modals).
2. **One accent, disciplined semantics.** A single brand colour for primary
   actions; muted green/red/amber only to mean something (money in/out, status).
   No decorative colour. No gradients.
3. **Density is a feature.** Distributors scan hundreds of line items. Tight,
   consistent rows beat airy padding. Show data without endless scrolling.
4. **Numbers are sacred.** Every amount is right-aligned, uses tabular (lining)
   numerals, and a consistent currency format. Misaligned ₹ columns are the #1
   thing that makes finance UI look amateur.
5. **Spend boldness in one place.** For an ERP that place is usually one
   beautifully executed data table or one well-designed entry form — not a
   flashy hero.

## 2. Colour tokens

Warm-neutral foundation (avoids both clinical cold-gray and the AI
"cream + serif" cliché) with a confident teal brand accent that reads
"money / ledger / trust" and stays clear of the overused SaaS-purple and
generic blue.

```css
:root {
  /* Surfaces & neutrals (warm-tinted) */
  --bg-app:        #F7F7F5;  /* app background behind cards */
  --bg-surface:    #FFFFFF;  /* cards, tables, panels */
  --bg-subtle:     #F3F3F1;  /* hover rows, inset areas, disabled */
  --bg-hover:      #EFEFEC;

  --border:        #E5E5E1;  /* hairline 1px — default separators */
  --border-strong: #D4D4CF;  /* inputs, emphasized dividers */

  --text-primary:   #1A1A18; /* near-black, warm */
  --text-secondary: #5F5F59; /* labels, secondary info */
  --text-muted:     #94948D; /* meta, placeholders, captions */
  --text-on-brand:  #FFFFFF;

  /* Brand — deep teal */
  --brand-50:  #E6F4F1;
  --brand-100: #C2E5DE;
  --brand-500: #14A08C;
  --brand-600: #0F8576;  /* PRIMARY — buttons, active nav, links */
  --brand-700: #0B6B5E;  /* hover / pressed */
  --brand-900: #0A4B43;  /* text on brand-50 tints */

  /* Semantic — money & status (muted, not alarm-bright) */
  --pos-text: #15803D;  --pos-bg: #E9F6EC;  --pos-border: #BFE6C8; /* money in / credit / paid / success */
  --neg-text: #BE3A34;  --neg-bg: #FCEBEA;  --neg-border: #F3C9C6; /* money out / overdue / error */
  --warn-text:#B45309;  --warn-bg:#FEF3E2;  --warn-border:#F6D9A8; /* pending / mismatch / due soon */
  --info-text:#1D4ED8;  --info-bg:#E8EEFD;  --info-border:#C5D4F8; /* informational only */
}
```

**Accounting nuance — read this:** debit and credit are not good/bad. Don't
paint every debit red. Reserve `--neg-*` for genuinely negative states
(overdue, error, money out of the user's pocket) and `--pos-*` for positive
ones (received, paid, reconciled). Most ledger rows use neutral text; colour is
the exception, not the rule. Overusing red/green is itself a slop tell.

## 3. Typography

Inside a data app, legibility and clean number rendering beat typographic
personality. Use a neutral grotesque for UI; save any display character for
the marketing site.

* **UI font:** `Inter` (safe default). Slightly more distinctive but equally
  legible alternatives: `Geist` or `IBM Plex Sans`. Pick one, load 400/500/600 only.
* **Mono** (for IDs/codes — GSTIN, invoice no, HSN): `IBM Plex Mono` or
  `JetBrains Mono`. Optional but makes codes scannable.
* **Critical:** apply `font-variant-numeric: tabular-nums lining-nums;` to all
  numeric and money text so columns align.

```css
:root {
  --font-ui:   'Inter', system-ui, -apple-system, sans-serif;
  --font-mono: 'IBM Plex Mono', ui-monospace, monospace;

  --text-xs:   12px;  /* meta, captions, table sub-text */
  --text-sm:   13px;  /* dense table cells, secondary UI */
  --text-base: 14px;  /* DEFAULT body & inputs */
  --text-md:   16px;  /* card/subsection titles */
  --text-lg:   20px;  /* section titles */
  --text-xl:   24px;  /* page title */

  --leading-tight: 1.3;
  --leading-base:  1.5;

  --fw-regular:  400;
  --fw-medium:   500;  /* labels, table headers, emphasis */
  --fw-semibold: 600;  /* titles, primary buttons */
}

.num { font-variant-numeric: tabular-nums lining-nums; text-align: right; }
```

Use 500 (medium) for labels and table headers, 600 for titles. Avoid 700+
except very sparingly. Use sentence case for everything ("Add invoice", not
"Add Invoice" or "ADD INVOICE").

## 4. Spacing, radius, elevation, motion

```css
:root {
  /* 4px base scale — use ONLY these */
  --space-1: 4px;  --space-2: 8px;  --space-3: 12px; --space-4: 16px;
  --space-5: 20px; --space-6: 24px; --space-8: 32px; --space-10: 40px;
  --space-12: 48px; --space-16: 64px;

  /* Radius — tight. NOT 16–24px. */
  --radius-sm: 4px;
  --radius:    6px;  /* DEFAULT — buttons, inputs, cards */
  --radius-md: 8px;  /* modals, larger panels */
  --radius-full: 9999px; /* badges, avatars only */

  /* Elevation — borders first; shadows only for floating UI */
  --shadow-xs: 0 1px 2px rgba(16,24,40,0.04);
  --shadow-sm: 0 1px 3px rgba(16,24,40,0.06), 0 1px 2px rgba(16,24,40,0.04);
  --shadow-md: 0 4px 12px rgba(16,24,40,0.08);   /* dropdowns, popovers */
  --shadow-lg: 0 12px 32px rgba(16,24,40,0.12);  /* modals */

  /* Density */
  --row-h:        36px;  /* table rows, list items */
  --row-h-compact:32px;
  --control-h:    34px;  /* inputs, buttons, selects */

  /* Motion — subtle */
  --ease: cubic-bezier(0.2, 0, 0, 1);
  --dur-fast: 120ms;
  --dur-base: 180ms;
}
@media (prefers-reduced-motion: reduce) { * { transition: none !important; animation: none !important; } }
```

Cards = `--bg-surface` + 1px `--border` + `--radius`, no shadow (or
`--shadow-xs` at most). That single choice is most of the Campfire/Linear look.

## 5. Tailwind mapping (if React/Next)

```js
// tailwind.config.js → theme.extend
colors: {
  app:'#F7F7F5', surface:'#FFFFFF', subtle:'#F3F3F1',
  border:{DEFAULT:'#E5E5E1', strong:'#D4D4CF'},
  ink:{DEFAULT:'#1A1A18', secondary:'#5F5F59', muted:'#94948D'},
  brand:{50:'#E6F4F1',100:'#C2E5DE',500:'#14A08C',600:'#0F8576',700:'#0B6B5E',900:'#0A4B43'},
  pos:{DEFAULT:'#15803D', bg:'#E9F6EC', border:'#BFE6C8'},
  neg:{DEFAULT:'#BE3A34', bg:'#FCEBEA', border:'#F3C9C6'},
  warn:{DEFAULT:'#B45309', bg:'#FEF3E2', border:'#F6D9A8'},
  info:{DEFAULT:'#1D4ED8', bg:'#E8EEFD', border:'#C5D4F8'},
},
borderRadius:{ DEFAULT:'6px', sm:'4px', md:'8px' },
fontFamily:{ sans:['Inter','system-ui','sans-serif'], mono:['IBM Plex Mono','monospace'] },
```

Pair with shadcn/ui — it gives you accessible, already-clean primitives
(Button, Table, Dialog, Select, Badge) that map onto these tokens. It is the
fastest way to a Campfire-grade baseline in React.

## 6. Flutter (if Flutter Web — your likely stack)

shadcn is React-only, so in Flutter the equivalent is: build a themed widget
set once in `lib/ui/` and a `ThemeData` from these tokens, then compose every
screen from those widgets. Same principle, same payoff.

```dart
// lib/ui/tokens.dart
import 'package:flutter/material.dart';

class K {
  static const bgApp     = Color(0xFFF7F7F5);
  static const surface   = Color(0xFFFFFFFF);
  static const subtle    = Color(0xFFF3F3F1);
  static const border    = Color(0xFFE5E5E1);
  static const ink       = Color(0xFF1A1A18);
  static const inkSecond = Color(0xFF5F5F59);
  static const inkMuted  = Color(0xFF94948D);
  static const brand     = Color(0xFF0F8576);
  static const brandHover= Color(0xFF0B6B5E);
  static const posText   = Color(0xFF15803D); static const posBg = Color(0xFFE9F6EC);
  static const negText   = Color(0xFFBE3A34); static const negBg = Color(0xFFFCEBEA);
  static const warnText  = Color(0xFFB45309); static const warnBg= Color(0xFFFEF3E2);
  static const radius    = 6.0;
  static const space2 = 8.0, space3 = 12.0, space4 = 16.0, space6 = 24.0;
}
```

Set `fontFamily: 'Inter'`, and for money use
`Text(amount, style: TextStyle(fontFeatures: [FontFeature.tabularFigures()]))`,
right-aligned. Build `KButton`, `KTextField`, `KBadge`, `KDataTable`, `KCard`,
`KPageHeader`, `KEmptyState` and never raw-style a screen.

## 7. Component rules (the primitives to build first)

Build these 8, then compose all screens from them.

**Button** — height `--control-h`, radius `--radius`, weight 600, no gradient,
no shadow.

* Primary: `--brand-600` fill, white text; hover `--brand-700`.
* Secondary: `--bg-surface` fill, 1px `--border-strong`, `--text-primary`; hover `--bg-subtle`.
* Ghost: transparent, `--text-secondary`; hover `--bg-subtle`.
* Destructive: `--neg-text` fill (use rarely — only delete/void).

**Input / Select** — height `--control-h`, 1px `--border-strong`, radius
`--radius`, `--text-base`. Focus: `--brand-600` border (≈1.5px); an outer
`--brand-50` ring is optional polish (Flutter can't paint it on a bare
`TextField` without a wrapping `Focus` + faint shadow — don't block on it).
Label above in `--text-sm` `--fw-medium` `--text-secondary`. Error:
`--neg-border` border + `--neg-text` helper line. Money/qty inputs right-align
with tabular numerals.

**Data table** (the heart of the ERP):

* Header row: `--bg-subtle`, `--text-xs`, sentence case, `--fw-medium`,
  `--text-secondary`, sticky on scroll.
* Rows: height `--row-h`, 1px `--border` bottom only (no vertical gridlines —
  they add noise), hover `--bg-subtle`.
* Amount columns: right-aligned, tabular, consistent ₹ format. Negative
  amounts in `--neg-text`; never use parentheses and colour together — pick one.
* IDs/codes (GSTIN, invoice no) in `--font-mono`.
* Zebra striping: avoid; hover + hairlines are enough and look cleaner.

**Badge / status pill** — radius `--radius-full`, `--text-xs`, `--fw-medium`,
semantic bg+text+border pair from §2. e.g. Paid → `--pos-*`; Overdue →
`--neg-*`; GST pending/Mismatch → `--warn-*`; Draft → neutral
`--bg-subtle`/`--text-muted`.

**Card / section** — `--bg-surface`, 1px `--border`, `--radius`, no shadow.
Padding `--space-5` (20) for content cards, `--space-4` (16) for small/KPI
tiles — `--space-6` (24) is a touch roomy for a dense ERP (Linear/Campfire sit
~16–20). Title `--text-md` `--fw-semibold`; optional `--text-sm` `--text-muted`
description.

**Page header** — left-aligned (never centered) `--text-xl` title, optional
breadcrumb in `--text-sm` `--text-muted`, primary action button on the right.
Consistent across every screen.

**Empty state** — short headline + one sentence of direction in the
interface's voice + one primary action. Not a mood, an invitation: "No
invoices yet. Create your first invoice to start tracking receivables." →
[Create invoice].

**Toast** — `--bg-surface`, `--shadow-md`, semantic left-border accent.
Past-tense confirmation matching the action ("Invoice published").

### 7.1 React control and layout contract

The React design system is the source of truth for every common control. Its
implementation is in `react_app/src/design-system/components.css`; application
shell CSS must not define button, tab, filter, search, modal, or toolbar rules.

* **Toolbar:** use `DirectoryToolbar`. It has a 12px internal gap,
  `--space-3`/`--space-4` padding, wraps safely on narrow screens, and stacks
  only below 768px. Do not hand-style a toolbar with inline `display`, `gap`,
  `justifyContent`, or breakpoint rules.
* **Search:** use `SearchInput`, never raw `.search-field` markup. Search
  controls have `--control-h`, a maximum width of `--directory-search-max`,
  and shrink before they force other controls off-screen.
* **Tabs and filters:** use `FilterTabs`. All tab, filter-chip, and legacy
  adapters use `--control-h`, `--space-3` horizontal padding, `--space-1`
  between controls, a teal active state, and wrapping at the container edge.
* **Buttons and links:** use `Button` or a `Link` with the `button` plus
  variant classes. Buttons, secondary action links, and row action links share
  the same control height and `--space-2` icon/text gap. Never add ad-hoc icon
  margins or custom button padding in a feature.
* **Dialogs:** use `Modal`, `FormGrid`, `FormField`, `TextInput`, and
  `SelectInput`. The legacy `modal-card` classes are a central compatibility
  adapter only; no new screen may use them.
* **Cards and lists:** use `DocumentCard`, `DataTable`, `StatusChip`, and
  `EmptyState`. A feature may add a semantic layout class in the design-system
  stylesheet, but it must use existing tokens and cannot apply inline layout
  styles to raw elements.

Before a new screen is accepted, verify it has no raw `style={{...}}` layout
for common controls and that it composes the primitives above. Existing legacy
pages are migrated module by module; the central adapters ensure their controls
remain aligned during that transition.

## 8. Money & number formatting (enforce everywhere)

* Currency: `₹1,23,456.78` — Indian digit grouping (lakh/crore: 2-2-3), symbol
  then number, two decimals for amounts.
* Compact for dashboards: `₹1.23 L`, `₹4.5 Cr` (use `en-IN` Intl formatting /
  `NumberFormat.currency(locale:'en_IN')`).
* Always right-aligned in tables; always tabular numerals.
* Quantities: tabular, with unit (`240 strips`, `15 boxes`).
* Dates: `DD MMM YYYY` (`14 Oct 2025`) — unambiguous for Indian users.
* GSTIN shown in mono; validate the 15-char format inline.

## 9. Never do this (the slop checklist)

Hand this list to Claude Code as hard constraints:

* Gradients on buttons or backgrounds (especially purple/violet). Flat fills only.
* Drop shadows on cards/rows/inputs. Borders first; shadows only for floating UI.
* Radius >= 12px on cards/inputs/buttons. Stay at 6-8px.
* More than one brand accent. No rainbow of colours; semantics only.
* Emoji in UI chrome, headers, buttons, or labels.
* Centered hero layouts for app screens. Left-aligned, grid-based.
* Oversized padding on data screens. Respect the density tokens.
* Left-aligned or proportional-figure money. Always right-aligned + tabular.
* Lorem ipsum / fake "Product A" data. Use realistic ₹ amounts, GSTINs, party
  names so layouts are tested at true density.
* Mixed icon sets/weights. One library (Lucide or Phosphor), one weight.
* New colours/spacing invented per screen. Tokens only.
* Title Case or ALL CAPS for labels/buttons. Sentence case.

## 10. Using this with Claude Code

1. Commit this file as `docs/design-system.md`.
2. In `CLAUDE.md` add: "All UI must follow `docs/design-system.md`. Use only
   its tokens — never invent colours, spacing, or radii. Build screens by
   composing the primitives in §7; do not style raw elements per screen.
   Before writing a component, restate which tokens you are using."
3. **First task:** "Build the 8 primitives in §7 from these tokens" — review
   them once, by hand, until they're crisp. Everything downstream inherits
   their quality.
4. In each screen prompt, name the north star: "Match the restraint and
   density of Linear / Stripe Dashboard."
5. **Screenshot loop:** paste a screenshot of the current screen + a reference
   (Campfire/Zoho) and ask: "Critique this against `design-system.md` and the
   reference, then close the gap." Iterate 2-3 times.
6. Give it real screens with real content ("the receivables ageing table for a
   pharma distributor with 40 parties"), not "build a dashboard."
