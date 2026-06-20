import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/k_colors.dart';
import '../theme/k_spacing.dart';
import '../theme/k_typography.dart';
import 'k_text_field.dart';

/// One row's worth of display info, rendered inside the typeahead dropdown.
class KTypeaheadItem {
  final String title;
  final String? subtitle;
  final String? trailing;
  final IconData? leading;
  const KTypeaheadItem({
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
  });
}

/// Inline, keyboard-first picker. Replaces modal pickers AND dropdowns: user
/// types, ↑/↓ navigates the dropdown, Enter commits, Tab commits and advances
/// focus to the next field.
///
/// Mouse-safe: rows are tappable, the modal picker can still live alongside as
/// a "Browse all" fallback. This widget is purely additive.
///
/// Keyboard contract:
///   type   → debounced search; overlay opens with results
///   ↓ / ↑  → highlight next / prev (wraps)
///   Enter  → commit highlighted (or first), close overlay, keep focus
///   Tab    → commit highlighted (or first), close overlay, advance focus
///   Esc    → close overlay (does NOT clear field while still focused)
///   click  → commit and close
class KTypeaheadField<T> extends StatefulWidget {
  final Future<List<T>> Function(String query) onSearch;
  final KTypeaheadItem Function(T value) itemBuilder;
  final String Function(T value) displayString;
  final ValueChanged<T> onSelected;

  /// Optional: invoked when user presses Enter on a query with zero results.
  /// Useful for "create new contact / item from this query" flows.
  final ValueChanged<String>? onCreateNew;

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool isRequired;

  /// Wait this long after the last keystroke before firing onSearch.
  /// 200ms matches the POS catalog typeahead.
  final int debounceMs;

  /// Minimum characters before search fires (avoids hammering on first key).
  final int minChars;

  /// Maximum rows shown before the dropdown scrolls.
  final int maxVisibleRows;

  const KTypeaheadField({
    super.key,
    required this.onSearch,
    required this.itemBuilder,
    required this.displayString,
    required this.onSelected,
    required this.label,
    this.onCreateNew,
    this.hint,
    this.controller,
    this.focusNode,
    this.autofocus = false,
    this.isRequired = false,
    this.debounceMs = 200,
    this.minChars = 1,
    this.maxVisibleRows = 7,
  });

  @override
  State<KTypeaheadField<T>> createState() => _KTypeaheadFieldState<T>();
}

