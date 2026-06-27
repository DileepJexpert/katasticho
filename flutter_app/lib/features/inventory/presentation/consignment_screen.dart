import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../procurement/presentation/supplier_picker_sheet.dart';
import 'item_picker_sheet.dart';

/// Consignment / VMI — stock a supplier owns until it sells, then settle.
/// Backed by `ConsignmentController` (`/api/v1/inventory/consignment`):
/// receive stock, record a sale (drafts a settlement + deducts stock), and
/// settle (mark payable to the supplier). Two tabs: Stock + Settlements.
class ConsignmentScreen extends ConsumerStatefulWidget {
  const ConsignmentScreen({super.key});

  @override
  ConsumerState<ConsignmentScreen> createState() => _ConsignmentScreenState();
}

class _ConsignmentScreenState extends ConsumerState<ConsignmentScreen> {
  static final _money = NumberFormat.currency(
      locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _stock = [];
  final Map<String, String> _supplierNames = {};
  final Map<String, String> _warehouseNames = {};
  List<Map<String, dynamic>> _warehouses = [];

  // Settlements tab
  Map<String, dynamic>? _settleSupplier;
  List<Map<String, dynamic>> _settlements = [];
  bool _settlementsLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      // Name maps (best-effort) + warehouse dropdown source.
      try {
        final sup = await api.get(ApiConfig.suppliers);
        final list = _listOf(sup.data);
        _supplierNames
          ..clear()
          ..addEntries(list.map((s) => MapEntry(
              s['id'].toString(), (s['name'] ?? s['id']).toString())));
      } catch (_) {/* names optional */}
      try {
        final wh = await api.get(ApiConfig.warehouses);
        _warehouses = _listOf(wh.data);
        _warehouseNames
          ..clear()
          ..addEntries(_warehouses.map((w) => MapEntry(
              w['id'].toString(), (w['name'] ?? w['id']).toString())));
      } catch (_) {/* names optional */}

      final res = await api.get(ApiConfig.consignmentStock);
      _stock = _listOf(res.data);
    } on DioException catch (e) {
      _error = _msg(e) ?? 'Failed to load consignment stock';
    } catch (_) {
      _error = 'Failed to load consignment stock';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static List<Map<String, dynamic>> _listOf(dynamic body) {
    final data = body is Map ? body['data'] : body;
    final list = data is List
        ? data
        : (data is Map ? (data['content'] as List? ?? const []) : const []);
    return list.cast<Map<String, dynamic>>();
  }

  String _short(String? id) =>
      (id == null || id.length < 8) ? (id ?? '--') : '…${id.substring(id.length - 6)}';

  // ── Receive ─────────────────────────────────────────────────────────────

  Future<void> _receiveSheet() async {
    final item = await showItemPicker(context);
    if (item == null || !mounted) return;
    final supplier = await showSupplierPicker(context);
    if (supplier == null || !mounted) return;

    String? warehouseId = _warehouses.isNotEmpty
        ? (_warehouses.firstWhere((w) => w['isDefault'] == true,
                orElse: () => _warehouses.first)['id'])
            ?.toString()
        : null;
    final qty = TextEditingController();
    final cost = TextEditingController();
    final ref0 = TextEditingController();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: KSpacing.md,
          right: KSpacing.md,
          top: KSpacing.md,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + KSpacing.md,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Receive consignment', style: KTypography.h3),
              KSpacing.vGapSm,
              Text('${item['sku'] ?? ''} · ${item['name'] ?? ''} — from ${supplier['name'] ?? ''}',
                  style: KTypography.bodySmall
                      .copyWith(color: KColors.textSecondary)),
              KSpacing.vGapMd,
              DropdownButtonFormField<String>(
                initialValue: warehouseId,
                decoration: const InputDecoration(
                  labelText: 'Warehouse',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final w in _warehouses)
                    DropdownMenuItem(
                      value: w['id']?.toString(),
                      child: Text(w['name']?.toString() ?? '--'),
                    ),
                ],
                onChanged: (v) => setSheet(() => warehouseId = v),
              ),
              KSpacing.vGapSm,
              KCompactRow(children: [
                KTextField(
                  label: 'Quantity',
                  controller: qty,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                KTextField(
                  label: 'Unit cost',
                  controller: cost,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ]),
              KSpacing.vGapSm,
              KTextField(label: 'Agreement ref (optional)', controller: ref0),
              KSpacing.vGapMd,
              KButton(
                label: 'Receive',
                icon: Icons.inventory_2_outlined,
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;

    final q = double.tryParse(qty.text.trim());
    final c = double.tryParse(cost.text.trim());
    if (q == null || q <= 0 || c == null || warehouseId == null) {
      _snack('Quantity, unit cost and warehouse are required');
      return;
    }
    await _post(ApiConfig.consignmentReceive, {
      'itemId': item['id'],
      'warehouseId': warehouseId,
      'supplierId': supplier['id'],
      'quantity': q,
      'unitCost': c,
      if (ref0.text.trim().isNotEmpty) 'agreementRef': ref0.text.trim(),
    }, 'Consignment received');
  }

  Future<void> _recordSale(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null) return;
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record sale'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Quantity sold'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Record')),
        ],
      ),
    );
    if (ok != true) return;
    final q = double.tryParse(ctrl.text.trim());
    if (q == null || q <= 0) {
      _snack('Enter a valid quantity');
      return;
    }
    await _post(ApiConfig.consignmentRecordSale, {
      'consignmentStockId': id,
      'quantitySold': q,
    }, 'Sale recorded — settlement drafted');
  }

  Future<void> _post(
      String path, Map<String, dynamic> body, String okMsg) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(apiClientProvider).post(path, data: body);
      messenger.showSnackBar(SnackBar(content: Text(okMsg)));
      await _load();
      if (_settleSupplier != null) await _loadSettlements();
    } on DioException catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(_msg(e) ?? 'Action failed'),
        backgroundColor: KColors.error,
      ));
    }
  }

  // ── Settlements ──────────────────────────────────────────────────────────

  Future<void> _pickSettleSupplier() async {
    final s = await showSupplierPicker(context);
    if (s == null) return;
    setState(() => _settleSupplier = s);
    await _loadSettlements();
  }

  Future<void> _loadSettlements() async {
    final sid = _settleSupplier?['id']?.toString();
    if (sid == null) return;
    setState(() => _settlementsLoading = true);
    try {
      final res = await ref
          .read(apiClientProvider)
          .get(ApiConfig.consignmentUnsettled(sid));
      _settlements = _listOf(res.data);
    } catch (_) {
      _settlements = [];
    } finally {
      if (mounted) setState(() => _settlementsLoading = false);
    }
  }

  Future<void> _settle(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null) return;
    await _post(ApiConfig.consignmentSettle(id), const {},
        'Settlement marked payable');
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Consignment / VMI'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Stock'),
            Tab(text: 'Settlements'),
          ]),
        ),
        body: _loading
            ? const KLoading(message: 'Loading…')
            : _error != null
                ? KErrorView(message: _error!, onRetry: _load)
                : TabBarView(children: [_stockTab(), _settlementsTab()]),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _receiveSheet,
          icon: const Icon(Icons.add),
          label: const Text('Receive'),
        ),
      ),
    );
  }

  Widget _stockTab() {
    if (_stock.isEmpty) {
      return const KEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No consignment stock',
        subtitle: 'Receive stock a supplier owns until it sells.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: KSpacing.pagePadding,
        itemCount: _stock.length,
        separatorBuilder: (_, __) => KSpacing.vGapSm,
        itemBuilder: (_, i) {
          final r = _stock[i];
          final qty = (r['quantity'] as num?)?.toDouble() ?? 0;
          final cost = (r['unitCost'] as num?)?.toDouble() ?? 0;
          final status = (r['status'] ?? 'ACTIVE').toString();
          final supplier =
              _supplierNames[r['supplierId']?.toString()] ?? 'Supplier';
          final warehouse =
              _warehouseNames[r['warehouseId']?.toString()] ?? 'Warehouse';
          return KCard(
            child: Padding(
              padding: const EdgeInsets.all(KSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Item ${_short(r['itemId']?.toString())}',
                            style: KTypography.labelLarge),
                      ),
                      KStatusChip(status: status),
                    ],
                  ),
                  KSpacing.vGapXs,
                  Text('$supplier · $warehouse',
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textSecondary)),
                  if ((r['agreementRef']?.toString() ?? '').isNotEmpty)
                    Text('Ref: ${r['agreementRef']}',
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textHint)),
                  KSpacing.vGapSm,
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${qty.toStringAsFixed(2)} @ ${_money.format(cost)}  =  ${_money.format(qty * cost)}',
                          style: KTypography.bodyMedium,
                        ),
                      ),
                      if (status == 'ACTIVE' && qty > 0)
                        KButton(
                          label: 'Record sale',
                          size: KButtonSize.small,
                          variant: KButtonVariant.outlined,
                          onPressed: () => _recordSale(r),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _settlementsTab() {
    return Column(
      children: [
        Padding(
          padding: KSpacing.pagePadding,
          child: OutlinedButton.icon(
            onPressed: _pickSettleSupplier,
            icon: const Icon(Icons.store_outlined, size: 18),
            label: Text(_settleSupplier == null
                ? 'Pick a supplier'
                : 'Supplier: ${_settleSupplier!['name'] ?? ''}'),
          ),
        ),
        if (_settlementsLoading)
          const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator())
        else if (_settleSupplier == null)
          Expanded(
            child: Center(
              child: Text('Pick a supplier to see unsettled sales',
                  style: KTypography.bodyMedium
                      .copyWith(color: KColors.textHint)),
            ),
          )
        else if (_settlements.isEmpty)
          Expanded(
            child: Center(
              child: Text('No unsettled sales for this supplier',
                  style: KTypography.bodyMedium
                      .copyWith(color: KColors.textHint)),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: KSpacing.pagePadding,
              itemCount: _settlements.length,
              separatorBuilder: (_, __) => KSpacing.vGapSm,
              itemBuilder: (_, i) {
                final s = _settlements[i];
                final amt = (s['totalAmount'] as num?)?.toDouble() ?? 0;
                final qty = (s['quantitySold'] as num?)?.toDouble() ?? 0;
                return KCard(
                  child: Padding(
                    padding: const EdgeInsets.all(KSpacing.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  s['settlementNumber']?.toString() ??
                                      'Settlement',
                                  style: KTypography.labelLarge),
                              Text(
                                  '${qty.toStringAsFixed(2)} sold · ${s['settlementDate'] ?? ''}',
                                  style: KTypography.bodySmall.copyWith(
                                      color: KColors.textSecondary)),
                            ],
                          ),
                        ),
                        Text(_money.format(amt),
                            style: KTypography.labelLarge
                                .copyWith(color: KColors.primary)),
                        KSpacing.hGapSm,
                        KButton(
                          label: 'Settle',
                          size: KButtonSize.small,
                          onPressed: () => _settle(s),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  static String? _msg(DioException e) {
    final body = e.response?.data;
    return body is Map ? body['message'] as String? : null;
  }
}
