# Keyboard-First UX Plan — "Never Touch the Mouse"

**Status:** PROPOSAL — review before implementation. No code written yet.
**Date:** 2026-06-19
**Scope:** Flutter ERP app (`flutter_app/`). No backend changes, no migrations, no
risk to the 1057 backend tests. The field app (`katasticho-mr-salesman-app`) is
out of scope (it's touch-first by nature).

---

## 1. Honest assessment of where we are

The existing **Keyboard-Parity UX Program** (CLAUDE.md, "COMPLETE — 2026-06-11")
built the **frame**, not the **content**:

- `core/shortcuts/k_shortcuts.dart` — central shortcut catalogue ✅
- `core/widgets/k_command_palette.dart` — Ctrl+K palette, 118 commands, ↑/↓/Enter ✅
- `core/widgets/k_keyboard_list_wrapper.dart` — J/K nav, N/R/X/Enter on all 45 lists ✅
- `core/widgets/k_keyboard_form_wrapper.dart` — Ctrl+Enter submit on all 23 forms ✅
- `core/widgets/k_shortcut_help_overlay.dart` — `?` help ✅
- `routing/shell_screen.dart` — global Ctrl+K / Ctrl+N / `?` ✅

These handle **getting to** a form and **submitting** it. They do nothing for the
20 keystrokes in between — selecting an item, adding a line, picking an account,
completing a payment. Those still force a mouse.

**Proof:** `features/inventory/presentation/item_picker_sheet.dart` (the most-used
picker in the app) is a `showModalBottomSheet` opened by tap. Its search box is
**not autofocused** (line 69-78, no `autofocus`), and every result row is a
**tap-only `ListTile`** (`onTap: () => Navigator.pop(context, item)`, line 189).
There is zero arrow-key navigation. The same pattern backs customer, supplier,
account, and group selection.

So: the scaffolding is real and good. The actual data-entry interactions are not
keyboard-complete. This plan closes that gap.

---

## 2. Friction inventory (grounded, file:line)

Grouped by root-cause pattern so we fix patterns, not screens.

### Pattern A — Modal pickers force a tap, no in-modal keyboard nav  *(the #1 killer)*

The same `showModalBottomSheet` + tap-only `ListTile` pattern repeats for every
master lookup. It hits every voucher line in every form, plus POS.

| Picker | Function | Defined in | Called from (examples) |
|---|---|---|---|
| Item | `showItemPicker` | `features/inventory/presentation/item_picker_sheet.dart` | invoice `:745-787`, SO `:803-805`, bill `:1044-1046`, PO `:412-424` |
| Customer | `showContactPicker` | `features/contacts/presentation/contact_picker_sheet.dart` | invoice `:343-403`, SO add-customer `:361-383` |
| Supplier | `showSupplierPicker` | `features/procurement/...` | PO `:84-89` |
| Item group | inline modal | `features/inventory/presentation/item_create_screen.dart:906-925` | item create `:829-869` |

Inside `item_picker_sheet.dart` specifically:
- `:69-78` search field — no `autofocus`, so the user must click it first.
- `:133-190` `ListTile` rows — `onTap` only, no focus, no highlight, no ↑/↓/Enter.

### Pattern B — No fast line entry (Tally/Busy muscle memory)

Every voucher form: "Add line" is a button tap, the new line does NOT autofocus,
and you cannot press Enter on a line to spawn the next.

| Form | "Add line" | File |
|---|---|---|
| Invoice | `:535-539` `setState(() => _lineItems.add(_LineItem()))` | `features/invoices/presentation/invoice_create_screen.dart` |
| Sales Order | `:531` | `features/sales_orders/presentation/sales_order_create_screen.dart` |
| Bill | `:797` | `features/bills/presentation/bill_create_screen.dart` |
| Purchase Order | `:290` | `features/procurement/presentation/purchase_order_create_screen.dart` |
| Journal | `:97-99` + button `:255-260` | `features/journals/presentation/journal_create_screen.dart` |

### Pattern C — Dropdowns are tap-to-open, no type-ahead

| Field | File:line |
|---|---|
| Tax group | invoice `:1131-1139`, SO `:1050-1058`, bill `:1302-1310` |
| Unit (UoM) | SO `:1030-1036`, item secondary units `:696-710` |
| Account (journal line) | journal `:388-415` `DropdownButtonFormField<AccountDto>` — full CoA list, no search |
| GST treatment / payment terms / MR category | contact `:287-419` |

### Pattern D — POS counter still needs the mouse

| Friction | File:line |
|---|---|
| Search results not arrow-navigable (Enter adds top result only) | `pos_screen.dart:114-127`, results `:1800-1803` |
| Payment sheet "Complete Sale" is click-only | `widgets/pos_payment_sheet.dart:212-226` |
| Quick-amount buttons (₹100/500/1000/Exact) click-only | `widgets/pos_payment_sheet.dart:262-275` |
| Qty +/− buttons click-only; inline editor needs a tap to open | `widgets/pos_cart_item_tile.dart:424-451`, dialog `:343-411` |
| Batch picker (multi-batch items) tap-only | `pos_screen.dart:175-177` |
| Customer select — no shortcut to open | `pos_screen.dart:1537` |

POS already does well: F1–F7 payment hotkeys, Ctrl+F search, search auto-refocus
after add (`:111-112, 278`). Those stay.

### Pattern E — Date fields are calendar-picker-only

`KDatePicker` opens a calendar modal; can't type `19062026`, `+7`, or `t` for today.
Invoice `:414-428`, SO `:590-600`, bill `:738-748` (+ batch `:1347-1363`),
PO `:236-247`, item opening batch `:1388-1400` / `:1564-1589`.

### Pattern F — Collapsible sections need a tap to expand

`KCollapsibleSection` rows must be tapped to expand, so fields inside a collapsed
section are unreachable by Tab. Contact `:185-435`, item `:1032-1408`.

---

## 3. The core widget — `KTypeaheadField`

One reusable inline autocomplete that **replaces both Pattern A (modal pickers)
and Pattern C (dropdowns)**. This single widget is the highest-leverage piece —
it touches POS plus all seven forms.

**File:** `flutter_app/lib/core/widgets/k_typeahead_field.dart`

### 3.1 API

```dart
class KTypeaheadField<T> extends StatefulWidget {
  /// Async search. Called debounced; returns the candidate list for `query`.
  final Future<List<T>> Function(String query) onSearch;

  /// How each result renders in the dropdown (title + optional subtitle/trailing).
  final KTypeaheadItem Function(T value) itemBuilder;

  /// Display string for the chosen value (shown in the field once selected).
  final String Function(T value) displayString;

  /// Fired when the user commits a choice (Enter / Tab / tap).
  final ValueChanged<T> onSelected;

  /// Optional: user pressed Enter on a query with no match (e.g. "create new").
  final ValueChanged<String>? onCreateNew;

  final String? label;
  final String? hint;
  final T? initialValue;
  final bool autofocus;          // default false
  final FocusNode? focusNode;    // so forms can chain Tab order
  final int debounceMs;          // default 200 (matches POS)
  final int minChars;            // default 1
}
```

`KTypeaheadItem` = `{ String title; String? subtitle; String? trailing; IconData? leading; }`.

### 3.2 Keyboard contract (the whole point)

| Key | Behaviour |
|---|---|
| *type* | debounced `onSearch`; overlay opens with results |
| `↓` / `↑` | move highlight (wraps; auto-scrolls to keep highlight visible) |
| `Enter` | commit highlighted result → `onSelected`; if none highlighted, commit first; if zero results and `onCreateNew != null`, fire `onCreateNew(query)` |
| `Tab` | commit highlighted result **and** let focus advance to next field (fast line entry) |
| `Esc` | close overlay; second `Esc` clears the field (does NOT bubble to form-cancel while overlay open) |
| *click* | still works — touch/mobile unaffected |

### 3.3 Behaviour notes

- **Overlay**, not a modal route — Tab flow continues to the next field, no focus trap.
- **Mobile-safe:** on small screens the overlay still renders and rows remain
  tappable, so touch users lose nothing. Pure additive.
- **Reuses existing providers:** `onSearch` wraps the same repositories the modal
  pickers already call (`itemListProvider`, contact search, account list, etc.) —
  no new API surface.
- **Replaces** `showItemPicker` / `showContactPicker` / `showSupplierPicker` call
  sites and the `DropdownButtonFormField` account/tax/unit fields with one widget.
  The old modal pickers can stay as a "browse all" affordance behind a small
  button for mouse users, but are no longer the only path.

---

## 4. Supporting pieces

### 4.1 Fast line entry — `KLineEntryController` mixin (Pattern B)

A small helper for the voucher forms:

- Enter on the **last field of a line** → append a new line + `requestFocus` its
  first field (via a `List<FocusNode>` the form already could own).
- `Ctrl+D` → duplicate current line.
- `Alt+Delete` → remove current line, focus the previous.
- Implemented as a mixin + a `KLineRow` wrapper so each form opts in with ~10 lines.

### 4.2 POS keyboard close-out (Pattern D)

- **Search results:** wrap the result list so `↓/↑` highlights and `Enter` adds the
  highlighted row; `1`–`9` add the Nth result directly. (`pos_screen.dart` key
  handler already exists at `:1465-1517` — extend it.)
- **Payment sheet** (`pos_payment_sheet.dart`): amount field `onSubmitted` →
  triggers the same callback as the "Complete Sale" button (`:212-226`); map
  `Ctrl+Enter` to complete; quick-amount keys (e.g. `E`=Exact) Tab-reachable.
- **Qty:** make the qty number in `pos_cart_item_tile.dart` focusable so `Ctrl+↑/↓`
  adjusts inline without opening the dialog.

### 4.3 Date typing — `KDateField` enhancement (Pattern E)

Let `KDatePicker`'s text portion accept typed input: `ddmmyyyy`, `dd/mm/yyyy`,
`t`=today, `+7`/`-3`=relative days. Calendar button stays for mouse users.

### 4.4 Expand-on-focus (Pattern F)

`KCollapsibleSection`: auto-expand when any descendant gains focus (so Tab into a
collapsed section just works), and allow Enter/Space to toggle when the header is
focused.

---

## 5. Per-screen rollout checklist

| Screen | A: typeahead | B: fast lines | C: dropdowns→typeahead | D: POS | E: dates | F: sections |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| POS (`pos_screen` + widgets) | ✅ item search | — | — | ✅ | — | — |
| Invoice create | ✅ item, customer | ✅ | ✅ tax | — | ✅ | — |
| Sales Order create | ✅ item, customer | ✅ | ✅ tax, unit | — | ✅ | — |
| Bill create | ✅ item, vendor | ✅ | ✅ tax | — | ✅ (+batch) | — |
| Purchase Order create | ✅ item, supplier | ✅ | — | — | ✅ | — |
| Journal create | ✅ account | ✅ | ✅ account | — | ✅ | — |
| Estimate / Credit Note / Vendor Credit / DC / Stock Receipt | ✅ item, party | ✅ | ✅ | — | ✅ | — |
| Contact create | ✅ (GST/terms) | — | ✅ | — | — | ✅ |
| Item create | ✅ group, mfr, HSN | — | ✅ unit | — | ✅ batch | ✅ |

(Estimate/CN/VC/DC/Stock-Receipt share the same line-grid pattern as Invoice, so
they come almost free once the shared widgets land.)

---

## 6. Build order & estimates

| # | Build | What it unblocks | Est. |
|---|---|---|---|
| 1 | `KTypeaheadField` + roll into POS search + Invoice/SO/Bill/PO/Journal pickers & dropdowns | Patterns A + C everywhere — the dominant friction | 2–3 d |
| 2 | `KLineEntryController` fast line entry across the 5 voucher forms | Pattern B — Tally muscle memory | 1–2 d |
| 3 | POS keyboard close-out (results nav + payment Enter + inline qty) | Pattern D — 100% mouse-free counter | 1–2 d |
| 4 | `KDateField` typing + expand-on-focus sections | Patterns E + F — polish, folded into screens already touched | 1 d |

Each build is independently shippable and independently testable. Recommended to
land #1 first (biggest blast radius), then #2 and #3 in either order.

---

## 7. Risks, non-goals, guardrails

- **Touch must not regress.** Every keyboard affordance is additive; all existing
  taps keep working. The typeahead overlay and POS result list stay tappable.
- **No backend changes.** `onSearch` reuses existing providers/repositories.
- **No new routes or migrations.** Pure widget work.
- **Don't rip out the modal pickers.** Keep them behind a "browse" button as the
  mouse/discovery path; the typeahead becomes the fast default.
- **Verify locally.** Cloud env has no guaranteed Flutter SDK on PATH — every
  build must `flutter analyze` + `flutter test` locally before it's called done
  (this is already verification-debt item A.2 in CLAUDE.md).
- **Out of scope:** the field MR app (touch-first), report screens (read-mostly),
  and the sidebar (command palette already covers navigation).

---

## 8. Definition of done (per build)

1. Widget(s) added under `core/widgets/` with a focused widget test.
2. Target screens migrated per the §5 checklist.
3. `flutter analyze` clean + `flutter test` green (run locally).
4. A short clip / screenshots of a full no-mouse flow (search → add → pay, or
   open form → fill grid → Ctrl+Enter) for sign-off.
5. CLAUDE.md "Keyboard-Parity UX Program" section updated to reflect that the
   *interaction layer* (not just the frame) is now keyboard-complete.
