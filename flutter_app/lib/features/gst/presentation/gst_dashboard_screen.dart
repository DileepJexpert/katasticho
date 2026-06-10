import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/gst_repository.dart';
import 'gst_compliance_tabs.dart';

class GstDashboardScreen extends ConsumerStatefulWidget {
  const GstDashboardScreen({super.key});

  @override
  ConsumerState<GstDashboardScreen> createState() =>
      _GstDashboardScreenState();
}

class _GstDashboardScreenState extends ConsumerState<GstDashboardScreen>
    with SingleTickerProviderStateMixin {
  late int _year;
  late int _month;
  Map<String, dynamic>? _gstr1;
  Map<String, dynamic>? _gstr3b;
  Map<String, dynamic>? _review;
  Map<String, dynamic>? _gstr2bSummary;
  List<dynamic>? _calendar;
  List<dynamic>? _ewayBills;
  List<dynamic>? _eInvoices;
  bool _isLoading = false;
  String? _error;
  late TabController _tabController;

  String get _period =>
      '${_year.toString().padLeft(4, '0')}-${_month.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    final now = DateTime.now();
    _year = now.month == 1 ? now.year - 1 : now.year;
    _month = now.month == 1 ? 12 : now.month - 1;
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(gstRepositoryProvider);
      final results = await Future.wait([
        repo.getGstr1(year: _year, month: _month),
        repo.getGstr3b(year: _year, month: _month),
        repo.getReviewCenter(status: 'PENDING'),
      ]);
      // Compliance extras load best-effort — the returns must render even if
      // these fail (e.g. nothing uploaded yet).
      List<dynamic>? calendar;
      List<dynamic>? ewayBills;
      List<dynamic>? eInvoices;
      Map<String, dynamic>? gstr2bSummary;
      try {
        calendar = await repo.getComplianceCalendar();
      } catch (_) {}
      try {
        ewayBills = await repo.listEwayBills();
      } catch (_) {}
      try {
        eInvoices = await repo.listEInvoices();
      } catch (_) {}
      try {
        gstr2bSummary = await repo.getGstr2bSummary(_period);
      } catch (_) {}
      setState(() {
        _gstr1 = (results[0]['data'] ?? results[0]) as Map<String, dynamic>;
        _gstr3b = (results[1]['data'] ?? results[1]) as Map<String, dynamic>;
        _review = (results[2]['data'] ?? results[2]) as Map<String, dynamic>;
        _calendar = calendar;
        _ewayBills = ewayBills;
        _eInvoices = eInvoices;
        _gstr2bSummary = gstr2bSummary;
      });
    } catch (e) {
      setState(() => _error = 'Failed to load GST data');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  void _prevMonth() {
    setState(() {
      if (_month == 1) {
        _month = 12;
        _year--;
      } else {
        _month--;
      }
    });
    _loadData();
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_year == now.year && _month >= now.month) return;
    setState(() {
      if (_month == 12) {
        _month = 1;
        _year++;
      } else {
        _month++;
      }
    });
    _loadData();
  }

  Future<void> _exportJson(String type) async {
    final data = type == 'GSTR-1' ? _gstr1 : _gstr3b;
    if (data == null) return;
    final pretty = const JsonEncoder.withIndent('  ').convert(data);
    await Share.share(
      pretty,
      subject: '$type Export — ${_months[_month - 1]} $_year',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GST Compliance'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Calendar'),
            Tab(text: 'GSTR-3B'),
            Tab(text: 'GSTR-1'),
            Tab(text: '2B Recon'),
            Tab(text: 'e-Invoice'),
            Tab(text: 'e-Way Bills'),
            Tab(text: 'TDS'),
            Tab(text: 'Review'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Column(
          children: [
            _buildPeriodSelector(),
            if (_isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Expanded(child: KErrorBanner(message: _error!))
            else
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    GstCalendarTab(items: _calendar),
                    _Gstr3bTab(
                      data: _gstr3b,
                      onExport: () => _exportJson('GSTR-3B'),
                    ),
                    _Gstr1Tab(
                      data: _gstr1,
                      months: _months,
                      month: _month,
                      year: _year,
                      onExport: () => _exportJson('GSTR-1'),
                    ),
                    Gstr2bTab(
                      period: _period,
                      summary: _gstr2bSummary,
                      onChanged: _loadData,
                    ),
                    EInvoicesTab(
                      eInvoices: _eInvoices,
                      onChanged: _loadData,
                    ),
                    EwayBillsTab(
                      bills: _ewayBills,
                      onChanged: _loadData,
                    ),
                    const TdsTab(),
                    _GstReviewTab(
                      data: _review,
                      onReviewed: _loadData,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _prevMonth,
            icon: const Icon(Icons.chevron_left),
          ),
          SizedBox(
            width: 120,
            child: Text(
              '${_months[_month - 1]} $_year',
              style: KTypography.h3,
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            onPressed: _nextMonth,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

// ── GSTR-3B Tab ──────────────────────────────────────────────────────────────

class _Gstr3bTab extends StatelessWidget {
  final Map<String, dynamic>? data;
  final VoidCallback onExport;

  const _Gstr3bTab({required this.data, required this.onExport});

  @override
  Widget build(BuildContext context) {
    if (data == null) return const SizedBox.shrink();

    final totalInvoices = (data!['totalInvoices'] as num?)?.toInt() ?? 0;
    final b2b = (data!['b2bInvoices'] as num?)?.toInt() ?? 0;
    final b2cs = (data!['b2csInvoices'] as num?)?.toInt() ?? 0;
    final cnCount = (data!['creditNoteCount'] as num?)?.toInt() ?? 0;
    final billCount = (data!['billCount'] as num?)?.toInt() ?? 0;
    final totalTaxable = (data!['totalTaxable'] as num?)?.toDouble() ?? 0;
    final totalTax = (data!['totalTax'] as num?)?.toDouble() ?? 0;
    final igst = (data!['totalIgst'] as num?)?.toDouble() ?? 0;
    final cgst = (data!['totalCgst'] as num?)?.toDouble() ?? 0;
    final sgst = (data!['totalSgst'] as num?)?.toDouble() ?? 0;
    final cess = (data!['totalCess'] as num?)?.toDouble() ?? 0;
    final itcIgst = (data!['totalItcIgst'] as num?)?.toDouble() ?? 0;
    final itcCgst = (data!['totalItcCgst'] as num?)?.toDouble() ?? 0;
    final itcSgst = (data!['totalItcSgst'] as num?)?.toDouble() ?? 0;
    final itcCess = (data!['totalItcCess'] as num?)?.toDouble() ?? 0;
    final totalItc = (data!['totalItc'] as num?)?.toDouble() ?? 0;
    final netPayable = (data!['netPayable'] as num?)?.toDouble() ?? 0;

    return ListView(
      padding: KSpacing.pagePadding,
      children: [
        // Net payable highlight card
        _NetPayableCard(netPayable: netPayable),
        KSpacing.vGapLg,

        // Counts
        Row(
          children: [
            Expanded(
              child: _GstStatCard(
                label: 'Sales Invoices',
                value: '$totalInvoices',
                subtitle: 'B2B: $b2b  |  B2CS: $b2cs',
                icon: Icons.receipt_long,
                color: KColors.primary,
              ),
            ),
            KSpacing.hGapSm,
            Expanded(
              child: _GstStatCard(
                label: 'Credit Notes',
                value: '$cnCount',
                subtitle: '$billCount purchase bills',
                icon: Icons.receipt,
                color: KColors.error,
              ),
            ),
          ],
        ),
        KSpacing.vGapSm,
        _GstStatCard(
          label: 'Taxable Value (Net)',
          value: CurrencyFormatter.formatIndian(totalTaxable),
          icon: Icons.account_balance_wallet,
          color: KColors.accent,
          wide: true,
        ),
        KSpacing.vGapLg,

        // Output tax section
        _SectionHeader(
          icon: Icons.arrow_upward,
          color: KColors.error,
          title: 'Output Tax Liability',
        ),
        KSpacing.vGapSm,
        KCard(
          child: Column(
            children: [
              _TaxRow(label: 'IGST', amount: igst),
              const Divider(height: 16),
              _TaxRow(label: 'CGST', amount: cgst),
              const Divider(height: 16),
              _TaxRow(label: 'SGST', amount: sgst),
              if (cess > 0) ...[
                const Divider(height: 16),
                _TaxRow(label: 'CESS', amount: cess),
              ],
              const Divider(height: 16),
              _TaxRow(label: 'Total Output Tax', amount: totalTax, bold: true),
            ],
          ),
        ),
        KSpacing.vGapLg,

        // ITC section
        _SectionHeader(
          icon: Icons.arrow_downward,
          color: KColors.success,
          title: 'Input Tax Credit (ITC)',
        ),
        KSpacing.vGapSm,
        KCard(
          child: Column(
            children: [
              _TaxRow(label: 'IGST (ITC)', amount: itcIgst),
              const Divider(height: 16),
              _TaxRow(label: 'CGST (ITC)', amount: itcCgst),
              const Divider(height: 16),
              _TaxRow(label: 'SGST (ITC)', amount: itcSgst),
              if (itcCess > 0) ...[
                const Divider(height: 16),
                _TaxRow(label: 'CESS (ITC)', amount: itcCess),
              ],
              const Divider(height: 16),
              _TaxRow(label: 'Total ITC Available', amount: totalItc, bold: true),
            ],
          ),
        ),
        KSpacing.vGapLg,

        // Export button
        OutlinedButton.icon(
          onPressed: onExport,
          icon: const Icon(Icons.share),
          label: const Text('Export GSTR-3B JSON'),
        ),
        KSpacing.vGapLg,
      ],
    );
  }
}

// ── GSTR-1 Tab ───────────────────────────────────────────────────────────────

class _Gstr1Tab extends StatelessWidget {
  final Map<String, dynamic>? data;
  final List<String> months;
  final int month;
  final int year;
  final VoidCallback onExport;

  const _Gstr1Tab({
    required this.data,
    required this.months,
    required this.month,
    required this.year,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    if (data == null) return const SizedBox.shrink();

    final b2b = (data!['b2b'] as List?) ?? [];
    final b2cs = (data!['b2cs'] as List?) ?? [];
    final cdnr = (data!['cdnr'] as List?) ?? [];
    final cdnur = (data!['cdnur'] as List?) ?? [];
    final hsnsac = (data!['hsnsac'] as List?) ?? [];
    final fp = data!['fp']?.toString() ?? '';

    int b2bInvoiceCount = 0;
    for (final record in b2b) {
      final inv = (record as Map)['inv'] as List? ?? [];
      b2bInvoiceCount += inv.length;
    }

    return ListView(
      padding: KSpacing.pagePadding,
      children: [
        // Period chip
        if (fp.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: KStatusChip(status: 'INFO', label: 'Period: $fp'),
          ),
        KSpacing.vGapMd,

        // Summary chips
        Row(
          children: [
            _CountBadge(label: 'B2B', count: b2bInvoiceCount, color: KColors.primary),
            KSpacing.hGapSm,
            _CountBadge(label: 'B2CS', count: b2cs.length, color: KColors.accent),
            KSpacing.hGapSm,
            _CountBadge(label: 'CDNR', count: cdnr.length, color: KColors.error),
          ],
        ),
        KSpacing.vGapLg,

        // B2B section
        _SectionHeader(
          icon: Icons.business,
          color: KColors.primary,
          title: 'B2B Invoices ($b2bInvoiceCount)',
        ),
        KSpacing.vGapSm,
        if (b2b.isEmpty)
          _EmptySection(message: 'No B2B invoices for this period')
        else
          ...b2b.map((record) => _B2bRecord(record: record as Map<String, dynamic>)),
        KSpacing.vGapLg,

        // B2CS section
        _SectionHeader(
          icon: Icons.person,
          color: KColors.accent,
          title: 'B2CS Supplies (${b2cs.length})',
        ),
        KSpacing.vGapSm,
        if (b2cs.isEmpty)
          _EmptySection(message: 'No B2CS supplies for this period')
        else
          KCard(
            child: Column(
              children: b2cs.asMap().entries.map((entry) {
                final rec = entry.value as Map<String, dynamic>;
                final typ = rec['sply_tp']?.toString() ?? '';
                final pos = rec['pos']?.toString() ?? '';
                final rt = (rec['rt'] as num?)?.toDouble() ?? 0;
                final txval = (rec['txval'] as num?)?.toDouble() ?? 0;
                final iamt = (rec['iamt'] as num?)?.toDouble() ?? 0;
                final camt = (rec['camt'] as num?)?.toDouble() ?? 0;
                final samt = (rec['samt'] as num?)?.toDouble() ?? 0;
                final totalTax = iamt + camt + samt;
                return Column(
                  children: [
                    if (entry.key > 0) const Divider(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$typ — State $pos', style: KTypography.labelMedium),
                              Text('Rate: $rt%',
                                  style: KTypography.bodySmall
                                      .copyWith(color: KColors.textHint)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(CurrencyFormatter.formatIndian(txval),
                                style: KTypography.amountSmall),
                            Text('Tax: ${CurrencyFormatter.formatIndian(totalTax)}',
                                style: KTypography.bodySmall
                                    .copyWith(color: KColors.textHint)),
                          ],
                        ),
                      ],
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        KSpacing.vGapLg,

        // CDNR section
        if (cdnr.isNotEmpty || cdnur.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.undo,
            color: KColors.error,
            title: 'Credit Notes (CDNR: ${cdnr.length}, CDNUR: ${cdnur.length})',
          ),
          KSpacing.vGapSm,
          if (cdnr.isNotEmpty)
            ...cdnr.map((record) => _CdnrRecord(record: record as Map<String, dynamic>)),
          if (cdnur.isNotEmpty)
            KCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unregistered (${cdnur.length})', style: KTypography.labelMedium),
                  KSpacing.vGapSm,
                  ...cdnur.map((cn) {
                    final m = cn as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(m['nt_num']?.toString() ?? '',
                              style: KTypography.labelSmall),
                          Text(
                            CurrencyFormatter.formatIndian(
                                (m['val'] as num?)?.toDouble() ?? 0),
                            style: KTypography.amountSmall,
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          KSpacing.vGapLg,
        ],

        // HSN summary
        _SectionHeader(
          icon: Icons.category,
          color: KColors.secondary,
          title: 'HSN/SAC Summary (${hsnsac.length})',
        ),
        KSpacing.vGapSm,
        if (hsnsac.isEmpty)
          _EmptySection(message: 'No HSN data for this period')
        else
          KCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(flex: 2, child: Text('HSN', style: KTypography.labelSmall)),
                    Expanded(child: Text('Taxable', style: KTypography.labelSmall, textAlign: TextAlign.right)),
                    Expanded(child: Text('Tax', style: KTypography.labelSmall, textAlign: TextAlign.right)),
                  ],
                ),
                const Divider(),
                ...hsnsac.map((item) {
                  final m = item as Map<String, dynamic>;
                  final hsn = m['hsn_sc']?.toString() ?? '';
                  final txval = (m['txval'] as num?)?.toDouble() ?? 0;
                  final totTx = (m['tot_tx'] as num?)?.toDouble() ?? 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(hsn, style: KTypography.bodySmall),
                        ),
                        Expanded(
                          child: Text(
                            CurrencyFormatter.formatCompact(txval),
                            style: KTypography.amountSmall,
                            textAlign: TextAlign.right,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            CurrencyFormatter.formatCompact(totTx),
                            style: KTypography.amountSmall,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        KSpacing.vGapLg,

        // Export button
        OutlinedButton.icon(
          onPressed: onExport,
          icon: const Icon(Icons.share),
          label: const Text('Export GSTR-1 JSON'),
        ),
        KSpacing.vGapLg,
      ],
    );
  }
}

// ── Helper Widgets ────────────────────────────────────────────────────────────

class _NetPayableCard extends StatelessWidget {
  final double netPayable;

  const _NetPayableCard({required this.netPayable});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: netPayable > 0
              ? [KColors.error.withValues(alpha: 0.85), KColors.error]
              : [KColors.success.withValues(alpha: 0.85), KColors.success],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: KSpacing.borderRadiusLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Net Tax Payable',
              style: KTypography.labelLarge.copyWith(color: Colors.white70)),
          KSpacing.vGapSm,
          Text(
            CurrencyFormatter.formatIndian(netPayable),
            style: KTypography.h1.copyWith(color: Colors.white),
          ),
          KSpacing.vGapXs,
          Text(
            netPayable > 0 ? 'Amount to be paid to government' : 'No liability this period',
            style: KTypography.bodySmall.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;

  const _SectionHeader({
    required this.icon,
    required this.color,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: KSpacing.borderRadiusSm,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        KSpacing.hGapSm,
        Text(title, style: KTypography.h3),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _CountBadge({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: KSpacing.borderRadiusMd,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(label, style: KTypography.labelSmall.copyWith(color: color)),
          KSpacing.hGapXs,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: KTypography.labelSmall.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  final String message;

  const _EmptySection({required this.message});

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.info_outline, size: 28, color: KColors.textHint),
              KSpacing.vGapSm,
              Text(message, style: KTypography.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _B2bRecord extends StatelessWidget {
  final Map<String, dynamic> record;

  const _B2bRecord({required this.record});

  @override
  Widget build(BuildContext context) {
    final ctin = record['ctin']?.toString() ?? '';
    final invList = (record['inv'] as List?) ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.business, size: 14, color: KColors.textSecondary),
                KSpacing.hGapXs,
                Expanded(
                  child: Text(ctin,
                      style: KTypography.labelMedium,
                      overflow: TextOverflow.ellipsis),
                ),
                Text('${invList.length} inv',
                    style: KTypography.labelSmall.copyWith(color: KColors.textHint)),
              ],
            ),
            KSpacing.vGapSm,
            ...invList.map((inv) {
              final invMap = inv as Map<String, dynamic>;
              final inum = invMap['inum']?.toString() ?? '';
              final idt = invMap['idt']?.toString() ?? '';
              final val = (invMap['val'] as num?)?.toDouble() ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(inum, style: KTypography.labelSmall),
                          Text(idt,
                              style: KTypography.bodySmall
                                  .copyWith(color: KColors.textHint)),
                        ],
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatIndian(val),
                      style: KTypography.amountSmall,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _CdnrRecord extends StatelessWidget {
  final Map<String, dynamic> record;

  const _CdnrRecord({required this.record});

  @override
  Widget build(BuildContext context) {
    final ctin = record['ctin']?.toString() ?? '';
    final ntList = (record['nt'] as List?) ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.business, size: 14, color: KColors.textSecondary),
                KSpacing.hGapXs,
                Expanded(
                  child: Text(ctin,
                      style: KTypography.labelMedium,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            KSpacing.vGapSm,
            ...ntList.map((nt) {
              final m = nt as Map<String, dynamic>;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(m['nt_num']?.toString() ?? '', style: KTypography.labelSmall),
                  Text(
                    CurrencyFormatter.formatIndian(
                        (m['val'] as num?)?.toDouble() ?? 0),
                    style: KTypography.amountSmall,
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _GstStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final bool wide;

  const _GstStatCard({
    required this.label,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: wide
          ? Row(
              children: [
                Icon(icon, color: color, size: 28),
                KSpacing.hGapMd,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: KTypography.amountMedium),
                    Text(label, style: KTypography.bodySmall),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: KTypography.labelSmall
                              .copyWith(color: KColors.textHint)),
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 24),
                KSpacing.vGapSm,
                Text(value, style: KTypography.amountMedium),
                Text(label, style: KTypography.bodySmall),
                if (subtitle != null)
                  Text(subtitle!,
                      style: KTypography.labelSmall
                          .copyWith(color: KColors.textHint)),
              ],
            ),
    );
  }
}

class _GstReviewTab extends ConsumerStatefulWidget {
  final Map<String, dynamic>? data;
  final Future<void> Function() onReviewed;

  const _GstReviewTab({required this.data, required this.onReviewed});

  @override
  ConsumerState<_GstReviewTab> createState() => _GstReviewTabState();
}

class _GstReviewTabState extends ConsumerState<_GstReviewTab> {
  String? _busyId;

  Future<void> _review(String id, String action) async {
    setState(() => _busyId = id);
    try {
      await ref.read(gstRepositoryProvider).reviewSuggestion(id, action: action);
      await widget.onReviewed();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update GST issue: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    if (data == null) return const SizedBox.shrink();

    final issues = (data['issues'] as List?) ?? const [];
    final pending = (data['pendingIssues'] as num?)?.toInt() ?? 0;
    final critical = (data['criticalIssues'] as num?)?.toInt() ?? 0;
    final high = (data['highIssues'] as num?)?.toInt() ?? 0;
    final reviewed = (data['reviewedIssues'] as num?)?.toInt() ?? 0;

    return ListView(
      padding: KSpacing.pagePadding,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 900 ? 4 : 2;
            return GridView.count(
              crossAxisCount: columns,
              childAspectRatio: 3.1,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: [
                _GstStatCard(
                    label: 'Pending',
                    value: '$pending',
                    icon: Icons.pending_actions_outlined,
                    color: KColors.warning),
                _GstStatCard(
                    label: 'Critical',
                    value: '$critical',
                    icon: Icons.priority_high_rounded,
                    color: KColors.error),
                _GstStatCard(
                    label: 'High',
                    value: '$high',
                    icon: Icons.report_problem_outlined,
                    color: KColors.warning),
                _GstStatCard(
                    label: 'Reviewed',
                    value: '$reviewed',
                    icon: Icons.verified_outlined,
                    color: KColors.success),
              ],
            );
          },
        ),
        KSpacing.vGapMd,
        if (issues.isEmpty)
          const KEmptyState(
            icon: Icons.verified_outlined,
            title: 'No GST review issues',
            subtitle: 'AI and rule checks have not found pending GST issues.',
          )
        else
          ...issues.map((raw) {
            final issue = raw as Map<String, dynamic>;
            final id = issue['id']?.toString() ?? '';
            final priority = issue['priority']?.toString() ?? 'MEDIUM';
            final title = issue['title']?.toString() ?? 'GST review issue';
            final category = issue['category']?.toString() ?? '';
            final reasoning = issue['reasoning']?.toString() ?? '';
            final source = issue['sourceNumber']?.toString();
            final entityType = issue['entityType']?.toString();
            final entityId = issue['entityId']?.toString();
            final isBusy = _busyId == id;
            final color = priority == 'CRITICAL'
                ? KColors.error
                : priority == 'HIGH'
                    ? KColors.warning
                    : KColors.primary;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: KCard(
                child: InkWell(
                  onTap: entityType == 'INVOICE' && entityId != null
                      ? () => context.push('/invoices/$entityId')
                      : null,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.fact_check_outlined, color: color),
                      KSpacing.hGapMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                    child: Text(title,
                                        style: KTypography.labelLarge)),
                                KStatusChip(status: priority, label: priority),
                              ],
                            ),
                            KSpacing.vGapXs,
                            Text(category.replaceAll('_', ' '),
                                style: KTypography.labelSmall
                                    .copyWith(color: KColors.textHint)),
                            if (source != null && source.isNotEmpty)
                              Text(source, style: KTypography.bodySmall),
                            if (reasoning.isNotEmpty) ...[
                              KSpacing.vGapXs,
                              Text(reasoning, style: KTypography.bodySmall),
                            ],
                          ],
                        ),
                      ),
                      KSpacing.hGapMd,
                      Column(
                        children: [
                          KButton(
                            label: 'Accept',
                            icon: Icons.check_rounded,
                            size: KButtonSize.small,
                            onPressed:
                                isBusy ? null : () => _review(id, 'ACCEPT'),
                          ),
                          KSpacing.vGapXs,
                          KButton(
                            label: 'Ignore',
                            icon: Icons.close_rounded,
                            variant: KButtonVariant.outlined,
                            size: KButtonSize.small,
                            onPressed:
                                isBusy ? null : () => _review(id, 'REJECT'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _TaxRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool bold;

  const _TaxRow({required this.label, required this.amount, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: bold ? KTypography.labelLarge : KTypography.bodyMedium),
        Text(
          CurrencyFormatter.formatIndian(amount),
          style: bold ? KTypography.amountMedium : KTypography.amountSmall,
        ),
      ],
    );
  }
}
