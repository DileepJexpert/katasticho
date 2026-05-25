import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../data/indent_repository.dart';

class IndentListScreen extends ConsumerStatefulWidget {
  const IndentListScreen({super.key});

  @override
  ConsumerState<IndentListScreen> createState() => _IndentListScreenState();
}

class _IndentListScreenState extends ConsumerState<IndentListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  static const _tabs = ['All', 'Pending', 'Ordered', 'Arrived', 'Fulfilled'];
  static const _statusFilter = [null, 'PENDING', 'ORDERED', 'ARRIVED', 'FULFILLED'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String? get _currentStatus => _statusFilter[_tabController.index];

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(indentListProvider(_currentStatus));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Indents'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await context.push<bool>('/indents/create');
          if (created == true) {
            ref.invalidate(indentListProvider);
            ref.invalidate(indentSummaryProvider);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('New Indent'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(indentListProvider);
          ref.invalidate(indentSummaryProvider);
        },
        child: listAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (indents) {
            if (indents.isEmpty) {
              return const KEmptyState(
                icon: Icons.assignment_outlined,
                title: 'No indents',
                subtitle: 'Customer indents will appear here',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: indents.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) =>
                  _IndentRow(indent: indents[index], onAction: _refresh),
            );
          },
        ),
      ),
    );
  }

  void _refresh() {
    ref.invalidate(indentListProvider);
    ref.invalidate(indentSummaryProvider);
  }
}

class _IndentRow extends ConsumerWidget {
  final Map<String, dynamic> indent;
  final VoidCallback onAction;

  const _IndentRow({required this.indent, required this.onAction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemName = indent['itemName'] as String? ?? '';
    final contactName = indent['contactName'] as String? ?? 'Walk-in';
    final contactPhone = indent['contactPhone'] as String? ?? '';
    final qty = indent['requestedQty'];
    final unit = indent['unit'] as String? ?? 'PCS';
    final status = indent['status'] as String? ?? 'PENDING';
    final promisedDate = indent['promisedDate'] as String?;
    final id = indent['id']?.toString() ?? '';

    return InkWell(
      onTap: () => _showActions(context, ref, id, status),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _statusColor(status).withValues(alpha: 0.1),
                borderRadius: KSpacing.borderRadiusMd,
              ),
              child: Icon(Icons.assignment_outlined,
                  size: 20, color: _statusColor(status)),
            ),
            KSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(itemName,
                      style: KTypography.labelMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '$contactName${contactPhone.isNotEmpty ? ' • $contactPhone' : ''}',
                    style: KTypography.bodySmall
                        .copyWith(color: KColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _StatusChip(status: status),
                      const SizedBox(width: 8),
                      Text('$qty $unit',
                          style: KTypography.labelSmall
                              .copyWith(color: KColors.textHint)),
                      if (promisedDate != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.event, size: 12, color: KColors.textHint),
                        const SizedBox(width: 2),
                        Text(promisedDate,
                            style: KTypography.labelSmall
                                .copyWith(color: KColors.textHint)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: Theme.of(context).colorScheme.outlineVariant),
          ],
        ),
      ),
    );
  }

  void _showActions(
      BuildContext context, WidgetRef ref, String id, String status) {
    final repo = ref.read(indentRepositoryProvider);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(indent['itemName'] ?? '',
                style: KTypography.titleSmall),
            Text(indent['contactName'] ?? 'Walk-in',
                style: KTypography.bodySmall
                    .copyWith(color: KColors.textSecondary)),
            const SizedBox(height: 16),
            if (status == 'PENDING') ...[
              ListTile(
                leading: const Icon(Icons.local_shipping_outlined),
                title: const Text('Mark as Ordered'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await repo.markOrdered(id, '');
                    onAction();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed: $e')));
                    }
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.cancel_outlined, color: KColors.error),
                title: Text('Cancel', style: TextStyle(color: KColors.error)),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await repo.cancel(id);
                    onAction();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed: $e')));
                    }
                  }
                },
              ),
            ],
            if (status == 'ARRIVED') ...[
              ListTile(
                leading:
                    Icon(Icons.check_circle_outline, color: KColors.success),
                title: const Text('Mark as Fulfilled'),
                subtitle: const Text('Customer collected the item'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await repo.markFulfilled(id, '');
                    onAction();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed: $e')));
                    }
                  }
                },
              ),
              if (indent['contactPhone'] != null &&
                  (indent['contactPhone'] as String).isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: const Text('Call Customer'),
                  subtitle: Text(indent['contactPhone'] ?? ''),
                  onTap: () => Navigator.pop(ctx),
                ),
            ],
            if (status == 'ORDERED')
              const ListTile(
                leading: Icon(Icons.hourglass_empty),
                title: Text('Waiting for GRN'),
                subtitle: Text('Will auto-update when stock is received'),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return KColors.warning;
      case 'ORDERED':
        return KColors.info;
      case 'ARRIVED':
        return KColors.success;
      case 'FULFILLED':
        return KColors.textHint;
      case 'CANCELLED':
        return KColors.error;
      default:
        return KColors.textSecondary;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _IndentRow._statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: KTypography.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}
