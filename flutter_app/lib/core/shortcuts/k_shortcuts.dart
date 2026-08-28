import 'package:flutter/services.dart';

/// Central shortcut catalogue for app-wide and high-volume workflow keys.
///
/// Keep this file as the single source for labels and key detection so screens
/// do not drift into different shortcut meanings.
class KShortcuts {
  const KShortcuts._();

  // ── Global ────────────────────────────────────────────────────
  static const commandPalette = 'Ctrl/Cmd K';
  static const shortcutHelp = '?';
  static const globalNew = 'Ctrl/Cmd N';
  static const globalSave = 'Ctrl/Cmd S';
  static const globalSearch = '/';
  static const globalEscape = 'Esc';

  // ── List screens ──────────────────────────────────────────────
  static const listNew = 'N';
  static const listSearch = '/';
  static const listRefresh = 'R';
  static const listUp = '↑ / K';
  static const listDown = '↓ / J';
  static const listOpen = 'Enter';
  static const listSelect = 'X';
  static const listSelectAll = 'Ctrl/Cmd A';

  // ── Form & Billing screens ────────────────────────────────────
  static const formSubmit = 'Ctrl/Cmd Enter';
  static const formNextStep = 'Ctrl/Cmd →';
  static const formPrevStep = 'Ctrl/Cmd ←';
  static const formCancel = 'Esc';
  static const billingDateJump = 'F2';
  static const billingItemLookup = 'F7';
  static const billingSchemeLookup = 'F8';
  static const billingQuickCreate = 'Alt C';
  static const billingPrint = 'Ctrl/Cmd P';
  static const billingAddRow = 'Enter';

  // ── POS ───────────────────────────────────────────────────────
  // "/" (slash) is the search key — universal web-app convention. Ctrl+F is
  // kept as a best-effort fallback in code but browsers reserve it for
  // find-in-page at the OS level and Flutter Web cannot pre-empt it.
  static const posSearch = '/';
  static const posCompleteCurrent = 'Ctrl/Cmd Enter';
  static const posClearCart = 'Ctrl/Cmd Delete';
  static const posCash = 'F1';
  static const posUpi = 'F2';
  static const posCard = 'F3';
  static const posHold = 'F4';
  static const posRecall = 'F5';
  static const posSplit = 'F6';
  static const posScan = 'F7';
  static const posClearSearch = 'Esc';

  static bool isControlOrMetaPressed() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight);
  }

  static bool isShiftPressed() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight);
  }

  static bool isAltOrOptionPressed() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.altLeft) ||
        pressed.contains(LogicalKeyboardKey.altRight);
  }
}
