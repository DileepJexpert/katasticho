import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../data/gst_repository.dart';

// ── Compliance Calendar Tab ──────────────────────────────────────────────────

class GstCalendarTab extends StatelessWidget {
  final List<dynamic>? items;

  const GstCalendarTab({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final rows = items ?? const [];
    if (rows.isEmpty) {
      return const Center(child: Text('No compliance items'));
    }
    return ListView.separated(
      padding: KSpacing.pagePadding,
      itemCount: rows.length,
      separatorBuilder: (_, __) => KSpacing.vGapSm,
      itemBuilder: (context, i) {
        final item = Map<String, dynamic>.from(rows[i] as Map);
        final status = item['status']?.toString() ?? 'UPCOMING';
        final daysLeft = (item['daysLeft'] as num?)?.toInt() ?? 0;
        return KCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _statusIcon(status),
              KSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['title']?.toString() ?? '',
                        style: KTypography.labelLarge),
                    KSpacing.vGapXs,
                    Text(
                      'Period ${item['period']} · due ${item['dueDate']}'
                      '${daysLeft >= 0 ? ' · $daysLeft day(s) left' : ' · ${-daysLeft} day(s) overdue'}',
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textSecondary),
                    ),
                    if ((item['description']?.toString() ?? '').isNotEmpty) ...[
                      KSpacing.vGapXs,
                      Text(item['description'].toString(),
                          style: KTypography.bodySmall
                              .copyWith(color: KColors.textHint)),
                    ],
                  ],
                ),
              ),
              _statusChip(status),
            ],
          ),
        );
      },
    );
  }

  Widget _statusIcon(String status) {
    return switch (status) {
      'OVERDUE' => const Icon(Icons.error, color: KColors.error),
      'DUE_SOON' => const Icon(Icons.warning_amber, color: KColors.warning),
      _ => const Icon(Icons.event, color: KColors.info),
    };
  }

  Widget _statusChip(String status) {
    final (color, label) = switch (status) {
      'OVERDUE' => (KColors.error, 'Overdue'),
      'DUE_SOON' => (KColors.warning, 'Due soon'),
      _ => (KColors.info, 'Upcoming'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: KTypography.labelSmall.copyWith(color: color)),
    );
  }
}

// ── GSTR-2B Reconciliation Tab ───────────────────────────────────────────────

class Gstr2bTab extends ConsumerStatefulWidget {
  final String period; // YYYY-MM
  final Map<String, dynamic>? summary;
  final VoidCallback onChanged;

  const Gstr2bTab({
    super.key,
    required this.period,
    required this.summary,
    required this.onChanged,
  });

  @override
  ConsumerState<Gstr2bTab> createState() => _Gstr2bTabState();
}

class _Gstr2bTabState extends ConsumerState<Gstr2bTab> {
  List<dynamic>? _entries;
  bool _uploading = false;

  Future<void> _loadEntries() async {
    try {
      final entries = await ref
          .read(gstRepositoryProvider)
          .listGstr2bEntries(widget.period);
      if (mounted) setState(() => _entries = entries);
    } catch (_) {
      if (mounted) setState(() => _entries = const []);
    }
  }

