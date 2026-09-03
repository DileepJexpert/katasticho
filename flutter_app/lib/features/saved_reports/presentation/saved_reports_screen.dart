import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/saved_report_dto.dart';
import '../data/saved_report_providers.dart';
import '../data/saved_report_repository.dart';
import 'report_builder_screen.dart';
import 'report_schedule_sheet.dart';

class SavedReportsScreen extends ConsumerWidget {
  const SavedReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(savedReportListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Reports'),
        actions: [
          KButton.primary(
            label: 'New Report',
            icon: Icons.add,
            onPressed: () async {
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const ReportBuilderScreen()),
              );
              if (created == true) ref.invalidate(savedReportListProvider);
            },
          ),
          KSpacing.hGapSm,
        ],
      ),
      body: Column(
        children: [
          KListPageHeader(
            title: 'Saved Reports',
            searchHint: 'Search saved reports…',
          ),
          Expanded(
            child: listAsync.when(
              loading: () => const KLoading(message: 'Loading saved reports…'),
              error: (e, _) => KErrorView(
                message: 'Failed to load saved reports',
                onRetry: () => ref.invalidate(savedReportListProvider),
              ),
              data: (data) {
                final raw = data['data'];
                final items = raw is List ? raw : (raw as Map?)?.values.expand((v) => v is List ? v : [v]).toList() ?? [];
                if (items.isEmpty) {
                  return KEmptyState(
                    icon: Icons.analytics_outlined,
                    title: 'No saved reports yet',
                    subtitle: 'Create a custom report to save column selections,\nfilters and schedule automated email delivery.',
                    actionLabel: 'Create First Report',
                    onAction: () async {
                      final created = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(builder: (_) => const ReportBuilderScreen()),
                      );
                      if (created == true) ref.invalidate(savedReportListProvider);
                    },
                  );
                }
                final reports = items.whereType<Map<String, dynamic>>().map(SavedReportDto.new).toList();
                return ListView.separated(
                  padding: KSpacing.pagePadding,
                  itemCount: reports.length,
                  separatorBuilder: (_, __) => KSpacing.vGapSm,
                  itemBuilder: (context, i) => _SavedReportCard(
                    report: reports[i],
                    onDeleted: () => ref.invalidate(savedReportListProvider),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedReportCard extends ConsumerWidget {
  final SavedReportDto report;
  final VoidCallback onDeleted;

  const _SavedReportCard({required this.report, required this.onDeleted});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final option = BaseReportOption.all.where((o) => o.key == report.baseReportKey).firstOrNull;

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: KColors.primary.withValues(alpha: 0.1),
                  borderRadius: KSpacing.borderRadiusMd,
                ),
                child: const Icon(Icons.analytics_outlined, color: KColors.primary, size: 20),
              ),
              KSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(report.name, style: KTypography.labelLarge),
                    if (report.description.isNotEmpty)
                      Text(report.description, style: KTypography.bodySmall.copyWith(color: KColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(option?.label ?? report.baseReportKey, style: KTypography.bodySmall.copyWith(color: KColors.textHint)),
                  ],
                ),
              ),
              if (report.isPublic)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: KColors.info.withValues(alpha: 0.12),
                    borderRadius: KSpacing.borderRadiusXl,
                  ),
                  child: Text('Public', style: KTypography.labelSmall.copyWith(color: KColors.info, fontWeight: FontWeight.w700)),
                ),
              PopupMenuButton<String>(
                onSelected: (v) => _handleAction(context, ref, v),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'run', child: Row(children: [Icon(Icons.play_arrow_outlined, size: 18), SizedBox(width: 8), Text('Run Report')])),
                  const PopupMenuItem(value: 'schedule', child: Row(children: [Icon(Icons.schedule_outlined, size: 18), SizedBox(width: 8), Text('Manage Schedules')])),
                  const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit')])),
                  const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: KColors.error), SizedBox(width: 8), Text('Delete', style: TextStyle(color: KColors.error))])),
                ],
              ),
            ],
          ),
          if (report.tags.isNotEmpty) ...[
            KSpacing.vGapSm,
            Wrap(
              spacing: 4,
              children: report.tags.map((t) => Chip(
                label: Text(t, style: KTypography.labelSmall),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )).toList(),
            ),
          ],
          KSpacing.vGapSm,
          Text('${report.columnKeys.length} column${report.columnKeys.length == 1 ? '' : 's'} selected',
              style: KTypography.bodySmall.copyWith(color: KColors.textHint)),
        ],
      ),
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) async {
    switch (action) {
      case 'run':
        final option = BaseReportOption.all.where((o) => o.key == report.baseReportKey).firstOrNull;
        final dateRange = option?.hasDateRange ?? true;
        context.push(
          '/reports/operational/${report.baseReportKey}?title=${Uri.encodeQueryComponent(report.name)}&dateRange=$dateRange',
        );
        break;
      case 'schedule':
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => ReportScheduleSheet(report: report),
        );
        break;
      case 'edit':
        final updated = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => ReportBuilderScreen(editing: report)),
        );
        if (updated == true) ref.invalidate(savedReportListProvider);
        break;
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete report?'),
            content: Text('Are you sure you want to delete "${report.name}"? This also deletes its email schedules.'),
            actions: [
              KButton.outlined(label: 'Cancel', onPressed: () => Navigator.pop(ctx, false)),
              KSpacing.hGapSm,
              KButton.danger(label: 'Delete', onPressed: () => Navigator.pop(ctx, true)),
            ],
          ),
        );
        if (confirm == true) {
          try {
            await ref.read(savedReportRepositoryProvider).delete(report.id);
            onDeleted();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report deleted')));
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: KColors.error));
            }
          }
        }
        break;
    }
  }
}
