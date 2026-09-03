import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_state.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_error_view.dart';
import '../../../core/widgets/k_keyboard_list_wrapper.dart';
import '../../../core/widgets/k_loading.dart';
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
    final invitesAsync = ref.watch(_invitesProvider);
    final pendingCount = invitesAsync.valueOrNull?.length ?? 0;

    return KKeyboardListWrapper(
      itemCount: () => 0,
      onNew: _canManage ? _showInviteDialog : null,
      onRefresh: () {
        ref.invalidate(_usersProvider);
        ref.invalidate(_invitesProvider);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Team Members & Access Control'),
          bottom: TabBar(
            controller: _tabs,
            tabs: [
              const Tab(text: 'Active Members'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Pending Invites'),
                    if (pendingCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: KColors.warning,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$pendingCount',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                ref.invalidate(_usersProvider);
                ref.invalidate(_invitesProvider);
              },
            ),
          ],
        ),
        body: TabBarView(
          controller: _tabs,
          children: [
            _MembersTab(
              canManage: _canManage,
              isOwner: _isOwner,
              onInvite: _showInviteDialog,
              onRefresh: () => ref.invalidate(_usersProvider),
            ),
            _InvitesTab(
              canManage: _canManage,
              onRefresh: () => ref.invalidate(_invitesProvider),
            ),
          ],
        ),
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
  final VoidCallback onInvite;
  final VoidCallback onRefresh;

  const _MembersTab({
    required this.canManage,
    required this.isOwner,
    required this.onInvite,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(_usersProvider);
    final currentUserId = ref.watch(authProvider).userId;
    final cs = Theme.of(context).colorScheme;

    return usersAsync.when(
      loading: () => const KLoading(message: 'Loading organization team members...'),
      error: (e, _) => Padding(
        padding: KSpacing.pagePadding,
        child: KErrorView(message: ApiErrorParser.message(e), onRetry: onRefresh),
      ),
      data: (users) {
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_usersProvider),
          child: ListView(
            padding: KSpacing.pagePadding,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Organization Staff & Roles',
                          style: KTypography.h2.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Configure role-based access permissions (Owner, Admin, Accountant, Operator, Viewer).',
                          style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (canManage)
                    KButton.primary(
                      label: 'Invite Member',
                      icon: Icons.person_add_rounded,
                      onPressed: onInvite,
                    ),
                ],
              ),
              KSpacing.vGapLg,
              if (users.isEmpty)
                KEmptyState(
                  icon: Icons.groups_outlined,
                  title: 'No team members found',
                  subtitle: 'Invite coworkers to collaborate across sales, inventory, and accounting.',
                  actionLabel: canManage ? 'Invite Member' : null,
                  onAction: canManage ? onInvite : null,
                )
              else
                ...users.map((user) {
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
                }),
            ],
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
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Change Access Role'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioGroup<String>(
                  groupValue: selected,
                  onChanged: (v) {
                    if (v != null) setS(() => selected = v);
                  },
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
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            KButton.primary(
              label: 'Update Role',
              size: KButtonSize.small,
              onPressed: selected == currentRole
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      try {
                        await ref
                            .read(teamRepositoryProvider)
                            .updateRole(userId, selected);
                        onRefresh();
                        messenger.showSnackBar(
                          SnackBar(content: Text('Role updated to ${_roleLabels[selected]}'), backgroundColor: KColors.success),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Failed: ${ApiErrorParser.message(e)}'), backgroundColor: KColors.error),
                        );
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleActive(
      BuildContext context, WidgetRef ref, String userId, bool isActive) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isActive ? 'Deactivate User Account?' : 'Reactivate User Account?'),
        content: Text(isActive
            ? 'This user will immediately lose access to all modules and company data.'
            : 'This user will regain access to log in and use their assigned permissions.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          if (isActive)
            KButton.danger(
              label: 'Deactivate',
              size: KButtonSize.small,
              onPressed: () => Navigator.pop(ctx, true),
            )
          else
            KButton.primary(
              label: 'Reactivate',
              size: KButtonSize.small,
              onPressed: () => Navigator.pop(ctx, true),
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
      messenger.showSnackBar(
        SnackBar(content: Text(isActive ? 'User deactivated' : 'User reactivated'), backgroundColor: KColors.success),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed: ${ApiErrorParser.message(e)}'), backgroundColor: KColors.error),
      );
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
    final cs = Theme.of(context).colorScheme;
    final name = user['fullName'] as String? ?? 'Unnamed Member';
    final email = user['email'] as String?;
    final phone = user['phone'] as String?;
    final role = (user['role'] as String? ?? 'VIEWER').toUpperCase();
    final isActive = user['active'] as bool? ?? true;
    final lastLogin = user['lastLoginAt'] as String?;
    final roleColor = _roleColors[role] ?? cs.primary;

    return KCard(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      padding: const EdgeInsets.all(KSpacing.md),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: roleColor.withValues(alpha: 0.12),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
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
                        style: KTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    _RoleBadge(role: role),
                  ],
                ),
                if (email != null && email.isNotEmpty)
                  Text(
                    email,
                    style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                  ),
                if (phone != null && phone.isNotEmpty)
                  Text(
                    phone,
                    style: KTypography.mono(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                if (!isActive)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('Account Inactive',
                        style: KTypography.bodySmall.copyWith(color: KColors.error, fontWeight: FontWeight.w600)),
                  )
                else if (lastLogin != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _formatLastLogin(lastLogin),
                      style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          if (canManage)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, size: 20, color: cs.onSurfaceVariant),
              itemBuilder: (_) => [
                if (onChangeRole != null)
                  const PopupMenuItem(
                    value: 'role',
                    child: Row(
                      children: [
                        Icon(Icons.manage_accounts_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Change Role'),
                      ],
                    ),
                  ),
                if (onToggleActive != null)
                  PopupMenuItem(
                    value: 'active',
                    child: Row(
                      children: [
                        Icon(
                          isActive ? Icons.person_off_outlined : Icons.person_outlined,
                          color: isActive ? KColors.error : KColors.success,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(isActive ? 'Deactivate' : 'Reactivate'),
                      ],
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
      loading: () => const KLoading(message: 'Loading pending team invites...'),
      error: (e, _) => Padding(
        padding: KSpacing.pagePadding,
        child: KErrorView(message: ApiErrorParser.message(e), onRetry: onRefresh),
      ),
      data: (invites) {
        if (invites.isEmpty) {
          return const KEmptyState(
            icon: Icons.mail_outline_rounded,
            title: 'No pending invitations',
            subtitle: 'New invites sent to teammates will appear here until they accept and activate login.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_invitesProvider),
          child: ListView.builder(
            padding: KSpacing.pagePadding,
            itemCount: invites.length,
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
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(teamRepositoryProvider).resendInvite(inviteId);
      onRefresh();
      messenger.showSnackBar(const SnackBar(content: Text('Invitation resent successfully'), backgroundColor: KColors.success));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: ${ApiErrorParser.message(e)}'), backgroundColor: KColors.error));
    }
  }

  Future<void> _cancel(
      BuildContext context, WidgetRef ref, String inviteId) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke Invitation?'),
        content: const Text('This invitation link will be invalidated immediately.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Active'),
          ),
          KButton.danger(
            label: 'Revoke Invite',
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(teamRepositoryProvider).cancelInvite(inviteId);
      onRefresh();
      messenger.showSnackBar(const SnackBar(content: Text('Invitation revoked')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: ${ApiErrorParser.message(e)}'), backgroundColor: KColors.error));
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
    final cs = Theme.of(context).colorScheme;
    final email = invite['email'] as String?;
    final phone = invite['phone'] as String?;
    final role = (invite['role'] as String? ?? 'VIEWER').toUpperCase();
    final expired = invite['expired'] as bool? ?? false;
    final roleColor = _roleColors[role] ?? cs.primary;

    return KCard(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      padding: const EdgeInsets.all(KSpacing.md),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: expired
                ? cs.surfaceContainerHighest
                : roleColor.withValues(alpha: 0.12),
            child: Icon(
              Icons.mail_outline_rounded,
              size: 18,
              color: expired ? cs.onSurfaceVariant : roleColor,
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
                        email ?? phone ?? 'Unknown Contact',
                        style: KTypography.titleSmall.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    _RoleBadge(role: role, muted: expired),
                  ],
                ),
                Text(
                  expired ? 'Expired Invite' : 'Invite Sent (Pending Acceptance)',
                  style: KTypography.bodySmall.copyWith(
                    color: expired ? KColors.error : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (canManage)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, size: 20, color: cs.onSurfaceVariant),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'resend',
                  child: Row(
                    children: [
                      Icon(Icons.send_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Resend Invite'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'cancel',
                  child: Row(
                    children: [
                      Icon(Icons.cancel_outlined, color: KColors.error, size: 18),
                      SizedBox(width: 8),
                      Text('Revoke', style: TextStyle(color: KColors.error)),
                    ],
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invite Team Member', style: KTypography.h2),
            const SizedBox(height: 4),
            Text(
              'Send an invitation to join your company workspace with specific role permissions.',
              style: KTypography.bodySmall.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            KSpacing.vGapMd,
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number (Primary)',
                hintText: '+91 XXXXXXXXXX',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            KSpacing.vGapSm,
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address (Optional)',
                hintText: 'teammate@company.com',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            KSpacing.vGapMd,
            Text('Access Role & Permissions', style: KTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
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
            KButton.primary(
              label: 'Send Workspace Invitation',
              icon: Icons.send_rounded,
              fullWidth: true,
              isLoading: _loading,
              onPressed: _loading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final phone = _phone.text.trim();
    final email = _email.text.trim();

    if (phone.isEmpty && email.isEmpty) {
      setState(() => _error = 'Enter at least a phone number or email address');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(teamRepositoryProvider).invite(
            role: _role,
            phone: phone.isEmpty ? null : phone,
            email: email.isEmpty ? null : email,
          );
      widget.onDone();
      if (mounted) Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Workspace invitation sent successfully'), backgroundColor: KColors.success),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = ApiErrorParser.message(e);
        });
      }
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
    return 'Last active ${dt.day}/${dt.month}/${dt.year}';
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
    final cs = Theme.of(context).colorScheme;
    final color = muted ? cs.onSurfaceVariant : (_roleColors[role] ?? cs.primary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(KSpacing.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        _roleLabels[role] ?? role,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
