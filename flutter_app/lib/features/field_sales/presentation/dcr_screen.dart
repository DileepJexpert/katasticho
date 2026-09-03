import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_money.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../../../core/widgets/k_text_field.dart';
import '../data/field_sales_repository.dart';

class DcrScreen extends ConsumerStatefulWidget {
  const DcrScreen({super.key});

  @override
  ConsumerState<DcrScreen> createState() => _DcrScreenState();
}

class _DcrScreenState extends ConsumerState<DcrScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  String _workType = 'FIELD_WORK';
  final _remarksCtrl = TextEditingController();

  bool _isBuilding = false;
  Map<String, dynamic>? _previewDcr;

  bool _isLoadingHistory = false;
  List<Map<String, dynamic>> _myDcrs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _buildDcrPreview();
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Future<void> _buildDcrPreview() async {
    setState(() => _isBuilding = true);
    try {
      final repo = ref.read(fieldSalesRepositoryProvider);
      final dateStr = _formatDate(_selectedDate);
      final result = await repo.buildDcr(date: dateStr, workType: _workType);
      if (mounted) {
        setState(() {
          _previewDcr = result;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to compute DCR: ${ApiErrorParser.message(e)}'), backgroundColor: KColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isBuilding = false);
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final repo = ref.read(fieldSalesRepositoryProvider);
      final list = await repo.myDcrs();
      if (mounted) {
        setState(() {
          _myDcrs = list;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load DCR history: ${ApiErrorParser.message(e)}'), backgroundColor: KColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _submitDcr() async {
    try {
      final repo = ref.read(fieldSalesRepositoryProvider);
      final dateStr = _formatDate(_selectedDate);
      await repo.submitDcr(
        date: dateStr,
        workType: _workType,
        remarks: _remarksCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('DCR submitted successfully!'), backgroundColor: KColors.success),
        );
        _remarksCtrl.clear();
        await _loadHistory();
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: ${ApiErrorParser.message(e)}'), backgroundColor: KColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColors.bgApp,
      appBar: AppBar(
        title: Text('Daily Call Report (DCR)', style: KTypography.h3),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.edit_document), text: 'Submit Today DCR'),
            Tab(icon: Icon(Icons.history), text: 'Submission History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSubmitTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildSubmitTab() {
    return ListView(
      padding: const EdgeInsets.all(KSpacing.md),
      children: [
        // Date & Work Type Selector Card
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Report Date', style: KTypography.labelSmall),
                        const SizedBox(height: KSpacing.xs),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime.now().minusDays(30),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setState(() => _selectedDate = picked);
                              _buildDcrPreview();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: KColors.border),
                              borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formatDate(_selectedDate), style: KTypography.bodyMedium),
                                const Icon(Icons.calendar_today, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: KSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Work Type', style: KTypography.labelSmall),
                        const SizedBox(height: KSpacing.xs),
                        DropdownButtonFormField<String>(
                          initialValue: _workType,
                          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'FIELD_WORK', child: Text('Field Work (Doctor/Chemist)')),
                            DropdownMenuItem(value: 'TRANSIT', child: Text('Transit / Outstation')),
                            DropdownMenuItem(value: 'CONFERENCE', child: Text('Conference / CME')),
                            DropdownMenuItem(value: 'HEADQUARTERS', child: Text('HQ Meeting')),
                            DropdownMenuItem(value: 'LEAVE', child: Text('Leave')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _workType = val);
                              _buildDcrPreview();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: KSpacing.md),

        // Auto-aggregated Call Summary
        if (_isBuilding)
          const Center(child: Padding(padding: EdgeInsets.all(32), child: KLoading()))
        else if (_previewDcr != null) ...[
          Text('Call Summary & Performance', style: KTypography.h3),
          const SizedBox(height: KSpacing.sm),
          Row(
            children: [
              Expanded(child: _buildMetricCard('Doctor Calls', '${_previewDcr!['doctorCalls'] ?? 0}', Icons.medical_services_outlined, KColors.primary)),
              const SizedBox(width: KSpacing.sm),
              Expanded(child: _buildMetricCard('Chemist Calls', '${_previewDcr!['chemistCalls'] ?? 0}', Icons.local_pharmacy_outlined, KColors.info)),
              const SizedBox(width: KSpacing.sm),
              Expanded(child: _buildMetricCard('Stockist Calls', '${_previewDcr!['stockistCalls'] ?? 0}', Icons.storefront_outlined, KColors.secondary)),
              const SizedBox(width: KSpacing.sm),
              Expanded(child: _buildMetricCard('Total Calls', '${_previewDcr!['totalCalls'] ?? 0}', Icons.call_made_outlined, KColors.success)),
            ],
          ),
          const SizedBox(height: KSpacing.sm),
          Row(
            children: [
              Expanded(child: _buildMetricCard('Samples Given', '${_previewDcr!['samplesIssued'] ?? 0} units', Icons.inventory_2_outlined, KColors.warning)),
              const SizedBox(width: KSpacing.sm),
              Expanded(child: _buildMetricCard('Gifts Given', '${_previewDcr!['giftsIssued'] ?? 0} units', Icons.card_giftcard_outlined, KColors.textSecondary)),
              const SizedBox(width: KSpacing.sm),
              Expanded(
                child: KCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Orders Booked', style: KTypography.caption.copyWith(color: KColors.textSecondary)),
                      const SizedBox(height: 4),
                      KMoney(
                        (_previewDcr!['orderValue'] as num?)?.toDouble() ?? 0.0,
                        style: KTypography.h3.copyWith(fontWeight: FontWeight.w700, color: KColors.success),
                      ),
                      Text('${_previewDcr!['ordersBooked'] ?? 0} POs collected', style: KTypography.caption.copyWith(color: KColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpacing.md),

          // Remarks & Submission
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KTextField(
                  label: 'Manager Remarks / Key Learnings',
                  controller: _remarksCtrl,
                  hint: 'e.g. Completed all planned morning hospital calls. Joint work with ABM went well.',
                  maxLines: 3,
                ),
                const SizedBox(height: KSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    KButton(
                      label: 'Re-compute Summary',
                      icon: Icons.refresh,
                      variant: KButtonVariant.secondary,
                      onPressed: _buildDcrPreview,
                    ),
                    const SizedBox(width: KSpacing.sm),
                    KButton(
                      label: 'Submit DCR to Manager',
                      icon: Icons.send,
                      onPressed: _submitDcr,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: KSpacing.xxl),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: KTypography.caption.copyWith(color: KColors.textSecondary)),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: KTypography.h3.copyWith(fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_isLoadingHistory) {
      return const Center(child: KLoading());
    }
    if (_myDcrs.isEmpty) {
      return const Center(child: Text('No previous DCR submissions found.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(KSpacing.md),
      itemCount: _myDcrs.length,
      separatorBuilder: (_, __) => const SizedBox(height: KSpacing.sm),
      itemBuilder: (context, index) {
        final dcr = _myDcrs[index];
        final date = dcr['reportDate']?.toString() ?? '-';
        final status = dcr['status']?.toString() ?? 'DRAFT';
        final calls = dcr['totalCalls'] ?? 0;
        final docCalls = dcr['doctorCalls'] ?? 0;
        final chemistCalls = dcr['chemistCalls'] ?? 0;
        final samples = dcr['samplesIssued'] ?? 0;
        final orderVal = (dcr['orderValue'] as num?)?.toDouble() ?? 0.0;

        return KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('DCR for $date', style: KTypography.h4.copyWith(fontWeight: FontWeight.w700)),
                  KStatusChip(status: status),
                ],
              ),
              const SizedBox(height: KSpacing.xs),
              Text(
                'Calls: $calls total ($docCalls Doctors, $chemistCalls Chemists) • Samples: $samples • Orders: ₹${orderVal.toStringAsFixed(0)}',
                style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
              ),
              if (dcr['remarks'] != null && dcr['remarks'].toString().isNotEmpty) ...[
                const SizedBox(height: KSpacing.xs),
                Text('Notes: ${dcr['remarks']}', style: KTypography.caption.copyWith(fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        );
      },
    );
  }
}

extension DateTimeMinus on DateTime {
  DateTime minusDays(int days) => subtract(Duration(days: days));
}
