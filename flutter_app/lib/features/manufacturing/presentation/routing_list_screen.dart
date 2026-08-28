import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/routing_repository.dart';

class RoutingListScreen extends ConsumerStatefulWidget {
  const RoutingListScreen({super.key});

  @override
  ConsumerState<RoutingListScreen> createState() => _RoutingListScreenState();
}

class _RoutingListScreenState extends ConsumerState<RoutingListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KKeyboardListWrapper(
      itemCount: () => 0,
      onNew: () => _tabController.index == 0
          ? context.go('/manufacturing/routings/create')
          : _showAddWorkstationSheet(context),
      onRefresh: () => _tabController.index == 0
          ? ref.invalidate(routingsProvider)
          : ref.invalidate(workstationsProvider),
      child: Scaffold(
        body: Column(
          children: [
            const KListPageHeader(
              title: 'Routings & Workstations',
            ),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Routings'),
                Tab(text: 'Workstations'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _RoutingsTab(),
                  _WorkstationsTab(),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: _tabController.index == 0
            ? FloatingActionButton.extended(
                backgroundColor: KColors.primary,
                foregroundColor: Colors.white,
                onPressed: () => context.go('/manufacturing/routings/create'),
                icon: const Icon(Icons.add),
                label: const Text('New Routing'),
                tooltip: 'New Routing (N)',
              )
            : FloatingActionButton.extended(
                backgroundColor: KColors.primary,
                foregroundColor: Colors.white,
                onPressed: () => _showAddWorkstationSheet(context),
                icon: const Icon(Icons.add),
                label: const Text('Add Workstation'),
                tooltip: 'Add Workstation (N)',
              ),
      ),
    );
  }

  void _showAddWorkstationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _AddWorkstationSheet(),
    ).then((_) => ref.invalidate(workstationsProvider));
  }
}

// ---------------------------------------------------------------------------
// Routings Tab
// ---------------------------------------------------------------------------

class _RoutingsTab extends ConsumerWidget {
  const _RoutingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routingsAsync = ref.watch(routingsProvider);

    return routingsAsync.when(
      loading: () => const Center(child: KLoading(message: 'Loading routings...')),
      error: (e, _) => KErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(routingsProvider),
      ),
      data: (routings) {
        if (routings.isEmpty) {
          return const KEmptyState(
            icon: Icons.route_outlined,
            title: 'No routings yet',
            subtitle: 'Create a routing to define the sequence of operations for an item.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(routingsProvider),
          child: ListView.builder(
            padding: KSpacing.pagePadding,
            itemCount: routings.length,
            itemBuilder: (ctx, i) => _RoutingCard(routing: routings[i]),
          ),
        );
      },
    );
  }
}

class _RoutingCard extends StatelessWidget {
  const _RoutingCard({required this.routing});
  final Map<String, dynamic> routing;

