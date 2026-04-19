import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          Expanded(
            child: _AccountTabBody(
              type: _selectedType,
              search: _searchQuery,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/accounts/create'),
        icon: const Icon(Icons.add),
        label: const Text('Add Account'),
      ),
    );
  }
}

class _AccountTabBody extends ConsumerWidget {
  final String? type;
  final String search;

  const _AccountTabBody({required this.type, required this.search});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAccounts = ref.watch(accountListProvider(type));

    return asyncAccounts.when(
      loading: () => const KShimmerList(),
      error: (err, _) => KErrorView(
        message: 'Failed to load accounts',
        onRetry: () => ref.invalidate(accountListProvider(type)),
      ),
      data: (data) {
        final content = data['data'];
        List<dynamic> accounts = content is List
            ? content
            : (content is Map ? (content['content'] as List?) ?? [] : []);

        // Client-side filter: deleted rows
        accounts = accounts.where((a) {
          final m = a as Map<String, dynamic>;
          return m['isDeleted'] != true;
        }).toList();

        // Type filter
        if (type != null) {
          accounts = accounts.where((a) {
            final m = a as Map<String, dynamic>;
            final t = (m['type'] as String? ?? '').toUpperCase();
            // Map REVENUE → Income tab
            if (type == 'REVENUE') return t == 'REVENUE' || t == 'INCOME';
            return t == type;
          }).toList();
        }

        // Search
        if (search.isNotEmpty) {
          final q = search.toLowerCase();
          accounts = accounts.where((a) {
            final m = a as Map<String, dynamic>;
            return (m['name'] as String? ?? '').toLowerCase().contains(q) ||
                (m['code'] as String? ?? '').toLowerCase().contains(q);
          }).toList();
        }

        if (accounts.isEmpty) {
          return KEmptyState(
            icon: Icons.account_balance_outlined,
            title: search.isNotEmpty
                ? 'No accounts match "$search"'
                : 'No accounts yet',
            subtitle: search.isEmpty
                ? 'Add accounts or seed from a template'
                : null,
            actionLabel: search.isEmpty ? 'Add Account' : null,
            onAction: search.isEmpty ? () => context.push('/accounts/create') : null,
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(accountListProvider(type)),
          child: ListView.separated(
            padding: KSpacing.pagePadding,
            itemCount: accounts.length,
            separatorBuilder: (_, __) => KSpacing.vGapSm,
            itemBuilder: (context, index) {
              final account = accounts[index] as Map<String, dynamic>;
              return _AccountCard(account: account);
            },
          ),
        );
      },
    );
  }
}

class _AccountCard extends StatelessWidget {
  final Map<String, dynamic> account;

  const _AccountCard({required this.account});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final code = account['code'] as String? ?? '';
    final name = account['name'] as String? ?? 'Unknown';
    final type = (account['type'] as String? ?? '').toUpperCase();
    final subType = account['subType'] as String?;
    final isActive = account['isActive'] as bool? ?? true;
    final isSystem = account['isSystem'] as bool? ?? false;
    final level = (account['level'] as num?)?.toInt() ?? 1;
    final id = account['id']?.toString() ?? '';

    final typeColor = _typeColor(type);

    return KCard(
      onTap: () {
        if (id.isNotEmpty) context.push('/accounts/$id');
      },
      child: Row(
        children: [
          // Indent for hierarchy
          if (level > 1) SizedBox(width: (level - 1) * 16.0),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                code.isNotEmpty ? code.substring(0, code.length.clamp(0, 2)) : '?',
                style: KTypography.labelSmall.copyWith(color: typeColor, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: KTypography.labelLarge),
                KSpacing.vGapXs,
                Row(
                  children: [
                    Text(code, style: KTypography.bodySmall),
                    if (subType != null && subType.isNotEmpty) ...[
                      Text(' · ', style: KTypography.bodySmall),
                      Text(
                        subType.replaceAll('_', ' ').toLowerCase(),
                        style: KTypography.bodySmall,
                      ),
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
                  _typeLabel(type),
                  style: KTypography.labelSmall.copyWith(color: typeColor),
                ),
              ),
              KSpacing.vGapXs,
              Row(
                children: [
                  if (isSystem)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Tooltip(
                        message: 'System account',
                        child: Icon(Icons.lock_outline, size: 12, color: KColors.textHint),
                      ),
                    ),
                  if (!isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: KColors.draftBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Inactive',
                        style: KTypography.labelSmall.copyWith(color: KColors.draft),
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

  Color _typeColor(String type) => switch (type) {
        'ASSET' => KColors.info,
        'LIABILITY' => KColors.warning,
        'EQUITY' => KColors.success,
        'REVENUE' || 'INCOME' => KColors.primary,
        'EXPENSE' => KColors.error,
        _ => KColors.textSecondary,
      };

  String _typeLabel(String type) => switch (type) {
        'ASSET' => 'Asset',
        'LIABILITY' => 'Liability',
        'EQUITY' => 'Equity',
        'REVENUE' || 'INCOME' => 'Income',
        'EXPENSE' => 'Expense',
        _ => type,
      };
}
