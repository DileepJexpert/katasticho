import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../data/platform_admin_repository.dart';

class PlatformAdminPendingScreen extends ConsumerStatefulWidget {
  const PlatformAdminPendingScreen({super.key});

  @override
  ConsumerState<PlatformAdminPendingScreen> createState() =>
      _PlatformAdminPendingScreenState();
}

class _PlatformAdminPendingScreenState
    extends ConsumerState<PlatformAdminPendingScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() {
    return ref
        .read(platformAdminRepositoryProvider)
        .organisationsV2(status: 'PENDING');
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  Future<void> _approve(String orgId) async {
    await ref.read(platformAdminRepositoryProvider).approveOrgV2(orgId);
    _refresh();
  }

  Future<void> _reject(String orgId) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Organisation'),
        content: TextField(
          controller: reasonController,
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
                Navigator.of(context).pop(reasonController.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null) return;
    await ref
        .read(platformAdminRepositoryProvider)
        .rejectOrgV2(orgId, reason: reason.isNotEmpty ? reason : null);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pending Approvals')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final orgs = snapshot.data!;
          if (orgs.isEmpty) {
            return Center(
              child: Text(
                'No pending approvals.',
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
              final id = org['id'].toString();
              final name = org['name']?.toString() ?? 'Unnamed';
              final ownerName = org['ownerName']?.toString() ?? '';
              final ownerEmail = org['ownerEmail']?.toString() ?? '';
              final ownerPhone = org['ownerPhone']?.toString() ?? '';
              final industry = org['industry']?.toString() ?? '';
              final created = org['createdAt']?.toString() ?? '';

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: KTypography.h3),
                      KSpacing.vGapSm,
                      if (ownerName.isNotEmpty)
                        Text(
                          'Owner: $ownerName',
                          style: KTypography.bodyMedium,
                        ),
                      if (ownerEmail.isNotEmpty || ownerPhone.isNotEmpty)
                        Text(
                          [ownerEmail, ownerPhone]
                              .where((e) => e.isNotEmpty)
                              .join(' | '),
                          style: KTypography.bodySmall
                              .copyWith(color: KColors.textSecondary),
                        ),
                      if (industry.isNotEmpty)
                        Text(
                          'Industry: $industry',
                          style: KTypography.bodySmall
                              .copyWith(color: KColors.textSecondary),
                        ),
                      if (created.isNotEmpty)
                        Text(
                          'Signed up: $created',
                          style: KTypography.bodySmall
                              .copyWith(color: KColors.textHint),
                        ),
                      KSpacing.vGapMd,
                      Row(
                        children: [
                          FilledButton(
                            onPressed: () => _approve(id),
                            style: FilledButton.styleFrom(
                              backgroundColor: KColors.success,
                            ),
                            child: const Text('Approve'),
                          ),
                          KSpacing.hGapSm,
                          OutlinedButton(
                            onPressed: () => _reject(id),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: KColors.error,
                            ),
                            child: const Text('Reject'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