  @override
  Widget build(BuildContext context) {
    final name = routing['name']?.toString() ?? '';
    final itemId = routing['itemId']?.toString() ?? '';
    final isDefault = routing['isDefault'] == true;
    final ops = (routing['operations'] as List?)?.length ?? 0;

    final truncatedItemId = itemId.length > 18 ? '${itemId.substring(0, 8)}...' : itemId;

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
                  Expanded(
                    child: Text(
                      name,
                      style: KTypography.labelLarge,
                    ),
                  ),
                  if (isDefault)
                    const KStatusChip(status: 'DEFAULT'),
                ],
              ),
              KSpacing.vGapXs,
              Wrap(
                spacing: 16,
                children: [
                  if (itemId.isNotEmpty)
                    Text('Item: $truncatedItemId',
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary)),
                  Text('$ops operation${ops == 1 ? '' : 's'}',
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Workstations Tab
// ---------------------------------------------------------------------------

class _WorkstationsTab extends ConsumerWidget {
  const _WorkstationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wsAsync = ref.watch(workstationsProvider);

    return wsAsync.when(
      loading: () => const Center(child: KLoading(message: 'Loading workstations...')),
      error: (e, _) => KErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(workstationsProvider),
      ),
      data: (workstations) {
        if (workstations.isEmpty) {
          return const KEmptyState(
            icon: Icons.precision_manufacturing_outlined,
            title: 'No workstations',
            subtitle: 'Add a workstation to assign operations during production.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(workstationsProvider),
          child: ListView.builder(
            padding: KSpacing.pagePadding,
            itemCount: workstations.length,
            itemBuilder: (ctx, i) =>
                _WorkstationCard(workstation: workstations[i]),
          ),
        );
      },
    );
  }
}

class _WorkstationCard extends StatelessWidget {
  const _WorkstationCard({required this.workstation});
  final Map<String, dynamic> workstation;

  @override
  Widget build(BuildContext context) {
    final code = workstation['code']?.toString() ?? '';
    final name = workstation['name']?.toString() ?? '';
    final hourlyRate = workstation['hourlyRate'];
    final capacity = workstation['capacityHoursPerDay'];
    final isActive = workstation['isActive'] != false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KCard(
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.md),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: KColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.settings_input_component,
                    color: KColors.primary, size: 20),
              ),
              KSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          code,
                          style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        KSpacing.hGapSm,
                        Expanded(
                          child: Text(
                            name,
                            style: KTypography.labelLarge,
                          ),
                        ),
                      ],
                    ),
                    KSpacing.vGapXs,
                    Wrap(
                      spacing: 16,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (hourlyRate != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Rate: ', style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                              KMoney((hourlyRate as num).toDouble()),
                              Text('/hr', style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                            ],
                          ),
                        if (capacity != null)
                          Text('Capacity: ${capacity}h/day',
                              style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
              KStatusChip(status: isActive ? 'ACTIVE' : 'INACTIVE'),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add Workstation Bottom Sheet
// ---------------------------------------------------------------------------

class _AddWorkstationSheet extends ConsumerStatefulWidget {
  const _AddWorkstationSheet();

  @override
  ConsumerState<_AddWorkstationSheet> createState() =>
      _AddWorkstationSheetState();
}

class _AddWorkstationSheetState extends ConsumerState<_AddWorkstationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtl = TextEditingController();
  final _nameCtl = TextEditingController();
  final _descCtl = TextEditingController();
  final _rateCtl = TextEditingController();
  final _capacityCtl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _codeCtl.dispose();
    _nameCtl.dispose();
    _descCtl.dispose();
    _rateCtl.dispose();
    _capacityCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: KSpacing.lg,
        right: KSpacing.lg,
        top: KSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + KSpacing.xl,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add Workstation',
                style: KTypography.h3),
            KSpacing.vGapMd,
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: KTextField(
                    controller: _codeCtl,
                    label: 'Code *',
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                KSpacing.hGapSm,
                Expanded(
                  flex: 2,
                  child: KTextField(
                    controller: _nameCtl,
                    label: 'Name *',
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
              ],
            ),
            KSpacing.vGapSm,
            KTextField(
              controller: _descCtl,
              label: 'Description',
              maxLines: 2,
            ),
            KSpacing.vGapSm,
            Row(
              children: [
                Expanded(
                  child: KTextField(
                    controller: _rateCtl,
                    label: 'Hourly Rate (₹)',
                    keyboardType: TextInputType.number,
                  ),
                ),
                KSpacing.hGapSm,
                Expanded(
                  child: KTextField(
                    controller: _capacityCtl,
                    label: 'Capacity (hrs/day)',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            KSpacing.vGapLg,
            KButton.primary(
              onPressed: _submitting ? null : _submit,
              isLoading: _submitting,
              icon: Icons.check,
              label: 'Save Workstation',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await ref.read(routingRepositoryProvider).createWorkstation(
            code: _codeCtl.text.trim(),
            name: _nameCtl.text.trim(),
            description: _descCtl.text.trim(),
            hourlyRate: double.tryParse(_rateCtl.text.trim()),
            capacityHours: double.tryParse(_capacityCtl.text.trim()),
          );
      ref.invalidate(workstationsProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workstation created'),
            backgroundColor: KColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: KColors.error));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
