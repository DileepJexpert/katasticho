import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/pos_providers.dart';

const _prefPrefix = 'receipt_';

class ReceiptSettings {
  final bool showStoreLogo;
  final bool showStoreAddress;
  final bool showGstin;
  final bool showHsnCode;
  final bool showItemSku;
  final bool showTaxBreakdown;
  final String footerText;
  final String paperSize; // '58mm' or '80mm'

  const ReceiptSettings({
    this.showStoreLogo = true,
    this.showStoreAddress = true,
    this.showGstin = true,
    this.showHsnCode = false,
    this.showItemSku = false,
    this.showTaxBreakdown = true,
    this.footerText = 'Thank you for your purchase!',
    this.paperSize = '58mm',
  });

  ReceiptSettings copyWith({
    bool? showStoreLogo,
    bool? showStoreAddress,
    bool? showGstin,
    bool? showHsnCode,
    bool? showItemSku,
    bool? showTaxBreakdown,
    String? footerText,
    String? paperSize,
  }) {
    return ReceiptSettings(
      showStoreLogo: showStoreLogo ?? this.showStoreLogo,
      showStoreAddress: showStoreAddress ?? this.showStoreAddress,
      showGstin: showGstin ?? this.showGstin,
      showHsnCode: showHsnCode ?? this.showHsnCode,
      showItemSku: showItemSku ?? this.showItemSku,
      showTaxBreakdown: showTaxBreakdown ?? this.showTaxBreakdown,
      footerText: footerText ?? this.footerText,
      paperSize: paperSize ?? this.paperSize,
    );
  }
}

class ReceiptSettingsNotifier extends StateNotifier<ReceiptSettings> {
  ReceiptSettingsNotifier() : super(const ReceiptSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = ReceiptSettings(
      showStoreLogo: prefs.getBool('${_prefPrefix}showStoreLogo') ?? true,
      showStoreAddress:
          prefs.getBool('${_prefPrefix}showStoreAddress') ?? true,
      showGstin: prefs.getBool('${_prefPrefix}showGstin') ?? true,
      showHsnCode: prefs.getBool('${_prefPrefix}showHsnCode') ?? false,
      showItemSku: prefs.getBool('${_prefPrefix}showItemSku') ?? false,
      showTaxBreakdown:
          prefs.getBool('${_prefPrefix}showTaxBreakdown') ?? true,
      footerText: prefs.getString('${_prefPrefix}footerText') ??
          'Thank you for your purchase!',
      paperSize: prefs.getString('${_prefPrefix}paperSize') ?? '58mm',
    );
  }

  Future<void> update(ReceiptSettings settings) async {
    state = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
        '${_prefPrefix}showStoreLogo', settings.showStoreLogo);
    await prefs.setBool(
        '${_prefPrefix}showStoreAddress', settings.showStoreAddress);
    await prefs.setBool('${_prefPrefix}showGstin', settings.showGstin);
    await prefs.setBool('${_prefPrefix}showHsnCode', settings.showHsnCode);
    await prefs.setBool('${_prefPrefix}showItemSku', settings.showItemSku);
    await prefs.setBool(
        '${_prefPrefix}showTaxBreakdown', settings.showTaxBreakdown);
    await prefs.setString('${_prefPrefix}footerText', settings.footerText);
    await prefs.setString('${_prefPrefix}paperSize', settings.paperSize);
  }
}

final receiptSettingsProvider =
    StateNotifierProvider<ReceiptSettingsNotifier, ReceiptSettings>((ref) {
  return ReceiptSettingsNotifier();
});

