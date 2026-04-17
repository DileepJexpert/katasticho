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
import '../../tax_groups/presentation/widgets/tax_group_picker.dart';
import '../data/vendor_credit_repository.dart';

class VendorCreditCreateScreen extends ConsumerStatefulWidget {
  const VendorCreditCreateScreen({super.key});

  @override
  ConsumerState<VendorCreditCreateScreen> createState() =>
      _VendorCreditCreateScreenState();
}

class _VendorCreditCreateScreenState
    extends ConsumerState<VendorCreditCreateScreen> {
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

  // Credit metadata
  DateTime _creditDate = DateTime.now();
  String _reason = '';
  String _placeOfSupply = '';
  String _purchaseBillId = '';

  // Line items
  final List<_CreditLineItem> _lineItems = [_CreditLineItem()];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final repo = ref.read(contactRepositoryProvider);
      final result = await repo.listContacts(size: 200);
      final content = result['data'];
      final list = content is List
          ? content.cast<Map<String, dynamic>>()
          : (content is Map
              ? ((content['content'] as List?)
                      ?.cast<Map<String, dynamic>>() ??
                  [])
              : <Map<String, dynamic>>[]);
      final vendors = list.where((c) {
        final type = (c['contactType'] as String? ?? '').toUpperCase();
        return type == 'VENDOR' || type == 'BOTH';
      }).toList();
      if (mounted) {
        setState(() {
          _contacts = vendors;
          _filteredContacts = vendors;
          _loadingContacts = false;
        });
      }
    } catch (_) {
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
                (c['name'] as String? ?? '')
                    .toLowerCase()
                    .contains(lower) ||
                (c['companyName'] as String? ?? '')
                    .toLowerCase()
                    .contains(lower) ||
                (c['gstin'] as String? ?? '')
                    .toLowerCase()
                    .contains(lower))
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
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(vendorCreditRepositoryProvider);
      final data = {
        'contactId': _selectedContactId,
        'creditDate': _creditDate.toIso8601String().split('T')[0],
        if (_purchaseBillId.isNotEmpty) 'purchaseBillId': _purchaseBillId,
        if (_reason.isNotEmpty) 'reason': _reason,
        if (_placeOfSupply.isNotEmpty) 'placeOfSupply': _placeOfSupply,
        'lines': _lineItems
            .where((l) => l.description.isNotEmpty)
            .map((l) => {
                  'description': l.description,
                  if (l.hsnCode.isNotEmpty) 'hsnCode': l.hsnCode,
                  if (l.itemId != null) 'itemId': l.itemId,
                  if (l.accountId.isNotEmpty) 'accountId': l.accountId,
                  'quantity': l.quantity,
                  'unitPrice': l.unitPrice,
                  'gstRate': l.gstRate,
                  if (l.taxGroupId != null) 'taxGroupId': l.taxGroupId,
                })
            .toList(),
      };

      await repo.createCredit(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Vendor credit created successfully')),
        );
        context.go(Routes.vendorCredits);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e is DioException
            ? ApiErrorParser.message(e)
            : 'Failed to create vendor credit. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Vendor Credit'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go(Routes.vendorCredits),
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
                    label: 'Lines',
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
                  onDismiss: () =>
                      setState(() => _errorMessage = null),
                ),
              ),

            // Step content
            Expanded(
              child: SingleChildScrollView(
                padding: KSpacing.pagePadding,
                child: switch (_currentStep) {
                  0 => _buildVendorStep(),
                  1 => _buildLinesStep(),
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
                            setState(() => _errorMessage =
                                'Please select a vendor');
                            return;
                          }
                          setState(() => _currentStep++);
                        },
                      )
                    else
                      KButton(
                        label: 'Create Credit',
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
          style: KTypography.labelLarge
              .copyWith(color: KColors.textSecondary),
        ),
        KSpacing.vGapSm,

        if (_loadingContacts)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
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
            final companyName =
                contact['companyName'] as String? ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _VendorSelectTile(
                name: name,
                subtitle: gstin.isNotEmpty
                    ? 'GSTIN: $gstin'
                    : (companyName.isNotEmpty
                        ? companyName
                        : 'Vendor'),
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

        // Credit metadata
        KDatePicker(
          label: 'Credit Date',
          value: _creditDate,
          onChanged: (d) => setState(() => _creditDate = d),
        ),
        KSpacing.vGapMd,
        KTextField(
          label: 'Purchase Bill ID (optional)',
          hint: 'Link to original purchase bill',
          initialValue: _purchaseBillId,
          onChanged: (v) => _purchaseBillId = v,
        ),
        KSpacing.vGapMd,
        KTextField(
          label: 'Reason',
          hint: 'e.g. Goods returned, Pricing error',
          initialValue: _reason,
          onChanged: (v) => _reason = v,
        ),
        KSpacing.vGapMd,
        KTextField(
          label: 'Place of Supply',
          hint: 'e.g. Maharashtra',
          initialValue: _placeOfSupply,
          onChanged: (v) => _placeOfSupply = v,
        ),
      ],
    );
  }

  // ── Step 1: Line Items ──
  Widget _buildLinesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Credit Lines', style: KTypography.h2),
        KSpacing.vGapMd,

        ...List.generate(_lineItems.length, (index) {
          return _CreditLineItemCard(
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
              setState(() => _lineItems.add(_CreditLineItem())),
        ),

        KSpacing.vGapLg,

        // Summary
        KCard(
          child: Column(
            children: [
              _SummaryRow(
                  label: 'Subtotal',
                  value:
                      CurrencyFormatter.formatIndian(_subtotal)),
              _SummaryRow(
                  label: 'Tax',
                  value:
                      CurrencyFormatter.formatIndian(_totalTax)),
              const Divider(),
              _SummaryRow(
                label: 'Grand Total',
                value:
                    CurrencyFormatter.formatIndian(_grandTotal),
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
        Text('Review Credit', style: KTypography.h2),
        KSpacing.vGapMd,

        KCard(
          title: 'Vendor',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _vendorName.isEmpty
                    ? 'Selected Vendor'
                    : _vendorName,
                style: KTypography.bodyLarge,
              ),
              KSpacing.vGapSm,
              KDetailRow(
                label: 'Credit Date',
                value: DateFormatter.display(_creditDate),
              ),
              if (_reason.isNotEmpty)
                KDetailRow(label: 'Reason', value: _reason),
              if (_purchaseBillId.isNotEmpty)
                KDetailRow(
                    label: 'Purchase Bill',
                    value: _purchaseBillId),
              if (_placeOfSupply.isNotEmpty)
                KDetailRow(
                    label: 'Place of Supply',
                    value: _placeOfSupply),
            ],
          ),
        ),
        KSpacing.vGapMd,

        KCard(
          title: 'Lines (${_lineItems.length})',
          child: Column(
            children:
                _lineItems.asMap().entries.map((entry) {
              final item = entry.value;
              return Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
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
                      CurrencyFormatter.formatIndian(
                          item.lineTotal),
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
                  value:
                      CurrencyFormatter.formatIndian(_subtotal)),
              _SummaryRow(
                  label: 'Tax',
                  value:
                      CurrencyFormatter.formatIndian(_totalTax)),
              const Divider(),
              _SummaryRow(
                label: 'Total',
                value:
                    CurrencyFormatter.formatIndian(_grandTotal),
                bold: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Helper Classes & Widgets ──

class _CreditLineItem {
  String? itemId;
  String? taxGroupId;
  String description = '';
  String hsnCode = '';
  String accountId = '';
  double quantity = 1;
  double unitPrice = 0;
  double gstRate = 18;

  double get taxableAmount => quantity * unitPrice;
  double get taxAmount => taxableAmount * gstRate / 100;
  double get lineTotal => taxableAmount + taxAmount;
}

class _CreditLineItemCard extends StatefulWidget {
  final _CreditLineItem item;
  final int index;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  const _CreditLineItemCard({
    required this.item,
    required this.index,
    this.onRemove,
    required this.onChanged,
  });

  @override
  State<_CreditLineItemCard> createState() =>
      _CreditLineItemCardState();
}

class _CreditLineItemCardState
    extends State<_CreditLineItemCard> {
  late final TextEditingController _descCtl;
  late final TextEditingController _hsnCtl;
  late final TextEditingController _qtyCtl;
  late final TextEditingController _priceCtl;
  late final TextEditingController _accountCtl;

  @override
  void initState() {
    super.initState();
    _descCtl =
        TextEditingController(text: widget.item.description);
    _hsnCtl =
        TextEditingController(text: widget.item.hsnCode);
    _qtyCtl = TextEditingController(
        text: widget.item.quantity.toString());
    _priceCtl = TextEditingController(
        text: widget.item.unitPrice.toString());
    _accountCtl =
        TextEditingController(text: widget.item.accountId);
  }

  @override
  void dispose() {
    _descCtl.dispose();
    _hsnCtl.dispose();
    _qtyCtl.dispose();
    _priceCtl.dispose();
    _accountCtl.dispose();
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
              Text('Item ${widget.index + 1}',
                  style: KTypography.labelLarge),
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
          KTextField(
            label: 'HSN Code',
            controller: _hsnCtl,
            hint: 'e.g. 8471',
            onChanged: (v) {
              widget.item.hsnCode = v;
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
                      const TextInputType.numberWithOptions(
                          decimal: true),
                  onChanged: (v) {
                    widget.item.quantity =
                        double.tryParse(v) ?? 1;
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
                    widget.item.unitPrice =
                        double.tryParse(v) ?? 0;
                    widget.onChanged();
                  },
                ),
              ),
            ],
          ),
          KSpacing.vGapSm,
          Row(
            children: [
              Expanded(
                child: KTextField(
                  label: 'Account ID',
                  controller: _accountCtl,
                  hint: 'e.g. 5000',
                  onChanged: (v) {
                    widget.item.accountId = v;
                    widget.onChanged();
                  },
                ),
              ),
              KSpacing.hGapSm,
              Expanded(
                child: TaxGroupPicker(
                  value: widget.item.taxGroupId,
                  label: 'Tax Group',
                  onChanged: (group) {
                    widget.item.taxGroupId = group?.id;
                    widget.item.gstRate =
                        group?.totalRate ?? 0;
                    widget.onChanged();
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
            color: isSelected
                ? KColors.primary
                : KColors.divider,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor:
                  KColors.primaryLight.withValues(alpha: 0.15),
              child: const Icon(
                Icons.store,
                color: KColors.primary,
              ),
            ),
            KSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: KTypography.bodyMedium),
                  Text(subtitle,
                      style: KTypography.bodySmall),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle,
                  color: KColors.primary),
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
            style: bold
                ? KTypography.labelLarge
                : KTypography.bodyMedium,
          ),
          Text(
            value,
            style: bold
                ? KTypography.amountMedium
                : KTypography.amountSmall,
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
                  ? const Icon(Icons.check,
                      color: Colors.white, size: 16)
                  : Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: isActive
                            ? Colors.white
                            : KColors.textSecondary,
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
              color: isActive
                  ? KColors.primary
                  : KColors.textSecondary,
              fontWeight: isActive
                  ? FontWeight.w600
                  : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
