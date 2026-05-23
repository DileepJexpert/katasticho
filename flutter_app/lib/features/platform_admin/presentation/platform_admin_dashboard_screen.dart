import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../routing/app_router.dart';
import '../data/platform_admin_auth_state.dart';
import '../data/platform_admin_repository.dart';

class PlatformAdminDashboardScreen extends ConsumerStatefulWidget {
  const PlatformAdminDashboardScreen({super.key});

  @override
  ConsumerState<PlatformAdminDashboardScreen> createState() =>
      _PlatformAdminDashboardScreenState();
}

class _PlatformAdminDashboardScreenState
    extends ConsumerState<PlatformAdminDashboardScreen> {
  late Future<Map<String, dynamic>> _statsFuture;
  late Future<List<Map<String, dynamic>>> _pendingFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = ref.read(platformAdminRepositoryProvider).stats();
    _pendingFuture = ref
        .read(platformAdminRepositoryProvider)
        .organisationsV2(status: 'PENDING');
  }

  void _refresh() {
    setState(() {
      _statsFuture = ref.read(platformAdminRepositoryProvider).stats();
      _pendingFuture = ref
          .read(platformAdminRepositoryProvider)
          .organisationsV2(status: 'PENDING');
    });
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

  Future<void> _handleLogout() async {
    await ref.read(platformAdminTokenProvider.notifier).clearToken();
    if (mounted) context.go(Routes.platformAdminLogin);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Admin'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'dashboard':
                  break;
                case 'pending':
                  context.go(Routes.platformAdminPending);
                case 'orgs':
                  context.go(Routes.platformAdminOrgs);
                case 'users':
                  context.go(Routes.platformAdminUsers);
                case 'audit':
                  context.go(Routes.platformAdminAudit);
                case 'logout':
                  _handleLogout();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'dashboard', child: Text('Dashboard')),
              PopupMenuItem(
                  value: 'pending', child: Text('Pending Approvals')),
              PopupMenuItem(value: 'orgs', child: Text('All Orgs')),
              PopupMenuItem(value: 'users', child: Text('Users')),
              PopupMenuItem(value: 'audit', child: Text('Audit Log')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Stats Cards ──
              FutureBuilder<Map<String, dynamic>>(
                future: _statsFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final stats =
                      snapshot.data!['data'] as Map<String, dynamic>? ??
                          snapshot.data!;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _StatCard(
                        title: 'Total Orgs',
                        value: '${stats['total_orgs'] ?? stats['totalOrgs'] ?? 0}',
                        color: KColors.primary,
                      ),
                      _StatCard(
                        title: 'Pending',
                        value:
                            '${stats['pending_approval'] ?? stats['pendingApproval'] ?? 0}',
                        color: KColors.warning,
                      ),
                      _StatCard(
                        title: 'Active',
                        value: '${stats['active_orgs'] ?? stats['activeOrgs'] ?? 0}',
                        color: KColors.success,
                      ),
                      _StatCard(
                        title: 'Suspended',
                        value:
                            '${stats['suspended_orgs'] ?? stats['suspendedOrgs'] ?? 0}',
                        color: KColors.error,
                      ),
                    ],
                  );
                },
              ),
              KSpacing.vGapXl,

              // ── Pending Approvals ──
              Text('Pending Approvals', style: KTypography.h2),
              KSpacing.vGapMd,
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _pendingFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final orgs = snapshot.data!;
                  if (orgs.isEmpty) {
                    return Text(
                      'No pending approvals.',
                      style: KTypography.bodyMedium
                          .copyWith(color: KColors.textSecondary),
                    );
                  }
                  final display = orgs.take(5).toList();
                  return Column(
                    children: [
                      ...display.map((org) {
                        final id = org['id'].toString();
                        final name = org['name']?.toString() ?? 'Unnamed';
                        final owner = org['ownerName']?.toString() ?? '';
                        final created = org['createdAt']?.toString() ?? '';
                        return Card(
                          child: ListTile(
                            title: Text(name,
                                style: KTypography.h4),
                            subtitle: Text(
                              [owner, created]
                                  .where((e) => e.isNotEmpty)
                                  .join(' | '),
                              style: KTypography.bodySmall
                                  .copyWith(color: KColors.textSecondary),
                            ),
                            trailing: Wrap(
                              spacing: 8,
                              children: [
                                FilledButton(
                                  onPressed: () => _approve(id),
                                  child: const Text('Approve'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _reject(id),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: KColors.error,
                                  ),
                                  child: const Text('Reject'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      if (orgs.length > 5) ...[
                        KSpacing.vGapMd,
                        TextButton(
                          onPressed: () =>
                              context.go(Routes.platformAdminPending),
                          child: Text(
                            'View all ${orgs.length} pending',
                            style: KTypography.labelMedium
                                .copyWith(color: KColors.primary),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    KTypography.labelMedium.copyWith(color: KColors.textSecondary),
              ),
              KSpacing.vGapSm,
              Text(
                value,
                style: KTypography.amountLarge.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