class _KTypeaheadFieldState<T> extends State<KTypeaheadField<T>> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _ownsController = false;
  bool _ownsFocusNode = false;

  final LayerLink _layerLink = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  OverlayEntry? _overlay;
  List<T> _results = const [];
  int _highlight = -1;
  bool _loading = false;
  Timer? _debounce;
  int _searchSeq = 0;
  String _lastQuery = '';

  static const double _rowHeight = 52;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _ownsController = widget.controller == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode.addListener(_handleFocusChange);
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _hideOverlay();
    _focusNode.removeListener(_handleFocusChange);
    if (_ownsFocusNode) _focusNode.dispose();
    if (_ownsController) _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Focus + overlay lifecycle ────────────────────────────────────────

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      // Defer hide so a tap on a dropdown row has time to fire its onTap.
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (mounted && !_focusNode.hasFocus) _hideOverlay();
      });
    } else if (_results.isNotEmpty) {
      _showOverlay();
    }
  }

  void _showOverlay() {
    if (_overlay != null) {
      _overlay!.markNeedsBuild();
      return;
    }
    final overlay = Overlay.maybeOf(context, rootOverlay: false);
    if (overlay == null) return;
    _overlay = OverlayEntry(builder: _buildOverlay);
    overlay.insert(_overlay!);
  }

  void _hideOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  // ── Search ───────────────────────────────────────────────────────────

  void _onChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.length < widget.minChars) {
      setState(() {
        _results = const [];
        _highlight = -1;
        _loading = false;
        _lastQuery = trimmed;
      });
      _hideOverlay();
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(Duration(milliseconds: widget.debounceMs), () {
      _runSearch(trimmed);
    });
  }

  Future<void> _runSearch(String q) async {
    final seq = ++_searchSeq;
    _lastQuery = q;
    try {
      final results = await widget.onSearch(q);
      // Drop stale responses — the user has typed further by now.
      if (seq != _searchSeq || !mounted) return;
      setState(() {
        _results = results;
        _highlight = results.isEmpty ? -1 : 0;
        _loading = false;
      });
      if (_focusNode.hasFocus) {
        _showOverlay();
      }
    } catch (_) {
      if (seq != _searchSeq || !mounted) return;
      setState(() {
        _results = const [];
        _highlight = -1;
        _loading = false;
      });
      _hideOverlay();
    }
  }

  // ── Commit ───────────────────────────────────────────────────────────

  void _commit(T value) {
    final display = widget.displayString(value);
    _controller.text = display;
    _controller.selection = TextSelection.collapsed(offset: display.length);
    _debounce?.cancel();
    setState(() {
      _results = const [];
      _highlight = -1;
      _loading = false;
    });
    _hideOverlay();
    widget.onSelected(value);
  }

  void _commitOrCreateFromEnter() {
    if (_results.isNotEmpty) {
      final idx = _highlight >= 0 ? _highlight : 0;
      _commit(_results[idx]);
      return;
    }
    final create = widget.onCreateNew;
    if (create != null && _controller.text.trim().isNotEmpty) {
      create(_controller.text.trim());
    }
  }

  // ── Key handler ──────────────────────────────────────────────────────

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.escape) {
      if (_overlay != null) {
        _hideOverlay();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final overlayOpen = _overlay != null;
    if (!overlayOpen) return KeyEventResult.ignored;

    if (key == LogicalKeyboardKey.arrowDown) {
      if (_results.isEmpty) return KeyEventResult.handled;
      setState(() {
        _highlight = (_highlight + 1) % _results.length;
      });
      _scrollToHighlight();
      _overlay?.markNeedsBuild();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_results.isEmpty) return KeyEventResult.handled;
      setState(() {
        _highlight = (_highlight - 1 + _results.length) % _results.length;
      });
      _scrollToHighlight();
      _overlay?.markNeedsBuild();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _commitOrCreateFromEnter();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      // Commit, then return ignored so Flutter's native Tab handler advances
      // focus to the next field. Doing our own nextFocus() in addition would
      // skip a slot.
      _commitOrCreateFromEnter();
      return KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  void _scrollToHighlight() {
    if (_highlight < 0 || !_scrollController.hasClients) return;
    final target = _highlight * _rowHeight;
    final viewport = _scrollController.position.viewportDimension;
    final current = _scrollController.offset;
    if (target < current) {
      _scrollController.jumpTo(target);
    } else if (target + _rowHeight > current + viewport) {
      _scrollController.jumpTo(target + _rowHeight - viewport);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Focus(
        skipTraversal: true, // child KTextField owns the traversal slot
        onKeyEvent: _handleKey,
        child: KTextField(
          key: _fieldKey,
          label: widget.label,
          hint: widget.hint,
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onChanged,
          isRequired: widget.isRequired,
          prefixIcon: Icons.search,
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final fieldBox =
        _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    final width = fieldBox?.size.width ?? 300;
    final fieldHeight = fieldBox?.size.height ?? 40;
    final visibleRows =
        _results.length.clamp(1, widget.maxVisibleRows).toInt();
    final listHeight = (visibleRows * _rowHeight) + 8;

    final showCreate = widget.onCreateNew != null &&
        _results.isEmpty &&
        !_loading &&
        _lastQuery.isNotEmpty;

    return Positioned(
      width: width,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: Offset(0, fieldHeight + 4),
        child: Material(
          elevation: 6,
          borderRadius: KSpacing.borderRadiusMd,
          color: KColors.surface,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: listHeight + 4),
            child: _buildOverlayBody(showCreate),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayBody(bool showCreate) {
    if (_loading && _results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(KSpacing.sm),
        child: SizedBox(
          height: 18,
          width: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_results.isEmpty) {
      if (showCreate) {
        return InkWell(
          onTap: () {
            widget.onCreateNew?.call(_lastQuery);
            _hideOverlay();
          },
          child: Padding(
            padding: const EdgeInsets.all(KSpacing.sm),
            child: Row(
              children: [
                const Icon(Icons.add, size: 16, color: KColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Create "$_lastQuery"',
                    style: KTypography.bodyMedium
                        .copyWith(color: KColors.primary),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.all(KSpacing.sm),
        child: Text(
          'No matches',
          style:
              KTypography.bodySmall.copyWith(color: KColors.textSecondary),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final value = _results[i];
        final info = widget.itemBuilder(value);
        final selected = i == _highlight;
        return MouseRegion(
          onEnter: (_) {
            if (_highlight != i) {
              setState(() => _highlight = i);
              _overlay?.markNeedsBuild();
            }
          },
          child: InkWell(
            onTap: () => _commit(value),
            child: Container(
              height: _rowHeight,
              padding: const EdgeInsets.symmetric(
                  horizontal: KSpacing.sm, vertical: 6),
              color: selected
                  ? KColors.primary.withValues(alpha: 0.10)
                  : Colors.transparent,
              child: Row(
                children: [
                  if (info.leading != null) ...[
                    Icon(info.leading, size: 16, color: KColors.textSecondary),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          info.title,
                          style: KTypography.bodyMedium.copyWith(
                              fontWeight:
                                  selected ? FontWeight.w600 : FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (info.subtitle != null)
                          Text(
                            info.subtitle!,
                            style: KTypography.bodySmall
                                .copyWith(color: KColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (info.trailing != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      info.trailing!,
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
