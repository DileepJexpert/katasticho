import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/platform_admin_repository.dart';

class PlatformAdminOrgsScreen extends ConsumerStatefulWidget {
  const PlatformAdminOrgsScreen({super.key});

  @override
  ConsumerState<PlatformAdminOrgsScreen> createState() =>
      _PlatformAdminOrgsScreenState();
}

class _PlatformAdminOrgsScreenState
    extends ConsumerState<PlatformAdminOrgsScreen> {
  static const _planOptions = [
    'BASIC',
    'FINANCE_PRO',
    'RETAIL',
    'DISTRIBUTOR',
    'PHARMA',
    'RETAIL_DISTRIBUTOR',
    'PHARMA_DISTRIBUTOR',
    'MANUFACTURER_DISTRIBUTOR',
    'ENTERPRISE',
  ];

  final _searchController = TextEditingController();
  String _statusFilter = 'ALL';
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() {
    return ref.read(platformAdminRepositoryProvider).organisationsV2(
          status: _statusFilter == 'ALL' ? null : _statusFilter,
          search: _searchController.text.trim().isNotEmpty
              ? _searchController.text.trim()
              : null,
        );
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  void _showOrgDetail(Map<String, dynamic> org) {
    final id = org['id'].toString();

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.62,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: FutureBuilder<Map<String, dynamic>>(
            future: ref.read(platformAdminRepositoryProvider).organisationDetailV2(id),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 64),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(org['name']?.toString() ?? 'Organisation', style: KTypography.h2),
                      KSpacing.vGapMd,
                      Text(
                        'We could not load the organisation detail right now.',
                        style: KTypography.bodyMedium.copyWith(color: KColors.textSecondary),
                      ),
                    ],
                  ),
                );
              }

              final detail = snapshot.data ?? org;
              final status = detail['approvalStatus']?.toString() ??
                  org['approvalStatus']?.toString() ??
                  org['status']?.toString() ??
                  '';
              final enabledModules = _stringList(detail['enabledModules']);
              final enabledFeatures = _stringList(detail['enabledFeatures']);
              final subCategories = _stringList(detail['subCategories']);
              final recentActionsRaw = detail['recentAdminActions'];
              final recentActions = recentActionsRaw is List
                  ? recentActionsRaw.cast<Map<String, dynamic>>()
                  : const <Map<String, dynamic>>[];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detail['name']?.toString() ?? org['name']?.toString() ?? 'Organisation',
                    style: KTypography.h2,
                  ),
                  KSpacing.vGapSm,
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildStatusChip(status),
                      if ((detail['planTier']?.toString() ?? '').isNotEmpty)
                        _buildInfoChip(detail['planTier'].toString().replaceAll('_', ' ')),
                      if ((detail['active']?.toString() ?? '').isNotEmpty)
                        _buildInfoChip((detail['active'] == true) ? 'Active tenant' : 'Inactive tenant'),
                    ],
                  ),
                  KSpacing.vGapMd,
                  _buildDetailRow('Email', detail['email']?.toString()),
                  _buildDetailRow('Phone', detail['phone']?.toString()),
                  _buildDetailRow('Business', detail['businessType']?.toString()),
                  _buildDetailRow('Industry', detail['industryCode']?.toString()),
                  _buildDetailRow('Created', _formatInstant(detail['createdAt']?.toString())),
                  _buildDetailRow('Approved', _formatInstant(detail['approvedAt']?.toString())),
                  _buildDetailRow('Approval note', detail['approvalNote']?.toString()),
                  if (subCategories.isNotEmpty) ...[
                    KSpacing.vGapMd,
                    _buildSectionTitle('Subcategories'),
                    KSpacing.vGapSm,
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: subCategories.map(_buildInfoChip).toList(),
                    ),
                  ],
                  KSpacing.vGapLg,
                  _buildSectionTitle('Enabled Modules'),
                  KSpacing.vGapSm,
                  if (enabledModules.isEmpty)
                    Text(
                      'No module snapshot available yet.',
                      style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: enabledModules.map((module) => _buildInfoChip(module.replaceAll('_', ' '))).toList(),
                    ),
                  if (enabledFeatures.isNotEmpty) ...[
                    KSpacing.vGapMd,
                    Text(
                      '${enabledFeatures.length} enabled capabilities',
                      style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                    ),
                  ],
                  KSpacing.vGapLg,
                  _buildSectionTitle('Recent Admin Actions'),
                  KSpacing.vGapSm,
                  if (recentActions.isEmpty)
                    Text(
                      'No organisation-level platform actions yet.',
                      style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                    )
                  else
                    ...recentActions.map(_buildRecentActionRow),
                  KSpacing.vGapLg,
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await _changePlan(detail);
                        },
                        child: const Text('Change Plan'),
                      ),
                      if (status == 'PENDING') ...[
                        FilledButton(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await ref.read(platformAdminRepositoryProvider).approveOrgV2(id);
                            _refresh();
                          },
                          style: FilledButton.styleFrom(backgroundColor: KColors.success),
                          child: const Text('Approve'),
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await _rejectWithReason(id);
                          },
                          style: OutlinedButton.styleFrom(foregroundColor: KColors.error),
                          child: const Text('Reject'),
                        ),
                      ],
                      if (status == 'APPROVED' || status == 'ACTIVE')
                        OutlinedButton(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await _suspendWithReason(id);
                          },
                          style: OutlinedButton.styleFrom(foregroundColor: KColors.error),
                          child: const Text('Suspend'),
                        ),
                      if (status == 'SUSPENDED')
                        FilledButton(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await ref.read(platformAdminRepositoryProvider).reactivateOrg(id);
                            _refresh();
                          },
                          child: const Text('Reactivate'),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).where((item) => item.isNotEmpty).toList();
    }
    return const [];
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: KTypography.h4);
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _statusChipBgColor(status),
        borderRadius: KSpacing.borderRadiusSm,
      ),
      child: Text(
        status,
        style: KTypography.labelSmall.copyWith(color: _statusChipColor(status)),
      ),
    );
  }

  Widget _buildInfoChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: KColors.draftBg,
        borderRadius: KSpacing.borderRadiusSm,
      ),
      child: Text(
        label,
        style: KTypography.labelSmall.copyWith(color: KColors.textSecondary),
      ),
    );
  }

  Widget _buildRecentActionRow(Map<String, dynamic> action) {
    final actionType = action['actionType']?.toString().replaceAll('_', ' ') ?? 'Action';
    final targetName = action['targetName']?.toString();
    final reason = action['reason']?.toString();
    final performedAt = _formatInstant(action['performedAt']?.toString());
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KColors.draftBg,
        borderRadius: KSpacing.borderRadiusSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(actionType, style: KTypography.labelMedium),
          if (performedAt != null) ...[
            KSpacing.vGapXs,
            Text(
              performedAt,
              style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
            ),
          ],
          if (targetName != null && targetName.isNotEmpty) ...[
            KSpacing.vGapXs,
            Text(
              targetName,
              style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
            ),
          ],
          if (reason != null && reason.isNotEmpty) ...[
            KSpacing.vGapXs,
            Text(reason, style: KTypography.bodySmall),
          ],
        ],
      ),
    );
  }

  String? _formatInstant(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return raw.replaceFirst('T', ' ').replaceFirst('Z', ' UTC');
  }

  Widget _buildDetailRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style:
                  KTypography.labelMedium.copyWith(color: KColors.textSecondary),
            ),
          ),
          Expanded(child: Text(value, style: KTypography.bodyMedium)),
        ],
      ),
    );
  }

  Future<void> _rejectWithReason(String orgId) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Organisation'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Enter rejection reason',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null) return;
    await ref
        .read(platformAdminRepositoryProvider)
        .rejectOrgV2(orgId, reason: reason.isNotEmpty ? reason : null);
    _refresh();
  }

  Future<void> _suspendWithReason(String orgId) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Suspend Organisation'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Enter suspension reason',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Suspend'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.isEmpty) return;
    await ref
        .read(platformAdminRepositoryProvider)
        .suspendOrg(orgId, reason);
    _refresh();
  }

  Future<void> _changePlan(Map<String, dynamic> org) async {
    String selectedPlan = (org['planTier']?.toString().isNotEmpty ?? false)
        ? org['planTier'].toString().toUpperCase()
        : 'RETAIL';
    final noteController = TextEditingController();
    final plan = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Change Organisation Plan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _planOptions.contains(selectedPlan) ? selectedPlan : 'RETAIL',
                decoration: const InputDecoration(labelText: 'Plan Tier'),
                items: _planOptions
                    .map((plan) => DropdownMenuItem(
                          value: plan,
                          child: Text(plan.replaceAll('_', ' ')),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setModalState(() => selectedPlan = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  hintText: 'Reason or internal note',
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(selectedPlan),
              child: const Text('Update Plan'),
            ),
          ],
        ),
      ),
    );
    if (plan == null) {
      noteController.dispose();
      return;
    }
    await ref.read(platformAdminRepositoryProvider).updateOrgPlan(
          org['id'].toString(),
          plan,
          note: noteController.text.trim(),
        );
    noteController.dispose();
    _refresh();
  }

  Color _statusChipColor(String status) {
    return switch (status.toUpperCase()) {
      'PENDING' => KColors.warning,
      'APPROVED' || 'ACTIVE' => KColors.success,
      'REJECTED' => KColors.error,
      'SUSPENDED' => KColors.error,
      _ => KColors.textSecondary,
    };
  }

  Color _statusChipBgColor(String status) {
    return switch (status.toUpperCase()) {
      'PENDING' => KColors.warningLight,
      'APPROVED' || 'ACTIVE' => KColors.successLight,
      'REJECTED' => KColors.errorLight,
      'SUSPENDED' => KColors.errorLight,
      _ => KColors.draftBg,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Organisations')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: KTextField(
              label: '',
              hint: 'Search organisations...',
              controller: _searchController,
              prefixIcon: Icons.search,
              onChanged: (_) => _refresh(),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'ALL', label: Text('All')),
                ButtonSegment(value: 'PENDING', label: Text('Pending')),
                ButtonSegment(value: 'APPROVED', label: Text('Active')),
                ButtonSegment(value: 'REJECTED', label: Text('Rejected')),
                ButtonSegment(value: 'SUSPENDED', label: Text('Suspended')),
              ],
              selected: {_statusFilter},
              onSelectionChanged: (value) {
                setState(() {
                  _statusFilter = value.first;
                  _future = _load();
                });
              },
            ),
          ),
          KSpacing.vGapSm,
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final orgs = snapshot.data!;
                if (orgs.isEmpty) {
                  return Center(
                    child: Text(
                      'No organisations found.',
                      style: KTypography.bodyMedium
                          .copyWith(color: KColors.textSecondary),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: orgs.length,
                  separatorBuilder: (_, __) => KSpacing.vGapSm,
                  itemBuilder: (context, index) {
                    final org = orgs[index];
                    final status = org['approvalStatus']?.toString() ??
                        org['status']?.toString() ??
                        '';
                    final name = org['name']?.toString() ?? 'Unnamed';
                    final owner = org['ownerName']?.toString() ?? '';
                    final created = org['createdAt']?.toString() ?? '';

                    return Card(
                      child: ListTile(
                        onTap: () => _showOrgDetail(org),
                        title: Row(
                          children: [
                            Expanded(
                              child:
                                  Text(name, style: KTypography.h4),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _statusChipBgColor(status),
                                borderRadius: KSpacing.borderRadiusSm,
                              ),
                              child: Text(
                                status,
                                style: KTypography.labelSmall
                                    .copyWith(color: _statusChipColor(status)),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          [owner, created]
                              .where((e) => e.isNotEmpty)
                              .join(' | '),
                          style: KTypography.bodySmall
                              .copyWith(color: KColors.textSecondary),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
