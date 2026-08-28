import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';

/// Tracker #92: workstation load + bottleneck identification.
///
/// One-shot view of every workstation's queued hours, days of work,
/// and utilisation as a percentage of one day's capacity. Sorted by
/// queue depth so the bottleneck always sits at the top.
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
          ? const Center(child: KLoading(message: 'Calculating workstation load...'))
          : _error != null
              ? Center(child: KErrorView(message: _error!, onRetry: _refresh))
              : _rows == null || _rows!.isEmpty
                  ? const Center(
                      child: KEmptyState(
                        icon: Icons.precision_manufacturing_outlined,
                        title: 'No Workstations Configured',
                        subtitle: 'Add workstations to monitor load and identify bottlenecks.',
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.builder(
                        padding: KSpacing.pagePadding,
                        itemCount: _rows!.length,
                        itemBuilder: (ctx, i) => _buildRow(_rows![i]),
                      ),
                    ),
    );
  }

  Widget _buildRow(Map<String, dynamic> r) {
    final status = r['status']?.toString() ?? 'OK';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KCard(
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${r['workstationCode']}',
                    style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  KSpacing.hGapSm,
                  Expanded(
                    child: Text(
                      '${r['workstationName']}',
                      style: KTypography.labelLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  KStatusChip(status: status),
                ],
              ),
              KSpacing.vGapSm,
              Wrap(
                spacing: 20,
                runSpacing: 8,
                children: [
                  _stat('Queued', '${r['queuedHours']?.toString() ?? '0'}h'),
                  _stat('Capacity', '${r['capacityHoursPerDay']?.toString() ?? '0'}h/day'),
                  _stat('Days of Work', r['daysOfWork']?.toString() ?? '0'),
                  _stat('Open JCs', r['openJobCards']?.toString() ?? '0'),
                  _stat('In Progress', r['inProgressJobCards']?.toString() ?? '0'),
                  _stat('Utilisation', '${r['utilisationPctOfDay']?.toString() ?? '0'}%'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: KTypography.labelSmall.copyWith(color: KColors.textSecondary)),
          Text(
            value,
            style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      );
}
