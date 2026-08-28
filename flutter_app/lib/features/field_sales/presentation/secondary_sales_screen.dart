import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';

/// Stockist Secondary Sales / Stock & Sales Statement (SSS).
///
/// Tab 1 lets you build a monthly DRAFT statement per stockist (opening /
/// purchase / sales / return per product; closing is derived server-side) and
/// submit it. Tab 2 shows the secondary-sales and stock-on-hand reports across
/// a date range.
class SecondarySalesScreen extends ConsumerStatefulWidget {
  const SecondarySalesScreen({super.key});

  @override
  ConsumerState<SecondarySalesScreen> createState() =>
      _SecondarySalesScreenState();
}

class _SecondarySalesScreenState extends ConsumerState<SecondarySalesScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Secondary Sales'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Statements'),
              Tab(text: 'Reports'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _StatementsTab(),
            _ReportsTab(),
          ],
        ),
      ),
    );
  }
}

// ── helpers ──────────────────────────────────────────────────────────────────

String _firstOfMonth(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-01';

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _monthLabel(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.year}';
}

List<Map<String, dynamic>> _asMapList(dynamic raw) {
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  return const [];
}

Map<String, dynamic> _asMap(dynamic raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return const {};
}

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

// ── Tab 1: Statements ────────────────────────────────────────────────────────

class _StatementsTab extends ConsumerStatefulWidget {
  const _StatementsTab();

  @override
  ConsumerState<_StatementsTab> createState() => _StatementsTabState();
}

