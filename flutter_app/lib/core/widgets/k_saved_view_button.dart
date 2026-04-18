import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/saved_views.dart';
import '../theme/k_colors.dart';
import '../theme/k_spacing.dart';
import '../theme/k_typography.dart';

/// A compact button that shows the active saved-view name and opens a popup
/// menu for switching, saving, and managing views.
///
/// Drop it into a list screen's [KListPageHeader.actions].
///
/// ```dart
/// KSavedViewButton(
///   entityType: 'invoices',
///   currentFilters: {'status': filter.status, 'search': filter.search},
///   onViewSelected: (filters) { /* apply filters */ },
/// )
/// ```
class KSavedViewButton extends ConsumerWidget {
  final String entityType;
  final Map<String, String?> currentFilters;
  final void Function(Map<String, String?> filters) onViewSelected;

  const KSavedViewButton({
    super.key,
    required this.entityType,
    required this.currentFilters,
    required this.onViewSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final views = ref.watch(savedViewsProvider
        .select((all) => all.where((v) => v.entityType == entityType).toList()));
    final cs = Theme.of(context).colorScheme;

    return PopupMenuButton<_ViewAction>(
      tooltip: 'Saved views',
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KSpacing.radiusMd)),
      itemBuilder: (context) {
        return [
          // Saved view entries
          if (views.isNotEmpty) ...[
            PopupMenuItem(
              enabled: false,
              height: 30,
              child: Text('SAVED VIEWS',
                  style: KTypography.labelSmall.copyWith(
                      color: cs.onSurfaceVariant, letterSpacing: 0.8)),
            ),
            ...views.map((v) => PopupMenuItem(
                  value: _ViewAction.apply(v),
                  child: Row(
                    children: [
                      Icon(Icons.bookmark_rounded,
                          size: 16, color: cs.primary),
                      KSpacing.hGapSm,
                      Expanded(child: Text(v.name, style: KTypography.bodyMedium)),
                      IconButton(
                        icon: const Icon(Icons.close, size: 14),
                        visualDensity: VisualDensity.compact,
                        color: cs.onSurfaceVariant,
                        tooltip: 'Delete view',
                        onPressed: () {
                          Navigator.pop(context);
                          ref.read(savedViewsProvider.notifier).delete(v.id);
                        },
                      ),
                    ],
                  ),
                )),
            const PopupMenuDivider(),
          ],
          PopupMenuItem(
            value: _ViewAction.save(),
            child: Row(
              children: [
                Icon(Icons.bookmark_add_outlined, size: 16, color: cs.primary),
                KSpacing.hGapSm,
                Text('Save current view…', style: KTypography.bodyMedium),
              ],
            ),
          ),
        ];
      },
      onSelected: (action) => action.when(
        apply: (view) => onViewSelected(view.filters),
        save: () => _showSaveDialog(context, ref),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(KSpacing.radiusRound),
          border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_outline_rounded,
                size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 4),
            Text('Views',
                style: KTypography.labelSmall.copyWith(
                    color: cs.onSurfaceVariant)),
            const SizedBox(width: 2),
            Icon(Icons.expand_more_rounded,
                size: 14, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Future<void> _showSaveDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save view'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'View name (e.g. "Overdue this month")',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;

    final view = SavedView(
      id: '${entityType}_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}',
      name: name,
      entityType: entityType,
      filters: currentFilters,
    );
    ref.read(savedViewsProvider.notifier).save(view);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('View "$name" saved')),
      );
    }
  }
}

// ── Simple sealed action type ─────────────────────────────────────────────────

class _ViewAction {
  final SavedView? _view;
  const _ViewAction._(this._view);
  factory _ViewAction.apply(SavedView v) => _ViewAction._(v);
  factory _ViewAction.save() => const _ViewAction._(null);

  T when<T>({
    required T Function(SavedView) apply,
    required T Function() save,
  }) =>
      _view != null ? apply(_view!) : save();
}
