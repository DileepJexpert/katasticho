import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/k_colors.dart';
import '../../../../core/theme/k_spacing.dart';
import '../../../../core/theme/k_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/pos_cart_state.dart';
import '../../data/pos_repository.dart';

Future<void> showCustomerHistorySheet(
  BuildContext context, {
  required String contactId,
  required String contactName,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _CustomerHistorySheet(
      contactId: contactId,
      contactName: contactName,
    ),
  );
}

class _CustomerHistorySheet extends ConsumerStatefulWidget {
  final String contactId;
  final String contactName;

  const _CustomerHistorySheet({
    required this.contactId,
    required this.contactName,
  });

  @override
  ConsumerState<_CustomerHistorySheet> createState() =>
      _CustomerHistorySheetState();
}

class _CustomerHistorySheetState extends ConsumerState<_CustomerHistorySheet> {
  int _selectedDays = 180;
  Map<String, dynamic>? _data;
  bool _isLoading = false;
  String? _error;

  static const _periods = [
    (label: '1M', days: 30),
    (label: '3M', days: 90),
    (label: '6M', days: 180),
    (label: '1Y', days: 365),
    (label: 'All', days: 1825),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(posRepositoryProvider);
      final result = await repo.getCustomerHistory(
        widget.contactId,
        days: _selectedDays,
      );
      final raw = result['data'] ?? result;
      setState(() {
        _data = raw is Map ? raw.cast<String, dynamic>() : null;
      });
    } catch (e) {
      setState(() => _error = 'Could not load history');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changePeriod(int days) {
    if (_selectedDays == days) return;
    setState(() => _selectedDays = days);
    _load();
  }

  Future<void> _repeatOrder(String receiptId) async {
    try {
      final repo = ref.read(posRepositoryProvider);
      final result = await repo.getReceipt(receiptId);
      final data = (result['data'] ?? result) as Map<String, dynamic>;
      final lines = (data['lines'] as List?) ?? [];

      if (lines.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No items found in this receipt')),
          );
        }
        return;
      }

      final cart = ref.read(posCartProvider.notifier);
      int addedCount = 0;

      for (final line in lines) {
        final m = line as Map<String, dynamic>;
        final itemId = m['itemId']?.toString();
        final name = (m['itemName'] ?? m['description'] ?? '--') as String;
        final rate = (m['rate'] as num?)?.toDouble() ?? 0;
        final qty = (m['quantity'] as num?)?.toDouble() ?? 1;

        if (rate <= 0) continue;

        cart.addItem(CartItem(
          itemId: itemId,
          name: name,
          sku: m['itemSku']?.toString(),
          rate: rate,
          unit: m['unit'] as String?,
          mrp: (m['mrp'] as num?)?.toDouble(),
          hsnCode: m['hsnCode'] as String?,
          taxGroupId: m['taxGroupId']?.toString(),
          batchId: m['batchId']?.toString(),
          quantity: qty,
        ));
        addedCount++;
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$addedCount items added to cart'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load receipt items')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle + header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: KColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  KSpacing.vGapMd,
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor:
                            KColors.primary.withValues(alpha: 0.12),
                        child: Text(
                          widget.contactName.isNotEmpty
                              ? widget.contactName[0].toUpperCase()
                              : '?',
                          style: KTypography.labelLarge
                              .copyWith(color: KColors.primary),
                        ),
                      ),
                      KSpacing.hGapMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.contactName,
                                style: KTypography.labelLarge),
                            Text('Purchase History',
                                style: KTypography.bodySmall
                                    .copyWith(color: KColors.textSecondary)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.push('/contacts/${widget.contactId}');
                        },
                        child: const Text('Full Profile'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Period filter
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: _periods.map((p) {
                  final selected = _selectedDays == p.days;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(p.label),
                      selected: selected,
                      onSelected: (_) => _changePeriod(p.days),
                      visualDensity: VisualDensity.compact,
                      selectedColor: KColors.primary.withValues(alpha: 0.12),
                      labelStyle: KTypography.labelSmall.copyWith(
                        color: selected ? KColors.primary : null,
                        fontWeight: selected ? FontWeight.w700 : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Body
            Expanded(
              child: _isLoading
                  ? const KShimmerList()
                  : _error != null
                      ? KErrorView(
                          message: _error!,
                          onRetry: _load,
                        )
                      : _data == null
                          ? const KEmptyState(
                              icon: Icons.receipt_long_outlined,
                              title: 'No purchase history',
                            )
                          : _buildBody(scrollController),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBody(ScrollController scrollController) {
    final outstanding = (_data!['outstandingAmount'] as num?)?.toDouble() ?? 0;
    final totalSpent = (_data!['totalSpent'] as num?)?.toDouble() ?? 0;
    final visitCount = (_data!['visitCount'] as int?) ?? 0;
    final receipts = (_data!['recentReceipts'] as List?) ?? [];

    return ListView(
      controller: scrollController,
      padding: KSpacing.pagePadding,
      children: [
        // Outstanding warning
        if (outstanding > 0.01)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: KColors.error.withValues(alpha: 0.08),
              borderRadius: KSpacing.borderRadiusMd,
              border: Border.all(color: KColors.error.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: KColors.error, size: 18),
                KSpacing.hGapSm,
                Expanded(
                  child: Text(
                    '${CurrencyFormatter.formatIndian(outstanding)} invoice outstanding',
                    style:
                        KTypography.labelMedium.copyWith(color: KColors.error),
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message:
                      'This is from unpaid invoices / opening balance,\nnot from POS cash sales',
                  child: Icon(Icons.info_outline,
                      size: 14, color: KColors.error.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),

        // Compact summary row
        Row(
          children: [
            const Icon(Icons.currency_rupee_rounded,
                size: 14, color: KColors.textSecondary),
            const SizedBox(width: 2),
            Text(CurrencyFormatter.formatIndian(totalSpent),
                style:
                    KTypography.labelMedium.copyWith(color: KColors.success)),
            const SizedBox(width: 4),
            Text('spent',
                style: KTypography.bodySmall
                    .copyWith(color: KColors.textSecondary)),
            const SizedBox(width: 12),
            const Icon(Icons.receipt_long_outlined,
                size: 14, color: KColors.textSecondary),
            const SizedBox(width: 4),
            Text('$visitCount bill${visitCount == 1 ? '' : 's'}',
                style:
                    KTypography.labelMedium.copyWith(color: KColors.primary)),
          ],
        ),
        KSpacing.vGapMd,

        if (receipts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: KEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No purchases in this period',
            ),
          )
        else ...[
          Text('Recent Purchases', style: KTypography.labelLarge),
          KSpacing.vGapSm,
          ...receipts.map((r) => _ReceiptCard(
                receipt: r as Map<String, dynamic>,
                onRepeat: _repeatOrder,
              )),
        ],
      ],
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final Map<String, dynamic> receipt;
  final Future<void> Function(String receiptId) onRepeat;

  const _ReceiptCard({required this.receipt, required this.onRepeat});

  @override
  Widget build(BuildContext context) {
    final receiptNumber = receipt['receiptNumber'] as String? ?? '--';
    final total = (receipt['total'] as num?)?.toDouble() ?? 0;
    final paymentMode = receipt['paymentMode'] as String? ?? 'CASH';
    final date = receipt['receiptDate'] as String?;
    final items = (receipt['items'] as List?) ?? [];
    final id = receipt['id'] as String?;

    final dateDisplay = date != null ? _formatDate(date) : '--';

    return KCard(
      margin: const EdgeInsets.only(bottom: 8),
      onTap: id != null
          ? () {
              Navigator.pop(context);
              context.push('/sales-receipts/$id');
            }
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_outlined,
                  size: 16, color: KColors.textSecondary),
              KSpacing.hGapXs,
              Text(receiptNumber, style: KTypography.labelMedium),
              const Spacer(),
              if (id != null)
                SizedBox(
                  height: 28,
                  child: TextButton.icon(
                    onPressed: () => onRepeat(id),
                    icon: const Icon(Icons.replay_rounded, size: 14),
                    label: const Text('Repeat'),
                    style: TextButton.styleFrom(
                      foregroundColor: KColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: KTypography.labelSmall,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              KSpacing.hGapSm,
              Text(
                CurrencyFormatter.formatIndian(total),
                style: KTypography.amountSmall,
              ),
            ],
          ),
          KSpacing.vGapXs,
          Row(
            children: [
              Text(dateDisplay,
                  style: KTypography.bodySmall
                      .copyWith(color: KColors.textSecondary)),
              const Text(' · ', style: TextStyle(color: KColors.textHint)),
              _PaymentBadge(mode: paymentMode),
            ],
          ),
          if (items.isNotEmpty) ...[
            KSpacing.vGapXs,
            ...items.take(3).map((item) {
              final m = item as Map<String, dynamic>;
              final name = m['name'] as String? ?? '--';
              final qty = (m['quantity'] as num?)?.toDouble() ?? 0;
              final unit = m['unit'] as String? ?? '';
              final amount = (m['amount'] as num?)?.toDouble() ?? 0;
              return Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    const Text('  · ',
                        style:
                            TextStyle(color: KColors.textHint, fontSize: 11)),
                    Expanded(
                      child: Text(
                        '$name × ${_fmtQty(qty)} $unit'.trim(),
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatIndian(amount),
                      style: KTypography.bodySmall,
                    ),
                  ],
                ),
              );
            }),
            if (items.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 14),
                child: Text(
                  '+${items.length - 3} more items',
                  style:
                      KTypography.labelSmall.copyWith(color: KColors.textHint),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      const months = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${d.day} ${months[d.month]}';
    } catch (_) {
      return iso;
    }
  }

  String _fmtQty(double qty) => qty == qty.roundToDouble()
      ? qty.toInt().toString()
      : qty.toStringAsFixed(3);
}

class _PaymentBadge extends StatelessWidget {
  final String mode;
  const _PaymentBadge({required this.mode});

  @override
  Widget build(BuildContext context) {
    final color = switch (mode) {
      'UPI' => KColors.info,
      'CARD' => KColors.warning,
      _ => KColors.success,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        mode,
        style: KTypography.labelSmall.copyWith(
          color: color,
          fontSize: 10,
        ),
      ),
    );
  }
}
