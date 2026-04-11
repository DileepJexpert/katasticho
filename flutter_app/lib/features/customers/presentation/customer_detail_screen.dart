import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/customer_repository.dart';

class CustomerDetailScreen extends ConsumerWidget {
  final String customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Details'),
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: () {}),
          PopupMenuButton<String>(
            onSelected: (v) {},
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: FutureBuilder(
        future: ref.read(customerRepositoryProvider).getCustomer(customerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const KLoading();
          }
          if (snapshot.hasError) {
            return KErrorView(message: 'Failed to load customer');
          }

          final data = snapshot.data!;
          final customer = (data['data'] ?? data) as Map<String, dynamic>;
          final name = customer['name'] as String? ?? 'Customer';

          return SingleChildScrollView(
            padding: KSpacing.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor:
                            KColors.primaryLight.withValues(alpha: 0.15),
                        child: Text(
                          name[0].toUpperCase(),
                          style: KTypography.displayLarge
                              .copyWith(color: KColors.primary),
                        ),
                      ),
                      KSpacing.vGapMd,
                      Text(name, style: KTypography.h1),
                    ],
                  ),
                ),
                KSpacing.vGapLg,

                // Details card
                KCard(
                  title: 'Details',
                  child: Column(
                    children: [
                      KDetailRow(
                          label: 'GSTIN',
                          value: customer['gstin'] as String? ?? '--'),
                      KDetailRow(
                          label: 'PAN',
                          value: customer['pan'] as String? ?? '--'),
                      KDetailRow(
                          label: 'Phone',
                          value: customer['phone'] as String? ?? '--'),
                      KDetailRow(
                          label: 'Email',
                          value: customer['email'] as String? ?? '--'),
                      KDetailRow(
                          label: 'Credit Limit',
                          value: CurrencyFormatter.formatIndian(
                            (customer['creditLimit'] as num?)?.toDouble() ?? 0,
                          )),
                      KDetailRow(
                          label: 'Payment Terms',
                          value:
                              '${customer['paymentTermsDays'] ?? 30} days'),
                    ],
                  ),
                ),
                KSpacing.vGapMd,

                // Address
                KCard(
                  title: 'Billing Address',
                  child: Text(
                    [
                      customer['billingAddressLine1'],
                      customer['billingAddressLine2'],
                      customer['billingCity'],
                      customer['billingState'],
                      customer['billingPincode'],
                    ].where((s) => s != null && s.toString().isNotEmpty).join(', '),
                    style: KTypography.bodyMedium,
                  ),
                ),
                KSpacing.vGapMd,

                // Quick actions
                Text('Quick Actions', style: KTypography.h3),
                KSpacing.vGapSm,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.receipt_long, size: 18),
                      label: const Text('Create Invoice'),
                      onPressed: () {},
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.history, size: 18),
                      label: const Text('View Invoices'),
                      onPressed: () {},
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.assessment, size: 18),
                      label: const Text('Statement'),
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
