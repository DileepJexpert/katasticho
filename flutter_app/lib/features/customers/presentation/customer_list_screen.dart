import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../pricing/data/price_list_repository.dart';
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
        loading: () {
          debugPrint('[CustomerListScreen] Loading customers...');
          return const KShimmerList();
        },
        error: (err, st) {
          debugPrint('[CustomerListScreen] ERROR loading customers: $err');
          debugPrint('[CustomerListScreen] Stack trace: $st');
          return KErrorView(
            message: 'Failed to load customers',
            onRetry: () => ref.invalidate(customerListProvider),
          );
        },
        data: (data) {
          debugPrint('[CustomerListScreen] Raw data received: $data');
          final content = data['data'];
          debugPrint('[CustomerListScreen] content = $content (type: ${content.runtimeType})');
          final customers = content is List
              ? content
              : (content is Map ? (content['content'] as List?) ?? [] : []);
          debugPrint('[CustomerListScreen] Parsed ${customers.length} customers');

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
        child: const _AddCustomerSheetBody(),
      ),
    );
  }
}

/// Body of the Add Customer modal. Broken out as a ConsumerStatefulWidget
/// so the "Default Price List" dropdown can watch [priceListsProvider]
/// and so selecting a list survives rebuilds.
class _AddCustomerSheetBody extends ConsumerStatefulWidget {
  const _AddCustomerSheetBody();

  @override
  ConsumerState<_AddCustomerSheetBody> createState() =>
      _AddCustomerSheetBodyState();
}

class _AddCustomerSheetBodyState extends ConsumerState<_AddCustomerSheetBody> {
  final _nameController = TextEditingController();
  final _gstinController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  String? _defaultPriceListId;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _gstinController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final priceListsAsync = ref.watch(priceListsProvider);
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add Customer', style: KTypography.h2),
          KSpacing.vGapMd,
          KTextField(
            label: 'Customer Name',
            controller: _nameController,
            prefixIcon: Icons.person_outline,
          ),
          KSpacing.vGapMd,
          KTextField(
            label: 'Phone Number',
            controller: _phoneController,
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          KSpacing.vGapMd,
          KTextField(
            label: 'Email',
            controller: _emailController,
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          KSpacing.vGapMd,
          KTextField(
            label: 'GSTIN (Optional)',
            controller: _gstinController,
            prefixIcon: Icons.receipt_long_outlined,
          ),
          KSpacing.vGapMd,
          // Default price list picker — drives the F3 resolver at
          // invoice-create time. Null means "use org default list".
          priceListsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (err, st) {
              debugPrint('[AddCustomer] priceLists ERROR: $err');
              return const SizedBox.shrink();
            },
            data: (lists) {
              if (lists.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: KColors.primary.withValues(alpha: 0.06),
                    borderRadius: KSpacing.borderRadiusMd,
                    border: Border.all(
                        color: KColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sell_outlined,
                          size: 16, color: KColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No price lists yet — this customer will be '
                          'priced from item master.',
                          style: KTypography.bodySmall,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return DropdownButtonFormField<String?>(
                value: _defaultPriceListId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Default Price List (Optional)',
                  prefixIcon: Icon(Icons.sell_outlined),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('— Use org default —'),
                  ),
                  ...lists.map((l) {
                    final id = l['id']?.toString();
                    final name = l['name']?.toString() ?? 'Unnamed';
                    final isDefault = l['isDefault'] == true;
                    return DropdownMenuItem<String?>(
                      value: id,
                      child: Text(isDefault ? '$name (default)' : name,
                          overflow: TextOverflow.ellipsis),
                    );
                  }),
                ],
                onChanged: (v) => setState(() => _defaultPriceListId = v),
              );
            },
          ),
          KSpacing.vGapLg,
          KButton(
            label: 'Add Customer',
            fullWidth: true,
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
          KSpacing.vGapMd,
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final customerData = <String, dynamic>{
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
      'gstin': _gstinController.text.trim(),
      'defaultPriceListId': _defaultPriceListId,
    };
    debugPrint('[AddCustomer] creating: $customerData');
    try {
      final repo = ref.read(customerRepositoryProvider);
      await repo.createCustomer(customerData);
      ref.invalidate(customerListProvider);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e, st) {
      debugPrint('[AddCustomer] FAILED: $e\n$st');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add customer')),
      );
    }
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
