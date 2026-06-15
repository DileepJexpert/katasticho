import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';

/// Admin management of customer/vendor self-service portal accounts.
///
/// An org owner/admin invites a Contact (customer or vendor) to the portal;
/// the contact receives a one-time invite token to set their password and log
/// in. This screen lists those accounts and lets admins resend invites,
/// suspend/reactivate, or remove them. The external-facing portal itself is a
/// separate front-end — this is the ERP-side control surface.
class PortalUsersScreen extends ConsumerStatefulWidget {
  const PortalUsersScreen({super.key});

  @override
  ConsumerState<PortalUsersScreen> createState() => _PortalUsersScreenState();
}

class _PortalUsersScreenState extends ConsumerState<PortalUsersScreen> {
  List<Map<String, dynamic>>? _users;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  ApiClient get _api => ref.read(apiClientProvider);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.get(ApiConfig.portalUsers);
      final data = (res.data['data'] as List?) ?? const [];
      if (mounted) {
        setState(() => _users = data
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList());
      }
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Surface a backend `message` when present, else a clean string.
  String _msg(Object e) {
    if (e is DioException) {
      final body = e.response?.data;
      if (body is Map && body['message'] is String) {
        return body['message'] as String;
      }
    }
    return e.toString().replaceAll('Exception: ', '').trim();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Invite ────────────────────────────────────────────────────────────

  Future<void> _invite() async {
    final picked = await showDialog<_InviteResult>(
      context: context,
      builder: (_) => const _InviteDialog(),
    );
    if (picked == null || !mounted) return;

    try {
      final body = <String, dynamic>{'contactId': picked.contactId};
      if (picked.email.isNotEmpty) body['email'] = picked.email;
      if (picked.fullName.isNotEmpty) body['fullName'] = picked.fullName;
      final res = await _api.post(ApiConfig.portalUsers, data: body);
      final data = (res.data['data'] as Map?)?.cast<String, dynamic>() ?? {};
      if (!mounted) return;
      final token = data['inviteToken']?.toString();
      if (token != null && token.isNotEmpty) {
        await _showInviteToken(token, data['inviteExpiresAt']?.toString());
      }
      await _load();
    } catch (e) {
      _toast('Could not invite: ${_msg(e)}');
    }
  }

  Future<void> _showInviteToken(String token, String? expiresAt) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Portal invite'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share this one-time invite token with the customer or vendor. '
              'They use it to set a password and activate their portal login. '
              'It is shown only once.',
              style: KTypography.bodySmall.copyWith(color: KColors.warning),
            ),
            KSpacing.vGapMd,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: KColors.draftBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: KColors.divider),
              ),
              child: SelectableText(
                token,
                style: KTypography.bodySmall.copyWith(fontFamily: 'monospace'),
              ),
            ),
            if (expiresAt != null && expiresAt.isNotEmpty) ...[
              KSpacing.vGapSm,
              Text('Expires: $expiresAt',
                  style: KTypography.bodySmall
                      .copyWith(color: KColors.textSecondary)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: token));
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Invite token copied')),
              );
            },
            child: const Text('Copy'),
          ),
          FilledButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
        ],
      ),
    );
  }

  // ── Row actions ─────────────────────────────────────────────────────────

  Future<void> _resendInvite(Map<String, dynamic> u) async {
    final id = u['id']?.toString();
    if (id == null) return;
    try {
      final res = await _api.post(ApiConfig.portalUserResendInvite(id));
      final data = (res.data['data'] as Map?)?.cast<String, dynamic>() ?? {};
      if (!mounted) return;
      final token = data['inviteToken']?.toString();
      if (token != null && token.isNotEmpty) {
        await _showInviteToken(token, data['inviteExpiresAt']?.toString());
      }
      await _load();
      _toast('Invite resent');
    } catch (e) {
      _toast('Could not resend: ${_msg(e)}');
    }
  }

  Future<void> _suspend(Map<String, dynamic> u) async {
    final id = u['id']?.toString();
    if (id == null) return;
    try {
      await _api.post(ApiConfig.portalUserSuspend(id));
      await _load();
      _toast('Account suspended');
    } catch (e) {
      _toast('Could not suspend: ${_msg(e)}');
    }
  }

  Future<void> _reactivate(Map<String, dynamic> u) async {
    final id = u['id']?.toString();
    if (id == null) return;
    try {
      await _api.post(ApiConfig.portalUserReactivate(id));
      await _load();
      _toast('Account reactivated');
    } catch (e) {
      _toast('Could not reactivate: ${_msg(e)}');
    }
  }

  Future<void> _remove(Map<String, dynamic> u) async {
    final id = u['id']?.toString();
    if (id == null) return;
    final name = (u['fullName'] ?? u['email'] ?? 'this account').toString();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove portal account'),
        content: Text(
            'Remove the portal login for “$name”? They will lose access to '
            'the self-service portal immediately.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: KColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _api.delete(ApiConfig.portalUserById(id));
      await _load();
      _toast('Portal account removed');
    } catch (e) {
      _toast('Could not remove: ${_msg(e)}');
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Portal Users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _invite,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Invite'),
        tooltip: 'Invite a customer or vendor (N)',
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildIntro(),
            KSpacing.vGapLg,
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              _buildError()
            else if ((_users ?? const []).isEmpty)
              _buildEmpty()
            else
              ...(_users ?? const []).map(_buildUserCard),
          ],
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.badge_outlined, color: KColors.info, size: 18),
          KSpacing.hGapSm,
          Expanded(
            child: Text(
              'Invite a customer or vendor contact to the self-service portal. '
              'They log in with email + password to view their own invoices, '
              'statements, orders and bills. You manage their access here.',
              style:
                  KTypography.bodySmall.copyWith(color: KColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> u) {
    final status = (u['status'] ?? '').toString().toUpperCase();
    final kind = (u['kind'] ?? '').toString().toUpperCase();
    final name = (u['fullName'] ?? '').toString();
    final email = (u['email'] ?? '').toString();
    final lastLogin = u['lastLoginAt']?.toString();
    final isSuspended = status == 'SUSPENDED';

    return KCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name.isNotEmpty ? name : email,
                        style: KTypography.labelLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    KSpacing.hGapSm,
                    _chip(kind, KColors.info),
                    KSpacing.hGapXs,
                    _chip(status, _statusColor(status)),
                  ],
                ),
                if (name.isNotEmpty && email.isNotEmpty)
                  Text(email,
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textSecondary)),
                if (lastLogin != null && lastLogin.isNotEmpty)
                  Text('Last login: $lastLogin',
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textHint)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Actions',
            onSelected: (action) {
              switch (action) {
                case 'resend':
                  _resendInvite(u);
                  break;
                case 'suspend':
                  _suspend(u);
                  break;
                case 'reactivate':
                  _reactivate(u);
                  break;
                case 'remove':
                  _remove(u);
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'resend',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.mail_outline),
                  title: Text('Resend invite'),
                ),
              ),
              if (!isSuspended)
                const PopupMenuItem(
                  value: 'suspend',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.block),
                    title: Text('Suspend'),
                  ),
                ),
              if (isSuspended)
                const PopupMenuItem(
                  value: 'reactivate',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.check_circle_outline),
                    title: Text('Reactivate'),
                  ),
                ),
              const PopupMenuItem(
                value: 'remove',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline, color: KColors.error),
                  title: Text('Remove'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: KTypography.labelSmall.copyWith(color: color)),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ACTIVE':
        return KColors.success;
      case 'SUSPENDED':
        return KColors.error;
      case 'INVITED':
      default:
        return KColors.warning;
    }
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.badge_outlined,
                size: 48, color: KColors.textSecondary.withValues(alpha: 0.5)),
            KSpacing.vGapSm,
            Text('No portal accounts yet — invite a customer or vendor',
                style: KTypography.bodyMedium
                    .copyWith(color: KColors.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: KColors.error),
            KSpacing.vGapSm,
            Text(_error ?? 'Something went wrong',
                style: KTypography.bodySmall.copyWith(color: KColors.error),
                textAlign: TextAlign.center),
            KSpacing.vGapMd,
            KButton(label: 'Retry', onPressed: _load),
          ],
        ),
      ),
    );
  }
}

