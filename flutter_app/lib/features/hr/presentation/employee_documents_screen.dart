import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../../../core/widgets/k_text_field.dart';

/// HR Employee Document management — Core HR module.
/// Tabs: My Documents (upload + list + delete), Expiring (HR watchlist).
class EmployeeDocumentsScreen extends ConsumerStatefulWidget {
  const EmployeeDocumentsScreen({super.key});

  @override
  ConsumerState<EmployeeDocumentsScreen> createState() => _EmployeeDocumentsScreenState();
}

class _EmployeeDocumentsScreenState extends ConsumerState<EmployeeDocumentsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _mine = [];
  List<Map<String, dynamic>> _expiring = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _list(Object? d) =>
      (d as List?)?.cast<Map<String, dynamic>>() ?? [];

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = ref.read(apiClientProvider);
    try {
      final mine = await api.get(ApiConfig.hrDocumentsMine);
      List<Map<String, dynamic>> exp = [];
      try {
        final e = await api.get(ApiConfig.hrDocumentsExpiring,
            queryParameters: {'days': 30});
        exp = _list(e.data['data']);
      } catch (_) {
        // expiring view is HR-only; ignore if forbidden
      }
      if (!mounted) return;
      setState(() {
        _mine = _list(mine.data['data']);
        _expiring = exp;
      });
    } catch (e) {
      _toast('Failed to load documents: ${ApiErrorParser.message(e)}', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String m, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: isError ? KColors.error : null,
      ),
    );
  }

  Future<void> _upload() async {
    final title = TextEditingController();
    String category = 'ID_PROOF';
    DateTime? expiry;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Upload Employee Document', style: KTypography.titleLarge),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(
                      labelText: 'Document Category',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ID_PROOF', child: Text('Government ID Proof (Aadhaar/Passport)')),
                      DropdownMenuItem(value: 'PAN', child: Text('PAN Card')),
                      DropdownMenuItem(value: 'INSURANCE', child: Text('Medical / Life Insurance')),
                      DropdownMenuItem(value: 'CONTRACT', child: Text('Employment Contract / Offer')),
                      DropdownMenuItem(value: 'OTHER', child: Text('Other Certificate / Document')),
                    ],
                    onChanged: (v) => setD(() => category = v ?? 'OTHER'),
                  ),
                  KSpacing.vGapSm,
                  KTextField(
                    controller: title,
                    label: 'Document Title *',
                    hint: 'e.g. Aadhaar Card Front & Back',
                  ),
                  KSpacing.vGapSm,
                  KCard(
                    onTap: () async {
                      final now = DateTime.now();
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: expiry ?? now,
                        firstDate: now,
                        lastDate: DateTime(now.year + 30),
                      );
                      if (d != null) setD(() => expiry = d);
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 16, color: KColors.primary),
                        KSpacing.hGapMd,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Expiry Date (Optional)', style: KTypography.labelSmall),
                              Text(
                                expiry == null ? 'No expiration date' : DateFormatter.display(expiry!),
                                style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit_calendar_outlined, size: 16, color: KColors.textSecondary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            KButton.primary(
              icon: Icons.file_upload_outlined,
              label: 'Pick File & Upload',
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;

    final picked = await FilePicker.platform.pickFiles(withData: true);
    if (picked == null || picked.files.isEmpty || picked.files.first.bytes == null) {
      return;
    }
    final f = picked.files.first;
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(f.bytes!.toList(), filename: f.name),
        'title': title.text.trim(),
        'category': category,
        if (expiry != null) 'expiry': expiry!.toIso8601String().split('T').first,
      });
      await ref.read(apiClientProvider).dio.post(ApiConfig.hrDocumentsMine, data: form);
      _toast('Document uploaded successfully');
      await _load();
    } catch (e) {
      _toast('Upload failed: ${ApiErrorParser.message(e)}', isError: true);
    }
  }

  Future<void> _delete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Document', style: KTypography.titleLarge),
        content: Text('Are you sure you want to delete this document permanently?', style: KTypography.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          KButton.danger(
            label: 'Delete',
            icon: Icons.delete_outline_rounded,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref.read(apiClientProvider).delete(ApiConfig.hrDocumentById(id));
      _toast('Document deleted');
      await _load();
    } catch (e) {
      _toast('Delete failed: ${ApiErrorParser.message(e)}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expiringCount = _expiring.length;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Employee Documents & KYC'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          bottom: TabBar(
            tabs: [
              const Tab(text: 'My Documents'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Expiring (Watchlist)'),
                    if (expiringCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: KColors.warning,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$expiringCount',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: KLoading(message: 'Loading documents...'))
            : TabBarView(children: [_mineTab(), _expiringTab()]),
      ),
    );
  }

  Widget _mineTab() {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: KSpacing.pagePadding,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Personal Records & ID Proofs', style: KTypography.h3),
            KButton.primary(
              label: 'Upload Document',
              icon: Icons.upload_file_rounded,
              size: KButtonSize.small,
              onPressed: _upload,
            ),
          ],
        ),
        KSpacing.vGapMd,
        if (_mine.isEmpty)
          const KEmptyState(
            icon: Icons.folder_open_outlined,
            title: 'No Documents Uploaded',
            subtitle: 'Upload identity proofs, contracts, or certifications for your employee record.',
          )
        else
          ..._mine.map((d) {
            final cat = d['category']?.toString() ?? 'DOCUMENT';
            final id = d['id'].toString();
            return KCard(
              margin: const EdgeInsets.only(bottom: KSpacing.sm),
              padding: const EdgeInsets.all(KSpacing.md),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(KSpacing.radiusMd),
                    ),
                    child: Icon(Icons.description_outlined, color: cs.primary, size: 20),
                  ),
                  KSpacing.hGapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d['title']?.toString() ?? 'Document',
                          style: KTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                        ),
                        KSpacing.vGapXs,
                        Row(
                          children: [
                            if (d['expiryDate'] != null) ...[
                              Text('Expires: ', style: KTypography.caption.copyWith(color: cs.onSurfaceVariant)),
                              Text('${d['expiryDate']}', style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w600)),
                            ] else
                              Text('No expiry date', style: KTypography.caption.copyWith(color: cs.onSurfaceVariant)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  KStatusChip(status: cat),
                  KSpacing.hGapSm,
                  IconButton(
                    tooltip: 'Delete document',
                    icon: const Icon(Icons.delete_outline_rounded, color: KColors.error, size: 20),
                    onPressed: () => _delete(id),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _expiringTab() {
    final cs = Theme.of(context).colorScheme;

    if (_expiring.isEmpty) {
      return const KEmptyState(
        icon: Icons.verified_user_outlined,
        title: 'No Documents Expiring Soon',
        subtitle: 'All employee compliance documents and IDs are up to date.',
      );
    }
    return ListView.separated(
      padding: KSpacing.pagePadding,
      itemCount: _expiring.length,
      separatorBuilder: (_, __) => KSpacing.vGapSm,
      itemBuilder: (_, i) {
        final d = _expiring[i];
        final cat = d['category']?.toString() ?? 'DOCUMENT';
        final emp = d['employeeName']?.toString();

        return KCard(
          padding: const EdgeInsets.all(KSpacing.md),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: KColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(KSpacing.radiusMd),
                ),
                child: Icon(Icons.event_busy_rounded, color: KColors.warning, size: 20),
              ),
              KSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (emp != null && emp.isNotEmpty) ...[
                      Text(emp, style: KTypography.titleSmall.copyWith(fontWeight: FontWeight.w700)),
                      KSpacing.vGapXxs,
                    ],
                    Text(
                      d['title']?.toString() ?? 'Document',
                      style: KTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                    ),
                    KSpacing.vGapXs,
                    Row(
                      children: [
                        Text('Expires: ', style: KTypography.caption.copyWith(color: cs.onSurfaceVariant)),
                        Text(
                          '${d['expiryDate']}',
                          style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w700, color: KColors.warning),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              KStatusChip(status: cat),
            ],
          ),
        );
      },
    );
  }
}
