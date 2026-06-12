import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/field_sales_repository.dart';

/// Manager inbox for MR submissions: monthly tour plans (MTP) and
/// Daily Call Reports (DCR) awaiting approval.
class MrApprovalsScreen extends ConsumerStatefulWidget {
  const MrApprovalsScreen({super.key});

  @override
  ConsumerState<MrApprovalsScreen> createState() => _MrApprovalsScreenState();
}

class _MrApprovalsScreenState extends ConsumerState<MrApprovalsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _tourPlans = [];
  List<Map<String, dynamic>> _dcrs = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(fieldSalesRepositoryProvider);
      final results = await Future.wait([
        repo.pendingTourPlans(),
        repo.pendingDcrs(),
      ]);
      if (mounted) {
        setState(() {
          _tourPlans = results[0];
          _dcrs = results[1];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load approvals: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _decide({
    required bool isTourPlan,
    required String id,
    required bool approve,
  }) async {
    String? reason;
    if (!approve) {
      final ctl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reject'),
          content: TextField(
            controller: ctl,
            decoration: const InputDecoration(labelText: 'Reason'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Reject')),
          ],
        ),
      );
      if (ok != true) return;
      reason = ctl.text.trim();
    }

    try {
      final repo = ref.read(fieldSalesRepositoryProvider);
      if (isTourPlan) {
        approve
            ? await repo.approveTourPlan(id)
            : await repo.rejectTourPlan(id, reason ?? '');
      } else {
        approve
            ? await repo.approveDcr(id)
            : await repo.rejectDcr(id, reason ?? '');
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e')),
        );
      }
    }
  }

  Future<void> _showTourPlanEntries(Map<String, dynamic> plan) async {
    try {
      final detail = await ref
          .read(fieldSalesRepositoryProvider)
          .getTourPlan(plan['id'].toString());
      final entries = (detail['entries'] as List?) ?? [];
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            shrinkWrap: true,
            children: [
              Text('Plan for ${plan['planMonth'] ?? ''}',
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (entries.isEmpty) const Text('No entries'),
              ...entries.map((e) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.event),
                    title: Text('${e['planDate']} — ${e['activityType']}'),
                    subtitle: Text(
                        [e['area'], e['notes']]
                            .where((x) =>
                                x != null && x.toString().trim().isNotEmpty)
                            .join(' • '),
                        maxLines: 2),
                  )),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load plan: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('MR Approvals'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
            ),
          ],
          bottom: TabBar(tabs: [
            Tab(text: 'Tour Plans (${_tourPlans.length})'),
            Tab(text: 'DCRs (${_dcrs.length})'),
          ]),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: [
                _buildList(
                  items: _tourPlans,
                  emptyText: 'No tour plans awaiting approval',
                  builder: (plan) => ListTile(
                    leading: const Icon(Icons.calendar_month),
                    title: Text('Month: ${plan['planMonth'] ?? ''}'),
                    subtitle: Text(
                        'Submitted ${plan['submittedAt'] ?? ''}'.split('T')[0]),
                    onTap: () => _showTourPlanEntries(plan),
                    trailing: _decisionButtons(
                        isTourPlan: true, id: plan['id'].toString()),
                  ),
                ),
                _buildList(
                  items: _dcrs,
                  emptyText: 'No DCRs awaiting approval',
                  builder: (dcr) => ListTile(
                    leading: const Icon(Icons.assignment),
                    title: Text(
                        '${dcr['reportDate']} — ${dcr['workType'] ?? ''}'),
                    subtitle: Text(
                        'Visits ${dcr['totalVisits']} (Dr ${dcr['doctorsVisited']}'
                        ' / Ch ${dcr['chemistsVisited']})'
                        ' • POB ₹${dcr['totalPob']}'
                        ' • Samples ${dcr['samplesGiven']}'),
                    trailing: _decisionButtons(
                        isTourPlan: false, id: dcr['id'].toString()),
                  ),
                ),
              ]),
      ),
    );
  }

  Widget _buildList({
    required List<Map<String, dynamic>> items,
    required String emptyText,
    required Widget Function(Map<String, dynamic>) builder,
  }) {
    if (items.isEmpty) return Center(child: Text(emptyText));
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) => builder(items[i]),
      ),
    );
  }

  Widget _decisionButtons({required bool isTourPlan, required String id}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.check_circle_outline, color: Colors.green),
          tooltip: 'Approve',
          onPressed: () => _decide(isTourPlan: isTourPlan, id: id, approve: true),
        ),
        IconButton(
          icon: const Icon(Icons.cancel_outlined, color: Colors.red),
          tooltip: 'Reject',
          onPressed: () =>
              _decide(isTourPlan: isTourPlan, id: id, approve: false),
        ),
      ],
    );
  }
}
