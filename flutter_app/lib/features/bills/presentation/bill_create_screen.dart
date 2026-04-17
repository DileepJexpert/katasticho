import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../routing/app_router.dart';
import '../../contacts/data/contact_repository.dart';
import '../../tax_groups/data/tax_group_repository.dart';
import '../../tax_groups/presentation/widgets/tax_group_picker.dart';
import '../data/bill_repository.dart';

class BillCreateScreen extends ConsumerStatefulWidget {
  const BillCreateScreen({super.key});

  @override
  ConsumerState<BillCreateScreen> createState() => _BillCreateScreenState();
}

class _BillCreateScreenState extends ConsumerState<BillCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isSubmitting = false;
  String? _errorMessage;

  // Vendor step
  String? _selectedContactId;
  String _vendorName = '';
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _filteredContacts = [];
  bool _loadingContacts = true;

  // Bill metadata
  String _vendorBillNumber = '';
  DateTime _billDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  String _placeOfSupply = '';
  bool _reverseCharge = false;
  String _notes = '';

  // Line items
  final List<_BillLineItem> _lineItems = [_BillLineItem()];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final repo = ref.read(contactRepositoryProvider);
      // Load vendors (type=VENDOR) and dual-type contacts (type=BOTH)
      final result = await repo.listContacts(size: 200);
      final content = result['data'];
      final list = content is List
          ? content.cast<Map<String, dynamic>>()
          : (content is Map
              ? ((content['content'] as List?)
                      ?.cast<Map<String, dynamic>>() ??
                  [])
              : <Map<String, dynamic>>[]);
      // Filter to vendor-type contacts
      final vendors = list
          .where((c) {
            final type = (c['contactType'] as String? ?? '').toUpperCase();
            return type == 'VENDOR' || type == 'BOTH';
          })
          .toList();
      if (mounted) {
        setState(() {
          _contacts = vendors;
          _filteredContacts = vendors;
          _loadingContacts = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingContacts = false);
    }
  }

  void _filterContacts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = _contacts;
      } else {
        final lower = query.toLowerCase();
        _filteredContacts = _contacts
            .where((c) =>
                (c['name'] as String? ?? '').toLowerCase().contains(lower) ||
                (c['companyName'] as String? ?? '')
                    .toLowerCase()
                    .contains(lower) ||
                (c['gstin'] as String? ?? '').toLowerCase().contains(lower))
            .toList();
      }
    });
  }

  double get _subtotal =>
      _lineItems.fold(0, (sum, line) => sum + line.taxableAmount);

  double get _totalTax =>
      _lineItems.fold(0, (sum, line) => sum + line.taxAmount);

  double get _grandTotal => _subtotal + _totalTax;

  Future<void> _handleSubmit() async {
    final validLines = _lineItems
        .where((l) => l.description.isNotEmpty || l.unitPrice > 0)
        .toList();
    if (validLines.isEmpty) {
      setState(() => _errorMessage = 'Please add at least one line item with a description or price');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(billRepositoryProvider);
      final data = {
        'contactId': _selectedContactId,
        'vendorBillNumber': _vendorBillNumber,
        'billDate': _billDate.toIso8601String().split('T')[0],
        'dueDate': _dueDate.toIso8601String().split('T')[0],
        'placeOfSupply': _placeOfSupply,
        'reverseCharge': _reverseCharge,
        'notes': _notes,
        'lines': _lineItems
            .where((l) => l.description.isNotEmpty || l.unitPrice > 0)
            .map((l) => {
                  'description': l.description.isNotEmpty ? l.description : 'Line item',
                  'quantity': l.quantity,
                  'unitPrice': l.unitPrice,
                  'accountCode': l.accountCode,
                  'gstRate': l.taxRate,
                  if (l.taxGroupId != null) 'taxGroupId': l.taxGroupId,
                  if (l.itemId != null) 'itemId': l.itemId,
                })
            .toList(),
      };

      await repo.createBill(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill created successfully')),
        );
        context.go(Routes.bills);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e is DioException
            ? ApiErrorParser.message(e)
            : 'Failed to create bill. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Bill'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go(Routes.bills),
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
                    label: 'Vendor',
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
                  0 => _buildVendorStep(),
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
                              _selectedContactId == null) {
                            setState(() =>
                                _errorMessage = 'Please select a vendor');
                            return;
                          }
                          setState(() => _currentStep++);
                        },
                      )
                    else
                      KButton(
                        label: 'Create Bill',
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

  // ── Step 0: Vendor Selection ──
  Widget _buildVendorStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Vendor', style: KTypography.h2),
        KSpacing.vGapMd,

        KTextField(
          label: 'Search vendors',
          hint: 'Type vendor name, company or GSTIN...',
          prefixIcon: Icons.search,
          onChanged: _filterContacts,
        ),
        KSpacing.vGapMd,

        Text(
          'Your Vendors',
          style: KTypography.labelLarge.copyWith(color: KColors.textSecondary),
        ),
        KSpacing.vGapSm,

        if (_loadingContacts)
          const Center(
              child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ))
        else if (_filteredContacts.isEmpty)
          _VendorSelectTile(
            name: _contacts.isEmpty
                ? 'No vendors yet'
                : 'No matching vendors',
            subtitle: _contacts.isEmpty
                ? 'Add vendor contacts first'
                : 'Try a different search term',
            isSelected: false,
            onTap: () {},
          )
        else
          ..._filteredContacts.map((contact) {
            final id = contact['id']?.toString() ?? '';
            final name = contact['displayName'] as String? ??
                contact['companyName'] as String? ??
                'Unknown';
            final gstin = contact['gstin'] as String? ?? '';
            final companyName = contact['companyName'] as String? ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _VendorSelectTile(
                name: name,
                subtitle: gstin.isNotEmpty
                    ? 'GSTIN: $gstin'
                    : (companyName.isNotEmpty ? companyName : 'Vendor'),
                isSelected: _selectedContactId == id,
                onTap: () {
                  setState(() {
                    _selectedContactId = id;
                    _vendorName = name;
                  });
                },
              ),
            );
          }),

        KSpacing.vGapLg,
        const Divider(),
        KSpacing.vGapMd,

        // Bill metadata
        KTextField(
          label: 'Vendor Bill Number',
          hint: 'e.g. INV-2026-001',
          initialValue: _vendorBillNumber,
          onChanged: (v) => _vendorBillNumber = v,
        ),
        KSpacing.vGapMd,
        Row(
          children: [
            Expanded(
              child: KDatePicker(
                label: 'Bill Date',
                value: _billDate,
                onChanged: (d) => setState(() => _billDate = d),
              ),
            ),
            KSpacing.hGapMd,
            Expanded(
              child: KDatePicker(
                label: 'Due Date',
                value: _dueDate,
                onChanged: (d) => setState(() => _dueDate = d),
                firstDate: _billDate,
              ),
            ),
          ],
        ),
        KSpacing.vGapMd,
        KTextField(
          label: 'Place of Supply',
          hint: 'e.g. Maharashtra',
          initialValue: _placeOfSupply,
          onChanged: (v) => _placeOfSupply = v,
        ),
        KSpacing.vGapMd,
        SwitchListTile(
          title: const Text('Reverse Charge'),
          subtitle: const Text('Applicable under RCM'),
          value: _reverseCharge,
          onChanged: (v) => setState(() => _reverseCharge = v),
          contentPadding: EdgeInsets.zero,
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
          return _BillLineItemCard(
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
              setState(() => _lineItems.add(_BillLineItem())),
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
        Text('Review Bill', style: KTypography.h2),
        KSpacing.vGapMd,

        KCard(
          title: 'Vendor',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _vendorName.isEmpty ? 'Selected Vendor' : _vendorName,
                style: KTypography.bodyLarge,
              ),
              KSpacing.vGapSm,
              if (_vendorBillNumber.isNotEmpty)
                KDetailRow(
                  label: 'Vendor Bill #',
                  value: _vendorBillNumber,
                ),
              KDetailRow(
                label: 'Bill Date',
                value: DateFormatter.display(_billDate),
              ),
              KDetailRow(
                label: 'Due Date',
                value: DateFormatter.display(_dueDate),
              ),
              if (_placeOfSupply.isNotEmpty)
                KDetailRow(
                  label: 'Place of Supply',
                  value: _placeOfSupply,
                ),
              if (_reverseCharge)
                const KDetailRow(
                  label: 'Reverse Charge',
                  value: 'Yes',
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
                  label: 'Tax',
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
          hint: 'Add any notes for this bill',
          maxLines: 3,
          initialValue: _notes,
          onChanged: (v) => _notes = v,
        ),
      ],
    );
  }
}