class PosReceiptSettingsScreen extends ConsumerWidget {
  const PosReceiptSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(receiptSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Receipt Settings')),
      body: ListView(
        padding: KSpacing.pagePadding,
        children: [
          Text('Paper Size', style: KTypography.h3),
          KSpacing.vGapSm,
          KCard(
            child: Column(
              children: [
                RadioListTile<String>(
                  value: '58mm',
                  groupValue: settings.paperSize,
                  onChanged: (v) => _update(ref, settings.copyWith(paperSize: v)),
                  title: const Text('58mm (Thermal)'),
                  subtitle: const Text('Standard POS thermal printer'),
                  dense: true,
                ),
                RadioListTile<String>(
                  value: '80mm',
                  groupValue: settings.paperSize,
                  onChanged: (v) => _update(ref, settings.copyWith(paperSize: v)),
                  title: const Text('80mm (Wide Thermal)'),
                  subtitle: const Text('Wide format thermal printer'),
                  dense: true,
                ),
              ],
            ),
          ),
          KSpacing.vGapLg,
          Text('Header', style: KTypography.h3),
          KSpacing.vGapSm,
          KCard(
            child: Column(
              children: [
                SwitchListTile(
                  value: settings.showStoreLogo,
                  onChanged: (v) =>
                      _update(ref, settings.copyWith(showStoreLogo: v)),
                  title: const Text('Show Store Logo'),
                  dense: true,
                ),
                SwitchListTile(
                  value: settings.showStoreAddress,
                  onChanged: (v) =>
                      _update(ref, settings.copyWith(showStoreAddress: v)),
                  title: const Text('Show Store Address'),
                  dense: true,
                ),
                SwitchListTile(
                  value: settings.showGstin,
                  onChanged: (v) =>
                      _update(ref, settings.copyWith(showGstin: v)),
                  title: const Text('Show GSTIN'),
                  dense: true,
                ),
              ],
            ),
          ),
          KSpacing.vGapLg,
          Text('Line Items', style: KTypography.h3),
          KSpacing.vGapSm,
          KCard(
            child: Column(
              children: [
                SwitchListTile(
                  value: settings.showHsnCode,
                  onChanged: (v) =>
                      _update(ref, settings.copyWith(showHsnCode: v)),
                  title: const Text('Show HSN/SAC Code'),
                  dense: true,
                ),
                SwitchListTile(
                  value: settings.showItemSku,
                  onChanged: (v) =>
                      _update(ref, settings.copyWith(showItemSku: v)),
                  title: const Text('Show Item SKU'),
                  dense: true,
                ),
                SwitchListTile(
                  value: settings.showTaxBreakdown,
                  onChanged: (v) =>
                      _update(ref, settings.copyWith(showTaxBreakdown: v)),
                  title: const Text('Show Tax Breakdown'),
                  subtitle: const Text('CGST + SGST / IGST per line'),
                  dense: true,
                ),
              ],
            ),
          ),
          KSpacing.vGapLg,
          Text('Footer', style: KTypography.h3),
          KSpacing.vGapSm,
          KTextField(
            label: 'Footer Message',
            initialValue: settings.footerText,
            maxLines: 2,
            onChanged: (v) =>
                _update(ref, settings.copyWith(footerText: v)),
          ),
          KSpacing.vGapLg,
          const _UpiSettingsSection(),
          KSpacing.vGapXl,
        ],
      ),
    );
  }

  void _update(WidgetRef ref, ReceiptSettings settings) {
    ref.read(receiptSettingsProvider.notifier).update(settings);
  }
}

class _UpiSettingsSection extends ConsumerStatefulWidget {
  const _UpiSettingsSection();

  @override
  ConsumerState<_UpiSettingsSection> createState() => _UpiSettingsSectionState();
}

class _UpiSettingsSectionState extends ConsumerState<_UpiSettingsSection> {
  final _upiIdCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _upiIdCtrl.dispose();
    _displayNameCtrl.dispose();
    super.dispose();
  }

  void _prefill(Map<String, String> settings) {
    if (!_loaded) {
      _upiIdCtrl.text = settings['upiId'] ?? '';
      _displayNameCtrl.text = settings['displayName'] ?? '';
      _loaded = true;
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.put(ApiConfig.upiSettings, data: {
        'upiId': _upiIdCtrl.text.trim(),
        'displayName': _displayNameCtrl.text.trim(),
      });
      ref.invalidate(upiSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('UPI settings saved')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save UPI settings'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final role = authState.role?.toUpperCase() ?? '';
    final canEdit = role == 'OWNER' || role == 'ADMIN';

    final upiAsync = ref.watch(upiSettingsProvider);
    upiAsync.whenData(_prefill);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('UPI Payment', style: KTypography.h3),
        KSpacing.vGapSm,
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set your UPI ID to show a scannable QR code in the payment sheet.',
                style: KTypography.bodySmall
                    .copyWith(color: Colors.grey.shade600),
              ),
              KSpacing.vGapSm,
              KTextField(
                label: 'UPI ID',
                hint: 'yourname@upi',
                controller: _upiIdCtrl,
                prefixIcon: Icons.qr_code_2,
                enabled: canEdit,
              ),
              KSpacing.vGapSm,
              KTextField(
                label: 'Display Name',
                hint: 'Store name shown on UPI app',
                controller: _displayNameCtrl,
                prefixIcon: Icons.store_outlined,
                enabled: canEdit,
              ),
              if (canEdit) ...[
                KSpacing.vGapSm,
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_outlined, size: 16),
                    label: Text(_saving ? 'Saving...' : 'Save UPI Settings'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
