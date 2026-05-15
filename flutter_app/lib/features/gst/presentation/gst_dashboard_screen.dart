import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../../ai_chat/data/ai_inbox_models.dart';
import '../../ai_chat/data/ai_repository.dart';
import '../data/gst_repository.dart';

class GstDashboardScreen extends ConsumerStatefulWidget {
  const GstDashboardScreen({super.key});

  @override
  ConsumerState<GstDashboardScreen> createState() => _GstDashboardScreenState();
}

class _GstDashboardScreenState extends ConsumerState<GstDashboardScreen> {
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const _reviewFilters = ['PENDING', 'DEFERRED', 'ACCEPTED', 'ALL'];
  static const _gstSuggestionTypes = {
    'GST_AMOUNT_MISMATCH',
    'MISSING_HSN',
    'INVALID_GSTIN',
    'INVALID_GST_RATE',
    'DUPLICATE_INVOICE',
    'MISSING_TAX_ACCOUNT_MAPPING',
    'HSN_GST_SUGGESTION',
  };

  late int _year;
  late int _month;

  Map<String, dynamic>? _gstr1;
  Map<String, dynamic>? _gstr3b;
  bool _isLoading = false;
  String? _error;

  final ScrollController _reviewScrollController = ScrollController();
  final List<AiSuggestionItem> _gstSuggestions = [];
  bool _isReviewLoading = false;
  bool _isReviewRefreshing = false;
  bool _isReviewPageLoading = false;
  String? _reviewError;
  String _reviewStatus = 'PENDING';
  int _reviewPage = 0;
  int _reviewTotalPages = 1;