// ── Helper Classes & Widgets ──

class _BillLineItem {
  String? itemId;
  String description = '';
  double quantity = 1;
  double unitPrice = 0;
  double taxRate = 18;
  String? taxGroupId;
  String accountCode = '5000'; // default expense account

  double get taxableAmount => quantity * unitPrice;
  double get taxAmount => taxableAmount * taxRate / 100;
  double get lineTotal => taxableAmount + taxAmount;
}

class _BillLineItemCard extends StatefulWidget {
  final _BillLineItem item;
  final int index;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  const _BillLineItemCard({
    required this.item,
    required this.index,
    this.onRemove,
    required this.onChanged,
  });

  @override
  State<_BillLineItemCard> createState() => _BillLineItemCardState();
}

class _BillLineItemCardState extends State<_BillLineItemCard> {
  late final TextEditingController _descCtl;
  late final TextEditingController _qtyCtl;
  late final TextEditingController _priceCtl;

  @override
  void initState() {
    super.initState();
    _descCtl = TextEditingController(text: widget.item.description);
    _qtyCtl = TextEditingController(text: widget.item.quantity.toString());
    _priceCtl = TextEditingController(text: widget.item.unitPrice.toString());
  }

  @override
  void dispose() {
    _descCtl.dispose();
    _qtyCtl.dispose();
    _priceCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KCard(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Item ${widget.index + 1}', style: KTypography.labelLarge),
              const Spacer(),
              if (widget.onRemove != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: KColors.error, size: 20),
                  onPressed: widget.onRemove,
                ),
            ],
          ),
          KSpacing.vGapSm,
          KTextField(
            label: 'Description',
            controller: _descCtl,
            onChanged: (v) {
              widget.item.description = v;
              widget.onChanged();
            },
          ),
          KSpacing.vGapSm,
          Row(
            children: [
              Expanded(
                child: KTextField(
                  label: 'Quantity',
                  controller: _qtyCtl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) {
                    widget.item.quantity = double.tryParse(v) ?? 1;
                    widget.onChanged();
                  },
                ),
              ),
              KSpacing.hGapSm,
              Expanded(
                child: KTextField.amount(
                  label: 'Unit Price',
                  controller: _priceCtl,
                  onChanged: (v) {
                    widget.item.unitPrice = double.tryParse(v) ?? 0;
                    widget.onChanged();
                  },
                ),
              ),
            ],
          ),
          KSpacing.vGapSm,
          TaxGroupPicker(
            value: widget.item.taxGroupId,
            label: 'Tax Group',
            onChanged: (group) {
              widget.item.taxGroupId = group?.id;
              widget.item.taxRate = group?.totalRate ?? 0;
              widget.onChanged();
            },
          ),
          KSpacing.vGapSm,
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Line Total: ${CurrencyFormatter.formatIndian(widget.item.lineTotal)}',
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

class _VendorSelectTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _VendorSelectTile({
    required this.name,
    required this.subtitle,
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
              child: const Icon(
                Icons.store,
                color: KColors.primary,
              ),
            ),
            KSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: KTypography.bodyMedium),
                  Text(subtitle, style: KTypography.bodySmall),
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
