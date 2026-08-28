import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_error_view.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_text_field.dart';
import '../../gst/data/gst_repository.dart';

/// GSP (GST Suvidha Provider) connection settings.
///
/// These credentials let the org generate e-invoice IRNs, e-way bills, and pull
/// GSTR-2B directly from an aggregator (Masters India, ClearTax, etc.) instead
/// of the manual download-JSON → portal-upload round trip. The token is
/// write-only — the server never echoes it back, only whether one is set.
class GspSettingsScreen extends ConsumerStatefulWidget {
  const GspSettingsScreen({super.key});

  @override
  ConsumerState<GspSettingsScreen> createState() => _GspSettingsScreenState();
}

class _GspSettingsScreenState extends ConsumerState<GspSettingsScreen> {
  final _provider = TextEditingController();
  final _baseUrl = TextEditingController();
  final _gstin = TextEditingController();
  final _token = TextEditingController();
  final _einvoicePath = TextEditingController();
  final _ewaybillPath = TextEditingController();
  final _gstr2bPath = TextEditingController();

  bool _enabled = false;
  bool _tokenSet = false;
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  String? _error;
  String? _testMessage;
  bool _testOk = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _provider, _baseUrl, _gstin, _token,
      _einvoicePath, _ewaybillPath, _gstr2bPath,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await ref.read(gstRepositoryProvider).getGspSettings();
      if (!mounted) return;
      setState(() {
        _enabled = s['enabled'] == true;
        _tokenSet = s['tokenSet'] == true;
        _provider.text = (s['provider'] ?? '').toString();
        _baseUrl.text = (s['baseUrl'] ?? '').toString();
        _gstin.text = (s['gstin'] ?? '').toString();
        _einvoicePath.text = (s['einvoicePath'] ?? '').toString();
        _ewaybillPath.text = (s['ewaybillPath'] ?? '').toString();
        _gstr2bPath.text = (s['gstr2bPath'] ?? '').toString();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiErrorParser.message(e);
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final body = <String, dynamic>{
        'enabled': _enabled,
        'provider': _provider.text.trim(),
        'baseUrl': _baseUrl.text.trim(),
        'gstin': _gstin.text.trim(),
        'einvoicePath': _einvoicePath.text.trim(),
        'ewaybillPath': _ewaybillPath.text.trim(),
        'gstr2bPath': _gstr2bPath.text.trim(),
        if (_token.text.trim().isNotEmpty) 'token': _token.text.trim(),
      };
      final s = await ref.read(gstRepositoryProvider).updateGspSettings(body);
      if (!mounted) return;
      setState(() {
        _tokenSet = s['tokenSet'] == true;
        _token.clear();
        _saving = false;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('GSP connection settings saved successfully'), backgroundColor: KColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(
        content: Text('Save failed: ${ApiErrorParser.message(e)}'),
        backgroundColor: KColors.error,
      ));
    }
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testMessage = null;
    });
    try {
      final r = await ref.read(gstRepositoryProvider).testGspConnection();
      if (!mounted) return;
      setState(() {
        _testOk = r['reachable'] == true;
        _testMessage = (r['message'] ?? '').toString();
        _testing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testOk = false;
        _testMessage = 'Test failed: ${ApiErrorParser.message(e)}';
        _testing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('GST Suvidha Provider (GSP) Setup'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: KLoading(message: 'Loading GSP connector settings...'))
          : _error != null
              ? Padding(
                  padding: KSpacing.pagePadding,
                  child: KErrorView(message: _error!, onRetry: _load),
                )
              : ListView(
                  padding: KSpacing.pagePadding,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Automated GSTN Portal Gateway',
                          style: KTypography.h2.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Connect via authorized GSPs (Masters India, ClearTax, IRIS) for instant e-Invoice IRN and e-Way bill generation.',
                          style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                    KSpacing.vGapLg,
                    KCard(
                      title: 'Live Connection Credentials',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Enable Automated GSP Integration'),
                            subtitle: Text(
                              _enabled
                                  ? 'Active — 1-click IRN generation & e-Way bill dispatch enabled'
                                  : 'Disabled — Fallback to manual JSON portal downloads',
                              style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                            ),
                            value: _enabled,
                            activeThumbColor: KColors.primary,
                            onChanged: (v) => setState(() => _enabled = v),
                          ),
                          const Divider(height: 24),
                          KTextField(
                            label: 'GSP Provider Name *',
                            hint: 'e.g. MastersIndia / ClearTax / IRIS',
                            controller: _provider,
                          ),
                          KSpacing.vGapSm,
                          KTextField(
                            label: 'API Gateway Base URL *',
                            hint: 'https://api.mastersindia.co',
                            controller: _baseUrl,
                            keyboardType: TextInputType.url,
                          ),
                          KSpacing.vGapSm,
                          KTextField(
                            label: 'Authorized GSTIN *',
                            hint: '27AABCT1234A1Z5',
                            controller: _gstin,
                          ),
                          KSpacing.vGapSm,
                          KTextField(
                            label: _tokenSet
                                ? 'Bearer Auth Token (Encrypted on Server — Enter new token to replace)'
                                : 'Bearer Auth Token / API Secret *',
                            hint: _tokenSet ? '•••••••• (Stored & Protected)' : 'Enter client secret token',
                            controller: _token,
                            obscureText: true,
                          ),
                        ],
                      ),
                    ),
                    KSpacing.vGapMd,
                    KCard(
                      title: 'Custom Endpoint Routing (Optional)',
                      subtitle: 'Override standard API endpoint URI paths if your aggregator uses custom gateways.',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          KTextField(
                            label: 'e-Invoice IRN Endpoint Path',
                            hint: '/einvoice/generate',
                            controller: _einvoicePath,
                          ),
                          KSpacing.vGapSm,
                          KTextField(
                            label: 'e-Way Bill Generation Path',
                            hint: '/ewaybill/generate',
                            controller: _ewaybillPath,
                          ),
                          KSpacing.vGapSm,
                          KTextField(
                            label: 'GSTR-2B Input Fetch Path',
                            hint: '/gstr2b/fetch',
                            controller: _gstr2bPath,
                          ),
                        ],
                      ),
                    ),
                    KSpacing.vGapLg,
                    Row(
                      children: [
                        Expanded(
                          child: KButton.primary(
                            label: 'Save GSP Configuration',
                            icon: Icons.save_rounded,
                            isLoading: _saving,
                            onPressed: _saving ? null : _save,
                          ),
                        ),
                        KSpacing.hGapMd,
                        KButton.outlined(
                          label: _testing ? 'Testing...' : 'Test Gateway Connection',
                          icon: Icons.wifi_tethering_rounded,
                          isLoading: _testing,
                          onPressed: (_testing || _saving) ? null : _test,
                        ),
                      ],
                    ),
                    if (_testMessage != null) ...[
                      KSpacing.vGapMd,
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _testOk
                              ? KColors.success.withValues(alpha: 0.12)
                              : KColors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(KSpacing.radiusMd),
                          border: Border.all(
                            color: _testOk
                                ? KColors.success.withValues(alpha: 0.3)
                                : KColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _testOk ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                              color: _testOk ? KColors.success : KColors.error,
                              size: 20,
                            ),
                            KSpacing.hGapSm,
                            Expanded(
                              child: Text(
                                _testMessage!,
                                style: KTypography.bodySmall.copyWith(
                                  color: _testOk ? KColors.success : KColors.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }
}
