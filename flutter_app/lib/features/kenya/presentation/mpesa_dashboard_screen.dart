import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../../../core/widgets/k_text_field.dart';
import '../data/kenya_repository.dart';

class MpesaDashboardScreen extends ConsumerStatefulWidget {
  const MpesaDashboardScreen({super.key});

  @override
  ConsumerState<MpesaDashboardScreen> createState() => _MpesaDashboardScreenState();
}

class _MpesaDashboardScreenState extends ConsumerState<MpesaDashboardScreen> {
  String _selectedStatus = 'ALL';
  List<MpesaTransactionDto> _transactions = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(kenyaRepositoryProvider);
      final list = await repo.listTransactions(status: _selectedStatus);
      if (mounted) setState(() => _transactions = list);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load M-Pesa transactions: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showStkPushDialog() async {
    final phoneController = TextEditingController(text: '254712345678');
    final amountController = TextEditingController(text: '1500.00');
    final nameController = TextEditingController(text: 'Nairobi Trading Customer');
    final refController = TextEditingController(text: 'INV-2026-009');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.phone_android, color: Color(0xFF00A859)),
            SizedBox(width: 8),
            Text('Trigger M-Pesa STK Push (Lipa Na M-Pesa)'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KTextField(
                controller: phoneController,
                label: 'Customer Phone (e.g. 2547XXXXXXXX)',
              ),
              KSpacing.vGapMd,
              KTextField(
                controller: amountController,
                label: 'Amount (KSh)',
              ),
              KSpacing.vGapMd,
              KTextField(
                controller: nameController,
                label: 'Customer Name',
              ),
              KSpacing.vGapMd,
              KTextField(
                controller: refController,
                label: 'Account / Invoice Reference',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          KButton.primary(
            label: 'Send STK Prompt',
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (ok == true && phoneController.text.isNotEmpty && amountController.text.isNotEmpty) {
      try {
        final repo = ref.read(kenyaRepositoryProvider);
        final amt = double.tryParse(amountController.text) ?? 100.0;
        final tx = await repo.initiateStkPush(
          phoneNumber: phoneController.text.trim(),
          amount: amt,
          customerName: nameController.text.trim(),
          accountReference: refController.text.trim(),
        );
        _loadTransactions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('M-Pesa STK push completed! Receipt: ${tx.mpesaReceiptNumber}'),
              backgroundColor: KColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('STK Push failed: $e'), backgroundColor: KColors.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double totalCollected = 0;
    for (final t in _transactions) {
      totalCollected += t.amount;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('M-Pesa Collections & Reconciliation (Kenya)'),
        actions: [
          KButton.primary(
            label: 'Trigger STK Push',
            icon: Icons.send_to_mobile,
            onPressed: _showStkPushDialog,
          ),
          KSpacing.hGapSm,
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransactions,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // KPI Summary Cards
          Container(
            color: KColors.surface,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildKpi('Total M-Pesa Inflow', 'KSh ${CurrencyFormatter.format(totalCollected)}', Icons.account_balance_wallet, const Color(0xFF00A859)),
                KSpacing.hGapMd,
                _buildKpi('Transactions', '${_transactions.length}', Icons.receipt_long, KColors.primary),
                KSpacing.hGapMd,
                _buildKpi('Gateway Status', 'Daraja API Live', Icons.cloud_done, KColors.success),
              ],
            ),
          ),
          const Divider(height: 1),

          // Filter bar
          Container(
            color: KColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['ALL', 'COMPLETED', 'PENDING', 'RECONCILED'].map((s) {
                  final isSel = _selectedStatus == s;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(s),
                      selected: isSel,
                      onSelected: (_) {
                        setState(() => _selectedStatus = s);
                        _loadTransactions();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1),

          // Main list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error!, style: const TextStyle(color: KColors.error)),
                            KSpacing.vGapMd,
                            KButton.secondary(label: 'Retry', onPressed: _loadTransactions),
                          ],
                        ),
                      )
                    : _transactions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.phone_android, size: 64, color: KColors.textHint),
                                KSpacing.vGapMd,
                                Text('No M-Pesa transactions found', style: KTypography.h3),
                                KSpacing.vGapXs,
                                Text('Tap "Trigger STK Push" to initiate customer mobile collection prompt.',
                                    style: KTypography.bodySmall.copyWith(color: KColors.textHint)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: KSpacing.pagePadding,
                            itemCount: _transactions.length,
                            separatorBuilder: (_, __) => KSpacing.vGapMd,
                            itemBuilder: (context, index) {
                              final t = _transactions[index];
                              return _buildTxCard(t);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpi(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: KCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            KSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: KTypography.bodySmall.copyWith(color: KColors.textHint)),
                  KSpacing.vGapXs,
                  Text(value, style: KTypography.labelLarge.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTxCard(MpesaTransactionDto t) {
    return KCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: M-Pesa Icon badge
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF00A859).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.mobile_friendly, color: Color(0xFF00A859), size: 24),
            ),
          ),
          KSpacing.hGapMd,

          // Center Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      t.partyName ?? 'M-Pesa Customer',
                      style: KTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'KSh ${CurrencyFormatter.format(t.amount)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF00A859)),
                    ),
                  ],
                ),
                KSpacing.vGapXs,
                Row(
                  children: [
                    Text(t.phoneNumber, style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                    KSpacing.hGapMd,
                    Text('Receipt: ${t.mpesaReceiptNumber}',
                        style: KTypography.bodySmall.copyWith(color: KColors.textHint, fontFamily: 'monospace')),
                  ],
                ),
                KSpacing.vGapXs,
                Text(
                  'Ref: ${t.accountReference ?? "N/A"} · ${t.transactionTime.split('T').first}',
                  style: const TextStyle(fontSize: 11, color: KColors.textHint),
                ),
              ],
            ),
          ),
          KSpacing.hGapMd,

          // Status Chip
          KStatusChip(status: t.status),
        ],
      ),
    );
  }
}