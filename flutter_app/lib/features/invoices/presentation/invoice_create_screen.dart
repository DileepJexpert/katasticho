import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../routing/app_router.dart';
import '../data/invoice_repository.dart';

class InvoiceCreateScreen extends ConsumerStatefulWidget {
  const InvoiceCreateScreen({super.key});

  @override
  ConsumerState<InvoiceCreateScreen> createState() =>
      _InvoiceCreateScreenState();
}

class _InvoiceCreateScreenState extends ConsumerState<InvoiceCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isSubmitting = false;
  String? _errorMessage;

  // Customer step
  String? _selectedCustomerId;
  String _customerName = '';

  // Line items
  final List<_LineItem> _lineItems = [_LineItem()];

  // Dates
  DateTime _invoiceDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  String _notes = '';

  double get _subtotal =>
      _lineItems.fold(0, (sum, line) => sum + line.lineTotal);

  double get _totalTax =>
      _lineItems.fold(0, (sum, line) => sum + line.taxAmount);

  double get _grandTotal => _subtotal + _totalTax;

  Future<void> _handleSubmit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(invoiceRepositoryProvider);
      final data = {
        'customerId': _selectedCustomerId,
        'invoiceDate': _invoiceDate.toIso8601String().split('T')[0],
        'dueDate': _dueDate.toIso8601String().split('T')[0],
        'notes': _notes,
        'lines': _lineItems
            .where((l) => l.description.isNotEmpty)
            .map((l) => {
                  'description': l.description,
                  'hsnCode': l.hsnCode,
                  'quantity': l.quantity,
                  'unitPrice': l.unitPrice,
                  'gstRate': l.gstRate,
                  'accountCode': '4000',
                })
            .toList(),
      };

      await repo.createInvoice(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice created successfully')),
        );
        context.go(Routes.invoices);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to create invoice. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Invoice'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go(Routes.invoices),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Step indicator
            Container(
              color: KColors.surface,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StepTab(
                    label: 'Customer',
                    index: 0,
                    current: _currentStep,
                    onTap: () => setState(() => _currentStep = 0),
                  ),
                  _stepConnector(),
                  _StepTab(
                    label: 'Items',
                    index: 1,
                    current: _currentStep,
                    onTap: () => setState(() => _currentStep = 1),
                  ),
                  _stepConnector(),
                  _StepTab(
                    label: 'Review',
                    index: 2,
                    current: _currentStep,
                    onTap: () => setState(() => _currentStep = 2),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(KSpacing.md),
                child: KErrorBanner(
                  message: _errorMessage!,
                  onDismiss: () => setState(() => _errorMessage = null),
                ),
              ),

            // Step content
            Expanded(
              child: SingleChildScrollView(
                padding: KSpacing.pagePadding,
                child: switch (_currentStep) {
                  0 => _buildCustomerStep(),
                  1 => _buildItemsStep(),
                  2 => _buildReviewStep(),
                  _ => const SizedBox(),
                },
              ),
            ),

            // Bottom bar
            Container(
              padding: const EdgeInsets.all(KSpacing.md),
              decoration: BoxDecoration(
                color: KColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    // Total
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Total', style: KTypography.bodySmall),
                        Text(
                          CurrencyFormatter.formatIndian(_grandTotal),
                          style: KTypography.amountLarge,
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (_currentStep > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: KButton(
                          label: 'Back',
                          variant: KButtonVariant.outlined,
                          onPressed: () =>
                              setState(() => _currentStep--),
                        ),
                      ),
                    if (_currentStep < 2)
                      KButton(
                        label: 'Next',
                        onPressed: () {
                          if (_currentStep == 0 &&
                              _selectedCustomerId == null) {
                            setState(() =>
                                _errorMessage = 'Please select a customer');
                            return;
                          }
                          setState(() => _currentStep++);
                        },
                      )
                    else
                      KButton(
                        label: 'Create Invoice',
                        onPressed: _handleSubmit,
                        isLoading: _isSubmitting,
                        icon: Icons.check,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepConnector() {
    return Container(
      width: 32,
      height: 2,
      color: KColors.divider,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  // ── Step 0: Customer Selection ──
  Widget _buildCustomerStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Customer', style: KTypography.h2),
        KSpacing.vGapMd,

        // Customer search/select placeholder
        KTextField(
          label: 'Search customers',
          hint: 'Type customer name...',
          prefixIcon: Icons.search,
          onChanged: (v) {},
        ),
        KSpacing.vGapMd,

        // Placeholder customer list
        Text(
          'Recent Customers',
          style: KTypography.labelLarge.copyWith(color: KColors.textSecondary),
        ),
        KSpacing.vGapSm,

        // Placeholder items — will be wired to customer API
        _CustomerSelectTile(
          name: 'Select a customer from the list',
          gstin: 'Search or browse your customers',
          isSelected: false,
          onTap: () {},
        ),

        KSpacing.vGapLg,
        const Divider(),
        KSpacing.vGapMd,

        // Invoice dates
        Row(
          children: [
            Expanded(
              child: KDatePicker(
                label: 'Invoice Date',
                value: _invoiceDate,
                onChanged: (d) => setState(() => _invoiceDate = d),
              ),
            ),
            KSpacing.hGapMd,
            Expanded(
              child: KDatePicker(
                label: 'Due Date',
                value: _dueDate,
                onChanged: (d) => setState(() => _dueDate = d),
                firstDate: _invoiceDate,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Step 1: Line Items ──
  Widget _buildItemsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Line Items', style: KTypography.h2),
        KSpacing.vGapMd,

        ...List.generate(_lineItems.length, (index) {
          return _LineItemCard(
            item: _lineItems[index],
            index: index,
            onRemove: _lineItems.length > 1
                ? () => setState(() => _lineItems.removeAt(index))
                : null,
            onChanged: () => setState(() {}),
          );
        }),

        KSpacing.vGapMd,
        KButton(
          label: 'Add Line Item',
          icon: Icons.add,
          variant: KButtonVariant.outlined,
          onPressed: () =>
              setState(() => _lineItems.add(_LineItem())),
        ),

        KSpacing.vGapLg,

        // Summary
        KCard(
          child: Column(
            children: [
              _SummaryRow(
                  label: 'Subtotal',
                  value: CurrencyFormatter.formatIndian(_subtotal)),
              _SummaryRow(
                  label: 'Tax',
                  value: CurrencyFormatter.formatIndian(_totalTax)),
              const Divider(),
              _SummaryRow(
                label: 'Grand Total',
                value: CurrencyFormatter.formatIndian(_grandTotal),
                bold: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 2: Review ──
  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review Invoice', style: KTypography.h2),
        KSpacing.vGapMd,

        KCard(
          title: 'Customer',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _customerName.isEmpty ? 'Selected Customer' : _customerName,
                style: KTypography.bodyLarge,
              ),
              KSpacing.vGapSm,
              KDetailRow(
                label: 'Invoice Date',
                value: DateFormatter.display(_invoiceDate),
              ),
              KDetailRow(
                label: 'Due Date',
                value: DateFormatter.display(_dueDate),
              ),
            ],
          ),
        ),
        KSpacing.vGapMd,

        KCard(
          title: 'Items (${_lineItems.length})',
          child: Column(
            children: _lineItems.asMap().entries.map((entry) {
              final item = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.description.isEmpty
                                ? 'Item ${entry.key + 1}'
                                : item.description,
                            style: KTypography.bodyMedium,
                          ),
                          Text(
                            '${item.quantity} x ${CurrencyFormatter.formatIndian(item.unitPrice)}',
                            style: KTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatIndian(item.lineTotal),
                      style: KTypography.amountSmall,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        KSpacing.vGapMd,

        KCard(
          child: Column(
            children: [
              _SummaryRow(
                  label: 'Subtotal',
                  value: CurrencyFormatter.formatIndian(_subtotal)),
              _SummaryRow(
                  label: 'GST',
                  value: CurrencyFormatter.formatIndian(_totalTax)),
              const Divider(),
              _SummaryRow(
                label: 'Total',
                value: CurrencyFormatter.formatIndian(_grandTotal),
                bold: true,
              ),
            ],
          ),
        ),

        KSpacing.vGapMd,
        KTextField(
          label: 'Notes (optional)',
          hint: 'Add any notes for this invoice',
          maxLines: 3,
          initialValue: _notes,
          onChanged: (v) => _notes = v,
        ),
      ],
    );
  }
}

// ── Helper Widgets ──

class _LineItem {
  String description = '';
  String hsnCode = '';
  double quantity = 1;
  double unitPrice = 0;
  double gstRate = 18;

  double get taxableAmount => quantity * unitPrice;
  double get taxAmount => taxableAmount * gstRate / 100;
  double get lineTotal => taxableAmount + taxAmount;
}

class _LineItemCard extends StatelessWidget {
  final _LineItem item;
  final int index;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  const _LineItemCard({
    required this.item,
    required this.index,
    this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Item ${index + 1}', style: KTypography.labelLarge),
              const Spacer(),
              if (onRemove != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: KColors.error, size: 20),
                  onPressed: onRemove,
                ),
            ],
          ),
          KSpacing.vGapSm,
          KTextField(
            label: 'Description',
            initialValue: item.description,
            onChanged: (v) {
              item.description = v;
              onChanged();
            },
          ),
          KSpacing.vGapSm,
          Row(
            children: [
              Expanded(
                child: KTextField(
                  label: 'HSN Code',
                  initialValue: item.hsnCode,
                  onChanged: (v) {
                    item.hsnCode = v;
                    onChanged();
                  },
                ),
              ),
              KSpacing.hGapSm,
              Expanded(
                child: KTextField(
                  label: 'Quantity',
                  initialValue: item.quantity.toString(),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) {
                    item.quantity = double.tryParse(v) ?? 1;
                    onChanged();
                  },
                ),
              ),
            ],
          ),
          KSpacing.vGapSm,
          Row(
            children: [
              Expanded(
                child: KTextField.amount(
                  label: 'Unit Price',
                  onChanged: (v) {
                    item.unitPrice = double.tryParse(v) ?? 0;
                    onChanged();
                  },
                ),
              ),
              KSpacing.hGapSm,
              Expanded(
                child: DropdownButtonFormField<double>(
                  value: item.gstRate,
                  decoration: const InputDecoration(
                    labelText: 'GST Rate',
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('0%')),
                    DropdownMenuItem(value: 5, child: Text('5%')),
                    DropdownMenuItem(value: 12, child: Text('12%')),
                    DropdownMenuItem(value: 18, child: Text('18%')),
                    DropdownMenuItem(value: 28, child: Text('28%')),
                  ],
                  onChanged: (v) {
                    item.gstRate = v ?? 18;
                    onChanged();
                  },
                ),
              ),
            ],
          ),
          KSpacing.vGapSm,
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Line Total: ${CurrencyFormatter.formatIndian(item.lineTotal)}',
                style: KTypography.amountSmall.copyWith(
                  color: KColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CustomerSelectTile extends StatelessWidget {
  final String name;
  final String gstin;
  final bool isSelected;
  final VoidCallback onTap;

  const _CustomerSelectTile({
    required this.name,
    required this.gstin,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: KSpacing.borderRadiusMd,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? KColors.primary.withValues(alpha: 0.06)
              : KColors.surface,
          borderRadius: KSpacing.borderRadiusMd,
          border: Border.all(
            color: isSelected ? KColors.primary : KColors.divider,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: KColors.primaryLight.withValues(alpha: 0.15),
              child: Icon(
                Icons.person,
                color: KColors.primary,
              ),
            ),
            KSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: KTypography.bodyMedium),
                  Text(gstin, style: KTypography.bodySmall),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: KColors.primary),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: bold ? KTypography.labelLarge : KTypography.bodyMedium,
          ),
          Text(
            value,
            style: bold ? KTypography.amountMedium : KTypography.amountSmall,
          ),
        ],
      ),
    );
  }
}

class _StepTab extends StatelessWidget {
  final String label;
  final int index;
  final int current;
  final VoidCallback onTap;

  const _StepTab({
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    final isCompleted = index < current;

    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isActive || isCompleted
                  ? KColors.primary
                  : KColors.divider,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: isActive ? Colors.white : KColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
            ),
          ),
          KSpacing.hGapXs,
          Text(
            label,
            style: KTypography.labelMedium.copyWith(
              color: isActive ? KColors.primary : KColors.textSecondary,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Import DateFormatter for review step
class DateFormatter {
  static String display(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')} '
        '${_months[date.month - 1]} '
        '${date.year}';
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}
