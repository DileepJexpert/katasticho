import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';

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
          KSpacing.vGapXl,
        ],
      ),
    );
  }

  void _update(WidgetRef ref, ReceiptSettings settings) {
    ref.read(receiptSettingsProvider.notifier).update(settings);
  }
}
