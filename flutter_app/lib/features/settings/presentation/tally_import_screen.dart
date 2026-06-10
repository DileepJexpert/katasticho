import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';

/// Migrate from Tally: upload the Masters XML exported from TallyPrime,
/// preview what every ledger/stock item becomes, then import.
class TallyImportScreen extends ConsumerStatefulWidget {
  const TallyImportScreen({super.key});

  @override
  ConsumerState<TallyImportScreen> createState() => _TallyImportScreenState();
}

class _TallyImportScreenState extends ConsumerState<TallyImportScreen> {
  List<int>? _fileBytes;
  String? _fileName;
  Map<String, dynamic>? _preview;
  Map<String, dynamic>? _result;
  bool _busy = false;
  String? _error;

  Future<void> _pickFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xml'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final bytes = picked.files.first.bytes;
    if (bytes == null || !mounted) return;
    setState(() {
      _fileBytes = bytes.toList();
      _fileName = picked.files.first.name;
      _preview = null;
      _result = null;
      _error = null;
    });
    await _runPreview();
  }

  Future<void> _runPreview() async {
    if (_fileBytes == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await _upload(ApiConfig.tallyImportPreview);
      if (mounted) setState(() => _preview = data);
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runImport() async {
    if (_fileBytes == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await _upload(ApiConfig.tallyImport);
      if (mounted) setState(() => _result = data);
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Map<String, dynamic>> _upload(String path) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(_fileBytes!,
          filename: _fileName ?? 'Master.xml'),
    });
    final response =
        await ref.read(apiClientProvider).post(path, data: form);
    final body = response.data as Map<String, dynamic>;
    return Map<String, dynamic>.from((body['data'] as Map?) ?? body);
  }

  String _msg(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
    }
    return e.toString().replaceAll('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Migrate from Tally')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSteps(),
          KSpacing.vGapMd,
          _buildPicker(),
          if (_error != null) ...[
            KSpacing.vGapMd,
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: KColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!,
                  style: KTypography.bodySmall.copyWith(color: KColors.error)),
            ),
          ],
          if (_result != null) ...[
            KSpacing.vGapMd,
            _buildResult(),
          ] else if (_preview != null) ...[
            KSpacing.vGapMd,
            _buildPreview(),
          ],
        ],
      ),
    );
  }

  Widget _buildSteps() {
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Switch from Tally in three steps', style: KTypography.h3),
          KSpacing.vGapSm,
          _step('1',
              'In TallyPrime: Gateway of Tally → Export → Masters → set Format to XML → Export. You get one Master.xml file.'),
          _step('2',
              'Upload it here. We preview every ledger and stock item: customers, suppliers, accounts, items with opening balances and stock.'),
          _step('3',
              'Tap Import. GST/tax ledgers are skipped (Katasticho manages those), and re-running is safe — existing records are never duplicated.'),
        ],
      ),
    );
  }

  Widget _step(String n, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: KColors.primarySoft,
            child: Text(n,
                style: KTypography.labelSmall.copyWith(color: KColors.primary)),
          ),
          KSpacing.hGapSm,
          Expanded(
            child: Text(text,
                style: KTypography.bodySmall
                    .copyWith(color: KColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildPicker() {
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.upload_file, color: KColors.primary),
              KSpacing.hGapSm,
              Expanded(
                child: Text(_fileName ?? 'No file selected',
                    style: KTypography.bodyMedium, overflow: TextOverflow.ellipsis),
              ),
              KButton(
                label: _fileName == null ? 'Pick Masters XML' : 'Change file',
                variant: KButtonVariant.outlined,
                onPressed: _busy ? null : _pickFile,
              ),
            ],
          ),
          if (_busy) ...[
            KSpacing.vGapMd,
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final p = _preview!;
    final rows = (p['rows'] as List?) ?? const [];
    final toCreate = (p['customers'] as num? ?? 0) +
        (p['vendors'] as num? ?? 0) +
        (p['accounts'] as num? ?? 0) +
        (p['items'] as num? ?? 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _metric('Customers', p['customers'], KColors.primary),
            KSpacing.hGapSm,
            _metric('Suppliers', p['vendors'], KColors.info),
            KSpacing.hGapSm,
            _metric('Accounts', p['accounts'], KColors.success),
            KSpacing.hGapSm,
            _metric('Items', p['items'], KColors.warning),
          ],
        ),
        KSpacing.vGapSm,
        SizedBox(
          width: double.infinity,
          child: KButton(
            label: 'Import $toCreate records',
            icon: Icons.download_done,
            isLoading: _busy,
            onPressed: toCreate > 0 && !_busy ? _runImport : null,
          ),
        ),
        KSpacing.vGapMd,
        Text('What each Tally master becomes', style: KTypography.h3),
        KSpacing.vGapSm,
        ...rows.map((raw) {
          final row = Map<String, dynamic>.from(raw as Map);
          final action = row['action']?.toString() ?? '';
          final color = switch (action) {
            'CREATE' => KColors.success,
            'SKIP_EXISTS' => KColors.info,
            _ => KColors.textSecondary,
          };
          return Padding(
            padding: const EdgeInsets.only(bottom: KSpacing.xs),
            child: KCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row['tallyName']?.toString() ?? '',
                            style: KTypography.labelLarge),
                        Text(
                          '${row['tallyGroup'] ?? ''} → ${row['becomes']} · ${row['detail'] ?? ''}',
                          style: KTypography.bodySmall
                              .copyWith(color: KColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(action.replaceAll('_', ' '),
                        style:
                            KTypography.labelSmall.copyWith(color: color)),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildResult() {
    final r = _result!;
    final errors = (r['errors'] as List?) ?? const [];
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(errors.isEmpty ? Icons.check_circle : Icons.warning_amber,
                  color: errors.isEmpty ? KColors.success : KColors.warning),
              KSpacing.hGapSm,
              Text('Import complete', style: KTypography.h3),
            ],
          ),
          KSpacing.vGapSm,
          Text(
            '${r['customersCreated']} customers · ${r['vendorsCreated']} suppliers · '
            '${r['accountsCreated']} accounts · ${r['itemsCreated']} items created'
            '${(r['skipped'] as num? ?? 0) > 0 ? ' · ${r['skipped']} skipped' : ''}',
            style: KTypography.bodyMedium,
          ),
          if (errors.isNotEmpty) ...[
            KSpacing.vGapSm,
            Text('${errors.length} row(s) failed:',
                style: KTypography.labelLarge.copyWith(color: KColors.error)),
            ...errors.take(20).map((e) {
              final err = Map<String, dynamic>.from(e as Map);
              return Text('• ${err['tallyName']}: ${err['error']}',
                  style:
                      KTypography.bodySmall.copyWith(color: KColors.error));
            }),
          ],
          KSpacing.vGapSm,
          Text(
            'Next: post your first sale, or scan a purchase bill — AI drafts it for you.',
            style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, Object? value, Color color) {
    return Expanded(
      child: KCard(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Text('${value ?? 0}', style: KTypography.h3.copyWith(color: color)),
            Text(label,
                style:
                    KTypography.bodySmall.copyWith(color: KColors.textHint)),
          ],
        ),
      ),
    );
  }
}
