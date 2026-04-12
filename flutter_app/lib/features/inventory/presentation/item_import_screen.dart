import 'package:dio/dio.dart';
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

/// Bulk item import via CSV. We deliberately avoid pulling in a
/// file-picker dependency: most SMEs paste CSVs they exported from Tally
/// or BUSY, so a textarea + clear template instructions is faster than a
/// file dialog round-trip. The text gets uploaded as a multipart "file"
/// part using Dio's MultipartFile.fromString.
class ItemImportScreen extends ConsumerStatefulWidget {
  const ItemImportScreen({super.key});

  @override
  ConsumerState<ItemImportScreen> createState() => _ItemImportScreenState();
}

class _ItemImportScreenState extends ConsumerState<ItemImportScreen> {
  static const _template =
      'sku,name,description,item_type,category,brand,hsn_code,'
      'unit_of_measure,purchase_price,sale_price,mrp,gst_rate,'
      'reorder_level,reorder_quantity,opening_stock\n'
      'PCM-500,Paracetamol 500mg,Pain reliever,GOODS,Pharma,Generic,3004,'
      'STRIP,8.50,12.00,15.00,12,20,100,50';

  final _csvCtl = TextEditingController(text: _template);
  bool _isUploading = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void dispose() {
    _csvCtl.dispose();
    super.dispose();
  }

  Future<void> _upload() async {
    final csv = _csvCtl.text;
    if (csv.trim().isEmpty) {
      setState(() => _error = 'Paste your CSV data first');
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
        'file': MultipartFile.fromString(
          csv,
          filename: 'items.csv',
        ),
      });
      final response = await api.dio.post(
        ApiConfig.itemImport,
        data: form,
        options: Options(
          // Let dio set the multipart boundary
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );
      final body = response.data as Map<String, dynamic>;
      final result = (body['data'] ?? body) as Map<String, dynamic>;
      ref.invalidate(itemListProvider);
      setState(() => _result = result);
    } catch (e, st) {
      debugPrint('[ItemImport] upload FAILED: $e\n$st');
      setState(() => _error = 'Upload failed. Check the CSV format and try again.');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _resetToTemplate() {
    setState(() {
      _csvCtl.text = _template;
      _result = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

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
            KCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 20, color: KColors.primary),
                      KSpacing.hGapSm,
                      Text('CSV format', style: KTypography.labelLarge),
                    ],
                  ),
                  KSpacing.vGapSm,
                  Text(
                    'Required columns: sku, name. Optional: description, item_type '
                    '(GOODS or SERVICE), category, brand, hsn_code, unit_of_measure, '
                    'purchase_price, sale_price, mrp, gst_rate, reorder_level, '
                    'reorder_quantity, opening_stock.',
                    style: KTypography.bodySmall,
                  ),
                  KSpacing.vGapSm,
                  Text(
                    'Items with a positive opening_stock automatically get an OPENING '
                    'movement posted to your default warehouse.',
                    style: KTypography.bodySmall.copyWith(
                      color: KColors.textSecondary,
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

            Text('Paste CSV', style: KTypography.labelLarge),
            KSpacing.vGapSm,
            Container(
              decoration: BoxDecoration(
                color: KColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: KColors.divider),
              ),
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: _csvCtl,
                maxLines: 12,
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
            Row(
              children: [
                TextButton.icon(
                  onPressed: _resetToTemplate,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reset to template'),
                ),
                const Spacer(),
                KButton(
                  label: 'Import',
                  icon: Icons.upload,
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
          Text(value,
              style: KTypography.h2.copyWith(color: color)),
          KSpacing.vGapXs,
          Text(label, style: KTypography.labelSmall),
        ],
      ),
    );
  }
}
