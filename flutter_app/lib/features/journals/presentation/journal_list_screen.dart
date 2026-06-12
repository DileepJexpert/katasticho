import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/widgets/k_keyboard_list_wrapper.dart';
import '../data/journal_repository.dart';

const _sourceTabs = [
  KListTab(label: 'All'),
  KListTab(label: 'Manual', value: 'MANUAL'),
  KListTab(label: 'Invoice', value: 'SALES'),
  KListTab(label: 'Bill', value: 'PURCHASE'),
  KListTab(label: 'POS', value: 'POS'),
  KListTab(label: 'Payment', value: 'PAYMENT'),
];

class JournalListScreen extends ConsumerStatefulWidget {
  const JournalListScreen({super.key});

  @override
  ConsumerState<JournalListScreen> createState() => _JournalListScreenState();
}

class _JournalListScreenState extends ConsumerState<JournalListScreen> {
  List<Map<String, dynamic>> _currentJournals = const [];

  void _openAtIndex(int index) {
    if (index < 0 || index >= _currentJournals.length) return;
    final id = _currentJournals[index]['id']?.toString();
    if (id != null) context.push('/accounting/journal-entries/$id');
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(journalFilterProvider);
    final journalsAsync = ref.watch(journalListProvider);

    return KKeyboardListWrapper(
      itemCount: () => _currentJournals.length,
      onNew: () => context.push('/accounting/journal-entries/create'),
      onRefresh: () => ref.invalidate(journalListProvider),
      onOpen: _openAtIndex,
      child: Scaffold(
      body: Column(
        children: [
          KListPageHeader(
            title: 'Journal Entries',
            searchHint: 'Search journals…',
            tabs: _sourceTabs,
            selectedTab: filter.sourceModule,
            onTabChanged: (v) => ref
                .read(journalFilterProvider.notifier)
                .state = filter.copyWith(sourceModule: v, page: 0),
            onSearchChanged: (q) => ref
                .read(journalFilterProvider.notifier)
                .state =
                filter.copyWith(search: q.isEmpty ? null : q, page: 0),
          ),
          Expanded(
            child: journalsAsync.when(
              loading: () => const KShimmerList(),
              error: (err, _) => KErrorView(
                message: 'Failed to load journal entries',
                onRetry: () => ref.invalidate(journalListProvider),
              ),
              data: (data) {
                final content = data['data'];
                if (content == null) {
                  return KEmptyState(
                    icon: Icons.menu_book_outlined,
                    title: 'No journal entries yet',
                    subtitle:
                        'Journal entries are created automatically or manually',
                    actionLabel: 'Create Manual Journal',
                    onAction: () =>
                        context.push('/accounting/journal-entries/create'),
                  );
                }

                final journals = (content is List)
                    ? content
                    : (content['content'] as List?) ?? [];

                if (journals.isEmpty) {
                  return KEmptyState(
                    icon: Icons.menu_book_outlined,
                    title: 'No journal entries found',
                    subtitle: filter.sourceModule != null
                        ? 'No ${filter.sourceModule!.toLowerCase()} journals'
                        : 'Create a manual journal entry',
                    actionLabel: 'Create Manual Journal',
                    onAction: () =>
                        context.push('/accounting/journal-entries/create'),
                  );
                }

                final journalMaps = journals
                    .whereType<Map>()
                    .map((journal) => journal.cast<String, dynamic>())
                    .toList();
                _currentJournals = journalMaps;

                return KResponsiveEntityList<Map<String, dynamic>>(
                  items: journalMaps,
                  onRefresh: () async => ref.invalidate(journalListProvider),
                  mobileItemBuilder: (context, journal) =>
                      _JournalCard(journal: journal),
                  tableBuilder: (context) =>
                      _JournalTable(journals: journalMaps),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/accounting/journal-entries/create'),
        icon: const Icon(Icons.add),
        label: const Text('Manual Journal'),
        tooltip: 'Manual Journal (N)',
      ),
    ));
  }
}

class _JournalTable extends StatelessWidget {
  final List<Map<String, dynamic>> journals;

  const _JournalTable({required this.journals});

  @override
  Widget build(BuildContext context) {
    return KEntityDataTable(
      columnSpacing: 20,
      horizontalMargin: 14,
      columns: const [
        DataColumn(label: Text('Entry')),
        DataColumn(label: Text('Date')),
        DataColumn(label: Text('Description')),
        DataColumn(label: Text('Source')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Debit'), numeric: true),
        DataColumn(label: Text('Credit'), numeric: true),
        DataColumn(label: SizedBox(width: 32, child: Text(''))),
      ],
      rows: journals.map((journal) {
        final id = journal['id']?.toString() ?? '';
        final entryNumber = journal['entryNumber']?.toString() ?? '--';
        final description = journal['description']?.toString() ?? '--';
        final effectiveDate = journal['effectiveDate']?.toString();
        final sourceModule = journal['sourceModule']?.toString() ?? '';
        final status = journal['status']?.toString() ?? 'POSTED';
        final totalDebit = (journal['totalDebit'] as num?)?.toDouble() ?? 0;
        final totalCredit = (journal['totalCredit'] as num?)?.toDouble() ??
            totalDebit;

        return DataRow(
          color: kEntityRowColor(context),
          onSelectChanged: (_) {
            if (id.isNotEmpty) {
              context.push('/accounting/journal-entries/$id');
            }
          },
          cells: [
            DataCell(KTablePrimaryTextCell(value: entryNumber, width: 160)),
            DataCell(KTableDateCell(value: effectiveDate)),
            DataCell(KTableTextCell(value: description, width: 280)),
            DataCell(_SourceChip(sourceModule: sourceModule)),
            DataCell(status == 'POSTED'
                ? const Text('--')
                : KTableStatusCell(status: status)),
            DataCell(KTableAmountCell(value: totalDebit)),
            DataCell(KTableAmountCell(value: totalCredit)),
            DataCell(KTableOpenActionCell(
              tooltip: 'Open journal entry',
              onPressed: id.isEmpty
                  ? null
                  : () => context.push('/accounting/journal-entries/$id'),
            )),
          ],
        );
      }).toList(),
    );
  }
}

class _JournalCard extends StatelessWidget {
  final Map<String, dynamic> journal;

  const _JournalCard({required this.journal});

  @override
  Widget build(BuildContext context) {
    final id = journal['id']?.toString() ?? '';
    final entryNumber = journal['entryNumber']?.toString() ?? '';
    final description = journal['description']?.toString() ?? '';
    final effectiveDate = journal['effectiveDate']?.toString() ?? '';
    final sourceModule = journal['sourceModule']?.toString() ?? '';
    final status = journal['status']?.toString() ?? '';
    final totalDebit =
        (journal['totalDebit'] as num?)?.toDouble() ?? 0.0;

    final cs = Theme.of(context).colorScheme;

    return KCard(
      onTap: () => context.push('/accounting/journal-entries/$id'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entryNumber,
                  style: KTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  KSpacing.vGapXs,
                  Text(
                    description,
                    style: KTypography.bodySmall.copyWith(
                      color: KColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          KSpacing.hGapMd,
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.formatIndian(totalDebit),
                style: KTypography.amountSmall.copyWith(
                  color: cs.onSurface,
                ),
              ),
              KSpacing.vGapXs,
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (effectiveDate.isNotEmpty)
                    Text(
                      _formatDate(effectiveDate),
                      style: KTypography.bodySmall.copyWith(
                        color: KColors.textHint,
                      ),
                    ),
                  KSpacing.hGapSm,
                  _SourceChip(sourceModule: sourceModule),
                ],
              ),
              if (status.isNotEmpty && status != 'POSTED') ...[
                KSpacing.vGapXs,
                KStatusChip(status: status, dense: true),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${dt.day} ${months[dt.month]} ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }
}

class _SourceChip extends StatelessWidget {
  final String sourceModule;

  const _SourceChip({required this.sourceModule});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (sourceModule.toUpperCase()) {
      'MANUAL' => ('Manual', KColors.info),
      'SALES' => ('Invoice', KColors.success),
      'PURCHASE' => ('Bill', KColors.warning),
      'POS' => ('POS', const Color(0xFF7C3AED)),
      'PAYMENT' => ('Payment', const Color(0xFF0D9488)),
      'EXPENSE' => ('Expense', const Color(0xFFEA580C)),
      _ => (sourceModule, KColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(KSpacing.radiusRound),
      ),
      child: Text(
        label,
        style: KTypography.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}
