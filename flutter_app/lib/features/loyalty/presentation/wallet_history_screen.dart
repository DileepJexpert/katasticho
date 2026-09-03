import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/wallet_repository.dart';

/// Full-page wallet transaction history for a specific customer.
///
/// Shows a balance summary card at the top, then a chronological list of
/// EARN / REDEEM / ADJUSTMENT transactions.
class WalletHistoryScreen extends ConsumerWidget {
  const WalletHistoryScreen({
    super.key,
    required this.contactId,
    this.contactName,
  });

  final String contactId;
  final String? contactName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(contactWalletProvider(contactId));
    final txnsAsync =
        ref.watch(contactWalletTransactionsProvider(contactId));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Loyalty Wallet',
                style:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            if (contactName != null && contactName!.isNotEmpty)
              Text(
                contactName!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.55),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(contactWalletProvider(contactId));
              ref.invalidate(
                  contactWalletTransactionsProvider(contactId));
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(contactWalletProvider(contactId));
          ref.invalidate(
              contactWalletTransactionsProvider(contactId));
        },
        child: CustomScrollView(
          slivers: [
            // ── Balance summary card ──────────────────────────
            SliverToBoxAdapter(
              child: walletAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: KShimmerList(),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: KErrorView(
                      message: 'Could not load wallet: $e'),
                ),
                data: (wallet) => _WalletSummaryCard(wallet: wallet),
              ),
            ),

            // ── Transaction list header ───────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding:
                    EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Transaction History',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            // ── Transactions ──────────────────────────────────
            txnsAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                child: KErrorView(
                    message: 'Could not load transactions: $e'),
              ),
              data: (txns) {
                if (txns.isEmpty) {
                  return const SliverFillRemaining(
                    child: KEmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'No transactions yet',
                      subtitle:
                          'Points are earned with every purchase',
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == txns.length) {
                        return const SizedBox(height: 32);
                      }
                      return _TransactionTile(txn: txns[index]);
                    },
                    childCount: txns.length + 1,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Balance summary card ─────────────────────────────────────────────────

class _WalletSummaryCard extends StatelessWidget {
  const _WalletSummaryCard({required this.wallet});

  final Map<String, dynamic>? wallet;

  @override
  Widget build(BuildContext context) {
    if (wallet == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: KEmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: 'No wallet found',
          subtitle: 'Wallet is created automatically on first purchase',
        ),
      );
    }

    final balance = (wallet!['balance'] as num?)?.toDouble() ?? 0;
    final totalEarned = (wallet!['totalEarned'] as num?)?.toDouble() ?? 0;
    final totalRedeemed =
        (wallet!['totalRedeemed'] as num?)?.toDouble() ?? 0;

    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 0,
        color: cs.primaryContainer,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KSpacing.radiusMd)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance_wallet,
                      color: cs.primary, size: 22),
                  const SizedBox(width: 8),
                  Text('Current Balance',
                      style: KTypography.labelSmall
                          .copyWith(color: cs.primary)),
                ],
              ),
              const SizedBox(height: 8),
              KMoney(
                balance,
                size: KMoneySize.large,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '1 point = ₹1 discount · Min ₹10 · Max 50% of sale',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.primary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatCell(
                      label: 'Total Earned',
                      amount: totalEarned,
                      color: KColors.success,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCell(
                      label: 'Total Redeemed',
                      amount: totalRedeemed,
                      color: cs.error,
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

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final num amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        KMoney(
          amount,
          size: KMoneySize.medium,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ── Transaction tile ─────────────────────────────────────────────────────

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.txn});

  final Map<String, dynamic> txn;

  @override
  Widget build(BuildContext context) {
    final txnType = txn['txnType']?.toString() ?? '';
    final amount = (txn['amount'] as num?)?.toDouble() ?? 0;
    final balanceAfter = (txn['balanceAfter'] as num?)?.toDouble() ?? 0;
    final notes = txn['notes']?.toString();
    final referenceType = txn['referenceType']?.toString();
    final createdAt = txn['createdAt']?.toString();

    final isEarn = txnType == 'EARN';
    final isRedeem = txnType == 'REDEEM';

    final typeColor = isEarn
        ? KColors.success
        : isRedeem
            ? Theme.of(context).colorScheme.error
            : Colors.orange;

    final typeIcon = isEarn
        ? Icons.add_circle_outline
        : isRedeem
            ? Icons.remove_circle_outline
            : Icons.swap_horiz;

    final typeLabel = isEarn
        ? 'Earned'
        : isRedeem
            ? 'Redeemed'
            : 'Adjusted';

    final amountText = isEarn
        ? '+₹${amount.toStringAsFixed(0)}'
        : '-₹${amount.abs().toStringAsFixed(0)}';

    String? formattedDate;
    if (createdAt != null) {
      final dt = DateTime.tryParse(createdAt);
      if (dt != null) {
        formattedDate =
            DateFormat('d MMM yyyy, h:mm a').format(dt.toLocal());
      }
    }

    return Column(
      children: [
        ListTile(
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(typeIcon, color: typeColor, size: 18),
          ),
          title: Text(
            typeLabel,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (formattedDate != null)
                Text(formattedDate,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey)),
              if (notes != null && notes.isNotEmpty)
                Text(notes,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey)),
              if (referenceType != null &&
                  referenceType.isNotEmpty)
                Text('Ref: $referenceType',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey)),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amountText,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: typeColor,
                ),
              ),
              Text(
                'Bal ₹${balanceAfter.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          isThreeLine: (notes != null && notes.isNotEmpty) ||
              (referenceType != null && referenceType.isNotEmpty),
        ),
        const Divider(height: 1, indent: 72),
      ],
    );
  }
}
