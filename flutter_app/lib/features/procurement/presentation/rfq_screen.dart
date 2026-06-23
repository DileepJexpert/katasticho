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
                color: KColors.surfaceMuted,
                borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                border: Border.all(color: KColors.border),
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

class _CreateRfqDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CreateRfqDialog> createState() => _CreateRfqDialogState();
}

class _CreateRfqDialogState extends ConsumerState<_CreateRfqDialog> {
  final _titleCtrl = TextEditingController();
  final _itemIdCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _suppliersCtrl = TextEditingController();
  DateTime? _dueDate;
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _itemIdCtrl.dispose();
    _descriptionCtrl.dispose();
    _qtyCtrl.dispose();
    _suppliersCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final qty = num.tryParse(_qtyCtrl.text.trim());
    final supplierIds = _suppliersCtrl.text
        .split(RegExp(r'[,\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (title.isEmpty || qty == null || supplierIds.isEmpty) {
      setState(() => _err = 'Title, qty, and ≥1 supplier id required');
      return;
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
        'lines': [
          {
            if (_itemIdCtrl.text.trim().isNotEmpty)
              'itemId': _itemIdCtrl.text.trim(),
            'description': _descriptionCtrl.text.trim(),
            'quantity': qty,
          }
        ],
        'supplierContactIds': supplierIds,
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
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleCtrl,
                decoration:
                    const InputDecoration(labelText: 'Title (e.g. Cement Q3)'),
              ),
              const SizedBox(height: KSpacing.sm),
              Row(
                children: [
                  Expanded(child: Text(_dueDate == null
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
              Text('First line', style: KTypography.bodySmall.copyWith(
                  color: KColors.textSecondary)),
              TextField(
                controller: _itemIdCtrl,
                decoration: const InputDecoration(labelText: 'Item id (UUID, optional)'),
              ),
              TextField(
                controller: _descriptionCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              TextField(
                controller: _qtyCtrl,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
              ),
              const Divider(),
              TextField(
                controller: _suppliersCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Supplier contact ids (UUIDs, one per line or comma-separated)',
                  helperText: 'Each must be a VENDOR (or BOTH) contact in this org.',
                ),
              ),
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
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Create'),
        ),
      ],
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
  final _supplierIdCtrl = TextEditingController();
  final _quoteNumCtrl = TextEditingController();
  final _itemIdCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();
  final _leadCtrl = TextEditingController();
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _supplierIdCtrl.dispose();
    _quoteNumCtrl.dispose();
    _itemIdCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _leadCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final supplier = _supplierIdCtrl.text.trim();
    final qty = num.tryParse(_qtyCtrl.text.trim());
    final price = num.tryParse(_priceCtrl.text.trim());
    if (supplier.isEmpty || qty == null || price == null) {
      setState(() => _err = 'Supplier contact id, qty, and unit price required');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final body = {
        'supplierContactId': supplier,
        if (_quoteNumCtrl.text.trim().isNotEmpty)
          'quoteNumber': _quoteNumCtrl.text.trim(),
        'lines': [
          {
            if (_itemIdCtrl.text.trim().isNotEmpty)
              'itemId': _itemIdCtrl.text.trim(),
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
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                  controller: _supplierIdCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Supplier contact id (UUID)')),
              TextField(
                  controller: _quoteNumCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Quote number (optional — auto if blank)')),
              const Divider(),
              TextField(
                  controller: _itemIdCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Item id (UUID, optional)')),
              TextField(
                  controller: _qtyCtrl,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: _priceCtrl,
                  decoration: const InputDecoration(labelText: 'Unit price (₹)'),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: _leadCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Lead time (days)'),
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
                : const Text('Save')),
      ],
    );
  }
}
