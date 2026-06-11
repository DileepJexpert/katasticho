import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/api_keys_repository.dart';

/// Manage org API keys — programmatic credentials for the Katasticho MCP server,
/// integrations, and scripts. The secret is shown once at creation.
class ApiKeysScreen extends ConsumerStatefulWidget {
  const ApiKeysScreen({super.key});

  @override
  ConsumerState<ApiKeysScreen> createState() => _ApiKeysScreenState();
}

class _ApiKeysScreenState extends ConsumerState<ApiKeysScreen> {
  List<ApiKey>? _keys;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final keys = await ref.read(apiKeysRepositoryProvider).list();
      if (mounted) setState(() => _keys = keys);
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = e.toString().replaceAll('Exception: ', '').trim());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createKey() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create API key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Give the key a name so you remember where it is used.'),
            KSpacing.vGapMd,
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Claude Desktop',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty || !mounted) return;

    try {
      final secret = await ref.read(apiKeysRepositoryProvider).create(name);
      if (!mounted) return;
      await _showSecret(name, secret);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create key: $e')),
      );
    }
  }

  Future<void> _showSecret(String name, String secret) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Copy your API key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This is shown only once. Store it securely — you can\'t see it again.',
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
                secret,
                style: KTypography.bodySmall.copyWith(fontFamily: 'monospace'),
              ),
            ),
            KSpacing.vGapSm,
            Text('“$name”',
                style: KTypography.bodySmall
                    .copyWith(color: KColors.textSecondary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: secret));
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Key copied to clipboard')),
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

  Future<void> _revokeKey(ApiKey key) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke API key'),
        content: Text(
            'Revoke “${key.name}” (${key.keyPrefix}…)? Any client using it will stop working immediately.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: KColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await ref.read(apiKeysRepositoryProvider).revoke(key.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not revoke: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('API Keys')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createKey,
        icon: const Icon(Icons.add),
        label: const Text('Create key'),
        tooltip: 'Create key (N)',
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
              ))
            else if (_error != null)
              _buildError()
            else if ((_keys ?? const []).isEmpty)
              _buildEmpty()
            else
              ...(_keys ?? const []).map(_buildKeyCard),
          ],
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KColors.info.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.key, color: KColors.info, size: 18),
          KSpacing.hGapSm,
          Expanded(
            child: Text(
              'Use an API key to let the Katasticho MCP server (Claude Desktop), '
              'integrations, or scripts act on this organisation. The key carries '
              'your role; it can draft transactions, but posting still needs approval.',
              style:
                  KTypography.bodySmall.copyWith(color: KColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyCard(ApiKey key) {
    final subtitle = StringBuffer('${key.keyPrefix}…');
    if (key.lastUsedAt != null) {
      subtitle.write('  ·  last used ${_fmtDate(key.lastUsedAt!)}');
    } else if (key.createdAt != null) {
      subtitle.write('  ·  created ${_fmtDate(key.createdAt!)}');
    }
    return KCard(
      child: Row(
        children: [
          Icon(
            key.active ? Icons.vpn_key : Icons.key_off,
            color: key.active ? KColors.success : KColors.textSecondary,
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(key.name,
                          style: KTypography.labelLarge,
                          overflow: TextOverflow.ellipsis),
                    ),
                    KSpacing.hGapSm,
                    if (!key.active)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: KColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('Revoked',
                            style: KTypography.labelSmall
                                .copyWith(color: KColors.error)),
                      ),
                  ],
                ),
                Text(subtitle.toString(),
                    style: KTypography.bodySmall
                        .copyWith(color: KColors.textSecondary)),
              ],
            ),
          ),
          if (key.active)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: KColors.error),
              tooltip: 'Revoke',
              onPressed: () => _revokeKey(key),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.vpn_key_outlined,
                size: 48, color: KColors.textSecondary.withOpacity(0.5)),
            KSpacing.vGapSm,
            Text('No API keys yet',
                style: KTypography.bodyMedium
                    .copyWith(color: KColors.textSecondary)),
            KSpacing.vGapXs,
            Text('Create one to connect Claude Desktop or an integration.',
                style:
                    KTypography.bodySmall.copyWith(color: KColors.textHint),
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

  String _fmtDate(DateTime d) {
    final local = d.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '$dd/$mm/${local.year}';
  }
}
