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

/// RFQ → supplier quotation compare → award → PO.
///
/// List of RFQs at the top, "New RFQ" FAB drafts a header + first line +
/// chosen suppliers in one shot. Tap a row to see all returned quotes side by
/// side with a per-row "Award" button. Award drafts a real PO carrying the
/// winning supplier and prices.
class RfqScreen extends ConsumerStatefulWidget {
  const RfqScreen({super.key});

  @override
  ConsumerState<RfqScreen> createState() => _RfqScreenState();
}

class _RfqScreenState extends ConsumerState<RfqScreen> {
  List<Map<String, dynamic>> _rfqs = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = ref.read(apiClientProvider).dio;
      final resp = await dio.get(ApiConfig.procurementRfqList,
          queryParameters: {'page': 0, 'size': 50});
      final content = (resp.data['data']?['content'] as List?) ?? const [];
      setState(() {
        _rfqs = content
            .whereType<Map>()
            .map((m) => m.cast<String, dynamic>())
            .toList();
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = ApiErrorParser.parse(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request for Quotations (RFQ)'),
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
                'Shop around: draft an RFQ, record each supplier\'s quote, '
                'compare, and award the winner — the system drafts the PO.',
                style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
              ),
            ),
            const SizedBox(height: KSpacing.md),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text(
                            'Failed to load: $_error',
                            style: KTypography.bodySmall
                                .copyWith(color: KColors.error),
                          ),
                        )
                      : _rfqs.isEmpty
                          ? Center(
                              child: Text(
                                'No RFQs yet — tap "New RFQ" to draft one.',
                                style: KTypography.body.copyWith(
                                    color: KColors.textSecondary),
                              ),
                            )
                          : ListView.separated(
                              itemBuilder: (_, i) => _RfqTile(
                                rfq: _rfqs[i],
                                onChanged: _refresh,
                              ),
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemCount: _rfqs.length,
                            ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('New RFQ'),
      ),
    );
  }

  Future<void> _showCreateDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateRfqDialog(),
    );
    if (result == true) _refresh();
  }
}

class _RfqTile extends ConsumerWidget {
  final Map<String, dynamic> rfq;
  final VoidCallback onChanged;

  const _RfqTile({required this.rfq, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = rfq['status']?.toString() ?? 'DRAFT';
    final lines = (rfq['lines'] as List?) ?? const [];
    final suppliers = (rfq['supplierContactIds'] as List?) ?? const [];
    return ListTile(
      title: Row(
        children: [
          Text(rfq['rfqNumber']?.toString() ?? '',
              style: KTypography.mono(fontWeight: FontWeight.w600)),
          const SizedBox(width: KSpacing.md),
          Expanded(child: Text(rfq['title']?.toString() ?? '')),
          KStatusChip(status: status),
        ],
      ),
      subtitle: Text(
        '${lines.length} line${lines.length == 1 ? '' : 's'} · '
        '${suppliers.length} supplier${suppliers.length == 1 ? '' : 's'} · '
        'Due ${rfq['dueDate'] ?? '—'}',
        style: KTypography.bodySmall,
      ),
      onTap: () => _showRfqDetail(context, ref, rfq, onChanged),
    );
  }
}

Future<void> _showRfqDetail(BuildContext context, WidgetRef ref,
    Map<String, dynamic> rfq, VoidCallback onChanged) async {
  final dio = ref.read(apiClientProvider).dio;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scroll) => _RfqDetailSheet(
        rfqId: rfq['id'].toString(),
        rfqNumber: rfq['rfqNumber']?.toString() ?? '',
        status: rfq['status']?.toString() ?? 'DRAFT',
        dio: dio,
        scrollController: scroll,
        onChanged: onChanged,
      ),
    ),
  );
}

class _RfqDetailSheet extends StatefulWidget {
  final String rfqId;
  final String rfqNumber;
  final String status;
  final Dio dio;
  final ScrollController scrollController;
  final VoidCallback onChanged;

  const _RfqDetailSheet({
    required this.rfqId,
    required this.rfqNumber,
    required this.status,
    required this.dio,
    required this.scrollController,
    required this.onChanged,
  });

  @override
  State<_RfqDetailSheet> createState() => _RfqDetailSheetState();
}

