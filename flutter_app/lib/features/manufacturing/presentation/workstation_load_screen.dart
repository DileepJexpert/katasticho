import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';

/// Tracker #92: workstation load + bottleneck identification.
///
/// One-shot view of every workstation's queued hours, days of work,
/// and utilisation as a percentage of one day's capacity. Sorted by
/// queue depth so the bottleneck always sits at the top. Color-coded
/// status chip: BOTTLENECK (red) > BUSY (orange) > OK (green) > IDLE.
class WorkstationLoadScreen extends ConsumerStatefulWidget {
  const WorkstationLoadScreen({super.key});

  @override
  ConsumerState<WorkstationLoadScreen> createState() =>
      _WorkstationLoadScreenState();
}

class _WorkstationLoadScreenState extends ConsumerState<WorkstationLoadScreen> {
  List<Map<String, dynamic>>? _rows;
  String? _error;
  bool _loading = false;

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
      final res = await ref.read(apiClientProvider).get(
            ApiConfig.manufacturingWorkstationLoad,
          );
      final list = (res.data['data'] as List?)?.cast<dynamic>() ?? const [];
      setState(() {
        _rows = list
            .map<Map<String, dynamic>>((r) => (r as Map).cast<String, dynamic>())
            .toList();
        _loading = false;
      });
    } catch (e) {
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
        title: const Text('Workstation Load'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!,
                  style: const TextStyle(color: Colors.red)))
              : _rows == null || _rows!.isEmpty
                  ? const Center(
                      child: Text('No workstations configured'))
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(KSpacing.md),
                        itemCount: _rows!.length,
                        itemBuilder: (ctx, i) => _buildRow(_rows![i]),
                      ),
                    ),
    );
  }

  Widget _buildRow(Map<String, dynamic> r) {
    final status = r['status']?.toString() ?? 'OK';
    final color = switch (status) {
      'BOTTLENECK' => Colors.red.shade700,
      'BUSY' => Colors.orange.shade700,
      'OK' => Colors.green.shade700,
      'IDLE' => Colors.grey.shade500,
      _ => Colors.blue.shade700,
    };
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
                      '${r['workstationCode']} — ${r['workstationName']}',
                      style: KTypography.titleSmall),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(status,
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _stat('Queued',
                    '${r['queuedHours']?.toString() ?? '0'}h'),
                _stat('Capacity',
                    '${r['capacityHoursPerDay']?.toString() ?? '0'}h/day'),
                _stat('Days of work',
                    '${r['daysOfWork']?.toString() ?? '0'}'),
                _stat('Open JCs',
                    '${r['openJobCards']?.toString() ?? '0'}'),
                _stat('In progress',
                    '${r['inProgressJobCards']?.toString() ?? '0'}'),
                _stat('Utilisation',
                    '${r['utilisationPctOfDay']?.toString() ?? '0'}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: KTypography.labelSmall),
          Text(value, style: KTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600)),
        ],
      );
}
