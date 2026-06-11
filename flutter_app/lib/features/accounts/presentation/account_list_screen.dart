import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_keyboard_list_wrapper.dart';
import '../../../core/widgets/widgets.dart';
import '../data/account_repository.dart';

const _accountTabs = [
  KListTab(label: 'All'),
  KListTab(label: 'Assets', value: 'ASSET'),
  KListTab(label: 'Liabilities', value: 'LIABILITY'),
  KListTab(label: 'Equity', value: 'EQUITY'),
  KListTab(label: 'Income', value: 'REVENUE'),
  KListTab(label: 'Expense', value: 'EXPENSE'),
];

class AccountListScreen extends ConsumerStatefulWidget {
  const AccountListScreen({super.key});

  @override
  ConsumerState<AccountListScreen> createState() => _AccountListScreenState();
}

class _AccountListScreenState extends ConsumerState<AccountListScreen> {
  String? _selectedType;
  String _searchQuery = '';
  final Set<String> _collapsed = <String>{};

  bool _matchesType(AccountDto a) {
    if (_selectedType == null) return true;
    final t = a.type.toUpperCase();
    if (_selectedType == 'REVENUE') return t == 'REVENUE' || t == 'INCOME';
    return t == _selectedType;
  }

  bool _matchesSearch(AccountDto a) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();
    return a.name.toLowerCase().contains(q) ||
        a.code.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    return KKeyboardListWrapper(
      itemCount: () {
        final async = ref.read(accountsProvider);
        return async.valueOrNull?.where((a) => !a.isDeleted).length ?? 0;
      },
      onNew: () => context.push('/accounts/create'),
      onRefresh: () => ref.invalidate(accountsProvider),
      onOpen: (index) {
        final async = ref.read(accountsProvider);
        final all = async.valueOrNull?.where((a) => !a.isDeleted).toList();
        if (all != null && index < all.length) {
          context.push('/accounts/${all[index].id}');
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            KListPageHeader(
              title: 'Chart of Accounts',
              searchHint: 'Search by name or code…',
              tabs: _accountTabs,
              selectedTab: _selectedType,
              onTabChanged: (v) => setState(() => _selectedType = v),
              onSearchChanged: (q) => setState(() => _searchQuery = q),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/accounts/create'),
          icon: const Icon(Icons.add),
          label: const Text('Add Account'),
          tooltip: 'Add Account (N)',
        ),
      ),
    );
  }

  Widget _buildBody() {
    final async = ref.watch(accountsProvider);
    return async.when(
      loading: () => const KShimmerList(),
      error: (e, _) => KErrorView(
        message: 'Failed to load accounts',
        onRetry: () => ref.invalidate(accountsProvider),
      ),
      data: (all) {
        final filtered = all.where((a) => !a.isDeleted).toList();
        final rows = _searchQuery.isNotEmpty
            ? _flatSearch(filtered)
            : _tree(filtered);
        if (rows.isEmpty) {
          return KEmptyState(
            icon: Icons.account_balance_outlined,
            title: _searchQuery.isNotEmpty
                ? 'No accounts match "$_searchQuery"'
                : 'No accounts yet',
            subtitle: _searchQuery.isEmpty
                ? 'Add accounts or seed from a template'
                : null,
            actionLabel: _searchQuery.isEmpty ? 'Add Account' : null,
            onAction:
                _searchQuery.isEmpty ? () => context.push('/accounts/create') : null,
          );
        }
        return KResponsiveEntityList<_Row>(
          items: rows,
          onRefresh: () async => ref.invalidate(accountsProvider),
          mobileItemBuilder: (context, row) => _AccountCard(
            account: row.account,
            depth: row.depth,
            isCollapsed: _collapsed.contains(row.account.id),
            onToggle: row.account.hasChildren
                ? () => setState(() {
                      if (!_collapsed.remove(row.account.id)) {
                        _collapsed.add(row.account.id);
                      }
                    })
                : null,
          ),
          tableBuilder: (context) => _AccountTable(
            rows: rows,
            collapsed: _collapsed,
            onToggle: (id) => setState(() {
              if (!_collapsed.remove(id)) {
                _collapsed.add(id);
              }
            }),
          ),
        );
      },
    );
  }

