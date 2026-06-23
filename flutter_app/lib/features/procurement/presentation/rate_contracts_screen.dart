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
import '../../contacts/presentation/contact_picker_sheet.dart';
import '../../inventory/presentation/item_picker_sheet.dart';

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
                color: KColors.bgApp,
                borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                border: Border.all(color: KColors.divider),
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

/// Per-line state for the rate-contract create dialog.
class _ContractLineDraft {
  Map<String, dynamic>? item;
  final priceCtrl = TextEditingController();
  final moqCtrl = TextEditingController(text: '0');

  String? get itemId => item?['id']?.toString();
  String? get itemName => item?['name']?.toString();
  String? get itemSku => item?['sku']?.toString();

  void dispose() {
    priceCtrl.dispose();
    moqCtrl.dispose();
  }
}

class _CreateContractDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CreateContractDialog> createState() =>
      _CreateContractDialogState();
}

class _CreateContractDialogState extends ConsumerState<_CreateContractDialog> {
  Map<String, dynamic>? _supplier;
  final List<_ContractLineDraft> _lines = [_ContractLineDraft()];
  DateTime? _validFrom;
  DateTime? _validUntil;
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _pickSupplier() async {
    final picked = await showContactPicker(
      context,
      contactType: 'VENDOR',
      showQuickCreate: true,
      title: 'Select supplier (VENDOR / BOTH)',
    );
    if (picked != null) setState(() => _supplier = picked);
  }

  Future<void> _pickItemForLine(_ContractLineDraft line) async {
    final picked = await showItemPicker(context);
    if (picked == null) return;
    setState(() {
      line.item = picked;
      // Pre-fill with the item's purchase price if available — planner
      // can override before saving.
      final pp = (picked['purchasePrice'] as num?)?.toString();
      if (pp != null && line.priceCtrl.text.trim().isEmpty) {
        line.priceCtrl.text = pp;
      }
    });
  }

  void _addLine() {
    setState(() => _lines.add(_ContractLineDraft()));
  }

  void _removeLine(int index) {
    if (_lines.length <= 1) return;
    setState(() {
      _lines[index].dispose();
      _lines.removeAt(index);
    });
  }

  Future<void> _submit() async {
    final supplierId = _supplier?['id']?.toString();
    if (supplierId == null) {
      setState(() => _err = 'Pick a supplier');
      return;
    }
    final lineBodies = <Map<String, dynamic>>[];
    for (final line in _lines) {
      final itemId = line.itemId;
      final price = num.tryParse(line.priceCtrl.text.trim());
      if (itemId == null) {
        setState(() => _err = 'Pick an item for every line');
        return;
      }
      if (price == null || price <= 0) {
        setState(() => _err = 'Every line needs a unit price > 0');
        return;
      }
      lineBodies.add({
        'itemId': itemId,
        'unitPrice': price,
        'minOrderQty': num.tryParse(line.moqCtrl.text.trim()) ?? 0,
      });
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final dio = ref.read(apiClientProvider).dio;
      final body = {
        'supplierContactId': supplierId,
        if (_validFrom != null)
          'validFrom':
              '${_validFrom!.year}-${_validFrom!.month.toString().padLeft(2, '0')}-${_validFrom!.day.toString().padLeft(2, '0')}',
        if (_validUntil != null)
          'validUntil':
              '${_validUntil!.year}-${_validUntil!.month.toString().padLeft(2, '0')}-${_validUntil!.day.toString().padLeft(2, '0')}',
        'lines': lineBodies,
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
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ContractPickerRow(
                label: 'Supplier',
                value: _supplier?['displayName']?.toString() ??
                    _supplier?['name']?.toString(),
                placeholder: 'Pick a supplier (VENDOR / BOTH)',
                icon: Icons.local_shipping_outlined,
                onPick: _pickSupplier,
              ),
              const SizedBox(height: KSpacing.sm),
              Row(children: [
                Expanded(
                    child: Text(
                        _validFrom == null
                            ? 'Valid from: today'
                            : 'Valid from ${_validFrom!.toLocal().toString().substring(0, 10)}',
                        style: KTypography.bodySmall)),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 30)),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 3)),
                    );
                    if (picked != null) setState(() => _validFrom = picked);
                  },
                  child: const Text('Pick from'),
                ),
              ]),
              Row(children: [
                Expanded(
                    child: Text(
                        _validUntil == null
                            ? 'Valid until: open'
                            : 'Valid until ${_validUntil!.toLocal().toString().substring(0, 10)}',
                        style: KTypography.bodySmall)),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          DateTime.now().add(const Duration(days: 365)),
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (picked != null) setState(() => _validUntil = picked);
                  },
                  child: const Text('Pick until'),
                ),
              ]),
              const Divider(),
              Text('Items & rates',
                  style: KTypography.bodySmall
                      .copyWith(color: KColors.textSecondary)),
              const SizedBox(height: KSpacing.xs),
              ..._lines.asMap().entries.map(
                    (entry) => _ContractLineEditor(
                      index: entry.key,
                      line: entry.value,
                      canRemove: _lines.length > 1,
                      onPickItem: () => _pickItemForLine(entry.value),
                      onRemove: () => _removeLine(entry.key),
                    ),
                  ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addLine,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add line'),
                ),
              ),
              if (_err != null) ...[
                const SizedBox(height: KSpacing.sm),
                Text(_err!,
                    style: KTypography.bodySmall
                        .copyWith(color: KColors.error)),
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
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Create draft')),
      ],
    );
  }
}

