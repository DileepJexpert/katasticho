import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';

/// Statutory pharma registers — Schedule H1 / Schedule X / Narcotics.
///
/// Required by Rule 65(11)(h) Drugs & Cosmetics Rules + Form 20G + NDPS Act.
/// Each tab is one register; rows are inserted automatically when a POS sale
/// of a scheduled drug is recorded. CSV export downloads the full register
/// for a drug-inspector audit.
class StatutoryRegistersScreen extends ConsumerStatefulWidget {
  const StatutoryRegistersScreen({super.key});

  @override
  ConsumerState<StatutoryRegistersScreen> createState() =>
      _StatutoryRegistersScreenState();
}

class _StatutoryRegistersScreenState
    extends ConsumerState<StatutoryRegistersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  DateTimeRange? _range;

  static const _tabs = <_TabSpec>[
    _TabSpec('H1', 'Schedule H1', 3, Icons.medication_liquid_rounded),
    _TabSpec('SCHEDULE_X', 'Schedule X', 2, Icons.psychology_rounded),
    _TabSpec('NARCOTICS', 'Narcotics', 2, Icons.no_drinks_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    // Default range: last 90 days through today.
    final now = DateTime.now();
    _range = DateTimeRange(start: now.subtract(const Duration(days: 90)), end: now);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _activeType => _tabs[_tabController.index].type;

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2010),
      lastDate: DateTime(2100),
      initialDateRange: _range,
    );
    if (picked != null && mounted) {
      setState(() => _range = picked);
    }
  }

  Future<void> _exportCsv() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Generating CSV for inspector audit…')),
    );
    try {
      final df = DateFormat('yyyy-MM-dd');
      final qs = <String, dynamic>{
        'type': _activeType,
        if (_range != null) 'from': df.format(_range!.start),
        if (_range != null) 'to': df.format(_range!.end),
      };
      final res = await ref.read(apiClientProvider).get(
            ApiConfig.statutoryRegistersExport,
            queryParameters: qs,
            options: Options(responseType: ResponseType.bytes),
          );
      final bytes = res.data as List<int>;
      final filename =
          'statutory-register-${_activeType.toLowerCase()}-${df.format(DateTime.now())}.csv';
      // Printing.sharePdf is a misnomer — it shares arbitrary bytes via the
      // native share sheet; the filename's .csv extension governs how the
      // recipient app opens it (Excel / Sheets / Files).
      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: filename,
      );
      // Also stash on the clipboard as text so the inspector machine without
      // a working share sheet can paste it into a spreadsheet.
      await Clipboard.setData(ClipboardData(text: String.fromCharCodes(bytes)));
      messenger.showSnackBar(
        const SnackBar(content: Text('CSV exported + copied to clipboard')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(ApiErrorParser.message(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = _tabs[_tabController.index];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statutory Registers'),
        actions: [
          IconButton(
            tooltip: 'Filter date range',
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range_rounded),
          ),
          IconButton(
            tooltip: 'Export CSV for inspector',
            onPressed: _exportCsv,
            icon: const Icon(Icons.download_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            for (final t in _tabs)
              Tab(icon: Icon(t.icon), text: t.label),
          ],
        ),
      ),
      body: Column(
        children: [
          _RegulatoryBanner(spec: spec),
          _RangeBar(range: _range, onPick: _pickRange),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                for (final t in _tabs)
                  _RegisterTab(type: t.type, range: _range),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabSpec {
  final String type;
  final String label;
  final int retentionYears;
  final IconData icon;
  const _TabSpec(this.type, this.label, this.retentionYears, this.icon);
}

class _RegulatoryBanner extends StatelessWidget {
  final _TabSpec spec;
  const _RegulatoryBanner({required this.spec});

  @override
  Widget build(BuildContext context) {
    final body = switch (spec.type) {
      'H1' => 'Rule 65(11)(h), Drugs & Cosmetics Rules. Separate register required '
          'with prescriber name + address, patient name, drug name + qty. '
          'Retain ${spec.retentionYears} years.',
      'SCHEDULE_X' =>
        'Schedule X / Form 20G. Form 19C tracking required; invoice copies '
            'forwarded to Licensing Authority. Retain ${spec.retentionYears} years.',
      'NARCOTICS' =>
        'NDPS Act 1985, Forms 3D / 3E / 3H. Retain ≥${spec.retentionYears} years.',
      _ => '',
    };
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(KSpacing.md),
      color: KColors.warningLight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.gavel_rounded, color: KColors.warning, size: 20),
          SizedBox(width: KSpacing.sm),
          Expanded(child: Text(body)),
        ],
      ),
    );
  }
}

class _RangeBar extends StatelessWidget {
  final DateTimeRange? range;
  final VoidCallback onPick;
  const _RangeBar({required this.range, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy');
    final label = range == null
        ? 'All time'
        : '${df.format(range!.start)} → ${df.format(range!.end)}';
    return Padding(
      padding: EdgeInsets.fromLTRB(KSpacing.md, KSpacing.sm, KSpacing.md, 0),
      child: Row(
        children: [
          Icon(Icons.calendar_month_rounded, size: 16, color: KColors.textSecondary),
          SizedBox(width: KSpacing.xs),
          TextButton(
            onPressed: onPick,
            child: Text(label),
          ),
        ],
      ),
    );
  }
}

/// Pulls a paginated register page for a given type + date range.
final _registerPageProvider = FutureProvider.family.autoDispose<
    Map<String, dynamic>, _RegisterQuery>((ref, q) async {
  final df = DateFormat('yyyy-MM-dd');
  final qs = <String, dynamic>{
    'type': q.type,
    'page': 0,
    'size': 200,
    if (q.range != null) 'from': df.format(q.range!.start),
    if (q.range != null) 'to': df.format(q.range!.end),
  };
  final res = await ref
      .read(apiClientProvider)
      .get(ApiConfig.statutoryRegisters, queryParameters: qs);
  final data = res.data['data'] as Map<String, dynamic>;
  return data;
});

class _RegisterQuery {
  final String type;
  final DateTimeRange? range;
  const _RegisterQuery(this.type, this.range);
  @override
  bool operator ==(Object o) =>
      o is _RegisterQuery &&
      o.type == type &&
      o.range?.start == range?.start &&
      o.range?.end == range?.end;
  @override
  int get hashCode => Object.hash(type, range?.start, range?.end);
}

class _RegisterTab extends ConsumerWidget {
  final String type;
  final DateTimeRange? range;
  const _RegisterTab({required this.type, required this.range});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_registerPageProvider(_RegisterQuery(type, range)));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (page) {
        final content = page['content'];
        final rows = content is List ? content : const <dynamic>[];
        if (rows.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(KSpacing.lg),
              child: Text(
                'No entries in this register for the selected period.\n'
                'Rows are inserted automatically when a POS sale of a scheduled drug is recorded.',
                textAlign: TextAlign.center,
                style: TextStyle(color: KColors.textSecondary),
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(_registerPageProvider(_RegisterQuery(type, range))),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.all(KSpacing.md),
            child: SingleChildScrollView(
              child: DataTable(
                headingTextStyle: KTypography.labelMedium,
                columnSpacing: KSpacing.lg,
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Drug')),
                  DataColumn(label: Text('Batch')),
                  DataColumn(label: Text('Qty'), numeric: true),
                  DataColumn(label: Text('Prescriber')),
                  DataColumn(label: Text('Patient')),
                  DataColumn(label: Text('Receipt')),
                  DataColumn(label: Text('Retention Until')),
                ],
                rows: [
                  for (final row in rows.cast<Map<String, dynamic>>())
                    DataRow(cells: [
                      DataCell(Text(_fmt(row['saleDate']))),
                      DataCell(Text(row['drugName']?.toString() ?? '')),
                      DataCell(Text(row['batchNumber']?.toString() ?? '—',
                          style: KTypography.mono())),
                      DataCell(Text(
                          (row['quantity']?.toString() ?? '0'),
                          style: KTypography.mono())),
                      DataCell(Text(_prescriber(row))),
                      DataCell(Text(row['patientName']?.toString() ?? '—')),
                      DataCell(Text(_shortId(row['saleReceiptId']) ??
                          _shortId(row['invoiceId']) ??
                          '—',
                          style: KTypography.mono())),
                      DataCell(Text(_fmt(row['retentionUntil']),
                          style: TextStyle(color: _retentionColor(row['retentionUntil'])))),
                    ]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _fmt(dynamic v) {
    if (v == null) return '—';
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(v.toString()));
    } catch (_) {
      return v.toString();
    }
  }

  static String _prescriber(Map<String, dynamic> row) {
    final name = row['prescriberName']?.toString();
    final reg = row['prescriberRegNumber']?.toString();
    if (name == null && reg == null) return '—';
    if (name != null && reg != null) return '$name ($reg)';
    return name ?? reg!;
  }

  static String? _shortId(dynamic id) {
    if (id == null) return null;
    final s = id.toString();
    return s.length > 8 ? s.substring(0, 8) : s;
  }

  static Color _retentionColor(dynamic v) {
    if (v == null) return KColors.textSecondary;
    try {
      final dt = DateTime.parse(v.toString());
      final days = dt.difference(DateTime.now()).inDays;
      if (days < 30) return KColors.error;
      if (days < 180) return KColors.warning;
      return KColors.textPrimary;
    } catch (_) {
      return KColors.textSecondary;
    }
  }
}
