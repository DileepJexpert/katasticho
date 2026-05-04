import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/utils/form_error_handler.dart';
import '../../../core/widgets/widgets.dart';
import '../../contacts/data/contact_repository.dart';
import '../../tax_groups/data/tax_group_repository.dart';
import '../../tax_groups/presentation/widgets/tax_group_picker.dart';
import '../data/expense_repository.dart';
import 'expense_list_screen.dart' show kExpenseCategories;

/// Lightweight provider to pull the chart of accounts once per screen open.
final _accountsFutureProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get(ApiConfig.chartOfAccounts);
  final data = (resp.data as Map<String, dynamic>)['data'];
  if (data is List) {
    return data.cast<Map<String, dynamic>>();
  }
  return <Map<String, dynamic>>[];
});

class ExpenseCreateScreen extends ConsumerStatefulWidget {
  const ExpenseCreateScreen({super.key});

  @override
  ConsumerState<ExpenseCreateScreen> createState() =>
      _ExpenseCreateScreenState();
}

class _ExpenseCreateScreenState extends ConsumerState<ExpenseCreateScreen>
    with FormErrorHandler {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  DateTime _expenseDate = DateTime.now();
  String? _category;
  String _paymentMode = 'CASH';
  String? _expenseAccountId;
  String? _paidThroughId;
  double _gstRate = 0;
  String? _taxGroupId;
  String? _vendorContactId;
  String? _vendorContactName;
  bool _billable = false;
  bool _submitting = false;

  static const _paymentModes = [
    ('CASH', 'Cash', Icons.payments_outlined),
    ('BANK', 'Bank Transfer', Icons.account_balance_outlined),
    ('UPI', 'UPI', Icons.qr_code_2_outlined),
    ('CREDIT_CARD', 'Credit Card', Icons.credit_card_outlined),
  ];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(_accountsFutureProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Record Expense')),
      body: accountsAsync.when(
        loading: () => const KLoading(),
        error: (_, __) => KErrorView(
          message: 'Failed to load accounts',
          onRetry: () => ref.invalidate(_accountsFutureProvider),
        ),
        data: (accounts) {
          final expenseAccounts = accounts
              .where((a) => (a['type'] as String?) == 'EXPENSE')
              .toList();
          final assetAccounts = accounts
              .where((a) =>
                  (a['subType'] as String?) == 'CURRENT_ASSET' ||
                  (a['subType'] as String?) == 'BANK' ||
                  (a['name'] as String? ?? '').toLowerCase().contains('cash') ||
                  (a['name'] as String? ?? '').toLowerCase().contains('bank'))
              .toList();

          return Form(
            key: _formKey,
            child: ListView(
              padding: KSpacing.pagePadding,
              children: [
                // Amount + Date side-by-side
                KCompactRow(children: [
                  KTextField.amount(
                    label: 'Amount',
                    isRequired: true,
                    controller: _amountCtrl,
                    serverError: serverErrors['amount'],
                    validator: (v) => fieldError('amount', () {
                      if (v == null || v.isEmpty) return 'Required';
                      final n = double.tryParse(v);
                      if (n == null || n <= 0) return 'Enter a positive amount';
                      return null;
                    }()),
                  ),
                  KDatePicker(
                    label: 'Expense date',
                    value: _expenseDate,
                    isRequired: true,
                    onChanged: (d) => setState(() => _expenseDate = d),
                  ),
                ]),
                KSpacing.vGapSm,

                // Category + Expense account side-by-side
                KCompactRow(children: [
                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: kExpenseCategories
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _category = v),
                  ),
                  DropdownButtonFormField<String>(
                    value: _expenseAccountId,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Expense account *'),
                    items: expenseAccounts.map((a) {
                      return DropdownMenuItem<String>(
                        value: a['id']?.toString(),
                        child: Text(
                          '${a['code']} — ${a['name']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    validator: (v) => v == null ? 'Required' : null,
                    onChanged: (v) => setState(() => _expenseAccountId = v),
                  ),
                ]),
                KSpacing.vGapSm,

                // Tax + Paid through side-by-side
                KCompactRow(children: [
                  TaxGroupPicker(
                    value: _taxGroupId,
                    label: 'Tax (GST)',
                    onChanged: (group) => setState(() {
                      _taxGroupId = group?.id;
                      _gstRate = group?.totalRate ?? 0;
                    }),
                  ),
                  DropdownButtonFormField<String>(
                    value: _paidThroughId,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Paid through *'),
                    items: assetAccounts.map((a) {
                      return DropdownMenuItem<String>(
                        value: a['id']?.toString(),
                        child: Text(
                          '${a['code']} — ${a['name']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    validator: (v) => v == null ? 'Required' : null,
                    onChanged: (v) => setState(() => _paidThroughId = v),
                  ),
                ]),
                KSpacing.vGapSm,

                // Payment mode chips
                Text('Payment mode *', style: KTypography.labelLarge),
                KSpacing.vGapXs,
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _paymentModes.map((m) {
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(m.$3, size: 14),
                          KSpacing.hGapXs,
                          Text(m.$2),
                        ],
                      ),
                      selected: _paymentMode == m.$1,
                      onSelected: (_) =>
                          setState(() => _paymentMode = m.$1),
                    );
                  }).toList(),
                ),
                KSpacing.vGapSm,

                // Vendor picker
                InkWell(
                  onTap: _pickVendor,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Vendor (optional)',
                      suffixIcon: _vendorContactId != null
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() {
                                _vendorContactId = null;
                                _vendorContactName = null;
                              }),
                            )
                          : const Icon(Icons.person_search_outlined),
                    ),
                    child: Text(
                      _vendorContactName ?? 'Select vendor',
                      style: KTypography.bodyMedium,
                    ),
                  ),
                ),
                KSpacing.vGapSm,

                // Notes
                KTextField(
                  label: 'Notes',
                  controller: _descriptionCtrl,
                  maxLines: 2,
                ),
                KSpacing.vGapSm,

                SwitchListTile(
                  title: const Text('Billable to customer'),
                  subtitle: const Text(
                      'Mark so it can be added to a customer invoice'),
                  value: _billable,
                  onChanged: (v) => setState(() => _billable = v),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                KSpacing.vGapMd,

                KButton(
                  label: 'Record Expense',
                  fullWidth: true,
                  isLoading: _submitting,
                  onPressed: _submit,
                ),
                KSpacing.vGapSm,
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickVendor() async {
    final repo = ref.read(contactRepositoryProvider);
    Map<String, dynamic>? result;
    try {
      result = await repo.listContacts(type: 'VENDOR');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load vendors')));
      return;
    }

    if (!mounted) return;
    final content = result['data'];
    final contacts = content is List
        ? content
        : (content is Map ? (content['content'] as List?) ?? [] : []);

    // Keep only VENDOR or BOTH
    final filtered = contacts.where((c) {
      final t = (c as Map)['contactType'] as String? ?? '';
      return t == 'VENDOR' || t == 'BOTH';
    }).toList();

    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No vendors found. Add a vendor contact first.'),
              )
            else
              ...filtered.map((c) {
                final m = c as Map<String, dynamic>;
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: Text(m['displayName'] as String? ?? 'Vendor'),
                  onTap: () => Navigator.pop(ctx, m),
                );
              }),
            KSpacing.vGapSm,
          ],
        ),
      ),
    );

    if (picked != null) {
      setState(() {
        _vendorContactId = picked['id']?.toString();
        _vendorContactName = picked['displayName'] as String?;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final payload = {
        'expenseDate':
            '${_expenseDate.year.toString().padLeft(4, '0')}-${_expenseDate.month.toString().padLeft(2, '0')}-${_expenseDate.day.toString().padLeft(2, '0')}',
        'accountId': _expenseAccountId,
        'category': _category,
        'description': _descriptionCtrl.text.trim(),
        'amount': double.parse(_amountCtrl.text),
        'gstRate': _gstRate,
        if (_taxGroupId != null) 'taxGroupId': _taxGroupId,
        'currency': 'INR',
        'contactId': _vendorContactId,
        'paymentMode': _paymentMode,
        'paidThroughId': _paidThroughId,
        'billable': _billable,
      };

      await ref.read(expenseRepositoryProvider).createExpense(payload);
      if (!mounted) return;

      ref.invalidate(expenseListProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense recorded')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is DioException
            ? ApiErrorParser.message(e)
            : 'Failed to save: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
