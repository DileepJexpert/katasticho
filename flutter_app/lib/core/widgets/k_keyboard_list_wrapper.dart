import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../shortcuts/k_shortcuts.dart';

typedef KeyboardListCallback = void Function();
typedef KeyboardListOpenCallback = void Function(int index);

class KKeyboardListWrapper extends StatefulWidget {
  final Widget child;
  final int itemCount;
  final KeyboardListCallback? onNew;
  final KeyboardListCallback? onRefresh;
  final KeyboardListCallback? onSearchFocus;
  final KeyboardListOpenCallback? onOpen;
  final KeyboardListCallback? onToggleSelect;
  final ValueChanged<int>? onSelectedIndexChanged;

  const KKeyboardListWrapper({
    super.key,
    required this.child,
    required this.itemCount,
    this.onNew,
    this.onRefresh,
    this.onSearchFocus,
    this.onOpen,
    this.onToggleSelect,
    this.onSelectedIndexChanged,
  });

  @override
  State<KKeyboardListWrapper> createState() => KKeyboardListWrapperState();
}

class KKeyboardListWrapperState extends State<KKeyboardListWrapper> {
  int _selectedIndex = -1;

  int get selectedIndex => _selectedIndex;

  set selectedIndex(int value) {
    if (value != _selectedIndex) {
      setState(() => _selectedIndex = value);
      widget.onSelectedIndexChanged?.call(value);
    }
  }

  void _move(int delta) {
    if (widget.itemCount == 0) return;
    final next = (_selectedIndex + delta).clamp(0, widget.itemCount - 1);
    selectedIndex = next;
  }

  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_isTextFieldFocused()) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final hasModifier = KShortcuts.isControlOrMetaPressed();

    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyJ) {
      _move(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyK) {
      _move(-1);
      return KeyEventResult.handled;
    }
    if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) &&
        !hasModifier) {
      if (_selectedIndex >= 0 && widget.onOpen != null) {
        widget.onOpen!(_selectedIndex);
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.keyN && !hasModifier) {
      widget.onNew?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyR && !hasModifier) {
      widget.onRefresh?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.slash && !hasModifier) {
      widget.onSearchFocus?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyX && !hasModifier) {
      widget.onToggleSelect?.call();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  bool _isTextFieldFocused() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return false;
    final ctx = focus.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: widget.child,
    );
  }
}