class _ContractLineEditor extends StatelessWidget {
  final int index;
  final _ContractLineDraft line;
  final bool canRemove;
  final VoidCallback onPickItem;
  final VoidCallback onRemove;

  const _ContractLineEditor({
    required this.index,
    required this.line,
    required this.canRemove,
    required this.onPickItem,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final picked = line.itemId != null;
    return Container(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      padding: const EdgeInsets.all(KSpacing.sm),
      decoration: BoxDecoration(
        color: KColors.bgApp,
        borderRadius: BorderRadius.circular(KSpacing.radiusSm),
        border: Border.all(color: KColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Line ${index + 1}',
                  style: KTypography.labelMedium),
              const Spacer(),
              TextButton.icon(
                onPressed: onPickItem,
                icon: const Icon(Icons.search, size: 14),
                label: Text(picked ? 'Change item' : 'Pick item'),
              ),
              if (canRemove)
                IconButton(
                  iconSize: 18,
                  icon: const Icon(Icons.close, color: KColors.error),
                  onPressed: onRemove,
                ),
            ],
          ),
          if (picked)
            Padding(
              padding: const EdgeInsets.only(bottom: KSpacing.xs),
              child: Text(
                '${line.itemName ?? ''}'
                '${line.itemSku != null ? ' · ${line.itemSku}' : ''}',
                style: KTypography.bodySmall
                    .copyWith(color: KColors.textSecondary),
              ),
            ),
          TextField(
            controller: line.priceCtrl,
            decoration: const InputDecoration(labelText: 'Unit price (₹)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          TextField(
            controller: line.moqCtrl,
            decoration:
                const InputDecoration(labelText: 'Minimum order quantity'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ),
    );
  }
}

/// Same compact picker row used by RFQ — kept private here so the
/// rate-contract screen doesn't depend on the RFQ file. If a third
/// screen needs the same shape we'll promote it to a shared widget.
class _ContractPickerRow extends StatelessWidget {
  final String label;
  final String? value;
  final String placeholder;
  final IconData icon;
  final VoidCallback onPick;

  const _ContractPickerRow({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.icon,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final picked = value != null && value!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.sm, vertical: KSpacing.xs),
      decoration: BoxDecoration(
        color: KColors.bgApp,
        borderRadius: BorderRadius.circular(KSpacing.radiusSm),
        border: Border.all(color: KColors.divider),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: KColors.textSecondary),
          const SizedBox(width: KSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: KTypography.bodySmall
                        .copyWith(color: KColors.textSecondary)),
                Text(
                  picked ? value! : placeholder,
                  style: picked
                      ? KTypography.bodyMedium
                      : KTypography.bodyMedium
                          .copyWith(color: KColors.textHint),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.search, size: 14),
            label: Text(picked ? 'Change' : 'Pick'),
          ),
        ],
      ),
    );
  }
}
