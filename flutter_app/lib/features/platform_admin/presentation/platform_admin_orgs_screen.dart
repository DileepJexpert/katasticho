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
    final status =
        org['approvalStatus']?.toString() ?? org['status']?.toString() ?? '';

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                org['name']?.toString() ?? 'Organisation',
                style: KTypography.h2,
              ),
              KSpacing.vGapSm,
              _buildDetailRow('Status', status),
              _buildDetailRow('Owner', org['ownerName']?.toString()),
              _buildDetailRow('Email', org['ownerEmail']?.toString()),
              _buildDetailRow('Phone', org['ownerPhone']?.toString()),
              _buildDetailRow('Industry', org['industry']?.toString()),
              _buildDetailRow('Created', org['createdAt']?.toString()),
              KSpacing.vGapLg,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (status == 'PENDING') ...[
                    FilledButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await ref
                            .read(platformAdminRepositoryProvider)
                            .approveOrgV2(id);
                        _refresh();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: KColors.success,
                      ),
                      child: const Text('Approve'),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _rejectWithReason(id);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: KColors.error,
                      ),
                      child: const Text('Reject'),
                    ),
                  ],
                  if (status == 'APPROVED' || status == 'ACTIVE')
                    OutlinedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _suspendWithReason(id);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: KColors.error,
                      ),
                      child: const Text('Suspend'),
                    ),
                  if (status == 'SUSPENDED')
                    FilledButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await ref
                            .read(platformAdminRepositoryProvider)
                            .reactivateOrg(id);
                        _refresh();
                      },
                      child: const Text('Reactivate'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
