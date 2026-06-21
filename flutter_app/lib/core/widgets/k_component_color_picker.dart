import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/component_color_controller.dart';
import '../theme/k_colors.dart';
import '../theme/k_spacing.dart';
import '../theme/k_typography.dart';

/// A swatch picker for the per-component colour override
/// ([componentColorProvider]). Open it from a card's overflow menu or
/// long-press to let the user paint that component a colour different from
/// the global theme.
///
/// Uses a fixed palette drawn from the design-system tokens (no third-party
/// colour-picker dependency) — pick a swatch, or "Use theme colour" to clear.
///
/// ```dart
/// onLongPress: () => KComponentColorPicker.show(context, 'dashboard.sales'),
/// ```
class KComponentColorPicker {
  KComponentColorPicker._();

  /// Design-system-aligned palette the user can choose from.
  static const List<Color> palette = [
    KColors.brandSeed, // teal
    Color(0xFF1D4ED8), // info blue
    Color(0xFF15803D), // success green
    Color(0xFFB45309), // amber
    Color(0xFFBE3A34), // muted brick
    Color(0xFF7C3AED), // violet
    Color(0xFF0D9488), // shipped teal
    Color(0xFFC2410C), // rust
    Color(0xFF5F5F59), // warm grey
  ];

  static Future<void> show(BuildContext context, String colorKey) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _PickerSheet(colorKey: colorKey),
    );
  }
}

class _PickerSheet extends ConsumerWidget {
  final String colorKey;
  const _PickerSheet({required this.colorKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(
      componentColorProvider.select((m) => m[colorKey]),
    );
    final controller = ref.read(componentColorProvider.notifier);

    return Padding(
      padding: KSpacing.pagePaddingLg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Component colour', style: KTypography.h4),
          const SizedBox(height: 4),
          Text(
            'Paint this card a colour different from the app theme.',
            style: KTypography.bodySmall.copyWith(
              color: KColors.textSecondary,
            ),
          ),
          KSpacing.vGapMd,
          Wrap(
            spacing: KSpacing.sm,
            runSpacing: KSpacing.sm,
            children: [
              for (final c in KComponentColorPicker.palette)
                _Swatch(
                  color: c,
                  selected: current?.toARGB32() == c.toARGB32(),
                  onTap: () {
                    controller.setColor(colorKey, c);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
          KSpacing.vGapMd,
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: current == null
                  ? null
                  : () {
                      controller.clear(colorKey);
                      Navigator.of(context).pop();
                    },
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text('Use theme colour'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KSpacing.radiusMd),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(KSpacing.radiusMd),
          border: Border.all(
            color: selected ? KColors.textPrimary : Colors.transparent,
            width: 2,
          ),
        ),
        child: selected
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}
