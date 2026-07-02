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
            child: RadioGroup<String>(
              groupValue: settings.paperSize,
              onChanged: (v) => _update(ref, settings.copyWith(paperSize: v)),
              child: Column(
                children: const [
                  RadioListTile<String>(
                    value: '58mm',
                    title: Text('58mm (Thermal)'),
                    subtitle: Text('Standard POS thermal printer'),
                    dense: true,
                  ),
                  RadioListTile<String>(
                    value: '80mm',
                    title: Text('80mm (Wide Thermal)'),
                    subtitle: Text('Wide format thermal printer'),
                    dense: true,
                  ),
                ],
              ),
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
          const _BillingPolicySection(),
          KSpacing.vGapLg,
          const _UpiSettingsSection(),
          KSpacing.vGapLg,
          const _SmsSettingsSection(),
          KSpacing.vGapLg,
          const _WhatsAppSettingsSection(),
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

class _WhatsAppSettingsSection extends ConsumerStatefulWidget {
  const _WhatsAppSettingsSection();

  @override
  ConsumerState<_WhatsAppSettingsSection> createState() =>
      _WhatsAppSettingsSectionState();
}

class _WhatsAppSettingsSectionState
    extends ConsumerState<_WhatsAppSettingsSection> {
  final _apiKeyCtrl = TextEditingController();
  final _phoneIdCtrl = TextEditingController();
  final _customUrlCtrl = TextEditingController();
  final _langCtrl = TextEditingController(text: 'en');
  final _tplInvoiceCtrl = TextEditingController();
  final _tplReceiptCtrl = TextEditingController();
  final _tplReminderCtrl = TextEditingController();
  bool _enabled = false;
  bool _autoSendReceipt = false;
  String _provider = 'META';
  bool _saving = false;
  bool _prefilled = false;

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _phoneIdCtrl.dispose();
    _customUrlCtrl.dispose();
    _langCtrl.dispose();
    _tplInvoiceCtrl.dispose();
    _tplReceiptCtrl.dispose();
    _tplReminderCtrl.dispose();
    super.dispose();
  }

  void _prefill(Map<String, String> s) {
    if (_prefilled) return;
    _prefilled = true;
    setState(() {
      _enabled = s['enabled'] == 'true';
      _autoSendReceipt = s['autoSendReceipt'] == 'true';
      _provider = s['provider'] ?? 'META';
      _phoneIdCtrl.text = s['phoneNumberId'] ?? '';
      _customUrlCtrl.text = s['customUrl'] ?? '';
      _langCtrl.text = s['lang'] ?? 'en';
      _tplInvoiceCtrl.text = s['templateInvoice'] ?? '';
      _tplReceiptCtrl.text = s['templateReceipt'] ?? '';
      _tplReminderCtrl.text = s['templateReminder'] ?? '';
      // apiKey is write-only; leave the field blank (apiKeySet tells if one exists)
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final client = ref.read(apiClientProvider);
      final data = <String, String>{
        'enabled': _enabled.toString(),
        'autoSendReceipt': _autoSendReceipt.toString(),
        'provider': _provider,
        'phoneNumberId': _phoneIdCtrl.text.trim(),
        'customUrl': _customUrlCtrl.text.trim(),
        'lang': _langCtrl.text.trim(),
        'templateInvoice': _tplInvoiceCtrl.text.trim(),
        'templateReceipt': _tplReceiptCtrl.text.trim(),
        'templateReminder': _tplReminderCtrl.text.trim(),
      };
      if (_apiKeyCtrl.text.trim().isNotEmpty) {
        data['apiKey'] = _apiKeyCtrl.text.trim();
      }
      await client.put(ApiConfig.whatsappSettings, data: data);
      ref.invalidate(whatsappSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('WhatsApp settings saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).role?.toUpperCase() ?? '';
    final canEdit = role == 'OWNER' || role == 'ADMIN';
    final waAsync = ref.watch(whatsappSettingsProvider);
    waAsync.whenData(_prefill);
    final keySet = waAsync.asData?.value['apiKeySet'] == 'true';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('WhatsApp Documents', style: KTypography.h3),
        KSpacing.vGapSm,
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable WhatsApp Sending'),
                  subtitle: const Text(
                      'Send invoices, receipts & reminders via WhatsApp Business API'),
                  value: _enabled,
                  onChanged: canEdit ? (v) => setState(() => _enabled = v) : null,
                ),
                if (_enabled) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto-send POS receipt'),
                    subtitle:
                        const Text('Send each receipt automatically after sale'),
                    value: _autoSendReceipt,
                    onChanged: canEdit
                        ? (v) => setState(() => _autoSendReceipt = v)
                        : null,
                  ),
                  KSpacing.vGapSm,
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Provider',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: _provider,
                    items: const [
                      DropdownMenuItem(
                          value: 'META', child: Text('Meta Cloud API')),
                      DropdownMenuItem(
                          value: 'CUSTOM', child: Text('Custom aggregator')),
                    ],
                    onChanged: canEdit
                        ? (v) => setState(() => _provider = v ?? 'META')
                        : null,
                  ),
                  KSpacing.vGapSm,
                  KTextField(
                    label: keySet ? 'Access Token (set — leave blank to keep)' : 'Access Token / API Key',
                    hint: 'Provider access token',
                    controller: _apiKeyCtrl,
                    enabled: canEdit,
                    obscureText: true,
                  ),
                  if (_provider == 'META') ...[
                    KSpacing.vGapSm,
                    KTextField(
                      label: 'Phone Number ID',
                      hint: 'WhatsApp Cloud API phone number id',
                      controller: _phoneIdCtrl,
                      enabled: canEdit,
                    ),
                  ] else ...[
                    KSpacing.vGapSm,
                    KTextField(
                      label: 'Webhook URL',
                      hint: 'https://aggregator.example.com/send',
                      controller: _customUrlCtrl,
                      enabled: canEdit,
                    ),
                  ],
                  KSpacing.vGapSm,
                  KTextField(
                    label: 'Template Language',
                    hint: 'en',
                    controller: _langCtrl,
                    enabled: canEdit,
                  ),
                  KSpacing.vGapSm,
                  KTextField(
                    label: 'Invoice Template Name',
                    hint: 'invoice_document',
                    controller: _tplInvoiceCtrl,
                    enabled: canEdit,
                  ),
                  KSpacing.vGapSm,
                  KTextField(
                    label: 'Receipt Template Name',
                    hint: 'receipt_document',
                    controller: _tplReceiptCtrl,
                    enabled: canEdit,
                  ),
                  KSpacing.vGapSm,
                  KTextField(
                    label: 'Reminder Template Name',
                    hint: 'payment_reminder',
                    controller: _tplReminderCtrl,
                    enabled: canEdit,
                  ),
                ],
                if (canEdit) ...[
                  KSpacing.vGapMd,
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save_outlined, size: 16),
                      label: Text(_saving ? 'Saving...' : 'Save WhatsApp Settings'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Counter billing policy — toggles `pos.allow_negative_stock`. When on (the
/// default), the POS adds a medicine in one tap and sells any quantity even at
/// 0 stock (stock goes negative, reconciled later). Off = strict stock control.
class _BillingPolicySection extends ConsumerStatefulWidget {
  const _BillingPolicySection();

  @override
  ConsumerState<_BillingPolicySection> createState() =>
      _BillingPolicySectionState();
}

class _BillingPolicySectionState extends ConsumerState<_BillingPolicySection> {
  bool _saving = false;

  Future<void> _setAllowNegative(bool value) async {
    setState(() => _saving = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.put('${ApiConfig.orgSettings}/pos.allow_negative_stock',
          data: {'value': value.toString()});
      ref.invalidate(posAllowNegativeStockProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(value
                ? 'Bill freely is on — counter sells even at 0 stock'
                : 'Strict stock control is on — short sales are blocked')));
      }
    } catch (e) {
      ref.invalidate(posAllowNegativeStockProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setAllowCreditSales(bool value) async {
    setState(() => _saving = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.put('${ApiConfig.orgSettings}/pos.allow_credit_sales',
          data: {'value': value.toString()});
      ref.invalidate(posAllowCreditSalesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(value
                ? 'Khata sales are on — the POS shows a Khata payment button'
                : 'Khata sales are off')));
      }
    } catch (e) {
      ref.invalidate(posAllowCreditSalesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).role?.toUpperCase() ?? '';
    final canEdit = role == 'OWNER' || role == 'ADMIN';
    final allow = ref.watch(posAllowNegativeStockProvider).valueOrNull ?? true;
    final allowCredit =
        ref.watch(posAllowCreditSalesProvider).valueOrNull ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Billing', style: KTypography.h3),
        KSpacing.vGapSm,
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bill freely (sell without stock)'),
                  subtitle: const Text(
                      'Add a medicine in one tap and sell any quantity even when '
                      'stock shows 0. Stock can go negative and is corrected later '
                      'with a stock receipt. Turn off for strict stock control.'),
                  value: allow,
                  onChanged: (canEdit && !_saving)
                      ? (v) => _setAllowNegative(v)
                      : null,
                ),
                const Divider(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Khata (credit) sales'),
                  subtitle: const Text(
                      'Show a Khata button at checkout: nothing is collected, '
                      'the bill total goes on the selected customer\'s '
                      'outstanding and shows in the credit ledger and '
                      'collections. A customer must be selected on the bill.'),
                  value: allowCredit,
                  onChanged: (canEdit && !_saving)
                      ? (v) => _setAllowCreditSales(v)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SmsSettingsSection extends ConsumerStatefulWidget {
  const _SmsSettingsSection();

  @override
  ConsumerState<_SmsSettingsSection> createState() =>
      _SmsSettingsSectionState();
}

class _SmsSettingsSectionState extends ConsumerState<_SmsSettingsSection> {
  final _apiKeyCtrl = TextEditingController();
  final _senderIdCtrl = TextEditingController();
  bool _enabled = false;
  String _provider = 'FAST2SMS';
  bool _saving = false;
  bool _prefilled = false;

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _senderIdCtrl.dispose();
    super.dispose();
  }

  void _prefill(Map<String, String> s) {
    if (_prefilled) return;
    _prefilled = true;
    setState(() {
      _enabled = s['enabled'] == 'true';
      _provider = s['provider'] ?? 'FAST2SMS';
      _apiKeyCtrl.text = s['apiKey'] ?? '';
      _senderIdCtrl.text = s['senderId'] ?? 'KTSEPR';
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.put(ApiConfig.smsSettings, data: {
        'enabled': _enabled.toString(),
        'provider': _provider,
        'apiKey': _apiKeyCtrl.text.trim(),
        'senderId': _senderIdCtrl.text.trim(),
      });
      ref.invalidate(smsSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SMS settings saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).role?.toUpperCase() ?? '';
    final canEdit = role == 'OWNER' || role == 'ADMIN';
    final smsAsync = ref.watch(smsSettingsProvider);
    smsAsync.whenData(_prefill);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SMS Notifications', style: KTypography.h3),
        KSpacing.vGapSm,
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable SMS Notifications'),
                  subtitle: const Text('Send receipt SMS to customers'),
                  value: _enabled,
                  onChanged: canEdit ? (v) => setState(() => _enabled = v) : null,
                ),
                if (_enabled) ...[
                  KSpacing.vGapSm,
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'SMS Provider',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: _provider,
                    items: const [
                      DropdownMenuItem(value: 'FAST2SMS', child: Text('Fast2SMS')),
                      DropdownMenuItem(value: 'MSG91', child: Text('MSG91')),
                    ],
                    onChanged: canEdit
                        ? (v) => setState(() => _provider = v ?? 'FAST2SMS')
                        : null,
                  ),
                  KSpacing.vGapSm,
                  KTextField(
                    label: 'API Key',
                    hint: 'Provider API key',
                    controller: _apiKeyCtrl,
                    enabled: canEdit,
                    obscureText: true,
                  ),
                  if (_provider == 'MSG91') ...[
                    KSpacing.vGapSm,
                    KTextField(
                      label: 'Sender ID',
                      hint: '6-char alphanumeric (e.g. KTSEPR)',
                      controller: _senderIdCtrl,
                      enabled: canEdit,
                    ),
                  ],
                ],
                if (canEdit) ...[
                  KSpacing.vGapMd,
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save_outlined, size: 16),
                      label: Text(_saving ? 'Saving...' : 'Save SMS Settings'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
