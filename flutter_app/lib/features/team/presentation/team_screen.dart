import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/team_repository.dart';

// ── Providers ─────────────────────────────────────────────────────────

final _usersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.read(teamRepositoryProvider).listUsers(),
);

final _invitesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.read(teamRepositoryProvider).listPendingInvites(),
);

// ── Role config ───────────────────────────────────────────────────────

const _roleColors = {
  'OWNER': Color(0xFF6750A4),
  'ADMIN': Color(0xFF006A6A),
  'ACCOUNTANT': Color(0xFF1B6EA8),
  'OPERATOR': Color(0xFF006E1C),
  'VIEWER': Color(0xFF6E5400),
};

const _roleLabels = {
  'OWNER': 'Owner',
  'ADMIN': 'Admin',
  'ACCOUNTANT': 'Accountant',
  'OPERATOR': 'Operator',
  'VIEWER': 'Viewer',
};

const _assignableRoles = ['ADMIN', 'ACCOUNTANT', 'OPERATOR', 'VIEWER'];

// ── Screen ────────────────────────────────────────────────────────────

class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key});

  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  bool get _canManage {
    final role = ref.read(authProvider).role?.toUpperCase() ?? '';
    return role == 'OWNER' || role == 'ADMIN';
  }

  bool get _isOwner =>
      ref.read(authProvider).role?.toUpperCase() == 'OWNER';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Members'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Members'),
            Tab(text: 'Pending Invites'),
          ],
        ),
        actions: [
          if (_canManage)
            IconButton(
              icon: const Icon(Icons.person_add_outlined),
              tooltip: 'Invite',
              onPressed: _showInviteDialog,
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _MembersTab(
            canManage: _canManage,
            isOwner: _isOwner,
            onRefresh: () => ref.invalidate(_usersProvider),
          ),
          _InvitesTab(
            canManage: _canManage,
            onRefresh: () => ref.invalidate(_invitesProvider),
          ),
        ],
      ),
    );
  }

  void _showInviteDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: _InviteSheet(isOwner: _isOwner, onDone: () {
          ref.invalidate(_invitesProvider);
        }),
      ),
    );
  }
}

// ── Members Tab ───────────────────────────────────────────────────────

class _MembersTab extends ConsumerWidget {
  final bool canManage;
  final bool isOwner;
  final VoidCallback onRefresh;

