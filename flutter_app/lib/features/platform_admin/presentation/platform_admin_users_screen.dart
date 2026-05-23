import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/platform_admin_repository.dart';

class PlatformAdminUsersScreen extends ConsumerStatefulWidget {
  const PlatformAdminUsersScreen({super.key});

  @override
  ConsumerState<PlatformAdminUsersScreen> createState() =>
      _PlatformAdminUsersScreenState();
}

class _PlatformAdminUsersScreenState
    extends ConsumerState<PlatformAdminUsersScreen> {
  final _searchController = TextEditingController();
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
    return ref.read(platformAdminRepositoryProvider).usersV2(
          search: _searchController.text.trim().isNotEmpty
              ? _searchController.text.trim()
              : null,
        );
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  void _showUserDetail(Map<String, dynamic> user) {
    final userId = user['id'].toString();
    final isActive = user['status']?.toString().toUpperCase() != 'INACTIVE';

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        maxChildSize: 0.7,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user['fullName']?.toString() ?? 'User',
                style: KTypography.h2,
              ),
              KSpacing.vGapSm,
              _buildDetailRow('Email', user['email']?.toString()),
              _buildDetailRow('Phone', user['phone']?.toString()),
              _buildDetailRow('Organisation', user['orgName']?.toString()),
              _buildDetailRow('Role', user['role']?.toString()),
              _buildDetailRow('Last Login', user['lastLoginAt']?.toString()),
              _buildDetailRow('Status', user['status']?.toString()),
              KSpacing.vGapLg,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showResetPasswordDialog(userId);
                    },
                    icon: const Icon(Icons.lock_reset, size: 18),
                    label: const Text('Reset Password'),
                  ),
                  if (isActive)
                    OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _deactivateWithReason(userId);
                      },
                      icon: const Icon(Icons.block, size: 18),
                      label: const Text('Deactivate'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: KColors.error,
                      ),
                    )
                  else
                    FilledButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await ref
                            .read(platformAdminRepositoryProvider)
                            .reactivateUser(userId);
                        _refresh();
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Reactivate'),
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
            width: 100,
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

  Future<void> _showResetPasswordDialog(String userId) async {
    final passwordController = TextEditingController();
    bool notifyUser = false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reset Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KTextField(
                label: 'New Password',
                controller: passwordController,
                obscureText: true,
                prefixIcon: Icons.lock_outline,
              ),
              KSpacing.vGapMd,
              SwitchListTile(
                title: const Text('Notify user'),
                value: notifyUser,
                onChanged: (v) => setDialogState(() => notifyUser = v),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop({
                'password': passwordController.text,
                'notify': notifyUser,
              }),
              child: const Text('Reset'),
            ),
          ],
        ),
      ),
    );
    passwordController.dispose();

    if (result == null) return;
    final password = result['password'] as String;
    if (password.length < 8) return;

    await ref.read(platformAdminRepositoryProvider).resetPasswordV2(
          userId,
          password,
          notifyUser: result['notify'] as bool,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset successfully.')),
      );
    }
  }

  Future<void> _deactivateWithReason(String userId) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deactivate User'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Enter deactivation reason',
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
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.isEmpty) return;
    await ref
        .read(platformAdminRepositoryProvider)
        .deactivateUser(userId, reason);
    _refresh();
  }

  Color _roleChipColor(String? role) {
    return switch (role?.toUpperCase()) {
      'OWNER' => KColors.primary,
      'ADMIN' => KColors.info,
      'ACCOUNTANT' => KColors.success,
      _ => KColors.textSecondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: KTextField(
              label: '',
              hint: 'Search users...',
              controller: _searchController,
              prefixIcon: Icons.search,
              onChanged: (_) => _refresh(),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final users = snapshot.data!;
                if (users.isEmpty) {
                  return Center(
                    child: Text(
                      'No users found.',
                      style: KTypography.bodyMedium
                          .copyWith(color: KColors.textSecondary),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: users.length,
                  separatorBuilder: (_, __) => KSpacing.vGapSm,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final name = user['fullName']?.toString() ?? 'User';
                    final orgName = user['orgName']?.toString() ?? '';
                    final role = user['role']?.toString() ?? '';
                    final lastLogin = user['lastLoginAt']?.toString() ?? '';

                    return Card(
                      child: ListTile(
                        onTap: () => _showUserDetail(user),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(name, style: KTypography.h4),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _roleChipColor(role)
                                    .withValues(alpha: 0.12),
                                borderRadius: KSpacing.borderRadiusSm,
                              ),
                              child: Text(
                                role,
                                style: KTypography.labelSmall
                                    .copyWith(color: _roleChipColor(role)),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          [orgName, if (lastLogin.isNotEmpty) lastLogin]
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
