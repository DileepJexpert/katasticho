import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_keyboard_list_wrapper.dart';
import '../../../core/utils/api_error_parser.dart';
import '../data/supply_chain_repository.dart';

final _alertListProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(supplyChainRepositoryProvider).listAlerts(status: 'OPEN');
});

class SupplyChainAlertListScreen extends ConsumerWidget {
  const SupplyChainAlertListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(_alertListProvider);

    return KKeyboardListWrapper(
      itemCount: () => (listAsync.valueOrNull?['content'] as List?)?.length ?? 0,
      onRefresh: () => ref.invalidate(_alertListProvider),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Supply Chain Alerts'),
          actions: [
            IconButton(
              tooltip: 'Scan for alerts',
              icon: const Icon(Icons.radar),
              onPressed: () async {
                try {
                  await ref.read(supplyChainRepositoryProvider).runAlertScan();
                  ref.invalidate(_alertListProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Alert scan completed')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ApiErrorParser.message(e))),
                    );
                  }
                }
              },
            ),
          ],
        ),
        body: listAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
          data: (data) {
            final items = (data['content'] as List?) ?? [];
            if (items.isEmpty) {
              return const Center(child: Text('No open alerts'));
            }
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(_alertListProvider),
              child: ListView.builder(
                padding: KSpacing.pagePadding,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final alert = items[index] as Map<String, dynamic>;
                  return _AlertCard(alert: alert, ref: ref);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Map<String, dynamic> alert;
  final WidgetRef ref;
  const _AlertCard({required this.alert, required this.ref});

  @override
  Widget build(BuildContext context) {
    final severity = alert['severity'] as String? ?? 'MEDIUM';
    final color = switch (severity) {
      'HIGH' => KColors.error,
      'MEDIUM' => KColors.warning,
      'LOW' => KColors.info,
      _ => KColors.draft,
    };
    final icon = switch (severity) {
      'HIGH' => Icons.error,
      'MEDIUM' => Icons.warning_amber,
      _ => Icons.info_outline,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(alert['title'] ?? '', style: KTypography.titleSmall),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(alert['alertType']?.toString().replaceAll('_', ' ') ?? '',
                style: KTypography.bodySmall.copyWith(color: color)),
            if (alert['description'] != null)
              Text(alert['description'], maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: KTypography.bodySmall),
          ],
        ),
        trailing: TextButton(
          onPressed: () async {
            try {
              await ref.read(supplyChainRepositoryProvider).resolveAlert(alert['id']);
              ref.invalidate(_alertListProvider);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ApiErrorParser.message(e))),
                );
              }
            }
          },
          child: const Text('Resolve'),
        ),
      ),
    );
  }
}
