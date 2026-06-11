import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../../ai_chat/data/ai_repository.dart';

/// Shows a bottom sheet that lets the user scan a bill image, review/edit
/// extracted fields, and returns populated data to pre-fill the bill form.
///
/// Returns `null` if the user cancels.
Future<Map<String, dynamic>?> showBillScanSheet(BuildContext context) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scroll) => _BillScanSheet(scrollController: scroll),
    ),
  );
}

enum _Phase { picker, scanning, review }

class _BillScanSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;

  const _BillScanSheet({required this.scrollController});

  @override
  ConsumerState<_BillScanSheet> createState() => _BillScanSheetState();
}

class _BillScanSheetState extends ConsumerState<_BillScanSheet> {
  final _picker = ImagePicker();
  _Phase _phase = _Phase.picker;
  String? _error;
  String? _previewPath;
  double _confidence = 0;
  bool _posting = false;

  // Editable fields
  late TextEditingController _vendorNameCtrl;
  late TextEditingController _vendorGstinCtrl;
  late TextEditingController _invoiceNumberCtrl;
  DateTime? _billDate;
  DateTime? _dueDate;
  List<_LineItemData> _lineItems = [];

  @override
  void initState() {
    super.initState();
    _vendorNameCtrl = TextEditingController();
    _vendorGstinCtrl = TextEditingController();
    _invoiceNumberCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _vendorNameCtrl.dispose();
    _vendorGstinCtrl.dispose();
    _invoiceNumberCtrl.dispose();
    for (final item in _lineItems) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _pickAndScan(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() {
        _phase = _Phase.scanning;
        _error = null;
        _previewPath = picked.path;
      });

      final bytes = await picked.readAsBytes();
      final base64Image = base64Encode(bytes);

      final aiRepo = ref.read(aiRepositoryProvider);
      final result = await aiRepo.scanBill(base64Image);

      if (!mounted) return;

      final data = (result['data'] ?? result) as Map<String, dynamic>;
      _populateFields(data);

      setState(() {
        _phase = _Phase.review;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('[BillScan] Error: $e');
      setState(() {
        _phase = _Phase.picker;
        _error = 'Scan failed: ${e.toString().replaceAll('Exception: ', '')}';
      });
    }
  }

  void _populateFields(Map<String, dynamic> data) {
    _vendorNameCtrl.text = data['vendorName']?.toString() ?? '';
    _vendorGstinCtrl.text = data['vendorGstin']?.toString() ?? '';
    _invoiceNumberCtrl.text = data['invoiceNumber']?.toString() ?? '';
    _billDate = DateTime.tryParse(data['invoiceDate']?.toString() ?? '') ??
        DateTime.now();
    _dueDate = DateTime.tryParse(data['dueDate']?.toString() ?? '');
    _confidence = (data['confidence'] as num?)?.toDouble() ?? 0;

    // Dispose old line items
    for (final item in _lineItems) {
      item.dispose();
    }

    final rawItems = data['lineItems'] as List? ?? [];
    _lineItems = rawItems.map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      return _LineItemData.fromMap(map);
    }).toList();

