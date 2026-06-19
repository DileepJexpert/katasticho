import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/ai_inbox_models.dart';
import '../data/ai_repository.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: KColors.accent.withValues(alpha: 0.15),
                borderRadius: KSpacing.borderRadiusSm,
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 20,
                color: KColors.accent,
              ),
            ),
            KSpacing.hGapSm,
            const Text('AI Command Center'),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Inbox', icon: Icon(Icons.inbox_outlined)),
            Tab(text: 'Assistant', icon: Icon(Icons.chat_bubble_outline)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _AiInboxTab(),
          _AiAssistantTab(),
        ],
      ),
    );
  }
}

class _AiInboxTab extends ConsumerStatefulWidget {
  const _AiInboxTab();

  @override
  ConsumerState<_AiInboxTab> createState() => _AiInboxTabState();
}

class _AiInboxTabState extends ConsumerState<_AiInboxTab> {
  static const _filters = ['PENDING', 'DEFERRED', 'ACCEPTED', 'ALL'];

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _entryController = TextEditingController();
  bool _entryBusy = false;
  String _selectedStatus = 'PENDING';
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  AiInboxSummary? _summary;
  final List<AiSuggestionItem> _suggestions = [];
  int _page = 0;
  int _totalPages = 1;
  bool _isPageLoading = false;

  bool get _canLoadMore => _page + 1 < _totalPages;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _quickEntry() async {
    final text = _entryController.text.trim();
    if (text.isEmpty || _entryBusy) return;
    setState(() => _entryBusy = true);
    try {
      final data = await ref.read(aiRepositoryProvider).draftEntry(text);
      if (!mounted) return;
      if (data['drafted'] == true) {
        _entryController.clear();
        final warnings = (data['warnings'] as List?) ?? const [];
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(warnings.isEmpty
              ? 'Drafted — review and approve below.'
              : 'Drafted with a note: ${warnings.first}'),
        ));
        await _load(reset: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(data['message']?.toString() ?? 'Could not draft that.'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Entry failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _entryBusy = false);
    }
  }

