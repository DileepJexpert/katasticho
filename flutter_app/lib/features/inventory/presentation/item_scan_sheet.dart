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

class _ScannedItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int index;
  final VoidCallback onUse;
  final VoidCallback onRemove;

  const _ScannedItemCard({
    required this.item,
    required this.index,
    required this.onUse,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final name = item['name']?.toString() ?? 'Unknown';
    final brand = item['brand']?.toString();
    final mrp = item['mrp'];
    final purchasePrice = item['purchasePrice'];
    final barcode = item['barcode']?.toString();
    final category = item['category']?.toString();
    final gstRate = item['gstRate'];

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
                  '${index + 1}',
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
                icon: const Icon(Icons.close, size: 18),
                onPressed: onRemove,
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
              onPressed: onUse,
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Use This Item'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
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
