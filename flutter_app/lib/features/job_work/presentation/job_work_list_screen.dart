import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_error_view.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_money.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../../../core/widgets/k_text_field.dart';
import '../data/job_work_models.dart';
import '../data/job_work_repository.dart';

class JobWorkChallan45ListScreen extends ConsumerStatefulWidget {
  const JobWorkChallan45ListScreen({super.key});

  @override
  ConsumerState<JobWorkChallan45ListScreen> createState() => _JobWorkChallan45ListScreenState();
}

class _JobWorkChallan45ListScreenState extends ConsumerState<JobWorkChallan45ListScreen>
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
        title: const Text('Subcontracting & Job Work (Challan 45)'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.outbox_outlined), text: 'Job Work Orders (Rule 45)'),
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'GST ITC-04 Register'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(jobWorkOrdersProvider);
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _OrdersTab(),
          _Itc04Tab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1: JOB WORK ORDERS
// ─────────────────────────────────────────────────────────────────────────────

class _OrdersTab extends ConsumerWidget {
  const _OrdersTab();

  void _showCreateModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateJobWorkSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(jobWorkOrdersProvider);

    return ordersAsync.when(
      loading: () => const KLoading(),
      error: (err, _) => KErrorView(
        message: 'Failed to load job work orders: $err',
        onRetry: () => ref.invalidate(jobWorkOrdersProvider),
      ),
      data: (orders) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: KSpacing.md, vertical: KSpacing.sm),
              color: KColors.bgApp,
              child: Row(
                children: [
                  const Icon(Icons.precision_manufacturing_outlined,
                      size: 18, color: KColors.primary),
                  KSpacing.hGapXs,
                  Text(
                    'Job Work Dispatch Orders (${orders.length})',
                    style: KTypography.labelLarge,
                  ),
                  const Spacer(),
                  KButton(
                    label: 'Issue Challan 45 Order',
                    icon: Icons.add,
                    onPressed: () => _showCreateModal(context, ref),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: orders.isEmpty
                  ? const KEmptyState(
                      icon: Icons.outbox,
                      title: 'No Job Work Orders Found',
                      subtitle:
                          'Issue raw materials and bulk items to job workers under Rule 45 Challans.',
                    )
                  : ListView.separated(
                      padding: KSpacing.pagePadding,
                      itemCount: orders.length,
                      separatorBuilder: (_, __) => KSpacing.vGapSm,
                      itemBuilder: (context, i) {
                        final o = orders[i];
                        final isCompleted = o.status == 'COMPLETED';

                        return InkWell(
                          onTap: () => context.push('/inventory/job-work/${o.id}'),
                          borderRadius: BorderRadius.circular(8),
                          child: KCard(
                            padding: const EdgeInsets.all(KSpacing.md),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: isCompleted
                                      ? KColors.success.withValues(alpha: 0.12)
                                      : KColors.primary.withValues(alpha: 0.12),
                                  child: Icon(
                                    Icons.engineering_outlined,
                                    size: 20,
                                    color: isCompleted
                                        ? KColors.success
                                        : KColors.primary,
                                  ),
                                ),
                                KSpacing.hGapMd,

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            o.orderNumber,
                                            style: KTypography.labelLarge
                                                .copyWith(fontWeight: FontWeight.w700),
                                          ),
                                          KSpacing.hGapSm,
                                          KStatusChip(
                                            status: isCompleted
                                                ? 'PAID'
                                                : o.status == 'ISSUED'
                                                    ? 'SENT'
                                                    : 'PENDING',
                                            label: o.status,
                                          ),
                                        ],
                                      ),
                                      KSpacing.vGapXs,
                                      Text(
                                        'Job Worker: ${o.jobWorkerName} ${o.jobWorkerGstin != null ? "• GSTIN: ${o.jobWorkerGstin}" : ""}',
                                        style: KTypography.caption
                                            .copyWith(color: KColors.textSecondary),
                                      ),
                                      if (o.processDescription != null) ...[
                                        KSpacing.vGapXs,
                                        Text(
                                          'Process: ${o.processDescription}',
                                          style: KTypography.caption,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Issued Value', style: KTypography.caption),
                                    KMoney(o.totalIssuedValue),
                                    KSpacing.vGapXs,
                                    Text(
                                      'Date: ${o.orderDate}',
                                      style: KTypography.mono(
                                          fontSize: 11,
                                          color: KColors.textSecondary),
                                    ),
                                  ],
                                ),
                                KSpacing.hGapSm,
                                const Icon(Icons.chevron_right, color: KColors.textHint),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2: GST FORM ITC-04 REGISTER
// ─────────────────────────────────────────────────────────────────────────────

class _Itc04Tab extends ConsumerStatefulWidget {
  const _Itc04Tab();

  @override
  ConsumerState<_Itc04Tab> createState() => _Itc04TabState();
}

class _Itc04TabState extends ConsumerState<_Itc04Tab> {
  String _quarter = 'Q1';
  int _year = 2026;

  @override
  Widget build(BuildContext context) {
    final itcAsync = ref.watch(itc04ReportProvider((quarter: _quarter, year: _year)));

    return ListView(
      padding: KSpacing.pagePadding,
      children: [
        // Filter bar
        KCard(
          padding: const EdgeInsets.all(KSpacing.md),
          child: Row(
            children: [
              const Icon(Icons.filter_alt_outlined, color: KColors.primary),
              KSpacing.hGapSm,
              Text('Statutory Return Period:', style: KTypography.labelLarge),
              KSpacing.hGapMd,
              DropdownButton<String>(
                value: _quarter,
                items: const [
                  DropdownMenuItem(value: 'Q1', child: Text('Q1 (Apr - Jun)')),
                  DropdownMenuItem(value: 'Q2', child: Text('Q2 (Jul - Sep)')),
                  DropdownMenuItem(value: 'Q3', child: Text('Q3 (Oct - Dec)')),
                  DropdownMenuItem(value: 'Q4', child: Text('Q4 (Jan - Mar)')),
                ],
                onChanged: (v) => setState(() => _quarter = v!),
              ),
              KSpacing.hGapMd,
              DropdownButton<int>(
                value: _year,
                items: const [
                  DropdownMenuItem(value: 2025, child: Text('FY 2025-26')),
                  DropdownMenuItem(value: 2026, child: Text('FY 2026-27')),
                ],
                onChanged: (v) => setState(() => _year = v!),
              ),
            ],
          ),
        ),
        KSpacing.vGapMd,

        itcAsync.when(
          loading: () => const KLoading(),
          error: (err, _) => KErrorView(
            message: 'Failed to load ITC-04 data: $err',
            onRetry: () => ref.invalidate(itc04ReportProvider((quarter: _quarter, year: _year))),
          ),
          data: (report) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Metrics
                Row(
                  children: [
                    Expanded(
                      child: KCard(
                        padding: const EdgeInsets.all(KSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total Issued (Table 4)', style: KTypography.caption),
                            KSpacing.vGapXs,
                            KMoney(report.totalIssuedValue),
                          ],
                        ),
                      ),
                    ),
                    KSpacing.hGapSm,
                    Expanded(
                      child: KCard(
                        padding: const EdgeInsets.all(KSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Received Back (Table 5A)', style: KTypography.caption),
                            KSpacing.vGapXs,
                            KMoney(report.totalReturnedValue),
                          ],
                        ),
                      ),
                    ),
                    KSpacing.hGapSm,
                    Expanded(
                      child: KCard(
                        padding: const EdgeInsets.all(KSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pending at Job Worker', style: KTypography.caption),
                            KSpacing.vGapXs,
                            KMoney(report.pendingValue),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                KSpacing.vGapLg,

                // Table 4 Lines
                Text('Table 4: Details of Inputs / Capital Goods Sent for Job Work',
                    style: KTypography.labelLarge),
                KSpacing.vGapSm,
                if (report.table4InputsSent.isEmpty)
                  const KCard(
                    padding: EdgeInsets.all(KSpacing.md),
                    child: Text('No inputs sent in this quarter.'),
                  )
                else
                  ...report.table4InputsSent.map((l) => Container(
                        margin: const EdgeInsets.only(bottom: KSpacing.sm),
                        child: KCard(
                          padding: const EdgeInsets.all(KSpacing.sm),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${l.challanNumber} (${l.challanDate})',
                                      style: KTypography.mono(fontWeight: FontWeight.w700)),
                                  Text('${l.itemName} • ${l.quantity} ${l.uom}'),
                                  Text('Worker: ${l.jobWorkerName}',
                                      style: KTypography.caption
                                          .copyWith(color: KColors.textSecondary)),
                                ],
                              ),
                              KMoney(l.taxableValue),
                            ],
                          ),
                        ),
                      )),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CREATE JOB WORK ORDER SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _CreateJobWorkSheet extends ConsumerStatefulWidget {
  const _CreateJobWorkSheet();

  @override
  ConsumerState<_CreateJobWorkSheet> createState() => _CreateJobWorkSheetState();
}

class _CreateJobWorkSheetState extends ConsumerState<_CreateJobWorkSheet> {
  String? _selectedWorkerId;
  String? _selectedItemId;
  final _processCtl = TextEditingController(text: 'Coating & Packaging');
  final _qtyCtl = TextEditingController(text: '100');
  final _rateCtl = TextEditingController(text: '250');
  final _notesCtl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _processCtl.dispose();
    _qtyCtl.dispose();
    _rateCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedWorkerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Job Worker / Vendor')),
      );
      return;
    }
    if (_selectedItemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select raw material to dispatch')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final req = CreateJobWorkRequest(
        jobWorkerId: _selectedWorkerId!,
        orderDate: DateTime.now().toIso8601String().split('T').first,
        expectedReturnDate: DateTime.now().add(const Duration(days: 30)).toIso8601String().split('T').first,
        processDescription: _processCtl.text.trim(),
        notes: _notesCtl.text.trim().isNotEmpty ? _notesCtl.text.trim() : null,
        issueLines: [
          {
            'itemId': _selectedItemId,
            'issuedQuantity': double.tryParse(_qtyCtl.text.trim()) ?? 100.0,
            'unitRate': double.tryParse(_rateCtl.text.trim()) ?? 250.0,
            'natureOfProcessing': _processCtl.text.trim(),
          }
        ],
      );

      await ref.read(jobWorkRepositoryProvider).createOrder(req);
      ref.invalidate(jobWorkOrdersProvider);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Challan 45 Job Work Order issued successfully!'),
          backgroundColor: KColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: KColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendorsAsync = ref.watch(jobWorkVendorsProvider);
    final itemsAsync = ref.watch(jobWorkItemsProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(KSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Issue Job Work Order (Challan 45)', style: KTypography.h2),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            KSpacing.vGapMd,

            // Vendor picker
            vendorsAsync.when(
              data: (vendors) => DropdownButtonFormField<String>(
                initialValue: _selectedWorkerId,
                decoration: const InputDecoration(labelText: 'Job Worker (Vendor) *'),
                items: vendors.map((v) => DropdownMenuItem(
                      value: v['id']?.toString(),
                      child: Text('${v['displayName'] ?? v['companyName']} ${v['gstin'] != null ? "(${v['gstin']})" : ""}'),
                    )).toList(),
                onChanged: (v) => setState(() => _selectedWorkerId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            KSpacing.vGapSm,

            // Item picker
            itemsAsync.when(
              data: (items) => DropdownButtonFormField<String>(
                initialValue: _selectedItemId,
                decoration: const InputDecoration(labelText: 'Raw Material to Dispatch *'),
                items: items.map((i) => DropdownMenuItem(
                      value: i['id']?.toString(),
                      child: Text('${i['name']} (${i['sku'] ?? "-"})'),
                    )).toList(),
                onChanged: (v) => setState(() => _selectedItemId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            KSpacing.vGapSm,

            Row(
              children: [
                Expanded(
                  child: KTextField(
                    label: 'Issued Quantity *',
                    controller: _qtyCtl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                KSpacing.hGapSm,
                Expanded(
                  child: KTextField(
                    label: 'Unit Valuation Rate (₹) *',
                    controller: _rateCtl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            KSpacing.vGapSm,

            KTextField(
              label: 'Nature of Processing',
              hint: 'e.g. Coating, Bottling, Fabrication',
              controller: _processCtl,
            ),
            KSpacing.vGapLg,

            KButton(
              label: _isSaving ? 'Issuing Challan...' : 'Issue Challan 45 & Dispatch',
              icon: Icons.outbox,
              isLoading: _isSaving,
              onPressed: _submit,
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}
