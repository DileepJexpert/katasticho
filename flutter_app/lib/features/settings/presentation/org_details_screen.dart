import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _orgDetailsProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, orgId) async {
  final client = ref.watch(apiClientProvider);
  final res = await client.dio.get(ApiConfig.organisationById(orgId));
  return (res.data['data'] as Map<String, dynamic>?) ?? {};
});

// ── Screen ────────────────────────────────────────────────────────────────────

class OrgDetailsScreen extends ConsumerStatefulWidget {
  const OrgDetailsScreen({super.key});

  @override
  ConsumerState<OrgDetailsScreen> createState() => _OrgDetailsScreenState();
}

class _OrgDetailsScreenState extends ConsumerState<OrgDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _editing = false;
  bool _saving = false;

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _gstin = TextEditingController();
  final _addr1 = TextEditingController();
  final _addr2 = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _stateCode = TextEditingController();
  final _postal = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _gstin, _addr1, _addr2, _city, _state, _stateCode, _postal]) {
      c.dispose();
    }
    super.dispose();
  }

  void _populate(Map<String, dynamic> org) {
    _name.text = org['name'] as String? ?? '';
    _phone.text = org['phone'] as String? ?? '';
    _email.text = org['email'] as String? ?? '';
    _gstin.text = org['gstin'] as String? ?? '';
    _addr1.text = org['addressLine1'] as String? ?? '';
    _addr2.text = org['addressLine2'] as String? ?? '';
    _city.text = org['city'] as String? ?? '';
    _state.text = org['state'] as String? ?? '';
    _stateCode.text = org['stateCode'] as String? ?? '';
    _postal.text = org['postalCode'] as String? ?? '';
  }

  Future<void> _save(String orgId) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.dio.put(
        ApiConfig.organisationById(orgId),
        data: {
          'name': _name.text.trim(),
          'phone': _phone.text.trim(),
          'email': _email.text.trim(),
          'gstin': _gstin.text.trim(),
          'addressLine1': _addr1.text.trim(),
          'addressLine2': _addr2.text.trim(),
          'city': _city.text.trim(),
          'state': _state.text.trim(),
          'stateCode': _stateCode.text.trim().toUpperCase(),
          'postalCode': _postal.text.trim(),
        },
      );
      if (!mounted) return;
      ref.invalidate(_orgDetailsProvider(orgId));
      setState(() {
        _editing = false;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Organisation details saved')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgId = ref.watch(authProvider).orgId ?? '';
    final asyncOrg = ref.watch(_orgDetailsProvider(orgId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Organisation Details'),
        actions: [
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () => setState(() => _editing = true),
            ),
        ],
      ),
      body: asyncOrg.when(
        loading: () => const KShimmerList(),
        error: (err, _) => KErrorView(
          message: 'Failed to load organisation details',
          onRetry: () => ref.invalidate(_orgDetailsProvider(orgId)),
        ),
        data: (org) {
          if (!_editing) {
            // Populate on first load and when coming back from editing
            WidgetsBinding.instance.addPostFrameCallback((_) => _populate(org));
          }
          return _editing
              ? _buildForm(orgId)
              : _buildReadOnly(org);
        },
      ),
    );
  }

  Widget _buildReadOnly(Map<String, dynamic> org) {
    return SingleChildScrollView(
      padding: KSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(label: 'Business Name', value: org['name']),
                _InfoRow(label: 'GSTIN', value: org['gstin']),
                _InfoRow(label: 'Phone', value: org['phone']),
                _InfoRow(label: 'Email', value: org['email']),
              ],
            ),
          ),
          KSpacing.vGapMd,
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Address', style: KTypography.labelSmall.copyWith(color: KColors.textSecondary)),
                KSpacing.vGapSm,
                _InfoRow(label: 'Line 1', value: org['addressLine1']),
                _InfoRow(label: 'Line 2', value: org['addressLine2']),
                _InfoRow(label: 'City', value: org['city']),
                _InfoRow(label: 'State', value: org['state']),
                _InfoRow(label: 'State Code', value: org['stateCode']),
                _InfoRow(label: 'Postal Code', value: org['postalCode']),
              ],
            ),
          ),
          KSpacing.vGapMd,
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(label: 'Industry', value: org['industryCode']),
                _InfoRow(label: 'Business Type', value: org['businessType']),
                _InfoRow(label: 'Plan', value: org['planTier']),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(String orgId) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: KSpacing.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Business Info', style: KTypography.h3),
            KSpacing.vGapSm,
            KCard(
              child: Column(
                children: [
                  _field(_name, 'Business Name', required: true),
                  KSpacing.vGapSm,
                  _field(_gstin, 'GSTIN', hint: '22ABCDE1234F1Z5'),
                  KSpacing.vGapSm,
                  _field(_phone, 'Phone', keyboard: TextInputType.phone),
                  KSpacing.vGapSm,
                  _field(_email, 'Email', keyboard: TextInputType.emailAddress),
                ],
              ),
            ),
            KSpacing.vGapLg,
            Text('Address', style: KTypography.h3),
            KSpacing.vGapSm,
            KCard(
              child: Column(
                children: [
                  _field(_addr1, 'Address Line 1'),
                  KSpacing.vGapSm,
                  _field(_addr2, 'Address Line 2'),
                  KSpacing.vGapSm,
                  Row(
                    children: [
                      Expanded(child: _field(_city, 'City')),
                      KSpacing.hGapSm,
                      Expanded(child: _field(_postal, 'Postal Code')),
                    ],
                  ),
                  KSpacing.vGapSm,
                  Row(
                    children: [
                      Expanded(flex: 3, child: _field(_state, 'State')),
                      KSpacing.hGapSm,
                      Expanded(child: _field(_stateCode, 'Code', hint: 'MH')),
                    ],
                  ),
                ],
              ),
            ),
            KSpacing.vGapLg,
            Row(
              children: [
                Expanded(
                  child: KButton(
                    label: 'Cancel',
                    variant: KButtonVariant.secondary,
                    fullWidth: true,
                    onPressed: _saving ? null : () => setState(() => _editing = false),
                  ),
                ),
                KSpacing.hGapMd,
                Expanded(
                  child: KButton(
                    label: 'Save',
                    fullWidth: true,
                    loading: _saving,
                    onPressed: _saving ? null : () => _save(orgId),
                  ),
                ),
              ],
            ),
            KSpacing.vGapXl,
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    String? hint,
    bool required = false,
    TextInputType? keyboard,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final dynamic value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final v = value?.toString() ?? '';
    if (v.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
          ),
          Expanded(child: Text(v, style: KTypography.bodyMedium)),
        ],
      ),
    );
  }
}
