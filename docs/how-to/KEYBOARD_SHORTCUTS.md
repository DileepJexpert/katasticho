# Keyboard Shortcuts

This is the current shortcut contract for Katasticho. Keep shortcuts small,
stable, and safe. A shortcut may open a dialog or payment sheet, but it should
not silently post inventory, accounting, or sales without the normal confirmation
step.

## Global

| Shortcut | Action |
| --- | --- |
| `Ctrl/Cmd K` | Open command palette to jump to pages or create records |

## POS

POS shortcuts are designed for counter speed. They should work from the POS
screen without requiring mouse use.

| Shortcut | Action |
| --- | --- |
| `Ctrl/Cmd F` | Focus item search |
| `F1` | Open Cash payment sheet |
| `F2` | Open UPI payment sheet |
| `F3` | Open Card payment sheet |
| `F4` | Hold current cart |
| `F5` | Recall held cart |
| `F6` | Open Split payment sheet |
| `F7` | Scan barcode |
| `Ctrl/Cmd Enter` | Open payment sheet using current cart payment mode |
| `Ctrl/Cmd Delete` | Clear current cart |
| `Esc` | Clear active search |

## Design Rules

- Do not create shortcuts that directly post stock, receive GRNs, dispatch
  orders, approve workflows, or create accounting entries without confirmation.
- Prefer page-local shortcuts for high-volume workflows such as POS, purchase
  entry, sales order entry, and collections.
- Prefer `Ctrl/Cmd K` for navigation instead of many global navigation keys.
- Keep shortcut labels sourced from `KShortcuts` in the Flutter app so UI text
  and behavior do not drift.
- For future vertical-specific shortcuts, keep the base action stable and vary
  only page hints. Example: `F1` remains primary payment on POS whether the
  organisation is pharma, kirana, or FMCG.

## Future Candidates

These are not implemented yet and should be added only when the related screen
flow is mature:

| Shortcut | Candidate Screen | Action |
| --- | --- | --- |
| `Ctrl/Cmd S` | Draft forms | Save draft |
| `Ctrl/Cmd Enter` | Draft forms | Submit or confirm after validation |
| `F2` | Item/medicine lookup fields | Focus product search |
| `F4` | Sales order | Open dispatch/challan step |
| `F8` | Collections | Record payment |
