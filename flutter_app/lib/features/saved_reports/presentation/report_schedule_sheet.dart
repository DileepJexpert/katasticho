import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/saved_report_dto.dart';
import '../data/saved_report_repository.dart';

class ReportScheduleSheet extends ConsumerStatefulWidget {
  final SavedReportDto report;
  const ReportScheduleSheet({super.key, required this.report});

  @override
  ConsumerState<ReportScheduleSheet> createState() => _ReportScheduleSheetState();
}

class _ReportScheduleSheetState extends ConsumerState<ReportScheduleSheet> {
  List<ReportScheduleDto> _schedules = [];
  bool _loading = true;

  // new schedule form fields
  String _frequency = 'DAILY';
  int _dayOfWeek = 1;
  int _dayOfMonth = 1;
  TimeOfDay _sendTime = const TimeOfDay(hour: 8, minute: 0);
  final _emailsCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  bool _adding = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _emailsCtrl.dispose();
    _subjectCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(savedReportRepositoryProvider);
      final res = await repo.listSchedules(widget.report.id);
      final raw = res['data'];
      final list = raw is List ? raw : [];
      setState(() {
        _schedules = list.whereType<Map<String, dynamic>>().map(ReportScheduleDto.new).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _addSchedule() async {
    final emails = _emailsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.contains('@')).toList();
    if (emails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter at least one valid email')));
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(savedReportRepositoryProvider);
      final sendTimeStr = '${_sendTime.hour.toString().padLeft(2, '0')}:${_sendTime.minute.toString().padLeft(2, '0')}';
      await repo.addSchedule(
        widget.report.id,
        frequency: _frequency,
        dayOfWeek: _frequency == 'WEEKLY' ? _dayOfWeek : null,
        dayOfMonth: _frequency == 'MONTHLY' ? _dayOfMonth : null,
        sendTime: sendTimeStr,
        recipientEmails: emails,
        subjectTemplate: _subjectCtrl.text.trim().isNotEmpty ? _subjectCtrl.text.trim() : null,
      );
      _emailsCtrl.clear();
      _subjectCtrl.clear();
      setState(() { _adding = false; _saving = false; });
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: KColors.error));
      }
      setState(() => _saving = false);
    }
  }

  Future<void> _deleteSchedule(ReportScheduleDto s) async {
    try {
      await ref.read(savedReportRepositoryProvider).deleteSchedule(widget.report.id, s.id);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: KColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: KColors.border, borderRadius: KSpacing.borderRadiusXl)),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
              child: Row(
                children: [
                  const Icon(Icons.schedule_outlined, color: KColors.primary, size: 20),
                  KSpacing.hGapSm,
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Email Schedules', style: KTypography.h2),
                      Text(widget.report.name, style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                    ],
                  )),
                  KButton.outlined(
                    label: _adding ? 'Cancel' : 'Add Schedule',
                    icon: _adding ? null : Icons.add,
                    onPressed: () => setState(() => _adding = !_adding),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),

            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: KSpacing.pagePadding,
                children: [
                  // Add schedule form
                  if (_adding) ...[
                    KCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('New Schedule', style: KTypography.labelLarge),
                          KSpacing.vGapMd,

                          // Frequency
                          Text('Frequency', style: KTypography.labelMedium),
                          KSpacing.vGapXs,
                          Row(
                            children: ['DAILY', 'WEEKLY', 'MONTHLY'].map((f) {
                              final sel = _frequency == f;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: InkWell(
                                  onTap: () => setState(() => _frequency = f),
                                  borderRadius: KSpacing.borderRadiusMd,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: sel ? KColors.primary : KColors.surface,
                                      border: Border.all(color: sel ? KColors.primary : KColors.border),
                                      borderRadius: KSpacing.borderRadiusMd,
                                    ),
                                    child: Text(f, style: KTypography.labelSmall.copyWith(color: sel ? Colors.white : KColors.textPrimary)),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          if (_frequency == 'WEEKLY') ...[
                            KSpacing.vGapMd,
                            Text('Day of Week', style: KTypography.labelMedium),
                            KSpacing.vGapXs,
                            DropdownButtonFormField<int>(
                              initialValue: _dayOfWeek,
                              onChanged: (v) => setState(() => _dayOfWeek = v!),
                              items: const [
                                DropdownMenuItem(value: 1, child: Text('Monday')),
                                DropdownMenuItem(value: 2, child: Text('Tuesday')),
                                DropdownMenuItem(value: 3, child: Text('Wednesday')),
                                DropdownMenuItem(value: 4, child: Text('Thursday')),
                                DropdownMenuItem(value: 5, child: Text('Friday')),
                                DropdownMenuItem(value: 6, child: Text('Saturday')),
                                DropdownMenuItem(value: 7, child: Text('Sunday')),
                              ],
                              decoration: const InputDecoration(border: OutlineInputBorder()),
                            ),
                          ],

                          if (_frequency == 'MONTHLY') ...[
                            KSpacing.vGapMd,
                            Text('Day of Month', style: KTypography.labelMedium),
                            KSpacing.vGapXs,
                            DropdownButtonFormField<int>(
                              initialValue: _dayOfMonth,
                              onChanged: (v) => setState(() => _dayOfMonth = v!),
                              items: List.generate(28, (i) => i + 1)
                                  .map((d) => DropdownMenuItem(value: d, child: Text('Day $d')))
                                  .toList(),
                              decoration: const InputDecoration(border: OutlineInputBorder()),
                            ),
                          ],

                          KSpacing.vGapMd,
                          Text('Send Time', style: KTypography.labelMedium),
                          KSpacing.vGapXs,
                          InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(context: context, initialTime: _sendTime);
                              if (picked != null) setState(() => _sendTime = picked);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(border: Border.all(color: KColors.border), borderRadius: KSpacing.borderRadiusMd),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time, size: 18, color: KColors.textSecondary),
                                  KSpacing.hGapSm,
                                  Text(_sendTime.format(context), style: KTypography.bodyMedium),
                                ],
                              ),
                            ),
                          ),

                          KSpacing.vGapMd,
                          KTextField(
                            controller: _emailsCtrl,
                            label: 'Recipient Emails',
                            hint: 'owner@example.com, finance@example.com',
                          ),
                          KSpacing.vGapMd,
                          KTextField(
                            controller: _subjectCtrl,
                            label: 'Email Subject (optional)',
                            hint: 'Monthly Sales Summary � {date}',
                          ),
                          KSpacing.vGapMd,
                          KButton.primary(
                            label: _saving ? 'Adding�' : 'Add Schedule',
                            icon: Icons.add,
                            onPressed: _saving ? null : _addSchedule,
                          ),
                        ],
                      ),
                    ),
                    KSpacing.vGapMd,
                  ],

                  // Schedules list
                  if (_loading)
                    const KLoading(message: 'Loading schedules�')
                  else if (_schedules.isEmpty && !_adding)
                    KEmptyState(
                      icon: Icons.schedule_outlined,
                      title: 'No schedules yet',
                      subtitle: 'Add a schedule to automatically email this report.',
                    )
                  else
                    ..._schedules.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: KSpacing.sm),
                      child: KCard(
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: s.active ? KColors.success.withValues(alpha: 0.1) : KColors.border,
                                borderRadius: KSpacing.borderRadiusMd,
                              ),
                              child: Icon(Icons.email_outlined,
                                  size: 18,
                                  color: s.active ? KColors.success : KColors.textHint),
                            ),
                            KSpacing.hGapMd,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.frequencyLabel, style: KTypography.labelMedium),
                                  Text('at ${s.sendTime}  �  ${s.recipientEmails.length} recipient${s.recipientEmails.length == 1 ? '' : 's'}',
                                      style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                                  if (s.recipientEmails.isNotEmpty)
                                    Text(s.recipientEmails.take(2).join(', ') + (s.recipientEmails.length > 2 ? '�' : ''),
                                        style: KTypography.mono(fontSize: 11, color: KColors.textHint)),
                                ],
                              ),
                            ),
                            KStatusChip(status: s.active ? 'active' : 'inactive'),
                            KSpacing.hGapSm,
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: KColors.error),
                              onPressed: () => _deleteSchedule(s),
                            ),
                          ],
                        ),
                      ),
                    )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
