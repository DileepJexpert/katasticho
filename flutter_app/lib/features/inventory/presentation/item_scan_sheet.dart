import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../ai_chat/data/ai_repository.dart';

enum _ScanMode { label, invoice }

/// Shows a bottom sheet that lets the user pick an image (camera/gallery),
/// sends it to the AI scan endpoint, and returns extracted item data.
///
/// For [mode] == label: returns a single item map.
/// For [mode] == invoice: returns a list of item maps.
Future<List<Map<String, dynamic>>?> showItemScanSheet(
  BuildContext context, {
  bool purchaseInvoice = false,
}) {
  return showModalBottomSheet<List<Map<String, dynamic>>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scroll) => _ItemScanSheet(
        scrollController: scroll,
        mode: purchaseInvoice ? _ScanMode.invoice : _ScanMode.label,
      ),
    ),
  );
}

class _ItemScanSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final _ScanMode mode;

  const _ItemScanSheet({
    required this.scrollController,
    required this.mode,
  });

  @override
  ConsumerState<_ItemScanSheet> createState() => _ItemScanSheetState();
}

class _ItemScanSheetState extends ConsumerState<_ItemScanSheet> {
  final _picker = ImagePicker();
  bool _scanning = false;
  String? _error;
  List<Map<String, dynamic>> _scannedItems = [];
  double _confidence = 0;
  String? _previewPath;

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
        _scanning = true;
        _error = null;
        _scannedItems = [];
        _previewPath = picked.path;
      });

      final bytes = await picked.readAsBytes();
      final base64Image = base64Encode(bytes);
      final mediaType = picked.mimeType ?? 'image/jpeg';

      final aiRepo = ref.read(aiRepositoryProvider);
      final Map<String, dynamic> result;

      if (widget.mode == _ScanMode.invoice) {
        result = await aiRepo.scanPurchaseInvoice(base64Image, mediaType: mediaType);
      } else {
        result = await aiRepo.scanProductLabel(base64Image, mediaType: mediaType);
      }

      if (!mounted) return;

      final data = (result['data'] ?? result) as Map<String, dynamic>;
      final items = (data['items'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      final confidence = (data['confidence'] as num?)?.toDouble() ?? 0;

      setState(() {
        _scanning = false;
        _scannedItems = items;
        _confidence = confidence;
        if (items.isEmpty) {
          _error = 'No items detected. Try a clearer photo.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('[ItemScan] Error: $e');
      setState(() {
        _scanning = false;
        _error = 'Scan failed: ${e.toString().replaceAll('Exception: ', '')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLabel = widget.mode == _ScanMode.label;

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
                Icon(
                  isLabel ? Icons.camera_alt : Icons.receipt_long,
                  color: KColors.primary,
                ),
                KSpacing.hGapSm,
                Expanded(
                  child: Text(
                    isLabel ? 'Scan Product Label' : 'Scan Purchase Invoice',
                    style: KTypography.h3,
                  ),
                ),
                if (_scannedItems.isNotEmpty)
                  TextButton(
                    onPressed: () => Navigator.pop(context, _scannedItems),
                    child: Text('Use ${_scannedItems.length} item${_scannedItems.length == 1 ? '' : 's'}'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _scanning
                ? _buildScanning()
                : _scannedItems.isEmpty
                    ? _buildPickerUI(isLabel)
                    : _buildResults(),
          ),
        ],
      ),
    );
  }

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
        Text('Analyzing image...', style: KTypography.bodyMedium),
        KSpacing.vGapSm,
        Text(
          'This may take a few seconds',
          style: KTypography.bodySmall.copyWith(color: KColors.textHint),
        ),
      ],
    );
  }

  Widget _buildPickerUI(bool isLabel) {
    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: KSpacing.pagePadding,
      child: Column(
        children: [
          KSpacing.vGapLg,
          Icon(
            isLabel ? Icons.photo_camera_outlined : Icons.document_scanner_outlined,
            size: 64,
            color: KColors.textHint,
          ),
          KSpacing.vGapMd,
          Text(
            isLabel
                ? 'Take a photo of the product label or packaging'
                : 'Take a photo of the purchase invoice/bill',
            style: KTypography.bodyMedium.copyWith(color: KColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          KSpacing.vGapSm,
          Text(
            isLabel
                ? 'AI will extract name, MRP, barcode, brand, and more'
                : 'AI will extract all items with prices from the invoice',
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
                  const Icon(Icons.error_outline, color: KColors.error, size: 18),
                  KSpacing.hGapSm,
                  Expanded(
                    child: Text(_error!,
                        style: KTypography.bodySmall.copyWith(color: KColors.error)),
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
                const Icon(Icons.lightbulb_outline, color: KColors.info, size: 18),
                KSpacing.hGapSm,
                Expanded(
                  child: Text(
                    isLabel
                        ? 'Tip: Make sure the product name and MRP are clearly visible. Hold steady for best results.'
                        : 'Tip: Capture the full item table. Multiple pages? Scan each page separately.',
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

  Widget _buildResults() {
    return Column(
      children: [
        // Confidence bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: KSpacing.md, vertical: 8),
          color: _confidence >= 0.7
              ? KColors.success.withValues(alpha: 0.08)
              : KColors.warning.withValues(alpha: 0.08),
          child: Row(
            children: [
              Icon(
                _confidence >= 0.7 ? Icons.check_circle : Icons.info_outline,
                size: 16,
                color: _confidence >= 0.7 ? KColors.success : KColors.warning,
              ),
              KSpacing.hGapSm,
              Text(
                'Confidence: ${(_confidence * 100).toStringAsFixed(0)}%',
                style: KTypography.labelSmall.copyWith(
                  color: _confidence >= 0.7 ? KColors.success : KColors.warning,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() {
                  _scannedItems = [];
                  _error = null;
                  _previewPath = null;
                }),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Rescan'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
        // Items list
        Expanded(
          child: ListView.separated(
            controller: widget.scrollController,
            padding: KSpacing.pagePadding,
            itemCount: _scannedItems.length,
            separatorBuilder: (_, __) => KSpacing.vGapSm,
            itemBuilder: (context, index) {
              final item = _scannedItems[index];
              return _ScannedItemCard(
                item: item,
                index: index,
                onUse: () => Navigator.pop(context, [item]),
                onRemove: () {
                  setState(() => _scannedItems.removeAt(index));
                  if (_scannedItems.isEmpty) {
                    setState(() => _error = null);
                  }
                },
                onUpdate: (updated) {
                  setState(() => _scannedItems[index] = updated);
                },
              );
            },
          ),
        ),
        // Bottom action bar
        if (_scannedItems.length > 1)
          Container(
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
            child: KButton(
              label: 'Use All ${_scannedItems.length} Items',
              icon: Icons.check,
              onPressed: () => Navigator.pop(context, _scannedItems),
            ),
          ),
      ],
    );
  }
}

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

class _ScannedItemCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final int index;
  final VoidCallback onUse;
  final VoidCallback onRemove;
  final ValueChanged<Map<String, dynamic>> onUpdate;

  const _ScannedItemCard({
    required this.item,
    required this.index,
    required this.onUse,
    required this.onRemove,
    required this.onUpdate,
  });

  @override
  State<_ScannedItemCard> createState() => _ScannedItemCardState();
}

class _ScannedItemCardState extends State<_ScannedItemCard> {
  bool _editing = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _brandCtrl;
  late TextEditingController _mrpCtrl;
  late TextEditingController _purchasePriceCtrl;
  late TextEditingController _barcodeCtrl;
  late TextEditingController _categoryCtrl;
  late TextEditingController _gstRateCtrl;
  late TextEditingController _hsnCodeCtrl;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    _nameCtrl = TextEditingController(text: widget.item['name']?.toString() ?? '');
    _brandCtrl = TextEditingController(text: widget.item['brand']?.toString() ?? '');
    _mrpCtrl = TextEditingController(text: widget.item['mrp']?.toString() ?? '');
    _purchasePriceCtrl = TextEditingController(text: widget.item['purchasePrice']?.toString() ?? '');
    _barcodeCtrl = TextEditingController(text: widget.item['barcode']?.toString() ?? '');
    _categoryCtrl = TextEditingController(text: widget.item['category']?.toString() ?? '');
    _gstRateCtrl = TextEditingController(text: widget.item['gstRate']?.toString() ?? '');
    _hsnCodeCtrl = TextEditingController(text: widget.item['hsnCode']?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _mrpCtrl.dispose();
    _purchasePriceCtrl.dispose();
    _barcodeCtrl.dispose();
    _categoryCtrl.dispose();
    _gstRateCtrl.dispose();
    _hsnCodeCtrl.dispose();
    super.dispose();
  }

  void _startEditing() {
    _nameCtrl.text = widget.item['name']?.toString() ?? '';
    _brandCtrl.text = widget.item['brand']?.toString() ?? '';
    _mrpCtrl.text = widget.item['mrp']?.toString() ?? '';
    _purchasePriceCtrl.text = widget.item['purchasePrice']?.toString() ?? '';
    _barcodeCtrl.text = widget.item['barcode']?.toString() ?? '';
    _categoryCtrl.text = widget.item['category']?.toString() ?? '';
    _gstRateCtrl.text = widget.item['gstRate']?.toString() ?? '';
    _hsnCodeCtrl.text = widget.item['hsnCode']?.toString() ?? '';
    setState(() => _editing = true);
  }

  void _cancelEditing() {
    setState(() => _editing = false);
  }

  void _doneEditing() {
    final updated = Map<String, dynamic>.from(widget.item);
    updated['name'] = _nameCtrl.text.trim();
    updated['brand'] = _brandCtrl.text.trim();
    final mrpVal = double.tryParse(_mrpCtrl.text.trim());
    updated['mrp'] = mrpVal ?? (_mrpCtrl.text.trim().isEmpty ? null : _mrpCtrl.text.trim());
    final ppVal = double.tryParse(_purchasePriceCtrl.text.trim());
    updated['purchasePrice'] = ppVal ?? (_purchasePriceCtrl.text.trim().isEmpty ? null : _purchasePriceCtrl.text.trim());
    updated['barcode'] = _barcodeCtrl.text.trim();
    updated['category'] = _categoryCtrl.text.trim();
    final gstVal = double.tryParse(_gstRateCtrl.text.trim());
    updated['gstRate'] = gstVal ?? (_gstRateCtrl.text.trim().isEmpty ? null : _gstRateCtrl.text.trim());
    updated['hsnCode'] = _hsnCodeCtrl.text.trim();
    widget.onUpdate(updated);
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return _buildEditingView();
    }
    return _buildReadOnlyView();
  }

  Widget _buildReadOnlyView() {
    final name = widget.item['name']?.toString() ?? 'Unknown';
    final brand = widget.item['brand']?.toString();
    final mrp = widget.item['mrp'];
    final purchasePrice = widget.item['purchasePrice'];
    final barcode = widget.item['barcode']?.toString();
    final category = widget.item['category']?.toString();
    final gstRate = widget.item['gstRate'];

    return KCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: KColors.primarySoft,
                child: Text(
                  '${widget.index + 1}',
                  style: KTypography.labelSmall.copyWith(color: KColors.primary),
                ),
              ),
              KSpacing.hGapSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: KTypography.labelLarge),
                    if (brand != null && brand.isNotEmpty)
                      Text(brand,
                          style: KTypography.bodySmall
                              .copyWith(color: KColors.textSecondary)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: _startEditing,
                visualDensity: VisualDensity.compact,
                tooltip: 'Edit',
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: widget.onRemove,
                visualDensity: VisualDensity.compact,
                tooltip: 'Remove',
              ),
            ],
          ),
          KSpacing.vGapSm,
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (mrp != null)
                _chip('MRP ₹$mrp'),
              if (purchasePrice != null)
                _chip('Cost ₹$purchasePrice'),
              if (barcode != null && barcode.isNotEmpty)
                _chip(barcode),
              if (category != null && category.isNotEmpty)
                _chip(category),
              if (gstRate != null)
                _chip('GST $gstRate%'),
            ],
          ),
          KSpacing.vGapSm,
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: widget.onUse,
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Use This Item'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditingView() {
    return KCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: KColors.primarySoft,
                child: Text(
                  '${widget.index + 1}',
                  style: KTypography.labelSmall.copyWith(color: KColors.primary),
                ),
              ),
              KSpacing.hGapSm,
              Expanded(
                child: Text('Edit Item', style: KTypography.labelLarge),
              ),
            ],
          ),
          KSpacing.vGapSm,
          KTextField(
            label: 'Name',
            controller: _nameCtrl,
          ),
          KSpacing.vGapXs,
          KTextField(
            label: 'Brand',
            controller: _brandCtrl,
          ),
          KSpacing.vGapXs,
          KCompactRow(
            children: [
              KTextField.amount(
                label: 'MRP',
                controller: _mrpCtrl,
              ),
              KTextField.amount(
                label: 'Purchase Price',
                controller: _purchasePriceCtrl,
              ),
            ],
          ),
          KSpacing.vGapXs,
          KTextField(
            label: 'Barcode',
            controller: _barcodeCtrl,
          ),
          KSpacing.vGapXs,
          KTextField(
            label: 'Category',
            controller: _categoryCtrl,
          ),
          KSpacing.vGapXs,
          KCompactRow(
            children: [
              KTextField(
                label: 'GST Rate (%)',
                controller: _gstRateCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              KTextField(
                label: 'HSN Code',
                controller: _hsnCodeCtrl,
              ),
            ],
          ),
          KSpacing.vGapSm,
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _cancelEditing,
                child: const Text('Cancel'),
              ),
              KSpacing.hGapSm,
              KButton(
                label: 'Done',
                icon: Icons.check,
                onPressed: _doneEditing,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: KColors.divider.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: KTypography.labelSmall),
    );
  }
}
