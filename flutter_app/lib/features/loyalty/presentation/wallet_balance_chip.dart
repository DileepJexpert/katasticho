import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/wallet_repository.dart';

/// A small chip shown in the POS when a customer is selected.
/// Displays wallet balance and lets the cashier initiate a redemption.
///
/// [onRedeem] is called with the chosen redemption amount so the caller
/// can deduct it from the sale total.
class WalletBalanceChip extends ConsumerWidget {
  const WalletBalanceChip({
    super.key,
    required this.contactId,
    required this.cartTotal,
    required this.onRedeem,
  });

  final String contactId;
  final double cartTotal;
  final ValueChanged<double> onRedeem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(contactWalletProvider(contactId));

    return walletAsync.when(
      loading: () => const SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (wallet) {
        if (wallet == null) return const SizedBox.shrink();

        final balance = (wallet['balance'] as num?)?.toDouble() ?? 0;
        if (balance <= 0) return const SizedBox.shrink();

        final cs = Theme.of(context).colorScheme;

        return _WalletChipContent(
          balance: balance,
          cartTotal: cartTotal,
          onRedeem: onRedeem,
          cs: cs,
        );
      },
    );
  }
}

class _WalletChipContent extends StatelessWidget {
  const _WalletChipContent({
    required this.balance,
    required this.cartTotal,
    required this.onRedeem,
    required this.cs,
  });

  final double balance;
  final double cartTotal;
  final ValueChanged<double> onRedeem;
  final ColorScheme cs;

  // Max redeemable: min(balance, cartTotal * 0.5), and must be >= 10
  double get _maxRedeemable {
    final cap = cartTotal * 0.5;
    return balance < cap ? balance : cap;
  }

  bool get _canRedeem => balance >= 10 && cartTotal > 0 && _maxRedeemable >= 10;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              size: 14, color: cs.primary),
          const SizedBox(width: 4),
          Text(
            '₹${balance.toStringAsFixed(0)} pts',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.primary,
            ),
          ),
          if (_canRedeem) ...[
            const SizedBox(width: 6),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showRedeemDialog(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Redeem up to ₹${_maxRedeemable.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.onPrimary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showRedeemDialog(BuildContext context) async {
    final maxAmt = _maxRedeemable;
    final controller = TextEditingController(
      text: maxAmt.toStringAsFixed(0),
    );

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => _RedeemDialog(
        balance: balance,
        maxRedeemable: maxAmt,
        controller: controller,
      ),
    );

    controller.dispose();

    if (result != null && result > 0) {
      onRedeem(result);
    }
  }
}

class _RedeemDialog extends StatefulWidget {
  const _RedeemDialog({
    required this.balance,
    required this.maxRedeemable,
    required this.controller,
  });

  final double balance;
  final double maxRedeemable;
  final TextEditingController controller;

  @override
  State<_RedeemDialog> createState() => _RedeemDialogState();
}

class _RedeemDialogState extends State<_RedeemDialog> {
  String? _error;

  void _validate(String value) {
    final amt = double.tryParse(value);
    setState(() {
      if (amt == null || amt <= 0) {
        _error = 'Enter a valid amount';
      } else if (amt < 10) {
        _error = 'Minimum redemption is ₹10';
      } else if (amt > widget.maxRedeemable) {
        _error =
            'Maximum redeemable is ₹${widget.maxRedeemable.toStringAsFixed(0)}';
      } else {
        _error = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.account_balance_wallet_outlined, size: 20),
          const SizedBox(width: 8),
          const Expanded(child: Text('Redeem Wallet Points')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available: ₹${widget.balance.toStringAsFixed(0)} '
            '· Max this sale: ₹${widget.maxRedeemable.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          const Text(
            'Min ₹10 · Up to 50% of sale total',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: widget.controller,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Redeem amount',
              prefixText: '₹ ',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
            onChanged: _validate,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _error != null
              ? null
              : () {
                  final amt =
                      double.tryParse(widget.controller.text.trim()) ?? 0;
                  if (amt >= 10 && amt <= widget.maxRedeemable) {
                    Navigator.pop(context, amt);
                  }
                },
          child: const Text('Confirm Redemption'),
        ),
      ],
    );
  }
}
