import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../data/vendor_credit_dto.dart';
import '../data/vendor_credit_providers.dart';
import 'widgets/vendor_credit_card.dart';

const _statusTabs = [
  KListTab(label: 'All'),
  KListTab(label: 'Draft', value: 'DRAFT'),
  KListTab(label: 'Open', value: 'OPEN'),
  KListTab(label: 'Applied', value: 'APPLIED'),
  KListTab(label: 'Void', value: 'VOID'),
];

class VendorCreditListScreen extends ConsumerStatefulWidget {
  const VendorCreditListScreen({super.key});

  @override
  ConsumerState<VendorCreditListScreen> createState() =>
      _VendorCreditListScreenState();
}

class _VendorCreditListScreenState
    extends ConsumerState<VendorCreditListScreen> {
  List<Map<String, dynamic>> _currentCredits = const [];

  void _openAtIndex(int index) {
    if (index < 0 || index >= _currentCredits.length) return;
    final id = _currentCredits[index]['id']?.toString();
    if (id != null) context.go('/vendor-credits/$id');
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(vendorCreditFilterProvider);
    final creditsAsync = ref.watch(vendorCreditListProvider);

    return KKeyboardListWrapper(
      itemCount: () => _currentCredits.length,
      onNew: () => context.go(Routes.vendorCreditCreate),
      onRefresh: () => ref.invalidate(vendorCreditListProvider),
      onOpen: _openAtIndex,
      child: Scaffold(
      body: Column(
        children: [
          KListPageHeader(
            title: 'Vendor Credits',
            searchHint: 'Search vendor credits...',
            tabs: _statusTabs,
            selectedTab: filter.status,
            onTabChanged: (v) => ref
                .read(vendorCreditFilterProvider.notifier)
                .state = VendorCreditListFilter(
              status: v,
              contactId: filter.contactId,
              page: 0,
            ),
          ),
          Expanded(
            child: creditsAsync.when(
              loading: () => const KShimmerList(),
              error: (err, _) => KErrorView(
                message: 'Failed to load vendor credits',
                onRetry: () => ref.invalidate(vendorCreditListProvider),
              ),
              data: (data) {
                final content = data['data'];
                if (content == null) {
                  return KEmptyState(
                    icon: Icons.note_alt_outlined,
                    title: 'No vendor credits yet',
                    subtitle: 'Create your first vendor credit to get started',
                    actionLabel: 'Create Credit',
                    onAction: () => context.go(Routes.vendorCreditCreate),
                  );
                }

                final credits = (content is List)
                    ? content
                    : (content['content'] as List?) ?? [];

                if (credits.isEmpty) {
                  return KEmptyState(
                    icon: Icons.note_alt_outlined,
                    title: 'No vendor credits found',
                    subtitle: filter.status != null
                        ? 'No ${filter.status} credits'
                        : 'Create your first vendor credit',
                    actionLabel: 'Create Credit',
                    onAction: () => context.go(Routes.vendorCreditCreate),
                  );
                }

                final creditMaps = credits.cast<Map<String, dynamic>>();
                _currentCredits = creditMaps;

                return KResponsiveEntityList<Map<String, dynamic>>(
                  items: creditMaps,
                  breakpoint: 720,
                  onRefresh: () async =>
                      ref.invalidate(vendorCreditListProvider),
                  tableBuilder: (_) => _VendorCreditTable(credits: creditMaps),
                  mobileItemBuilder: (_, credit) =>
                      VendorCreditCard(credit: credit),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(Routes.vendorCreditCreate),
        icon: const Icon(Icons.add),
        label: const Text('New Credit'),
        tooltip: 'New Credit (N)',
      ),
    ));
  }
}

class _VendorCreditTable extends StatelessWidget {
  final List<Map<String, dynamic>> credits;

  const _VendorCreditTable({required this.credits});

  @override
  Widget build(BuildContext context) {
    return KEntityDataTable(
      columnSpacing: 16,
      horizontalMargin: 12,
      columns: const [
        DataColumn(label: Text('Credit')),
        DataColumn(label: Text('Vendor')),
        DataColumn(label: Text('Date')),
        DataColumn(label: Text('Reason')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Total'), numeric: true),
        DataColumn(label: Text('Balance'), numeric: true),
        DataColumn(label: SizedBox(width: 32)),
      ],
      rows: credits.map((raw) {
        final c = VendorCreditDto(raw);

        return DataRow(
          color: kEntityRowColor(context),
          onSelectChanged: c.id.isEmpty
              ? null
              : (_) => context.go('/vendor-credits/${c.id}'),
          cells: [
            DataCell(KTableTextCell(value: c.creditNumber, width: 130, style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w500))),
            DataCell(KTableTextCell(value: c.vendorName, width: 150)),
            DataCell(KTableDateCell(value: c.creditDate)),
            DataCell(KTableTextCell(
              value: c.reason.isEmpty ? '--' : c.reason,
              width: 180,
              style: KTypography.bodySmall.copyWith(
                color: c.reason.isEmpty
                    ? KColors.textHint
                    : Theme.of(context).colorScheme.onSurface,
              ),
            )),
            DataCell(KTableStatusCell(status: c.status)),
            DataCell(KTableAmountCell(value: c.totalAmount)),
            DataCell(
              KTableAmountCell(
                value: c.balance,
                color: c.balance > 0 ? KColors.warning : KColors.success,
              ),
            ),
            DataCell(KTableOpenActionCell(
              tooltip: 'Open credit',
              onPressed: c.id.isEmpty
                  ? null
                  : () => context.go('/vendor-credits/${c.id}'),
            )),
          ],
        );
      }).toList(),
    );
  }
}