class _RfqDetailSheetState extends State<_RfqDetailSheet> {
  List<Map<String, dynamic>> _quotes = const [];
  bool _loading = true;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final resp =
          await widget.dio.get(ApiConfig.procurementRfqQuotes(widget.rfqId));
      final list = (resp.data['data'] as List?) ?? const [];
      setState(() {
        _quotes = list
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

  Future<void> _award(String quoteId) async {
    try {
      await widget.dio.post(ApiConfig.procurementRfqAward(widget.rfqId),
          data: {'winningQuoteId': quoteId});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('RFQ awarded; PO drafted')));
      widget.onChanged();
      Navigator.of(context).pop();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Award failed: ${ApiErrorParser.parse(e)}')));
    }
  }

  Future<void> _addQuote() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _RecordQuoteDialog(rfqId: widget.rfqId, dio: widget.dio),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(KSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(widget.rfqNumber,
                  style: KTypography.h3.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: KSpacing.md),
              KStatusChip(status: widget.status),
              const Spacer(),
              if (widget.status == 'DRAFT' || widget.status == 'SENT')
                TextButton.icon(
                  onPressed: _addQuote,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Record quote'),
                ),
            ],
          ),
          const Divider(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _err != null
                    ? Center(
                        child: Text('Failed: $_err',
                            style: KTypography.bodySmall
                                .copyWith(color: KColors.error)))
                    : _quotes.isEmpty
                        ? Center(
                            child: Text(
                                'No quotes yet — tap "Record quote" once a supplier replies.',
                                style: KTypography.body.copyWith(
                                    color: KColors.textSecondary)),
                          )
                        : ListView.builder(
                            controller: widget.scrollController,
                            itemCount: _quotes.length,
                            itemBuilder: (_, i) {
                              final q = _quotes[i];
                              final qStatus = q['status']?.toString() ?? 'RECEIVED';
                              return Card(
                                margin: const EdgeInsets.only(
                                    bottom: KSpacing.sm),
                                child: ListTile(
                                  title: Row(
                                    children: [
                                      Text(q['quoteNumber']?.toString() ?? '',
                                          style: KTypography.mono()),
                                      const SizedBox(width: KSpacing.sm),
                                      KStatusChip(status: qStatus),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        const Text('Total: '),
                                        KMoney(_toBig(q['totalAmount'])),
                                        const SizedBox(width: KSpacing.md),
                                        Text(
                                            'Valid until ${q['validUntil'] ?? '—'}',
                                            style: KTypography.bodySmall),
                                      ],
                                    ),
                                  ),
                                  trailing: (widget.status != 'AWARDED' &&
                                          widget.status != 'CANCELLED' &&
                                          qStatus == 'RECEIVED')
                                      ? FilledButton(
                                          onPressed: () =>
                                              _award(q['id'].toString()),
                                          child: const Text('Award'),
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  num _toBig(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }
}

/// Per-line state. Each line carries the picked item (id, name, hsn, gst
/// pulled from the item master) plus an editable description + quantity.
class _RfqLineDraft {
  String? itemId;
  String? itemName;
  String? sku;
  String? hsnCode;
  num? gstRate;
  final descriptionCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '1');

  void dispose() {
    descriptionCtrl.dispose();
    qtyCtrl.dispose();
  }
}

class _CreateRfqDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CreateRfqDialog> createState() => _CreateRfqDialogState();
}

class _CreateRfqDialogState extends ConsumerState<_CreateRfqDialog> {
  final _titleCtrl = TextEditingController();
  final List<_RfqLineDraft> _lines = [_RfqLineDraft()];
  // Picked vendor contacts: list of {id, displayName, gstin, ...}.
  final List<Map<String, dynamic>> _suppliers = [];
  DateTime? _dueDate;
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _titleCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _pickItemForLine(_RfqLineDraft line) async {
    final picked = await showItemPicker(context);
    if (picked == null) return;
    setState(() {
      line.itemId = picked['id']?.toString();
      line.itemName = picked['name']?.toString();
      line.sku = picked['sku']?.toString();
      line.hsnCode = picked['hsnCode']?.toString();
      line.gstRate = (picked['gstRate'] as num?);
      // Auto-fill description with the item name (user can override).
      if (line.descriptionCtrl.text.trim().isEmpty) {
        line.descriptionCtrl.text = picked['name']?.toString() ?? '';
      }
    });
  }

  Future<void> _addSupplier() async {
    final picked = await showContactPicker(
      context,
      contactType: 'VENDOR',
      showQuickCreate: true,
      title: 'Add supplier (VENDOR / BOTH)',
    );
    if (picked == null) return;
    final id = picked['id']?.toString();
    if (id == null) return;
    if (_suppliers.any((s) => s['id']?.toString() == id)) return;
    setState(() => _suppliers.add(picked));
  }

  void _removeSupplier(String id) {
    setState(() => _suppliers.removeWhere((s) => s['id']?.toString() == id));
  }

  void _addLine() {
    setState(() => _lines.add(_RfqLineDraft()));
  }

  void _removeLine(int index) {
    if (_lines.length <= 1) return;
    setState(() {
      _lines[index].dispose();
      _lines.removeAt(index);
    });
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _err = 'Title is required');
      return;
    }
    if (_suppliers.isEmpty) {
      setState(() => _err = 'Pick at least one supplier');
      return;
    }
    final lineBodies = <Map<String, dynamic>>[];
    for (final line in _lines) {
      final qty = num.tryParse(line.qtyCtrl.text.trim());
      if (qty == null || qty <= 0) {
        setState(() => _err = 'Every line needs a quantity > 0');
        return;
      }
      lineBodies.add({
        if (line.itemId != null) 'itemId': line.itemId,
        'description': line.descriptionCtrl.text.trim(),
        'quantity': qty,
        if (line.hsnCode != null && line.hsnCode!.isNotEmpty)
          'hsnCode': line.hsnCode,
        if (line.gstRate != null) 'gstRate': line.gstRate,
      });
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final dio = ref.read(apiClientProvider).dio;
      final body = {
        'title': title,
        if (_dueDate != null)
          'dueDate':
              '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}',
        'lines': lineBodies,
        'supplierContactIds':
            _suppliers.map((s) => s['id']?.toString()).whereType<String>().toList(),
      };
      await dio.post(ApiConfig.procurementRfqList, data: body);
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
      title: const Text('New RFQ'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Title (e.g. Cement Q3)'),
              ),
              const SizedBox(height: KSpacing.sm),
              Row(
                children: [
                  Expanded(
                      child: Text(
                          _dueDate == null
                              ? 'No due date'
                              : 'Due ${_dueDate!.toLocal().toString().substring(0, 10)}',
                          style: KTypography.bodySmall)),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: const Text('Pick'),
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: now,
                        firstDate: now.subtract(const Duration(days: 1)),
                        lastDate: now.add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _dueDate = picked);
                    },
                  ),
                ],
              ),
              const Divider(),
              Text('Items',
                  style: KTypography.bodySmall
                      .copyWith(color: KColors.textSecondary)),
              const SizedBox(height: KSpacing.xs),
              ..._lines.asMap().entries.map(
                    (entry) => _RfqLineEditor(
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
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _suppliers.isEmpty
                          ? 'Suppliers — none yet'
                          : 'Suppliers (${_suppliers.length})',
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textSecondary),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addSupplier,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add supplier'),
                  ),
                ],
              ),
              const SizedBox(height: KSpacing.xs),
              if (_suppliers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: KSpacing.xs),
                  child: Text(
                    'Pick at least one VENDOR (or BOTH) contact to invite.',
                    style: KTypography.bodySmall
                        .copyWith(color: KColors.textHint),
                  ),
                )
              else
                Wrap(
                  spacing: KSpacing.xs,
                  runSpacing: KSpacing.xs,
                  children: _suppliers
                      .map((s) => InputChip(
                            label: Text(
                              s['displayName']?.toString() ??
                                  s['name']?.toString() ??
                                  'Vendor',
                            ),
                            avatar: const Icon(Icons.local_shipping_outlined,
                                size: 14),
                            onDeleted: () =>
                                _removeSupplier(s['id']?.toString() ?? ''),
                          ))
                      .toList(),
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
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Create'),
        ),
      ],
    );
  }
}