  bool get _canLoadMoreReviews => _reviewPage + 1 < _reviewTotalPages;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.month == 1 ? now.year - 1 : now.year;
    _month = now.month == 1 ? 12 : now.month - 1;
    _reviewScrollController.addListener(_onReviewScroll);
    _loadData();
    _loadReviewSuggestions(reset: true);
  }

  @override
  void dispose() {
    _reviewScrollController
      ..removeListener(_onReviewScroll)
      ..dispose();
    super.dispose();
  }

  void _onReviewScroll() {
    if (!_canLoadMoreReviews || _isReviewPageLoading || _isReviewLoading) {
      return;
    }
    if (_reviewScrollController.position.pixels >
        _reviewScrollController.position.maxScrollExtent - 280) {
      _loadMoreReviewSuggestions();
    }
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
      if (!mounted) return;
      setState(() {
        _gstr1 = (results[0]['data'] ?? results[0]) as Map<String, dynamic>;
        _gstr3b = (results[1]['data'] ?? results[1]) as Map<String, dynamic>;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load GST data');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadReviewSuggestions({required bool reset}) async {
    setState(() {
      _reviewError = null;
      if (reset) {
        _isReviewLoading = true;
        _reviewPage = 0;
        _reviewTotalPages = 1;
      } else {
        _isReviewRefreshing = true;
      }
    });

    try {
      final page = await ref.read(aiRepositoryProvider).listSuggestions(
            status: _reviewStatus,
            page: 0,
            size: 100,
          );
      if (!mounted) return;
      setState(() {
        _gstSuggestions
          ..clear()
          ..addAll(_filterGstSuggestions(page.content));
        _reviewPage = page.page;
        _reviewTotalPages = page.totalPages;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _reviewError = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isReviewLoading = false;
          _isReviewRefreshing = false;
        });
      }
    }
  }

  Future<void> _loadMoreReviewSuggestions() async {
    setState(() => _isReviewPageLoading = true);
    try {
      final page = await ref.read(aiRepositoryProvider).listSuggestions(
            status: _reviewStatus,
            page: _reviewPage + 1,
            size: 100,
          );
      if (!mounted) return;
      setState(() {
        _gstSuggestions.addAll(_filterGstSuggestions(page.content));
        _reviewPage = page.page;
        _reviewTotalPages = page.totalPages;
      });
    } catch (_) {
      // Keep current results visible.
    } finally {
      if (mounted) {
        setState(() => _isReviewPageLoading = false);
      }
    }
  }

  List<AiSuggestionItem> _filterGstSuggestions(List<AiSuggestionItem> items) {
    return items
        .where(
          (item) =>
              _gstSuggestionTypes.contains(item.suggestionType.toUpperCase()),
        )
        .toList();
  }

  Future<void> _reviewSuggestion(
    AiSuggestionItem item,
    String action, {
    String? correctionReason,
  }) async {
    try {
      await ref.read(aiRepositoryProvider).reviewSuggestion(
            item.id,
            action: action,
            correctionReason: correctionReason,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('GST issue ${action.toLowerCase()}ed.')),
      );
      await _loadReviewSuggestions(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Review failed: $e')),
      );
    }
  }

  Future<void> _openReviewDetail(AiSuggestionItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _GstSuggestionDetailSheet(
        item: item,
        onAccept: () => _reviewSuggestion(item, 'ACCEPT'),
        onDefer: () => _reviewSuggestion(item, 'DEFER'),
        onReject: (reason) =>
            _reviewSuggestion(item, 'REJECT', correctionReason: reason),
      ),
    );
  }

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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('GST Center'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Returns', icon: Icon(Icons.receipt_long_outlined)),
              Tab(
                  text: 'Review Center',
                  icon: Icon(Icons.rule_folder_outlined)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildReturnsTab(),
            _buildReviewTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildReturnsTab() {
    return RefreshIndicator(
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
    );
  }

  Widget _buildReviewTab() {
    if (_isReviewLoading) {
      return const KLoading(message: 'Loading GST review queue...');
    }

    if (_reviewError != null) {
      return KEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to load GST review center',
        subtitle: _reviewError,
        actionLabel: 'Retry',
        onAction: () => _loadReviewSuggestions(reset: true),
      );
    }

    final pendingCount =
        _gstSuggestions.where((item) => item.status == 'PENDING').length;
    final highPriorityCount = _gstSuggestions
        .where(
          (item) =>
              item.status == 'PENDING' && item.priority.toUpperCase() == 'HIGH',
        )
        .length;
    final issueTypeCount = _gstSuggestions
        .map((item) => item.suggestionType.toUpperCase())
        .toSet()
        .length;

    return RefreshIndicator(
      onRefresh: () => _loadReviewSuggestions(reset: false),
      child: ListView(
        controller: _reviewScrollController,
        padding: KSpacing.pagePadding,
        children: [
          _GstReviewHero(
            pendingCount: pendingCount,
            highPriorityCount: highPriorityCount,
            issueTypeCount: issueTypeCount,
            isRefreshing: _isReviewRefreshing,
          ),
          KSpacing.vGapMd,
          _GstFilterBar(
            selected: _reviewStatus,
            filters: _reviewFilters,
            onSelected: (value) {
              if (_reviewStatus == value) return;
              setState(() => _reviewStatus = value);
              _loadReviewSuggestions(reset: true);
            },
          ),
          KSpacing.vGapMd,
          if (_gstSuggestions.isEmpty)
            const SizedBox(
              height: 320,
              child: KEmptyState(
                icon: Icons.task_alt_outlined,
                title: 'No GST review items right now',
                subtitle:
                    'GST mismatches, missing HSN, invoice duplicates, and mapping issues will appear here.',
              ),
            )
          else ...[
            ..._gstSuggestions.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: KSpacing.sm),
                child: _GstReviewCard(
                  item: item,
                  onOpen: () => _openReviewDetail(item),
                  onAccept:
                      item.status == 'PENDING' || item.status == 'DEFERRED'
                          ? () => _reviewSuggestion(item, 'ACCEPT')
                          : null,
                  onDefer: item.status == 'PENDING'
                      ? () => _reviewSuggestion(item, 'DEFER')
                      : null,
                ),
              ),
            ),
            if (_isReviewPageLoading) ...[
              KSpacing.vGapSm,
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ],
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
              child: const Icon(
                Icons.summarize,
                color: KColors.secondary,
                size: 20,
              ),
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
              _TaxRow(
                label: 'Total Tax Liability',
                amount: totalTax,
                bold: true,
              ),
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
              child: const Icon(
                Icons.upload_file,
                color: KColors.primary,
                size: 20,
              ),
            ),
            KSpacing.hGapSm,
            Expanded(child: Text('GSTR-1 Detail', style: KTypography.h3)),
            if (fp.isNotEmpty) KStatusChip(status: 'INFO', label: 'FP: $fp'),
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
                    const Icon(
                      Icons.info_outline,
                      size: 32,
                      color: KColors.textHint,
                    ),
                    KSpacing.vGapSm,
                    Text(
                      'No B2B invoices for this period',
                      style: KTypography.bodyMedium,
                    ),
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
                      const Icon(
                        Icons.business,
                        size: 16,
                        color: KColors.textSecondary,
                      ),
                      KSpacing.hGapSm,
                      Expanded(
                        child: Text(
                          ctin,
                          style: KTypography.labelMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                                Text(
                                  idt,
                                  style: KTypography.bodySmall.copyWith(
                                    color: KColors.textHint,
                                  ),
                                ),
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
                          Text(
                            '${items.length} rate${items.length == 1 ? '' : 's'}',
                            style: KTypography.labelSmall.copyWith(
                              color: KColors.textHint,
                            ),
                          ),
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

class _GstReviewHero extends StatelessWidget {
  final int pendingCount;
  final int highPriorityCount;
  final int issueTypeCount;
  final bool isRefreshing;

  const _GstReviewHero({
    required this.pendingCount,
    required this.highPriorityCount,
    required this.issueTypeCount,
    required this.isRefreshing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return KCard(
      padding: const EdgeInsets.all(KSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GST Review Center', style: KTypography.h2),
                    KSpacing.vGapXs,
                    Text(
                      'Review tax mismatches, GSTIN quality, HSN gaps, and filing-risk issues before returns move forward.',
                      style: KTypography.bodySmall.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isRefreshing)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          KSpacing.vGapMd,
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final children = [
                _ReviewMetric(
                  icon: Icons.rule_outlined,
                  label: 'Open GST issues',
                  value: pendingCount.toString(),
                  color: KColors.primary,
                ),
                _ReviewMetric(
                  icon: Icons.priority_high_rounded,
                  label: 'High priority',
                  value: highPriorityCount.toString(),
                  color: KColors.warning,
                ),
                _ReviewMetric(
                  icon: Icons.category_outlined,
                  label: 'Issue types',
                  value: issueTypeCount.toString(),
                  color: KColors.info,
                ),
              ];

              if (wide) {
                return Row(
                  children: [
                    Expanded(child: children[0]),
                    KSpacing.hGapSm,
                    Expanded(child: children[1]),
                    KSpacing.hGapSm,
                    Expanded(child: children[2]),
                  ],
                );
              }

              return Column(
                children: [
                  children[0],
                  KSpacing.vGapSm,
                  children[1],
                  KSpacing.vGapSm,
                  children[2],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReviewMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ReviewMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: KSpacing.borderRadiusMd,
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: KSpacing.borderRadiusSm,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          KSpacing.hGapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: KTypography.h2),
                Text(
                  label,
                  style: KTypography.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GstFilterBar extends StatelessWidget {
  final String selected;
  final List<String> filters;
  final ValueChanged<String> onSelected;

  const _GstFilterBar({
    required this.selected,
    required this.filters,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters
            .map(
              (filter) => Padding(
                padding: const EdgeInsets.only(right: KSpacing.sm),
                child: ChoiceChip(
                  selected: selected == filter,
                  label: Text(filter.replaceAll('_', ' ')),
                  onSelected: (_) => onSelected(filter),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _GstReviewCard extends StatelessWidget {
  final AiSuggestionItem item;
  final VoidCallback onOpen;
  final VoidCallback? onAccept;
  final VoidCallback? onDefer;

  const _GstReviewCard({
    required this.item,
    required this.onOpen,
    this.onAccept,
    this.onDefer,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return KCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(KSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PriorityDot(priority: item.priority),
              KSpacing.hGapSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Text(
                          _beautify(item.suggestionType),
                          style: KTypography.h3,
                        ),
                        KStatusChip(
                            status: item.status, label: _beautify(item.status)),
                        _InlinePill(
                          label:
                              '${(item.confidence * 100).round()}% confident',
                          color: KColors.info,
                        ),
                      ],
                    ),
                    KSpacing.vGapXs,
                    Text(
                      '${_beautify(item.entityType)}${item.entityId != null ? ' • ${item.entityId!.substring(0, 8)}' : ''}',
                      style: KTypography.bodySmall.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: KColors.textHint),
            ],
          ),
          KSpacing.vGapSm,
          Text(
            item.reasoning.isEmpty ? 'No reasoning provided.' : item.reasoning,
            style: KTypography.bodyMedium,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          KSpacing.vGapSm,
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _MetaText(label: 'Priority', value: _beautify(item.priority)),
              if (item.suggestedAction != null &&
                  item.suggestedAction!.isNotEmpty)
                _MetaText(
                  label: 'Action',
                  value: _beautify(item.suggestedAction!),
                ),
              if (item.createdAt != null)
                _MetaText(
                  label: 'Created',
                  value: DateFormat('dd MMM, hh:mm a')
                      .format(item.createdAt!.toLocal()),
                ),
            ],
          ),
          if (onAccept != null || onDefer != null) ...[
            KSpacing.vGapMd,
            Row(
              children: [
                if (onAccept != null)
                  FilledButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.task_alt, size: 18),
                    label: const Text('Accept'),
                  ),
                if (onDefer != null) ...[
                  KSpacing.hGapSm,
                  OutlinedButton.icon(
                    onPressed: onDefer,
                    icon: const Icon(Icons.schedule_outlined, size: 18),
                    label: const Text('Defer'),
                  ),
                ],
                const Spacer(),
                TextButton(
                  onPressed: onOpen,
                  child: const Text('Review'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PriorityDot extends StatelessWidget {
  final String priority;

  const _PriorityDot({required this.priority});

  @override
  Widget build(BuildContext context) {
    final color = switch (priority.toUpperCase()) {
      'HIGH' => KColors.error,
      'MEDIUM' => KColors.warning,
      _ => KColors.info,
    };
    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _InlinePill extends StatelessWidget {
  final String label;
  final Color color;

  const _InlinePill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: KTypography.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  final String label;
  final String value;

  const _MetaText({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: KTypography.bodySmall.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        children: [
          TextSpan(text: '$label: '),
          TextSpan(
            text: value,
            style: KTypography.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GstSuggestionDetailSheet extends StatefulWidget {
  final AiSuggestionItem item;
  final Future<void> Function() onAccept;
  final Future<void> Function() onDefer;
  final Future<void> Function(String reason) onReject;

  const _GstSuggestionDetailSheet({
    required this.item,
    required this.onAccept,
    required this.onDefer,
    required this.onReject,
  });

  @override
  State<_GstSuggestionDetailSheet> createState() =>
      _GstSuggestionDetailSheetState();
}

class _GstSuggestionDetailSheetState extends State<_GstSuggestionDetailSheet> {
  bool _submitting = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _submitting = true);
    await action();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _reject() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject GST issue'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Optional reason for rejection',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (reason == null) return;
    setState(() => _submitting = true);
    await widget.onReject(reason);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: KSpacing.md,
          right: KSpacing.md,
          top: KSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + KSpacing.md,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _beautify(item.suggestionType),
                      style: KTypography.h2,
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _submitting ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                '${_beautify(item.entityType)}${item.entityId != null ? ' • ${item.entityId}' : ''}',
                style: KTypography.bodySmall.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              KSpacing.vGapMd,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  KStatusChip(
                      status: item.status, label: _beautify(item.status)),
                  _InlinePill(
                    label: _beautify(item.priority),
                    color: _priorityColor(item.priority),
                  ),
                  _InlinePill(
                    label: '${(item.confidence * 100).round()}% confidence',
                    color: KColors.info,
                  ),
                ],
              ),
              KSpacing.vGapMd,
              KCard(
                title: 'Reasoning',
                padding: const EdgeInsets.all(KSpacing.md),
                child: Text(
                  item.reasoning.isEmpty
                      ? 'No reasoning provided.'
                      : item.reasoning,
                  style: KTypography.bodyMedium,
                ),
              ),
              KSpacing.vGapMd,
              KCard(
                title: 'Suggested payload',
                padding: const EdgeInsets.all(KSpacing.md),
                child: SelectableText(
                  item.suggestedValue.entries.isEmpty
                      ? '{}'
                      : item.suggestedValue.entries
                          .map((entry) => '${entry.key}: ${entry.value}')
                          .join('\n'),
                  style: KTypography.bodySmall.copyWith(
                    color: cs.onSurface,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              KSpacing.vGapMd,
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (item.agentName != null)
                    _MetaText(label: 'Agent', value: item.agentName!),
                  if (item.modelName != null)
                    _MetaText(
                      label: 'Model',
                      value:
                          '${item.modelName}${item.modelVersion != null ? ' ${item.modelVersion}' : ''}',
                    ),
                  if (item.createdAt != null)
                    _MetaText(
                      label: 'Created',
                      value: DateFormat('dd MMM yyyy, hh:mm a')
                          .format(item.createdAt!.toLocal()),
                    ),
                  if (item.dueBy != null)
                    _MetaText(
                      label: 'Due',
                      value: DateFormat('dd MMM yyyy, hh:mm a')
                          .format(item.dueBy!.toLocal()),
                    ),
                ],
              ),
              KSpacing.vGapLg,
              if (_submitting)
                const Center(child: CircularProgressIndicator())
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: item.status == 'PENDING'
                            ? () => _run(widget.onDefer)
                            : null,
                        icon: const Icon(Icons.schedule_outlined),
                        label: const Text('Defer'),
                      ),
                    ),
                    KSpacing.hGapSm,
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (item.status == 'PENDING' ||
                                item.status == 'DEFERRED')
                            ? _reject
                            : null,
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Reject'),
                      ),
                    ),
                    KSpacing.hGapSm,
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: (item.status == 'PENDING' ||
                                item.status == 'DEFERRED')
                            ? () => _run(widget.onAccept)
                            : null,
                        icon: const Icon(Icons.task_alt),
                        label: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
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
            Text(
              subtitle!,
              style: KTypography.labelSmall.copyWith(color: KColors.textHint),
            ),
        ],
      ),
    );
  }
}

class _TaxRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool bold;

  const _TaxRow({
    required this.label,
    required this.amount,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: bold ? KTypography.labelLarge : KTypography.bodyMedium,
        ),
        Text(
          CurrencyFormatter.formatIndian(amount),
          style: bold ? KTypography.amountMedium : KTypography.amountSmall,
        ),
      ],
    );
  }
}

String _beautify(String value) {
  return value
      .replaceAll('_', ' ')
      .toLowerCase()
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

Color _priorityColor(String priority) {
  return switch (priority.toUpperCase()) {
    'HIGH' => KColors.error,
    'MEDIUM' => KColors.warning,
    _ => KColors.info,
  };
}