  const _MembersTab({
    required this.canManage,
    required this.isOwner,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(_usersProvider);
    final currentUserId = ref.watch(authProvider).userId;

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorRetry(message: e.toString(), onRetry: () => ref.invalidate(_usersProvider)),
      data: (users) {
        if (users.isEmpty) {
          return const Center(child: Text('No team members yet.'));
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_usersProvider),
          child: ListView.separated(
            padding: KSpacing.pagePadding,
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final user = users[i];
              final userId = user['id'] as String;
              final role = (user['role'] as String).toUpperCase();
              final isActive = user['active'] as bool? ?? true;
              final isSelf = userId == currentUserId;
              final isThisOwner = role == 'OWNER';

              return _UserCard(
                user: user,
                isSelf: isSelf,
                canManage: canManage && !isThisOwner && !isSelf,
                isOwner: isOwner,
                onChangeRole: !isThisOwner && canManage
                    ? () => _showChangeRoleDialog(context, ref, userId, role)
                    : null,
                onToggleActive: !isThisOwner && !isSelf && canManage
                    ? () => _toggleActive(context, ref, userId, isActive)
                    : null,
              );
            },
          ),
        );
      },
    );
  }

  void _showChangeRoleDialog(
      BuildContext context, WidgetRef ref, String userId, String currentRole) {
    String selected = currentRole;
    final availableRoles = isOwner
        ? _assignableRoles
        : _assignableRoles.where((r) => r != 'ADMIN').toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Change Role'),
          content: RadioGroup<String>(
            groupValue: selected,
            onChanged: (v) => setS(() => selected = v!),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: availableRoles
                  .map((role) => RadioListTile<String>(
                        title: Text(_roleLabels[role] ?? role),
                        value: role,
                      ))
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: selected == currentRole
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      try {
                        await ref
                            .read(teamRepositoryProvider)
                            .updateRole(userId, selected);
                        onRefresh();
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Role updated to ${_roleLabels[selected]}')),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Failed: $e')),
                          );
                        }
                      }
                    },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleActive(
      BuildContext context, WidgetRef ref, String userId, bool isActive) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isActive ? 'Deactivate User?' : 'Reactivate User?'),
        content: Text(isActive
            ? 'This user will lose access immediately.'
            : 'This user will regain access to the organisation.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: isActive
                ? FilledButton.styleFrom(backgroundColor: KColors.error)
                : null,
            child: Text(isActive ? 'Deactivate' : 'Reactivate'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final repo = ref.read(teamRepositoryProvider);
      if (isActive) {
        await repo.deactivateUser(userId);
      } else {
        await repo.reactivateUser(userId);
      }
      onRefresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isActive ? 'User deactivated' : 'User reactivated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }
}

// ── User Card ─────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isSelf;
  final bool canManage;
  final bool isOwner;
  final VoidCallback? onChangeRole;
  final VoidCallback? onToggleActive;

  const _UserCard({
    required this.user,
    required this.isSelf,
    required this.canManage,
    required this.isOwner,
    this.onChangeRole,
    this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final name = user['fullName'] as String? ?? 'Unknown';
    final email = user['email'] as String?;
    final phone = user['phone'] as String?;
    final role = (user['role'] as String).toUpperCase();
    final isActive = user['active'] as bool? ?? true;
    final lastLogin = user['lastLoginAt'] as String?;
    final roleColor = _roleColors[role] ?? KColors.textHint;

    return KCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: roleColor.withValues(alpha: 0.15),
            child: Text(
              name[0].toUpperCase(),
              style: TextStyle(
                color: roleColor,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name + (isSelf ? ' (You)' : ''),
                        style: KTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _RoleBadge(role: role),
                  ],
                ),
                if (email != null)
                  Text(email,
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textHint)),
                if (phone != null)
                  Text(phone,
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textHint)),
                if (!isActive)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('Inactive',
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.error)),
                  )
                else if (lastLogin != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _formatLastLogin(lastLogin),
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textHint, fontSize: 11),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('Never logged in',
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textHint, fontSize: 11)),
                  ),
              ],
            ),
          ),
          if (canManage)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  size: 20, color: KColors.textHint),
              itemBuilder: (_) => [
                if (onChangeRole != null)
                  const PopupMenuItem(
                    value: 'role',
                    child: ListTile(
                      leading: Icon(Icons.manage_accounts_outlined),
                      title: Text('Change Role'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                if (onToggleActive != null)
                  PopupMenuItem(
                    value: 'active',
                    child: ListTile(
                      leading: Icon(
                        isActive ? Icons.person_off_outlined : Icons.person_outlined,
                        color: isActive ? KColors.error : KColors.success,
                      ),
                      title: Text(isActive ? 'Deactivate' : 'Reactivate'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
              ],
              onSelected: (action) {
                if (action == 'role') onChangeRole?.call();
                if (action == 'active') onToggleActive?.call();
              },
            ),
        ],
      ),
    );
  }
}

// ── Invites Tab ───────────────────────────────────────────────────────

class _InvitesTab extends ConsumerWidget {
  final bool canManage;
  final VoidCallback onRefresh;