// ── Invite dialog ─────────────────────────────────────────────────────────

class _InviteResult {
  final String contactId;
  final String email;
  final String fullName;
  const _InviteResult({
    required this.contactId,
    required this.email,
    required this.fullName,
  });
}

class _InviteDialog extends ConsumerStatefulWidget {
  const _InviteDialog();

  @override
  ConsumerState<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends ConsumerState<_InviteDialog> {
  final _searchCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  List<Map<String, dynamic>> _results = const [];
  Map<String, dynamic>? _selected;
  bool _searching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String term) async {
    setState(() => _searching = true);
    try {
      final res = await ref.read(apiClientProvider).get(
        ApiConfig.contacts,
        queryParameters: {'search': term},
      );
      final content =
          ((res.data['data'] as Map?)?['content'] as List?) ?? const [];
      if (mounted) {
        setState(() => _results = content
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList());
      }
    } catch (_) {
      if (mounted) setState(() => _results = const []);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  String _displayName(Map<String, dynamic> c) {
    final dn = (c['displayName'] ?? '').toString();
    if (dn.isNotEmpty) return dn;
    return (c['name'] ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return AlertDialog(
      title: const Text('Invite to portal'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selected == null) ...[
              TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Search customer / vendor',
                  hintText: 'Type a name…',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: _search,
              ),
              KSpacing.vGapSm,
              if (_searching)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_results.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('No matches yet — type to search',
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textHint)),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ListView(
                    shrinkWrap: true,
                    children: _results.map((c) {
                      final email = (c['email'] ?? '').toString();
                      return ListTile(
                        dense: true,
                        title: Text(_displayName(c)),
                        subtitle: email.isNotEmpty ? Text(email) : null,
                        onTap: () => setState(() {
                          _selected = c;
                          _emailCtrl.text = email;
                        }),
                      );
                    }).toList(),
                  ),
                ),
            ] else ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline),
                title: Text(_displayName(selected)),
                subtitle: Text((selected['email'] ?? '').toString()),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Change',
                  onPressed: () => setState(() {
                    _selected = null;
                    _emailCtrl.clear();
                  }),
                ),
              ),
              KSpacing.vGapSm,
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Login email (optional override)',
                  hintText: 'Defaults to the contact email',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: selected == null
              ? null
              : () => Navigator.pop(
                    context,
                    _InviteResult(
                      contactId: selected['id'].toString(),
                      email: _emailCtrl.text.trim(),
                      fullName: '',
                    ),
                  ),
          child: const Text('Send invite'),
        ),
      ],
    );
  }
}