  /// Build a tree: keep a node if it matches the type filter OR has a
  /// descendant that does. Renders root → children depth-first.
  List<_Row> _tree(List<AccountDto> accounts) {
    final byParent = <String?, List<AccountDto>>{};
    for (final a in accounts) {
      byParent.putIfAbsent(a.parentId, () => []).add(a);
    }
    for (final list in byParent.values) {
      list.sort((a, b) => a.code.compareTo(b.code));
    }

    // Determine which nodes (or ancestors) match the type filter.
    final include = <String>{};
    bool visit(AccountDto a) {
      bool any = _matchesType(a);
      for (final c in byParent[a.id] ?? const <AccountDto>[]) {
        if (visit(c)) any = true;
      }
      if (any) include.add(a.id);
      return any;
    }

    for (final root in byParent[null] ?? const <AccountDto>[]) {
      visit(root);
    }

    final out = <_Row>[];
    void walk(AccountDto a, int depth) {
      if (!include.contains(a.id)) return;
      out.add(_Row(a, depth));
      if (_collapsed.contains(a.id)) return;
      for (final c in byParent[a.id] ?? const <AccountDto>[]) {
        walk(c, depth + 1);
      }
    }

    for (final root in byParent[null] ?? const <AccountDto>[]) {
      walk(root, 0);
    }
    return out;
  }

  /// While searching, flatten and show only rows that match search + type.
  List<_Row> _flatSearch(List<AccountDto> accounts) {
    return accounts
        .where((a) => _matchesType(a) && _matchesSearch(a))
        .map((a) => _Row(a, 0))
        .toList()
      ..sort((a, b) => a.account.code.compareTo(b.account.code));
  }
}

class _Row {
  final AccountDto account;
  final int depth;
  const _Row(this.account, this.depth);
}

class _AccountTable extends StatelessWidget {
  final List<_Row> rows;
  final Set<String> collapsed;
  final ValueChanged<String> onToggle;

  const _AccountTable({
    required this.rows,
    required this.collapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return KEntityDataTable(
      columnSpacing: 20,
      horizontalMargin: 14,
      columns: const [
        DataColumn(label: Text('Account')),
        DataColumn(label: Text('Code')),
        DataColumn(label: Text('Type')),
        DataColumn(label: Text('Subtype')),
        DataColumn(label: Text('Children')),
        DataColumn(label: Text('Flags')),
        DataColumn(label: SizedBox(width: 32, child: Text(''))),
      ],
      rows: rows.map((row) {
        final account = row.account;
        final type = account.type.toUpperCase();
        final typeColor = _accountTypeColor(type);
        final isCollapsed = collapsed.contains(account.id);

        return DataRow(
          color: kEntityRowColor(context),
          onSelectChanged: (_) => context.push('/accounts/${account.id}'),
          cells: [
            DataCell(SizedBox(
              width: 280,
              child: Row(
                children: [
                  SizedBox(width: row.depth * 18.0),
                  SizedBox(
                    width: 28,
                    child: account.hasChildren
                        ? IconButton(
                            tooltip: isCollapsed ? 'Expand' : 'Collapse',
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              isCollapsed
                                  ? Icons.chevron_right
                                  : Icons.keyboard_arrow_down,
                              size: 20,
                            ),
                            onPressed: () => onToggle(account.id),
                          )
                        : const SizedBox.shrink(),
                  ),
                  KSpacing.hGapXs,
                  Expanded(
                    child: Text(
                      account.name,
                      style: KTypography.labelLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )),
            DataCell(Text(account.code)),
            DataCell(_AccountTypePill(
              label: _accountTypeLabel(type),
              color: typeColor,
            )),
            DataCell(KTableTextCell(
              value: account.subType?.replaceAll('_', ' ').toLowerCase() ?? '--',
              width: 180,
            )),
            DataCell(Text(account.hasChildren ? '${account.childCount}' : '--')),
            DataCell(_AccountFlags(account: account)),
            DataCell(KTableOpenActionCell(
              tooltip: 'Open account',
              onPressed: () => context.push('/accounts/${account.id}'),
            )),
          ],
        );
      }).toList(),
    );
  }
}

class _AccountTypePill extends StatelessWidget {
  final String label;
  final Color color;

  const _AccountTypePill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: KTypography.labelSmall.copyWith(color: color),
      ),
    );
  }
}

class _AccountFlags extends StatelessWidget {
  final AccountDto account;

