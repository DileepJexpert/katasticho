import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../data/item_repository.dart';

/// Bulk item import via CSV. Two separate input controls on the same page:
///  1. Upload CSV file (file picker — works on web & native via `withData`)
///  2. Paste CSV content (textarea)
///
/// A single Import button sends whichever source has content. If both are
/// populated, the picked file wins. Uploads multipart/form-data via Dio.
class ItemImportScreen extends ConsumerStatefulWidget {
  const ItemImportScreen({super.key});

  @override
  ConsumerState<ItemImportScreen> createState() => _ItemImportScreenState();
}

class _ItemImportScreenState extends ConsumerState<ItemImportScreen> {
  static const _template =
      'sku,name,description,item_type,category,brand,hsn_code,'
      'unit_of_measure,purchase_price,sale_price,mrp,gst_rate,'
      'reorder_level,reorder_quantity,opening_stock';

  final _pasteCtl = TextEditingController();

  // Picked file state
  String? _pickedFileName;
  String? _pickedFileContent;
  int? _pickedFileDataRows;

  bool _isUploading = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void dispose() {
    _pasteCtl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'txt'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() => _error = 'Could not read file contents');
        return;
      }
      // Strip UTF-8 BOM if present so the first header cell doesn't get
      // a hidden \uFEFF prefix that breaks `sku` column detection.
      var text = utf8.decode(bytes, allowMalformed: true);
      if (text.startsWith('\uFEFF')) text = text.substring(1);

      // Count data rows (non-blank minus header).
      final lines = text
          .split(RegExp(r'\r?\n'))
          .where((l) => l.trim().isNotEmpty)
          .toList();
      final dataRows = lines.length > 0 ? lines.length - 1 : 0;

      setState(() {
        _pickedFileName = file.name;
        _pickedFileContent = text;
        _pickedFileDataRows = dataRows < 0 ? 0 : dataRows;
        _result = null;
        _error = null;
      });
    } catch (e, st) {
      debugPrint('[ItemImport] pick FAILED: $e\n$st');
      setState(() => _error = 'Could not open file picker: $e');
    }
  }

  void _clearPickedFile() {
    setState(() {
      _pickedFileName = null;
      _pickedFileContent = null;
      _pickedFileDataRows = null;
    });
  }

  void _copyTemplate() {
    setState(() {
      _pasteCtl.text = _template;
      _error = null;
    });
  }

  Future<void> _upload() async {
    // Prefer picked file if present; else fall back to paste textarea.
    String? csv;
    String filename = 'items.csv';
    if (_pickedFileContent != null && _pickedFileContent!.trim().isNotEmpty) {
      csv = _pickedFileContent;
      filename = _pickedFileName ?? 'items.csv';
    } else if (_pasteCtl.text.trim().isNotEmpty) {
      csv = _pasteCtl.text;
    }

    if (csv == null) {
      setState(() => _error =
          'Upload a CSV file or paste CSV content before importing.');
      return;
    }

    setState(() {
      _isUploading = true;
      _error = null;
      _result = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final form = FormData.fromMap({
        'file': MultipartFile.fromString(csv, filename: filename),
      });
      final response = await api.dio.post(
        ApiConfig.itemImport,
        data: form,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );
      final body = response.data as Map<String, dynamic>;
      final result = (body['data'] ?? body) as Map<String, dynamic>;
      ref.invalidate(itemListProvider);
      setState(() => _result = result);
    } catch (e, st) {
      debugPrint('[ItemImport] upload FAILED: $e\n$st');
      setState(() =>
          _error = 'Upload failed. Check the CSV format and try again.');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Import Items'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.items),
        ),
      ),
      body: SingleChildScrollView(
        padding: KSpacing.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Instructions ─────────────────────────────────────
            KCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: cs.primary),
                      KSpacing.hGapSm,
                      Text('CSV format', style: KTypography.labelLarge),
                    ],
                  ),
                  KSpacing.vGapSm,
                  Text(
                    'Required columns: sku, name. Optional: description, '
                    'item_type (GOODS or SERVICE), category, brand, hsn_code, '
                    'unit_of_measure, purchase_price, sale_price, mrp, '
                    'gst_rate, reorder_level, reorder_quantity, opening_stock.',
                    style: KTypography.bodySmall,
                  ),
                  KSpacing.vGapSm,
                  Text(
                    'Items with a positive opening_stock automatically get an '
                    'OPENING movement posted to your default warehouse.',
                    style: KTypography.bodySmall.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            KSpacing.vGapMd,

            if (_error != null) ...[
              KErrorBanner(
                message: _error!,
                onDismiss: () => setState(() => _error = null),
              ),
              KSpacing.vGapMd,
            ],

            // ── Option 1: Upload CSV file ────────────────────────
            _SectionHeader(
              number: '1',
              title: 'Upload CSV file',
              subtitle: 'Pick a .csv file from your computer',
            ),
            KSpacing.vGapSm,
            _FilePickerCard(
              fileName: _pickedFileName,
              dataRows: _pickedFileDataRows,
              onPick: _pickFile,
              onClear: _clearPickedFile,
            ),

            KSpacing.vGapLg,
            _OrDivider(),
            KSpacing.vGapLg,

            // ── Option 2: Paste CSV ──────────────────────────────
            _SectionHeader(
              number: '2',
              title: 'Copy / paste CSV content here',
              subtitle: 'For quick tests or Tally/BUSY exports',
            ),
            KSpacing.vGapSm,
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(KSpacing.radiusMd),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: _pasteCtl,
                maxLines: 12,
                minLines: 8,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Paste CSV here…',
                ),
              ),
            ),
            KSpacing.vGapSm,
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _copyTemplate,
                icon: const Icon(Icons.content_copy, size: 16),
                label: const Text('Insert header template'),
              ),
            ),

            KSpacing.vGapLg,

            // ── Single Import button ─────────────────────────────
            Row(
              children: [
                const Spacer(),
                KButton(
                  label: 'Import',
                  icon: Icons.cloud_upload_outlined,
                  onPressed: _upload,
                  isLoading: _isUploading,
                ),
              ],
            ),

            if (result != null) ...[
              KSpacing.vGapLg,
              const Divider(),
              KSpacing.vGapMd,
              _ImportResultPanel(result: result),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Section header with numbered badge ─────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: TextStyle(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
        KSpacing.hGapSm,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: KTypography.labelLarge),
              Text(
                subtitle,
                style: KTypography.bodySmall.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── "OR" divider between the two options ──────────────────────────
class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: cs.outlineVariant.withValues(alpha: 0.6),
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: cs.outlineVariant.withValues(alpha: 0.6),
            thickness: 1,
          ),
        ),
      ],
    );
  }
}

