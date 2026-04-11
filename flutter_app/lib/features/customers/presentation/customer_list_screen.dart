import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/customer_repository.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
        ],
      ),
      body: customersAsync.when(
        loading: () => const KShimmerList(),
        error: (err, _) => KErrorView(
          message: 'Failed to load customers',
          onRetry: () => ref.invalidate(customerListProvider),
        ),
        data: (data) {
          final content = data['data'];
          final customers = content is List
              ? content
              : (content is Map ? (content['content'] as List?) ?? [] : []);

          if (customers.isEmpty) {
            return KEmptyState(
              icon: Icons.people_outline,
              title: 'No customers yet',
              subtitle: 'Add your first customer to start invoicing',
              actionLabel: 'Add Customer',
              onAction: () => _showAddCustomerSheet(context),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(customerListProvider),
            child: ListView.separated(
              padding: KSpacing.pagePadding,
              itemCount: customers.length,
              separatorBuilder: (_, __) => KSpacing.vGapSm,
              itemBuilder: (context, index) {
                final customer = customers[index] as Map<String, dynamic>;
                return _CustomerCard(customer: customer);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCustomerSheet(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Customer'),
      ),
    );
  }

  void _showAddCustomerSheet(BuildContext context) {
    final nameController = TextEditingController();
    final gstinController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: KSpacing.md,
          right: KSpacing.md,
          top: KSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add Customer', style: KTypography.h2),
              KSpacing.vGapMd,
              KTextField(
                label: 'Customer Name',
                controller: nameController,
                prefixIcon: Icons.person_outline,
              ),
              KSpacing.vGapMd,
              KTextField(
                label: 'Phone Number',
                controller: phoneController,
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              KSpacing.vGapMd,
              KTextField(
                label: 'Email',
                controller: emailController,
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              KSpacing.vGapMd,
              KTextField(
                label: 'GSTIN (Optional)',
                controller: gstinController,
                prefixIcon: Icons.receipt_long_outlined,
              ),
              KSpacing.vGapLg,
              KButton(
                label: 'Add Customer',
                fullWidth: true,
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    final repo = ref.read(customerRepositoryProvider);
                    await repo.createCustomer({
                      'name': nameController.text.trim(),
                      'phone': phoneController.text.trim(),
                      'email': emailController.text.trim(),
                      'gstin': gstinController.text.trim(),
                    });
                    ref.invalidate(customerListProvider);
                  } catch (_) {}
                },
              ),
              KSpacing.vGapMd,
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final Map<String, dynamic> customer;

  const _CustomerCard({required this.customer});

  @override
  Widget build(BuildContext context) {
    final name = customer['name'] as String? ?? 'Unknown';
    final gstin = customer['gstin'] as String? ?? '';
    final outstandingBalance =
        (customer['outstandingBalance'] as num?)?.toDouble() ?? 0;

    return KCard(
      onTap: () {
        final id = customer['id']?.toString();
        if (id != null) context.go('/customers/$id');
      },
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: KColors.primaryLight.withValues(alpha: 0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: KTypography.h3.copyWith(color: KColors.primary),
            ),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: KTypography.labelLarge),
                if (gstin.isNotEmpty) ...[
                  KSpacing.vGapXs,
                  Text(
                    'GSTIN: $gstin',
                    style: KTypography.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (outstandingBalance > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.formatIndian(outstandingBalance),
                  style: KTypography.amountSmall.copyWith(
                    color: KColors.warning,
                  ),
                ),
                Text('Outstanding', style: KTypography.labelSmall),
              ],
            ),
          KSpacing.hGapSm,
          const Icon(Icons.chevron_right, color: KColors.textHint),
        ],
      ),
    );
  }
}