  void _onScroll() {
    if (!_canLoadMore || _isPageLoading || _isLoading) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 280) {
      _loadMore();
    }
  }

  Future<void> _load({required bool reset}) async {
    setState(() {
      _error = null;
      if (reset) {
        _isLoading = true;
        _page = 0;
        _totalPages = 1;
      } else {
        _isRefreshing = true;
      }
    });

    try {
      final repo = ref.read(aiRepositoryProvider);
      final results = await Future.wait([
        repo.getSuggestionSummary(),
        repo.listSuggestions(status: _selectedStatus, page: 0, size: 20),
      ]);
      final summary = results[0] as AiInboxSummary;
      final page = results[1] as AiSuggestionPage;

      if (!mounted) return;
      setState(() {
        _summary = summary;
        _suggestions
          ..clear()
          ..addAll(page.content);
        _page = page.page;
        _totalPages = page.totalPages;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isPageLoading = true);
    try {
      final repo = ref.read(aiRepositoryProvider);
      final next = await repo.listSuggestions(
        status: _selectedStatus,
        page: _page + 1,
        size: 20,
      );
      if (!mounted) return;
      setState(() {
        _suggestions.addAll(next.content);
        _page = next.page;
        _totalPages = next.totalPages;
      });
    } catch (_) {
      // Keep the current page visible; refresh is enough for recovery.
    } finally {
      if (mounted) {
        setState(() => _isPageLoading = false);
      }
    }
  }

  Future<void> _reviewSuggestion(
    AiSuggestionItem item,
    String action, {
    String? correctionReason,
  }) async {
    try {
      final repo = ref.read(aiRepositoryProvider);
      // Drafted bills are posted/deleted via the bill-drafting endpoints — the
      // generic review only flips status and would leave the bill unposted.
      if (item.suggestionType == 'DRAFT_BILL' && action == 'ACCEPT') {
        final posted = await repo.approveBillDraft(item.id);
        if (!mounted) return;
        final billNumber = posted['billNumber']?.toString() ?? '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  billNumber.isEmpty ? 'Bill posted.' : 'Bill $billNumber posted.')),
        );
        await _load(reset: true);
        return;
      }
      if (item.suggestionType == 'DRAFT_BILL' && action == 'REJECT') {
        await repo.rejectBillDraft(item.id, reason: correctionReason);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Drafted bill rejected.')),
        );
        await _load(reset: true);
        return;
      }
      // Conversational entries post/delete via the entry endpoints.
      if (item.suggestionType == 'DRAFT_ENTRY' && action == 'ACCEPT') {
        final posted = await repo.approveEntryDraft(item.id);
        if (!mounted) return;
        final entryNumber = posted['narration']?.toString() ?? '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(entryNumber.isEmpty ? 'Entry posted.' : 'Posted: $entryNumber')),
        );
        await _load(reset: true);
        return;
      }
      if (item.suggestionType == 'DRAFT_ENTRY' && action == 'REJECT') {
        await repo.rejectEntryDraft(item.id, reason: correctionReason);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Drafted entry discarded.')),
        );
        await _load(reset: true);
        return;
      }
      await repo.reviewSuggestion(
        item.id,
        action: action,
        correctionReason: correctionReason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Suggestion ${action.toLowerCase()}ed.')),
      );
      await _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Review failed: $e')),
      );
    }
  }

  Future<void> _openDetail(AiSuggestionItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AiSuggestionDetailSheet(
        item: item,
        onAccept: () => _reviewSuggestion(item, 'ACCEPT'),
        onDefer: () => _reviewSuggestion(item, 'DEFER'),
        onReject: (reason) =>
            _reviewSuggestion(item, 'REJECT', correctionReason: reason),
      ),
    );
  }

  Future<void> _runSweep() async {
    if (_entryBusy) return;
    setState(() => _entryBusy = true);
    try {
      final r = await ref.read(aiRepositoryProvider).runProactiveSweep();
      if (!mounted) return;
      final total = (r['collections'] as num? ?? 0) +
          (r['monthClose'] as num? ?? 0) +
          (r['anomalies'] as num? ?? 0);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(total == 0
            ? 'All clear — nothing new to flag.'
            : 'Found $total new item(s): '
                '${r['collections'] ?? 0} collections, '
                '${r['anomalies'] ?? 0} anomalies.'),
      ));
      await _load(reset: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Sweep failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _entryBusy = false);
    }
  }

  Widget _buildQuickEntry() {
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, size: 18, color: KColors.primary),
              KSpacing.hGapXs,
              Text('Quick entry', style: KTypography.labelLarge),
              const Spacer(),
              TextButton.icon(
                onPressed: _entryBusy ? null : _runSweep,
                icon: const Icon(Icons.radar, size: 16),
                label: const Text('Run checks'),
              ),
            ],
          ),
          KSpacing.vGapXs,
          Text(
            'Type what happened — we draft the entry for you to approve.',
            style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
          ),
          KSpacing.vGapSm,
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _entryController,
                  enabled: !_entryBusy,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _quickEntry(),
                  decoration: const InputDecoration(
                    hintText: 'e.g. paid 5000 cash for shop rent',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              KSpacing.hGapSm,
              _entryBusy
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton.filled(
                      onPressed: _quickEntry,
                      icon: const Icon(Icons.send),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const KLoading(message: 'Loading AI inbox...');
    }

    if (_error != null) {
      return KEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to load AI inbox',
        subtitle: _error,
        actionLabel: 'Retry',
        onAction: () => _load(reset: true),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(reset: false),
      child: ListView(
        controller: _scrollController,
        padding: KSpacing.pagePadding,
        children: [
          _AiInboxHero(
            summary: _summary ??
                const AiInboxSummary(pending: 0, highPriorityPending: 0),
            isRefreshing: _isRefreshing,
          ),
          KSpacing.vGapMd,
          _buildQuickEntry(),
          KSpacing.vGapMd,
          _AiFilterBar(
            selected: _selectedStatus,
            filters: _filters,
            onSelected: (value) {
              if (_selectedStatus == value) return;
              setState(() => _selectedStatus = value);
              _load(reset: true);
            },
          ),
          KSpacing.vGapMd,
          if (_suggestions.isEmpty)
            const SizedBox(
              height: 320,
              child: KEmptyState(
                icon: Icons.task_alt_outlined,
                title: 'No AI suggestions right now',
                subtitle:
                    'As invoices, payments, and stock events flow in, review items will appear here.',
              ),
            )
          else
            ..._suggestions.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: KSpacing.sm),
                child: _AiSuggestionCard(
                  item: item,
                  onOpen: () => _openDetail(item),
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
          if (_isPageLoading) ...[
            KSpacing.vGapSm,
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}

class _AiInboxHero extends StatelessWidget {
  final AiInboxSummary summary;
  final bool isRefreshing;

  const _AiInboxHero({
    required this.summary,
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
                    Text('Review queue', style: KTypography.h2),
                    KSpacing.vGapXs,
                    Text(
                      'AI suggestions stay here until you accept, reject, or defer them.',
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
              final wide = constraints.maxWidth >= 720;
              final cards = [
                _SummaryMetric(
                  icon: Icons.inbox_outlined,
                  label: 'Pending',
                  value: summary.pending.toString(),
                  color: KColors.primary,
                ),
                _SummaryMetric(
                  icon: Icons.priority_high_rounded,
                  label: 'High priority',
                  value: summary.highPriorityPending.toString(),
                  color: KColors.warning,
                ),
              ];
              if (wide) {
                return Row(
                  children: [
                    Expanded(child: cards[0]),
                    KSpacing.hGapSm,
                    Expanded(child: cards[1]),
                  ],
                );
              }
              return Column(
                children: [
                  cards[0],
                  KSpacing.vGapSm,
                  cards[1],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryMetric({
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
        border: Border.all(color: color.withValues(alpha: 0.18)),
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

class _AiFilterBar extends StatelessWidget {
  final String selected;
  final List<String> filters;
  final ValueChanged<String> onSelected;

  const _AiFilterBar({
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

class _AiSuggestionCard extends StatelessWidget {
  final AiSuggestionItem item;
  final VoidCallback onOpen;
  final VoidCallback? onAccept;
  final VoidCallback? onDefer;

  const _AiSuggestionCard({
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
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _beautify(item.suggestionType),
                          style: KTypography.h3,
                        ),
                        _InlinePill(
                          label: _beautify(item.status),
                          color: _statusColor(item.status),
                        ),
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
                  child: const Text('Open'),
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

class _AiSuggestionDetailSheet extends StatefulWidget {
  final AiSuggestionItem item;
  final Future<void> Function() onAccept;
  final Future<void> Function() onDefer;
  final Future<void> Function(String reason) onReject;

  const _AiSuggestionDetailSheet({
    required this.item,
    required this.onAccept,
    required this.onDefer,
    required this.onReject,
  });

  @override
  State<_AiSuggestionDetailSheet> createState() =>
      _AiSuggestionDetailSheetState();
}

class _AiSuggestionDetailSheetState extends State<_AiSuggestionDetailSheet> {
  bool _submitting = false;

  Future<void> _reject() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject suggestion'),
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

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _submitting = true);
    await action();
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
                  _InlinePill(
                    label: _beautify(item.status),
                    color: _statusColor(item.status),
                  ),
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
                  const JsonEncoder.withIndent('  ')
                      .convert(item.suggestedValue),
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

class _AiAssistantTab extends ConsumerStatefulWidget {
  const _AiAssistantTab();

  @override
  ConsumerState<_AiAssistantTab> createState() => _AiAssistantTabState();
}

class _AiAssistantTabState extends ConsumerState<_AiAssistantTab> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      _ChatMessage(
        text:
            "Hi! I'm your AI assistant. Ask about your data, record a payment, or "
            "check who owes you — I'll handle it.\n\n"
            "Try:\n"
            "- \"What's my total revenue this month?\"\n"
            "- \"Paid 5000 cash for shop rent\"\n"
            "- \"Who owes me money?\"\n"
            "- \"Compare this month vs last month\"",
        isUser: false,
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      final aiRepo = ref.read(aiRepositoryProvider);
      final result = await aiRepo.agent(text);

      // For data queries, the tool payload carries the result rows to render.
      Map<String, dynamic>? rows;
      if (result['tool'] == 'query_data' && result['data'] is Map) {
        final q = result['data'] as Map<String, dynamic>;
        rows = q['results'] as Map<String, dynamic>?;
      }

      setState(() {
        _messages.add(
          _ChatMessage(
            text: result['reply'] as String? ?? 'I couldn\'t process that.',
            isUser: false,
            data: rows,
            actionRequired: result['actionRequired'] == true,
          ),
        );
      });
    } catch (_) {
      setState(() {
        _messages.add(
          _ChatMessage(
            text: 'Sorry, I encountered an error. Please try again.',
            isUser: false,
          ),
        );
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: KSpacing.pagePadding,
            itemCount: _messages.length + (_isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _messages.length && _isLoading) {
                return const _TypingIndicator();
              }
              return _ChatBubble(message: _messages[index]);
            },
          ),
        ),
        if (_messages.length <= 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
            child: Row(
              children: [
                _SuggestionChip(
                  label: 'Revenue this month',
                  onTap: () {
                    _messageController.text =
                        "What's my total revenue this month?";
                    _sendMessage();
                  },
                ),
                _SuggestionChip(
                  label: 'Overdue invoices',
                  onTap: () {
                    _messageController.text = 'Show me overdue invoices';
                    _sendMessage();
                  },
                ),
                _SuggestionChip(
                  label: 'Profit this quarter',
                  onTap: () {
                    _messageController.text = "What's my profit this quarter?";
                    _sendMessage();
                  },
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(KSpacing.sm),
          decoration: BoxDecoration(
            color: KColors.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.camera_alt_outlined),
                  color: KColors.textSecondary,
                  onPressed: () {},
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ask about your finances...',
                      border: OutlineInputBorder(
                        borderRadius: KSpacing.borderRadiusXl,
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                KSpacing.hGapSm,
                Container(
                  decoration: const BoxDecoration(
                    color: KColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final Map<String, dynamic>? data;
  final bool actionRequired;

  _ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.data,
    this.actionRequired = false,
  }) : timestamp = timestamp ?? DateTime.now();
}

class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: KColors.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 16,
                color: KColors.accent,
              ),
            ),
            KSpacing.hGapSm,
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser ? KColors.primary : KColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  if (!isUser)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: KTypography.bodyMedium.copyWith(
                      color: isUser ? Colors.white : KColors.textPrimary,
                    ),
                  ),
                  if (message.data != null && message.data!.isNotEmpty) ...[
                    KSpacing.vGapSm,
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isUser
                            ? Colors.white.withValues(alpha: 0.12)
                            : KColors.primary.withValues(alpha: 0.05),
                        borderRadius: KSpacing.borderRadiusSm,
                      ),
                      child: Text(
                        const JsonEncoder.withIndent('  ')
                            .convert(message.data),
                        style: KTypography.bodySmall.copyWith(
                          color: isUser ? Colors.white : KColors.textSecondary,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                  if (message.actionRequired) ...[
                    KSpacing.vGapSm,
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 14, color: KColors.warning),
                        KSpacing.hGapXs,
                        Flexible(
                          child: Text(
                            'Draft created — approve it in the AI Inbox tab',
                            style: KTypography.bodySmall
                                .copyWith(color: KColors.warning),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) KSpacing.hGapSm,
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: KColors.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.auto_awesome, size: 16, color: KColors.accent),
          ),
          KSpacing.hGapSm,
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: KColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                _Dot(delay: 0),
                _Dot(delay: 1),
                _Dot(delay: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    Future.delayed(Duration(milliseconds: widget.delay * 200), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: KColors.textHint.withValues(alpha: _controller.value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: ActionChip(
        label: Text(label, style: KTypography.labelMedium),
        backgroundColor: KColors.primary.withValues(alpha: 0.06),
        side: const BorderSide(color: KColors.primary, width: 0.5),
        onPressed: onTap,
      ),
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

Color _statusColor(String status) {
  return switch (status.toUpperCase()) {
    'ACCEPTED' => KColors.success,
    'REJECTED' => KColors.error,
    'DEFERRED' => KColors.warning,
    'MODIFIED' => KColors.info,
    _ => KColors.primary,
  };
}

Color _priorityColor(String priority) {
  return switch (priority.toUpperCase()) {
    'HIGH' => KColors.error,
    'MEDIUM' => KColors.warning,
    _ => KColors.info,
  };
}