// ── File picker drop-zone card ────────────────────────────────────
class _FilePickerCard extends StatelessWidget {
  final String? fileName;
  final int? dataRows;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _FilePickerCard({
    required this.fileName,
    required this.dataRows,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasFile = fileName != null;

    return InkWell(
      onTap: hasFile ? null : onPick,
      borderRadius: BorderRadius.circular(KSpacing.radiusMd),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: hasFile
              ? cs.primaryContainer.withValues(alpha: 0.25)
              : cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(KSpacing.radiusMd),
          border: Border.all(
            color: hasFile
                ? cs.primary.withValues(alpha: 0.5)
                : cs.outlineVariant.withValues(alpha: 0.7),
            width: hasFile ? 1.5 : 1,
            style: hasFile ? BorderStyle.solid : BorderStyle.solid,
          ),
        ),
        child: hasFile
            ? _PickedFileRow(
                fileName: fileName!,
                dataRows: dataRows ?? 0,
                onReplace: onPick,
                onClear: onClear,
              )
            : _PickPrompt(onPick: onPick),
      ),
    );
  }
}

class _PickPrompt extends StatelessWidget {
  final VoidCallback onPick;
  const _PickPrompt({required this.onPick});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.cloud_upload_outlined,
            color: cs.primary,
            size: 28,
          ),
        ),
        KSpacing.vGapSm,
        Text(
          'Click to choose a CSV file',
          style: KTypography.labelLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          'Accepted: .csv, .txt (UTF-8)',
          style: KTypography.bodySmall.copyWith(
            color: cs.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        KSpacing.vGapSm,
        FilledButton.tonalIcon(
          onPressed: onPick,
          icon: const Icon(Icons.folder_open_outlined, size: 18),
          label: const Text('Browse files'),
        ),
      ],
    );
  }
}

class _PickedFileRow extends StatelessWidget {
  final String fileName;
  final int dataRows;
  final VoidCallback onReplace;
  final VoidCallback onClear;

  const _PickedFileRow({
    required this.fileName,
    required this.dataRows,
    required this.onReplace,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.description_outlined,
            color: cs.primary,
            size: 22,
          ),
        ),
        KSpacing.hGapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                fileName,
                style: KTypography.labelLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '$dataRows data row${dataRows == 1 ? '' : 's'} detected',
                style: KTypography.bodySmall.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        KSpacing.hGapSm,
        TextButton.icon(
          onPressed: onReplace,
          icon: const Icon(Icons.swap_horiz, size: 16),
          label: const Text('Replace'),
        ),
        IconButton(
          tooltip: 'Remove file',
          onPressed: onClear,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}

class _ImportResultPanel extends StatelessWidget {
  final Map<String, dynamic> result;
  const _ImportResultPanel({required this.result});

  @override
  Widget build(BuildContext context) {
    final total = (result['totalRows'] as num?)?.toInt() ?? 0;
    final created = (result['created'] as num?)?.toInt() ?? 0;
    final skipped = (result['skipped'] as num?)?.toInt() ?? 0;
    final errors = (result['errors'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Import Result', style: KTypography.h3),
        KSpacing.vGapMd,
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Total rows',
                value: '$total',
                color: KColors.textSecondary,
              ),
            ),
            KSpacing.hGapSm,
            Expanded(
              child: _StatTile(
                label: 'Created',
                value: '$created',
                color: KColors.success,
              ),
            ),
            KSpacing.hGapSm,
            Expanded(
              child: _StatTile(
                label: 'Skipped',
                value: '$skipped',
                color: skipped > 0 ? KColors.warning : KColors.textSecondary,
              ),
            ),
          ],
        ),
        if (errors.isNotEmpty) ...[
          KSpacing.vGapMd,
          Text('Skipped rows', style: KTypography.labelLarge),
          KSpacing.vGapSm,
          ...errors.map((e) {
            final err = e as Map<String, dynamic>;
            final row = err['rowNumber'];
            final sku = err['sku'] as String?;
            final msg = err['message'] as String? ?? 'Unknown error';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: KColors.warning),
                  KSpacing.hGapSm,
                  Expanded(
                    child: Text(
                      'Row $row${sku != null ? " ($sku)" : ""}: $msg',
                      style: KTypography.bodySmall,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Column(
        children: [
          Text(value, style: KTypography.h2.copyWith(color: color)),
          KSpacing.vGapXs,
          Text(label, style: KTypography.labelSmall),
        ],
      ),
    );
  }
}
