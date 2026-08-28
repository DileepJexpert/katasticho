import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../shortcuts/k_shortcuts.dart';

class KKeyboardFormWrapper extends StatelessWidget {
  final Widget child;
  final VoidCallback? onSubmit;
  final VoidCallback? onNextStep;
  final VoidCallback? onPrevStep;
  final VoidCallback? onCancel;
  final VoidCallback? onDateJump;
  final VoidCallback? onItemPicker;
  final VoidCallback? onSchemeLookup;
  final VoidCallback? onQuickCreate;
  final VoidCallback? onSaveAndPrint;
  final VoidCallback? onAddRow;

  const KKeyboardFormWrapper({
    super.key,
    required this.child,
    this.onSubmit,
    this.onNextStep,
    this.onPrevStep,
    this.onCancel,
    this.onDateJump,
    this.onItemPicker,
    this.onSchemeLookup,
    this.onQuickCreate,
    this.onSaveAndPrint,
    this.onAddRow,
  });

  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final hasModifier = KShortcuts.isControlOrMetaPressed();
    final hasAlt = KShortcuts.isAltOrOptionPressed();

    // Ctrl/Cmd + Enter: Submit & save document
    if (hasModifier &&
        (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter)) {
      onSubmit?.call();
      return KeyEventResult.handled;
    }

    // Ctrl/Cmd + P: Save & Print
    if (hasModifier && key == LogicalKeyboardKey.keyP && onSaveAndPrint != null) {
      onSaveAndPrint?.call();
      return KeyEventResult.handled;
    }

    // F2: Date jumper / picker
    if (key == LogicalKeyboardKey.f2 && onDateJump != null) {
      onDateJump?.call();
      return KeyEventResult.handled;
    }

    // F7: Fast Item search / picker
    if (key == LogicalKeyboardKey.f7 && onItemPicker != null) {
      onItemPicker?.call();
      return KeyEventResult.handled;
    }

    // F8: Schemes / Promotions lookup
    if (key == LogicalKeyboardKey.f8 && onSchemeLookup != null) {
      onSchemeLookup?.call();
      return KeyEventResult.handled;
    }

    // Alt + C: In-line Quick Create (Customer, Vendor, Item)
    if (hasAlt && key == LogicalKeyboardKey.keyC && onQuickCreate != null) {
      onQuickCreate?.call();
      return KeyEventResult.handled;
    }

    // Alt + A or Ctrl + Insert: Add new line item row
    if (((hasAlt && key == LogicalKeyboardKey.keyA) ||
            (hasModifier && key == LogicalKeyboardKey.insert)) &&
        onAddRow != null) {
      onAddRow?.call();
      return KeyEventResult.handled;
    }

    // Ctrl + Arrow navigation across multi-step wizard tabs
    if (hasModifier && key == LogicalKeyboardKey.arrowRight) {
      onNextStep?.call();
      return KeyEventResult.handled;
    }
    if (hasModifier && key == LogicalKeyboardKey.arrowLeft) {
      onPrevStep?.call();
      return KeyEventResult.handled;
    }

    // Esc cancels the form — but never while the user is typing in a field
    // (Esc there is habitually used to dismiss autocomplete/IME popups, and
    // navigating away would silently discard everything entered).
    if (key == LogicalKeyboardKey.escape &&
        !hasModifier &&
        !hasAlt &&
        !_isTextFieldFocused()) {
      onCancel?.call();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  bool _isTextFieldFocused() {
    final focus = FocusManager.instance.primaryFocus;
    final ctx = focus?.context;
    return ctx != null && ctx.widget is EditableText;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: _handleKey,
      child: child,
    );
  }
}
