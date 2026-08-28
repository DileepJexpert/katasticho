import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_money.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../../../core/widgets/k_text_field.dart';
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
        _err = ApiErrorParser.message(e);
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
          SnackBar(content: Text('$op failed: ${ApiErrorParser.message(e)}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier Rate Contracts'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
          Padding(
            padding: const EdgeInsets.only(right: KSpacing.md),
            child: KButton.primary(
              size: KButtonSize.small,
              icon: Icons.add,
              label: 'New Contract',
              onPressed: _showCreate,
            ),
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
                color: KColors.primarySoft,
                borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                border: Border.all(color: KColors.divider),
              ),
              child: Row(
                children: [
                  Icon(Icons.handshake_outlined, size: 20, color: KColors.primary),
                  KSpacing.hGapSm,
                  Expanded(
                    child: Text(
                      'Negotiated vendor pricing: long-term locked purchase rates per (supplier, item). When creating a PO, contract rates auto-apply.',
                      style: KTypography.bodySmall.copyWith(color: KColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            KSpacing.vGapMd,
            Expanded(
              child: _loading
                  ? const Center(child: KLoading())
                  : _err != null
                      ? Center(
                          child: Text('Failed: $_err',
                              style: KTypography.bodySmall
                                  .copyWith(color: KColors.error)))
                      : _rows.isEmpty
                          ? Center(
                              child: KEmptyState(
                                icon: Icons.handshake_outlined,
                                title: 'No Rate Contracts',
                                subtitle: 'Lock in negotiated unit prices with your key suppliers.',
                                actionLabel: 'Draft First Contract',
                                onAction: _showCreate,
                              ),
                            )
                          : ListView.separated(
                              itemBuilder: (_, i) {
                                final row = _rows[i];
                                final status =
                                    row['status']?.toString() ?? 'DRAFT';
                                final lines = (row['lines'] as List?) ?? const [];
                                return KCard(
                                  onTap: () => _showLines(row),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: KColors.primarySoft,
                                          borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                                        ),
                                        alignment: Alignment.center,
                                        child: Icon(Icons.handshake_outlined, color: KColors.primary, size: 20),
                                      ),
                                      KSpacing.hGapMd,
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  row['contractNumber']?.toString() ?? '',
                                                  style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w700),
                                                ),
                                                KSpacing.hGapSm,
                                                KStatusChip(status: status),
                                              ],
                                            ),
                                            KSpacing.vGapXs,
                                            Row(
                                              children: [
                                                Text(
                                                  '${lines.length} Item Rate${lines.length == 1 ? '' : 's'}',
                                                  style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w600),
                                                ),
                                                Text('  ·  ', style: KTypography.caption),
                                                Icon(Icons.calendar_today_outlined, size: 12, color: KColors.textHint),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Valid: ${row['validFrom'] ?? '—'} → ${row['validUntil'] ?? 'Open'}',
                                                  style: KTypography.mono(fontSize: 11),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        icon: Icon(Icons.more_vert, color: KColors.textHint),
                                        onSelected: (op) =>
                                            _action(row['id'].toString(), op),
                                        itemBuilder: (_) => [
                                          if (status == 'DRAFT')
                                            const PopupMenuItem(
                                                value: 'activate',
                                                child: Text('Activate Contract')),
                                          if (status == 'ACTIVE')
                                            const PopupMenuItem(
                                                value: 'expire',
                                                child: Text('Mark as Expired')),
                                          if (status == 'DRAFT' ||
                                              status == 'ACTIVE')
                                            const PopupMenuItem(
                                                value: 'cancel',
                                                child: Text('Cancel Contract')),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                              separatorBuilder: (_, __) => KSpacing.vGapSm,
                              itemCount: _rows.length,
                            ),
            ),
          ],
        ),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(KSpacing.radiusLg)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(KSpacing.md),
        child: SizedBox(
          height: 480,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(row['contractNumber']?.toString() ?? '',
                      style: KTypography.mono(fontSize: 18, fontWeight: FontWeight.w700)),
                  KSpacing.hGapSm,
                  KStatusChip(status: row['status']?.toString() ?? 'DRAFT'),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              KSpacing.vGapXs,
              Text('Contracted Items & Rates (${lines.length})', style: KTypography.bodySmall),
              KSpacing.vGapSm,
              const Divider(),
              KSpacing.vGapSm,
              Expanded(
                child: ListView.separated(
                  itemCount: lines.length,
                  separatorBuilder: (_, __) => KSpacing.vGapSm,
                  itemBuilder: (_, i) {
                    final l = (lines[i] as Map).cast<String, dynamic>();
                    return KCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l['itemId']?.toString() ?? 'Item',
                                  style: KTypography.mono(fontWeight: FontWeight.w600),
                                ),
                                KSpacing.vGapXs,
                                Text(
                                  'Minimum Order Qty (MOQ): ${l['minOrderQty'] ?? 0}',
                                  style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Contract Rate', style: KTypography.caption),
                              KSpacing.vGapXs,
                              KMoney(_n(l['unitPrice'])),
                            ],
                          ),
                        ],
                      ),
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
      title: 'Select Supplier',
    );
    if (picked != null) setState(() => _supplier = picked);
  }

  Future<void> _pickItemForLine(_ContractLineDraft line) async {
    final picked = await showItemPicker(context);
    if (picked == null) return;
    setState(() {
      line.item = picked;
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
        _err = ApiErrorParser.message(e);
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KSpacing.radiusLg)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.lg),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('New Supplier Rate Contract', style: KTypography.titleLarge),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                KSpacing.vGapMd,
                _ContractPickerRow(
                  label: 'Supplier',
                  value: _supplier?['displayName']?.toString() ??
                      _supplier?['name']?.toString(),
                  placeholder: 'Select supplier for price agreement',
                  icon: Icons.local_shipping_outlined,
                  onPick: _pickSupplier,
                ),
                KSpacing.vGapSm,
                Row(
                  children: [
                    Expanded(
                      child: KCard(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                          );
                          if (picked != null) setState(() => _validFrom = picked);
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Valid From', style: KTypography.caption),
                            KSpacing.vGapXs,
                            Text(
                              _validFrom == null
                                  ? 'Today'
                                  : _validFrom!.toLocal().toString().substring(0, 10),
                              style: KTypography.mono(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    KSpacing.hGapSm,
                    Expanded(
                      child: KCard(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(const Duration(days: 365)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                          );
                          if (picked != null) setState(() => _validUntil = picked);
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Valid Until', style: KTypography.caption),
                            KSpacing.vGapXs,
                            Text(
                              _validUntil == null
                                  ? 'Open / No Expiry'
                                  : _validUntil!.toLocal().toString().substring(0, 10),
                              style: KTypography.mono(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                KSpacing.vGapMd,
                Row(
                  children: [
                    Text('Contracted Items & Rates', style: KTypography.titleSmall),
                    const Spacer(),
                    KButton.outlined(
                      size: KButtonSize.small,
                      icon: Icons.add,
                      label: 'Add Line',
                      onPressed: _addLine,
                    ),
                  ],
                ),
                KSpacing.vGapSm,
                ..._lines.asMap().entries.map(
                      (entry) => _ContractLineEditor(
                        index: entry.key,
                        line: entry.value,
                        canRemove: _lines.length > 1,
                        onPickItem: () => _pickItemForLine(entry.value),
                        onRemove: () => _removeLine(entry.key),
                      ),
                    ),
                if (_err != null) ...[
                  KSpacing.vGapSm,
                  Text(_err!,
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.error)),
                ],
                KSpacing.vGapLg,
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    KButton.outlined(
                      label: 'Cancel',
                      onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                    ),
                    KSpacing.hGapSm,
                    KButton.primary(
                      label: 'Save Contract',
                      isLoading: _busy,
                      onPressed: _busy ? null : _submit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Contract Item #${index + 1}', style: KTypography.labelMedium),
              const Spacer(),
              KButton.outlined(
                size: KButtonSize.small,
                icon: Icons.search,
                label: picked ? 'Change Item' : 'Pick Item',
                onPressed: onPickItem,
              ),
              if (canRemove) ...[
                KSpacing.hGapSm,
                IconButton(
                  iconSize: 18,
                  icon: const Icon(Icons.delete_outline, color: KColors.error),
                  onPressed: onRemove,
                ),
              ],
            ],
          ),
          if (picked) ...[
            KSpacing.vGapXs,
            Text(
              '${line.itemName ?? ''}'
              '${line.itemSku != null ? ' · SKU: ${line.itemSku}' : ''}',
              style: KTypography.mono(fontSize: 11, color: KColors.primary),
            ),
          ],
          KSpacing.vGapSm,
          Row(
            children: [
              Expanded(
                child: KTextField.amount(
                  controller: line.priceCtrl,
                  label: 'Agreed Unit Price *',
                ),
              ),
              KSpacing.hGapSm,
              Expanded(
                child: KTextField(
                  controller: line.moqCtrl,
                  label: 'Min Order Qty (MOQ)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
    return KCard(
      onTap: onPick,
      child: Row(
        children: [
          Icon(icon, size: 20, color: KColors.primary),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: KTypography.caption),
                KSpacing.vGapXs,
                Text(
                  picked ? value! : placeholder,
                  style: picked
                      ? KTypography.labelMedium
                      : KTypography.bodyMedium.copyWith(color: KColors.textHint),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          KSpacing.hGapSm,
          KButton.outlined(
            size: KButtonSize.small,
            label: picked ? 'Change' : 'Select',
            onPressed: onPick,
          ),
        ],
      ),
    );
  }
}
