import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/utils/form_error_handler.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../routing/app_router.dart';
import '../../contacts/presentation/contact_picker_sheet.dart';
import '../../custom_fields/data/custom_field_repository.dart';
import '../../inventory/data/item_repository.dart';
import '../../inventory/presentation/batch_picker_sheet.dart';
import '../../inventory/presentation/item_picker_sheet.dart';
import '../../pricing/data/price_list_repository.dart';
import '../../tax_groups/presentation/widgets/tax_group_picker.dart';
import '../data/invoice_repository.dart';

class InvoiceCreateScreen extends ConsumerStatefulWidget {
  /// When set, the screen edits an existing DRAFT invoice (PUT) instead of
  /// creating a new one (POST).
  final String? invoiceId;

  const InvoiceCreateScreen({super.key, this.invoiceId});

  @override
  ConsumerState<InvoiceCreateScreen> createState() =>
      _InvoiceCreateScreenState();
}

class _InvoiceCreateScreenState extends ConsumerState<InvoiceCreateScreen>
    with FormErrorHandler {
  final _formKey = GlobalKey<FormState>();
  final _customFieldsKey = GlobalKey<KCustomFieldsRendererState>();
  bool _isSubmitting = false;
  String? _errorMessage;

  // Customer step
  String? _selectedContactId;
  String _contactName = '';
  String? _contactGstin;
  String? _contactPhone;
  Map<String, dynamic>? _selectedCustomer;

  Future<void> _openCustomerPicker() async {
    final picked = await showContactPicker(context, showQuickCreate: true);
    if (picked == null || !mounted) return;
    setState(() {
      _selectedCustomer = picked;
      _selectedContactId = picked['id']?.toString();
      _contactName = _contactDisplayName(picked);
      _contactGstin = picked['gstin'] as String?;
      _contactPhone = picked['phone'] as String? ?? picked['mobile'] as String?;
      _errorMessage = null;
    });
  }

  String _contactDisplayName(Map<String, dynamic> contact) {
    for (final key in const [
      'displayName',
      'companyName',
      'name',
      'fullName',
      'contactName',
    ]) {
      final value = contact[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    final first = contact['firstName']?.toString().trim() ?? '';
    final last = contact['lastName']?.toString().trim() ?? '';
    final full = [first, last].where((s) => s.isNotEmpty).join(' ');
    if (full.isNotEmpty) return full;
    return 'Customer';
  }

  String _customerSubtitle() {
    final parts = <String>[
      if (_contactGstin != null && _contactGstin!.isNotEmpty)
        'GSTIN: $_contactGstin',
      if (_contactPhone != null && _contactPhone!.isNotEmpty) _contactPhone!,
    ];
    return parts.isEmpty ? 'Tap to change' : parts.join(' · ');
  }

  // Line items
  final List<_LineItem> _lineItems = [_LineItem()];

  // Dates
  DateTime _invoiceDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  String _notes = '';

  double get _subtotal =>
      _lineItems.fold(0, (sum, line) => sum + line.taxableAmount);

  double get _totalTax =>
      _lineItems.fold(0, (sum, line) => sum + line.taxAmount);

  double get _grandTotal => _subtotal + _totalTax;

  bool get _isEdit => widget.invoiceId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadForEdit());
    }
  }

  /// Pull the DRAFT invoice and prefill the wizard so the user edits in place.
  Future<void> _loadForEdit() async {
    try {
      final raw =
          await ref.read(invoiceRepositoryProvider).getInvoice(widget.invoiceId!);
      final inv = (raw['data'] ?? raw) as Map<String, dynamic>;
      final lines =
          (inv['lines'] as List?)?.whereType<Map>().toList() ?? const [];
      setState(() {
        _selectedContactId = inv['contactId']?.toString();
        _contactName = inv['contactName']?.toString() ?? '';
        _selectedCustomer = _selectedContactId == null
            ? null
            : {'id': _selectedContactId, 'displayName': _contactName};
        _notes = inv['notes']?.toString() ?? '';
        _invoiceDate =
            DateTime.tryParse(inv['invoiceDate']?.toString() ?? '') ?? _invoiceDate;
        _dueDate =
            DateTime.tryParse(inv['dueDate']?.toString() ?? '') ?? _dueDate;
        _lineItems
          ..clear()
          ..addAll(lines.map((l) {
            final li = _LineItem();
            li.description = l['description']?.toString() ?? '';
            li.hsnCode = l['hsnCode']?.toString() ?? '';
            li.quantity = (l['quantity'] as num?)?.toDouble() ?? 1;
            li.unitPrice = (l['unitPrice'] as num?)?.toDouble() ?? 0;
            li.gstRate = (l['gstRate'] as num?)?.toDouble() ?? 0;
            li.taxGroupId = l['taxGroupId']?.toString();
            li.itemId = l['itemId']?.toString();
            li.batchId = l['batchId']?.toString();
            li.batchNumber = l['batchNumber']?.toString();
            return li;
          }));
        if (_lineItems.isEmpty) _lineItems.add(_LineItem());
      });
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to load invoice for editing.');
      }
    }
  }

  Future<void> _handleSubmit() async {
    // Guard: Ctrl+Enter can invoke this directly while a submit is in
    // flight; without this check a second press creates a duplicate document.
    if (_isSubmitting) return;
    if (_selectedContactId == null) {
      setState(() => _errorMessage = 'Please select a customer.');
      return;
    }
    if (!_formKey.currentState!.validate()) {
      setState(() => _errorMessage = 'Please fix the highlighted fields.');
      return;
    }
    if (_grandTotal <= 0) {
      setState(() => _errorMessage = 'Invoice total must be greater than zero.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(invoiceRepositoryProvider);
      final data = {
        'contactId': _selectedContactId,
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
                  if (l.taxGroupId != null) 'taxGroupId': l.taxGroupId,
                  if (l.itemId != null) 'itemId': l.itemId,
                  if (l.batchId != null) 'batchId': l.batchId,
                })
            .toList(),
      };

      String invoiceId = '';
      if (_isEdit) {
        invoiceId = widget.invoiceId!;
        await repo.updateInvoice(invoiceId, data);
      } else {
        final res = await repo.createInvoice(data);
        invoiceId = res['id']?.toString() ?? '';
      }

      final customInputs = _customFieldsKey.currentState?.getValues();
      if (invoiceId.isNotEmpty && customInputs != null && customInputs.isNotEmpty) {
        try {
          await ref.read(customFieldRepositoryProvider).saveValues(
            'INVOICE',
            invoiceId,
            customInputs,
          );
        } catch (e) {
          debugPrint('Failed to save custom fields on invoice: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_isEdit
                  ? 'Invoice updated successfully'
                  : 'Invoice created successfully')),
        );
        context.go(Routes.invoices);
      }
    } catch (e) {
      if (e is DioException) {
        final fieldErrs = ApiErrorParser.fieldErrors(e);
        if (fieldErrs.isNotEmpty) {
          setState(() => serverErrors = fieldErrs);
          _formKey.currentState!.validate();
        }
        setState(() => _errorMessage = ApiErrorParser.message(e));
      } else {
        setState(() => _errorMessage = _isEdit
            ? 'Failed to update invoice. Please try again.'
            : 'Failed to create invoice. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasCustomer = _selectedContactId != null;

    return KKeyboardFormWrapper(
      onSubmit: _handleSubmit,
      onCancel: () => context.go(Routes.invoices),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? 'Edit Invoice' : 'Create Invoice'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back to invoices',
            onPressed: () => context.go(Routes.invoices),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: KButton(
                  label: _isEdit ? 'Save Changes' : 'Save Invoice',
                  icon: Icons.check,
                  variant: KButtonVariant.primary,
                  onPressed: _handleSubmit,
                  isLoading: _isSubmitting,
                ),
              ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KSpacing.md,
                    vertical: KSpacing.sm,
                  ),
                  child: KErrorBanner(
                    message: _errorMessage!,
                    onDismiss: () => setState(() => _errorMessage = null),
                  ),
                ),

              // Document Body
              Expanded(
                child: SingleChildScrollView(
                  padding: KSpacing.pagePadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Card 1: Customer & Invoice Meta
                      KCard(
                        title: 'Invoice Details',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            KCompactRow(
                              flex: const [4, 2, 2],
                              stackBelow: 720,
                              children: [
                                // Customer Picker
                                InkWell(
                                  onTap: _openCustomerPicker,
                                  borderRadius: KSpacing.borderRadiusMd,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: KSpacing.sm,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: hasCustomer
                                          ? cs.primary.withValues(alpha: 0.04)
                                          : cs.surfaceContainerHighest.withValues(alpha: 0.3),
                                      borderRadius: KSpacing.borderRadiusMd,
                                      border: Border.all(
                                        color: hasCustomer ? cs.primary : cs.outlineVariant,
                                        width: hasCustomer ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: cs.primary.withValues(alpha: 0.12),
                                          child: Icon(
                                            hasCustomer ? Icons.person : Icons.person_add_alt_1,
                                            color: cs.primary,
                                            size: 16,
                                          ),
                                        ),
                                        KSpacing.hGapSm,
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                hasCustomer ? _contactName : 'Select Customer *',
                                                style: KTypography.labelLarge.copyWith(
                                                  color: hasCustomer ? cs.onSurface : cs.error,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                hasCustomer
                                                    ? _customerSubtitle()
                                                    : 'Tap to pick customer from directory',
                                                style: KTypography.bodySmall.copyWith(
                                                  color: cs.onSurfaceVariant,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          hasCustomer ? 'Change' : 'Browse',
                                          style: KTypography.labelMedium.copyWith(color: cs.primary),
                                        ),
                                        const Icon(Icons.chevron_right, size: 16),
                                      ],
                                    ),
                                  ),
                                ),
                                // Invoice Date
                                KDatePicker(
                                  label: 'Invoice Date',
                                  value: _invoiceDate,
                                  isRequired: true,
                                  onChanged: (d) => setState(() => _invoiceDate = d),
                                ),
                                // Due Date
                                KDatePicker(
                                  label: 'Due Date',
                                  value: _dueDate,
                                  isRequired: true,
                                  onChanged: (d) => setState(() => _dueDate = d),
                                  firstDate: _invoiceDate,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      KSpacing.vGapMd,

                      // Price List Banner (if active)
                      _buildPriceListHint(),

                      // Card 2: Line Items Grid
                      KCard(
                        title: 'Line Items (${_lineItems.length})',
                        action: KButton(
                          label: 'Add Item',
                          icon: Icons.add,
                          size: KButtonSize.small,
                          variant: KButtonVariant.outlined,
                          onPressed: () => setState(() => _lineItems.add(_LineItem())),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...List.generate(_lineItems.length, (index) {
                              return _LineItemCard(
                                key: ObjectKey(_lineItems[index]),
                                item: _lineItems[index],
                                index: index,
                                onRemove: _lineItems.length > 1
                                    ? () => setState(() => _lineItems.removeAt(index))
                                    : null,
                                onChanged: () => setState(() {}),
                              );
                            }),
                            KSpacing.vGapSm,
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => setState(() => _lineItems.add(_LineItem())),
                                icon: const Icon(Icons.add_circle_outline, size: 18),
                                label: const Text('Add Another Line Item'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      KSpacing.vGapMd,

                      // Card 3: Financial Summary & Notes
                      KCard(
                        title: 'Notes & Summary',
                        child: KCompactRow(
                          flex: const [3, 2],
                          stackBelow: 720,
                          children: [
                            KTextField(
                              label: 'Customer Notes & Terms',
                              hint: 'Add payment instructions, delivery terms, or bank account notes...',
                              maxLines: 4,
                              initialValue: _notes,
                              onChanged: (v) => _notes = v,
                            ),
                            Container(
                              padding: const EdgeInsets.all(KSpacing.sm),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
                                borderRadius: KSpacing.borderRadiusMd,
                                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _SummaryRow(
                                    label: 'Subtotal (Taxable)',
                                    value: _subtotal,
                                  ),
                                  _SummaryRow(
                                    label: 'Total GST',
                                    value: _totalTax,
                                  ),
                                  const Divider(height: 12),
                                  _SummaryRow(
                                    label: 'Grand Total',
                                    value: _grandTotal,
                                    bold: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      KSpacing.vGapMd,
                      KCustomFieldsRenderer(
                        key: _customFieldsKey,
                        entityType: 'INVOICE',
                        entityId: widget.invoiceId,
                      ),
                      KSpacing.vGapXl,
                    ],
                  ),
                ),
              ),

              // Bottom Sticky Bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: KSpacing.md,
                  vertical: KSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border(top: BorderSide(color: cs.outlineVariant)),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Grand Total', style: KTypography.bodySmall),
                          KMoney(_grandTotal, size: KMoneySize.medium),
                        ],
                      ),
                      const Spacer(),
                      KButton(
                        label: 'Cancel',
                        variant: KButtonVariant.outlined,
                        onPressed: () => context.go(Routes.invoices),
                      ),
                      KSpacing.hGapSm,
                      KButton(
                        label: _isEdit ? 'Save Changes' : 'Create Invoice',
                        icon: Icons.check,
                        variant: KButtonVariant.primary,
                        onPressed: _handleSubmit,
                        isLoading: _isSubmitting,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Returns the price list that will drive resolution for the
  /// currently-selected customer, or null if none is loaded yet / none
  /// applies. Walks the F3 fall-through chain on the client side so the
  /// banner matches what [`PriceListService.resolvePrice`] will do at
  /// invoice-submit time.
  Map<String, dynamic>? _effectivePriceList(List<Map<String, dynamic>> lists) {
    if (_selectedContactId == null) return null;
    final customer = _selectedCustomer ?? const <String, dynamic>{};
    final pinned = customer['defaultPriceListId']?.toString();
    if (pinned != null) {
      for (final l in lists) {
        if (l['id']?.toString() == pinned && l['active'] != false) {
          return l;
        }
      }
    }
    // Fall through to org default
    for (final l in lists) {
      if (l['isDefault'] == true && l['active'] != false) return l;
    }
    return null;
  }

  Widget _buildPriceListHint() {
    final listsAsync = ref.watch(priceListsProvider);
    return listsAsync.maybeWhen(
      data: (lists) {
        final effective = _effectivePriceList(lists);
        if (effective == null) return const SizedBox.shrink();
        final name = effective['name']?.toString() ?? 'Price List';
        final currency = effective['currency']?.toString() ?? 'INR';
        return Padding(
          padding: const EdgeInsets.only(bottom: KSpacing.md),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: KSpacing.sm, vertical: KSpacing.sm),
            decoration: BoxDecoration(
              color: KColors.primary.withValues(alpha: 0.06),
              borderRadius: KSpacing.borderRadiusMd,
              border: Border.all(color: KColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.sell_outlined,
                    size: 18, color: KColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.primary),
                      children: [
                        const TextSpan(text: 'Prices will follow price list '),
                        TextSpan(
                          text: name,
                          style: KTypography.bodySmall.copyWith(
                            color: KColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(text: ' ($currency). '),
                        const TextSpan(
                          text:
                              'Unit prices below may be overridden when the invoice is saved.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }


}

// ── Helper Widgets ──

class _LineItem {
  String? itemId;
  String? taxGroupId;
  String description = '';
  String hsnCode = '';
  double quantity = 1;
  double unitPrice = 0;
  double gstRate = 0;
  bool weightBasedBilling = false;
  String weightUnit = 'KG';
  double? availableStock;
  double? selectedBatchAvailable;

  /// True if the linked item has `trackBatches = true`. When set, the
  /// line MUST carry [batchId] before the invoice can be sent — the
  /// backend gate rejects the post otherwise (INV_BATCH_REQUIRED).
  bool trackBatches = false;

  /// The explicit batch this line will draw from. Null means "let the
  /// server FEFO-pick at send time", which is still valid: the
  /// deductStockForInvoice branch walks batches in expiry order.
  String? batchId;

  /// Display hint — the batch number for the chip. Not sent to the
  /// server (it resolves by id).
  String? batchNumber;

  /// Display hint — `yyyy-MM-dd` string from the API. Used to colour
  /// the expiry chip urgently when it's near.
  String? batchExpiry;

  double? get maxSellQuantity => selectedBatchAvailable ?? availableStock;

  double get taxableAmount => quantity * unitPrice;
  double get taxAmount => taxableAmount * gstRate / 100;
  double get lineTotal => taxableAmount + taxAmount;
}

class _LineItemCard extends ConsumerStatefulWidget {
  final _LineItem item;
  final int index;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  const _LineItemCard({
    super.key,
    required this.item,
    required this.index,
    this.onRemove,
    required this.onChanged,
  });

  @override
  ConsumerState<_LineItemCard> createState() => _LineItemCardState();
}

class _LineItemCardState extends ConsumerState<_LineItemCard> {
  late final TextEditingController _descCtl;
  late final TextEditingController _hsnCtl;
  late final TextEditingController _qtyCtl;
  late final TextEditingController _priceCtl;

  @override
  void initState() {
    super.initState();
    _descCtl = TextEditingController(text: widget.item.description);
    _hsnCtl = TextEditingController(text: widget.item.hsnCode);
    _qtyCtl = TextEditingController(text: widget.item.quantity.toString());
    _priceCtl = TextEditingController(text: widget.item.unitPrice.toString());
  }

  @override
  void dispose() {
    _descCtl.dispose();
    _hsnCtl.dispose();
    _qtyCtl.dispose();
    _priceCtl.dispose();
    super.dispose();
  }

  Future<void> _pickItem() async {
    final picked = await showItemPicker(context);
    if (picked == null) return;
    await _applyPickedItem(picked);
  }

  /// Shared item-fill: called by both the modal picker and the inline
  /// typeahead so they stay in lockstep.
  Future<void> _applyPickedItem(Map<String, dynamic> picked) async {
    setState(() {
      widget.item.itemId = picked['id']?.toString();
      widget.item.description = picked['name']?.toString() ?? '';
      widget.item.hsnCode = picked['hsnCode']?.toString() ?? '';
      widget.item.unitPrice = (picked['salePrice'] as num?)?.toDouble() ?? 0;
      widget.item.availableStock =
          (picked['currentStock'] as num?)?.toDouble() ??
              (picked['quantityOnHand'] as num?)?.toDouble();
      final pickedTaxGroupId = picked['defaultTaxGroupId']?.toString();
      if (pickedTaxGroupId != null) {
        widget.item.taxGroupId = pickedTaxGroupId;
        final pickedGst = (picked['gstRate'] as num?)?.toDouble();
        widget.item.gstRate = pickedGst ?? 0;
      } else {
        widget.item.taxGroupId = null;
        widget.item.gstRate = 0;
      }
      widget.item.trackBatches = picked['trackBatches'] == true;
      widget.item.weightBasedBilling = picked['weightBasedBilling'] == true;
      if (widget.item.weightBasedBilling) {
        widget.item.weightUnit = 'KG';
      }
      // New item means any prior batch selection is stale.
      widget.item.batchId = null;
      widget.item.batchNumber = null;
      widget.item.batchExpiry = null;
      widget.item.selectedBatchAvailable = null;
      _descCtl.text = widget.item.description;
      _hsnCtl.text = widget.item.hsnCode;
      _priceCtl.text = widget.item.unitPrice.toString();
    });
    widget.onChanged();

    // If the item is batch-tracked, chain straight into the batch
    // picker so the user never lands on a send-button-disabled state
    // without knowing why. They can still cancel and come back later
    // via the "Pick Batch" button on the line card.
    if (widget.item.trackBatches && widget.item.itemId != null && mounted) {
      await _pickBatch();
    }
  }

  Future<List<Map<String, dynamic>>> _searchItems(String query) async {
    final repo = ref.read(itemRepositoryProvider);
    final raw = await repo.listItems(search: query);
    final content = raw['data'];
    final list = content is List
        ? content
        : (content is Map ? (content['content'] as List?) ?? [] : []);
    return list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }

  Future<void> _pickBatch() async {
    final itemId = widget.item.itemId;
    if (itemId == null) return;
    final picked = await showBatchPicker(
      context,
      itemId: itemId,
      itemName: widget.item.description,
    );
    if (picked == null) return;
    setState(() {
      widget.item.batchId = picked['id']?.toString();
      widget.item.batchNumber = picked['batchNumber']?.toString();
      widget.item.batchExpiry = picked['expiryDate']?.toString();
      widget.item.selectedBatchAvailable =
          (picked['quantityAvailable'] as num?)?.toDouble();
    });
    widget.onChanged();
  }

  void _clearBatch() {
    setState(() {
      widget.item.batchId = null;
      widget.item.batchNumber = null;
      widget.item.batchExpiry = null;
      widget.item.selectedBatchAvailable = null;
    });
    widget.onChanged();
  }

  void _clearItemLink() {
    setState(() {
      widget.item.itemId = null;
      widget.item.trackBatches = false;
      widget.item.weightBasedBilling = false;
      widget.item.batchId = null;
      widget.item.batchNumber = null;
      widget.item.batchExpiry = null;
      widget.item.availableStock = null;
      widget.item.selectedBatchAvailable = null;
    });
    widget.onChanged();
  }

  /// The batch strip shown only when the linked item is batch-tracked.
  /// Two states:
  ///  • `batchId == null` → amber "Pick Batch" banner warning the user
  ///    that the invoice can't send until a batch is chosen (or they
  ///    leave it null and let the server FEFO-pick at send time — the
  ///    banner says as much).
  ///  • `batchId != null` → outlined chip showing batch number + expiry,
  ///    with close + re-pick affordances. The expiry colour mirrors the
  ///    picker: red if expired, amber if within 30 days.
  Widget _buildBatchRow() {
    final batchId = widget.item.batchId;
    if (batchId == null) {
      return InkWell(
        onTap: _pickBatch,
        borderRadius: KSpacing.borderRadiusMd,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: KSpacing.sm, vertical: KSpacing.sm),
          decoration: BoxDecoration(
            color: KColors.warning.withValues(alpha: 0.08),
            borderRadius: KSpacing.borderRadiusMd,
            border: Border.all(color: KColors.warning.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.inventory_2_outlined,
                  size: 16, color: KColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pick batch — or leave blank to auto-pick earliest expiry (FEFO)',
                  style: KTypography.bodySmall.copyWith(color: KColors.warning),
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: KColors.warning),
            ],
          ),
        ),
      );
    }

    final expiry = widget.item.batchExpiry;
    final expiryColor = _expiryColor(expiry);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.sm, vertical: KSpacing.xs),
      decoration: BoxDecoration(
        color: KColors.primary.withValues(alpha: 0.06),
        borderRadius: KSpacing.borderRadiusMd,
        border: Border.all(color: KColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2, size: 16, color: KColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Batch: ${widget.item.batchNumber ?? "—"}',
                  style:
                      KTypography.labelMedium.copyWith(color: KColors.primary),
                ),
                if (expiry != null)
                  Text(
                    'Expires $expiry',
                    style: KTypography.labelSmall.copyWith(color: expiryColor),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: _pickBatch,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Change'),
          ),
          IconButton(
            tooltip: 'Clear batch',
            icon: const Icon(Icons.close, size: 16),
            visualDensity: VisualDensity.compact,
            onPressed: _clearBatch,
          ),
        ],
      ),
    );
  }

  Color _expiryColor(String? expiry) {
    if (expiry == null) return KColors.textSecondary;
    final parsed = DateTime.tryParse(expiry);
    if (parsed == null) return KColors.textSecondary;
    final days = parsed.difference(DateTime.now()).inDays;
    if (days < 0) return KColors.error;
    if (days <= 30) return KColors.warning;
    return KColors.textSecondary;
  }

  String _fmtQty(double qty) {
    return qty == qty.roundToDouble()
        ? qty.toInt().toString()
        : qty.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final isLinked = widget.item.itemId != null;
    return KCard(
      margin: const EdgeInsets.only(bottom: KSpacing.xs),
      padding: const EdgeInsets.all(KSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Item ${widget.index + 1}', style: KTypography.labelLarge),
              if (isLinked) ...[
                KSpacing.hGapSm,
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: KColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.link, size: 12, color: KColors.success),
                      const SizedBox(width: 4),
                      Text('Tracked',
                          style: KTypography.labelSmall.copyWith(
                            color: KColors.success,
                            fontWeight: FontWeight.w700,
                          )),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              TextButton.icon(
                onPressed: _pickItem,
                icon: const Icon(Icons.search, size: 16),
                label: Text(isLinked ? 'Change' : 'Pick Item'),
              ),
              if (isLinked)
                IconButton(
                  tooltip: 'Unlink (free-text)',
                  icon: const Icon(Icons.link_off, size: 18),
                  onPressed: _clearItemLink,
                ),
              if (widget.onRemove != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: KColors.error, size: 20),
                  onPressed: widget.onRemove,
                ),
            ],
          ),
          if (!isLinked) ...[
            KSpacing.vGapXs,
            // Keyboard-first item picker. Type → ↓/↑ → Enter to pick.
            // The "Pick Item" button above stays as a mouse-friendly browse path.
            KTypeaheadField<Map<String, dynamic>>(
              label: 'Search item',
              hint: 'Type item name or SKU…',
              onSearch: _searchItems,
              displayString: (m) => m['name']?.toString() ?? '',
              itemBuilder: (m) {
                final sku = m['sku']?.toString();
                final onHand = m['totalOnHand'];
                final parts = <String>[
                  if (sku != null && sku.isNotEmpty) 'SKU: $sku',
                  if (onHand != null) '$onHand on hand',
                ];
                final price = (m['salePrice'] as num?)?.toDouble();
                return KTypeaheadItem(
                  title: m['name']?.toString() ?? '',
                  subtitle: parts.isEmpty ? null : parts.join(' • '),
                  trailing: price == null
                      ? null
                      : CurrencyFormatter.formatIndian(price),
                  leading: m['itemType'] == 'SERVICE'
                      ? Icons.build_outlined
                      : Icons.inventory_2_outlined,
                );
              },
              onSelected: (m) => _applyPickedItem(m),
            ),
          ],
          if (widget.item.trackBatches) ...[
            KSpacing.vGapSm,
            _buildBatchRow(),
          ],
          if (widget.item.maxSellQuantity != null) ...[
            KSpacing.vGapXs,
            Text(
              '${_fmtQty(widget.item.maxSellQuantity!)} available',
              style: KTypography.labelSmall.copyWith(
                color: widget.item.quantity > widget.item.maxSellQuantity!
                    ? KColors.error
                    : KColors.textSecondary,
                fontWeight: widget.item.quantity > widget.item.maxSellQuantity!
                    ? FontWeight.w700
                    : null,
              ),
            ),
          ],
          KSpacing.vGapXs,
          KTextField(
            label: 'Description',
            controller: _descCtl,
            onChanged: (v) {
              widget.item.description = v;
              widget.onChanged();
            },
          ),
          KSpacing.vGapXs,
          KCompactRow(children: [
            KTextField(
              label: 'HSN Code',
              controller: _hsnCtl,
              onChanged: (v) {
                widget.item.hsnCode = v;
                widget.onChanged();
              },
            ),
            widget.item.weightBasedBilling
                ? Row(
                    children: [
                      Expanded(
                        child: KTextField(
                          label: 'Weight',
                          controller: _qtyCtl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: (v) {
                            final weight = double.tryParse(v ?? '') ?? 0;
                            if (weight <= 0) return 'Weight must be positive';
                            final qty = widget.item.weightUnit == 'GM'
                                ? weight / 1000
                                : weight;
                            final max = widget.item.maxSellQuantity;
                            if (max != null && qty > max) {
                              return 'Only ${_fmtQty(max)} KG available';
                            }
                            return null;
                          },
                          onChanged: (v) {
                            final raw = double.tryParse(v) ?? 0;
                            widget.item.quantity =
                                widget.item.weightUnit == 'GM'
                                    ? raw / 1000
                                    : raw;
                            widget.onChanged();
                          },
                        ),
                      ),
                      const SizedBox(width: 4),
                      DropdownButton<String>(
                        value: widget.item.weightUnit,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: 'KG', child: Text('KG')),
                          DropdownMenuItem(value: 'GM', child: Text('GM')),
                        ],
                        onChanged: (unit) {
                          if (unit == null) return;
                          final currentRaw = double.tryParse(_qtyCtl.text) ?? 0;
                          setState(() {
                            widget.item.weightUnit = unit;
                            if (currentRaw > 0) {
                              final converted = unit == 'GM'
                                  ? currentRaw * 1000
                                  : currentRaw / 1000;
                              _qtyCtl.text = unit == 'GM'
                                  ? converted.toStringAsFixed(0)
                                  : converted.toStringAsFixed(3);
                              widget.item.quantity =
                                  unit == 'GM' ? converted / 1000 : converted;
                            }
                          });
                          widget.onChanged();
                        },
                      ),
                    ],
                  )
                : KTextField(
                    label: 'Qty',
                    controller: _qtyCtl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final qty = double.tryParse(v ?? '') ?? 0;
                      if (qty <= 0) return 'Quantity must be positive';
                      final max = widget.item.maxSellQuantity;
                      if (max != null && qty > max) {
                        return 'Only ${_fmtQty(max)} available';
                      }
                      return null;
                    },
                    onChanged: (v) {
                      widget.item.quantity = double.tryParse(v) ?? 1;
                      widget.onChanged();
                    },
                  ),
            KTextField.amount(
              label: widget.item.weightBasedBilling ? 'Rate/kg' : 'Price',
              controller: _priceCtl,
              validator: (v) {
                final price = double.tryParse(v ?? '') ?? 0;
                if (price <= 0) return 'Price must be positive';
                return null;
              },
              onChanged: (v) {
                widget.item.unitPrice = double.tryParse(v) ?? 0;
                widget.onChanged();
              },
            ),
          ]),
          KSpacing.vGapXs,
          Row(
            children: [
              Expanded(
                child: TaxGroupPicker(
                  value: widget.item.taxGroupId,
                  label: 'Tax Group',
                  onChanged: (group) {
                    widget.item.taxGroupId = group?.id;
                    widget.item.gstRate = group?.totalRate ?? 0;
                    widget.onChanged();
                  },
                ),
              ),
              KSpacing.hGapMd,
              KMoney(
                widget.item.lineTotal,
                size: KMoneySize.small,
                style: const TextStyle(
                  color: KColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final num value;
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
                ? KTypography.labelLarge.copyWith(fontWeight: FontWeight.w700)
                : KTypography.bodyMedium,
          ),
          KMoney(
            value,
            size: bold ? KMoneySize.medium : KMoneySize.small,
            style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null,
          ),
        ],
      ),
    );
  }
}
