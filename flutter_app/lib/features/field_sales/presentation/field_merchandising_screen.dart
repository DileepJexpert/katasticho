import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../data/field_sales_repository.dart';

class FieldMerchandisingScreen extends ConsumerStatefulWidget {
  const FieldMerchandisingScreen({super.key});

  @override
  ConsumerState<FieldMerchandisingScreen> createState() =>
      _FieldMerchandisingScreenState();
}

class _FieldMerchandisingScreenState
    extends ConsumerState<FieldMerchandisingScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _audits = [];
  Map<String, dynamic>? _summary;
  String _selectedFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(fieldSalesRepositoryProvider);
      final results = await Future.wait([
        repo.getRecentMerchandising(),
        repo.getMerchandisingSummary(),
      ]);

      if (mounted) {
        setState(() {
          _audits = (results[0] as List).whereType<Map<String, dynamic>>().toList();
          _summary = results[1] as Map<String, dynamic>?;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load merchandising data: ${ApiErrorParser.message(e)}'),
            backgroundColor: KColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showImageDialog(String url, String customerName) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: KSpacing.md, vertical: KSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(KSpacing.radiusMd),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(customerName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  KSpacing.hGapMd,
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            KSpacing.vGapSm,
            ClipRRect(
              borderRadius: BorderRadius.circular(KSpacing.radiusLg),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(KSpacing.xl),
                  child: const Text('Failed to load image preview'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: KLoading()));
    }

    final filteredAudits = _audits.where((a) {
      if (_selectedFilter == 'ALL') return true;
      if (_selectedFilter == 'STOCK_OUT') return a['isStockOut'] == true;
      if (_selectedFilter == 'NON_COMPLIANT') {
        return a['planogramCompliance'] == 'NON_COMPLIANT';
      }
      return a['auditType'] == _selectedFilter;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Merchandising & Shelf Audits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Audits',
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(KSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary KPI Metrics
              _buildSummaryHeader(),
              KSpacing.vGapLg,

              // Filter Chips
              _buildFilterChips(),
              KSpacing.vGapMd,

              // Audits Feed
              if (filteredAudits.isEmpty)
                const KEmptyState(
                  title: 'No merchandising audits found',
                  subtitle: 'Field representatives can capture shelf photos during store visits.',
                  icon: Icons.storefront_outlined,
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredAudits.length,
                  separatorBuilder: (_, __) => KSpacing.vGapMd,
                  itemBuilder: (context, index) {
                    final audit = filteredAudits[index];
                    return _buildAuditCard(audit);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    final totalAudits = _summary?['totalAudits'] ?? _audits.length;
    final avgShelf = _summary?['averageShelfSharePct'] ?? 0;
    final compliance = _summary?['complianceRatePct'] ?? 100;
    final stockOuts = _summary?['stockOutCount'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'Total Audits',
            '$totalAudits',
            Icons.checklist_rtl_outlined,
            KColors.primary,
          ),
        ),
        KSpacing.hGapSm,
        Expanded(
          child: _buildMetricCard(
            'Avg Shelf Share',
            '$avgShelf%',
            Icons.pie_chart_outline,
            KColors.secondary,
          ),
        ),
        KSpacing.hGapSm,
        Expanded(
          child: _buildMetricCard(
            'Compliance Rate',
            '$compliance%',
            Icons.verified_outlined,
            compliance >= 80 ? KColors.success : KColors.warning,
          ),
        ),
        KSpacing.hGapSm,
        Expanded(
          child: _buildMetricCard(
            'Stock-Outs',
            '$stockOuts',
            Icons.warning_amber_outlined,
            stockOuts > 0 ? KColors.error : KColors.success,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return KCard(
      padding: const EdgeInsets.all(KSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: KTypography.caption.copyWith(color: KColors.textSecondary)),
              Icon(icon, size: 18, color: color),
            ],
          ),
          KSpacing.vGapSm,
          Text(
            value,
            style: KTypography.amountLarge.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'key': 'ALL', 'label': 'All Audits'},
      {'key': 'PRIMARY_SHELF', 'label': 'Primary Shelf'},
      {'key': 'SECONDARY_DISPLAY', 'label': 'Secondary Display'},
      {'key': 'NON_COMPLIANT', 'label': 'Non-Compliant'},
      {'key': 'STOCK_OUT', 'label': 'Stock-Outs'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f['key'];
          return Padding(
            padding: const EdgeInsets.only(right: KSpacing.sm),
            child: ChoiceChip(
              label: Text(f['label']!),
              selected: isSelected,
              selectedColor: KColors.primary.withValues(alpha: 0.15),
              labelStyle: TextStyle(
                color: isSelected ? KColors.primary : KColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (_) => setState(() => _selectedFilter = f['key']!),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAuditCard(Map<String, dynamic> audit) {
    final customerName = audit['customerName'] ?? 'Store Customer';
    final repName = audit['salespersonName'] ?? 'Sales Representative';
    final auditType = audit['auditType']?.toString().replaceAll('_', ' ') ?? 'PRIMARY SHELF';
    final compliance = audit['planogramCompliance'] ?? 'COMPLIANT';
    final shelfShare = audit['shelfSharePct'];
    final facingCount = audit['facingCount'];
    final isStockOut = audit['isStockOut'] == true;
    final competitorBrands = audit['competitorBrandNames'];
    final notes = audit['notes'];
    final photoUrl = audit['photoUrl']?.toString();
    final auditedAt = audit['auditedAt'] != null
        ? DateTime.tryParse(audit['auditedAt'].toString())
        : null;

    final formattedDate = auditedAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(auditedAt.toLocal())
        : '';

    return KCard(
      padding: const EdgeInsets.all(KSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Thumbnail or Icon
              if (photoUrl != null && photoUrl.isNotEmpty)
                GestureDetector(
                  onTap: () => _showImageDialog(photoUrl, customerName),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(KSpacing.radiusMd),
                    child: Image.network(
                      photoUrl,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 72,
                        height: 72,
                        color: KColors.primary.withValues(alpha: 0.1),
                        child: const Icon(Icons.camera_alt, color: KColors.primary),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: KColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(KSpacing.radiusMd),
                  ),
                  child: const Icon(Icons.storefront_outlined, color: KColors.primary, size: 32),
                ),
              KSpacing.hGapMd,

              // Customer & Rep Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(customerName, style: KTypography.h4),
                        ),
                        KStatusChip(status: compliance),
                      ],
                    ),
                    KSpacing.vGapXs,
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 14, color: KColors.textSecondary),
                        KSpacing.hGapXs,
                        Text(repName, style: KTypography.caption),
                        KSpacing.hGapMd,
                        const Icon(Icons.schedule, size: 14, color: KColors.textSecondary),
                        KSpacing.hGapXs,
                        Text(formattedDate, style: KTypography.caption),
                      ],
                    ),
                    KSpacing.vGapSm,
                    Wrap(
                      spacing: KSpacing.sm,
                      runSpacing: KSpacing.xs,
                      children: [
                        KStatusChip(status: auditType),
                        if (isStockOut)
                          const KStatusChip(status: 'STOCK OUT'),
                        if (shelfShare != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: KColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Shelf: $shelfShare%',
                              style: KTypography.caption.copyWith(
                                color: KColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (facingCount != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Facings: $facingCount',
                              style: KTypography.caption.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if ((competitorBrands != null && competitorBrands.isNotEmpty) ||
              (notes != null && notes.isNotEmpty)) ...[
            KSpacing.vGapSm,
            const Divider(color: KColors.border),
            if (competitorBrands != null && competitorBrands.isNotEmpty) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Competitors: ',
                    style: KTypography.caption.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Expanded(
                    child: Text(competitorBrands, style: KTypography.caption),
                  ),
                ],
              ),
              KSpacing.vGapXs,
            ],
            if (notes != null && notes.isNotEmpty)
              Text(
                'Remarks: $notes',
                style: KTypography.caption.copyWith(fontStyle: FontStyle.italic),
              ),
          ],
        ],
      ),
    );
  }
}
