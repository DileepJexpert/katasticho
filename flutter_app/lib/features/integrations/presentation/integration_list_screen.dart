import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/api_error_parser.dart';
import '../data/integration_repository.dart';

final _integrationsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) {
  return ref.watch(integrationRepositoryProvider).listIntegrations();
});

class IntegrationListScreen extends ConsumerWidget {
  const IntegrationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(_integrationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Integrations')),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
        data: (integrations) {
          if (integrations.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.extension_outlined,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: KSpacing.md),
                  const Text('No integrations configured'),
                  const SizedBox(height: KSpacing.sm),
                  const Text(
                    'Integrations connect your ERP with external services',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_integrationsProvider),
            child: ListView.builder(
              padding: KSpacing.screenPadding,
              itemCount: integrations.length,
              itemBuilder: (_, i) {
                final integration = integrations[i] as Map<String, dynamic>;
                return _IntegrationCard(integration: integration, ref: ref);
              },
            ),
          );
        },
      ),
    );
  }
}

class _IntegrationCard extends StatefulWidget {
  final Map<String, dynamic> integration;
  final WidgetRef ref;
  const _IntegrationCard({required this.integration, required this.ref});

  @override
  State<_IntegrationCard> createState() => _IntegrationCardState();
}

class _IntegrationCardState extends State<_IntegrationCard> {
  bool _testingConnection = false;
  bool _syncing = false;

  @override
  Widget build(BuildContext context) {
    final integration = widget.integration;
    final status = integration['status'] as String? ?? 'INACTIVE';
    final syncStatus = integration['lastSyncStatus'] as String?;
    final isEnabled = integration['enabled'] as bool? ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _integrationIcon(integration['type'] as String? ?? ''),
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: KSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        integration['name'] as String? ?? 'Integration',
                        style: KTypography.titleSmall,
                      ),
                      Text(
                        integration['type'] as String? ?? '',
                        style: KTypography.bodySmall,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isEnabled,
                  onChanged: (v) => _toggle(context, v),
                ),
              ],
            ),
            const SizedBox(height: KSpacing.sm),
            Row(
              children: [
                KStatusChip(status: status),
                if (syncStatus != null) ...[
                  const SizedBox(width: KSpacing.xs),
                  KStatusChip(status: syncStatus),
                ],
              ],
            ),
            if (integration['lastSyncAt'] != null) ...[
              const SizedBox(height: 4),
              Text(
                'Last synced: ${integration['lastSyncAt']}',
                style: KTypography.bodySmall,
              ),
            ],
            const SizedBox(height: KSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _testingConnection ? null : _testConnection,
                  icon: _testingConnection
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cable_outlined, size: 16),
                  label: const Text('Test'),
                ),
                const SizedBox(width: KSpacing.sm),
                FilledButton.icon(
                  onPressed: _syncing ? null : _sync,
                  icon: _syncing
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.sync_outlined, size: 16),
                  label: const Text('Sync'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _integrationIcon(String type) {
    return switch (type.toUpperCase()) {
      'TALLY' => Icons.account_balance_outlined,
      'SHOPIFY' => Icons.storefront_outlined,
      'WOOCOMMERCE' => Icons.shopping_bag_outlined,
      'AMAZON' => Icons.local_mall_outlined,
      'FLIPKART' => Icons.phone_android_outlined,
      'ZOHO' => Icons.hub_outlined,
      'QUICKBOOKS' => Icons.receipt_long_outlined,
      'RAZORPAY' || 'STRIPE' => Icons.payment_outlined,
      'SHIPROCKET' || 'DELHIVERY' => Icons.local_shipping_outlined,
      _ => Icons.extension_outlined,
    };
  }

  Future<void> _testConnection() async {
    setState(() => _testingConnection = true);
    final id = widget.integration['id'] as String? ?? '';
    try {
      final result =
          await widget.ref.read(integrationRepositoryProvider).testConnection(id);
      if (mounted) {
        final success = result['success'] as bool? ?? false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Connection successful'
                : (result['message'] as String? ?? 'Connection failed')),
            backgroundColor: success ? KColors.success : KColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(ApiErrorParser.message(e)),
              backgroundColor: KColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _testingConnection = false);
    }
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    final id = widget.integration['id'] as String? ?? '';
    try {
      await widget.ref.read(integrationRepositoryProvider).syncIntegration(id);
      widget.ref.invalidate(_integrationsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync started')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(ApiErrorParser.message(e)),
              backgroundColor: KColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _toggle(BuildContext context, bool enabled) async {
    final id = widget.integration['id'] as String? ?? '';
    try {
      await widget.ref
          .read(integrationRepositoryProvider)
          .toggleIntegration(id, enabled);
      widget.ref.invalidate(_integrationsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(ApiErrorParser.message(e)),
              backgroundColor: KColors.error),
        );
      }
    }
  }
}
