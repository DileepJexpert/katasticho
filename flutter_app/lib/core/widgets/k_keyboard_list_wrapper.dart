import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../shortcuts/k_shortcuts.dart';

typedef KeyboardListCallback = void Function();
typedef KeyboardListOpenCallback = void Function(int index);

class KKeyboardListWrapper extends StatefulWidget {
  final Widget child;

  /// Read lazily at each keypress so navigation works even when the list is
  /// loaded inside an async builder during the same build pass (a plain int
  /// would be stale until the next rebuild).
  final int Function() itemCount;
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
    final count = widget.itemCount();
    if (count == 0) return;
    selectedIndex = (_selectedIndex + delta).clamp(0, count - 1);
  }

  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_isTextFieldFocused()) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final hasModifier = KShortcuts.isControlOrMetaPressed();
    final isRepeat = event is KeyRepeatEvent;

    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyJ) {
      _move(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyK) {
      _move(-1);
      return KeyEventResult.handled;
    }

    // Action keys fire once per press — holding Enter must not stack detail
    // routes, and holding R must not hammer the API.
    if (isRepeat) return KeyEventResult.ignored;

    if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) &&
        !hasModifier) {
      final count = widget.itemCount();
      if (_selectedIndex >= 0 && _selectedIndex < count && widget.onOpen != null) {
        widget.onOpen!(_selectedIndex);
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.keyN && !hasModifier && widget.onNew != null) {
      widget.onNew!();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyR && !hasModifier && widget.onRefresh != null) {
      widget.onRefresh!();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.slash &&
        !hasModifier &&
        !KShortcuts.isShiftPressed() &&
        widget.onSearchFocus != null) {
      widget.onSearchFocus!();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyX && !hasModifier && widget.onToggleSelect != null) {
      widget.onToggleSelect!();
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
