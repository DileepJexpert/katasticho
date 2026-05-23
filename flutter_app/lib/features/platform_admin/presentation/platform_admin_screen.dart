import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/platform_admin_repository.dart';

class PlatformAdminScreen extends ConsumerStatefulWidget {
  const PlatformAdminScreen({super.key});

  @override
  ConsumerState<PlatformAdminScreen> createState() => _PlatformAdminScreenState();
}

class _PlatformAdminScreenState extends ConsumerState<PlatformAdminScreen> {
  String _status = 'PENDING';
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() {
    return ref.read(platformAdminRepositoryProvider).organisations(
          status: _status == 'ALL' ? null : _status,
        );
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  Future<void> _approve(String orgId) async {
    await ref.read(platformAdminRepositoryProvider).approveOrg(orgId);
    _refresh();
  }

  Future<void> _reject(String orgId) async {
    await ref.read(platformAdminRepositoryProvider).rejectOrg(orgId);
    _refresh();
  }

  Future<void> _showUsers(String orgId, String orgName) async {
    final users = await ref.read(platformAdminRepositoryProvider).users(orgId);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _UsersSheet(
        orgName: orgName,
        users: users,
        onReset: _resetPassword,
      ),
    );
  }

  Future<void> _resetPassword(String userId) async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Set new password'),
        content: KTextField(
          label: 'New Password',
          controller: controller,
          obscureText: true,
          prefixIcon: Icons.lock_outline,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (password == null || password.length < 8) return;
    await ref.read(platformAdminRepositoryProvider).resetPassword(
          userId,
          password,
          reason: 'Platform admin reset',
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Platform Admin')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Account Approvals', style: KTypography.h2),
            Text(
              'Approve new businesses before they can login and use Katixo.',
              style: KTypography.bodyMedium.copyWith(color: KColors.textSecondary),
            ),
            KSpacing.vGapLg,
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'PENDING', label: Text('Pending')),
                ButtonSegment(value: 'APPROVED', label: Text('Approved')),
                ButtonSegment(value: 'REJECTED', label: Text('Rejected')),
                ButtonSegment(value: 'ALL', label: Text('All')),
              ],
              selected: {_status},
              onSelectionChanged: (value) {
                setState(() {
                  _status = value.first;
                  _future = _load();
                });
              },
            ),
            KSpacing.vGapLg,
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final orgs = snapshot.data!;
                  if (orgs.isEmpty) {
                    return const Center(child: Text('No organisations found.'));
                  }
                  return ListView.separated(
                    itemCount: orgs.length,
                    separatorBuilder: (_, __) => KSpacing.vGapSm,
                    itemBuilder: (context, index) {
                      final org = orgs[index];
                      final status = org['approvalStatus']?.toString() ?? '';
                      final id = org['id'].toString();
                      return Card(
                        child: ListTile(
                          title: Text(org['name']?.toString() ?? 'Unnamed org'),
                        subtitle: Text([
                            status,
                            org['businessType'],
                            org['phone'],
                          ].where((e) => e != null && e.toString().isNotEmpty).join(' / ')),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: () => _showUsers(
                                  id,
                                  org['name']?.toString() ?? 'Organisation',
                                ),
                                child: const Text('Users'),
                              ),
                              if (status == 'PENDING') ...[
                                FilledButton(
                                  onPressed: () => _approve(id),
                                  child: const Text('Approve'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _reject(id),
                                  child: const Text('Reject'),
                                ),
                              ],
                            ],
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
      ),
    );
  }
}

class _UsersSheet extends StatelessWidget {
  final String orgName;
  final List<Map<String, dynamic>> users;
  final ValueChanged<String> onReset;

  const _UsersSheet({
    required this.orgName,
    required this.users,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(orgName, style: KTypography.h3),
          KSpacing.vGapMd,
          Expanded(
            child: ListView.separated(
              itemCount: users.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final user = users[index];
                return ListTile(
                  title: Text(user['fullName']?.toString() ?? 'User'),
                  subtitle: Text([
                    user['role'],
                    user['phone'],
                    user['email'],
                  ].where((e) => e != null && e.toString().isNotEmpty).join(' / ')),
                  trailing: TextButton(
                    onPressed: () => onReset(user['id'].toString()),
                    child: const Text('Reset Password'),
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
