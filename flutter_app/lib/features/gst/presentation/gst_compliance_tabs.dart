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
