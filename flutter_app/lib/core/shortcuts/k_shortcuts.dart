import 'package:flutter/services.dart';

/// Central shortcut catalogue for app-wide and high-volume workflow keys.
///
/// Keep this file as the single source for labels and key detection so screens
/// do not drift into different shortcut meanings.
class KShortcuts {
  const KShortcuts._();

  static const commandPalette = 'Ctrl/Cmd K';

  static const posSearch = 'Ctrl/Cmd F';
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
}
