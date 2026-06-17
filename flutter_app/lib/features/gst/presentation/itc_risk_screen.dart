import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/gst_repository.dart';

/// ITC-at-risk monitor — the preventive, pre-cutoff view: which suppliers
/// haven't filed their GSTR-1 yet, how much of your input credit that puts at
/// risk, and a one-tap WhatsApp nudge to chase each one before the 11th.
class ItcRiskScreen extends ConsumerStatefulWidget {
  const ItcRiskScreen({super.key});

  @override
  ConsumerState<ItcRiskScreen> createState() => _ItcRiskScreenState();
}

class _ItcRiskScreenState extends ConsumerState<ItcRiskScreen> {
  late String _period; // YYYY-MM
  Map<String, dynamic>? _report;
  bool _loading = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    // Default to the month whose GSTR-1 deadline (11th) is the live window.
    final now = DateTime.now();
    final prev = DateTime(now.year, now.month - 1);
    _period = '${prev.year}-${prev.month.toString().padLeft(2, '0')}';
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ref.read(gstRepositoryProvider).getItcRisk(_period);
      if (mounted) setState(() => _report = r);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Could not load: ${e.toString().replaceAll('Exception: ', '')}'),
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshNow() async {
    setState(() => _refreshing = true);
    try {
      final r = await ref.read(gstRepositoryProvider).raiseItcRiskAlerts(_period);
      if (!mounted) return;
      final raised = r['alertsRaised'] as int? ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(raised > 0
            ? 'Pulled latest filings — $raised supplier(s) flagged to your AI Inbox'
            : 'Pulled latest filings — nothing new at risk'),
      ));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('Check failed: ${e.toString().replaceAll('Exception: ', '')}'),
      ));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _pickMonth() async {
    final parts = _period.split('-');
    final current = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2022),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked == null) return;
    setState(() => _period =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}');
    await _load();
  }

  Future<void> _remind(Map<String, dynamic> supplier) async {
    final url = supplier['whatsappUrl'] as String?;
    if (url != null && url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No WhatsApp number on file for this supplier'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final dataAvailable = report?['dataAvailable'] == true;
    final suppliers =
        (report?['suppliers'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('ITC at Risk'),
        actions: [
          TextButton.icon(
            onPressed: _loading ? null : _pickMonth,
            icon: const Icon(Icons.calendar_month, size: 18),
            label: Text(_period),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: KSpacing.pagePadding,
              children: [
                KCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.shield_outlined, color: KColors.warning),
                          KSpacing.hGapSm,
                          Expanded(
                            child: Text('Catch unfiled suppliers before the cutoff',
                                style: KTypography.h3),
                          ),
                        ],
                      ),
                      KSpacing.vGapSm,
                      Text(
                        'From April 2026, your GSTR-3B can only claim ITC that GSTR-2B '
                        'reflects — one supplier who hasn\'t filed blocks that credit. '
                        'This watches the real-time 2A and flags them before the 11th, '
                        'while you can still chase them.',
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary),
                      ),
                      KSpacing.vGapMd,
                      KButton(
                        label: _refreshing
                            ? 'Checking latest filings…'
                            : 'Check latest filings now',
                        icon: Icons.refresh,
                        isLoading: _refreshing,
                        onPressed: _refreshing ? null : _refreshNow,
                      ),
                      if (report != null) ...[
                        KSpacing.vGapSm,
                        _freshnessLine(report),
                      ],
                    ],
                  ),
                ),
                KSpacing.vGapMd,
                if (!dataAvailable)
                  KCard(
                    child: Column(
                      children: [
                        Icon(Icons.info_outline,
                            color: KColors.textSecondary, size: 32),
                        KSpacing.vGapSm,
                        Text(
                          report?['message'] as String? ??
                              'No filing data yet for this period.',
                          textAlign: TextAlign.center,
                          style: KTypography.bodyMedium
                              .copyWith(color: KColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                else if (suppliers.isEmpty)
                  KCard(
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: KColors.success),
                        KSpacing.hGapSm,
                        Expanded(
                          child: Text(
                            report?['message'] as String? ??
                                'No ITC at risk — everyone reported.',
                            style: KTypography.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  KCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total ITC at risk', style: KTypography.bodyMedium),
                        Text(
                          CurrencyFormatter.formatIndian(
                              (report?['totalItcAtRisk'] as num?)?.toDouble() ??
                                  0),
                          style: KTypography.h3.copyWith(color: KColors.error),
                        ),
                      ],
                    ),
                  ),
                  KSpacing.vGapSm,
                  ...suppliers.map(_supplierCard),
                ],
              ],
            ),
    );
  }

  /// "Signal: real-time GSTR-2A · refreshed 3h ago" — so the owner knows how
  /// fresh, and how trustworthy, the data behind the alert is.
  Widget _freshnessLine(Map<String, dynamic> report) {
    final source = report['source'] as String?;
    final refreshedRaw = report['lastRefreshedAt'] as String?;
    if (source == null && refreshedRaw == null) {
      return Text(
        'No filing data pulled yet for this period.',
        style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
      );
    }
    final sourceLabel = switch (source) {
      'GSTR_2A' => 'real-time GSTR-2A',
      'GSTR_2B' => 'GSTR-2B (frozen)',
      'UPLOAD' => 'manual upload',
      _ => source ?? 'unknown',
    };
    DateTime? refreshedAt;
    if (refreshedRaw != null) {
      refreshedAt = DateTime.tryParse(refreshedRaw)?.toLocal();
    }
    final age = refreshedAt == null ? null : DateTime.now().difference(refreshedAt);
    final stale = age != null && age.inHours >= 24;
    final color = stale ? KColors.warning : KColors.textSecondary;
    final when = age == null ? '' : ' · refreshed ${_ago(age)}';
    return Row(
      children: [
        Icon(stale ? Icons.history_toggle_off : Icons.sensors,
            size: 14, color: color),
        KSpacing.hGapXs,
        Expanded(
          child: Text(
            'Signal: $sourceLabel$when${stale ? ' — may be outdated' : ''}',
            style: KTypography.bodySmall.copyWith(color: color),
          ),
        ),
      ],
    );
  }

  String _ago(Duration d) {
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  Widget _supplierCard(Map<String, dynamic> s) {
    final invoices =
        (s['invoiceNumbers'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final phone = s['phone'] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(s['supplierName']?.toString() ?? 'Supplier',
                      style: KTypography.labelLarge),
                ),
                Text(
                  CurrencyFormatter.formatIndian(
                      (s['itcAtRisk'] as num?)?.toDouble() ?? 0),
                  style: KTypography.labelLarge.copyWith(color: KColors.error),
                ),
              ],
            ),
            if (s['gstin'] != null) ...[
              KSpacing.vGapXs,
              Text(s['gstin'].toString(),
                  style: KTypography.bodySmall
                      .copyWith(color: KColors.textSecondary)),
            ],
            KSpacing.vGapXs,
            Text(
              '${invoices.length} invoice(s) unreported: ${invoices.join(', ')}',
              style:
                  KTypography.bodySmall.copyWith(color: KColors.textSecondary),
            ),
            KSpacing.vGapSm,
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: (phone == null || phone.isEmpty)
                    ? null
                    : () => _remind(s),
                icon: const Icon(Icons.chat, size: 16),
                label: const Text('Remind on WhatsApp'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