class _StatementsTabState extends ConsumerState<_StatementsTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  List<Map<String, dynamic>> _contacts = [];
  String? _stockistId;
  List<Map<String, dynamic>> _statements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() => _loading = true);
    await Future.wait([_loadContacts(), _loadStatements()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadContacts() async {
    try {
      final res = await ref.read(apiClientProvider).get(
        ApiConfig.contacts,
        queryParameters: {'type': 'CUSTOMER', 'search': ''},
      );
      final content = _asMapList(_asMap(res.data['data'])['content']);
      if (mounted) setState(() => _contacts = content);
    } catch (e) {
      _toast('Failed to load stockists: $e');
    }
  }

  Future<void> _loadStatements() async {
    try {
      final res = await ref.read(apiClientProvider).get(
        ApiConfig.secondarySalesStatements,
        queryParameters: {'month': _firstOfMonth(_month)},
      );
      final list = _asMapList(res.data['data']);
      if (mounted) setState(() => _statements = list);
    } catch (e) {
      if (mounted) setState(() => _statements = []);
      _toast('Failed to load statements: $e');
    }
  }

  String _contactName(String? id) {
    if (id == null) return '';
    final c = _contacts.firstWhere(
      (e) => e['id']?.toString() == id,
      orElse: () => const {},
    );
    return (c['displayName'] ?? c['name'] ?? id).toString();
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2018),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _month = DateTime(picked.year, picked.month, 1);
      _loading = true;
    });
    await _loadStatements();
    if (mounted) setState(() => _loading = false);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    if (existing == null && _stockistId == null) {
      _toast('Pick a stockist first');
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _StatementEditorDialog(
        month: _month,
        stockistId: existing?['stockistContactId']?.toString() ?? _stockistId!,
        stockistName: _contactName(
            existing?['stockistContactId']?.toString() ?? _stockistId),
        statementId: existing?['id']?.toString(),
      ),
    );
    if (saved == true) await _loadStatements();
  }

  Future<void> _view(Map<String, dynamic> statement) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _StatementViewDialog(
        statementId: statement['id'].toString(),
        title: _contactName(statement['stockistContactId']?.toString()),
      ),
    );
  }

  Future<void> _submit(Map<String, dynamic> statement) async {
    try {
      await ref
          .read(apiClientProvider)
          .post(ApiConfig.secondarySalesStatementSubmit(statement['id'].toString()));
      _toast('Statement submitted');
      await _loadStatements();
    } catch (e) {
      _toast('Submit failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: KColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('New statement'),
      ),
      body: _loading
          ? const Center(child: KLoading())
          : ListView(
              padding: KSpacing.pagePadding,
              children: [
                KCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Stock & Sales Statement', style: KTypography.titleLarge),
                      KSpacing.vGapSm,
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickMonth,
                              icon: const Icon(Icons.calendar_month, size: 18),
                              label: Text(_monthLabel(_month)),
                            ),
                          ),
                          KSpacing.hGapSm,
                          IconButton(
                            tooltip: 'Refresh',
                            onPressed: _loadStatements,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      KSpacing.vGapSm,
                      DropdownButtonFormField<String>(
                        initialValue: _stockistId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Stockist (for new statement)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: _contacts.map((c) {
                          final id = c['id']?.toString() ?? '';
                          final name =
                              (c['displayName'] ?? c['name'] ?? id).toString();
                          return DropdownMenuItem(
                            value: id,
                            child:
                                Text(name, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _stockistId = v),
                      ),
                    ],
                  ),
                ),
                KSpacing.vGapMd,
                if (_statements.isEmpty)
                  KEmptyState(
                    icon: Icons.assignment_outlined,
                    title: 'No statements found for ${_monthLabel(_month)}',
                    subtitle: 'Create a stockist secondary sales statement by picking a stockist and clicking "New statement".',
                    actionLabel: 'New statement',
                    onAction: () => _openEditor(),
                  )
                else
                  ..._statements.map(_statementCard),
              ],
            ),
    );
  }

  Widget _statementCard(Map<String, dynamic> s) {
    final status = s['status']?.toString() ?? 'DRAFT';
    final isDraft = status == 'DRAFT';
    final color = isDraft ? KColors.warning : KColors.success;
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.sm),
      child: KCard(
        statusAccent: color,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _contactName(s['stockistContactId']?.toString()),
                    style: KTypography.labelLarge.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                KStatusChip(status: status),
              ],
            ),
            KSpacing.vGapXs,
            Text(
              [
                s['periodMonth']?.toString() ?? _firstOfMonth(_month),
                if ((s['notes']?.toString() ?? '').isNotEmpty)
                  s['notes'].toString(),
              ].where((e) => e.isNotEmpty).join(' · '),
              style:
                  KTypography.bodySmall.copyWith(color: KColors.textSecondary),
            ),
            KSpacing.vGapSm,
            Row(
              children: [
                Expanded(
                  child: KButton.outlined(
                    onPressed: () => _view(s),
                    icon: Icons.visibility,
                    size: KButtonSize.small,
                    label: 'View',
                  ),
                ),
                if (isDraft) ...[
                  KSpacing.hGapSm,
                  Expanded(
                    child: KButton.outlined(
                      onPressed: () => _openEditor(existing: s),
                      icon: Icons.edit,
                      size: KButtonSize.small,
                      label: 'Edit',
                    ),
                  ),
                  KSpacing.hGapSm,
                  Expanded(
                    child: KButton.primary(
                      onPressed: () => _submit(s),
                      icon: Icons.check,
                      size: KButtonSize.small,
                      label: 'Submit',
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Statement editor dialog ──────────────────────────────────────────────────

class _StatementEditorDialog extends ConsumerStatefulWidget {
  final DateTime month;
  final String stockistId;
  final String stockistName;
  final String? statementId;

  const _StatementEditorDialog({
    required this.month,
    required this.stockistId,
    required this.stockistName,
    this.statementId,
  });

  @override
  ConsumerState<_StatementEditorDialog> createState() =>
      _StatementEditorDialogState();
}

class _LineControllers {
  final TextEditingController product = TextEditingController();
  final TextEditingController opening = TextEditingController();
  final TextEditingController purchase = TextEditingController();
  final TextEditingController sales = TextEditingController();
  final TextEditingController returns = TextEditingController();
  final TextEditingController value = TextEditingController();

  void dispose() {
    product.dispose();
    opening.dispose();
    purchase.dispose();
    sales.dispose();
    returns.dispose();
    value.dispose();
  }
}

class _StatementEditorDialogState
    extends ConsumerState<_StatementEditorDialog> {
  final List<_LineControllers> _lines = [];
  final TextEditingController _notes = TextEditingController();
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.statementId != null) {
      _loadExisting();
    } else {
      _addLine();
    }
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    _notes.dispose();
    super.dispose();
  }

  void _addLine() {
    setState(() => _lines.add(_LineControllers()));
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).get(
          ApiConfig.secondarySalesStatementById(widget.statementId!));
      final data = _asMap(res.data['data']);
      final statement = _asMap(data['statement']);
      _notes.text = statement['notes']?.toString() ?? '';
      final lines = _asMapList(data['lines']);
      for (final l in lines) {
        final ctl = _LineControllers();
        ctl.product.text = l['productName']?.toString() ?? '';
        ctl.opening.text = _num(l['openingQty']).toString();
        ctl.purchase.text = _num(l['purchaseQty']).toString();
        ctl.sales.text = _num(l['salesQty']).toString();
        ctl.returns.text = _num(l['returnQty']).toString();
        ctl.value.text = _num(l['salesValue']).toString();
        _lines.add(ctl);
      }
      if (_lines.isEmpty) _addLine();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Load failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final lines = <Map<String, dynamic>>[];
    for (final l in _lines) {
      final name = l.product.text.trim();
      if (name.isEmpty) continue;
      lines.add({
        'productName': name,
        'openingQty': double.tryParse(l.opening.text.trim()) ?? 0,
        'purchaseQty': double.tryParse(l.purchase.text.trim()) ?? 0,
        'salesQty': double.tryParse(l.sales.text.trim()) ?? 0,
        'returnQty': double.tryParse(l.returns.text.trim()) ?? 0,
        'salesValue': double.tryParse(l.value.text.trim()) ?? 0,
      });
    }
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one product line')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).post(
        ApiConfig.secondarySalesStatements,
        data: {
          'stockistContactId': widget.stockistId,
          'periodMonth': _firstOfMonth(widget.month),
          'notes': _notes.text.trim(),
          'lines': lines,
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        '${widget.statementId == null ? 'New' : 'Edit'} statement'
        '${widget.stockistName.isEmpty ? '' : ' · ${widget.stockistName}'}',
        style: KTypography.labelLarge,
      ),
      content: SizedBox(
        width: 720,
        child: _loading
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${_monthLabel(widget.month)} · closing is derived',
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary)),
                    KSpacing.vGapSm,
                    TextField(
                      controller: _notes,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    KSpacing.vGapMd,
                    ..._lines.asMap().entries.map((e) => _lineRow(e.key)),
                    KSpacing.vGapSm,
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _addLine,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add line'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }

  Widget _lineRow(int index) {
    final l = _lines[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: l.product,
                  decoration: const InputDecoration(
                    labelText: 'Product',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove line',
                onPressed: _lines.length == 1
                    ? null
                    : () => setState(() {
                          _lines.removeAt(index).dispose();
                        }),
                icon: const Icon(Icons.delete_outline, color: KColors.error),
              ),
            ],
          ),
          KSpacing.vGapXs,
          Row(
            children: [
              Expanded(child: _qtyField(l.opening, 'Opening')),
              KSpacing.hGapSm,
              Expanded(child: _qtyField(l.purchase, 'Purchase')),
              KSpacing.hGapSm,
              Expanded(child: _qtyField(l.sales, 'Sales')),
            ],
          ),
          KSpacing.vGapXs,
          Row(
            children: [
              Expanded(child: _qtyField(l.returns, 'Return')),
              KSpacing.hGapSm,
              Expanded(child: _qtyField(l.value, 'Sales value (₹)')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyField(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}

// ── Statement view dialog ────────────────────────────────────────────────────

class _StatementViewDialog extends ConsumerStatefulWidget {
  final String statementId;
  final String title;

  const _StatementViewDialog({required this.statementId, required this.title});

  @override
  ConsumerState<_StatementViewDialog> createState() =>
      _StatementViewDialogState();
}

class _StatementViewDialogState extends ConsumerState<_StatementViewDialog> {
  Map<String, dynamic>? _statement;
  List<Map<String, dynamic>> _lines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ref.read(apiClientProvider).get(
          ApiConfig.secondarySalesStatementById(widget.statementId));
      final data = _asMap(res.data['data']);
      if (mounted) {
        setState(() {
          _statement = _asMap(data['statement']);
          _lines = _asMapList(data['lines']);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Load failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title.isEmpty ? 'Statement' : widget.title,
          style: KTypography.labelLarge),
      content: SizedBox(
        width: 720,
        child: _loading
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_statement?['periodMonth'] ?? ''} · '
                      '${_statement?['status'] ?? ''}',
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textSecondary),
                    ),
                    KSpacing.vGapSm,
                    if (_lines.isEmpty)
                      Text('No lines',
                          style: KTypography.bodyMedium
                              .copyWith(color: KColors.textHint))
                    else
                      ..._lines.map((l) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: KSpacing.sm),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l['productName']?.toString() ?? '',
                                    style: KTypography.labelMedium),
                                Text(
                                  'Open ${_num(l['openingQty']).toStringAsFixed(0)} · '
                                  'Pur ${_num(l['purchaseQty']).toStringAsFixed(0)} · '
                                  'Sale ${_num(l['salesQty']).toStringAsFixed(0)} · '
                                  'Ret ${_num(l['returnQty']).toStringAsFixed(0)} · '
                                  'Close ${_num(l['closingQty']).toStringAsFixed(0)}',
                                  style: KTypography.bodySmall
                                      .copyWith(color: KColors.textSecondary),
                                ),
                                Row(
                                  children: [
                                    Text('Sales value: ',
                                        style: KTypography.bodySmall),
                                    KMoney(_num(l['salesValue']),
                                        size: KMoneySize.small),
                                  ],
                                ),
                                const Divider(),
                              ],
                            ),
                          )),
                  ],
                ),
              ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

// ── Tab 2: Reports ───────────────────────────────────────────────────────────

class _ReportsTab extends ConsumerStatefulWidget {
  const _ReportsTab();

  @override
  ConsumerState<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends ConsumerState<_ReportsTab> {
  late DateTime _from;
  late DateTime _to;
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _stock = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month + 1, 0); // last day of current month
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final client = ref.read(apiClientProvider);
      final results = await Future.wait([
        client.get(
          ApiConfig.secondarySalesReport,
          queryParameters: {'from': _isoDate(_from), 'to': _isoDate(_to)},
        ),
        client.get(
          ApiConfig.secondarySalesStockOnHand,
          queryParameters: {'month': _firstOfMonth(_from)},
        ),
      ]);
      if (mounted) {
        setState(() {
          _sales = _asMapList(results[0].data['data']);
          _stock = _asMapList(results[1].data['data']);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sales = [];
          _stock = [];
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load reports: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2018),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _from = picked.start;
      _to = picked.end;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: KSpacing.pagePadding,
      children: [
        KCard(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text('${_isoDate(_from)}  →  ${_isoDate(_to)}'),
                ),
              ),
              KSpacing.hGapSm,
              IconButton(
                tooltip: 'Refresh',
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        KSpacing.vGapMd,
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else ...[
          Text('Secondary Sales', style: KTypography.h4),
          KSpacing.vGapSm,
          if (_sales.isEmpty)
            _empty('No secondary sales in this range')
          else
            KDataTable(
              columns: const [
                KTableColumn(label: 'Product'),
                KTableColumn(label: 'Sales Qty', numeric: true),
                KTableColumn(label: 'Return Qty', numeric: true),
                KTableColumn(label: 'Net Qty', numeric: true),
                KTableColumn(label: 'Sales Value', numeric: true),
              ],
              rows: _sales.map((r) {
                return [
                  Text(
                    r['productName']?.toString() ?? '',
                    style: KTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(_num(r['salesQty']).toStringAsFixed(0), style: KTypography.bodySmall),
                  Text(_num(r['returnQty']).toStringAsFixed(0), style: KTypography.bodySmall),
                  Text(_num(r['netSalesQty']).toStringAsFixed(0), style: KTypography.bodySmall),
                  KMoney(_num(r['salesValue']), size: KMoneySize.small),
                ];
              }).toList(),
            ),
          KSpacing.vGapLg,
          Text('Stock on Hand · ${_monthLabel(_from)}', style: KTypography.h4),
          KSpacing.vGapSm,
          if (_stock.isEmpty)
            _empty('No stock-on-hand for this month')
          else
            KDataTable(
              columns: const [
                KTableColumn(label: 'Product'),
                KTableColumn(label: 'Closing Qty', numeric: true),
              ],
              rows: _stock.map((r) {
                return [
                  Text(
                    r['productName']?.toString() ?? '',
                    style: KTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(_num(r['closingQty']).toStringAsFixed(0), style: KTypography.bodySmall),
                ];
              }).toList(),
            ),
        ],
      ],
    );
  }

  Widget _empty(String msg) => KCard(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              msg,
              style: KTypography.bodyMedium.copyWith(color: KColors.textSecondary),
            ),
          ),
        ),
      );
}
