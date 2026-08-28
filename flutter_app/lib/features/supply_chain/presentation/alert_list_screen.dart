import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_keyboard_list_wrapper.dart';
import '../../../core/widgets/k_loading.dart';
import '../data/supply_chain_repository.dart';
import 'widgets/scm_breadcrumb.dart';

final _alertListProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(supplyChainRepositoryProvider).listAlerts(status: 'OPEN');
});

class SupplyChainAlertListScreen extends ConsumerStatefulWidget {
  const SupplyChainAlertListScreen({super.key});

  @override
  ConsumerState<SupplyChainAlertListScreen> createState() => _SupplyChainAlertListScreenState();
}

class _SupplyChainAlertListScreenState extends ConsumerState<SupplyChainAlertListScreen> {
  bool _scanning = false;
  String _severityFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(_alertListProvider);
    final cs = Theme.of(context).colorScheme;

    return KKeyboardListWrapper(
      itemCount: () => (listAsync.valueOrNull?['content'] as List?)?.length ?? 0,
      onRefresh: () => ref.invalidate(_alertListProvider),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Supply Chain Alerts'),
          bottom: scmBreadcrumb(context, 'Alerts'),
        ),
        body: listAsync.when(
          loading: () => const KLoading(message: 'Loading supply chain alerts...'),
          error: (e, _) => Center(
            child: Padding(
              padding: KSpacing.pagePadding,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline_rounded, size: 48, color: KColors.error),
                  KSpacing.vGapMd,
                  Text(ApiErrorParser.message(e), style: KTypography.bodyMedium, textAlign: TextAlign.center),
                  KSpacing.vGapMd,
                  KButton.outlined(
                    label: 'Retry',
                    icon: Icons.refresh_rounded,
                    onPressed: () => ref.invalidate(_alertListProvider),
                  ),
                ],
              ),
            ),
          ),
          data: (data) {
            final rawItems = (data['content'] as List?) ?? [];
            final items = rawItems.where((a) {
              if (_severityFilter == 'ALL') return true;
              final map = a as Map<String, dynamic>;
              return (map['severity'] as String? ?? '').toUpperCase() == _severityFilter;
            }).toList();

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(_alertListProvider),
              child: ListView(
                padding: KSpacing.pagePadding,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Shortage & Risk Alerts',
                              style: KTypography.h2.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Real-time detection of low stock, expiring batches, and supplier delay risks.',
                              style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      KButton.primary(
                        label: 'Scan Alerts',
                        icon: Icons.radar_rounded,
                        isLoading: _scanning,
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          setState(() => _scanning = true);
                          try {
                            await ref.read(supplyChainRepositoryProvider).runAlertScan();
                            ref.invalidate(_alertListProvider);
                            if (!mounted) return;
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Alert scan completed successfully')),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(content: Text(ApiErrorParser.message(e)), backgroundColor: KColors.error),
                            );
                          } finally {
                            if (mounted) setState(() => _scanning = false);
                          }
                        },
                      ),
                    ],
                  ),
                  KSpacing.vGapMd,
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _SeverityChip(
                          label: 'All (${rawItems.length})',
                          selected: _severityFilter == 'ALL',
                          onSelected: () => setState(() => _severityFilter = 'ALL'),
                        ),
                        const SizedBox(width: 8),
                        _SeverityChip(
                          label: 'High Severity',
                          selected: _severityFilter == 'HIGH',
                          color: KColors.error,
                          onSelected: () => setState(() => _severityFilter = 'HIGH'),
                        ),
                        const SizedBox(width: 8),
                        _SeverityChip(
                          label: 'Medium',
                          selected: _severityFilter == 'MEDIUM',
                          color: KColors.warning,
                          onSelected: () => setState(() => _severityFilter = 'MEDIUM'),
                        ),
                        const SizedBox(width: 8),
                        _SeverityChip(
                          label: 'Low',
                          selected: _severityFilter == 'LOW',
                          color: KColors.info,
                          onSelected: () => setState(() => _severityFilter = 'LOW'),
                        ),
                      ],
                    ),
                  ),
                  KSpacing.vGapMd,
                  if (items.isEmpty)
                    KEmptyState(
                      icon: Icons.check_circle_outline_rounded,
                      title: 'Zero Open Alerts',
                      subtitle: _severityFilter != 'ALL'
                          ? 'No open alerts with $_severityFilter severity.'
                          : 'All inventory items are within healthy replenishment thresholds.',
                      actionLabel: 'Re-scan Now',
                      onAction: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        setState(() => _scanning = true);
                        try {
                          await ref.read(supplyChainRepositoryProvider).runAlertScan();
                          ref.invalidate(_alertListProvider);
                        } catch (e) {
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(content: Text(ApiErrorParser.message(e)), backgroundColor: KColors.error),
                          );
                        } finally {
                          if (mounted) setState(() => _scanning = false);
                        }
                      },
                    )
                  else
                    ...items.map((alert) {
                      final map = alert as Map<String, dynamic>;
                      return _AlertCard(alert: map, ref: ref);
                    }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SeverityChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onSelected;

  const _SeverityChip({
    required this.label,
    required this.selected,
    this.color,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeColor = color ?? cs.primary;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      labelStyle: KTypography.labelSmall.copyWith(
        color: selected ? Colors.white : cs.onSurface,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      selectedColor: activeColor,
      showCheckmark: false,
    );
  }
}

class _AlertCard extends StatefulWidget {
  final Map<String, dynamic> alert;
  final WidgetRef ref;
  const _AlertCard({required this.alert, required this.ref});

  @override
  State<_AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends State<_AlertCard> {
  bool _resolving = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final severity = (widget.alert['severity'] as String? ?? 'MEDIUM').toUpperCase();
    final color = switch (severity) {
      'HIGH' => KColors.error,
      'MEDIUM' => KColors.warning,
      'LOW' => KColors.info,
      _ => KColors.draft,
    };
    final icon = switch (severity) {
      'HIGH' => Icons.error_outline_rounded,
      'MEDIUM' => Icons.warning_amber_rounded,
      _ => Icons.info_outline_rounded,
    };
    final alertType = (widget.alert['alertType']?.toString() ?? 'ALERT').replaceAll('_', ' ');
    final description = widget.alert['description'] as String?;

    return KCard(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      padding: const EdgeInsets.all(KSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(KSpacing.radiusSm),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.alert['title'] ?? 'Alert',
                        style: KTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        severity,
                        style: KTypography.labelSmall.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  alertType,
                  style: KTypography.labelSmall.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          KSpacing.hGapSm,
          KButton.outlined(
            label: 'Resolve',
            size: KButtonSize.small,
            isLoading: _resolving,
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              setState(() => _resolving = true);
              try {
                await widget.ref.read(supplyChainRepositoryProvider).resolveAlert(widget.alert['id']);
                widget.ref.invalidate(_alertListProvider);
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(content: Text('Alert marked as resolved')),
                );
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text(ApiErrorParser.message(e)), backgroundColor: KColors.error),
                );
              } finally {
                if (mounted) setState(() => _resolving = false);
              }
            },
          ),
        ],
      ),
    );
  }
}
