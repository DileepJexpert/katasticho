import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/k_money.dart';
import '../../../core/widgets/k_status_chip.dart';

/// Supplier rate contracts — negotiated unit prices per (supplier, item).
/// When a PO is drafted, the line's unit price defaults to the active
/// contract rate if the planner leaves it blank.
class RateContractsScreen extends ConsumerStatefulWidget {
  const RateContractsScreen({super.key});

  @override
  ConsumerState<RateContractsScreen> createState() => _RateContractsScreenState();
}

class _RateContractsScreenState extends ConsumerState<RateContractsScreen> {
  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;
  String? _err;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final dio = ref.read(apiClientProvider).dio;
      final resp = await dio.get(ApiConfig.procurementRateContracts,
          queryParameters: {'page': 0, 'size': 50});
      final content = (resp.data['data']?['content'] as List?) ?? const [];
      setState(() {
        _rows = content
            .whereType<Map>()
            .map((m) => m.cast<String, dynamic>())
            .toList();
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _err = ApiErrorParser.parse(e);
        _loading = false;
      });
    }
  }

  Future<void> _action(String id, String op) async {
    try {
      final dio = ref.read(apiClientProvider).dio;
      await dio.post(switch (op) {
        'activate' => ApiConfig.procurementRateContractActivate(id),
        'expire' => ApiConfig.procurementRateContractExpire(id),
        'cancel' => ApiConfig.procurementRateContractCancel(id),
        _ => throw StateError('unknown op $op'),
      });
      _refresh();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$op failed: ${ApiErrorParser.parse(e)}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier rate contracts'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(KSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(KSpacing.md),
              decoration: BoxDecoration(
                color: KColors.surfaceMuted,
                borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                border: Border.all(color: KColors.border),
              ),
              child: Text(
                'Negotiated unit prices per (supplier, item). When a PO line\'s '
                'price is left blank, the active contract rate auto-fills it.',
                style: KTypography.bodySmall
                    .copyWith(color: KColors.textSecondary),
              ),
            ),
            const SizedBox(height: KSpacing.md),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _err != null
                      ? Center(
                          child: Text('Failed: $_err',
                              style: KTypography.bodySmall
                                  .copyWith(color: KColors.error)))
                      : _rows.isEmpty
                          ? Center(
                              child: Text(
                                  'No contracts yet — tap "New contract" to draft one.',
                                  style: KTypography.body.copyWith(
                                      color: KColors.textSecondary)),
                            )
                          : ListView.separated(
                              itemBuilder: (_, i) {
                                final row = _rows[i];
                                final status =
                                    row['status']?.toString() ?? 'DRAFT';
                                final lines = (row['lines'] as List?) ?? const [];
                                return ListTile(
                                  title: Row(
                                    children: [
                                      Text(row['contractNumber']?.toString() ?? '',
                                          style: KTypography.mono(
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(width: KSpacing.md),
                                      KStatusChip(status: status),
                                    ],
                                  ),
                                  subtitle: Text(
                                    '${lines.length} line${lines.length == 1 ? '' : 's'} · '
                                    'Valid ${row['validFrom'] ?? '—'} → ${row['validUntil'] ?? 'open'}',
                                    style: KTypography.bodySmall,
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (op) =>
                                        _action(row['id'].toString(), op),
                                    itemBuilder: (_) => [
                                      if (status == 'DRAFT')
                                        const PopupMenuItem(
                                            value: 'activate',
                                            child: Text('Activate')),
                                      if (status == 'ACTIVE')
                                        const PopupMenuItem(
                                            value: 'expire',
                                            child: Text('Expire')),
                                      if (status == 'DRAFT' ||
                                          status == 'ACTIVE')
                                        const PopupMenuItem(
                                            value: 'cancel',
                                            child: Text('Cancel')),
                                    ],
                                  ),
                                  onTap: () => _showLines(row),
                                );
                              },
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemCount: _rows.length,
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreate,
        icon: const Icon(Icons.add),
        label: const Text('New contract'),
      ),
    );
  }

  Future<void> _showCreate() async {
    final ok = await showDialog<bool>(
        context: context, builder: (_) => _CreateContractDialog());
    if (ok == true) _refresh();
  }

  Future<void> _showLines(Map<String, dynamic> row) async {
    final lines = (row['lines'] as List?) ?? const [];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(KSpacing.md),
        child: SizedBox(
          height: 460,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row['contractNumber']?.toString() ?? '',
                  style: KTypography.h3.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: KSpacing.sm),
              Text('Lines (${lines.length})', style: KTypography.bodySmall),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: lines.length,
                  itemBuilder: (_, i) {
                    final l = (lines[i] as Map).cast<String, dynamic>();
                    return ListTile(
                      dense: true,
                      title: Text(l['itemId']?.toString() ?? '',
                          style: KTypography.mono()),
                      trailing: KMoney(_n(l['unitPrice'])),
                      subtitle: Text('MOQ: ${l['minOrderQty'] ?? 0}'),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  num _n(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }
}

class _CreateContractDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CreateContractDialog> createState() =>
      _CreateContractDialogState();
}

class _CreateContractDialogState extends ConsumerState<_CreateContractDialog> {
  final _supplierCtrl = TextEditingController();
  final _itemIdCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _moqCtrl = TextEditingController(text: '0');
  DateTime? _validFrom;
  DateTime? _validUntil;
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _supplierCtrl.dispose();
    _itemIdCtrl.dispose();
    _priceCtrl.dispose();
    _moqCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final supplier = _supplierCtrl.text.trim();
    final itemId = _itemIdCtrl.text.trim();
    final price = num.tryParse(_priceCtrl.text.trim());
    if (supplier.isEmpty || itemId.isEmpty || price == null) {
      setState(() => _err = 'Supplier, item id, and price required');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final dio = ref.read(apiClientProvider).dio;
      final body = {
        'supplierContactId': supplier,
        if (_validFrom != null)
          'validFrom':
              '${_validFrom!.year}-${_validFrom!.month.toString().padLeft(2, '0')}-${_validFrom!.day.toString().padLeft(2, '0')}',
        if (_validUntil != null)
          'validUntil':
              '${_validUntil!.year}-${_validUntil!.month.toString().padLeft(2, '0')}-${_validUntil!.day.toString().padLeft(2, '0')}',
        'lines': [
          {
            'itemId': itemId,
            'unitPrice': price,
            'minOrderQty': num.tryParse(_moqCtrl.text.trim()) ?? 0,
          }
        ],
      };
      await dio.post(ApiConfig.procurementRateContracts, data: body);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      setState(() {
        _err = ApiErrorParser.parse(e);
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New supplier rate contract'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                  controller: _supplierCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Supplier contact id (UUID, VENDOR/BOTH)')),
              Row(children: [
                Expanded(child: Text(_validFrom == null
                    ? 'Valid from: today'
                    : 'Valid from ${_validFrom!.toLocal().toString().substring(0, 10)}',
                    style: KTypography.bodySmall)),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                    );
                    if (picked != null) setState(() => _validFrom = picked);
                  },
                  child: const Text('Pick from'),
                ),
              ]),
              Row(children: [
                Expanded(child: Text(_validUntil == null
                    ? 'Valid until: open'
                    : 'Valid until ${_validUntil!.toLocal().toString().substring(0, 10)}',
                    style: KTypography.bodySmall)),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 365)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (picked != null) setState(() => _validUntil = picked);
                  },
                  child: const Text('Pick until'),
                ),
              ]),
              const Divider(),
              Text('First line', style: KTypography.bodySmall.copyWith(
                  color: KColors.textSecondary)),
              TextField(
                  controller: _itemIdCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Item id (UUID)')),
              TextField(
                  controller: _priceCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Unit price (₹)'),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: _moqCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Minimum order quantity'),
                  keyboardType: TextInputType.number),
              if (_err != null) ...[
                const SizedBox(height: KSpacing.sm),
                Text(_err!,
                    style: KTypography.bodySmall.copyWith(color: KColors.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Create draft')),
      ],
    );
  }
}