    if (_lineItems.isEmpty) {
      _lineItems.add(_LineItemData.empty());
    }
  }

  void _resetToPhase(_Phase phase) {
    setState(() {
      _phase = phase;
      _error = null;
      if (phase == _Phase.picker) {
        _previewPath = null;
      }
    });
  }

  void _addLineItem() {
    setState(() {
      _lineItems.add(_LineItemData.empty());
    });
  }

  void _removeLineItem(int index) {
    if (_lineItems.length <= 1) return;
    setState(() {
      _lineItems[index].dispose();
      _lineItems.removeAt(index);
    });
  }

  double get _subtotal {
    double total = 0;
    for (final item in _lineItems) {
      total += item.lineTotal;
    }
    return total;
  }

  double get _taxTotal {
    double total = 0;
    for (final item in _lineItems) {
      total += item.lineTotal * (item.gstRate / 100);
    }
    return total;
  }

  double get _grandTotal => _subtotal + _taxTotal;

  Map<String, dynamic> _buildReturnValue() {
    return {
      'vendorName': _vendorNameCtrl.text,
      'vendorGstin': _vendorGstinCtrl.text,
      'invoiceNumber': _invoiceNumberCtrl.text,
      'billDate': _billDate ?? DateTime.now(),
      'dueDate': _dueDate ?? DateTime.now(),
      'lineItems': _lineItems.map((item) => item.toMap()).toList(),
      'confidence': _confidence,
    };
  }

  /// "Draft, don't type": send the (reviewed) scan to the backend, which drafts
  /// a DRAFT bill, then approve it to post — all in one tap. Pops with a
  /// `{'posted': true, ...}` result so the caller skips the manual form.
  Future<void> _approveAndPost() async {
    if (_posting) return;
    setState(() => _posting = true);
    try {
      final aiRepo = ref.read(aiRepositoryProvider);
      final draft = await aiRepo.draftBillFromScan(_buildDraftPayload());
      final suggestionId = draft['suggestionId']?.toString();
      if (suggestionId == null || suggestionId.isEmpty) {
        throw Exception('Draft did not return a suggestion');
      }
      final posted = await aiRepo.approveBillDraft(suggestionId);
      if (!mounted) return;
      Navigator.pop(context, {
        'posted': true,
        'billId':
            posted['billId']?.toString() ?? draft['billId']?.toString(),
        'billNumber': posted['billNumber']?.toString() ??
            draft['billNumber']?.toString(),
        'status': posted['status']?.toString(),
        'vendorCreated': draft['vendorCreated'] == true,
        'warnings': (draft['warnings'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[],
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _posting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Could not post bill: ${e.toString().replaceAll('Exception: ', '')}'),
        ),
      );
    }
  }

  Map<String, dynamic> _buildDraftPayload() {
    final gstin = _vendorGstinCtrl.text.trim();
    return {
      'vendorName': _vendorNameCtrl.text.trim(),
      if (gstin.isNotEmpty) 'vendorGstin': gstin,
      // First two GSTIN digits are the GST state code (place of supply).
      if (gstin.length >= 2) 'vendorStateCode': gstin.substring(0, 2),
      'invoiceNumber': _invoiceNumberCtrl.text.trim(),
      if (_billDate != null) 'billDate': _isoDate(_billDate!),
      if (_dueDate != null) 'dueDate': _isoDate(_dueDate!),
      'confidence': _confidence,
      'lines': _lineItems
          .where((l) => l.descriptionCtrl.text.trim().isNotEmpty)
          .map((l) => {
                'description': l.descriptionCtrl.text.trim(),
                if (l.hsnCodeCtrl.text.trim().isNotEmpty)
                  'hsnCode': l.hsnCodeCtrl.text.trim(),
                'quantity': l.quantity,
                'unitPrice': l.unitPrice,
                'gstRate': l.gstRate,
              })
          .toList(),
    };
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
                KSpacing.md, KSpacing.md, KSpacing.md, KSpacing.sm),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, color: KColors.primary),
                KSpacing.hGapSm,
                Expanded(
                  child: Text('Scan Bill', style: KTypography.h3),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: switch (_phase) {
              _Phase.picker => _buildPickerUI(),
              _Phase.scanning => _buildScanning(),
              _Phase.review => _buildReview(),
            },
          ),
        ],
      ),
    );
  }

  // ─── Phase 1: Image Picker ──────────────────────────────────────────────

  Widget _buildPickerUI() {
    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: KSpacing.pagePadding,
      child: Column(
        children: [
          KSpacing.vGapLg,
          const Icon(
            Icons.document_scanner_outlined,
            size: 64,
            color: KColors.textHint,
          ),
          KSpacing.vGapMd,
          Text(
            'Take a photo of the bill or invoice',
            style: KTypography.bodyMedium.copyWith(color: KColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          KSpacing.vGapSm,
          Text(
            'AI will extract vendor details, line items, and tax info',
            style: KTypography.bodySmall.copyWith(color: KColors.textHint),
            textAlign: TextAlign.center,
          ),
          if (_error != null) ...[
            KSpacing.vGapMd,
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: KColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: KColors.error, size: 18),
                  KSpacing.hGapSm,
                  Expanded(
                    child: Text(_error!,
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.error)),
                  ),
                ],
              ),
            ),
          ],
          KSpacing.vGapLg,
          Row(
            children: [
              Expanded(
                child: _ScanOptionCard(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  subtitle: 'Take a photo now',
                  onTap: () => _pickAndScan(ImageSource.camera),
                ),
              ),
              KSpacing.hGapMd,
              Expanded(
                child: _ScanOptionCard(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  subtitle: 'Pick from photos',
                  onTap: () => _pickAndScan(ImageSource.gallery),
                ),
              ),
            ],
          ),
          KSpacing.vGapLg,
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: KColors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline,
                    color: KColors.info, size: 18),
                KSpacing.hGapSm,
                Expanded(
                  child: Text(
                    'Tip: Capture the full bill including vendor name, items table, and totals. Hold steady for best results.',
                    style: KTypography.bodySmall.copyWith(color: KColors.info),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Phase 2: Scanning Animation ───────────────────────────────────────

  Widget _buildScanning() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_previewPath != null && !kIsWeb)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(_previewPath!),
              height: 200,
              fit: BoxFit.contain,
            ),
          ),
        KSpacing.vGapLg,
        const CircularProgressIndicator(),
        KSpacing.vGapMd,
        Text('Analyzing bill...', style: KTypography.bodyMedium),
        KSpacing.vGapSm,
        Text(
          'Extracting vendor, items, and tax details',
          style: KTypography.bodySmall.copyWith(color: KColors.textHint),
        ),
      ],
    );
  }

  // ─── Phase 3: Editable Review ──────────────────────────────────────────

  Widget _buildReview() {
    return Column(
      children: [
        // Confidence bar
        _buildConfidenceBar(),
        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: KSpacing.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildVendorSection(),
                KSpacing.vGapMd,
                _buildLineItemsSection(),
                KSpacing.vGapMd,
                _buildTotalsSection(),
                KSpacing.vGapLg,
              ],
            ),
          ),
        ),
        // Bottom action bar
        _buildBottomActions(),
      ],
    );
  }

  Widget _buildConfidenceBar() {
    final isHigh = _confidence >= 0.7;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.md, vertical: KSpacing.sm),
      color: isHigh
          ? KColors.success.withValues(alpha: 0.08)
          : KColors.warning.withValues(alpha: 0.08),
      child: Row(
        children: [
          Icon(
            isHigh ? Icons.check_circle : Icons.info_outline,
            size: 16,
            color: isHigh ? KColors.success : KColors.warning,
          ),
          KSpacing.hGapSm,
          Text(
            'Confidence: ${(_confidence * 100).toStringAsFixed(0)}%',
            style: KTypography.labelSmall.copyWith(
              color: isHigh ? KColors.success : KColors.warning,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _resetToPhase(_Phase.picker),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Rescan'),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorSection() {
    return KCard(
      title: 'Vendor & Invoice Details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KTextField(
            label: 'Vendor Name',
            controller: _vendorNameCtrl,
            hint: 'e.g. ABC Traders',
          ),
          KSpacing.vGapMd,
          KTextField(
            label: 'Vendor GSTIN',
            controller: _vendorGstinCtrl,
            hint: 'e.g. 27AABCT1234A1Z5',
          ),
          KSpacing.vGapMd,
          KTextField(
            label: 'Invoice Number',
            controller: _invoiceNumberCtrl,
            hint: 'e.g. INV-2025-001',
          ),
          KSpacing.vGapMd,
          KDatePicker(
            label: 'Bill Date',
            value: _billDate,
            onChanged: (date) => setState(() => _billDate = date),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
          ),
          KSpacing.vGapMd,
          KDatePicker(
            label: 'Due Date',
            value: _dueDate,
            onChanged: (date) => setState(() => _dueDate = date),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
          ),
        ],
      ),
    );
  }

  Widget _buildLineItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Line Items', style: KTypography.h3),
            const Spacer(),
            TextButton.icon(
              onPressed: _addLineItem,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Item'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ],
        ),
        KSpacing.vGapSm,
        ...List.generate(_lineItems.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: KSpacing.sm),
            child: _buildLineItemCard(index),
          );
        }),
      ],
    );
  }

  Widget _buildLineItemCard(int index) {
    final item = _lineItems[index];
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: KColors.primarySoft,
                child: Text(
                  '${index + 1}',
                  style:
                      KTypography.labelSmall.copyWith(color: KColors.primary),
                ),
              ),
              KSpacing.hGapSm,
              Expanded(
                child: Text('Item ${index + 1}', style: KTypography.labelLarge),
              ),
              if (_lineItems.length > 1)
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: KColors.error),
                  onPressed: () => _removeLineItem(index),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Remove item',
                ),
            ],
          ),
          KSpacing.vGapSm,
          KTextField(
            label: 'Description',
            controller: item.descriptionCtrl,
            hint: 'Item name or description',
            onChanged: (_) => setState(() {}),
          ),
          KSpacing.vGapSm,
          KTextField(
            label: 'HSN Code',
            controller: item.hsnCodeCtrl,
            hint: 'e.g. 1234',
            onChanged: (_) => setState(() {}),
          ),
          KSpacing.vGapSm,
          Row(
            children: [
              Expanded(
                child: KTextField.amount(
                  label: 'Quantity',
                  controller: item.quantityCtrl,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              KSpacing.hGapMd,
              Expanded(
                child: KTextField.amount(
                  label: 'Unit Price',
                  controller: item.unitPriceCtrl,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          KSpacing.vGapSm,
          Row(
            children: [
              Expanded(
                child: KTextField(
                  label: 'GST Rate (%)',
                  controller: item.gstRateCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  hint: 'e.g. 5',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              KSpacing.hGapMd,
              Expanded(
                child: KTextField.amount(
                  label: 'MRP',
                  controller: item.mrpCtrl,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          KSpacing.vGapSm,
          // Pharma: batch + expiry + free qty
          Container(
            padding: const EdgeInsets.all(KSpacing.sm),
            decoration: BoxDecoration(
              color: KColors.info.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(KSpacing.radiusSm),
              border: Border.all(color: KColors.info.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.medical_services_outlined,
                        size: 14, color: KColors.info),
                    KSpacing.hGapSm,
                    Text('Batch & Expiry',
                        style: KTypography.labelSmall
                            .copyWith(color: KColors.info)),
                  ],
                ),
                KSpacing.vGapSm,
                Row(
                  children: [
                    Expanded(
                      child: KTextField(
                        label: 'Batch No.',
                        controller: item.batchCtrl,
                        hint: 'e.g. NM4820054A',
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    KSpacing.hGapMd,
                    Expanded(
                      child: KTextField(
                        label: 'Free Qty',
                        controller: item.freeQtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        hint: '0',
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                KSpacing.vGapSm,
                KDatePicker(
                  label: 'Expiry Date',
                  value: item.expiryDate,
                  onChanged: (date) =>
                      setState(() => item.expiryDate = date),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2040),
                ),
              ],
            ),
          ),
          KSpacing.vGapSm,
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: KSpacing.sm, vertical: KSpacing.xs),
            decoration: BoxDecoration(
              color: KColors.primarySoft,
              borderRadius: BorderRadius.circular(KSpacing.radiusSm),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Line Total',
                    style: KTypography.labelSmall
                        .copyWith(color: KColors.textSecondary)),
                Text(
                  CurrencyFormatter.formatIndian(item.lineTotal),
                  style:
                      KTypography.labelLarge.copyWith(color: KColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsSection() {
    return KCard(
      title: 'Totals',
      child: Column(
        children: [
          _totalRow('Subtotal', _subtotal),
          KSpacing.vGapXs,
          _totalRow('Tax (GST)', _taxTotal),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: KSpacing.xs),
            child: Divider(height: 1),
          ),
          _totalRow('Total', _grandTotal, bold: true),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double value, {bool bold = false}) {
    final style = bold ? KTypography.labelLarge : KTypography.bodyMedium;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style.copyWith(color: KColors.textSecondary)),
        Text(
          CurrencyFormatter.formatIndian(value),
          style: style.copyWith(
            color: bold ? KColors.primary : null,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: KButton(
              label: _posting ? 'Posting…' : 'Approve & Post',
              icon: Icons.task_alt,
              isLoading: _posting,
              onPressed: _approveAndPost,
            ),
          ),
          KSpacing.vGapSm,
          Row(
            children: [
              Expanded(
                child: KButton(
                  label: 'Rescan',
                  variant: KButtonVariant.outlined,
                  icon: Icons.refresh,
                  onPressed: _posting ? null : () => _resetToPhase(_Phase.picker),
                ),
              ),
              KSpacing.hGapMd,
              Expanded(
                child: KButton(
                  label: 'Edit in form',
                  variant: KButtonVariant.outlined,
                  icon: Icons.edit_outlined,
                  onPressed: _posting
                      ? null
                      : () => Navigator.pop(context, _buildReturnValue()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Scan Option Card ──────────────────────────────────────────────────────

class _ScanOptionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ScanOptionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          Icon(icon, size: 36, color: KColors.primary),
          KSpacing.vGapSm,
          Text(label, style: KTypography.labelLarge),
          const SizedBox(height: 2),
          Text(subtitle,
              style: KTypography.bodySmall.copyWith(color: KColors.textHint)),
        ],
      ),
    );
  }
}

// ─── Line Item Data Model ──────────────────────────────────────────────────

class _LineItemData {
  final TextEditingController descriptionCtrl;
  final TextEditingController hsnCodeCtrl;
  final TextEditingController quantityCtrl;
  final TextEditingController unitPriceCtrl;
  final TextEditingController gstRateCtrl;
  final TextEditingController batchCtrl;
  final TextEditingController mrpCtrl;
  final TextEditingController freeQtyCtrl;
  DateTime? expiryDate;

  _LineItemData({
    required this.descriptionCtrl,
    required this.hsnCodeCtrl,
    required this.quantityCtrl,
    required this.unitPriceCtrl,
    required this.gstRateCtrl,
    required this.batchCtrl,
    required this.mrpCtrl,
    required this.freeQtyCtrl,
    this.expiryDate,
  });

  factory _LineItemData.fromMap(Map<String, dynamic> map) {
    return _LineItemData(
      descriptionCtrl:
          TextEditingController(text: map['description']?.toString() ?? ''),
      hsnCodeCtrl:
          TextEditingController(text: map['hsnCode']?.toString() ?? ''),
      quantityCtrl: TextEditingController(
          text: (map['quantity'] as num?)?.toString() ?? '1'),
      unitPriceCtrl: TextEditingController(
          text: (map['unitPrice'] as num?)?.toString() ?? '0'),
      gstRateCtrl: TextEditingController(
          text: (map['gstRate'] as num?)?.toString() ?? '0'),
      batchCtrl:
          TextEditingController(text: map['batchNumber']?.toString() ?? ''),
      mrpCtrl: TextEditingController(
          text: (map['mrp'] as num?)?.toString() ?? ''),
      freeQtyCtrl: TextEditingController(
          text: (map['freeQuantity'] as num?)?.toString() ?? '0'),
      expiryDate: DateTime.tryParse(map['expiryDate']?.toString() ?? ''),
    );
  }

  factory _LineItemData.empty() {
    return _LineItemData(
      descriptionCtrl: TextEditingController(),
      hsnCodeCtrl: TextEditingController(),
      quantityCtrl: TextEditingController(text: '1'),
      unitPriceCtrl: TextEditingController(text: '0'),
      gstRateCtrl: TextEditingController(text: '0'),
      batchCtrl: TextEditingController(),
      mrpCtrl: TextEditingController(),
      freeQtyCtrl: TextEditingController(text: '0'),
    );
  }

  double get quantity => double.tryParse(quantityCtrl.text) ?? 0;
  double get unitPrice => double.tryParse(unitPriceCtrl.text) ?? 0;
  double get gstRate => double.tryParse(gstRateCtrl.text) ?? 0;
  double get mrp => double.tryParse(mrpCtrl.text) ?? 0;
  double get freeQuantity => double.tryParse(freeQtyCtrl.text) ?? 0;
  double get lineTotal => quantity * unitPrice;

  Map<String, dynamic> toMap() {
    return {
      'description': descriptionCtrl.text,
      'hsnCode': hsnCodeCtrl.text.isEmpty ? null : hsnCodeCtrl.text,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'gstRate': gstRate,
      'batchNumber': batchCtrl.text.isEmpty ? null : batchCtrl.text,
      'expiryDate': expiryDate,
      'mrp': mrp,
      'freeQuantity': freeQuantity,
    };
  }

  void dispose() {
    descriptionCtrl.dispose();
    hsnCodeCtrl.dispose();
    quantityCtrl.dispose();
    unitPriceCtrl.dispose();
    gstRateCtrl.dispose();
    batchCtrl.dispose();
    mrpCtrl.dispose();
    freeQtyCtrl.dispose();
  }
}
