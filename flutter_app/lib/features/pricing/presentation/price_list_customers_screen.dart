import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../contacts/presentation/contact_picker_sheet.dart';
import '../data/price_list_repository.dart';

/// Assign customers to a price list. The price resolver already honours
/// `contact.defaultPriceListId`; this screen is the only place that sets it.
/// A customer pinned here gets this list's tiered prices on every SO/invoice.
class PriceListCustomersScreen extends ConsumerWidget {
  final String listId;
  final String? listName;

  const PriceListCustomersScreen({
    super.key,
    required this.listId,
    this.listName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(priceListCustomersProvider(listId));

    return Scaffold(
      appBar: AppBar(
        title: Text(listName == null
            ? 'Price List Customers'
            : '$listName · Customers'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _assign(context, ref),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Assign customer'),
      ),
      body: customersAsync.when(
        loading: () => const KLoading(),
        error: (e, _) => KErrorView(
          message: 'Failed to load customers',
          onRetry: () => ref.invalidate(priceListCustomersProvider(listId)),
        ),
        data: (customers) {
          if (customers.isEmpty) {
            return KEmptyState(
              icon: Icons.group_outlined,
              title: 'No customers on this list',
              subtitle:
                  'Assign customers so they get this price list\'s tiered '
                  'rates automatically on every sales order and invoice.',
              actionLabel: 'Assign customer',
              onAction: () => _assign(context, ref),
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(priceListCustomersProvider(listId)),
            child: ListView.separated(
              padding: KSpacing.pagePadding,
              itemCount: customers.length,
              separatorBuilder: (_, __) => KSpacing.vGapSm,
              itemBuilder: (_, i) => _customerCard(context, ref, customers[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _customerCard(
      BuildContext context, WidgetRef ref, Map<String, dynamic> c) {
    final name = c['displayName']?.toString() ?? '—';
    final phone = c['phone']?.toString() ?? '';
    final type = c['contactType']?.toString() ?? '';
    return KCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: KTypography.labelLarge),
                if (phone.isNotEmpty) ...[
                  KSpacing.vGapXs,
                  Text(phone,
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textSecondary)),
                ],
              ],
            ),
          ),
          if (type == 'BOTH')
            Padding(
              padding: const EdgeInsets.only(right: KSpacing.sm),
              child: KStatusChip(status: 'Customer + Vendor'),
            ),
          IconButton(
            tooltip: 'Remove from list',
            icon: const Icon(Icons.link_off, color: KColors.error),
            onPressed: () => _unassign(context, ref, c['id'].toString(), name),
          ),
        ],
      ),
    );
  }

  Future<void> _assign(BuildContext context, WidgetRef ref) async {
    final contact = await showContactPicker(
      context,
      contactType: 'CUSTOMER',
      title: 'Assign a customer',
    );
    if (contact == null) return;
    if (!context.mounted) return;
    final id = contact['id']?.toString();
    if (id == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(priceListRepositoryProvider).assignCustomer(listId, id);
      ref.invalidate(priceListCustomersProvider(listId));
      messenger.showSnackBar(SnackBar(
          content: Text('${contact['displayName'] ?? 'Customer'} assigned')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(
              'Could not assign: ${e.toString().replaceAll('Exception: ', '')}')));
    }
  }

  Future<void> _unassign(BuildContext context, WidgetRef ref, String contactId,
      String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from price list'),
        content: Text(
            'Remove "$name" from this price list? They\'ll fall back to the '
            'org default list (or item prices).'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: KColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(priceListRepositoryProvider)
          .unassignCustomer(listId, contactId);
      ref.invalidate(priceListCustomersProvider(listId));
      messenger.showSnackBar(const SnackBar(content: Text('Removed')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not remove: $e')));
    }
  }
}