  const _InvitesTab({required this.canManage, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitesAsync = ref.watch(_invitesProvider);

    return invitesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          _ErrorRetry(message: e.toString(), onRetry: () => ref.invalidate(_invitesProvider)),
      data: (invites) {
        if (invites.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mail_outline_rounded,
                    size: 48, color: KColors.textHint),
                KSpacing.vGapMd,
                Text('No pending invites', style: KTypography.bodyMedium),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_invitesProvider),
          child: ListView.separated(
            padding: KSpacing.pagePadding,
            itemCount: invites.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final invite = invites[i];
              return _InviteCard(
                invite: invite,
                canManage: canManage,
                onResend: canManage
                    ? () => _resend(context, ref, invite['id'] as String)
                    : null,
                onCancel: canManage
                    ? () => _cancel(context, ref, invite['id'] as String)
                    : null,
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _resend(
      BuildContext context, WidgetRef ref, String inviteId) async {
    try {
      await ref.read(teamRepositoryProvider).resendInvite(inviteId);
      onRefresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Invitation resent')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _cancel(
      BuildContext context, WidgetRef ref, String inviteId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Invitation?'),
        content: const Text('This invitation link will be revoked.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: KColors.error),
            child: const Text('Cancel Invite'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(teamRepositoryProvider).cancelInvite(inviteId);
      onRefresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invitation cancelled')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }
}

// ── Invite Card ───────────────────────────────────────────────────────

class _InviteCard extends StatelessWidget {
  final Map<String, dynamic> invite;
  final bool canManage;
  final VoidCallback? onResend;
  final VoidCallback? onCancel;

  const _InviteCard({
    required this.invite,
    required this.canManage,
    this.onResend,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final email = invite['email'] as String?;
    final phone = invite['phone'] as String?;
    final role = (invite['role'] as String).toUpperCase();
    final expired = invite['expired'] as bool? ?? false;
    final roleColor = _roleColors[role] ?? KColors.textHint;

    return KCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: expired
                ? KColors.textHint.withValues(alpha: 0.15)
                : roleColor.withValues(alpha: 0.15),
            child: Icon(
              Icons.mail_outline_rounded,
              size: 18,
              color: expired ? KColors.textHint : roleColor,
            ),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        email ?? phone ?? 'Unknown',
                        style: KTypography.bodyMedium
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    _RoleBadge(role: role, muted: expired),
                  ],
                ),
                Text(
                  expired ? 'Expired' : 'Pending',
                  style: KTypography.bodySmall.copyWith(
                    color: expired ? KColors.error : KColors.textHint,
                  ),
                ),
              ],
            ),
          ),
          if (canManage)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
                  size: 20, color: KColors.textHint),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'resend',
                  child: ListTile(
                    leading: Icon(Icons.send_outlined),
                    title: Text('Resend'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 'cancel',
                  child: ListTile(
                    leading: Icon(Icons.cancel_outlined, color: KColors.error),
                    title: Text('Cancel',
                        style: TextStyle(color: KColors.error)),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ],
              onSelected: (action) {
                if (action == 'resend') onResend?.call();
                if (action == 'cancel') onCancel?.call();
              },
            ),
        ],
      ),
    );
  }
}

// ── Invite Sheet ──────────────────────────────────────────────────────

class _InviteSheet extends ConsumerStatefulWidget {
  final bool isOwner;
  final VoidCallback onDone;

  const _InviteSheet({required this.isOwner, required this.onDone});

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  final _phone = TextEditingController();
  final _email = TextEditingController();
  String _role = 'ACCOUNTANT';
  bool _loading = false;
  String? _error;

  List<String> get _availableRoles => widget.isOwner
      ? _assignableRoles
      : _assignableRoles.where((r) => r != 'ADMIN').toList();

  @override
  void dispose() {
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Invite Team Member', style: KTypography.h3),
          KSpacing.vGapMd,

          // Contact
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone (primary)',
              hintText: '+91 XXXXXXXXXX',
              prefixIcon: Icon(Icons.phone_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          KSpacing.vGapSm,
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email (optional)',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          KSpacing.vGapMd,

          // Role selector
          Text('Role', style: KTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
          KSpacing.vGapSm,
          Wrap(
            spacing: 8,
            children: _availableRoles
                .map((r) => ChoiceChip(
                      label: Text(_roleLabels[r] ?? r),
                      selected: _role == r,
                      onSelected: (_) => setState(() => _role = r),
                    ))
                .toList(),
          ),
          KSpacing.vGapMd,

          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: KColors.error)),
            KSpacing.vGapSm,
          ],

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send Invitation'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final phone = _phone.text.trim();
    final email = _email.text.trim();

    if (phone.isEmpty && email.isEmpty) {
      setState(() => _error = 'Enter phone or email');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(teamRepositoryProvider).invite(
            role: _role,
            phone: phone.isEmpty ? null : phone,
            email: email.isEmpty ? null : email,
          );
      widget.onDone();
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation sent')),
        );
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }
}

// ── Helpers ───────────────────────────────────────────────────────────

String _formatLastLogin(String iso) {
  try {
    final dt = DateTime.parse(iso);
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Active now';
    if (diff.inMinutes < 60) return 'Active ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Active ${diff.inHours}h ago';
    if (diff.inDays < 7) return 'Active ${diff.inDays}d ago';
    return 'Last seen ${dt.day}/${dt.month}/${dt.year}';
  } catch (_) {
    return '';
  }
}

// ── Role Badge ────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  final String role;
  final bool muted;

  const _RoleBadge({required this.role, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final color = muted ? KColors.textHint : (_roleColors[role] ?? KColors.textHint);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        _roleLabels[role] ?? role,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ── Error + Retry ─────────────────────────────────────────────────────

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: KColors.error),
          KSpacing.vGapMd,
          Text(message,
              textAlign: TextAlign.center, style: KTypography.bodyMedium),
          KSpacing.vGapMd,
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
