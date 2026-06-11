import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../accounts/data/account_repository.dart';

/// Budgets: one annual amount per account per fiscal year. The Budget vs
/// Actual report (Reports → Financial) pro-rates these over the viewed period.
class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetLineEdit {
  AccountDto? account;
  final TextEditingController amountCtl;
  _BudgetLineEdit({this.account, String amount = ''})
      : amountCtl = TextEditingController(text: amount);
  void dispose() => amountCtl.dispose();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  late int _fy;
  final List<_BudgetLineEdit> _lines = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fy = now.month >= 4 ? now.year : now.year - 1;
    _load();
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref.read(apiClientProvider).get('/api/v1/budgets/$_fy');
      final body = response.data as Map<String, dynamic>;
      final data = (body['data'] as List?) ?? const [];
      final accounts = await ref.read(accountsProvider.future);
      final byCode = {for (final a in accounts) a.code: a};
      if (!mounted) return;
      setState(() {
        for (final l in _lines) {
          l.dispose();
        }
        _lines
          ..clear()
          ..addAll(data.map((raw) {
            final m = Map<String, dynamic>.from(raw as Map);
            return _BudgetLineEdit(
              account: byCode[m['accountCode']?.toString()],
              amount: (m['annualAmount'] ?? '').toString(),
            );
          }));
        if (_lines.isEmpty) _lines.add(_BudgetLineEdit());
      });
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final payload = _lines
          .where((l) => l.account != null)
          .map((l) => {
                'accountCode': l.account!.code,
                'annualAmount': double.tryParse(l.amountCtl.text.trim()) ?? 0,
              })
          .toList();
      await ref
          .read(apiClientProvider)
          .put('/api/v1/budgets/$_fy', data: payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Budget saved.')));
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: ${_msg(e)}')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _msg(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) return data['message'].toString();
    }
    return e.toString().replaceAll('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: _loading
          ? const KLoading(message: 'Loading budget...')
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                KCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Annual budget per account', style: KTypography.h3),
                      KSpacing.vGapXs,
                      Text(
                        'Set a yearly amount per revenue/expense account. The '
                        'Budget vs Actual report pro-rates it over any period.',
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary),
                      ),
                      KSpacing.vGapSm,
                      DropdownButtonFormField<int>(
                        value: _fy,
                        decoration: const InputDecoration(
                          labelText: 'Fiscal year',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: List.generate(4, (i) {
                          final y = DateTime.now().year + 1 - i;
                          return DropdownMenuItem(
                              value: y, child: Text('FY $y-${(y + 1) % 100}'));
                        }),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _fy = v);
                          _load();
                        },
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  KSpacing.vGapMd,
                  Text(_error!,
                      style:
                          KTypography.bodySmall.copyWith(color: KColors.error)),
                ],
                KSpacing.vGapMd,
                ..._lines.asMap().entries.map((entry) {
                  final i = entry.key;
                  final line = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: KSpacing.sm),
                    child: KCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: accountsAsync.when(
                              data: (accounts) =>
                                  DropdownButtonFormField<AccountDto>(
                                value: line.account,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Account',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: accounts
                                    .map((a) => DropdownMenuItem(
                                          value: a,
                                          child: Text('${a.code} ${a.name}',
                                              overflow: TextOverflow.ellipsis),
                                        ))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => line.account = v),
                              ),
                              loading: () => const LinearProgressIndicator(),
                              error: (e, _) => Text('$e'),
                            ),
                          ),
                          KSpacing.hGapSm,
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: line.amountCtl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Annual ₹',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() {
                              _lines.removeAt(i).dispose();
                            }),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                OutlinedButton.icon(
                  onPressed: () =>
                      setState(() => _lines.add(_BudgetLineEdit())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add account'),
                ),
                KSpacing.vGapMd,
                SizedBox(
                  width: double.infinity,
                  child: KButton(
                    label: 'Save budget',
                    icon: Icons.save_outlined,
                    isLoading: _saving,
                    onPressed: _saving ? null : _save,
                  ),
                ),
              ],
            ),
    );
  }
}
