import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/brand_palette.dart';

/// App-bar "Brand palette" button — a palette icon that opens a dropdown of
/// brand colours (Katixo Teal / Clinical Blue / Warm Amber / Royal Indigo).
/// Picking one repaints the whole app's primary colour live and persists the
/// choice. Mirrors the hospital-os switcher.
///
/// Drop into an AppBar `actions:` list next to [ThemeModeIconButton].
class BrandPaletteSwitcher extends ConsumerWidget {
  const BrandPaletteSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(brandPaletteProvider);
    final controller = ref.read(brandPaletteProvider.notifier);

    return PopupMenuButton<BrandPalette>(
      tooltip: 'Brand palette',
      icon: const Icon(Icons.palette_outlined),
      position: PopupMenuPosition.under,
      onSelected: controller.setPalette,
      itemBuilder: (context) => [
        for (final p in BrandPalette.values)
          PopupMenuItem<BrandPalette>(
            value: p,
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: p.seed,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(p.label)),
                if (p == current) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check_rounded,
                      size: 18, color: Theme.of(context).colorScheme.primary),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
