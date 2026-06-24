import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_config.dart';
import '../../../../core/auth/auth_state.dart';
import '../../../../core/theme/k_colors.dart';
import '../../../../core/theme/k_spacing.dart';
import '../../../../core/theme/k_typography.dart';
import '../../../../core/utils/api_error_parser.dart';
import '../../../../core/widgets/widgets.dart';

/// Per-bill 3-way match snapshot: header status + per-line variance rows.
///
/// Shared between the AP Inbox (Exceptions tab) and the Bill detail screen
/// so that one source of truth governs how a match result is rendered.
///
/// Design tokens in play:
/// - KStatusChip for the header + per-line status (keyword-infer covers
///   MATCHED / EXCEPTION / BYPASSED / OVERRIDDEN / QTY_OVER / PRICE_HIKE /
///   NO_PO / NO_GRN)
/// - KMoney for prices/variances (₹ Indian grouping + tabular figures)
/// - KTypography.mono for bill / PO / GRN numbers
/// - KSpacing tokens for padding & gaps; KCard for sectioning
class ThreeWayMatchDetailSheet extends ConsumerStatefulWidget {
  final String billId;

  /// Optional callback fired when the user successfully posts an override —
  /// so the parent (e.g. the Exceptions list) can refresh.
  final VoidCallback? onChanged;

  const ThreeWayMatchDetailSheet({
    super.key,
    required this.billId,
    this.onChanged,
  });

  /// Shows the sheet as a modal bottom sheet. Constrained to ~85% of screen
  /// height so the user can still see the underlying list and dismiss by tap.
  static Future<void> show(
    BuildContext context,
    String billId, {
    VoidCallback? onChanged,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.88,
        child: ThreeWayMatchDetailSheet(
          billId: billId,
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  ConsumerState<ThreeWayMatchDetailSheet> createState() =>
      _ThreeWayMatchDetailSheetState();
}

class _ThreeWayMatchDetailSheetState
    extends ConsumerState<ThreeWayMatchDetailSheet> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final res = await ref
        .read(apiClientProvider)
        .get(ApiConfig.threeWayMatchById(widget.billId));
    final data = res.data;
    final payload = (data is Map && data['data'] is Map)
        ? data['data'] as Map<String, dynamic>
        : (data as Map).cast<String, dynamic>();
    return payload;
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _rerunMatch() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(apiClientProvider)
          .post(ApiConfig.threeWayMatchRun(widget.billId));
      await _reload();
      widget.onChanged?.call();
      messenger.showSnackBar(
        const SnackBar(content: Text('Match re-run complete')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(ApiErrorParser.message(e))),
      );
    }
  }

