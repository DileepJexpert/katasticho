import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_error_view.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../../../core/widgets/k_text_field.dart';
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
        setState(() => _error = ApiErrorParser.message(e));
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
        title: const Text('Generate New API Key'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assign an identifier label to this credential (e.g. MCP Server, Zapier, Custom Storefront).',
                style: KTypography.bodySmall.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              KSpacing.vGapMd,
              KTextField(
                controller: nameCtrl,
                autofocus: true,
                label: 'Integration / Key Name *',
                hint: 'e.g. Claude Desktop MCP',
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
            label: 'Generate Key',
            icon: Icons.vpn_key_rounded,
            size: KButtonSize.small,
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, nameCtrl.text.trim());
            },
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
        SnackBar(content: Text('Could not create key: ${ApiErrorParser.message(e)}'), backgroundColor: KColors.error),
      );
    }
  }

  Future<void> _showSecret(String name, String secret) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.vpn_key_rounded, color: KColors.primary),
            SizedBox(width: 8),
            Text('Copy Secret Token'),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: KColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 18, color: KColors.warning),
                    KSpacing.hGapSm,
                    Expanded(
                      child: Text(
                        'This secret token is displayed only once. Store it in a secure password manager or environment variable.',
                        style: KTypography.caption.copyWith(color: KColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
              KSpacing.vGapMd,
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: SelectableText(
                  secret,
                  style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              KSpacing.vGapSm,
              Text(
                'Label: “$name”',
                style: KTypography.bodySmall.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        actions: [
          KButton.outlined(
            label: 'Copy to Clipboard',
            icon: Icons.copy_rounded,
            size: KButtonSize.small,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: secret));
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Secret key copied to clipboard'), backgroundColor: KColors.success),
              );
            },
          ),
          KButton.primary(
            label: 'Done',
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  Future<void> _revokeKey(ApiKey key) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke API Key?'),
        content: Text(
          'Revoke credential “${key.name}” (${key.keyPrefix}…)? Any external application, agent, or service using it will stop working immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          KButton.danger(
            label: 'Revoke Key',
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx, true),
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
        SnackBar(content: Text('Could not revoke: ${ApiErrorParser.message(e)}'), backgroundColor: KColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('API Keys & Agent Credentials'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
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
                        'Programmatic API Credentials',
                        style: KTypography.h2.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Generate secure bearer tokens for Katasticho Model Context Protocol (MCP) servers, LLM sidecars, and webhooks.',
                        style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                KButton.primary(
                  label: 'Generate Key',
                  icon: Icons.vpn_key_rounded,
                  onPressed: _createKey,
                ),
              ],
            ),
            KSpacing.vGapMd,
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(KSpacing.radiusMd),
                border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: cs.primary, size: 18),
                  KSpacing.hGapSm,
                  Expanded(
                    child: Text(
                      'API keys inherit the role permissions of the issuing user. They can draft transactions and query ERP records; financial posting continues to respect organization governance policies.',
                      style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
            KSpacing.vGapLg,
            if (_loading)
              const KLoading(message: 'Loading configured API keys...')
            else if (_error != null)
              KErrorView(message: _error!, onRetry: _load)
            else if ((_keys ?? const []).isEmpty)
              KEmptyState(
                icon: Icons.vpn_key_outlined,
                title: 'No API keys generated yet',
                subtitle: 'Generate an API key to connect Claude Desktop, AI agents, or automated webhook integrations.',
                actionLabel: 'Generate Key',
                onAction: _createKey,
              )
            else
              ...(_keys ?? const []).map(_buildKeyCard),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyCard(ApiKey key) {
    final cs = Theme.of(context).colorScheme;
    final subtitle = StringBuffer('Prefix: ${key.keyPrefix}…');
    if (key.lastUsedAt != null) {
      subtitle.write('  •  Last used ${_fmtDate(key.lastUsedAt!)}');
    } else if (key.createdAt != null) {
      subtitle.write('  •  Created ${_fmtDate(key.createdAt!)}');
    }

    return KCard(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      padding: const EdgeInsets.all(KSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: key.active ? cs.primary.withValues(alpha: 0.10) : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(KSpacing.radiusMd),
            ),
            child: Icon(
              key.active ? Icons.vpn_key_rounded : Icons.key_off_rounded,
              color: key.active ? cs.primary : cs.onSurfaceVariant,
              size: 20,
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
                        key.name,
                        style: KTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    KStatusChip(status: key.active ? 'ACTIVE' : 'REVOKED'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle.toString(),
                  style: KTypography.mono(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (key.active) ...[
            KSpacing.hGapSm,
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: KColors.error, size: 20),
              tooltip: 'Revoke Key',
              onPressed: () => _revokeKey(key),
            ),
          ],
        ],
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
