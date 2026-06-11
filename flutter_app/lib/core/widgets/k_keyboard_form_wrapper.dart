import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../shortcuts/k_shortcuts.dart';

class KKeyboardFormWrapper extends StatelessWidget {
  final Widget child;
  final VoidCallback? onSubmit;
  final VoidCallback? onNextStep;
  final VoidCallback? onPrevStep;
  final VoidCallback? onCancel;

  const KKeyboardFormWrapper({
    super.key,
    required this.child,
    this.onSubmit,
    this.onNextStep,
    this.onPrevStep,
    this.onCancel,
  });

  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final hasModifier = KShortcuts.isControlOrMetaPressed();

    if (hasModifier &&
        (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter)) {
      onSubmit?.call();
      return KeyEventResult.handled;
    }

    if (hasModifier && key == LogicalKeyboardKey.arrowRight) {
      onNextStep?.call();
      return KeyEventResult.handled;
    }
    if (hasModifier && key == LogicalKeyboardKey.arrowLeft) {
      onPrevStep?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape && !hasModifier) {
      onCancel?.call();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: _handleKey,
      child: child,
    );
  }
}
