import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../data/debit_note_repository.dart';

const _dnTabs = [
  KListTab(label: 'All'),
  KListTab(label: 'Draft', value: 'DRAFT'),
  KListTab(label: 'Submitted', value: 'SUBMITTED'),
  KListTab(label: 'Accepted', value: 'ACCEPTED'),
];

class DebitNotesScreen extends ConsumerStatefulWidget {
  const DebitNotesScreen({super.key});

  @override
  ConsumerState<DebitNotesScreen> createState() => _DebitNotesScreenState();
}

class _DebitNotesScreenState extends ConsumerState<DebitNotesScreen> {
  String? _status;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(debitNotesProvider);

    return Scaffold(
      body: Column(
        children: [
          KListPageHeader(
            title: 'Debit Notes',
            searchHint: 'Search DN number, supplier...',
            tabs: _dnTabs,
            selectedTab: _status,
            onTabChanged: (value) => setState(() => _status = value),
            onSearchChanged: (value) =>
                setState(() => _search = value.trim().toLowerCase()),
          ),
          Expanded(
            child: notesAsync.when(
              loading: () => const KShimmerList(),
              error: (err, _) => KErrorView(
                message: 'Failed to load debit notes',
                onRetry: () => ref.invalidate(debitNotesProvider),
              ),
              data: (notes) {
                if (notes.isEmpty) {
                  return KEmptyState(
                    icon: Icons.assignment_return_outlined,
                    title: 'No debit notes yet',
                    subtitle:
                        'Create a debit note to record a purchase return to a supplier.',
                    actionLabel: 'New Debit Note',
                    onAction: () => context.go(Routes.debitNoteCreate),
                  );
                }

                final filtered = notes.where((n) {
                  final status = n['status']?.toString();
                  if (_status != null && status != _status) return false;
                  if (_search.isEmpty) return true;
                  final haystack = [
                    n['debitNoteNumber'],
                    n['supplierName'],
                    n['status'],
                    n['returnReason'],
                  ].whereType<Object>().join(' ').toLowerCase();
                  return haystack.contains(_search);
                }).toList();

                if (filtered.isEmpty) {
                  return KEmptyState(
                    icon: Icons.assignment_return_outlined,
                    title: 'No matching debit notes',
                    subtitle: 'Try another status or search term.',
                    actionLabel: 'Clear Filters',
                    onAction: () => setState(() {
                      _status = null;
                      _search = '';
                    }),
                  );
                }

                return KResponsiveEntityList<Map<String, dynamic>>(
                  items: filtered,
                  onRefresh: () async => ref.invalidate(debitNotesProvider),
                  mobileItemBuilder: (context, note) =>
                      _DebitNoteCard(note: note),
                  tableBuilder: (context) =>
                      _DebitNoteTable(notes: filtered),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: KColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => context.go(Routes.debitNoteCreate),
        icon: const Icon(Icons.add),
        label: const Text('New Debit Note'),
        tooltip: 'New Debit Note (N)',
      ),
    );
  }
}

class _DebitNoteTable extends StatelessWidget {
  final List<Map<String, dynamic>> notes;
  const _DebitNoteTable({required this.notes});

  @override
  Widget build(BuildContext context) {
    return KEntityDataTable(
      columnSpacing: 20,
      horizontalMargin: 14,
      columns: const [
        DataColumn(label: Text('DN Number')),
        DataColumn(label: Text('Supplier')),
        DataColumn(label: Text('Date')),
        DataColumn(label: Text('Reason')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Total'), numeric: true),
        DataColumn(label: SizedBox(width: 32, child: Text(''))),
      ],
      rows: notes.map((note) {
        final id = note['id']?.toString() ?? '';
        final dnNumber = note['debitNoteNumber']?.toString() ?? '--';
        final supplierName =
            note['supplierName']?.toString() ?? 'Unknown supplier';
        final status = note['status']?.toString() ?? 'DRAFT';
        final total = (note['totalAmount'] as num?)?.toDouble() ?? 0;
        final noteDateRaw = note['noteDate']?.toString();
        final reason = _formatReason(note['returnReason']?.toString());

        return DataRow(
          color: kEntityRowColor(context),
          onSelectChanged: (_) {
            if (id.isNotEmpty) context.go('/debit-notes/$id');
          },
          cells: [
            DataCell(KTablePrimaryTextCell(value: dnNumber, width: 130)),
            DataCell(KTableTextCell(value: supplierName, width: 200)),
            DataCell(KTableDateCell(value: noteDateRaw)),
            DataCell(KTableTextCell(value: reason, width: 160)),
            DataCell(KTableStatusCell(status: status)),
            DataCell(KTableAmountCell(value: total)),
            DataCell(KTableOpenActionCell(
              tooltip: 'Open debit note',
              onPressed:
                  id.isEmpty ? null : () => context.go('/debit-notes/$id'),
            )),
          ],
        );
      }).toList(),
    );
  }
}

class _DebitNoteCard extends StatelessWidget {
  final Map<String, dynamic> note;
  const _DebitNoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    final dnNumber = note['debitNoteNumber'] as String? ?? '--';
    final supplierName = note['supplierName'] as String? ?? 'Unknown supplier';
    final status = note['status'] as String? ?? 'DRAFT';
    final total = (note['totalAmount'] as num?)?.toDouble() ?? 0;
    final noteDateRaw = note['noteDate'] as String?;
    final reason = _formatReason(note['returnReason']?.toString());

    return KCard(
      onTap: () {
        final id = note['id']?.toString();
        if (id != null) context.go('/debit-notes/$id');
      },
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      dnNumber,
                      style: KTypography.mono(fontSize: 13, weight: FontWeight.w600),
                    ),
                    KSpacing.hGapSm,
                    KStatusChip(status: status),
                  ],
                ),
                KSpacing.vGapXs,
                Text(
                  supplierName,
                  style: KTypography.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                KSpacing.vGapXs,
                Row(
                  children: [
                    if (noteDateRaw != null) ...[
                      Text(
                        DateFormatter.display(DateTime.parse(noteDateRaw)),
                        style: KTypography.bodySmall,
                      ),
                      const Text(' · ',
                          style: TextStyle(color: KColors.textHint)),
                    ],
                    Flexible(
                      child: Text(
                        reason,
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          KMoney(
            total,
            size: KMoneySize.medium,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          KSpacing.hGapSm,
          const Icon(Icons.chevron_right, color: KColors.textHint),
        ],
      ),
    );
  }
}

String _formatReason(String? reason) {
  return switch (reason) {
    'EXPIRED' => 'Expired Medicines',
    'DAMAGED' => 'Damaged',
    'WRONG_ITEM' => 'Wrong Item Received',
    'QUALITY_ISSUE' => 'Quality Issue',
    'EXCESS_STOCK' => 'Excess Stock',
    _ => reason ?? '--',
  };
}