  const _AccountFlags({required this.account});

  @override
  Widget build(BuildContext context) {
    final flags = <Widget>[];
    if (account.isSystem) {
      flags.add(const Tooltip(
        message: 'System account',
        child: Icon(Icons.lock_outline, size: 15, color: KColors.textHint),
      ));
    }
    if (account.isInvolvedInTransaction) {
      flags.add(const Tooltip(
        message: 'Has posted transactions',
        child:
            Icon(Icons.receipt_long_outlined, size: 15, color: KColors.textHint),
      ));
    }
    if (!account.isActive) {
      flags.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: KColors.draftBg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'Inactive',
          style: KTypography.labelSmall.copyWith(color: KColors.draft),
        ),
      ));
    }
    if (flags.isEmpty) return const Text('--');
    return Row(mainAxisSize: MainAxisSize.min, children: flags);
  }
}

class _AccountCard extends StatelessWidget {
  final AccountDto account;
  final int depth;
  final bool isCollapsed;
  final VoidCallback? onToggle;

  const _AccountCard({
    required this.account,
    required this.depth,
    required this.isCollapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final type = account.type.toUpperCase();
    final typeColor = _accountTypeColor(type);

    return KCard(
      onTap: () => context.push('/accounts/${account.id}'),
      child: Row(
        children: [
          SizedBox(width: depth * 20.0),
          SizedBox(
            width: 28,
            child: account.hasChildren
                ? InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: onToggle,
                    child: Icon(
                      isCollapsed
                          ? Icons.chevron_right
                          : Icons.keyboard_arrow_down,
                      size: 20,
                      color: KColors.textSecondary,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                account.code.isNotEmpty
                    ? account.code.substring(0, account.code.length.clamp(0, 2))
                    : '?',
                style: KTypography.labelSmall
                    .copyWith(color: typeColor, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.name, style: KTypography.labelLarge),
                KSpacing.vGapXs,
                Row(
                  children: [
                    Text(account.code, style: KTypography.bodySmall),
                    if (account.subType != null && account.subType!.isNotEmpty) ...[
                      Text(' · ', style: KTypography.bodySmall),
                      Text(
                        account.subType!.replaceAll('_', ' ').toLowerCase(),
                        style: KTypography.bodySmall,
                      ),
                    ],
                    if (account.hasChildren) ...[
                      Text(' · ', style: KTypography.bodySmall),
                      Text('${account.childCount} sub',
                          style: KTypography.bodySmall
                              .copyWith(color: KColors.textHint)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _accountTypeLabel(type),
                  style: KTypography.labelSmall.copyWith(color: typeColor),
                ),
              ),
              KSpacing.vGapXs,
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (account.isSystem)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Tooltip(
                        message: 'System account',
                        child: Icon(Icons.lock_outline,
                            size: 12, color: KColors.textHint),
                      ),
                    ),
                  if (account.isInvolvedInTransaction)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Tooltip(
                        message: 'Has posted transactions',
                        child: Icon(Icons.receipt_long_outlined,
                            size: 12, color: KColors.textHint),
                      ),
                    ),
                  if (!account.isActive)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: KColors.draftBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Inactive',
                        style: KTypography.labelSmall
                            .copyWith(color: KColors.draft),
                      ),
                    ),
                ],
              ),
            ],
          ),
          KSpacing.hGapSm,
          const Icon(Icons.chevron_right, color: KColors.textHint),
        ],
      ),
    );
  }

}

Color _accountTypeColor(String type) => switch (type) {
      'ASSET' => KColors.info,
      'LIABILITY' => KColors.warning,
      'EQUITY' => KColors.success,
      'REVENUE' || 'INCOME' => KColors.primary,
      'EXPENSE' => KColors.error,
      _ => KColors.textSecondary,
    };

String _accountTypeLabel(String type) => switch (type) {
      'ASSET' => 'Asset',
      'LIABILITY' => 'Liability',
      'EQUITY' => 'Equity',
      'REVENUE' || 'INCOME' => 'Income',
      'EXPENSE' => 'Expense',
      _ => type,
    };
