import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';

/// RCPA — Retail Chemist Prescription Audit.
/// Captures, per chemist, which brands (our own vs competitor) are being
/// prescribed/sold so the field force can track own-brand share.
class RcpaScreen extends ConsumerStatefulWidget {
  const RcpaScreen({super.key});

  @override
  ConsumerState<RcpaScreen> createState() => _RcpaScreenState();
}

class _RcpaScreenState extends ConsumerState<RcpaScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RCPA — Chemist Prescription Audit'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Audits'),
            Tab(text: 'Reports'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _MyAuditsTab(),
          _ReportsTab(),
        ],
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

List<Map<String, dynamic>> _asMapList(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => e.cast<String, dynamic>())
      .toList();
}

double _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

// ── Tab 1: My Audits ─────────────────────────────────────────────────────────

class _MyAuditsTab extends ConsumerStatefulWidget {
  const _MyAuditsTab();

  @override
  ConsumerState<_MyAuditsTab> createState() => _MyAuditsTabState();
}

class _MyAuditsTabState extends ConsumerState<_MyAuditsTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _audits = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).get(ApiConfig.mrRcpaMine);
      final list = _asMapList(res.data?['data']);
      if (mounted) setState(() => _audits = list);
    } catch (e) {
      _toast('Failed to load audits: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _RcpaEditorDialog(existing: existing),
    );
    if (saved == true) await _load();
  }

  Future<void> _view(Map<String, dynamic> audit) async {
    final id = audit['id']?.toString();
    if (id == null) return;
    try {
      final res =
          await ref.read(apiClientProvider).get(ApiConfig.mrRcpaById(id));
      final data = (res.data?['data'] as Map?)?.cast<String, dynamic>() ?? {};
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _RcpaDetailSheet(data: data),
      );
    } catch (e) {
      _toast('Failed to load audit: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('New audit'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _audits.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Text(
                            'No audits yet. Tap "New audit" to record one.',
                            style: KTypography.bodyMedium
                                .copyWith(color: KColors.textHint),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: KSpacing.pagePadding,
                      itemCount: _audits.length,
                      separatorBuilder: (_, __) => KSpacing.vGapSm,
                      itemBuilder: (context, i) {
                        final a = _audits[i];
                        final remarks = a['remarks']?.toString() ?? '';
                        return KCard(
                          child: InkWell(
                            onTap: () => _view(a),
                            child: Row(
                              children: [
                                const Icon(Icons.fact_check_outlined,
                                    color: KColors.info),
                                KSpacing.hGapMd,
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Audit · ${a['auditDate'] ?? ''}',
                                        style: KTypography.labelLarge,
                                      ),
                                      if (remarks.isNotEmpty) ...[
                                        KSpacing.vGapXs,
                                        Text(
                                          remarks,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: KTypography.bodySmall.copyWith(
                                              color: KColors.textSecondary),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  tooltip: 'Edit',
                                  onPressed: () => _openEditor(existing: a),
                                ),
                                const Icon(Icons.chevron_right,
                                    color: KColors.textHint),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

// ── Audit detail (view) ──────────────────────────────────────────────────────

class _RcpaDetailSheet extends StatelessWidget {
  final Map<String, dynamic> data;

  const _RcpaDetailSheet({required this.data});

  @override
  Widget build(BuildContext context) {
    final audit = (data['audit'] as Map?)?.cast<String, dynamic>() ?? {};
    final lines = _asMapList(data['lines']);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, controller) {
        return ListView(
          controller: controller,
          padding: KSpacing.pagePadding,
          children: [
            Text('Audit · ${audit['auditDate'] ?? ''}',
                style: KTypography.h3),
            if ((audit['remarks']?.toString() ?? '').isNotEmpty) ...[
              KSpacing.vGapXs,
              Text(audit['remarks'].toString(),
                  style: KTypography.bodySmall
                      .copyWith(color: KColors.textSecondary)),
            ],
            KSpacing.vGapMd,
            Text('Brand lines', style: KTypography.labelLarge),
            KSpacing.vGapSm,
            if (lines.isEmpty)
              Text('No lines recorded',
                  style: KTypography.bodySmall
                      .copyWith(color: KColors.textHint))
            else
              ...lines.map((l) {
                final isOwn =
                    (l['brandType']?.toString() ?? '').toUpperCase() == 'OWN';
                final competitor = l['competitorName']?.toString() ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: KSpacing.sm),
                  child: KCard(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isOwn ? KColors.success : KColors.warning)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(isOwn ? 'OWN' : 'COMP',
                              style: KTypography.labelSmall.copyWith(
                                  color: isOwn
                                      ? KColors.success
                                      : KColors.warning)),
                        ),
                        KSpacing.hGapMd,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l['productName']?.toString() ?? '',
                                  style: KTypography.labelLarge),
                              if (!isOwn && competitor.isNotEmpty)
                                Text(competitor,
                                    style: KTypography.bodySmall.copyWith(
                                        color: KColors.textSecondary)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Qty ${l['quantity'] ?? 0}',
                                style: KTypography.bodySmall),
                            Text(
                                CurrencyFormatter.formatIndian(
                                    _asDouble(l['value'])),
                                style: KTypography.labelMedium),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            KSpacing.vGapMd,
          ],
        );
      },
    );
  }
}

// ── Audit editor (create / edit) ─────────────────────────────────────────────

class _RcpaLineDraft {
  final productCtrl = TextEditingController();
  final competitorCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();
  final valueCtrl = TextEditingController();
  String brandType = 'OWN';

  _RcpaLineDraft();

  _RcpaLineDraft.from(Map<String, dynamic> l) {
    productCtrl.text = l['productName']?.toString() ?? '';
    competitorCtrl.text = l['competitorName']?.toString() ?? '';
    qtyCtrl.text = (l['quantity'] ?? '').toString();
    valueCtrl.text = (l['value'] ?? '').toString();
    brandType = (l['brandType']?.toString() ?? 'OWN').toUpperCase() ==
            'COMPETITOR'
        ? 'COMPETITOR'
        : 'OWN';
  }

  void dispose() {
    productCtrl.dispose();
    competitorCtrl.dispose();
    qtyCtrl.dispose();
    valueCtrl.dispose();
  }

  Map<String, dynamic> toJson() => {
        'productName': productCtrl.text.trim(),
        'brandType': brandType,
        'competitorName':
            brandType == 'COMPETITOR' ? competitorCtrl.text.trim() : null,
        'quantity': double.tryParse(qtyCtrl.text.trim()) ?? 0,
        'value': double.tryParse(valueCtrl.text.trim()) ?? 0,
      };
}

class _RcpaEditorDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;

  const _RcpaEditorDialog({this.existing});

  @override
  ConsumerState<_RcpaEditorDialog> createState() => _RcpaEditorDialogState();
}

class _RcpaEditorDialogState extends ConsumerState<_RcpaEditorDialog> {
  final _remarksCtrl = TextEditingController();
  final List<_RcpaLineDraft> _lines = [];

  bool _loadingContacts = true;
  bool _saving = false;
  List<Map<String, dynamic>> _chemists = [];
  String? _chemistId;
  DateTime _auditDate = DateTime.now();
  String? _editingAuditId;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _editingAuditId = existing['id']?.toString();
      _chemistId = existing['chemistContactId']?.toString();
      _remarksCtrl.text = existing['remarks']?.toString() ?? '';
      final dateStr = existing['auditDate']?.toString();
      if (dateStr != null) {
        _auditDate = DateTime.tryParse(dateStr) ?? DateTime.now();
      }
    }
    _loadContacts();
    if (_editingAuditId != null) {
      _loadExistingLines(_editingAuditId!);
    } else {
      _lines.add(_RcpaLineDraft());
    }
  }

  @override
  void dispose() {
    _remarksCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      final res = await ref.read(apiClientProvider).get(
        ApiConfig.contacts,
        queryParameters: {'type': 'CUSTOMER', 'search': ''},
      );
      final content = ((res.data?['data'] as Map?)?['content'] as List?);
      final list = _asMapList(content);
      if (mounted) setState(() => _chemists = list);
    } catch (e) {
      _toast('Failed to load chemists: $e');
    } finally {
      if (mounted) setState(() => _loadingContacts = false);
    }
  }

  Future<void> _loadExistingLines(String id) async {
    try {
      final res =
          await ref.read(apiClientProvider).get(ApiConfig.mrRcpaById(id));
      final data = (res.data?['data'] as Map?)?.cast<String, dynamic>() ?? {};
      final lines = _asMapList(data['lines']);
      if (mounted) {
        setState(() {
          _lines
            ..clear()
            ..addAll(lines.map((l) => _RcpaLineDraft.from(l)));
          if (_lines.isEmpty) _lines.add(_RcpaLineDraft());
        });
      }
    } catch (e) {
      _toast('Failed to load lines: $e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _auditDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _auditDate = picked);
  }

  Future<void> _save() async {
    if (_chemistId == null) {
      _toast('Select a chemist');
      return;
    }
    final lines = _lines
        .where((l) => l.productCtrl.text.trim().isNotEmpty)
        .map((l) => l.toJson())
        .toList();
    if (lines.isEmpty) {
      _toast('Add at least one product line');
      return;
    }
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        if (_editingAuditId != null) 'auditId': _editingAuditId,
        'chemistContactId': _chemistId,
        'auditDate': _isoDate(_auditDate),
        'remarks': _remarksCtrl.text.trim(),
        'lines': lines,
      };
      await ref.read(apiClientProvider).post(ApiConfig.mrRcpa, data: body);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _toast('Failed to save: $e');
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_editingAuditId != null ? 'Edit audit' : 'New audit'),
      content: SizedBox(
        width: 520,
        child: _loadingContacts
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _chemistId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Chemist',
                        border: OutlineInputBorder(),
                      ),
                      items: _chemists.map((c) {
                        final id = c['id']?.toString() ?? '';
                        final name = c['displayName']?.toString() ??
                            c['name']?.toString() ??
                            id;
                        return DropdownMenuItem(
                          value: id,
                          child: Text(name, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _chemistId = v),
                    ),
                    KSpacing.vGapMd,
                    InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Audit date',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(_isoDate(_auditDate)),
                      ),
                    ),
                    KSpacing.vGapMd,
                    TextField(
                      controller: _remarksCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Remarks (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    KSpacing.vGapMd,
                    Row(
                      children: [
                        Text('Brand lines', style: KTypography.labelLarge),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => _lines.add(_RcpaLineDraft())),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add line'),
                        ),
                      ],
                    ),
                    ..._lines.asMap().entries.map((entry) {
                      final i = entry.key;
                      final line = entry.value;
                      return _buildLineEditor(i, line);
                    }),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed:
              _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }

  Widget _buildLineEditor(int index, _RcpaLineDraft line) {
    final isCompetitor = line.brandType == 'COMPETITOR';
    return Padding(
      padding: const EdgeInsets.only(top: KSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: KColors.divider),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: line.productCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Product',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                if (_lines.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: KColors.error),
                    tooltip: 'Remove line',
                    onPressed: () {
                      setState(() {
                        line.dispose();
                        _lines.removeAt(index);
                      });
                    },
                  ),
              ],
            ),
            KSpacing.vGapSm,
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: line.brandType,
                    decoration: const InputDecoration(
                      labelText: 'Brand',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'OWN', child: Text('Own')),
                      DropdownMenuItem(
                          value: 'COMPETITOR', child: Text('Competitor')),
                    ],
                    onChanged: (v) => setState(
                        () => line.brandType = v ?? 'OWN'),
                  ),
                ),
                KSpacing.hGapSm,
                Expanded(
                  child: TextField(
                    controller: line.qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Qty',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                KSpacing.hGapSm,
                Expanded(
                  child: TextField(
                    controller: line.valueCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Value',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            if (isCompetitor) ...[
              KSpacing.vGapSm,
              TextField(
                controller: line.competitorCtrl,
                decoration: const InputDecoration(
                  labelText: 'Competitor name',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
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
  bool _loading = false;
  Map<String, dynamic>? _share;
  List<Map<String, dynamic>> _competitors = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month + 1, 0);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final client = ref.read(apiClientProvider);
      final params = {'from': _isoDate(_from), 'to': _isoDate(_to)};
      final shareRes = await client.get(ApiConfig.mrRcpaShareReport,
          queryParameters: params);
      final compRes = await client.get(ApiConfig.mrRcpaCompetitors,
          queryParameters: params);
      if (mounted) {
        setState(() {
          _share =
              (shareRes.data?['data'] as Map?)?.cast<String, dynamic>() ?? {};
          _competitors = _asMapList(compRes.data?['data']);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load report: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final share = _share;
    return ListView(
      padding: KSpacing.pagePadding,
      children: [
        KCard(
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(isFrom: true),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'From',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: Text(_isoDate(_from)),
                  ),
                ),
              ),
              KSpacing.hGapMd,
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(isFrom: false),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'To',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: Text(_isoDate(_to)),
                  ),
                ),
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
          Text('Own brand share', style: KTypography.h3),
          KSpacing.vGapSm,
          Row(
            children: [
              _shareCard(
                'By quantity',
                _asDouble(share?['ownShareByQtyPct']),
                KColors.primary,
              ),
              KSpacing.hGapSm,
              _shareCard(
                'By value',
                _asDouble(share?['ownShareByValuePct']),
                KColors.success,
              ),
            ],
          ),
          KSpacing.vGapSm,
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _kv('Own — quantity', '${share?['ownQty'] ?? 0}'),
                _kv('Own — value',
                    CurrencyFormatter.formatIndian(_asDouble(share?['ownValue']))),
                const Divider(),
                _kv('Competitor — quantity',
                    '${share?['competitorQty'] ?? 0}'),
                _kv(
                    'Competitor — value',
                    CurrencyFormatter.formatIndian(
                        _asDouble(share?['competitorValue']))),
              ],
            ),
          ),
          KSpacing.vGapMd,
          Text('Competitor brands league', style: KTypography.h3),
          KSpacing.vGapSm,
          if (_competitors.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No competitor activity in this range',
                    style: KTypography.bodyMedium
                        .copyWith(color: KColors.textHint)),
              ),
            )
          else
            ..._competitors.map((c) {
              return Padding(
                padding: const EdgeInsets.only(bottom: KSpacing.sm),
                child: KCard(
                  child: Row(
                    children: [
                      const Icon(Icons.business_outlined,
                          color: KColors.warning),
                      KSpacing.hGapMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c['productName']?.toString() ?? '',
                                style: KTypography.labelLarge),
                            Text(c['competitorName']?.toString() ?? '',
                                style: KTypography.bodySmall.copyWith(
                                    color: KColors.textSecondary)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Qty ${c['quantity'] ?? 0}',
                              style: KTypography.bodySmall),
                          Text(
                              CurrencyFormatter.formatIndian(
                                  _asDouble(c['value'])),
                              style: KTypography.labelMedium
                                  .copyWith(color: KColors.primary)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ],
    );
  }

  Widget _shareCard(String label, double pct, Color color) {
    return Expanded(
      child: KCard(
        child: Column(
          children: [
            Text('${pct.toStringAsFixed(1)}%',
                style: KTypography.h2.copyWith(color: color)),
            Text(label,
                style: KTypography.bodySmall
                    .copyWith(color: KColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: KTypography.bodyMedium),
          Text(value, style: KTypography.labelMedium),
        ],
      ),
    );
  }
}
