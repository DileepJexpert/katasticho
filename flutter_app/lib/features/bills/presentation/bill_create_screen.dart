import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/utils/dual_uom_formatter.dart';
import '../../../core/utils/form_error_handler.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../routing/app_router.dart';
import '../../contacts/data/contact_repository.dart';
import '../../contacts/presentation/contact_picker_sheet.dart';
import '../../inventory/data/item_repository.dart';
import '../../inventory/presentation/item_picker_sheet.dart';
import '../../tax_groups/presentation/widgets/tax_group_picker.dart';
import '../data/bill_repository.dart';
import 'bill_scan_sheet.dart';

class BillCreateScreen extends ConsumerStatefulWidget {
  const BillCreateScreen({super.key});

  @override
  ConsumerState<BillCreateScreen> createState() => _BillCreateScreenState();
}

class _BillCreateScreenState extends ConsumerState<BillCreateScreen>
    with FormErrorHandler {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isSubmitting = false;
  String? _errorMessage;

  // Vendor step
  String? _selectedContactId;
  String _vendorName = '';
  String? _vendorGstin;
  String? _vendorPhone;
  String? _vendorCompany;

  // Bill metadata
  String _vendorBillNumber = '';
  DateTime _billDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  String _placeOfSupply = '';
  bool _reverseCharge = false;
  String _notes = '';

  // Line items
  final List<_BillLineItem> _lineItems = [_BillLineItem()];

  Future<void> _openVendorPicker() async {
    final picked = await showContactPicker(
      context,
      contactType: 'VENDOR',
      title: 'Select Vendor',
    );
    if (picked == null || !mounted) return;

    setState(() {
      _selectedContactId = picked['id']?.toString();
      _vendorName = _contactDisplayName(picked);
      _vendorGstin = picked['gstin']?.toString();
      _vendorPhone = (picked['phone'] ?? picked['mobile'])?.toString();
      _vendorCompany = picked['companyName']?.toString();
      _errorMessage = null;
    });
  }

  Future<Map<String, dynamic>?> _findVendorByGstin(String gstin) async {
    try {
      final result = await ref.read(contactRepositoryProvider).listContacts(
            type: 'VENDOR',
            search: gstin,
            size: 20,
          );
      final content = result['data'];
      final raw = content is List
          ? content
          : content is Map
              ? (content['content'] as List?) ?? const []
              : const [];
      for (final value in raw) {
        if (value is! Map) continue;
        final contact = Map<String, dynamic>.from(value);
        final type = contact['contactType']?.toString().toUpperCase();
        final candidate = contact['gstin']?.toString().toUpperCase();
        if ((type == 'VENDOR' || type == 'BOTH') &&
            candidate == gstin.toUpperCase()) {
          return contact;
        }
      }
    } catch (_) {
      // Scanning can still populate the bill even when vendor lookup fails.
    }
    return null;
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
    return full.isEmpty ? 'Vendor' : full;
  }

  String _vendorSubtitle() {
    final parts = <String>[
      if (_vendorCompany != null &&
          _vendorCompany!.isNotEmpty &&
          _vendorCompany != _vendorName)
        _vendorCompany!,
      if (_vendorGstin != null && _vendorGstin!.isNotEmpty)
        'GSTIN: $_vendorGstin',
      if (_vendorPhone != null && _vendorPhone!.isNotEmpty) _vendorPhone!,
    ];
    return parts.isEmpty ? 'Vendor contact selected' : parts.join(' | ');
  }

  Future<void> _scanBill() async {
    final result = await showBillScanSheet(context);
    if (result == null || !mounted) return;

    // AI-first path: the scan was approved & posted directly — no manual form.
    if (result['posted'] == true) {
      final billNumber = result['billNumber']?.toString() ?? '';
      final warnings = (result['warnings'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      final base = billNumber.isEmpty ? 'Bill posted' : 'Bill $billNumber posted';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(warnings.isEmpty
              ? base
              : '$base — ${warnings.length} note(s) to review'),
        ),
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return;
    }

    // Populate vendor info immediately
    setState(() {
      _vendorBillNumber =
          result['invoiceNumber'] as String? ?? _vendorBillNumber;
      if (result['billDate'] is DateTime) {
        _billDate = result['billDate'] as DateTime;
      }
      if (result['dueDate'] is DateTime) {
        _dueDate = result['dueDate'] as DateTime;
      }

    });

    final gstin = result['vendorGstin'] as String? ?? '';
    if (gstin.isNotEmpty) {
      final match = await _findVendorByGstin(gstin);
      if (match != null && mounted) {
        setState(() {
          _selectedContactId = match['id']?.toString();
          _vendorName = _contactDisplayName(match);
          _vendorGstin = match['gstin']?.toString();
          _vendorPhone = (match['phone'] ?? match['mobile'])?.toString();
          _vendorCompany = match['companyName']?.toString();
        });
      }
    }

    final scannedLines = (result['lineItems'] as List?) ?? [];
    if (scannedLines.isEmpty) {
      if (mounted) {
        setState(() => _currentStep = 1);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill scanned — no items detected')),
        );
      }
      return;
    }

    // Match / create inventory items with a progress dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Matching items to inventory...'),
              ],
            ),
          ),
        ),
      ),
    );

    final itemRepo = ref.read(itemRepositoryProvider);
    final newLines = <_BillLineItem>[];
    int matched = 0;
    int created = 0;
    int failed = 0;

    for (final line in scannedLines) {
      final l = line as Map<String, dynamic>;
      final desc = (l['description'] as String? ?? '').trim();
      final qty = (l['quantity'] as num?)?.toDouble() ?? 1;
      final price = (l['unitPrice'] as num?)?.toDouble() ?? 0;
      final gst = (l['gstRate'] as num?)?.toDouble() ?? 0;
      final hsn = l['hsnCode'] as String?;
      final mrp = (l['mrp'] as num?)?.toDouble() ?? 0;
      final batch = (l['batchNumber'] as String? ?? '').trim();
      final expiry =
          l['expiryDate'] is DateTime ? l['expiryDate'] as DateTime : null;

      final bill = _BillLineItem()
        ..lineType = 'GOODS'
        ..description = desc
        ..quantity = qty
        ..unitPrice = price
        ..taxRate = gst;

      if (desc.isNotEmpty) {
        try {
          final existing = await _findInventoryMatch(itemRepo, desc);
          if (existing != null) {
            bill.itemId = existing['id']?.toString();
            bill.trackBatches = existing['trackBatches'] as bool? ?? false;
            matched++;
          } else {
            final createdItem = await _createInventoryItem(
              itemRepo,
              name: desc,
              hsnCode: hsn,
              mrp: mrp,
              gstRate: gst,
              purchasePrice: price,
            );
            bill.itemId = createdItem['id']?.toString();
            bill.trackBatches = createdItem['trackBatches'] as bool? ?? true;
            created++;
          }
        } catch (_) {
          failed++;
        }
      }

      // Populate batch / expiry when the item tracks batches
      if (bill.trackBatches) {
        if (batch.isNotEmpty) bill.batchNumber = batch;
        if (expiry != null) bill.expiryDate = expiry;
      }

      newLines.add(bill);
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // close progress dialog

    setState(() {
      _lineItems
        ..clear()
        ..addAll(newLines.isEmpty ? [_BillLineItem()] : newLines);
      _currentStep = 1;
    });

    final summary = StringBuffer('Scan complete: ');
    final parts = <String>[];
    if (matched > 0) parts.add('$matched matched');
    if (created > 0) parts.add('$created new items created');
    if (failed > 0) parts.add('$failed need manual linking');
    summary.write(parts.isEmpty ? 'review items below' : parts.join(', '));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(summary.toString())),
    );
  }

  /// Fuzzy-match a scanned product name against existing inventory.
  /// Returns the best item map or null if no confident match.
  Future<Map<String, dynamic>?> _findInventoryMatch(
      ItemRepository repo, String name) async {
    // Search by the first 2 significant tokens for a focused result set
    final tokens = _significantTokens(name);
    if (tokens.isEmpty) return null;
    final query = tokens.take(2).join(' ');

    final resp = await repo.listItems(search: query, size: 20);
    final content = resp['data'];
    final items = content is List
        ? content.cast<Map<String, dynamic>>()
        : (content is Map
            ? ((content['content'] as List?)?.cast<Map<String, dynamic>>() ??
                [])
            : <Map<String, dynamic>>[]);
    if (items.isEmpty) return null;

    final target = _normalize(name);
    Map<String, dynamic>? best;
    double bestScore = 0;
    for (final it in items) {
      final candidate = _normalize(it['name']?.toString() ?? '');
      final score = _similarity(target, candidate);
      if (score > bestScore) {
        bestScore = score;
        best = it;
      }
    }
    // Require a strong match to auto-link; otherwise treat as new
    return bestScore >= 0.6 ? best : null;
  }

  Future<Map<String, dynamic>> _createInventoryItem(
    ItemRepository repo, {
    required String name,
    String? hsnCode,
    required double mrp,
    required double gstRate,
    required double purchasePrice,
  }) async {
    final sku = _generateSku(name);
    final data = <String, dynamic>{
      'sku': sku,
      'name': name.length > 255 ? name.substring(0, 255) : name,
      'itemType': 'GOODS',
      'trackInventory': true,
      // Pharma: batch + expiry tracking is essential for FEFO dispensing
      'trackBatches': true,
      if (hsnCode != null && hsnCode.isNotEmpty) 'hsnCode': hsnCode,
      if (mrp > 0) 'mrp': mrp,
      if (gstRate > 0) 'gstRate': gstRate,
      if (purchasePrice > 0) 'purchasePrice': purchasePrice,
    };
    final resp = await repo.createItem(data);
    return (resp['data'] ?? resp) as Map<String, dynamic>;
  }

  String _generateSku(String name) {
    final slug = name
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '')
        .padRight(4, 'X');
    final base = slug.length > 10 ? slug.substring(0, 10) : slug;
    final suffix = DateTime.now().millisecondsSinceEpoch.toString();
    return 'AUTO-$base-${suffix.substring(suffix.length - 5)}';
  }

  static final _stopWords = {
    'tab',
    'tabs',
    'cap',
    'caps',
    'syp',
    'syrup',
    'inj',
    'cream',
    'gel',
    'mg',
    'ml',
    'gm',
    'mcg',
    'the',
    'of',
    's',
  };

  List<String> _significantTokens(String name) {
    return _normalize(name)
        .split(' ')
        .where((t) => t.length > 1 && !_stopWords.contains(t))
        .toList();
  }

  String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9\s]"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Jaccard token-overlap similarity in [0,1].
  double _similarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final sa = a.split(' ').toSet();
    final sb = b.split(' ').toSet();
    if (sa.isEmpty || sb.isEmpty) return 0;
    final inter = sa.intersection(sb).length;
    final union = sa.union(sb).length;
    return inter / union;
  }

  double get _subtotal =>
      _lineItems.fold(0, (sum, line) => sum + line.taxableAmount);

  double get _totalTax =>
      _lineItems.fold(0, (sum, line) => sum + line.taxAmount);

  double get _grandTotal => _subtotal + _totalTax;

  Future<void> _handleSubmit() async {
    // Guard: Ctrl+Enter can invoke this directly while a submit is in
    // flight; without this check a second press creates a duplicate document.
    if (_isSubmitting) return;
    final validLines = _lineItems
        .where((l) => l.description.isNotEmpty || l.unitPrice > 0)
        .toList();
    if (validLines.isEmpty) {
      setState(() => _errorMessage =
          'Please add at least one line item with a description or price');
      return;
    }
    final unlinked = validLines.where((l) => l.needsItem).toList();
    if (unlinked.isNotEmpty) {
      setState(() => _errorMessage =
          'Goods lines must be linked to an item for stock tracking. '
              'Pick an item or switch line type to Service.');
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
                  'lineType': l.lineType,
                  'description':
                      l.description.isNotEmpty ? l.description : 'Line item',
                  'quantity': l.quantity,
                  'unitPrice': l.unitPrice,
                  'accountCode': l.accountCode,
                  'gstRate': l.taxRate,
                  if (l.taxGroupId != null) 'taxGroupId': l.taxGroupId,
                  if (l.itemId != null) 'itemId': l.itemId,
                  if (l.unitUomId != null) 'unitUomId': l.unitUomId,
                  if (l.unitConversionFactor != null)
                    'unitConversionFactor': l.unitConversionFactor,
                  if (l.trackBatches && l.batchNumber.isNotEmpty)
                    'batchNumber': l.batchNumber,
                  if (l.manufacturingDate != null)
                    'manufacturingDate':
                        l.manufacturingDate!.toIso8601String().split('T')[0],
                  if (l.expiryDate != null)
                    'expiryDate': l.expiryDate!.toIso8601String().split('T')[0],
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
      if (e is DioException) {
        final fieldErrs = ApiErrorParser.fieldErrors(e);
        if (fieldErrs.isNotEmpty) {
          setState(() => serverErrors = fieldErrs);
          _formKey.currentState!.validate();
        }
        setState(() => _errorMessage = ApiErrorParser.message(e));
      } else {
        setState(
            () => _errorMessage = 'Failed to create bill. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _nextStep() {
    if (_currentStep >= 2) return;
    if (_currentStep == 0 && _selectedContactId == null) {
      setState(() => _errorMessage = 'Please select a vendor');
      return;
    }
    setState(() => _currentStep++);
  }

  void _prevStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  Future<void> _openBillDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _billDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        _billDate = picked;
        if (_dueDate.isBefore(picked)) {
          _dueDate = picked.add(const Duration(days: 30));
        }
      });
    }
  }

  Future<void> _triggerItemPicker() async {
    if (_currentStep != 1) {
      setState(() => _currentStep = 1);
    }
    final picked = await showItemPicker(context);
    if (picked == null || !mounted) return;
    final item = _BillLineItem();
    item.itemId = picked['id']?.toString();
    item.description = picked['name']?.toString() ?? '';
    item.unitPrice = (picked['purchasePrice'] as num?)?.toDouble() ?? 0;
    item.purchaseUom =
        picked['purchaseUom']?.toString() ?? picked['unit']?.toString();
    item.baseUom = picked['unit']?.toString();
    item.trackBatches = picked['trackBatches'] == true;
    final pickedTaxGroupId = picked['defaultTaxGroupId']?.toString();
    if (pickedTaxGroupId != null) {
      item.taxGroupId = pickedTaxGroupId;
      final pickedGst = (picked['gstRate'] as num?)?.toDouble();
      item.taxRate = pickedGst ?? 0;
    }
    final secondary = picked['secondaryUnits'] as List?;
    if (secondary != null) {
      item.availableUnits = secondary.cast<Map<String, dynamic>>();
    }
    setState(() {
      if (_lineItems.length == 1 &&
          _lineItems.first.itemId == null &&
          _lineItems.first.description.isEmpty) {
        _lineItems[0] = item;
      } else {
        _lineItems.add(item);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return KKeyboardFormWrapper(
      onSubmit: _currentStep == 2 ? _handleSubmit : _nextStep,
      onNextStep: _nextStep,
      onPrevStep: _prevStep,
      onCancel: () => context.go(Routes.bills),
      onDateJump: _openBillDatePicker,
      onItemPicker: _triggerItemPicker,
      onQuickCreate: _openVendorPicker,
      onAddRow: () => setState(() => _lineItems.add(_BillLineItem())),
      onSaveAndPrint: _handleSubmit,
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Create Bill'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to bills',
          onPressed: () => context.go(Routes.bills),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_outlined),
            tooltip: 'Scan Bill',
            onPressed: _scanBill,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Step indicator
            Container(
              color: KColors.surface,
              padding: const EdgeInsets.symmetric(vertical: 8),
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
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: switch (_currentStep) {
                      0 => _buildVendorStep(),
                      1 => _buildItemsStep(),
                      2 => _buildReviewStep(),
                      _ => const SizedBox(),
                    },
                  ),
                ),
              ),
            ),

            // Bottom bar
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: KSpacing.md,
                vertical: KSpacing.sm,
              ),
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
                          style: KTypography.amountMedium,
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
                          onPressed: () => setState(() => _currentStep--),
                        ),
                      ),
                    if (_currentStep < 2)
                      KButton(
                        label: 'Next',
                        onPressed: _nextStep,
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
    ));
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

        _VendorSelectTile(
          name: _selectedContactId == null
              ? 'Tap to pick a vendor'
              : _vendorName,
          subtitle: _selectedContactId == null
              ? 'Search by name, company, GSTIN or phone'
              : _vendorSubtitle(),
          isSelected: _selectedContactId != null,
          onTap: _openVendorPicker,
        ),

        KSpacing.vGapLg,
        const Divider(),
        KSpacing.vGapMd,

        // Bill metadata
        KCompactRow(children: [
          KTextField(
            label: 'Vendor Bill Number',
            hint: 'e.g. INV-2026-001',
            initialValue: _vendorBillNumber,
            onChanged: (v) => _vendorBillNumber = v,
          ),
          KTextField(
            label: 'Place of Supply',
            hint: 'e.g. Maharashtra',
            initialValue: _placeOfSupply,
            onChanged: (v) => _placeOfSupply = v,
          ),
        ]),
        KSpacing.vGapSm,
        KCompactRow(children: [
          KDatePicker(
            label: 'Bill Date',
            value: _billDate,
            onChanged: (d) => setState(() => _billDate = d),
          ),
          KDatePicker(
            label: 'Due Date',
            value: _dueDate,
            onChanged: (d) => setState(() => _dueDate = d),
            firstDate: _billDate,
          ),
        ]),
        KSpacing.vGapSm,
        SwitchListTile(
          title: const Text('Reverse Charge'),
          subtitle: const Text('Applicable under RCM'),
          value: _reverseCharge,
          onChanged: (v) => setState(() => _reverseCharge = v),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ],
    );
  }

  // ── Step 1: Line Items ──
  Widget _buildItemsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KBillingShortcutBar(
          onDateJump: _openBillDatePicker,
          onItemLookup: _triggerItemPicker,
          onQuickCreate: _openVendorPicker,
          onAddRow: () => setState(() => _lineItems.add(_BillLineItem())),
          onSubmit: _handleSubmit,
        ),
        KSpacing.vGapMd,
        Row(
          children: [
            Expanded(child: Text('Line Items', style: KTypography.h2)),
            TextButton.icon(
              onPressed: _scanBill,
              icon: const Icon(Icons.document_scanner_outlined, size: 18),
              label: const Text('Scan'),
            ),
          ],
        ),
        KSpacing.vGapMd,

        ...List.generate(_lineItems.length, (index) {
          return _BillLineItemCard(
            key: ObjectKey(_lineItems[index]),
            item: _lineItems[index],
            index: index,
            isLastRow: index == _lineItems.length - 1,
            onAddRow: () => setState(() => _lineItems.add(_BillLineItem())),
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
          onPressed: () => setState(() => _lineItems.add(_BillLineItem())),
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
  String lineType = 'GOODS'; // GOODS or SERVICE
  String? itemId;
  String description = '';
  double quantity = 1;
  double unitPrice = 0;
  double taxRate = 0;
  String? taxGroupId;
  String accountCode = '5000';
  bool trackBatches = false;
  bool weightBasedBilling = false;
  String weightUnit = 'KG';
  String batchNumber = '';
  DateTime? manufacturingDate;
  DateTime? expiryDate;
  String? unitUomId;
  double? unitConversionFactor;
  String? baseUom;
  String? purchaseUom;
  double? purchaseUomConversion;
  List<Map<String, dynamic>> availableUnits = [];

  bool get isGoods => lineType == 'GOODS';
  bool get needsItem => isGoods && itemId == null;
  double get taxableAmount => quantity * unitPrice;
  double get taxAmount => taxableAmount * taxRate / 100;
  double get lineTotal => taxableAmount + taxAmount;
}

class _BillLineItemCard extends StatefulWidget {
  final _BillLineItem item;
  final int index;
  final bool isLastRow;
  final VoidCallback? onAddRow;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  const _BillLineItemCard({
    super.key,
    required this.item,
    required this.index,
    this.isLastRow = false,
    this.onAddRow,
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
  String? _selectedUnitAbbr;

  List<Map<String, dynamic>> get _unitOptions {
    final units = <Map<String, dynamic>>[];
    final base = widget.item.baseUom;
    if (base != null && base.isNotEmpty) {
      units.add({
        'abbreviation': base,
        'uomId': null,
        'conversionFactor': 1.0,
        'customPrice': null
      });
    }
    final pUom = widget.item.purchaseUom;
    final pConv = widget.item.purchaseUomConversion;
    if (pUom != null && pConv != null && pConv > 0) {
      units.add({
        'abbreviation': pUom,
        'uomId': null,
        'conversionFactor': pConv,
        'customPrice': null
      });
    }
    for (final u in widget.item.availableUnits) {
      final abbr = u['uomAbbreviation'] ?? u['abbreviation'];
      if (abbr != null && units.every((x) => x['abbreviation'] != abbr)) {
        units.add({
          'abbreviation': abbr,
          'uomId': u['uomId'],
          'conversionFactor': (u['conversionFactor'] as num?)?.toDouble(),
          'customPrice': (u['customPrice'] as num?)?.toDouble(),
        });
      }
    }
    return units;
  }

  @override
  void initState() {
    super.initState();
    _descCtl = TextEditingController(text: widget.item.description);
    _qtyCtl = TextEditingController(text: widget.item.quantity.toString());
    _priceCtl = TextEditingController(text: widget.item.unitPrice.toString());
    _selectedUnitAbbr = widget.item.purchaseUom ?? widget.item.baseUom;
  }

  @override
  void dispose() {
    _descCtl.dispose();
    _qtyCtl.dispose();
    _priceCtl.dispose();
    super.dispose();
  }

  Future<void> _pickItem() async {
    final picked = await showItemPicker(context);
    if (picked == null || !mounted) return;
    final item = widget.item;
    item.itemId = picked['id']?.toString();
    final name = picked['name']?.toString() ?? '';
    if (name.isNotEmpty && item.description.isEmpty) {
      item.description = name;
      _descCtl.text = name;
    }
    final purchasePrice = (picked['purchasePrice'] as num?)?.toDouble();
    if (purchasePrice != null && purchasePrice > 0 && item.unitPrice == 0) {
      item.unitPrice = purchasePrice;
      _priceCtl.text = purchasePrice.toString();
    }
    item.trackBatches = picked['trackBatches'] as bool? ?? false;
    item.weightBasedBilling = picked['weightBasedBilling'] == true;
    if (item.weightBasedBilling) {
      item.weightUnit = 'KG';
    }
    item.baseUom = picked['unitOfMeasure'] as String?;
    final pUom = picked['purchaseUom'] as String?;
    final pConv = (picked['purchaseUomConversion'] as num?)?.toDouble();
    final pPrice = (picked['purchasePricePerUom'] as num?)?.toDouble();
    if (pUom != null && pConv != null && pConv > 0) {
      item.purchaseUom = pUom;
      item.purchaseUomConversion = pConv;
      item.unitUomId = null;
      item.unitConversionFactor = pConv;
      if (pPrice != null && pPrice > 0 && item.unitPrice == 0) {
        item.unitPrice = pPrice;
        _priceCtl.text = pPrice.toString();
      }
    }
    final secondary = picked['secondaryUnits'] as List?;
    if (secondary != null) {
      item.availableUnits = secondary.cast<Map<String, dynamic>>();
    }
    setState(() {
      _selectedUnitAbbr = item.purchaseUom ?? item.baseUom;
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return KCard(
      margin: const EdgeInsets.only(bottom: KSpacing.xs),
      padding: const EdgeInsets.all(KSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Line ${widget.index + 1}', style: KTypography.labelLarge),
              const SizedBox(width: 8),
              ToggleButtons(
                isSelected: [
                  widget.item.lineType == 'GOODS',
                  widget.item.lineType == 'SERVICE',
                ],
                onPressed: (i) {
                  setState(() {
                    widget.item.lineType = i == 0 ? 'GOODS' : 'SERVICE';
                    if (!widget.item.isGoods) {
                      widget.item.itemId = null;
                      widget.item.trackBatches = false;
                    }
                  });
                  widget.onChanged();
                },
                borderRadius: BorderRadius.circular(6),
                constraints: const BoxConstraints(minWidth: 60, minHeight: 28),
                textStyle: KTypography.labelSmall,
                children: const [
                  Text('Goods'),
                  Text('Service'),
                ],
              ),
              const Spacer(),
              if (widget.onRemove != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: KColors.error, size: 20),
                  onPressed: widget.onRemove,
                ),
            ],
          ),
          if (widget.item.isGoods) ...[
            KSpacing.vGapXs,
            InkWell(
              onTap: _pickItem,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: widget.item.needsItem
                        ? KColors.error
                        : KColors.primary.withValues(alpha: 0.4),
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color:
                      widget.item.itemId != null ? KColors.primarySoft : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.item.itemId != null
                          ? Icons.check_circle
                          : Icons.inventory_2_outlined,
                      size: 18,
                      color: widget.item.itemId != null
                          ? KColors.primary
                          : widget.item.needsItem
                              ? KColors.error
                              : KColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.item.itemId != null
                            ? widget.item.description.isNotEmpty
                                ? widget.item.description
                                : 'Item linked'
                            : 'Tap to pick item (required for stock)',
                        style: KTypography.bodySmall.copyWith(
                          color: widget.item.itemId != null
                              ? KColors.primary
                              : widget.item.needsItem
                                  ? KColors.error
                                  : KColors.textSecondary,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 18),
                  ],
                ),
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
          if (_unitOptions.length > 1) ...[
            KSpacing.vGapXs,
            DropdownButtonFormField<String>(
              initialValue: _selectedUnitAbbr,
              decoration: const InputDecoration(
                labelText: 'Unit',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: _unitOptions.map((u) {
                final abbr = u['abbreviation'] as String;
                return DropdownMenuItem(value: abbr, child: Text(abbr));
              }).toList(),
              onChanged: (abbr) {
                if (abbr == null) return;
                final u = _unitOptions.firstWhere(
                    (x) => x['abbreviation'] == abbr,
                    orElse: () => _unitOptions.first);
                setState(() {
                  _selectedUnitAbbr = abbr;
                  widget.item.unitUomId = u['uomId'] as String?;
                  widget.item.unitConversionFactor =
                      (u['conversionFactor'] as num?)?.toDouble();
                  final customPrice = (u['customPrice'] as num?)?.toDouble();
                  if (customPrice != null && customPrice > 0) {
                    widget.item.unitPrice = customPrice;
                    _priceCtl.text = customPrice.toString();
                  }
                });
                widget.onChanged();
              },
            ),
          ],
          KSpacing.vGapXs,
          KCompactRow(children: [
            widget.item.weightBasedBilling
                ? Row(
                    children: [
                      Expanded(
                        child: KTextField(
                          label: 'Weight',
                          controller: _qtyCtl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
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
                    label: (widget.item.unitConversionFactor ??
                                widget.item.purchaseUomConversion ??
                                1.0) >
                            1.0
                        ? 'Qty (${_selectedUnitAbbr ?? widget.item.purchaseUom ?? 'BOX'}/${widget.item.baseUom ?? 'PCS'})'
                        : 'Qty',
                    hint: (widget.item.unitConversionFactor ??
                                widget.item.purchaseUomConversion ??
                                1.0) >
                            1.0
                        ? 'e.g. 10.5 or 10/5'
                        : '1',
                    controller: _qtyCtl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) {
                      final conv = widget.item.unitConversionFactor ??
                          widget.item.purchaseUomConversion ??
                          1.0;
                      if (conv > 1.0) {
                        final dual = DualUomParser.parse(
                          v,
                          conversionFactor: conv,
                          mainUnit: _selectedUnitAbbr ??
                              widget.item.purchaseUom ??
                              'BOX',
                          subUnit: widget.item.baseUom,
                        );
                        widget.item.quantity = dual.totalMainQty;
                      } else {
                        widget.item.quantity = double.tryParse(v) ?? 1;
                      }
                      widget.onChanged();
                    },
                  ),
            KTextField.amount(
              label: widget.item.weightBasedBilling ? 'Rate/kg' : 'Price',
              controller: _priceCtl,
              textInputAction: widget.isLastRow
                  ? TextInputAction.done
                  : TextInputAction.next,
              onFieldSubmitted: (_) {
                if (widget.isLastRow) {
                  widget.onAddRow?.call();
                } else {
                  FocusScope.of(context).nextFocus();
                }
              },
              onChanged: (v) {
                widget.item.unitPrice = double.tryParse(v) ?? 0;
                widget.onChanged();
              },
            ),
          ]),
          if (!widget.item.weightBasedBilling &&
              (widget.item.unitConversionFactor ??
                      widget.item.purchaseUomConversion ??
                      1.0) >
                  1.0 &&
              widget.item.quantity > 0) ...[
            Builder(builder: (context) {
              final conv = widget.item.unitConversionFactor ??
                  widget.item.purchaseUomConversion ??
                  1.0;
              final dual = DualUomParser.parse(
                DualUomParser.formatInput(widget.item.quantity, conv),
                conversionFactor: conv,
                mainUnit: _selectedUnitAbbr ?? widget.item.purchaseUom ?? 'BOX',
                subUnit: widget.item.baseUom ?? 'PCS',
              );
              return Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.layers_outlined,
                        size: 12,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      dual.displayText,
                      style: KTypography.labelSmall.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          KSpacing.vGapXs,
          Row(
            children: [
              Expanded(
                child: TaxGroupPicker(
                  value: widget.item.taxGroupId,
                  label: 'Tax Group',
                  onChanged: (group) {
                    widget.item.taxGroupId = group?.id;
                    widget.item.taxRate = group?.totalRate ?? 0;
                    widget.onChanged();
                  },
                ),
              ),
              KSpacing.hGapMd,
              Text(
                CurrencyFormatter.formatIndian(widget.item.lineTotal),
                style: KTypography.amountSmall.copyWith(
                  color: KColors.primary,
                ),
              ),
            ],
          ),
          if (widget.item.trackBatches) ...[
            KSpacing.vGapXs,
            Container(
              padding: const EdgeInsets.all(KSpacing.sm),
              decoration: BoxDecoration(
                color: KColors.info.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: KColors.info.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Batch Details',
                      style: KTypography.labelMedium
                          .copyWith(color: KColors.info)),
                  KSpacing.vGapXs,
                  KTextField(
                    label: 'Batch Number *',
                    initialValue: widget.item.batchNumber,
                    onChanged: (v) {
                      widget.item.batchNumber = v;
                      widget.onChanged();
                    },
                  ),
                  KSpacing.vGapXs,
                  KCompactRow(children: [
                    KDatePicker(
                      label: 'Mfg Date',
                      value: widget.item.manufacturingDate,
                      lastDate: DateTime.now(),
                      onChanged: (d) {
                        setState(() => widget.item.manufacturingDate = d);
                        widget.onChanged();
                      },
                    ),
                    KDatePicker(
                      label: 'Expiry Date',
                      value: widget.item.expiryDate,
                      firstDate: DateTime.now(),
                      onChanged: (d) {
                        setState(() => widget.item.expiryDate = d);
                        widget.onChanged();
                      },
                    ),
                  ]),
                ],
              ),
            ),
          ],
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
              color:
                  isActive || isCompleted ? KColors.primary : KColors.divider,
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
