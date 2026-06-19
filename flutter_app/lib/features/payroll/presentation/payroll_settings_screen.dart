import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';

/// Payroll module settings screen.
///
/// Lets the org owner / admin configure pay frequency, statutory compliance
/// toggles (PF, ESI, PT, LWF, TDS) and GL account mappings for payroll
/// journal postings.
class PayrollSettingsScreen extends ConsumerStatefulWidget {
  const PayrollSettingsScreen({super.key});

  @override
  ConsumerState<PayrollSettingsScreen> createState() =>
      _PayrollSettingsScreenState();
}

class _PayrollSettingsScreenState extends ConsumerState<PayrollSettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  // ── Form state ──
  String _payFrequency = 'MONTHLY';
  bool _pfEnabled = false;
  bool _esiEnabled = false;
  bool _ptEnabled = false;
  bool _lwfEnabled = false;
  bool _tdsEnabled = false;

  final _salaryExpenseAccountCtl = TextEditingController();
  final _salaryPayableAccountCtl = TextEditingController();
  final _pfPayableAccountCtl = TextEditingController();
  final _esiPayableAccountCtl = TextEditingController();
  final _ptPayableAccountCtl = TextEditingController();
  final _lwfPayableAccountCtl = TextEditingController();
  final _tdsPayableAccountCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _salaryExpenseAccountCtl.dispose();
    _salaryPayableAccountCtl.dispose();
    _pfPayableAccountCtl.dispose();
    _esiPayableAccountCtl.dispose();
    _ptPayableAccountCtl.dispose();
    _lwfPayableAccountCtl.dispose();
    _tdsPayableAccountCtl.dispose();
    super.dispose();
  }

  // ── Load ──

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get(ApiConfig.payrollSettings);
      final data = response.data['data'] as Map<String, dynamic>?;
      if (data != null) {
        _applyData(data);
      }
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = ApiErrorParser.message(e);
      });
    }
  }

  void _applyData(Map<String, dynamic> data) {
    _payFrequency = data['payFrequency'] as String? ?? 'MONTHLY';
    _pfEnabled = data['pfEnabled'] as bool? ?? false;
    _esiEnabled = data['esiEnabled'] as bool? ?? false;
    _ptEnabled = data['ptEnabled'] as bool? ?? false;
    _lwfEnabled = data['lwfEnabled'] as bool? ?? false;
    _tdsEnabled = data['tdsEnabled'] as bool? ?? false;
    _salaryExpenseAccountCtl.text =
        data['salaryExpenseAccountId'] as String? ?? '';
    _salaryPayableAccountCtl.text =
        data['salaryPayableAccountId'] as String? ?? '';
    _pfPayableAccountCtl.text = data['pfPayableAccountId'] as String? ?? '';
    _esiPayableAccountCtl.text = data['esiPayableAccountId'] as String? ?? '';
    _ptPayableAccountCtl.text = data['ptPayableAccountId'] as String? ?? '';
    _lwfPayableAccountCtl.text = data['lwfPayableAccountId'] as String? ?? '';
    _tdsPayableAccountCtl.text = data['tdsPayableAccountId'] as String? ?? '';
  }

  // ── Save ──

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final body = <String, dynamic>{
        'payFrequency': _payFrequency,
        'pfEnabled': _pfEnabled,
        'esiEnabled': _esiEnabled,
        'ptEnabled': _ptEnabled,
        'lwfEnabled': _lwfEnabled,
        'tdsEnabled': _tdsEnabled,
        'salaryExpenseAccountId': _nullIfEmpty(_salaryExpenseAccountCtl.text),
        'salaryPayableAccountId': _nullIfEmpty(_salaryPayableAccountCtl.text),
        'pfPayableAccountId': _nullIfEmpty(_pfPayableAccountCtl.text),
        'esiPayableAccountId': _nullIfEmpty(_esiPayableAccountCtl.text),
        'ptPayableAccountId': _nullIfEmpty(_ptPayableAccountCtl.text),
        'lwfPayableAccountId': _nullIfEmpty(_lwfPayableAccountCtl.text),
        'tdsPayableAccountId': _nullIfEmpty(_tdsPayableAccountCtl.text),
      };
      final response = await api.put(ApiConfig.payrollSettings, data: body);
      final data = response.data['data'] as Map<String, dynamic>?;
      if (data != null) _applyData(data);
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payroll settings saved'),
          backgroundColor: KColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = ApiErrorParser.message(e);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiErrorParser.message(e)),
          backgroundColor: KColors.error,
        ),
      );
    }
  }

  String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payroll Settings'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const KLoading();

    if (_error != null && _isLoading == false && _payFrequency.isEmpty) {
      return KErrorView(
        message: _error ?? 'Failed to load payroll settings',
        onRetry: _load,
      );
    }

    return SingleChildScrollView(
      padding: KSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Error banner (non-fatal — settings may have loaded partially)
          if (_error != null) ...[
            KErrorBanner(message: _error!),
            KSpacing.vGapMd,
          ],

          // ── Pay Frequency ──
          Text('Pay Frequency', style: KTypography.h3),
          KSpacing.vGapSm,
          KCard(
            child: DropdownButtonFormField<String>(
              initialValue: _payFrequency,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Frequency',
                isDense: true,
                border: InputBorder.none,
              ),
              items: const [
                DropdownMenuItem(
                  value: 'MONTHLY',
                  child: Text('Monthly'),
                ),
                DropdownMenuItem(
                  value: 'SEMI_MONTHLY',
                  child: Text('Semi-Monthly'),
                ),
                DropdownMenuItem(
                  value: 'WEEKLY',
                  child: Text('Weekly'),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _payFrequency = v);
              },
            ),
          ),
          KSpacing.vGapLg,

          // ── Statutory Compliance ──
          Text('Statutory Compliance', style: KTypography.h3),
          KSpacing.vGapSm,
          KCard(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  value: _pfEnabled,
                  onChanged: (v) => setState(() => _pfEnabled = v),
                  title: const Text('PF (Provident Fund)'),
                  subtitle: const Text('Employee & employer PF contributions'),
                  activeThumbColor: KColors.primary,
                  dense: true,
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  value: _esiEnabled,
                  onChanged: (v) => setState(() => _esiEnabled = v),
                  title: const Text('ESI (Employee State Insurance)'),
                  subtitle: const Text('Applicable if gross wages <= 21,000/month'),
                  activeThumbColor: KColors.primary,
                  dense: true,
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  value: _ptEnabled,
                  onChanged: (v) => setState(() => _ptEnabled = v),
                  title: const Text('PT (Professional Tax)'),
                  subtitle: const Text('State-level professional tax deduction'),
                  activeThumbColor: KColors.primary,
                  dense: true,
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  value: _lwfEnabled,
                  onChanged: (v) => setState(() => _lwfEnabled = v),
                  title: const Text('LWF (Labour Welfare Fund)'),
                  subtitle:
                      const Text('State-level labour welfare fund contribution'),
                  activeThumbColor: KColors.primary,
                  dense: true,
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  value: _tdsEnabled,
                  onChanged: (v) => setState(() => _tdsEnabled = v),
                  title: const Text('TDS (Tax Deducted at Source)'),
                  subtitle: const Text('Income tax deduction under Section 192'),
                  activeThumbColor: KColors.primary,
                  dense: true,
                ),
              ],
            ),
          ),
          KSpacing.vGapLg,

          // ── Account Mappings ──
          Text('Account Mappings', style: KTypography.h3),
          KSpacing.vGapXs,
          Text(
            'Map payroll postings to your Chart of Accounts. '
            'Leave blank to use system defaults.',
            style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
          ),
          KSpacing.vGapSm,
          KCard(
            child: Column(
              children: [
                _AccountField(
                  label: 'Salary Expense Account',
                  controller: _salaryExpenseAccountCtl,
                ),
                const Divider(height: 1),
                _AccountField(
                  label: 'Salary Payable Account',
                  controller: _salaryPayableAccountCtl,
                ),
                if (_pfEnabled) ...[
                  const Divider(height: 1),
                  _AccountField(
                    label: 'PF Payable Account',
                    controller: _pfPayableAccountCtl,
                  ),
                ],
                if (_esiEnabled) ...[
                  const Divider(height: 1),
                  _AccountField(
                    label: 'ESI Payable Account',
                    controller: _esiPayableAccountCtl,
                  ),
                ],
                if (_ptEnabled) ...[
                  const Divider(height: 1),
                  _AccountField(
                    label: 'PT Payable Account',
                    controller: _ptPayableAccountCtl,
                  ),
                ],
                if (_lwfEnabled) ...[
                  const Divider(height: 1),
                  _AccountField(
                    label: 'LWF Payable Account',
                    controller: _lwfPayableAccountCtl,
                  ),
                ],
                if (_tdsEnabled) ...[
                  const Divider(height: 1),
                  _AccountField(
                    label: 'TDS Payable Account',
                    controller: _tdsPayableAccountCtl,
                  ),
                ],
              ],
            ),
          ),
          KSpacing.vGapXl,
        ],
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _AccountField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _AccountField({
    required this.label,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          return TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              hintText: 'Not configured',
              isDense: true,
              border: InputBorder.none,
              suffixIcon: value.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => controller.clear(),
                      tooltip: 'Clear',
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}
