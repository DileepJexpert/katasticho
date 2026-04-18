import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/k_spacing.dart';
import '../theme/k_typography.dart';

/// A single entry in the command palette.
///
/// Supply EITHER [route] (we'll `context.go(route)` on activate) OR
/// [onActivate] for custom actions.
class KCommand {
  final String label;
  final String? subtitle;
  final IconData icon;
  final String? route;
  final VoidCallback? onActivate;
  final List<String> keywords;
  final String section;

  const KCommand({
    required this.label,
    required this.icon,
    required this.section,
    this.subtitle,
    this.route,
    this.onActivate,
    this.keywords = const [],
  });

  /// Lower-cased haystack for fuzzy matching.
  String get _haystack => '$label ${keywords.join(" ")} ${subtitle ?? ""}'
      .toLowerCase();

  /// Subsequence + prefix-bonus score. Higher = better. 0 = no match.
  int score(String query) {
    if (query.isEmpty) return 1;
    final q = query.toLowerCase().trim();
    final h = _haystack;
    if (h.startsWith(q)) return 1000 + (200 - q.length).clamp(0, 200);
    if (label.toLowerCase().contains(q)) return 500;
    // Subsequence match (fuzzy).
    var hi = 0, qi = 0;
    while (hi < h.length && qi < q.length) {
      if (h[hi] == q[qi]) qi++;
      hi++;
    }
    return qi == q.length ? 100 : 0;
  }
}

/// Centered command palette — **Katasticho 2026** spec.
///
/// Cmd/Ctrl+K opens it. Arrow keys move selection, Enter activates,
/// Escape dismisses.
class KCommandPalette extends StatefulWidget {
  final List<KCommand> commands;

  const KCommandPalette({super.key, required this.commands});

  static Future<void> show(
    BuildContext context, {
    required List<KCommand> commands,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (ctx, anim, secondary) {
        return Align(
          alignment: const Alignment(0, -0.6),
          child: Material(
            color: Colors.transparent,
            child: KCommandPalette(commands: commands),
          ),
        );
      },
      transitionBuilder: (ctx, anim, secondary, widget) {
        final scale = Tween<double>(begin: 0.97, end: 1).animate(
          CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
        );
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: scale, child: widget),
        );
      },
    );
  }

  @override
  State<KCommandPalette> createState() => _KCommandPaletteState();
}

class _KCommandPaletteState extends State<KCommandPalette> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  int _selectedIndex = 0;
  List<KCommand> _filtered = const [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.commands;
    _controller.addListener(_onQueryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _onQueryChanged() {
    final q = _controller.text;
    final scored = <(int, KCommand)>[];
    for (final c in widget.commands) {
      final s = c.score(q);
      if (s > 0) scored.add((s, c));
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    setState(() {
      _filtered = scored.map((e) => e.$2).toList(growable: false);
      _selectedIndex = 0;
    });
  }

  void _activate() {
    if (_filtered.isEmpty) return;
    final cmd = _filtered[_selectedIndex];
    Navigator.of(context).pop();
    if (cmd.onActivate != null) {
      cmd.onActivate!();
    } else if (cmd.route != null) {
      context.go(cmd.route!);
    }
  }

  void _move(int delta) {
    if (_filtered.isEmpty) return;
    setState(() {
      _selectedIndex =
          (_selectedIndex + delta).clamp(0, _filtered.length - 1);
    });
    // Best-effort: scroll the selected row into view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      const rowHeight = 48.0;
      final target = _selectedIndex * rowHeight;
      final viewport = _scrollController.position.viewportDimension;
      final offset = _scrollController.offset;
      if (target < offset) {
        _scrollController.jumpTo(target);
      } else if (target + rowHeight > offset + viewport) {
        _scrollController.jumpTo(target + rowHeight - viewport);
      }
    });
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.arrowDown) {
      _move(1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp) {
      _move(-1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      _activate();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(KSpacing.radiusXl);

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 480),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: radius,
          border: Border.all(color: cs.outlineVariant, width: 1),
          boxShadow: KSpacing.shadowLg,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search row
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded,
                        size: 18, color: cs.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        autofocus: true,
                        style: KTypography.bodyMedium.copyWith(
                          color: cs.onSurface,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search commands, pages…',
                          hintStyle: KTypography.bodyMedium.copyWith(
                            color: cs.onSurfaceVariant
                                .withValues(alpha: 0.7),
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onSubmitted: (_) => _activate(),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                        border:
                            Border.all(color: cs.outlineVariant, width: 1),
                      ),
                      child: Text(
                        'esc',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1, color: cs.outlineVariant),

              // Results
              Flexible(
                child: _filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 32),
                        child: Center(
                          child: Text(
                            'No matches.',
                            style: KTypography.bodyMedium.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) {
                          final cmd = _filtered[i];
                          final selected = i == _selectedIndex;
                          final showSection = i == 0 ||
                              _filtered[i - 1].section != cmd.section;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (showSection)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      14, 8, 14, 4),
                                  child: Text(
                                    cmd.section.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.0,
                                      color: cs.onSurfaceVariant
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                              _CommandRow(
                                command: cmd,
                                selected: selected,
                                onHover: () {
                                  if (!selected) {
                                    setState(() => _selectedIndex = i);
                                  }
                                },
                                onTap: _activate,
                              ),
                            ],
                          );
                        },
                      ),
              ),

              // Footer hints
              Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  border: Border(
                    top: BorderSide(color: cs.outlineVariant, width: 1),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    _Kbd(label: '↑↓'),
                    const SizedBox(width: 6),
                    Text('Navigate',
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant)),
                    const SizedBox(width: 14),
                    _Kbd(label: '↵'),
                    const SizedBox(width: 6),
                    Text('Open',
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant)),
                    const Spacer(),
                    Text(
                      '${_filtered.length} result${_filtered.length == 1 ? "" : "s"}',
                      style:
                          TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommandRow extends StatelessWidget {
  final KCommand command;
  final bool selected;
  final VoidCallback onHover;
  final VoidCallback onTap;

  const _CommandRow({
    required this.command,
    required this.selected,
    required this.onHover,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => onHover(),
      child: Material(
        color: selected ? cs.primaryContainer.withValues(alpha: 0.6)
                       : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  command.icon,
                  size: 18,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        command.label,
                        style: KTypography.bodyMedium.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (command.subtitle != null)
                        Text(
                          command.subtitle!,
                          style: KTypography.bodySmall.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.subdirectory_arrow_left_rounded,
                      size: 14, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Kbd extends StatelessWidget {
  final String label;
  const _Kbd({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: cs.outlineVariant, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}