class _RfqLineEditor extends StatelessWidget {
  final int index;
  final _RfqLineDraft line;
  final bool canRemove;
  final VoidCallback onPickItem;
  final VoidCallback onRemove;

  const _RfqLineEditor({
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
                '${line.itemName ?? ''} '
                '${line.sku != null ? '· ${line.sku}' : ''}'
                '${line.hsnCode != null ? ' · HSN ${line.hsnCode}' : ''}'
                '${line.gstRate != null ? ' · ${line.gstRate}% GST' : ''}',
                style: KTypography.bodySmall
                    .copyWith(color: KColors.textSecondary),
              ),
            ),
          TextField(
            controller: line.descriptionCtrl,
            decoration: const InputDecoration(
              labelText: 'Description (free-text — sent to suppliers)',
            ),
          ),
          TextField(
            controller: line.qtyCtrl,
            decoration: const InputDecoration(labelText: 'Quantity'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ),
    );
  }
}

class _RecordQuoteDialog extends StatefulWidget {
  final String rfqId;
  final Dio dio;

  const _RecordQuoteDialog({required this.rfqId, required this.dio});

  @override
  State<_RecordQuoteDialog> createState() => _RecordQuoteDialogState();
}

class _RecordQuoteDialogState extends State<_RecordQuoteDialog> {
  Map<String, dynamic>? _supplier;
  Map<String, dynamic>? _item;
  final _quoteNumCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();
  final _leadCtrl = TextEditingController();
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _quoteNumCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _leadCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickSupplier() async {
    final picked = await showContactPicker(
      context,
      contactType: 'VENDOR',
      title: 'Select supplier',
    );
    if (picked != null) setState(() => _supplier = picked);
  }

