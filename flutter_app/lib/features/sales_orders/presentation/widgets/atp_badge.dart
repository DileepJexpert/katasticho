import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_config.dart';
import '../../../../core/theme/k_colors.dart';
import '../../../../core/theme/k_spacing.dart';
import '../../../../core/theme/k_typography.dart';

/// Inline Available-to-Promise badge under the SO line qty cell.
///
/// Shows the honest answer to "can we ship N units of this item now?" the
/// moment the cashier picks an item + types a qty. Backend call is debounced
/// (300ms) so a fast typist doesn't fan out N requests.
///
/// Status taxonomy (mirrors backend `AtpResponse`):
/// - `ATP_OK`        — green pill, "Available now"
/// - `ATP_PARTIAL`   — amber pill, "N available now · M in transit"
/// - `ATP_BACKORDER` — red pill, "Backorder · ETA <date>"
class AtpBadge extends ConsumerStatefulWidget {
  final String? itemId;
  final String? warehouseId;
  final double qty;

  const AtpBadge({
    super.key,
    required this.itemId,
    required this.warehouseId,
    required this.qty,
  });

  @override
  ConsumerState<AtpBadge> createState() => _AtpBadgeState();
}

class _AtpBadgeState extends ConsumerState<AtpBadge> {
  Timer? _debounce;
  Map<String, dynamic>? _atp;
  bool _loading = false;

  @override
  void didUpdateWidget(covariant AtpBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemId != widget.itemId ||
        oldWidget.warehouseId != widget.warehouseId ||
        oldWidget.qty != widget.qty) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), _fetch);
    }
  }

  @override
  void initState() {
    super.initState();
    _debounce = Timer(const Duration(milliseconds: 300), _fetch);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    final itemId = widget.itemId;
    final warehouseId = widget.warehouseId;
    if (itemId == null || itemId.isEmpty || warehouseId == null || warehouseId.isEmpty) {
      if (mounted) setState(() => _atp = null);
      return;
    }
    if (widget.qty <= 0) {
      if (mounted) setState(() => _atp = null);
      return;
    }
    setState(() => _loading = true);
    try {
      final client = ref.read(apiClientProvider);
      final res = await client.dio.get(
        ApiConfig.inventoryAtp(itemId, warehouseId, widget.qty),
      );
      final body = res.data as Map<String, dynamic>;
      final data = Map<String, dynamic>.from((body['data'] as Map?) ?? const {});
      if (mounted) setState(() => _atp = data);
    } on DioException {
      // Silent fail — ATP is an aide, not a gate. The save path's own
      // validations are the real guard.
      if (mounted) setState(() => _atp = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_atp == null && !_loading) return const SizedBox.shrink();
    if (_loading && _atp == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text('Checking availability…',
            style: KTypography.bodySmall.copyWith(color: KColors.textHint)),
      );
    }
    final atp = _atp!;
    final status = atp['status']?.toString() ?? '';
    final availableNow = _num(atp['availableNow']);
    final openPurchase = _num(atp['openPurchaseQty']);
    final openProd = _num(atp['openProductionQty']);
    final inflow = openPurchase + openProd;
    final eta = atp['nextInflowDate']?.toString();

    Color bg;
    Color fg;
    IconData icon;
    String text;

    switch (status) {
      case 'ATP_OK':
        bg = KColors.success.withValues(alpha: 0.10);
        fg = KColors.success;
        icon = Icons.check_circle_outline;
        text = 'Available now';
        break;
      case 'ATP_PARTIAL':
        bg = KColors.warning.withValues(alpha: 0.12);
        fg = KColors.warning;
        icon = Icons.error_outline;
        final etaPart = eta != null && eta.isNotEmpty ? ' · ETA $eta' : '';
        text = inflow > 0
            ? '${_fmt(availableNow)} available · ${_fmt(inflow)} in transit$etaPart'
            : '${_fmt(availableNow)} available now';
        break;
      case 'ATP_BACKORDER':
        bg = KColors.error.withValues(alpha: 0.10);
        fg = KColors.error;
        icon = Icons.cancel_outlined;
        text = eta != null && eta.isNotEmpty
            ? 'Backorder · ETA $eta'
            : 'Backorder · No inflow scheduled';
        break;
      default:
        return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fg, size: 14),
            const SizedBox(width: 6),
            Flexible(
              child: Text(text,
                  style: KTypography.bodySmall.copyWith(
                      color: fg, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  static double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }
}