  Future<void> _override() async {
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Override exception'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mark this bill as OVERRIDDEN so it can be paid despite the '
                'PO / GRN variance. The reason is stored on the bill and '
                'visible to auditors.',
                style: KTypography.bodySmall
                    .copyWith(color: KColors.textSecondary),
              ),
              SizedBox(height: KSpacing.md),
              KTextField(
                label: 'Reason',
                hint: 'e.g. Supplier renegotiated price after PO',
                controller: reasonCtrl,
                maxLines: 3,
                isRequired: true,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Reason is required'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Override'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(apiClientProvider).post(
            ApiConfig.threeWayMatchOverride(widget.billId),
            data: {'reason': reasonCtrl.text.trim()},
          );
      await _reload();
      widget.onChanged?.call();
      messenger.showSnackBar(
        const SnackBar(content: Text('Bill marked as OVERRIDDEN')),
      );
    } on DioException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(ApiErrorParser.message(e))),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(ApiErrorParser.message(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = ref.watch(authProvider).role == 'OWNER';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drag handle + title row
        Padding(
          padding: EdgeInsets.fromLTRB(
              KSpacing.md, KSpacing.sm, KSpacing.md, KSpacing.xs),
          child: Row(
            children: [
              Icon(Icons.fact_check_rounded,
                  size: 20, color: KColors.textSecondary),
              SizedBox(width: KSpacing.sm),
              Expanded(
                child: Text('3-Way Match Details',
                    style: KTypography.titleMedium),
              ),
              IconButton(
                tooltip: 'Re-run match',
                onPressed: _rerunMatch,
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(KSpacing.md),
                    child: Text(
                      ApiErrorParser.message(snap.error!),
                      style: TextStyle(color: KColors.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return _Body(
                data: snap.data ?? const {},
                isOwner: isOwner,
                onOverride: _override,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isOwner;
  final VoidCallback onOverride;

  const _Body({
    required this.data,
    required this.isOwner,
    required this.onOverride,
  });

  @override
  Widget build(BuildContext context) {
    final status = data['status']?.toString() ?? 'UNKNOWN';
    final billNumber = data['billNumber']?.toString() ?? '—';
    final lines = (data['lines'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final overrideReason = data['overrideReason']?.toString();
    // MatchSnapshot exposes matchedAt (the last-run timestamp) — for an
    // OVERRIDDEN bill that timestamp doubles as the override stamp.
    final stampedAt = data['matchedAt']?.toString();
    final canOverride = isOwner &&
        status != 'OVERRIDDEN' &&
        status != 'MATCHED' &&
        status != 'BYPASSED';

    return ListView(
      padding: EdgeInsets.all(KSpacing.md),
      children: [
        // Header card — bill + overall status
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bill',
                            style: KTypography.bodySmall
                                .copyWith(color: KColors.textSecondary)),
                        SizedBox(height: KSpacing.xxs),
                        Text(billNumber, style: KTypography.mono()),
                      ],
                    ),
                  ),
                  KStatusChip(status: status),
                ],
              ),
              if (overrideReason != null && overrideReason.isNotEmpty) ...[
                SizedBox(height: KSpacing.md),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(KSpacing.sm),
                  decoration: BoxDecoration(
                    color: KColors.infoLight,
                    borderRadius:
                        BorderRadius.circular(KSpacing.radiusMd),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Override reason',
                        style: KTypography.labelSmall
                            .copyWith(color: KColors.textSecondary),
                      ),
                      SizedBox(height: KSpacing.xxs),
                      Text(overrideReason),
                      if (stampedAt != null && stampedAt.isNotEmpty) ...[
                        SizedBox(height: KSpacing.xxs),
                        Text(
                          'Stamped ${_fmtTs(stampedAt)}',
                          style: KTypography.bodySmall
                              .copyWith(color: KColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (canOverride) ...[
                SizedBox(height: KSpacing.md),
                Align(
                  alignment: Alignment.centerRight,
                  child: KButton(
                    label: 'Override',
                    icon: Icons.gpp_maybe_rounded,
                    variant: KButtonVariant.outlined,
                    onPressed: onOverride,
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: KSpacing.md),
        // Per-line variance
        Text(
          'Line variances (${lines.length})',
          style: KTypography.labelMedium
              .copyWith(color: KColors.textSecondary),
        ),
        SizedBox(height: KSpacing.sm),
        if (lines.isEmpty)
          KCard(
            child: KEmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: 'No line variances recorded',
              subtitle:
                  'This bill matched cleanly or has not been run through 3-way match yet.',
            ),
          )
        else
          for (final line in lines)
            Padding(
              padding: EdgeInsets.only(bottom: KSpacing.sm),
              child: _LineCard(line: line),
            ),
        SizedBox(height: KSpacing.lg),
      ],
    );
  }

  static String _fmtTs(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('dd MMM yyyy, HH:mm').format(dt);
    } catch (_) {
      return iso;
    }
  }
}

class _LineCard extends StatelessWidget {
  final Map<String, dynamic> line;
  const _LineCard({required this.line});

  @override
  Widget build(BuildContext context) {
    final status = line['status']?.toString() ?? 'UNKNOWN';
    final itemName = line['itemName']?.toString() ??
        line['description']?.toString() ??
        '—';
    // Field names mirror BillMatchResultLine (Lombok camelCase from snake_case).
    final billedQty =
        _num(line['billedQty'] ?? line['billedQuantity']);
    final receivedQty =
        _num(line['receivedQty'] ?? line['receivedQuantity']);
    final orderedQty =
        _num(line['orderedQty'] ?? line['orderedQuantity']);
    final billPrice = _num(line['billUnitPrice']);
    final poPrice = _num(line['poUnitPrice']);
    // Service writes priceVariance / amountVariance / qtyVariance — show
    // amount as the headline since that's what hits the books.
    final variance = _num(line['amountVariance'] ??
        line['priceVariance'] ??
        line['variance']);
    final note = line['note']?.toString();
    final priceDelta = billPrice - poPrice;

    return KCard(
      padding: EdgeInsets.all(KSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(itemName, style: KTypography.titleSmall),
              ),
              KStatusChip(status: status, dense: true),
            ],
          ),
          SizedBox(height: KSpacing.sm),
          // Qty row
          _MetricRow(
            label: 'Billed',
            value: _fmtQty(billedQty),
            valueIsMono: true,
          ),
          _MetricRow(
            label: 'Received (GRN)',
            value: _fmtQty(receivedQty),
            valueIsMono: true,
            highlight: _isQtyVariance(status),
          ),
          _MetricRow(
            label: 'Ordered (PO)',
            value: _fmtQty(orderedQty),
            valueIsMono: true,
          ),
          SizedBox(height: KSpacing.xs),
          const Divider(height: 1),
          SizedBox(height: KSpacing.xs),
          _PriceRow(
            label: 'Bill price',
            amount: billPrice,
            highlight: _isPriceVariance(status) && priceDelta != 0,
          ),
          _PriceRow(
            label: 'PO price',
            amount: poPrice,
          ),
          if (variance != 0)
            _PriceRow(
              label: 'Variance',
              amount: variance,
              colorBySign: true,
            ),
          if (note != null && note.isNotEmpty) ...[
            SizedBox(height: KSpacing.xs),
            Text(
              note,
              style: KTypography.bodySmall
                  .copyWith(color: KColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  static double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

  static String _fmtQty(double q) {
    if (q == q.roundToDouble()) return q.toStringAsFixed(0);
    return q.toStringAsFixed(2);
  }

  static bool _isQtyVariance(String s) =>
      s == 'QTY_OVER' || s == 'NO_GRN';

  static bool _isPriceVariance(String s) =>
      s == 'PRICE_HIKE' || s == 'AMOUNT_MISMATCH';
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final bool valueIsMono;
  final bool highlight;
  const _MetricRow({
    required this.label,
    required this.value,
    this.valueIsMono = false,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: KSpacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: KTypography.bodySmall
                    .copyWith(color: KColors.textSecondary)),
          ),
          Text(
            value,
            style: (valueIsMono ? KTypography.mono() : KTypography.bodySmall)
                .copyWith(
              color: highlight ? KColors.error : null,
              fontWeight: highlight ? FontWeight.w600 : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool highlight;
  final bool colorBySign;
  const _PriceRow({
    required this.label,
    required this.amount,
    this.highlight = false,
    this.colorBySign = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: KSpacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: KTypography.bodySmall.copyWith(
                color: highlight ? KColors.error : KColors.textSecondary,
                fontWeight: highlight ? FontWeight.w600 : null,
              ),
            ),
          ),
          KMoney(
            amount,
            colorBySign: colorBySign,
            style: highlight
                ? const TextStyle(fontWeight: FontWeight.w600)
                : null,
          ),
        ],
      ),
    );
  }
}