  Future<void> _pickItem() async {
    final picked = await showItemPicker(context);
    if (picked != null) setState(() => _item = picked);
  }

  Future<void> _submit() async {
    final supplierId = _supplier?['id']?.toString();
    final qty = num.tryParse(_qtyCtrl.text.trim());
    final price = num.tryParse(_priceCtrl.text.trim());
    if (supplierId == null || qty == null || price == null) {
      setState(() => _err = 'Supplier, qty, and unit price required');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final body = {
        'supplierContactId': supplierId,
        if (_quoteNumCtrl.text.trim().isNotEmpty)
          'quoteNumber': _quoteNumCtrl.text.trim(),
        'lines': [
          {
            if (_item != null) 'itemId': _item!['id']?.toString(),
            'quantity': qty,
            'unitPrice': price,
            if (_leadCtrl.text.trim().isNotEmpty)
              'leadTimeDays': int.tryParse(_leadCtrl.text.trim()),
          }
        ],
      };
      await widget.dio
          .post(ApiConfig.procurementRfqQuotes(widget.rfqId), data: body);
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
      title: const Text('Record supplier quote'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PickerRow(
                label: 'Supplier',
                value: _supplier?['displayName']?.toString() ??
                    _supplier?['name']?.toString(),
                placeholder: 'Pick a supplier (VENDOR / BOTH)',
                icon: Icons.local_shipping_outlined,
                onPick: _pickSupplier,
              ),
              const SizedBox(height: KSpacing.sm),
              TextField(
                controller: _quoteNumCtrl,
                decoration: const InputDecoration(
                    labelText: 'Quote number (optional — auto if blank)'),
              ),
              const Divider(),
              _PickerRow(
                label: 'Item (optional)',
                value: _item?['name']?.toString(),
                placeholder: 'Pick an item — or leave blank for free-text',
                icon: Icons.inventory_2_outlined,
                onPick: _pickItem,
              ),
              const SizedBox(height: KSpacing.sm),
              TextField(
                controller: _qtyCtrl,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              TextField(
                controller: _priceCtrl,
                decoration: const InputDecoration(labelText: 'Unit price (₹)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              TextField(
                controller: _leadCtrl,
                decoration:
                    const InputDecoration(labelText: 'Lead time (days)'),
                keyboardType: TextInputType.number,
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
                : const Text('Save')),
      ],
    );
  }
}

/// Tiny composable for "label + picked value + pick button" rows that
/// the rest of the procurement dialogs reuse. Keeps the look uniform
/// without forcing the design system to grow a new primitive.
class _PickerRow extends StatelessWidget {
  final String label;
  final String? value;
  final String placeholder;
  final IconData icon;
  final VoidCallback onPick;

  const _PickerRow({
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
