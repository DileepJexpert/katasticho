import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../data/putaway_repository.dart';

class WarehousePutawayListScreen extends ConsumerStatefulWidget {
  const WarehousePutawayListScreen({super.key});

  @override
  ConsumerState<WarehousePutawayListScreen> createState() => _WarehousePutawayListScreenState();
}

class _WarehousePutawayListScreenState extends ConsumerState<WarehousePutawayListScreen> {
  String _selectedStatus = 'ALL';
  List<PutawayTaskDto> _tasks = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(putawayRepositoryProvider);
      final tasks = await repo.listTasks(status: _selectedStatus);
      if (mounted) setState(() => _tasks = tasks);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load putaway tasks: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Warehouse Putaway & Staging'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTasks,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Bar
          Container(
            color: KColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['ALL', 'PENDING', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'].map((s) {
                  final isSel = _selectedStatus == s;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(s.replaceAll('_', ' ')),
                      selected: isSel,
                      onSelected: (_) {
                        setState(() => _selectedStatus = s);
                        _loadTasks();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1),

          // Content Area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error!, style: const TextStyle(color: KColors.error)),
                            KSpacing.vGapMd,
                            KButton.secondary(label: 'Retry', onPressed: _loadTasks),
                          ],
                        ),
                      )
                    : _tasks.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.move_to_inbox_outlined, size: 64, color: KColors.textHint),
                                KSpacing.vGapMd,
                                Text('No putaway tasks found', style: KTypography.h3),
                                KSpacing.vGapXs,
                                Text('Stock received via GRN will generate putaway staging tasks here.',
                                    style: KTypography.bodySmall.copyWith(color: KColors.textHint)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: KSpacing.pagePadding,
                            itemCount: _tasks.length,
                            separatorBuilder: (_, __) => KSpacing.vGapMd,
                            itemBuilder: (context, index) {
                              final task = _tasks[index];
                              return _buildTaskCard(task);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(PutawayTaskDto task) {
    final confirmedCount = task.lines.where((l) => l.status == 'CONFIRMED').length;
    final totalLines = task.lines.length;

    return KCard(
      onTap: () => context.push('/inventory/putaway-tasks/${task.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, color: KColors.primary, size: 20),
                  KSpacing.hGapXs,
                  Text(task.taskNumber, style: KTypography.labelLarge.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              KStatusChip(status: task.status),
            ],
          ),
          KSpacing.vGapSm,
          Row(
            children: [
              const Icon(Icons.dock_outlined, size: 16, color: KColors.textSecondary),
              KSpacing.hGapXs,
              Text('Source: ${task.sourceLocation}', style: KTypography.bodySmall),
              KSpacing.hGapLg,
              const Icon(Icons.checklist_outlined, size: 16, color: KColors.textSecondary),
              KSpacing.hGapXs,
              Text('Progress: $confirmedCount / $totalLines lines confirmed', style: KTypography.bodySmall),
            ],
          ),
          if (task.notes != null && task.notes!.isNotEmpty) ...[
            KSpacing.vGapXs,
            Text(task.notes!, style: KTypography.bodySmall.copyWith(color: KColors.textHint, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}