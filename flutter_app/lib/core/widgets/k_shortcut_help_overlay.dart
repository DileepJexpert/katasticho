import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/k_spacing.dart';
import '../theme/k_typography.dart';
import '../shortcuts/k_shortcuts.dart';

class _ShortcutGroup {
  final String title;
  final List<(String, String)> shortcuts;
  const _ShortcutGroup(this.title, this.shortcuts);
}

class KShortcutHelpOverlay extends StatelessWidget {
  final bool showPosShortcuts;
  final bool showListShortcuts;
  final bool showFormShortcuts;

  const KShortcutHelpOverlay({
    super.key,
    this.showPosShortcuts = false,
    this.showListShortcuts = false,
    this.showFormShortcuts = false,
  });

  /// True while a help overlay is on screen — lets the global `?` handler
  /// skip re-opening (so `?` toggles instead of stacking dialogs).
  static bool isOpen = false;

  /// `?` is `Shift+/` on desktop keymaps: embedders report the logical key as
  /// `slash` with shift held, so matching `question` alone only works on web.
  static bool isHelpKey(KeyEvent event) {
    return event.logicalKey == LogicalKeyboardKey.question ||
        (event.logicalKey == LogicalKeyboardKey.slash &&
            HardwareKeyboard.instance.isShiftPressed);
  }

  static Future<void> show(
    BuildContext context, {
    bool showPosShortcuts = false,
    bool showListShortcuts = false,
    bool showFormShortcuts = false,
  }) {
    if (isOpen) return Future.value();
    isOpen = true;
    return _show(
      context,
      showPosShortcuts: showPosShortcuts,
      showListShortcuts: showListShortcuts,
      showFormShortcuts: showFormShortcuts,
    ).whenComplete(() => isOpen = false);
  }

  static Future<void> _show(
    BuildContext context, {
    bool showPosShortcuts = false,
    bool showListShortcuts = false,
    bool showFormShortcuts = false,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (ctx, anim, secondary) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: KShortcutHelpOverlay(
              showPosShortcuts: showPosShortcuts,
              showListShortcuts: showListShortcuts,
              showFormShortcuts: showFormShortcuts,
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, secondary, widget) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1)
                .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
            child: widget,
          ),
        );
      },
    );
  }

  List<_ShortcutGroup> _buildGroups() {
    final groups = <_ShortcutGroup>[
      const _ShortcutGroup('Global', [
        (KShortcuts.commandPalette, 'Command palette'),
        (KShortcuts.shortcutHelp, 'Show this help'),
        (KShortcuts.globalNew, 'New (context-aware)'),
        (KShortcuts.globalSearch, 'Focus search'),
        (KShortcuts.globalEscape, 'Close / cancel'),
      ]),
    ];

    if (showListShortcuts) {
      groups.add(const _ShortcutGroup('List', [
        (KShortcuts.listNew, 'Create new'),
        (KShortcuts.listSearch, 'Focus search'),
        (KShortcuts.listRefresh, 'Refresh'),
        (KShortcuts.listDown, 'Move down'),
        (KShortcuts.listUp, 'Move up'),
        (KShortcuts.listOpen, 'Open selected'),
        (KShortcuts.listSelect, 'Toggle selection'),
      ]));
    }

    if (showFormShortcuts) {
      groups.add(const _ShortcutGroup('Form', [
        (KShortcuts.formSubmit, 'Submit / save'),
        (KShortcuts.formNextStep, 'Next step'),
        (KShortcuts.formPrevStep, 'Previous step'),
        (KShortcuts.formCancel, 'Cancel'),
      ]));
    }

    if (showPosShortcuts) {
      groups.add(const _ShortcutGroup('POS', [
        (KShortcuts.posSearch, 'Focus search'),
        (KShortcuts.posCompleteCurrent, 'Complete sale'),
        (KShortcuts.posClearCart, 'Clear cart'),
        (KShortcuts.posCash, 'Cash'),
        (KShortcuts.posUpi, 'UPI'),
        (KShortcuts.posCard, 'Card'),
        (KShortcuts.posHold, 'Hold cart'),
        (KShortcuts.posRecall, 'Recall cart'),
        (KShortcuts.posSplit, 'Split payment'),
        (KShortcuts.posScan, 'Barcode scanner'),
      ]));
    }

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final groups = _buildGroups();

    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.escape ||
                KShortcutHelpOverlay.isHelpKey(event))) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 520),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(KSpacing.radiusLg),
          border: Border.all(color: cs.outlineVariant),
          boxShadow: KSpacing.shadowMd,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Icon(Icons.keyboard_rounded,
                      size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text('Keyboard Shortcuts', style: KTypography.h3),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < groups.length; i++) ...[
                      if (i > 0) const SizedBox(height: 16),
                      _GroupSection(group: groups[i]),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupSection extends StatelessWidget {
  final _ShortcutGroup group;
  const _GroupSection({required this.group});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          group.title.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: cs.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 6),
        for (final (key, desc) in group.shortcuts)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                _KeyBadge(label: key),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    desc,
                    style: TextStyle(fontSize: 13, color: cs.onSurface),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _KeyBadge extends StatelessWidget {
  final String label;
  const _KeyBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 80),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}
