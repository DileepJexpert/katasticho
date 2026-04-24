import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/gst_repository.dart';

class GstDashboardScreen extends ConsumerStatefulWidget {
  const GstDashboardScreen({super.key});

  @override
  ConsumerState<GstDashboardScreen> createState() =>
      _GstDashboardScreenState();
}

class _GstDashboardScreenState extends ConsumerState<GstDashboardScreen> {
  late int _year;
  late int _month;
  Map<String, dynamic>? _gstr1;
  Map<String, dynamic>? _gstr3b;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.month == 1 ? now.year - 1 : now.year;
    _month = now.month == 1 ? 12 : now.month - 1;
    _loadData();
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
      ]);
      setState(() {
        _gstr1 = (results[0]['data'] ?? results[0]) as Map<String, dynamic>;
        _gstr3b = (results[1]['data'] ?? results[1]) as Map<String, dynamic>;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GST Returns')),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: KSpacing.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPeriodSelector(),
              KSpacing.vGapLg,

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_error != null)
                KErrorBanner(message: _error!)
              else ...[
                _buildGstr3bSection(),
                KSpacing.vGapLg,
                _buildGstr1Section(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return KCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _prevMonth,
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            '${_months[_month - 1]} $_year',
            style: KTypography.h3,
          ),
          IconButton(
            onPressed: _nextMonth,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildGstr3bSection() {
    if (_gstr3b == null) return const SizedBox.shrink();

    final totalInvoices = (_gstr3b!['totalInvoices'] as num?)?.toInt() ?? 0;
    final b2b = (_gstr3b!['b2bInvoices'] as num?)?.toInt() ?? 0;
    final b2cs = (_gstr3b!['b2csInvoices'] as num?)?.toInt() ?? 0;
    final totalTaxable = (_gstr3b!['totalTaxable'] as num?)?.toDouble() ?? 0;
    final totalTax = (_gstr3b!['totalTax'] as num?)?.toDouble() ?? 0;
    final igst = (_gstr3b!['totalIgst'] as num?)?.toDouble() ?? 0;
    final cgst = (_gstr3b!['totalCgst'] as num?)?.toDouble() ?? 0;
    final sgst = (_gstr3b!['totalSgst'] as num?)?.toDouble() ?? 0;
    final cess = (_gstr3b!['totalCess'] as num?)?.toDouble() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: KColors.secondary.withValues(alpha: 0.1),
                borderRadius: KSpacing.borderRadiusMd,
              ),
              child: const Icon(Icons.summarize, color: KColors.secondary, size: 20),
            ),
            KSpacing.hGapSm,
            Text('GSTR-3B Summary', style: KTypography.h3),
          ],
        ),
        KSpacing.vGapMd,
        Row(
          children: [
            Expanded(
              child: _GstStatCard(
                label: 'Total Invoices',
                value: '$totalInvoices',
                subtitle: 'B2B: $b2b  |  B2CS: $b2cs',
                icon: Icons.receipt_long,
                color: KColors.primary,
              ),
            ),
            KSpacing.hGapSm,
            Expanded(
              child: _GstStatCard(
                label: 'Taxable Value',
                value: CurrencyFormatter.formatCompact(totalTaxable),
                icon: Icons.account_balance_wallet,
                color: KColors.accent,
              ),
            ),
          ],
        ),
        KSpacing.vGapSm,
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tax Breakdown', style: KTypography.labelLarge),
              KSpacing.vGapMd,
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
              _TaxRow(label: 'Total Tax Liability', amount: totalTax, bold: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGstr1Section() {
    if (_gstr1 == null) return const SizedBox.shrink();

    final b2b = (_gstr1!['b2b'] as List?) ?? [];
    final fp = _gstr1!['fp']?.toString() ?? '';

    int invoiceCount = 0;
    for (final record in b2b) {
      final inv = (record as Map)['inv'] as List? ?? [];
      invoiceCount += inv.length;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: KColors.primary.withValues(alpha: 0.1),
                borderRadius: KSpacing.borderRadiusMd,
              ),
              child: const Icon(Icons.upload_file, color: KColors.primary, size: 20),
            ),
            KSpacing.hGapSm,
            Expanded(child: Text('GSTR-1 Detail', style: KTypography.h3)),
            if (fp.isNotEmpty)
              KStatusChip(status: 'INFO', label: 'FP: $fp'),
          ],
        ),
        KSpacing.vGapMd,

        if (b2b.isEmpty)
          KCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.info_outline, size: 32, color: KColors.textHint),
                    KSpacing.vGapSm,
                    Text('No B2B invoices for this period',
                        style: KTypography.bodyMedium),
                  ],
                ),
              ),
            ),
          )
        else ...[
          Text('B2B Invoices ($invoiceCount)', style: KTypography.labelLarge),
          KSpacing.vGapSm,
          ...b2b.map((record) {
            final rec = record as Map<String, dynamic>;
            final ctin = rec['ctin']?.toString() ?? '';
            final invList = (rec['inv'] as List?) ?? [];

            return KCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.business, size: 16, color: KColors.textSecondary),
                      KSpacing.hGapSm,
                      Expanded(
                        child: Text(ctin,
                            style: KTypography.labelMedium,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  KSpacing.vGapSm,
                  ...invList.map((inv) {
                    final invMap = inv as Map<String, dynamic>;
                    final inum = invMap['inum']?.toString() ?? '';
                    final idt = invMap['idt']?.toString() ?? '';
                    final val = (invMap['val'] as num?)?.toDouble() ?? 0;
                    final items = (invMap['itms'] as List?) ?? [];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
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
                          Expanded(
                            child: Text(
                              CurrencyFormatter.formatIndian(val),
                              style: KTypography.amountSmall,
                              textAlign: TextAlign.right,
                            ),
                          ),
                          KSpacing.hGapSm,
                          Text('${items.length} rate${items.length == 1 ? '' : 's'}',
                              style: KTypography.labelSmall
                                  .copyWith(color: KColors.textHint)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _GstStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const _GstStatCard({
    required this.label,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          KSpacing.vGapSm,
          Text(value, style: KTypography.amountMedium),
          Text(label, style: KTypography.bodySmall),
          if (subtitle != null)
            Text(subtitle!,
                style: KTypography.labelSmall.copyWith(color: KColors.textHint)),
        ],
      ),
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
