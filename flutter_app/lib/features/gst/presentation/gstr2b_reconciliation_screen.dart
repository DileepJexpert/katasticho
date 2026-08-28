import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_money.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../../../core/widgets/k_text_field.dart';
import '../../../routing/app_router.dart';
import '../data/gst_repository.dart';
import '../data/gstr2b_reconciliation_model.dart';

class Gstr2bReconciliationScreen extends ConsumerStatefulWidget {
  const Gstr2bReconciliationScreen({super.key});

  @override
  ConsumerState<Gstr2bReconciliationScreen> createState() =>
      _Gstr2bReconciliationScreenState();
}

class _Gstr2bReconciliationScreenState
    extends ConsumerState<Gstr2bReconciliationScreen> {
  late String _period; // YYYY-MM
  bool _loading = false;
  bool _fetching = false;
  bool _uploading = false;

  Gstr2bSummaryModel? _summary;
  List<Gstr2bEntryModel> _entries = [];
  Gstr2bMatchCategory _selectedCategory = Gstr2bMatchCategory.all;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final prev = DateTime(now.year, now.month - 1);
    _period = '${prev.year}-${prev.month.toString().padLeft(2, '0')}';
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(gstRepositoryProvider);
      final summaryJson = await repo.getGstr2bSummary(_period);
      final entriesJson = await repo.listGstr2bEntries(_period);

      if (mounted) {
        setState(() {
          _summary = Gstr2bSummaryModel.fromJson(summaryJson);
          _entries = entriesJson
              .map((e) => Gstr2bEntryModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to load GSTR-2B: ${e.toString().replaceAll('Exception: ', '')}'),
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _prevPeriod() {
    final parts = _period.split('-');
    final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]) - 1);
    setState(() {
      _period = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
    });
    _loadData();
  }

  void _nextPeriod() {
    final parts = _period.split('-');
    final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]) + 1);
    setState(() {
      _period = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
    });
    _loadData();
  }

  Future<void> _pickPeriod() async {
    final parts = _period.split('-');
    final current = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null && mounted) {
      setState(() {
        _period = '${picked.year}-${picked.month.toString().padLeft(2, '0')}';
      });
      _loadData();
    }
  }

  Future<void> _fetchFromGsp() async {
    setState(() => _fetching = true);
    try {
      final res = await ref.read(gstRepositoryProvider).fetchGstr2bFromGsp(_period);
      if (!mounted) return;
      final mismatches = (res['valueMismatch'] as num? ?? 0) +
          (res['notInBooks'] as num? ?? 0);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(mismatches > 0
            ? 'GSTR-2B fetched: $mismatches issue(s) detected.'
            : 'GSTR-2B fetched: All invoices matched Books successfully!'),
        backgroundColor: mismatches > 0 ? KColors.warning : KColors.success,
      ));
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      final friendly = msg.contains('GSP_NOT_CONFIGURED')
          ? 'GSP credentials not configured. Upload the 2B JSON manually or configure credentials in Settings.'
          : 'Fetch failed: ${msg.replaceAll('Exception: ', '')}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendly)));
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  Future<void> _uploadJson({bool is2A = false}) async {
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
        throw const FormatException('File does not contain a valid JSON object.');
      }
      final res = await ref
          .read(gstRepositoryProvider)
          .uploadGstr2b(_period, json);
      if (!mounted) return;
      final mismatches = (res['valueMismatch'] as num? ?? 0) +
          (res['notInBooks'] as num? ?? 0);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(mismatches > 0
            ? 'Reconciled: $mismatches mismatch/unclaimed invoice(s) found.'
            : 'Reconciled: All invoices matched Books perfectly!'),
        backgroundColor: mismatches > 0 ? KColors.warning : KColors.success,
      ));
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Upload failed: ${e.toString().replaceAll('Exception: ', '')}'),
      ));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _openNudgeDialog(SupplierNotFiledModel supplier) {
    showDialog(
      context: context,
      builder: (ctx) => _VendorNudgeDialog(
        supplier: supplier,
        period: _period,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('GSTR-2B ITC Matcher & Vendor Follow-Up'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        actions: [
          KButton(
            label: _fetching ? 'Fetching...' : 'Auto-Fetch GSP',
            icon: Icons.cloud_download_outlined,
            variant: KButtonVariant.secondary,
            isLoading: _fetching,
            onPressed: (_fetching || _uploading) ? null : _fetchFromGsp,
          ),
          KSpacing.hGapSm,
          KButton(
            label: _uploading ? 'Uploading...' : 'Upload 2B JSON',
            icon: Icons.upload_file_outlined,
            variant: KButtonVariant.primary,
            isLoading: _uploading,
            onPressed: (_fetching || _uploading) ? null : () => _uploadJson(is2A: false),
          ),
          KSpacing.hGapMd,
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: KSpacing.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPeriodSelector(),
                  KSpacing.vGapLg,
                  if (_loading && summary == null)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(48.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (summary != null) ...[
                    _buildSummaryMetrics(summary),
                    KSpacing.vGapLg,
                    _buildCategoryTabs(summary),
                    KSpacing.vGapMd,
                    _buildSearchBar(),
                    KSpacing.vGapMd,
                    _buildListContent(summary),
                  ] else ...[
                    KCard(
                      child: KEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No GSTR-2B data for $_period',
                        subtitle:
                            'Auto-fetch via your GSP connection or upload the portal GSTR-2B JSON statement.',
                        actionLabel: 'Upload 2B JSON',
                        onAction: () => _uploadJson(is2A: false),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return KCard(
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.md, vertical: KSpacing.sm),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous month',
            onPressed: _prevPeriod,
          ),
          InkWell(
            onTap: _pickPeriod,
            borderRadius: BorderRadius.circular(KSpacing.radiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_outlined, size: 18, color: KColors.primary),
                  KSpacing.hGapSm,
                  Text(
                    'Return Period: $_period',
                    style: KTypography.h3,
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, size: 18),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next month',
            onPressed: _nextPeriod,
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetrics(Gstr2bSummaryModel summary) {
    return LayoutBuilder(builder: (context, constraints) {
      final isCompact = constraints.maxWidth < 800;
      final cards = [
        _MetricCard(
          title: 'Matched ITC',
          amount: summary.matchedItc,
          count: summary.matched,
          color: KColors.success,
          icon: Icons.check_circle_outline,
          subtitle: 'Eligible & ready to claim in 3B',
        ),
        _MetricCard(
          title: 'Value Mismatch',
          amount: summary.mismatchItc,
          count: summary.valueMismatch,
          color: KColors.warning,
          icon: Icons.warning_amber_rounded,
          subtitle: 'Rate/value difference vs Books',
        ),
        _MetricCard(
          title: 'Unclaimed in Books',
          amount: summary.missingItc,
          count: summary.notInBooks,
          color: const Color(0xFF2563EB),
          icon: Icons.mark_email_unread_outlined,
          subtitle: 'In 2B but bill missing in Books',
        ),
        _MetricCard(
          title: 'ITC at Risk',
          amount: summary.itcAtRisk,
          count: summary.supplierNotFiled.length,
          color: KColors.error,
          icon: Icons.error_outline,
          subtitle: 'Supplier has not filed GSTR-1',
        ),
      ];

      if (isCompact) {
        return Column(
          children: cards
              .map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: KSpacing.sm),
                    child: c,
                  ))
              .toList(),
        );
      }

      return Row(
        children: cards
            .map((c) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: c,
                  ),
                ))
            .toList(),
      );
    });
  }

  Widget _buildCategoryTabs(Gstr2bSummaryModel summary) {
    final matchedCount = summary.matched;
    final mismatchCount = summary.valueMismatch;
    final notInBooksCount = summary.notInBooks;
    final atRiskCount = summary.supplierNotFiled.length;
    final totalCount = summary.totalEntries + atRiskCount;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(
            category: Gstr2bMatchCategory.all,
            label: 'All Items ($totalCount)',
          ),
          KSpacing.hGapSm,
          _buildFilterChip(
            category: Gstr2bMatchCategory.matched,
            label: 'Matched ($matchedCount)',
            color: KColors.success,
          ),
          KSpacing.hGapSm,
          _buildFilterChip(
            category: Gstr2bMatchCategory.valueMismatch,
            label: 'Value Mismatch ($mismatchCount)',
            color: KColors.warning,
          ),
          KSpacing.hGapSm,
          _buildFilterChip(
            category: Gstr2bMatchCategory.notInBooks,
            label: 'Unclaimed in Books ($notInBooksCount)',
            color: const Color(0xFF2563EB),
          ),
          KSpacing.hGapSm,
          _buildFilterChip(
            category: Gstr2bMatchCategory.atRiskSupplierNotFiled,
            label: 'ITC at Risk ($atRiskCount)',
            color: KColors.error,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required Gstr2bMatchCategory category,
    required String label,
    Color? color,
  }) {
    final isSelected = _selectedCategory == category;
    final activeColor = color ?? KColors.primary;

    return InkWell(
      onTap: () => setState(() => _selectedCategory = category),
      borderRadius: BorderRadius.circular(KSpacing.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.12)
              : KColors.surface,
          borderRadius: BorderRadius.circular(KSpacing.radiusSm),
          border: Border.all(
            color: isSelected ? activeColor : KColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: KTypography.labelMedium.copyWith(
            color: isSelected ? activeColor : KColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return KTextField.search(
      hint: 'Search by vendor name, GSTIN, or invoice number...',
      onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
    );
  }

  Widget _buildListContent(Gstr2bSummaryModel summary) {
    if (_selectedCategory == Gstr2bMatchCategory.atRiskSupplierNotFiled) {
      return _buildAtRiskList(summary.supplierNotFiled);
    }

    final filteredEntries = _entries.where((e) {
      if (_selectedCategory == Gstr2bMatchCategory.matched &&
          e.matchStatus != 'MATCHED') {
        return false;
      }
      if (_selectedCategory == Gstr2bMatchCategory.valueMismatch &&
          e.matchStatus != 'VALUE_MISMATCH') {
        return false;
      }
      if (_selectedCategory == Gstr2bMatchCategory.notInBooks &&
          e.matchStatus != 'NOT_IN_BOOKS') {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final gstin = e.supplierGstin.toLowerCase();
        final name = (e.supplierName ?? '').toLowerCase();
        final inv = e.invoiceNumber.toLowerCase();
        if (!gstin.contains(_searchQuery) &&
            !name.contains(_searchQuery) &&
            !inv.contains(_searchQuery)) {
          return false;
        }
      }
      return true;
    }).toList();

    if (_selectedCategory == Gstr2bMatchCategory.all &&
        summary.supplierNotFiled.isNotEmpty &&
        _searchQuery.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAtRiskSection(summary.supplierNotFiled),
          KSpacing.vGapLg,
          Text('GSTR-2B Statement Invoices', style: KTypography.h3),
          KSpacing.vGapSm,
          _build2bEntriesList(filteredEntries),
        ],
      );
    }

    return _build2bEntriesList(filteredEntries);
  }

  Widget _buildAtRiskSection(List<SupplierNotFiledModel> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: KColors.error, size: 20),
            KSpacing.hGapSm,
            Text('ITC At Risk: Suppliers Missing in 2B (${list.length})',
                style: KTypography.h3.copyWith(color: KColors.error)),
          ],
        ),
        KSpacing.vGapSm,
        ...list.map((s) => _buildAtRiskCard(s)),
      ],
    );
  }

  Widget _buildAtRiskList(List<SupplierNotFiledModel> list) {
    final filtered = list.where((s) {
      if (_searchQuery.isEmpty) return true;
      final gstin = s.vendorGstin.toLowerCase();
      final name = s.vendorName.toLowerCase();
      final inv = (s.vendorBillNumber ?? s.billNumber).toLowerCase();
      return gstin.contains(_searchQuery) ||
          name.contains(_searchQuery) ||
          inv.contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return const KCard(
        child: KEmptyState(
          icon: Icons.check_circle_outline,
          title: 'No at-risk invoices',
          subtitle: 'All suppliers with posted bills have filed their GSTR-1.',
        ),
      );
    }

    return Column(
      children: filtered.map((s) => _buildAtRiskCard(s)).toList(),
    );
  }

  Widget _buildAtRiskCard(SupplierNotFiledModel s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.sm),
      child: KCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.vendorName, style: KTypography.h3),
                      KSpacing.vGapXs,
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: KColors.bgApp,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: KColors.border),
                            ),
                            child: Text(
                              s.vendorGstin,
                              style: KTypography.mono(fontSize: 11, color: KColors.textPrimary),
                            ),
                          ),
                          Text(
                            'Bill: ${s.vendorBillNumber ?? s.billNumber}',
                            style: KTypography.bodySmall
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (s.billDate != null)
                            Text(
                              'Date: ${s.billDate}',
                              style: KTypography.bodySmall
                                  .copyWith(color: KColors.textSecondary),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('ITC at Risk', style: KTypography.labelSmall),
                    KMoney(s.itc, style: KTypography.amountSmall.copyWith(color: KColors.error)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Bill Total: ',
                            style: KTypography.bodySmall
                                .copyWith(color: KColors.textSecondary)),
                        KMoney(s.totalAmount, size: KMoneySize.small),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            KSpacing.vGapMd,
            Container(
              padding: const EdgeInsets.all(KSpacing.sm),
              decoration: BoxDecoration(
                color: KColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(KSpacing.radiusSm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: KColors.error),
                  KSpacing.hGapSm,
                  Expanded(
                    child: Text(
                      'This bill is posted in your ERP, but the supplier did not upload it to the GST portal. Follow up before filing GSTR-3B to avoid disallowed credit.',
                      style: KTypography.bodySmall.copyWith(color: KColors.error),
                    ),
                  ),
                ],
              ),
            ),
            KSpacing.vGapMd,
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                KButton(
                  label: 'Nudge Supplier',
                  icon: Icons.notifications_active_outlined,
                  variant: KButtonVariant.primary,
                  onPressed: () => _openNudgeDialog(s),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _build2bEntriesList(List<Gstr2bEntryModel> list) {
    if (list.isEmpty) {
      return const KCard(
        child: KEmptyState(
          icon: Icons.search_off_outlined,
          title: 'No invoices found',
          subtitle: 'Try adjusting your category filter or search query.',
        ),
      );
    }

    return Column(
      children: list.map((e) => _build2bEntryCard(e)).toList(),
    );
  }

  Widget _build2bEntryCard(Gstr2bEntryModel e) {
    final status = e.matchStatus;
    final statusColor = switch (status) {
      'MATCHED' => KColors.success,
      'VALUE_MISMATCH' => KColors.warning,
      'NOT_IN_BOOKS' => const Color(0xFF2563EB),
      _ => KColors.textSecondary,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.sm),
      child: KCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.supplierName ?? 'Supplier ${e.supplierGstin}',
                          style: KTypography.h3),
                      KSpacing.vGapXs,
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: KColors.bgApp,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: KColors.border),
                            ),
                            child: Text(
                              e.supplierGstin,
                              style: KTypography.mono(fontSize: 11, color: KColors.textPrimary),
                            ),
                          ),
                          Text(
                            'Inv: ${e.invoiceNumber}',
                            style: KTypography.bodySmall
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (e.invoiceDate != null)
                            Text(
                              'Date: ${e.invoiceDate}',
                              style: KTypography.bodySmall
                                  .copyWith(color: KColors.textSecondary),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    KStatusChip(status: status),
                    KSpacing.vGapXs,
                    KMoney(e.invoiceValue, style: KTypography.amountSmall),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ITC: ',
                          style: KTypography.bodySmall.copyWith(
                              color: statusColor, fontWeight: FontWeight.w600),
                        ),
                        KMoney(
                          e.totalTax,
                          size: KMoneySize.small,
                          style: TextStyle(
                              color: statusColor, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            if (e.matchNote != null && e.matchNote!.isNotEmpty) ...[
              KSpacing.vGapSm,
              Container(
                padding: const EdgeInsets.all(KSpacing.sm),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                ),
                child: Row(
                  children: [
                    Icon(
                      status == 'MATCHED'
                          ? Icons.check_circle_outline
                          : Icons.info_outline,
                      size: 16,
                      color: statusColor,
                    ),
                    KSpacing.hGapSm,
                    Expanded(
                      child: Text(
                        e.matchNote!,
                        style: KTypography.bodySmall.copyWith(color: statusColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (status == 'NOT_IN_BOOKS') ...[
              KSpacing.vGapMd,
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  KButton(
                    label: 'Create Purchase Bill',
                    icon: Icons.add_circle_outline,
                    variant: KButtonVariant.secondary,
                    onPressed: () => context.push(Routes.billCreate),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final double amount;
  final int count;
  final Color color;
  final IconData icon;
  final String subtitle;

  const _MetricCard({
    required this.title,
    required this.amount,
    required this.count,
    required this.color,
    required this.icon,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              KSpacing.hGapSm,
              Expanded(
                child: Text(
                  title,
                  style: KTypography.labelMedium.copyWith(color: KColors.textSecondary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count',
                  style: KTypography.labelSmall.copyWith(color: color, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          KSpacing.vGapSm,
          KMoney(amount, style: KTypography.amountMedium.copyWith(color: color)),
          KSpacing.vGapXs,
          Text(subtitle, style: KTypography.caption.copyWith(color: KColors.textSecondary)),
        ],
      ),
    );
  }
}

class _VendorNudgeDialog extends StatefulWidget {
  final SupplierNotFiledModel supplier;
  final String period;

  const _VendorNudgeDialog({
    required this.supplier,
    required this.period,
  });

  @override
  State<_VendorNudgeDialog> createState() => _VendorNudgeDialogState();
}

class _VendorNudgeDialogState extends State<_VendorNudgeDialog> {
  late final TextEditingController _phoneCtl;
  late final TextEditingController _emailCtl;
  late final TextEditingController _msgCtl;

  @override
  void initState() {
    super.initState();
    _phoneCtl = TextEditingController(text: widget.supplier.phone ?? '');
    _emailCtl = TextEditingController(text: widget.supplier.email ?? '');

    final template = VendorNudgeHelper.buildNudgeMessage(
      vendorName: widget.supplier.vendorName,
      invoiceNo: widget.supplier.vendorBillNumber ?? widget.supplier.billNumber,
      invoiceDate: widget.supplier.billDate,
      invoiceAmount: widget.supplier.totalAmount,
      itcAmount: widget.supplier.itc,
      returnPeriod: widget.period,
    );
    _msgCtl = TextEditingController(text: template);
  }

  @override
  void dispose() {
    _phoneCtl.dispose();
    _emailCtl.dispose();
    _msgCtl.dispose();
    super.dispose();
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _msgCtl.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message copied to clipboard!')),
    );
  }

  Future<void> _sendWhatsApp() async {
    final phone = _phoneCtl.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid phone number for WhatsApp')),
      );
      return;
    }
    final ok = await VendorNudgeHelper.launchWhatsApp(
      phone: phone,
      message: _msgCtl.text,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch WhatsApp web/app')),
      );
    }
  }

  Future<void> _sendEmail() async {
    final email = _emailCtl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an email address')),
      );
      return;
    }
    final subject = 'Urgent: GST Filing Reminder - Invoice #${widget.supplier.vendorBillNumber ?? widget.supplier.billNumber}';
    final ok = await VendorNudgeHelper.launchEmail(
      email: email,
      subject: subject,
      body: _msgCtl.text,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch email client')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KSpacing.radiusMd)),
      child: Container(
        width: 540,
        padding: const EdgeInsets.all(KSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active_outlined, color: KColors.primary),
                KSpacing.hGapSm,
                Expanded(
                  child: Text('Nudge Supplier: ${widget.supplier.vendorName}',
                      style: KTypography.h3),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            KSpacing.vGapMd,
            Row(
              children: [
                Expanded(
                  child: KTextField(
                    label: 'Phone / WhatsApp',
                    controller: _phoneCtl,
                    prefixIcon: Icons.phone_outlined,
                    hint: 'e.g. 9876543210',
                  ),
                ),
                KSpacing.hGapMd,
                Expanded(
                  child: KTextField(
                    label: 'Email',
                    controller: _emailCtl,
                    prefixIcon: Icons.email_outlined,
                    hint: 'vendor@example.com',
                  ),
                ),
              ],
            ),
            KSpacing.vGapMd,
            KTextField(
              label: 'Message Copy',
              controller: _msgCtl,
              maxLines: 6,
            ),
            KSpacing.vGapLg,
            Row(
              children: [
                KButton(
                  label: 'Copy Text',
                  icon: Icons.copy_outlined,
                  variant: KButtonVariant.secondary,
                  onPressed: _copyToClipboard,
                ),
                const Spacer(),
                KButton(
                  label: 'Send Email',
                  icon: Icons.mail_outlined,
                  variant: KButtonVariant.secondary,
                  onPressed: _sendEmail,
                ),
                KSpacing.hGapSm,
                KButton(
                  label: 'WhatsApp',
                  icon: Icons.chat_bubble_outline,
                  variant: KButtonVariant.primary,
                  onPressed: _sendWhatsApp,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
