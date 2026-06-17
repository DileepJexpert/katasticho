import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/courier_repository.dart';

/// Per-partner courier credentials (BlueDart, Delhivery, India Post, DTDC,
/// Shiprocket). Mirrors the GSP settings screen — tokens are write-only.
class CourierSettingsScreen extends ConsumerStatefulWidget {
  const CourierSettingsScreen({super.key});

  @override
  ConsumerState<CourierSettingsScreen> createState() =>
      _CourierSettingsScreenState();
}

const _partners = ['BLUEDART', 'DELHIVERY', 'INDIA_POST', 'DTDC', 'SHIPROCKET', 'OTHER'];

class _CourierSettingsScreenState extends ConsumerState<CourierSettingsScreen> {
  Map<String, dynamic>? _settings;
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
      final r = await ref.read(courierRepositoryProvider).getCourierSettings();
      if (mounted) {
        setState(() {
          _settings = r;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Courier Connections')),
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
                          Text('Hook up your couriers',
                              style: KTypography.h3),
                          KSpacing.vGapSm,
                          Text(
                            'Each row is a courier (or aggregator like Shiprocket) '
                            'that can book parcels, push tracking events, and remit '
                            'COD collections. Off = manual AWB entry only. Tokens are '
                            'write-only — never echoed back.',
                            style: KTypography.bodySmall
                                .copyWith(color: KColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    KSpacing.vGapMd,
                    ..._partners.map((p) => _PartnerCard(
                          partner: p,
                          settings:
                              (_settings?[p] as Map?)?.cast<String, dynamic>() ??
                                  {},
                          onChanged: _load,
                        )),
                  ],
                ),
    );
  }
}

class _PartnerCard extends ConsumerStatefulWidget {
  final String partner;
  final Map<String, dynamic> settings;
  final VoidCallback onChanged;

  const _PartnerCard({
    required this.partner,
    required this.settings,
    required this.onChanged,
  });

  @override
  ConsumerState<_PartnerCard> createState() => _PartnerCardState();
}

class _PartnerCardState extends ConsumerState<_PartnerCard> {
  late final TextEditingController _baseUrl;
  late final TextEditingController _bookPath;
  late final TextEditingController _trackPath;
  late final TextEditingController _codPath;
  final TextEditingController _token = TextEditingController();

  late bool _enabled;
  late bool _tokenSet;
  bool _saving = false;
  bool _testing = false;
  String? _testMessage;
  bool _testOk = false;

  @override
  void initState() {
    super.initState();
    _baseUrl = TextEditingController(
        text: (widget.settings['baseUrl'] ?? '').toString());
    _bookPath = TextEditingController(
        text: (widget.settings['bookPath'] ?? '').toString());
    _trackPath = TextEditingController(
        text: (widget.settings['trackPath'] ?? '').toString());
    _codPath = TextEditingController(
        text: (widget.settings['codRemittancePath'] ?? '').toString());
    _enabled = widget.settings['enabled'] == true;
    _tokenSet = widget.settings['tokenSet'] == true;
  }

  @override
  void dispose() {
    for (final c in [_baseUrl, _bookPath, _trackPath, _codPath, _token]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'enabled': _enabled,
        'baseUrl': _baseUrl.text.trim(),
        'bookPath': _bookPath.text.trim(),
        'trackPath': _trackPath.text.trim(),
        'codRemittancePath': _codPath.text.trim(),
        if (_token.text.trim().isNotEmpty) 'token': _token.text.trim(),
      };
      await ref
          .read(courierRepositoryProvider)
          .updateCourierSettings(widget.partner, body);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${widget.partner} settings saved'),
      ));
      if (_token.text.trim().isNotEmpty) {
        setState(() => _tokenSet = true);
        _token.clear();
      }
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('Save failed: ${e.toString().replaceAll('Exception: ', '')}'),
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testMessage = null;
    });
    try {
      final r =
          await ref.read(courierRepositoryProvider).testCourier(widget.partner);
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
        _testMessage =
            'Test failed: ${e.toString().replaceAll('Exception: ', '')}';
        _testing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: KCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(widget.partner.replaceAll('_', ' '),
                  style: KTypography.labelLarge),
              subtitle: const Text('Enable to use this courier'),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            const Divider(),
            KSpacing.vGapSm,
            KTextField(
              label: 'Base URL',
              hint: 'https://api.${widget.partner.toLowerCase()}.example.com',
              controller: _baseUrl,
              keyboardType: TextInputType.url,
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
            KSpacing.vGapSm,
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Endpoint paths (optional)'),
              children: [
                KTextField(
                    label: 'Book shipment path',
                    hint: '/shipments/book',
                    controller: _bookPath),
                KSpacing.vGapSm,
                KTextField(
                    label: 'Track shipment path',
                    hint: '/shipments/track',
                    controller: _trackPath),
                KSpacing.vGapSm,
                KTextField(
                    label: 'COD remittance path',
                    hint: '/cod/remittances',
                    controller: _codPath),
              ],
            ),
            KSpacing.vGapMd,
            Row(
              children: [
                Expanded(
                  child: KButton(
                    label: _saving ? 'Saving…' : 'Save',
                    icon: Icons.save,
                    isLoading: _saving,
                    onPressed: _saving ? null : _save,
                  ),
                ),
                KSpacing.hGapSm,
                OutlinedButton.icon(
                  onPressed: (_testing || _saving) ? null : _test,
                  icon: const Icon(Icons.wifi_tethering),
                  label: Text(_testing ? 'Testing…' : 'Test'),
                ),
              ],
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
      ),
    );
  }
}
