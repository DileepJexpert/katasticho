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

/// RFQ → supplier quotation compare → award → PO.
///
/// List of RFQs at the top, "New RFQ" drafts a header + line items +
/// chosen suppliers. Tap a row to see all returned quotes side by
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
        _error = ApiErrorParser.message(e);
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
          Padding(
            padding: const EdgeInsets.only(right: KSpacing.md),
            child: KButton.primary(
              size: KButtonSize.small,
              icon: Icons.add,
              label: 'New RFQ',
              onPressed: _showCreateDialog,
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
                  Icon(Icons.info_outline, size: 20, color: KColors.primary),
                  KSpacing.hGapSm,
                  Expanded(
                    child: Text(
                      'Sourcing matrix: draft an RFQ, invite suppliers, record bids, compare quotes side-by-side, and award the winner to draft a Purchase Order.',
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
                              child: KEmptyState(
                                icon: Icons.request_quote_outlined,
                                title: 'No RFQs Created',
                                subtitle: 'Start by drafting a Request for Quotation to source items from vendors.',
                                actionLabel: 'Create First RFQ',
                                onAction: _showCreateDialog,
                              ),
                            )
                          : ListView.separated(
                              itemBuilder: (_, i) => _RfqTile(
                                rfq: _rfqs[i],
                                onChanged: _refresh,
                              ),
                              separatorBuilder: (_, __) => KSpacing.vGapSm,
                              itemCount: _rfqs.length,
                            ),
            ),
          ],
        ),
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
    return KCard(
      onTap: () => _showRfqDetail(context, ref, rfq, onChanged),
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
            child: Icon(Icons.request_quote_outlined, color: KColors.primary, size: 20),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      rfq['rfqNumber']?.toString() ?? '',
                      style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    KSpacing.hGapSm,
                    Expanded(
                      child: Text(
                        rfq['title']?.toString() ?? '',
                        style: KTypography.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    KSpacing.hGapSm,
                    KStatusChip(status: status),
                  ],
                ),
                KSpacing.vGapXs,
                Row(
                  children: [
                    Text(
                      '${lines.length} Item${lines.length == 1 ? '' : 's'}',
                      style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Text('  ·  ', style: KTypography.caption),
                    Text(
                      '${suppliers.length} Supplier${suppliers.length == 1 ? '' : 's'} Invited',
                      style: KTypography.bodySmall,
                    ),
                    if (rfq['dueDate'] != null) ...[
                      Text('  ·  ', style: KTypography.caption),
                      Icon(Icons.calendar_today_outlined, size: 12, color: KColors.textHint),
                      const SizedBox(width: 4),
                      Text('Due: ${rfq['dueDate']}', style: KTypography.mono(fontSize: 11)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          KSpacing.hGapSm,
          Icon(Icons.chevron_right, color: KColors.textHint),
        ],
      ),
    );
  }
}

Future<void> _showRfqDetail(BuildContext context, WidgetRef ref,
    Map<String, dynamic> rfq, VoidCallback onChanged) async {
  final dio = ref.read(apiClientProvider).dio;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(KSpacing.radiusLg)),
    ),
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
        _err = ApiErrorParser.message(e);
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
          const SnackBar(content: Text('RFQ awarded! Purchase Order has been drafted.')));
      widget.onChanged();
      Navigator.of(context).pop();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Award failed: ${ApiErrorParser.message(e)}')));
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
                  style: KTypography.mono(fontSize: 18, fontWeight: FontWeight.w700)),
              KSpacing.hGapMd,
              KStatusChip(status: widget.status),
              const Spacer(),
              if (widget.status == 'DRAFT' || widget.status == 'SENT')
                KButton.primary(
                  size: KButtonSize.small,
                  icon: Icons.add,
                  label: 'Record Quote',
                  onPressed: _addQuote,
                ),
            ],
          ),
          KSpacing.vGapMd,
          const Divider(),
          KSpacing.vGapSm,
          Expanded(
            child: _loading
                ? const Center(child: KLoading())
                : _err != null
                    ? Center(
                        child: Text('Failed: $_err',
                            style: KTypography.bodySmall
                                .copyWith(color: KColors.error)))
                    : _quotes.isEmpty
                        ? Center(
                            child: KEmptyState(
                              icon: Icons.price_check_outlined,
                              title: 'No Quotes Recorded',
                              subtitle: 'Record supplier quotations as they submit their bids.',
                              actionLabel: (widget.status == 'DRAFT' || widget.status == 'SENT')
                                  ? 'Record First Quote'
                                  : null,
                              onAction: (widget.status == 'DRAFT' || widget.status == 'SENT')
                                  ? _addQuote
                                  : null,
                            ),
                          )
                        : ListView.separated(
                            controller: widget.scrollController,
                            itemCount: _quotes.length,
                            separatorBuilder: (_, __) => KSpacing.vGapSm,
                            itemBuilder: (_, i) {
                              final q = _quotes[i];
                              final qStatus = q['status']?.toString() ?? 'RECEIVED';
                              final isAwarded = qStatus == 'AWARDED';
                              return KCard(
                                statusAccent: isAwarded ? KColors.success : null,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                q['quoteNumber']?.toString() ?? 'QUOTE',
                                                style: KTypography.mono(fontWeight: FontWeight.w700),
                                              ),
                                              KSpacing.hGapSm,
                                              KStatusChip(status: qStatus),
                                            ],
                                          ),
                                          KSpacing.vGapXs,
                                          Row(
                                            children: [
                                              Text('Total Quote: ', style: KTypography.caption),
                                              KMoney(_toBig(q['totalAmount'])),
                                              if (q['validUntil'] != null) ...[
                                                Text('  ·  ', style: KTypography.caption),
                                                Text(
                                                  'Valid Until ${q['validUntil']}',
                                                  style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (widget.status != 'AWARDED' &&
                                        widget.status != 'CANCELLED' &&
                                        qStatus == 'RECEIVED')
                                      KButton.primary(
                                        size: KButtonSize.small,
                                        icon: Icons.check_circle_outline,
                                        label: 'Award PO',
                                        onPressed: () => _award(q['id'].toString()),
                                      ),
                                  ],
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

/// Per-line state. Each line carries the picked item plus description + quantity.
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
      title: 'Add Supplier (Vendor)',
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
        constraints: const BoxConstraints(maxWidth: 580),
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.lg),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('New Request for Quotation (RFQ)', style: KTypography.titleLarge),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                KSpacing.vGapMd,
                KTextField(
                  controller: _titleCtrl,
                  label: 'RFQ Title *',
                  hint: 'e.g. Bulk Cement Procurement Q3',
                ),
                KSpacing.vGapSm,
                KCard(
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: now,
                      firstDate: now.subtract(const Duration(days: 1)),
                      lastDate: now.add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _dueDate = picked);
                  },
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 18, color: KColors.primary),
                      KSpacing.hGapSm,
                      Expanded(
                        child: Text(
                          _dueDate == null
                              ? 'Select Submission Due Date'
                              : 'Due Date: ${_dueDate!.toLocal().toString().substring(0, 10)}',
                          style: KTypography.bodyMedium,
                        ),
                      ),
                      KButton.outlined(
                        size: KButtonSize.small,
                        label: 'Change Date',
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
                ),
                KSpacing.vGapMd,
                Row(
                  children: [
                    Text('Line Items', style: KTypography.titleSmall),
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
                      (entry) => _RfqLineEditor(
                        index: entry.key,
                        line: entry.value,
                        canRemove: _lines.length > 1,
                        onPickItem: () => _pickItemForLine(entry.value),
                        onRemove: () => _removeLine(entry.key),
                      ),
                    ),
                KSpacing.vGapMd,
                Row(
                  children: [
                    Text('Invited Suppliers (${_suppliers.length})', style: KTypography.titleSmall),
                    const Spacer(),
                    KButton.outlined(
                      size: KButtonSize.small,
                      icon: Icons.person_add_outlined,
                      label: 'Add Supplier',
                      onPressed: _addSupplier,
                    ),
                  ],
                ),
                KSpacing.vGapSm,
                if (_suppliers.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: KSpacing.xs),
                    child: Text(
                      'Pick at least one vendor contact to invite to this RFQ.',
                      style: KTypography.bodySmall.copyWith(color: KColors.textHint),
                    ),
                  )
                else
                  Wrap(
                    spacing: KSpacing.xs,
                    runSpacing: KSpacing.xs,
                    children: _suppliers
                        .map((s) => Chip(
                              label: Text(
                                s['displayName']?.toString() ??
                                    s['name']?.toString() ??
                                    'Vendor',
                                style: KTypography.bodySmall,
                              ),
                              deleteIcon: const Icon(Icons.close, size: 14),
                              onDeleted: () =>
                                  _removeSupplier(s['id']?.toString() ?? ''),
                            ))
                        .toList(),
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
                      label: 'Create RFQ',
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
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Line Item #${index + 1}', style: KTypography.labelMedium),
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
              '${line.itemName ?? ''} '
              '${line.sku != null ? '· SKU: ${line.sku}' : ''}'
              '${line.hsnCode != null ? ' · HSN: ${line.hsnCode}' : ''}'
              '${line.gstRate != null ? ' · ${line.gstRate}% GST' : ''}',
              style: KTypography.mono(fontSize: 11, color: KColors.primary),
            ),
          ],
          KSpacing.vGapSm,
          KTextField(
            controller: line.descriptionCtrl,
            label: 'Description for Suppliers',
            hint: 'Specifications or requirements',
          ),
          KSpacing.vGapSm,
          KTextField(
            controller: line.qtyCtrl,
            label: 'Required Quantity',
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
      title: 'Select Supplier',
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
      setState(() => _err = 'Supplier, quantity, and unit price are required');
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
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.lg),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('Record Supplier Quote', style: KTypography.titleLarge),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                KSpacing.vGapMd,
                _PickerRow(
                  label: 'Supplier',
                  value: _supplier?['displayName']?.toString() ??
                      _supplier?['name']?.toString(),
                  placeholder: 'Select responding supplier',
                  icon: Icons.local_shipping_outlined,
                  onPick: _pickSupplier,
                ),
                KSpacing.vGapSm,
                KTextField(
                  controller: _quoteNumCtrl,
                  label: 'Quote Number (optional)',
                  hint: 'Supplier reference quote #',
                ),
                KSpacing.vGapSm,
                _PickerRow(
                  label: 'Item (optional)',
                  value: _item?['name']?.toString(),
                  placeholder: 'Pick item master or leave as generic',
                  icon: Icons.inventory_2_outlined,
                  onPick: _pickItem,
                ),
                KSpacing.vGapSm,
                Row(
                  children: [
                    Expanded(
                      child: KTextField(
                        controller: _qtyCtrl,
                        label: 'Quoted Qty',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    KSpacing.hGapSm,
                    Expanded(
                      child: KTextField.amount(
                        controller: _priceCtrl,
                        label: 'Unit Price',
                      ),
                    ),
                  ],
                ),
                KSpacing.vGapSm,
                KTextField(
                  controller: _leadCtrl,
                  label: 'Lead Time (Days)',
                  keyboardType: TextInputType.number,
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
                      label: 'Save Quote',
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
