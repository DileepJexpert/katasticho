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

/// Medicine catalogue bulk import: upload a CSV exported from Marg / a
/// 1mg-style A-Z list / Apollo / DavaIndia range sheets into the shared
/// drug_master catalogue. Add-only — existing brands are skipped, salts are
/// linked (never created), manufacturers auto-registered. Dry-run first.
///
/// Tokens used: KCard, KButton, KColors.*, KSpacing.*,
/// KTypography.mono for counts.
class DrugImportScreen extends ConsumerStatefulWidget {
  const DrugImportScreen({super.key});

  @override
  ConsumerState<DrugImportScreen> createState() => _DrugImportScreenState();
}

class _DrugImportScreenState extends ConsumerState<DrugImportScreen> {
  List<int>? _fileBytes;
  String? _fileName;
  int _fileSize = 0;
  bool _dryRun = true;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _result;

  Future<void> _pickFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final bytes = picked.files.first.bytes;
    if (bytes == null || !mounted) return;
    setState(() {
      _fileBytes = bytes.toList();
      _fileName = picked.files.first.name;
      _fileSize = picked.files.first.size;
      _result = null;
      _error = null;
    });
  }

  Future<void> _upload() async {
    if (_fileBytes == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(_fileBytes!,
            filename: _fileName ?? 'drugs.csv'),
      });
      final response = await ref.read(apiClientProvider).post(
            ApiConfig.drugMasterImport,
            data: form,
            queryParameters: {'dry_run': _dryRun.toString()},
          );
      final body = response.data as Map<String, dynamic>;
      if (mounted) {
        setState(() =>
            _result = Map<String, dynamic>.from((body['data'] as Map?) ?? body));
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _error =
            (e.response?.data is Map ? e.response?.data['message'] : null)
                    ?.toString() ??
                e.message ??
                'Upload failed');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medicine Catalogue Import')),
      body: ListView(
        padding: const EdgeInsets.all(KSpacing.lg),
        children: [
          Text(
            'Bulk-load external medicine lists (Marg export, 1mg-style A-Z '
            'dump, Apollo / DavaIndia ranges) into the shared drug catalogue',
            style: KTypography.bodyMedium
                .copyWith(color: KColors.textSecondary),
          ),
          const SizedBox(height: KSpacing.lg),
          _buildHowItWorksCard(),
          const SizedBox(height: KSpacing.lg),
          _buildUploadCard(),
          if (_error != null) ...[
            const SizedBox(height: KSpacing.md),
            KCard(
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: KColors.error),
                  const SizedBox(width: KSpacing.sm),
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(color: KColors.error)),
                  ),
                ],
              ),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: KSpacing.lg),
            _buildResultCard(_result!),
          ],
        ],
      ),
    );
  }

  Widget _buildHowItWorksCard() {
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How it works', style: KTypography.h4),
          const SizedBox(height: KSpacing.sm),
          const Text(
            '• CSV with a header row — columns (aliases in brackets): '
            'brand_name (brand, product_name) — required; generic_name '
            '(generic); salt_composition (composition, salt); manufacturer '
            '(company, mfg); hsn_code (hsn); gst_rate (gst); drug_schedule '
            '(schedule); dosage_form (form); pack_size (pack); mrp (price); '
            'prescription_required (rx).\n'
            '• Add-only: brands already in the catalogue are skipped, so '
            're-importing the same list is safe.\n'
            '• Salts are linked by generic name (never auto-created); new '
            'manufacturers are registered for autocomplete.\n'
            '• Schedules tolerate Marg spellings (Sch H1, Schedule-X, NDPS).\n'
            '• Up to 100,000 rows per upload — split bigger lists.',
            style: TextStyle(height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadCard() {
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Upload', style: KTypography.h4),
          const SizedBox(height: KSpacing.md),
          Row(
            children: [
              KButton(
                label: _fileName == null ? 'Choose CSV file' : 'Change file',
                icon: Icons.upload_file_outlined,
                variant: KButtonVariant.secondary,
                onPressed: _busy ? null : _pickFile,
              ),
              const SizedBox(width: KSpacing.md),
              if (_fileName != null)
                Expanded(
                  child: Text(
                    '$_fileName  (${(_fileSize / 1024).toStringAsFixed(0)} KB)',
                    style: KTypography.mono(size: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          const SizedBox(height: KSpacing.md),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _dryRun,
            onChanged: _busy ? null : (v) => setState(() => _dryRun = v),
            title: const Text('Dry run (preview counts, save nothing)'),
            subtitle: const Text(
                'Recommended first pass — turn off to actually import'),
          ),
          const SizedBox(height: KSpacing.md),
          KButton(
            label: _busy
                ? 'Uploading…'
                : (_dryRun ? 'Preview import (dry run)' : 'Import to catalogue'),
            icon: _dryRun ? Icons.visibility_outlined : Icons.publish_outlined,
            onPressed: (_busy || _fileBytes == null) ? null : _upload,
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> r) {
    final errors = (r['errors'] as List?) ?? const [];
    final bool dryRun = r['dryRun'] == true;
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(dryRun ? Icons.visibility_outlined : Icons.check_circle_outline,
                  color: dryRun ? KColors.textSecondary : KColors.success),
              const SizedBox(width: KSpacing.sm),
              Text(dryRun ? 'Dry-run preview' : 'Import complete',
                  style: KTypography.h4),
            ],
          ),
          const SizedBox(height: KSpacing.md),
          Wrap(
            spacing: KSpacing.lg,
            runSpacing: KSpacing.md,
            children: [
              _metric('Rows in file', r['totalDataRows']),
              _metric(dryRun ? 'Would import' : 'Imported', r['imported']),
              _metric('Skipped (already exists)', r['skippedDuplicates']),
              _metric('Linked to a salt', r['saltLinked']),
              _metric('New manufacturers', r['manufacturersCreated']),
              _metric('Errors', r['errorCount']),
            ],
          ),
          if (errors.isNotEmpty) ...[
            const SizedBox(height: KSpacing.md),
            Text('First ${errors.length} errors', style: KTypography.h4),
            const SizedBox(height: KSpacing.xs),
            ...errors.take(50).map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('• $e',
                      style: KTypography.mono(size: 12, color: KColors.error)),
                )),
          ],
        ],
      ),
    );
  }

  Widget _metric(String label, Object? value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${value ?? 0}', style: KTypography.mono(size: 20)),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: KColors.textSecondary)),
      ],
    );
  }
}
