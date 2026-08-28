import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_compact_row.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../../../core/widgets/k_text_field.dart';

/// HR Help Desk — Core HR module.
/// Tabs: My Tickets (raise + list), HR Inbox (open tickets, manage).
class HelpDeskScreen extends ConsumerStatefulWidget {
  const HelpDeskScreen({super.key});

  @override
  ConsumerState<HelpDeskScreen> createState() => _HelpDeskScreenState();
}

class _HelpDeskScreenState extends ConsumerState<HelpDeskScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _mine = [];
  List<Map<String, dynamic>> _open = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _list(Object? d) =>
      (d as List?)?.cast<Map<String, dynamic>>() ?? [];

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = ref.read(apiClientProvider);
    try {
      final results = await Future.wait([
        api.get(ApiConfig.hrHelpdeskMine),
        api.get(ApiConfig.hrHelpdeskOpen),
      ]);
      if (!mounted) return;
      setState(() {
        _mine = _list(results[0].data['data']);
        _open = _list(results[1].data['data']);
      });
    } catch (e) {
      _toast('Failed to load tickets: ${ApiErrorParser.message(e)}', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String m, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: isError ? KColors.error : null,
      ),
    );
  }

  Future<void> _raise() async {
    final subject = TextEditingController();
    final desc = TextEditingController();
    String category = 'GENERAL';
    String priority = 'NORMAL';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Raise HR Help Desk Ticket', style: KTypography.titleLarge),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  KCompactRow(children: [
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(
                        labelText: 'Ticket Category',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'GENERAL', child: Text('General Query')),
                        DropdownMenuItem(value: 'PAYROLL', child: Text('Payroll / Salary')),
                        DropdownMenuItem(value: 'LEAVE', child: Text('Leave / Attendance')),
                        DropdownMenuItem(value: 'DOCUMENT', child: Text('Document / Letter')),
                        DropdownMenuItem(value: 'GRIEVANCE', child: Text('HR Grievance')),
                      ],
                      onChanged: (v) => setD(() => category = v ?? 'GENERAL'),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: priority,
                      decoration: const InputDecoration(
                        labelText: 'Priority Level',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'LOW', child: Text('Low')),
                        DropdownMenuItem(value: 'NORMAL', child: Text('Normal')),
                        DropdownMenuItem(value: 'HIGH', child: Text('High / Urgent')),
                      ],
                      onChanged: (v) => setD(() => priority = v ?? 'NORMAL'),
                    ),
                  ]),
                  KSpacing.vGapSm,
                  KTextField(
                    controller: subject,
                    label: 'Subject / Summary *',
                    hint: 'e.g. Discrepancy in monthly payslip reimbursement',
                  ),
                  KSpacing.vGapSm,
                  KTextField(
                    controller: desc,
                    maxLines: 3,
                    label: 'Detailed Description',
                    hint: 'Provide full background context and details',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            KButton.primary(
              icon: Icons.send_rounded,
              label: 'Submit Ticket',
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );
    if (ok != true || subject.text.trim().isEmpty) return;
    try {
      await ref.read(apiClientProvider).post(ApiConfig.hrHelpdeskTickets, data: {
        'category': category,
        'subject': subject.text.trim(),
        'description': desc.text.trim(),
        'priority': priority,
      });
      _toast('Helpdesk ticket raised successfully');
      await _load();
    } catch (e) {
      _toast('Failed: ${ApiErrorParser.message(e)}', isError: true);
    }
  }

  Future<void> _openTicket(Map<String, dynamic> t, {required bool hrView}) async {
    final id = t['id'].toString();
    List<Map<String, dynamic>> comments = [];
    try {
      final res = await ref.read(apiClientProvider).get(ApiConfig.hrHelpdeskTicket(id));
      comments = _list((res.data['data'] as Map?)?['comments']);
    } catch (_) {}
    if (!mounted) return;

    final commentCtl = TextEditingController();
    final cs = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(KSpacing.radiusLg)),
        ),
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('${t['subject']}', style: KTypography.titleLarge),
                  ),
                  KStatusChip(status: t['status']?.toString() ?? 'OPEN'),
                ],
              ),
              KSpacing.vGapXs,
              Row(
                children: [
                  Text('Category: ', style: KTypography.caption),
                  Text('${t['category']}', style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w600)),
                  KSpacing.hGapMd,
                  Text('Priority: ', style: KTypography.caption),
                  Text(
                    '${t['priority']}',
                    style: KTypography.mono(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: t['priority'] == 'HIGH' ? KColors.error : cs.primary,
                    ),
                  ),
                ],
              ),
              if ((t['description'] as String?)?.isNotEmpty == true) ...[
                KSpacing.vGapMd,
                KCard(
                  child: Text(t['description'], style: KTypography.bodyMedium),
                ),
              ],
              KSpacing.vGapMd,
              const Divider(height: 1),
              KSpacing.vGapSm,
              Text('Conversation History', style: KTypography.titleMedium),
              KSpacing.vGapSm,
              if (comments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('No comments recorded yet.', style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant)),
                )
              else
                ...comments.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.all(KSpacing.sm),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c['body']?.toString() ?? '', style: KTypography.bodyMedium),
                            if (c['createdAt'] != null) ...[
                              KSpacing.vGapXs,
                              Text('${c['createdAt']}', style: KTypography.caption.copyWith(color: cs.onSurfaceVariant)),
                            ],
                          ],
                        ),
                      ),
                    )),
              KSpacing.vGapSm,
              Row(
                children: [
                  Expanded(
                    child: KTextField(
                      controller: commentCtl,
                      hint: 'Type a reply or update message…',
                      label: '',
                    ),
                  ),
                  KSpacing.hGapSm,
                  KButton.primary(
                    icon: Icons.send_rounded,
                    label: 'Reply',
                    onPressed: () async {
                      if (commentCtl.text.trim().isEmpty) return;
                      try {
                        await ref.read(apiClientProvider).post(
                            ApiConfig.hrHelpdeskComments(id),
                            data: {'body': commentCtl.text.trim()});
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        _toast('Failed: ${ApiErrorParser.message(e)}', isError: true);
                      }
                    },
                  ),
                ],
              ),
              if (hrView) ...[
                KSpacing.vGapMd,
                const Divider(height: 1),
                KSpacing.vGapSm,
                Text('Update Status (HR Action)', style: KTypography.labelSmall.copyWith(color: cs.onSurfaceVariant)),
                KSpacing.vGapSm,
                Wrap(
                  spacing: KSpacing.sm,
                  children: [
                    for (final s in const ['IN_PROGRESS', 'RESOLVED', 'CLOSED'])
                      KButton.outlined(
                        size: KButtonSize.small,
                        onPressed: () async {
                          try {
                            await ref.read(apiClientProvider).post(
                                ApiConfig.hrHelpdeskStatus(id), data: {'status': s});
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            _toast('Failed: ${ApiErrorParser.message(e)}', isError: true);
                          }
                        },
                        label: s.replaceAll('_', ' '),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final openCount = _open.length;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('HR Help Desk & Support'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          bottom: TabBar(
            tabs: [
              const Tab(text: 'My Tickets'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('HR Inbox'),
                    if (openCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: KColors.warning,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$openCount',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: KLoading(message: 'Loading help desk tickets...'))
            : TabBarView(children: [
                _ticketList(_mine, hrView: false, empty: 'You have not raised any help desk tickets.'),
                _ticketList(_open, hrView: true, empty: 'No open employee tickets in the HR queue.'),
              ]),
      ),
    );
  }

  Widget _ticketList(List<Map<String, dynamic>> items, {required bool hrView, required String empty}) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: KSpacing.pagePadding,
      children: [
        if (!hrView)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Support & Grievances', style: KTypography.h3),
              KButton.primary(
                label: 'Raise Ticket',
                icon: Icons.add_comment_rounded,
                size: KButtonSize.small,
                onPressed: _raise,
              ),
            ],
          ),
        if (!hrView) KSpacing.vGapMd,
        if (items.isEmpty)
          KEmptyState(
            icon: Icons.support_agent_outlined,
            title: 'No Tickets Found',
            subtitle: empty,
          )
        else
          ...items.map((t) {
            final status = t['status']?.toString() ?? 'OPEN';
            final priority = t['priority']?.toString() ?? 'NORMAL';
            return KCard(
              margin: const EdgeInsets.only(bottom: KSpacing.sm),
              padding: const EdgeInsets.all(KSpacing.md),
              onTap: () => _openTicket(t, hrView: hrView),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t['subject']?.toString() ?? 'Ticket',
                          style: KTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                        ),
                        KSpacing.vGapXs,
                        Row(
                          children: [
                            Text('Category: ', style: KTypography.caption.copyWith(color: cs.onSurfaceVariant)),
                            Text('${t['category'] ?? 'General'}', style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w600)),
                            KSpacing.hGapMd,
                            Text('Priority: ', style: KTypography.caption.copyWith(color: cs.onSurfaceVariant)),
                            Text(
                              priority,
                              style: KTypography.mono(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: priority == 'HIGH' ? KColors.error : cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  KStatusChip(status: status),
                  KSpacing.hGapSm,
                  Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                ],
              ),
            );
          }),
      ],
    );
  }
}
