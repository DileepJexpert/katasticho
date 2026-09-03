import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../../../core/widgets/k_text_field.dart';
import '../data/field_sales_repository.dart';

class TourPlanScreen extends ConsumerStatefulWidget {
  const TourPlanScreen({super.key});

  @override
  ConsumerState<TourPlanScreen> createState() => _TourPlanScreenState();
}

class _TourPlanScreenState extends ConsumerState<TourPlanScreen> {
  bool _isLoading = true;
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  Map<String, dynamic>? _currentPlan;
  List<Map<String, dynamic>> _entries = [];
  List<Map<String, dynamic>> _beats = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _formatMonth(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-01';
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(fieldSalesRepositoryProvider);
      final monthStr = _formatMonth(_currentMonth);

      final results = await Future.wait([
        repo.myTourPlans(),
        repo.listBeats(size: 100),
      ]);

      final allPlans = (results[0] as List).whereType<Map<String, dynamic>>().toList();
      _beats = (results[1] as List).whereType<Map<String, dynamic>>().toList();

      final matching = allPlans.where((p) => p['planMonth']?.toString().startsWith(monthStr.substring(0, 7)) == true).toList();

      if (matching.isNotEmpty) {
        final planId = matching.first['id'].toString();
        final fullPlan = await repo.getTourPlan(planId);
        _currentPlan = fullPlan['plan'] as Map<String, dynamic>? ?? matching.first;
        _entries = (fullPlan['entries'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
      } else {
        _currentPlan = null;
        _entries = [];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load tour plan: ${ApiErrorParser.message(e)}'), backgroundColor: KColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createPlan() async {
    try {
      final repo = ref.read(fieldSalesRepositoryProvider);
      final monthStr = _formatMonth(_currentMonth);
      await repo.createTourPlan(monthStr);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tour plan created successfully!'), backgroundColor: KColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create tour plan: ${ApiErrorParser.message(e)}'), backgroundColor: KColors.error),
        );
      }
    }
  }

  Future<void> _submitPlan() async {
    if (_currentPlan == null) return;
    final planId = _currentPlan!['id'].toString();
    try {
      final repo = ref.read(fieldSalesRepositoryProvider);
      await repo.submitTourPlan(planId);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tour plan submitted for manager approval!'), backgroundColor: KColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: ${ApiErrorParser.message(e)}'), backgroundColor: KColors.error),
        );
      }
    }
  }

  void _showAddEntryDialog([int? dayNumber]) {
    if (_currentPlan == null) return;
    final planId = _currentPlan!['id'].toString();

    final selectedDay = dayNumber ?? DateTime.now().day;
    DateTime planDate = DateTime(_currentMonth.year, _currentMonth.month, selectedDay);
    String activityType = 'FIELD_WORK';
    String? selectedBeatId = _beats.isNotEmpty ? _beats.first['id'].toString() : null;
    final areaCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text('Plan Day ${planDate.day}/${planDate.month}', style: KTypography.h3),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Activity Type', style: KTypography.labelSmall),
                const SizedBox(height: KSpacing.xs),
                DropdownButtonFormField<String>(
                  initialValue: activityType,
                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'FIELD_WORK', child: Text('Field Work (Doctor/Chemist Calls)')),
                    DropdownMenuItem(value: 'TRANSIT', child: Text('Transit / Outstation Travel')),
                    DropdownMenuItem(value: 'CONFERENCE', child: Text('CME / Medical Conference')),
                    DropdownMenuItem(value: 'HEADQUARTERS', child: Text('HQ Review Meeting')),
                    DropdownMenuItem(value: 'LEAVE', child: Text('Leave / Non-Working')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDlgState(() => activityType = val);
                  },
                ),
                const SizedBox(height: KSpacing.md),
                if (activityType == 'FIELD_WORK') ...[
                  Text('Target Beat', style: KTypography.labelSmall),
                  const SizedBox(height: KSpacing.xs),
                  DropdownButtonFormField<String>(
                    initialValue: selectedBeatId,
                    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                    items: _beats.map((b) => DropdownMenuItem(
                      value: b['id'].toString(),
                      child: Text(b['name']?.toString() ?? 'Unnamed Beat'),
                    )).toList(),
                    onChanged: (val) => setDlgState(() => selectedBeatId = val),
                  ),
                  const SizedBox(height: KSpacing.md),
                  KTextField(
                    label: 'Target Area / Hospital Hub',
                    controller: areaCtrl,
                    hint: 'e.g. Civil Hospital & Clinic Area',
                  ),
                  const SizedBox(height: KSpacing.md),
                ],
                KTextField(
                  label: 'Objectives / Detailing Focus',
                  controller: notesCtrl,
                  hint: 'e.g. Focus on launching new Azithral syrup formulation',
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            KButton(
              label: 'Save Day Entry',
              size: KButtonSize.small,
              onPressed: () async {
                try {
                  final repo = ref.read(fieldSalesRepositoryProvider);
                  final dateStr = '${planDate.year}-${planDate.month.toString().padLeft(2, '0')}-${planDate.day.toString().padLeft(2, '0')}';
                  await repo.addTourPlanEntry(planId, {
                    'planDate': dateStr,
                    'activityType': activityType,
                    if (activityType == 'FIELD_WORK') 'beatId': selectedBeatId,
                    if (areaCtrl.text.isNotEmpty) 'area': areaCtrl.text.trim(),
                    if (notesCtrl.text.isNotEmpty) 'notes': notesCtrl.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadData();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to save entry: ${ApiErrorParser.message(e)}'), backgroundColor: KColors.error),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthName = _getMonthName(_currentMonth.month);
    final daysInMonth = DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);
    final status = _currentPlan?['status']?.toString() ?? 'NO_PLAN';
    final isEditable = status == 'DRAFT' || status == 'REJECTED';

    return Scaffold(
      backgroundColor: KColors.bgApp,
      appBar: AppBar(
        title: Text('Monthly Tour Plan (MTP) — $monthName ${_currentMonth.year}', style: KTypography.h3),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
              });
              _loadData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
              });
              _loadData();
            },
          ),
          const SizedBox(width: KSpacing.sm),
        ],
      ),
      body: _isLoading
          ? const Center(child: KLoading())
          : _currentPlan == null
              ? Center(
                  child: KEmptyState(
                    icon: Icons.calendar_month_outlined,
                    title: 'No Tour Plan for $monthName ${_currentMonth.year}',
                    subtitle: 'Create a monthly tour plan to schedule your field visits and doctor detailing beats.',
                    actionLabel: 'Create MTP Draft',
                    onAction: _createPlan,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(KSpacing.md),
                  children: [
                    // Header Status Card
                    KCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('$monthName ${_currentMonth.year} Plan', style: KTypography.h3),
                                  const SizedBox(width: KSpacing.sm),
                                  KStatusChip(status: status),
                                ],
                              ),
                              const SizedBox(height: KSpacing.xs),
                              Text(
                                '${_entries.length} of $daysInMonth days scheduled',
                                style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                              ),
                            ],
                          ),
                          if (isEditable)
                            Row(
                              children: [
                                KButton(
                                  label: 'Add Day Entry',
                                  icon: Icons.add,
                                  variant: KButtonVariant.secondary,
                                  size: KButtonSize.small,
                                  onPressed: () => _showAddEntryDialog(),
                                ),
                                const SizedBox(width: KSpacing.sm),
                                KButton(
                                  label: 'Submit for Approval',
                                  icon: Icons.send,
                                  size: KButtonSize.small,
                                  onPressed: _entries.isNotEmpty ? _submitPlan : null,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: KSpacing.md),

                    // Calendar Schedule Grid / Table
                    KCard(
                      padding: EdgeInsets.zero,
                      child: Table(
                        columnWidths: const {
                          0: FixedColumnWidth(60),
                          1: FlexColumnWidth(2),
                          2: FlexColumnWidth(3),
                          3: FlexColumnWidth(3),
                          4: FixedColumnWidth(80),
                        },
                        children: [
                          TableRow(
                            decoration: const BoxDecoration(color: KColors.bgApp),
                            children: [
                              _tableCell('Date', isHeader: true),
                              _tableCell('Activity', isHeader: true),
                              _tableCell('Assigned Beat', isHeader: true),
                              _tableCell('Notes / Objectives', isHeader: true),
                              _tableCell('Action', isHeader: true),
                            ],
                          ),
                          ...List.generate(daysInMonth, (index) {
                            final day = index + 1;
                            final dateStr = '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                            final entry = _entries.where((e) => e['planDate']?.toString().startsWith(dateStr) == true).firstOrNull;
                            final dateObj = DateTime(_currentMonth.year, _currentMonth.month, day);
                            final isSunday = dateObj.weekday == DateTime.sunday;

                            return TableRow(
                              decoration: BoxDecoration(
                                color: isSunday ? KColors.bgApp.withValues(alpha: 0.5) : null,
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(KSpacing.sm),
                                  child: Text(
                                    '$day ${_getWeekdayShort(dateObj.weekday)}',
                                    style: KTypography.bodySmall.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: isSunday ? KColors.textSecondary : KColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(KSpacing.sm),
                                  child: entry != null
                                      ? KStatusChip(status: entry['activityType']?.toString().replaceAll('_', ' ') ?? 'FIELD WORK')
                                      : Text(isSunday ? 'Sunday' : 'Unplanned', style: KTypography.caption.copyWith(color: KColors.textSecondary)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(KSpacing.sm),
                                  child: Text(
                                    entry?['beatName']?.toString() ?? entry?['area']?.toString() ?? (isSunday ? '--' : '-'),
                                    style: KTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(KSpacing.sm),
                                  child: Text(
                                    entry?['notes']?.toString() ?? '-',
                                    style: KTypography.caption.copyWith(color: KColors.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(KSpacing.xs),
                                  child: isEditable
                                      ? IconButton(
                                          icon: Icon(entry != null ? Icons.edit_outlined : Icons.add_circle_outline, size: 18),
                                          onPressed: () => _showAddEntryDialog(day),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: KSpacing.xxl),
                  ],
                ),
    );
  }

  Widget _tableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.all(KSpacing.sm),
      child: Text(
        text,
        style: isHeader
            ? KTypography.caption.copyWith(fontWeight: FontWeight.w700, color: KColors.textSecondary)
            : KTypography.bodySmall,
      ),
    );
  }

  String _getMonthName(int month) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[month - 1];
  }

  String _getWeekdayShort(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }
}
