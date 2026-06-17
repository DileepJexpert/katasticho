import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
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
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'enabled': _enabled,
        'provider': _provider.text.trim(),
        'baseUrl': _baseUrl.text.trim(),
        'gstin': _gstin.text.trim(),
        'einvoicePath': _einvoicePath.text.trim(),
        'ewaybillPath': _ewaybillPath.text.trim(),
        'gstr2bPath': _gstr2bPath.text.trim(),
        // Token is write-only: only send when the user typed a new one.
        if (_token.text.trim().isNotEmpty) 'token': _token.text.trim(),
      };
      final s = await ref.read(gstRepositoryProvider).updateGspSettings(body);
      if (!mounted) return;
      setState(() {
        _tokenSet = s['tokenSet'] == true;
        _token.clear();
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GSP settings saved')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Save failed: ${e.toString().replaceAll('Exception: ', '')}'),
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
        _testMessage = 'Test failed: ${e.toString().replaceAll('Exception: ', '')}';
        _testing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GSP Connection')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: KSpacing.pagePadding,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        KSpacing.vGapMd,
                        KButton(label: 'Retry', onPressed: _load),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: KSpacing.pagePadding,
                  children: [
                    KCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('What is a GSP?', style: KTypography.h3),
                          KSpacing.vGapSm,
                          Text(
                            'A GST Suvidha Provider (e.g. Masters India, ClearTax) '
                            'is an aggregator that talks to the GST/NIC portals for '
                            'you. With credentials below you can generate e-invoice '
                            'IRNs, e-way bills, and pull GSTR-2B in one tap — no '
                            'manual portal download/upload.',
                            style: KTypography.bodySmall
                                .copyWith(color: KColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    KSpacing.vGapMd,
                    KCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Enable GSP integration'),
                            subtitle: const Text(
                                'Off = manual portal upload only'),
                            value: _enabled,
                            onChanged: (v) => setState(() => _enabled = v),
                          ),
                          const Divider(),
                          KSpacing.vGapSm,
                          KTextField(
                            label: 'Provider name',
                            hint: 'e.g. MastersIndia',
                            controller: _provider,
                          ),
                          KSpacing.vGapSm,
                          KTextField(
                            label: 'Base URL',
                            hint: 'https://api.example.com',
                            controller: _baseUrl,
                            keyboardType: TextInputType.url,
                          ),
                          KSpacing.vGapSm,
                          KTextField(
                            label: 'Your GSTIN',
                            hint: '27AABCT1234A1Z5',
                            controller: _gstin,
                          ),
                          KSpacing.vGapSm,
                          KTextField(
                            label: _tokenSet
                                ? 'API token (saved — type to replace)'
                                : 'API token',
                            hint: _tokenSet ? '•••••••• stored' : 'Bearer token / API key',
                            controller: _token,
                            obscureText: true,
                          ),
                        ],
                      ),
                    ),
                    KSpacing.vGapMd,
                    KCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Endpoint paths (optional)',
                              style: KTypography.labelLarge),
                          KSpacing.vGapXs,
                          Text(
                            'Leave blank to use defaults. Appended to the base URL.',
                            style: KTypography.bodySmall
                                .copyWith(color: KColors.textSecondary),
                          ),
                          KSpacing.vGapSm,
                          KTextField(
                            label: 'e-Invoice path',
                            hint: '/einvoice/generate',
                            controller: _einvoicePath,
                          ),
                          KSpacing.vGapSm,
                          KTextField(
                            label: 'e-Way bill path',
                            hint: '/ewaybill/generate',
                            controller: _ewaybillPath,
                          ),
                          KSpacing.vGapSm,
                          KTextField(
                            label: 'GSTR-2B fetch path',
                            hint: '/gstr2b/fetch',
                            controller: _gstr2bPath,
                          ),
                        ],
                      ),
                    ),
                    KSpacing.vGapLg,
                    KButton(
                      label: _saving ? 'Saving…' : 'Save GSP settings',
                      icon: Icons.save,
                      isLoading: _saving,
                      onPressed: _saving ? null : _save,
                    ),
                    KSpacing.vGapSm,
                    OutlinedButton.icon(
                      onPressed: (_testing || _saving) ? null : _test,
                      icon: const Icon(Icons.wifi_tethering),
                      label: Text(_testing ? 'Testing…' : 'Test connection'),
                    ),
                    if (_testMessage != null) ...[
                      KSpacing.vGapSm,
                      Row(
                        children: [
                          Icon(
                            _testOk ? Icons.check_circle : Icons.error_outline,
                            color: _testOk ? KColors.success : KColors.error,
                            size: 18,
                          ),
                          KSpacing.hGapSm,
                          Expanded(
                            child: Text(
                              _testMessage!,
                              style: KTypography.bodySmall.copyWith(
                                color: _testOk ? KColors.success : KColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
    );
  }
}
