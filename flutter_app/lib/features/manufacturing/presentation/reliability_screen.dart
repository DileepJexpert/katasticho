import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';

/// Tracker #86: per-equipment reliability dashboard.
///
/// MTBF (Mean Time Between Failures) + MTTR (Mean Time To Repair) +
/// Availability% per workstation over a date range. The two metrics
/// every reliability engineer asks about a machine: how long can we
/// run it before the next breakdown, and how long does it take to come
/// back online.
class ReliabilityScreen extends ConsumerStatefulWidget {
  const ReliabilityScreen({super.key});

  @override
  ConsumerState<ReliabilityScreen> createState() =>
      _ReliabilityScreenState();
}

class _ReliabilityScreenState extends ConsumerState<ReliabilityScreen> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  Map<String, dynamic>? _report;
  bool _loading = false;
  String? _error;

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
      final res = await ref.read(apiClientProvider).get(
            ApiConfig.mfgMaintReliabilityReport,
            queryParameters: {
              'from': _fmt(_from),
              'to': _fmt(_to),
            },
          );
      setState(() {
        _report = (res.data['data'] as Map).cast<String, dynamic>();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = ApiErrorParser.message(e);
        _loading = false;
      });
    }
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (picked != null) {
      setState(() {
        _from = picked.start;
        _to = picked.end;
      });
      _load();
    }
  }

  String _formatMinutes(Object? minutes) {
    if (minutes == null) return '—';
    final m = int.tryParse(minutes.toString()) ?? 0;
    if (m == 0) return '0m';
    if (m < 60) return '${m}m';
    final h = m ~/ 60;
    final remainingMin = m % 60;
    if (h < 24) return '${h}h ${remainingMin}m';
    final d = h ~/ 24;
    final remainingH = h % 24;
    return '${d}d ${remainingH}h';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipment Reliability'),
        actions: [
          IconButton(
            tooltip: 'Date range',
            icon: const Icon(Icons.date_range),
            onPressed: _pickRange,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!,
                  style: const TextStyle(color: Colors.red)))
              : _report == null
                  ? const Center(child: Text('No data'))
                  : _buildBody(_report!),
    );
  }

  Widget _buildBody(Map<String, dynamic> r) {
    final items = (r['items'] as List?)?.cast<dynamic>() ?? const [];
    return Column(
      children: [
        Container(
          color: Colors.blueGrey.shade50,
          padding: const EdgeInsets.all(KSpacing.md),
          child: Row(
            children: [
              Icon(Icons.calendar_today, size: 16,
                  color: Colors.blueGrey.shade700),
              const SizedBox(width: 8),
              Text('${r['from']} → ${r['to']}',
                  style: KTypography.bodyMedium),
              const Spacer(),
              Text('Window: ${_formatMinutes(r['windowMinutes'])}',
                  style: KTypography.bodySmall),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('No workstations configured'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(KSpacing.md),
                    itemCount: items.length,
                    itemBuilder: (ctx, i) {
                      final row = (items[i] as Map).cast<String, dynamic>();
                      return _buildRow(row);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildRow(Map<String, dynamic> row) {
    final availability =
        double.tryParse(row['availabilityPct']?.toString() ?? '0') ?? 0;
    final color = availability >= 95
        ? Colors.green
        : availability >= 85
            ? Colors.orange
            : Colors.red;
    final breakdowns = row['breakdownCount']?.toString() ?? '0';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                      '${row['workstationCode']} — ${row['workstationName']}',
                      style: KTypography.titleSmall),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                      '${availability.toStringAsFixed(1)}% available',
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _stat('MTBF', _formatMinutes(row['mtbfMinutes']),
                    'Mean Time Between Failures'),
                _stat('MTTR', _formatMinutes(row['mttrMinutes']),
                    'Mean Time To Repair'),
                _stat('Breakdowns', breakdowns,
                    'In selected window'),
                _stat('Preventive',
                    row['preventiveCount']?.toString() ?? '0',
                    'Scheduled maintenance'),
                _stat('Downtime',
                    _formatMinutes(row['totalDowntimeMinutes']),
                    'Total in window'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, String tooltip) => Tooltip(
        message: tooltip,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: KTypography.labelSmall),
            Text(value, style: KTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
