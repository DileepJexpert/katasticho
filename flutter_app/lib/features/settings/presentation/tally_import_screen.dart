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
  // Masters (Slice 1)
  List<int>? _fileBytes;
  String? _fileName;
  Map<String, dynamic>? _preview;
  Map<String, dynamic>? _result;

  // Vouchers (Slice 2)
  List<int>? _vFileBytes;
  String? _vFileName;
  Map<String, dynamic>? _vPreview;
  Map<String, dynamic>? _vResult;

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

  Future<Map<String, dynamic>> _upload(String path) =>
      _uploadBytes(path, _fileBytes!, _fileName ?? 'Master.xml');

  // ── Voucher (Day Book) ──────────────────────────────────────────────

  Future<void> _pickVoucherFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xml'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final bytes = picked.files.first.bytes;
    if (bytes == null || !mounted) return;
    setState(() {
      _vFileBytes = bytes.toList();
      _vFileName = picked.files.first.name;
      _vPreview = null;
      _vResult = null;
      _error = null;
    });
    await _runVoucherPreview();
  }

  Future<void> _runVoucherPreview() async {
    if (_vFileBytes == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      final data = await _uploadBytes(
          ApiConfig.tallyVoucherPreview, _vFileBytes!, _vFileName ?? 'DayBook.xml');
      if (mounted) setState(() => _vPreview = data);
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runVoucherImport() async {
    if (_vFileBytes == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      final data = await _uploadBytes(
          ApiConfig.tallyVoucherImport, _vFileBytes!, _vFileName ?? 'DayBook.xml');
      if (mounted) setState(() => _vResult = data);
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Map<String, dynamic>> _uploadBytes(
      String path, List<int> bytes, String filename) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await ref.read(apiClientProvider).post(path, data: form);
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
          Text('Step 1: Masters (ledgers, items, opening balances)',
              style: KTypography.h3),
          KSpacing.vGapSm,
          _buildPicker(),
          if (_result != null) ...[
            KSpacing.vGapMd,
            _buildResult(),
          ] else if (_preview != null) ...[
            KSpacing.vGapMd,
            _buildPreview(),
          ],
          KSpacing.vGapLg,
          Text('Step 2: Day Book (transaction history — optional)',
              style: KTypography.h3),
          KSpacing.vGapSm,
          _buildVoucherPicker(),
          if (_vResult != null) ...[
            KSpacing.vGapMd,
            _buildVoucherResult(),
          ] else if (_vPreview != null) ...[
            KSpacing.vGapMd,
            _buildVoucherPreview(),
          ],
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
        ],
      ),
    );
  }

  Widget _buildSteps() {
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Switch from Tally in two exports', style: KTypography.h3),
          KSpacing.vGapSm,
          _step('1',
              'Masters: Gateway of Tally → Export → Masters → XML. Imports ledgers, items, opening balances.'),
          _step('2',
              'Day Book (optional): Display → Day Book → set the FY period → Alt+E Export → XML. Imports transaction history as journal entries.'),
          _step('3',
              'Both imports preview before committing, skip duplicates on re-run, and never touch GST/tax accounts.'),
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

  // ── Voucher UI ─────────────────────────────────────────────────────

  Widget _buildVoucherPicker() {
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: KColors.primary),
              KSpacing.hGapSm,
              Expanded(
                child: Text(_vFileName ?? 'No Day Book file selected',
                    style: KTypography.bodyMedium, overflow: TextOverflow.ellipsis),
              ),
              KButton(
                label: _vFileName == null ? 'Pick Day Book XML' : 'Change file',
                variant: KButtonVariant.outlined,
                onPressed: _busy ? null : _pickVoucherFile,
              ),
            ],
          ),
          if (_busy && _vFileBytes != null) ...[
            KSpacing.vGapMd,
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }

  Widget _buildVoucherPreview() {
    final p = _vPreview!;
    final importable = p['importable'] as num? ?? 0;
    final byType = Map<String, dynamic>.from((p['byType'] as Map?) ?? {});
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _metric('Total', p['total'], KColors.primary),
            KSpacing.hGapSm,
            _metric('Importable', p['importable'], KColors.success),
            KSpacing.hGapSm,
            _metric('Skipped', p['skipped'], KColors.warning),
          ],
        ),
        if (byType.isNotEmpty) ...[
          KSpacing.vGapSm,
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: byType.entries.map((e) => Chip(
              label: Text('${e.key}: ${e.value}',
                  style: KTypography.labelSmall),
              visualDensity: VisualDensity.compact,
            )).toList(),
          ),
        ],
        KSpacing.vGapSm,
        SizedBox(
          width: double.infinity,
          child: KButton(
            label: 'Import $importable vouchers as journals',
            icon: Icons.download_done,
            isLoading: _busy,
            onPressed: importable > 0 && !_busy ? _runVoucherImport : null,
          ),
        ),
      ],
    );
  }

  Widget _buildVoucherResult() {
    final r = _vResult!;
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
              Text('Voucher import complete', style: KTypography.h3),
            ],
          ),
          KSpacing.vGapSm,
          Text(
            '${r['journalsCreated']} journal entries created'
            '${(r['skipped'] as num? ?? 0) > 0 ? ' · ${r['skipped']} skipped' : ''}',
            style: KTypography.bodyMedium,
          ),
          if (errors.isNotEmpty) ...[
            KSpacing.vGapSm,
            Text('${errors.length} voucher(s) failed:',
                style: KTypography.labelLarge.copyWith(color: KColors.error)),
            ...errors.take(20).map((e) {
              final err = Map<String, dynamic>.from(e as Map);
              return Text('• ${err['tallyName']}: ${err['error']}',
                  style: KTypography.bodySmall.copyWith(color: KColors.error));
            }),
          ],
          KSpacing.vGapSm,
          Text(
            'Your Tally trial balance should now match. Verify in Reports → Trial Balance.',
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