  Future<void> _pickAndUpload() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty || !mounted) return;
    final bytes = picked.files.first.bytes;
    if (bytes == null) return;

    setState(() => _uploading = true);
    try {
      final json = jsonDecode(utf8.decode(bytes));
      if (json is! Map<String, dynamic>) {
        throw const FormatException('Not a JSON object');
      }
      final summary = await ref
          .read(gstRepositoryProvider)
          .uploadGstr2b(widget.period, json);
      if (!mounted) return;
      final mismatches = (summary['valueMismatch'] as num? ?? 0) +
          (summary['notInBooks'] as num? ?? 0);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(mismatches > 0
            ? '2B reconciled — $mismatches issue(s) sent to your AI Inbox'
            : '2B reconciled — everything matched'),
      ));
      widget.onChanged();
      await _loadEntries();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('Upload failed: ${e.toString().replaceAll('Exception: ', '')}'),
      ));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final hasData = summary != null && (summary['totalEntries'] as num? ?? 0) > 0;

    return ListView(
      padding: KSpacing.pagePadding,
      children: [
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('GSTR-2B for ${widget.period}', style: KTypography.h3),
              KSpacing.vGapSm,
              Text(
                'Download the GSTR-2B JSON from the GST portal (generated on the '
                '14th) and upload it here. Bills are matched automatically; '
                'mismatches and missed ITC land in your AI Inbox.',
                style:
                    KTypography.bodySmall.copyWith(color: KColors.textSecondary),
              ),
              KSpacing.vGapMd,
              KButton(
                label: _uploading ? 'Uploading…' : 'Upload 2B JSON',
                icon: Icons.upload_file,
                isLoading: _uploading,
                onPressed: _pickAndUpload,
              ),
            ],
          ),
        ),
        if (hasData) ...[
          KSpacing.vGapMd,
          Row(
            children: [
              _metric('Matched', summary['matched'], KColors.success),
              KSpacing.hGapSm,
              _metric('Mismatch', summary['valueMismatch'], KColors.warning),
              KSpacing.hGapSm,
              _metric('Not in books', summary['notInBooks'], KColors.error),
            ],
          ),
          KSpacing.vGapSm,
          KCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('ITC at risk (supplier not filed)',
                    style: KTypography.bodyMedium),
                Text(
                  CurrencyFormatter.formatIndian(
                      (summary['itcAtRisk'] as num?)?.toDouble() ?? 0),
                  style:
                      KTypography.labelLarge.copyWith(color: KColors.error),
                ),
              ],
            ),
          ),
          if ((summary['supplierNotFiled'] as List?)?.isNotEmpty ?? false) ...[
            KSpacing.vGapMd,
            Text('Suppliers who did not file', style: KTypography.h3),
            KSpacing.vGapSm,
            ...(summary['supplierNotFiled'] as List).map((raw) {
              final row = Map<String, dynamic>.from(raw as Map);
              return Padding(
                padding: const EdgeInsets.only(bottom: KSpacing.sm),
                child: KCard(
                  child: Row(
                    children: [
                      const Icon(Icons.report_gmailerrorred,
                          color: KColors.error, size: 20),
                      KSpacing.hGapSm,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${row['vendorName']} · ${row['vendorBillNumber'] ?? row['billNumber']}',
                                style: KTypography.labelLarge),
                            Text(
                              'ITC ${CurrencyFormatter.formatIndian((row['itc'] as num?)?.toDouble() ?? 0)} at risk — follow up with the supplier',
                              style: KTypography.bodySmall
                                  .copyWith(color: KColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
          KSpacing.vGapMd,
          Row(
            children: [
              Text('Entries', style: KTypography.h3),
              const Spacer(),
              TextButton(
                onPressed: _loadEntries,
                child: Text(_entries == null ? 'Show all' : 'Refresh'),
              ),
            ],
          ),
          if (_entries != null)
            ...(_entries!).map((raw) {
              final e = Map<String, dynamic>.from(raw as Map);
              final status = e['matchStatus']?.toString() ?? '';
              final color = switch (status) {
                'MATCHED' => KColors.success,
                'VALUE_MISMATCH' => KColors.warning,
                'NOT_IN_BOOKS' => KColors.error,
                _ => KColors.textSecondary,
              };
              return Padding(
                padding: const EdgeInsets.only(bottom: KSpacing.sm),
                child: KCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${e['supplierName'] ?? e['supplierGstin']} · ${e['invoiceNumber']}',
                                style: KTypography.labelLarge),
                            Text(
                              CurrencyFormatter.formatIndian(
                                  (e['invoiceValue'] as num?)?.toDouble() ?? 0),
                              style: KTypography.bodySmall
                                  .copyWith(color: KColors.textSecondary),
                            ),
                            if ((e['matchNote']?.toString() ?? '').isNotEmpty)
                              Text(e['matchNote'].toString(),
                                  style: KTypography.bodySmall
                                      .copyWith(color: KColors.textHint)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(status.replaceAll('_', ' '),
                            style: KTypography.labelSmall
                                .copyWith(color: color)),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ] else ...[
          KSpacing.vGapLg,
          Center(
            child: Text('No 2B uploaded for this period yet',
                style:
                    KTypography.bodyMedium.copyWith(color: KColors.textHint)),
          ),
        ],
      ],
    );
  }

  Widget _metric(String label, Object? value, Color color) {
    return Expanded(
      child: KCard(
        child: Column(
          children: [
            Text('${value ?? 0}',
                style: KTypography.h2.copyWith(color: color)),
            Text(label,
                style: KTypography.bodySmall
                    .copyWith(color: KColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ── e-Invoice (IRN) Tab ──────────────────────────────────────────────────────

class EInvoicesTab extends ConsumerStatefulWidget {
  final List<dynamic>? eInvoices;
  final VoidCallback onChanged;

  const EInvoicesTab(
      {super.key, required this.eInvoices, required this.onChanged});

  @override
  ConsumerState<EInvoicesTab> createState() => _EInvoicesTabState();
}

class _EInvoicesTabState extends ConsumerState<EInvoicesTab> {
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    _loadEnabled();
  }

  Future<void> _loadEnabled() async {
    try {
      final enabled =
          await ref.read(gstRepositoryProvider).getEInvoiceEnabled();
      if (mounted) setState(() => _enabled = enabled);
    } catch (_) {}
  }

  Future<void> _toggleEnabled(bool value) async {
    setState(() => _enabled = value);
    try {
      await ref.read(gstRepositoryProvider).setEInvoiceEnabled(value);
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      setState(() => _enabled = !value);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not update: $e')));
    }
  }

  Future<void> _recordDialog(Map<String, dynamic> row) async {
    final irnCtrl = TextEditingController();
    final ackNoCtrl = TextEditingController();
    final ackDateCtrl = TextEditingController();
    final qrCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Record IRN — ${row['documentNumber']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: irnCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'IRN (64-char hash from the IRP)',
                  border: OutlineInputBorder(),
                ),
              ),
              KSpacing.vGapMd,
              TextField(
                controller: ackNoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ack number',
                  border: OutlineInputBorder(),
                ),
              ),
              KSpacing.vGapMd,
              TextField(
                controller: ackDateCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ack date (as on portal)',
                  border: OutlineInputBorder(),
                ),
              ),
              KSpacing.vGapMd,
              TextField(
                controller: qrCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Signed QR (optional, paste from response)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Record')),
        ],
      ),
    );
    if (ok != true || irnCtrl.text.trim().isEmpty || !mounted) return;
    try {
      await ref.read(gstRepositoryProvider).recordEInvoice(
            row['id'].toString(),
            irn: irnCtrl.text.trim(),
            ackNumber: ackNoCtrl.text.trim(),
            ackDate: ackDateCtrl.text.trim(),
            signedQr: qrCtrl.text.trim(),
          );
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not record: $e')));
    }
  }

  Future<void> _shareIrpJson(Map<String, dynamic> row) async {
    try {
      final json = await ref
          .read(gstRepositoryProvider)
          .eInvoicePortalJson(row['id'].toString());
      final pretty = const JsonEncoder.withIndent('  ').convert(json);
      await Share.share(pretty,
          subject: 'e-Invoice INV-01 JSON — ${row['documentNumber']}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not build JSON: $e')));
    }
  }

  Future<void> _cancelEntry(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel e-invoice entry'),
        content: Text('Cancel the e-invoice entry for ${row['documentNumber']}? '
            'If an IRN was generated, cancel it on the IRP within 24 hours too.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: KColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel entry'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(gstRepositoryProvider)
          .cancelEInvoice(row['id'].toString());
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not cancel: $e')));
    }
  }

  Future<void> _generateViaGsp(Map<String, dynamic> row) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
        const SnackBar(content: Text('Generating IRN via GSP...')));
    try {
      await ref
          .read(gstRepositoryProvider)
          .generateEInvoiceViaGsp(row['id'].toString());
      if (!mounted) return;
      messenger.showSnackBar(
          const SnackBar(content: Text('IRN generated via GSP')));
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('GSP: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.eInvoices ?? const [];
    return ListView(
      padding: KSpacing.pagePadding,
      children: [
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('e-Invoicing enabled'),
                subtitle: const Text(
                    'Turn on if your turnover crosses the e-invoice notification '
                    'threshold. Posted B2B invoices will then be flagged for IRN.'),
                value: _enabled ?? false,
                onChanged: _enabled == null ? null : _toggleEnabled,
              ),
            ],
          ),
        ),
        KSpacing.vGapMd,
        if (rows.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('No e-invoice entries yet',
                  style: KTypography.bodyMedium
                      .copyWith(color: KColors.textHint)),
            ),
          )
        else
          ...rows.map((raw) {
            final row = Map<String, dynamic>.from(raw as Map);
            final status = row['status']?.toString() ?? 'PENDING';
            final (color, icon) = switch (status) {
              'GENERATED' => (KColors.success, Icons.verified_outlined),
              'CANCELLED' => (KColors.textSecondary, Icons.cancel_outlined),
              _ => (KColors.warning, Icons.pending_actions),
            };
            final irn = row['irn']?.toString() ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: KSpacing.sm),
              child: KCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: color, size: 20),
                        KSpacing.hGapSm,
                        Expanded(
                          child: Text(
                            '${row['documentNumber']} · ${CurrencyFormatter.formatIndian((row['totalValue'] as num?)?.toDouble() ?? 0)}',
                            style: KTypography.labelLarge,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(status,
                              style: KTypography.labelSmall
                                  .copyWith(color: color)),
                        ),
                      ],
                    ),
                    KSpacing.vGapXs,
                    Text(
                      [
                        row['documentDate']?.toString() ?? '',
                        if (irn.isNotEmpty)
                          'IRN ${irn.length > 16 ? '${irn.substring(0, 16)}…' : irn}',
                      ].where((s) => s.isNotEmpty).join(' · '),
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textSecondary),
                    ),
                    if (status == 'PENDING') ...[
                      KSpacing.vGapSm,
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _shareIrpJson(row),
                              icon: const Icon(Icons.data_object, size: 16),
                              label: const Text('IRP JSON'),
                            ),
                          ),
                          KSpacing.hGapSm,
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _recordDialog(row),
                              icon: const Icon(Icons.task_alt, size: 16),
                              label: const Text('Record IRN'),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _generateViaGsp(row),
                            icon: const Icon(Icons.bolt, color: KColors.primary),
                            tooltip: 'Generate via GSP',
                          ),
                          IconButton(
                            onPressed: () => _cancelEntry(row),
                            icon: const Icon(Icons.close, color: KColors.error),
                            tooltip: 'Cancel entry',
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

// ── TDS Tab ──────────────────────────────────────────────────────────────────

class TdsTab extends ConsumerStatefulWidget {
  const TdsTab({super.key});

  @override
  ConsumerState<TdsTab> createState() => _TdsTabState();
}

class _TdsTabState extends ConsumerState<TdsTab> {
  late int _fy;
  late int _quarter;
  Map<String, dynamic>? _data;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fy = now.month >= 4 ? now.year : now.year - 1;
    final fyMonth = now.month >= 4 ? now.month - 3 : now.month + 9; // 1..12 in FY
    _quarter = ((fyMonth - 1) ~/ 3) + 1;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ref.read(gstRepositoryProvider).tds26q(_fy, _quarter);
      if (mounted) setState(() => _data = data);
    } catch (_) {
      if (mounted) setState(() => _data = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _share26q() async {
    if (_data == null) return;
    final pretty = const JsonEncoder.withIndent('  ').convert(_data);
    await Share.share(pretty, subject: 'Form 26Q data — Q$_quarter FY $_fy');
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final deductees = (data?['deductees'] as List?) ?? const [];
    return ListView(
      padding: KSpacing.pagePadding,
      children: [
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Form 26Q (TDS on vendor bills)', style: KTypography.h3),
              KSpacing.vGapSm,
              Text(
                'TDS deducts automatically on bills when the vendor master has '
                'TDS enabled (section + rate), honouring section thresholds. '
                'This prepares the quarterly deductee-wise data for filing.',
                style: KTypography.bodySmall
                    .copyWith(color: KColors.textSecondary),
              ),
              KSpacing.vGapMd,
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _fy,
                      decoration: const InputDecoration(
                        labelText: 'FY starting',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: List.generate(4, (i) {
                        final year = DateTime.now().year - i;
                        return DropdownMenuItem(
                            value: year,
                            child: Text('$year-${(year + 1) % 100}'));
                      }),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _fy = v);
                        _load();
                      },
                    ),
                  ),
                  KSpacing.hGapMd,
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _quarter,
                      decoration: const InputDecoration(
                        labelText: 'Quarter',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('Q1 Apr–Jun')),
                        DropdownMenuItem(value: 2, child: Text('Q2 Jul–Sep')),
                        DropdownMenuItem(value: 3, child: Text('Q3 Oct–Dec')),
                        DropdownMenuItem(value: 4, child: Text('Q4 Jan–Mar')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _quarter = v);
                        _load();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        KSpacing.vGapMd,
        if (_loading)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator()))
        else if (data == null)
          Center(
              child: Text('No TDS data for this quarter',
                  style: KTypography.bodyMedium
                      .copyWith(color: KColors.textHint)))
        else ...[
          Row(
            children: [
              Expanded(
                child: KCard(
                  child: Column(children: [
                    Text(
                        CurrencyFormatter.formatIndian(
                            (data['totalTdsDeducted'] as num?)?.toDouble() ??
                                0),
                        style:
                            KTypography.h2.copyWith(color: KColors.primary)),
                    Text('TDS deducted',
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary)),
                  ]),
                ),
              ),
              KSpacing.hGapSm,
              Expanded(
                child: KCard(
                  child: Column(children: [
                    Text('${data['deducteeCount'] ?? 0}',
                        style: KTypography.h2),
                    Text('Deductees',
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary)),
                  ]),
                ),
              ),
            ],
          ),
          if ((data['warning']?.toString() ?? '').isNotEmpty) ...[
            KSpacing.vGapSm,
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: KColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber,
                      color: KColors.warning, size: 18),
                  KSpacing.hGapSm,
                  Expanded(
                    child: Text(data['warning'].toString(),
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.warning)),
                  ),
                ],
              ),
            ),
          ],
          KSpacing.vGapSm,
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: deductees.isEmpty ? null : _share26q,
              icon: const Icon(Icons.ios_share, size: 16),
              label: const Text('Share 26Q data (JSON)'),
            ),
          ),
          KSpacing.vGapMd,
          ...deductees.map((raw) {
            final d = Map<String, dynamic>.from(raw as Map);
            final pan = d['deducteePan']?.toString() ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: KSpacing.sm),
              child: KCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d['deducteeName']?.toString() ?? '',
                              style: KTypography.labelLarge),
                          Text(
                            '${pan.isEmpty ? 'PAN MISSING' : pan} · ${d['section']} · ${d['billCount']} bill(s)',
                            style: KTypography.bodySmall.copyWith(
                                color: pan.isEmpty
                                    ? KColors.error
                                    : KColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                            CurrencyFormatter.formatIndian(
                                (d['tdsDeducted'] as num?)?.toDouble() ?? 0),
                            style: KTypography.labelLarge
                                .copyWith(color: KColors.primary)),
                        Text(
                            'on ${CurrencyFormatter.formatIndian((d['amountPaid'] as num?)?.toDouble() ?? 0)}',
                            style: KTypography.bodySmall
                                .copyWith(color: KColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}

// ── e-Way Bills Tab ──────────────────────────────────────────────────────────

class EwayBillsTab extends ConsumerStatefulWidget {
  final List<dynamic>? bills;
  final VoidCallback onChanged;

  const EwayBillsTab({super.key, required this.bills, required this.onChanged});

  @override
  ConsumerState<EwayBillsTab> createState() => _EwayBillsTabState();
}

class _EwayBillsTabState extends ConsumerState<EwayBillsTab> {
  Future<void> _recordDialog(Map<String, dynamic> bill) async {
    final ewbCtrl = TextEditingController();
    final vehicleCtrl =
        TextEditingController(text: bill['vehicleNumber']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Record e-way bill — ${bill['documentNumber']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ewbCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'EWB number (from NIC portal)',
                border: OutlineInputBorder(),
              ),
            ),
            KSpacing.vGapMd,
            TextField(
              controller: vehicleCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Vehicle number',
                hintText: 'e.g. MH12AB1234',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Record')),
        ],
      ),
    );
    if (ok != true || ewbCtrl.text.trim().isEmpty || !mounted) return;
    try {
      await ref.read(gstRepositoryProvider).recordEwayBill(
            bill['id'].toString(),
            ewbNumber: ewbCtrl.text.trim(),
            vehicleNumber: vehicleCtrl.text.trim(),
          );
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not record: $e')));
    }
  }

  Future<void> _sharePortalJson(Map<String, dynamic> bill) async {
    try {
      final json = await ref
          .read(gstRepositoryProvider)
          .ewayBillPortalJson(bill['id'].toString());
      final pretty = const JsonEncoder.withIndent('  ').convert(json);
      await Share.share(pretty,
          subject: 'e-Way bill JSON — ${bill['documentNumber']}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not build JSON: $e')));
    }
  }

  Future<void> _cancelEntry(Map<String, dynamic> bill) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel e-way bill entry'),
        content: Text(
            'Cancel the e-way bill entry for ${bill['documentNumber']}? '
            'If an EWB was generated on the portal, cancel it there too (within 24 hours).'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: KColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel entry'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(gstRepositoryProvider)
          .cancelEwayBill(bill['id'].toString());
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not cancel: $e')));
    }
  }

  Future<void> _generateViaGsp(Map<String, dynamic> bill) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
        const SnackBar(content: Text('Generating e-way bill via GSP...')));
    try {
      await ref
          .read(gstRepositoryProvider)
          .generateEwayBillViaGsp(bill['id'].toString());
      if (!mounted) return;
      messenger.showSnackBar(
          const SnackBar(content: Text('e-Way bill generated via GSP')));
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('GSP: $e')));
    }
  }

  Future<void> _checkVehicleDialog() async {
    final vehicleCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Check vehicle aggregate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'If the combined value of all documents in one vehicle crosses '
                '₹50,000, every document needs an e-way bill — even those '
                'individually below the limit.'),
            KSpacing.vGapMd,
            TextField(
              controller: vehicleCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Vehicle number',
                hintText: 'e.g. MH12AB1234',
                border: OutlineInputBorder(),
              ),
            ),
            KSpacing.vGapMd,
            TextField(
              controller: valueCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Value being loaded now (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Close')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Check')),
        ],
      ),
    );
    if (ok != true || vehicleCtrl.text.trim().isEmpty || !mounted) return;
    try {
      final today = DateTime.now();
      final date =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final result = await ref.read(gstRepositoryProvider).checkVehicle(
            vehicleNumber: vehicleCtrl.text.trim(),
            date: date,
            additionalValue: double.tryParse(valueCtrl.text.trim()),
          );
      if (!mounted) return;
      final required = result['ewayBillRequired'] == true;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(required ? Icons.warning_amber : Icons.check_circle,
                  color: required ? KColors.warning : KColors.success),
              KSpacing.hGapSm,
              Expanded(
                  child: Text(required
                      ? 'e-Way bills required'
                      : 'Below threshold')),
            ],
          ),
          content: Text(
            'Aggregate in ${result['vehicleNumber']}: '
            '${CurrencyFormatter.formatIndian((result['aggregateValue'] as num?)?.toDouble() ?? 0)}'
            ' (threshold ${CurrencyFormatter.formatIndian((result['threshold'] as num?)?.toDouble() ?? 0)})\n\n'
            '${result['note'] ?? ''}',
          ),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Check failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bills = widget.bills ?? const [];
    return ListView(
      padding: KSpacing.pagePadding,
      children: [
        KCard(
          child: Row(
            children: [
              const Icon(Icons.local_shipping_outlined, color: KColors.info),
              KSpacing.hGapSm,
              Expanded(
                child: Text(
                  'Invoices over ₹50,000 are flagged automatically when posted. '
                  'Splitting an order into smaller bills does not avoid the rule — '
                  'check the vehicle aggregate before dispatch.',
                  style: KTypography.bodySmall
                      .copyWith(color: KColors.textSecondary),
                ),
              ),
              KSpacing.hGapSm,
              OutlinedButton(
                onPressed: _checkVehicleDialog,
                child: const Text('Check vehicle'),
              ),
            ],
          ),
        ),
        KSpacing.vGapMd,
        if (bills.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('No e-way bill entries yet',
                  style: KTypography.bodyMedium
                      .copyWith(color: KColors.textHint)),
            ),
          )
        else
          ...bills.map((raw) {
            final bill = Map<String, dynamic>.from(raw as Map);
            final status = bill['status']?.toString() ?? 'PENDING';
            final (color, icon) = switch (status) {
              'GENERATED' => (KColors.success, Icons.verified_outlined),
              'CANCELLED' => (KColors.textSecondary, Icons.cancel_outlined),
              _ => (KColors.warning, Icons.pending_actions),
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: KSpacing.sm),
              child: KCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: color, size: 20),
                        KSpacing.hGapSm,
                        Expanded(
                          child: Text(
                            '${bill['documentNumber']} · ${CurrencyFormatter.formatIndian((bill['totalValue'] as num?)?.toDouble() ?? 0)}',
                            style: KTypography.labelLarge,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(status,
                              style: KTypography.labelSmall
                                  .copyWith(color: color)),
                        ),
                      ],
                    ),
                    KSpacing.vGapXs,
                    Text(
                      [
                        bill['documentDate']?.toString() ?? '',
                        if ((bill['ewbNumber']?.toString() ?? '').isNotEmpty)
                          'EWB ${bill['ewbNumber']}',
                        if ((bill['vehicleNumber']?.toString() ?? '')
                            .isNotEmpty)
                          'Vehicle ${bill['vehicleNumber']}',
                      ].where((s) => s.isNotEmpty).join(' · '),
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textSecondary),
                    ),
                    if (status == 'PENDING') ...[
                      KSpacing.vGapSm,
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _sharePortalJson(bill),
                              icon: const Icon(Icons.data_object, size: 16),
                              label: const Text('Portal JSON'),
                            ),
                          ),
                          KSpacing.hGapSm,
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _recordDialog(bill),
                              icon: const Icon(Icons.task_alt, size: 16),
                              label: const Text('Record EWB'),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _generateViaGsp(bill),
                            icon: const Icon(Icons.bolt, color: KColors.primary),
                            tooltip: 'Generate via GSP',
                          ),
                          IconButton(
                            onPressed: () => _cancelEntry(bill),
                            icon: const Icon(Icons.close, color: KColors.error),
                            tooltip: 'Cancel entry',
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// TCS 206C(1H) tab — settings toggle + quarterly Form 27EQ
// ─────────────────────────────────────────────────────────────────────────

class TcsTab extends ConsumerStatefulWidget {
  const TcsTab({super.key});

  @override
  ConsumerState<TcsTab> createState() => _TcsTabState();
}

class _TcsTabState extends ConsumerState<TcsTab> {
  late int _fy;
  late int _quarter;
  Map<String, dynamic>? _data;
  Map<String, dynamic>? _settings;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fy = now.month >= 4 ? now.year : now.year - 1;
    final fyMonth = now.month >= 4 ? now.month - 3 : now.month + 9;
    _quarter = ((fyMonth - 1) ~/ 3) + 1;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(gstRepositoryProvider);
      final results = await Future.wait([
        repo.tcs27eq(_fy, _quarter),
        repo.tcsSettings(),
      ]);
      if (mounted) {
        setState(() {
          _data = results[0];
          _settings = results[1];
        });
      }
    } catch (_) {
      if (mounted) setState(() => _data = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleEnabled(bool value) async {
    try {
      final updated = await ref
          .read(gstRepositoryProvider)
          .updateTcsSettings(enabled: value);
      if (mounted) setState(() => _settings = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not update: $e')));
      }
    }
  }

  Future<void> _share27eq() async {
    if (_data == null) return;
    final pretty = const JsonEncoder.withIndent('  ').convert(_data);
    await Share.share(pretty, subject: 'Form 27EQ data — Q$_quarter FY $_fy');
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final collectees = (data?['collectees'] as List?) ?? const [];
    final enabled = _settings?['enabled'] == true;
    return ListView(
      padding: KSpacing.pagePadding,
      children: [
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('TCS 206C(1H) on sales', style: KTypography.h3),
              KSpacing.vGapSm,
              Text(
                'If your turnover exceeds ₹10 crore, you must collect '
                '${_settings?['rate'] ?? '0.1'}% TCS from each buyer whose '
                'purchases cross ₹50 lakh in a financial year. When enabled, '
                'invoices add it automatically on the amount above ₹50 lakh.',
                style: KTypography.bodySmall
                    .copyWith(color: KColors.textSecondary),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('Collect TCS on invoices',
                    style: KTypography.labelLarge),
                value: enabled,
                onChanged: _loading ? null : _toggleEnabled,
              ),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _fy,
                      decoration: const InputDecoration(
                        labelText: 'FY starting',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: List.generate(4, (i) {
                        final year = DateTime.now().year - i;
                        return DropdownMenuItem(
                            value: year,
                            child: Text('$year-${(year + 1) % 100}'));
                      }),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _fy = v);
                        _load();
                      },
                    ),
                  ),
                  KSpacing.hGapMd,
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _quarter,
                      decoration: const InputDecoration(
                        labelText: 'Quarter',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('Q1 Apr–Jun')),
                        DropdownMenuItem(value: 2, child: Text('Q2 Jul–Sep')),
                        DropdownMenuItem(value: 3, child: Text('Q3 Oct–Dec')),
                        DropdownMenuItem(value: 4, child: Text('Q4 Jan–Mar')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _quarter = v);
                        _load();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        KSpacing.vGapMd,
        if (_loading)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator()))
        else if (data == null)
          Center(
              child: Text('No TCS data for this quarter',
                  style: KTypography.bodyMedium
                      .copyWith(color: KColors.textHint)))
        else ...[
          Row(
            children: [
              Expanded(
                child: KCard(
                  child: Column(children: [
                    Text(
                        CurrencyFormatter.formatIndian(
                            (data['totalTcsCollected'] as num?)?.toDouble() ??
                                0),
                        style:
                            KTypography.h2.copyWith(color: KColors.primary)),
                    Text('TCS collected',
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary)),
                  ]),
                ),
              ),
              KSpacing.hGapSm,
              Expanded(
                child: KCard(
                  child: Column(children: [
                    Text('${data['collecteeCount'] ?? 0}',
                        style: KTypography.h2),
                    Text('Buyers',
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary)),
                  ]),
                ),
              ),
            ],
          ),
          if ((data['warning']?.toString() ?? '').isNotEmpty) ...[
            KSpacing.vGapSm,
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: KColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber,
                      color: KColors.warning, size: 18),
                  KSpacing.hGapSm,
                  Expanded(
                    child: Text(data['warning'].toString(),
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.warning)),
                  ),
                ],
              ),
            ),
          ],
          KSpacing.vGapSm,
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: collectees.isEmpty ? null : _share27eq,
              icon: const Icon(Icons.ios_share, size: 16),
              label: const Text('Share 27EQ data (JSON)'),
            ),
          ),
          KSpacing.vGapMd,
          ...collectees.map((raw) {
            final c = Map<String, dynamic>.from(raw as Map);
            final pan = c['collecteePan']?.toString() ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: KSpacing.sm),
              child: KCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c['collecteeName']?.toString() ?? '',
                              style: KTypography.labelLarge),
                          Text(
                            '${pan.isEmpty ? 'PAN MISSING' : pan} · 206C(1H) · ${c['invoiceCount']} invoice(s)',
                            style: KTypography.bodySmall.copyWith(
                                color: pan.isEmpty
                                    ? KColors.error
                                    : KColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                            CurrencyFormatter.formatIndian(
                                (c['tcsCollected'] as num?)?.toDouble() ?? 0),
                            style: KTypography.labelLarge
                                .copyWith(color: KColors.primary)),
                        Text(
                            'on ${CurrencyFormatter.formatIndian((c['amountReceived'] as num?)?.toDouble() ?? 0)}',
                            style: KTypography.bodySmall
                                .copyWith(color: KColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}
