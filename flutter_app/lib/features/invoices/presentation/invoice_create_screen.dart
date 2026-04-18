import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../inventory/presentation/batch_picker_sheet.dart';
import '../../inventory/presentation/item_picker_sheet.dart';
import '../../pricing/data/price_list_repository.dart';
import '../../tax_groups/data/tax_group_repository.dart';
import '../../tax_groups/presentation/widgets/tax_group_picker.dart';
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
  String? _selectedContactId;
  String _contactName = '';
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  bool _loadingCustomers = true;
  String _customerSearch = '';

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
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
      final customers = list
          .where((c) {
            final type = (c['contactType'] as String? ?? '').toUpperCase();
            return type == 'CUSTOMER' || type == 'BOTH';
          })
          .toList();
      if (mounted) {
        setState(() {
          _customers = customers;
          _filteredCustomers = customers;
          _loadingCustomers = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingCustomers = false);
    }
  }

  void _filterCustomers(String query) {
    setState(() {
      _customerSearch = query;
      if (query.isEmpty) {
        _filteredCustomers = _customers;
      } else {
        final lower = query.toLowerCase();
        _filteredCustomers = _customers
            .where((c) =>
                (c['displayName'] as String? ?? '').toLowerCase().contains(lower) ||
                (c['companyName'] as String? ?? '').toLowerCase().contains(lower) ||
                (c['phone'] as String? ?? '').contains(lower) ||
                (c['mobile'] as String? ?? '').contains(lower) ||
                (c['gstin'] as String? ?? '').toLowerCase().contains(lower))
            .toList();
      }
    });
  }

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

      await repo.createInvoice(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice created successfully')),
        );
        context.go(Routes.invoices);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e is DioException
            ? ApiErrorParser.message(e)
            : 'Failed to create invoice. Please try again.';
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
                              _selectedContactId == null) {
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

        // Customer search
        KTextField(
          label: 'Search customers',
          hint: 'Type customer name, phone or GSTIN...',
          prefixIcon: Icons.search,
          onChanged: _filterCustomers,
        ),
        KSpacing.vGapMd,

        Text(
          'Your Customers',
          style: KTypography.labelLarge.copyWith(color: KColors.textSecondary),
        ),
        KSpacing.vGapSm,

        if (_loadingCustomers)
          const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ))
        else if (_filteredCustomers.isEmpty)
          _CustomerSelectTile(
            name: _customers.isEmpty
                ? 'No customers yet'
                : 'No matching customers',
            gstin: _customers.isEmpty
                ? 'Add customers from the Customers tab first'
                : 'Try a different search term',
            isSelected: false,
            onTap: () {},
          )
        else
          ..._filteredCustomers.map((customer) {
            final id = customer['id']?.toString() ?? '';
            final name = customer['displayName'] as String? ??
                customer['companyName'] as String? ?? 'Unknown';
            final gstin = customer['gstin'] as String? ?? '';
            final phone = customer['phone'] as String? ??
                customer['mobile'] as String? ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CustomerSelectTile(
                name: name,
                gstin: gstin.isNotEmpty
                    ? 'GSTIN: $gstin'
                    : (phone.isNotEmpty ? phone : 'No details'),
                isSelected: _selectedContactId == id,
                onTap: () {
                  setState(() {
                    _selectedContactId = id;
                    _contactName = name;
                  });
                },
              ),
            );
          }),

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

  /// Returns the price list that will drive resolution for the
  /// currently-selected customer, or null if none is loaded yet / none
  /// applies. Walks the F3 fall-through chain on the client side so the
  /// banner matches what [`PriceListService.resolvePrice`] will do at
  /// invoice-submit time.
  Map<String, dynamic>? _effectivePriceList(
      List<Map<String, dynamic>> lists) {
    if (_selectedContactId == null) return null;
    final customer = _customers.firstWhere(
      (c) => c['id']?.toString() == _selectedContactId,
      orElse: () => const <String, dynamic>{},
    );
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
              border:
                  Border.all(color: KColors.primary.withValues(alpha: 0.3)),
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
                        const TextSpan(
                            text: 'Prices will follow price list '),
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

  // ── Step 1: Line Items ──
  Widget _buildItemsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Line Items', style: KTypography.h2),
        KSpacing.vGapMd,

        _buildPriceListHint(),

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
                _contactName.isEmpty ? 'Selected Customer' : _contactName,
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
  String? itemId;
  String? taxGroupId;
  String description = '';
  String hsnCode = '';
  double quantity = 1;
  double unitPrice = 0;
  double gstRate = 18;

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

  double get taxableAmount => quantity * unitPrice;
  double get taxAmount => taxableAmount * gstRate / 100;
  double get lineTotal => taxableAmount + taxAmount;
}

class _LineItemCard extends StatefulWidget {
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
  State<_LineItemCard> createState() => _LineItemCardState();
}

class _LineItemCardState extends State<_LineItemCard> {
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
    setState(() {
      widget.item.itemId = picked['id']?.toString();
      widget.item.description = picked['name']?.toString() ?? '';
      widget.item.hsnCode = picked['hsnCode']?.toString() ?? '';
      widget.item.unitPrice = (picked['salePrice'] as num?)?.toDouble() ?? 0;
      final pickedGst = (picked['gstRate'] as num?)?.toDouble();
      if (pickedGst != null) {
        widget.item.gstRate = pickedGst;
      }
      final pickedTaxGroupId = picked['taxGroupId']?.toString();
      if (pickedTaxGroupId != null) {
        widget.item.taxGroupId = pickedTaxGroupId;
      }
      widget.item.trackBatches = picked['trackBatches'] == true;
      // New item means any prior batch selection is stale.
      widget.item.batchId = null;
      widget.item.batchNumber = null;
      widget.item.batchExpiry = null;
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
    });
    widget.onChanged();
  }

  void _clearBatch() {
    setState(() {
      widget.item.batchId = null;
      widget.item.batchNumber = null;
      widget.item.batchExpiry = null;
    });
    widget.onChanged();
  }

  void _clearItemLink() {
    setState(() {
      widget.item.itemId = null;
      widget.item.trackBatches = false;
      widget.item.batchId = null;
      widget.item.batchNumber = null;
      widget.item.batchExpiry = null;
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
                  style: KTypography.bodySmall
                      .copyWith(color: KColors.warning),
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 18, color: KColors.warning),
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
          const Icon(Icons.inventory_2,
              size: 16, color: KColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Batch: ${widget.item.batchNumber ?? "—"}',
                  style: KTypography.labelMedium
                      .copyWith(color: KColors.primary),
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

  @override
  Widget build(BuildContext context) {
    final isLinked = widget.item.itemId != null;
    return KCard(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Item ${widget.index + 1}', style: KTypography.labelLarge),
              if (isLinked) ...[
                KSpacing.hGapSm,
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
          if (widget.item.trackBatches) ...[
            KSpacing.vGapSm,
            _buildBatchRow(),
          ],
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
                  label: 'HSN Code',
                  controller: _hsnCtl,
                  onChanged: (v) {
                    widget.item.hsnCode = v;
                    widget.onChanged();
                  },
                ),
              ),
              KSpacing.hGapSm,
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
            ],
          ),
          KSpacing.vGapSm,
          Row(
            children: [
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
              KSpacing.hGapSm,
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

