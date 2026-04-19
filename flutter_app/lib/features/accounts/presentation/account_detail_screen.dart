import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/account_repository.dart';

class AccountDetailScreen extends ConsumerWidget {
  final String accountId;

  const AccountDetailScreen({super.key, required this.accountId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Map<String, dynamic>>(
      future: ref.read(accountRepositoryProvider).getAccount(accountId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: KLoading());
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Account')),
            body: KErrorView(message: 'Failed to load account'),
          );
        }

        final raw = snapshot.data!;
        final account = (raw['data'] ?? raw) as Map<String, dynamic>;
        final name = account['name'] as String? ?? 'Account';
        final type = (account['type'] as String? ?? '').toUpperCase();
        final isActive = account['isActive'] as bool? ?? true;
        final isSystem = account['isSystem'] as bool? ?? false;

        final typeColor = _typeColor(type);

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(name),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () =>
                      context.push('/accounts/$accountId/edit'),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'toggle_active') {
                      await _toggleActive(context, ref, account, isActive);
                    } else if (v == 'delete') {
                      await _deleteAccount(context, ref, name, isSystem);
                    }
                  },
                  itemBuilder: (_) => [
                    DropdownMenuItem(
                      value: 'toggle_active',
                      child: Text(isActive ? 'Mark Inactive' : 'Mark Active'),
                    ),
                    if (!isSystem)
                      const DropdownMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete',
                          style: TextStyle(color: KColors.error),
                        ),
                      ),
                  ].map((item) => PopupMenuItem<String>(
                        value: item.value,
                        child: item.child,
                      )).toList(),
                ),
              ],
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Details'),
                  Tab(text: 'Balance'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _DetailsTab(account: account, typeColor: typeColor),
                _BalanceTab(accountId: accountId),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleActive(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> account,
    bool currentlyActive,
  ) async {
    final repo = ref.read(accountRepositoryProvider);
    try {
      if (currentlyActive) {
        await repo.deactivateAccount(accountId);
      } else {
        await repo.activateAccount(accountId);
      }
      ref.invalidate(accountListProvider);
      ref.invalidate(accountsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentlyActive
                ? 'Account marked inactive'
                : 'Account marked active'),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _deleteAccount(
    BuildContext context,
    WidgetRef ref,
    String name,
    bool isSystem,
  ) async {
    if (isSystem) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('System accounts cannot be deleted')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: Text('Delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: KColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        await ref.read(accountRepositoryProvider).deleteAccount(accountId);
        ref.invalidate(accountListProvider);
        ref.invalidate(accountsProvider);
        if (context.mounted) context.pop();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  Color _typeColor(String type) => switch (type) {
        'ASSET' => KColors.info,
        'LIABILITY' => KColors.warning,
        'EQUITY' => KColors.success,
        'REVENUE' || 'INCOME' => KColors.primary,
        'EXPENSE' => KColors.error,
        _ => KColors.textSecondary,
      };
}

class _DetailsTab extends StatelessWidget {
  final Map<String, dynamic> account;
  final Color typeColor;

  const _DetailsTab({required this.account, required this.typeColor});

  @override
  Widget build(BuildContext context) {
    final code = account['code'] as String? ?? '';
    final name = account['name'] as String? ?? '';
    final type = account['type'] as String? ?? '';
    final subType = account['subType'] as String?;
    final description = account['description'] as String?;
    final openingBalance = account['openingBalance'] as num?;
    final currency = account['currency'] as String? ?? 'INR';
    final isActive = account['isActive'] as bool? ?? true;
    final isSystem = account['isSystem'] as bool? ?? false;
    final level = (account['level'] as num?)?.toInt() ?? 1;

    return SingleChildScrollView(
      padding: KSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      code.isNotEmpty ? code.substring(0, code.length.clamp(0, 4)) : '?',
                      style: KTypography.h2.copyWith(color: typeColor),
                    ),
                  ),
                ),
                KSpacing.vGapMd,
                Text(name, style: KTypography.h2),
                KSpacing.vGapXs,
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _TypeChip(label: _typeLabel(type), color: typeColor),
                    if (!isActive) ...[
                      KSpacing.hGapSm,
                      _TypeChip(label: 'Inactive', color: KColors.draft),
                    ],
                    if (isSystem) ...[
                      KSpacing.hGapSm,
                      _TypeChip(label: 'System', color: KColors.textSecondary),
                    ],
                  ],
                ),
              ],
            ),
          ),
          KSpacing.vGapLg,

          _SectionHeader('Account Info'),
          _InfoRow(Icons.tag_outlined, 'Code', code),
          _InfoRow(Icons.account_tree_outlined, 'Level', 'Level $level'),
          if (subType != null && subType.isNotEmpty)
            _InfoRow(
              Icons.subdirectory_arrow_right_outlined,
              'Sub-type',
              subType.replaceAll('_', ' '),
            ),
          _InfoRow(Icons.currency_rupee, 'Currency', currency),
          if (description != null && description.isNotEmpty) ...[
            KSpacing.vGapMd,
            _SectionHeader('Description'),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(description, style: KTypography.bodyMedium),
            ),
          ],
          KSpacing.vGapMd,
          _SectionHeader('Opening Balance'),
          _InfoRow(
            Icons.account_balance_wallet_outlined,
            'Opening Balance',
            '₹${(openingBalance ?? 0).toStringAsFixed(2)}',
          ),
          KSpacing.vGapXl,
        ],
      ),
    );
  }

  String _typeLabel(String type) => switch (type.toUpperCase()) {
        'ASSET' => 'Asset',
        'LIABILITY' => 'Liability',
        'EQUITY' => 'Equity',
        'REVENUE' || 'INCOME' => 'Income',
        'EXPENSE' => 'Expense',
        _ => type,
      };
}

class _BalanceTab extends ConsumerWidget {
  final String accountId;

  const _BalanceTab({required this.accountId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Map<String, dynamic>>(
      future: ref.read(accountRepositoryProvider).getBalance(accountId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const KLoading();
        }
        if (snapshot.hasError) {
          return KErrorView(message: 'Failed to load balance');
        }

        final raw = snapshot.data!;
        final data = (raw['data'] ?? raw) as Map<String, dynamic>;
        final balance = (data['balance'] as num?)?.toDouble() ?? 0.0;
        final asOfDate = data['asOfDate']?.toString() ?? '';

        final isPositive = balance >= 0;
        final balanceColor = isPositive ? KColors.success : KColors.error;

        return SingleChildScrollView(
          padding: KSpacing.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KSpacing.vGapLg,
              Center(
                child: Column(
                  children: [
                    Text('Current Balance', style: KTypography.bodyMedium),
                    KSpacing.vGapSm,
                    Text(
                      '₹${balance.abs().toStringAsFixed(2)}',
                      style: KTypography.displayLarge.copyWith(
                        color: balanceColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!isPositive)
                      Text(
                        'Credit Balance',
                        style: KTypography.bodySmall.copyWith(
                          color: KColors.error,
                        ),
                      ),
                    KSpacing.vGapSm,
                    if (asOfDate.isNotEmpty)
                      Text(
                        'As of $asOfDate',
                        style: KTypography.bodySmall,
                      ),
                  ],
                ),
              ),
              KSpacing.vGapXl,
            ],
          ),
        );
      },
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final Color color;

  const _TypeChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: KTypography.labelMedium.copyWith(color: color),
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: KSpacing.sm),
        child: Text(title, style: KTypography.h3),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;

  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: KColors.textHint),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: KTypography.labelSmall),
                Text(value!, style: KTypography.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
