import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/reimbursement_repository.dart';

class EmployeeReimbursementScreen extends ConsumerStatefulWidget {
  const EmployeeReimbursementScreen({super.key});

  @override
  ConsumerState<EmployeeReimbursementScreen> createState() => _EmployeeReimbursementScreenState();
}

class _EmployeeReimbursementScreenState extends ConsumerState<EmployeeReimbursementScreen> {
  List<Map<String, dynamic>> _claims = [];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _accounts = [];
  String _filter = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final repo = ref.read(reimbursementRepositoryProvider);
      final api = ref.read(apiClientProvider);
      final claimsFuture = repo.list(status: _filter.isEmpty ? null : _filter);
      final employeesFuture = api.get<Map<String, dynamic>>(
        ApiConfig.payrollEmployees,
        queryParameters: {'page': 0, 'size': 200},
      );
      final accountsFuture = api.get<Map<String, dynamic>>(ApiConfig.chartOfAccounts);

      // The futures start together, while each response remains strongly typed.
      final claimsData = await claimsFuture;
      final employeeResponse = await employeesFuture;
      final accountResponse = await accountsFuture;
      final employeeData = _responseMap(employeeResponse.data);
      final accountData = _responseMap(accountResponse.data);
      setState(() {
        _claims = _listFromResponse(claimsData);
        _employees = _listFromResponse(employeeData);
        _accounts = _listFromResponse(accountData);
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; _error = 'Unable to load reimbursement data'; });
    }
  }

  Map<String, dynamic> _responseMap(dynamic value) {
    if (value is Map) return value.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _listFromResponse(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is List) return data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    if (data is Map && data['content'] is List) {
      return (data['content'] as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    return [];
  }

  List<Map<String, dynamic>> get _expenseAccounts => _accounts.where((a) => a['type'] == 'EXPENSE').toList();
  List<Map<String, dynamic>> get _paidThroughAccounts => _accounts.where((a) {
    final subType = a['subType']?.toString() ?? '';
    final name = (a['name']?.toString() ?? '').toLowerCase();
    return subType == 'CURRENT_ASSET' || subType == 'BANK' || name.contains('cash') || name.contains('bank');
  }).toList();

  Future<void> _openSubmitSheet() async {
    if (_accounts.isEmpty) return;
    final result = await showModalBottomSheet<PlatformFile?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SubmitReimbursementSheet(
        employees: _employees,
        expenseAccounts: _expenseAccounts,
        onSubmit: (payload, receipt) async {
          final response = await ref.read(reimbursementRepositoryProvider).submit(payload);
          final data = response['data'];
          final id = data is Map ? data['id']?.toString() : null;
          if (id != null && receipt != null) {
            await ref.read(reimbursementRepositoryProvider).uploadReceipt(id, receipt);
          }
        },
      ),
    );
    if (result != null || mounted) await _load();
  }

  Future<void> _openAdvanceSheet() async {
    if (_paidThroughAccounts.isEmpty) {
      _showError('Create a cash or bank account first');
      return;
    }
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CreateAdvanceSheet(
        employees: _employees,
        paidThroughAccounts: _paidThroughAccounts,
        onCreate: (payload) async {
          await ref.read(reimbursementRepositoryProvider).createAdvance(payload);
        },
      ),
    );
    if (created == true && mounted) await _load();
  }

  Future<void> _approve(String id) async {
    try { await ref.read(reimbursementRepositoryProvider).approve(id); await _load(); }
    catch (e) { _showError(e); }
  }

  Future<void> _reject(String id) async {
    final reason = await _askReason();
    if (reason == null || reason.trim().isEmpty) return;
    try { await ref.read(reimbursementRepositoryProvider).reject(id, reason.trim()); await _load(); }
    catch (e) { _showError(e); }
  }

  Future<void> _pay(String id) async {
    if (_paidThroughAccounts.isEmpty) { _showError('Create a cash or bank account first'); return; }
    final selected = await showDialog<String>(context: context, builder: (_) => _AccountDialog(accounts: _paidThroughAccounts, title: 'Pay from')); 
    if (selected == null) return;
    try { await ref.read(reimbursementRepositoryProvider).pay(id, selected); await _load(); }
    catch (e) { _showError(e); }
  }

  Future<String?> _askReason() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject reimbursement'),
        content: KTextField(
            label: 'Reason', controller: controller, maxLines: 3, isRequired: true),
        actions: [
          KButton.outlined(
            label: 'Cancel',
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx),
          ),
          KSpacing.hGapSm,
          KButton.danger(
            label: 'Reject',
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx, controller.text),
          ),
        ],
      ),
    );
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        KListPageHeader(title: 'Employee Reimbursements', searchHint: 'Claims, employees, status...', actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_outlined), tooltip: 'Refresh'),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(KSpacing.md, KSpacing.sm, KSpacing.md, KSpacing.sm),
          child: Row(children: [
            SegmentedButton<String>(segments: const [
              ButtonSegment(value: '', label: Text('All')),
              ButtonSegment(value: 'SUBMITTED', label: Text('Submitted')),
              ButtonSegment(value: 'APPROVED', label: Text('Approved')),
              ButtonSegment(value: 'PAID', label: Text('Paid')),
            ], selected: {_filter}, onSelectionChanged: (v) { setState(() => _filter = v.first); _load(); }),
            const Spacer(),
            KButton.outlined(label: 'New Advance', icon: Icons.account_balance_wallet_outlined, onPressed: _openAdvanceSheet),
            const SizedBox(width: KSpacing.sm),
            KButton.primary(label: 'New Claim', icon: Icons.add, onPressed: _openSubmitSheet),
          ]),
        ),
        Expanded(child: _loading ? const KShimmerList() : _error != null ? KErrorView(message: _error!, onRetry: _load) : _claims.isEmpty
            ? KEmptyState(icon: Icons.receipt_long_outlined, title: 'No reimbursement claims', subtitle: 'Submit employee travel, meal, fuel, or other business expenses with a receipt.', actionLabel: 'New Claim', onAction: _openSubmitSheet)
            : ListView.separated(padding: const EdgeInsets.all(KSpacing.md), itemCount: _claims.length, separatorBuilder: (_, __) => KSpacing.vGapSm, itemBuilder: (_, i) => _claimCard(_claims[i]))),
      ]),
    );
  }

  Widget _claimCard(Map<String, dynamic> claim) {
    final id = claim['id']?.toString() ?? '';
    final status = claim['status']?.toString() ?? 'SUBMITTED';
    final amount = (claim['amount'] as num?)?.toDouble() ?? 0;
    final payable = (claim['payableAmount'] as num?)?.toDouble() ?? amount;
    return KCard(
      title: claim['employeeName']?.toString() ?? 'Employee',
      subtitle: '${claim['expenseDate'] ?? ''} · ${claim['category'] ?? 'Business expense'}',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          KStatusChip(status: status),
          const SizedBox(width: 12),
          KMoney(amount, size: KMoneySize.small, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((claim['description']?.toString() ?? '').isNotEmpty)
            Text(claim['description']!.toString(), style: KTypography.bodyMedium),
          if ((claim['receiptUrl']?.toString() ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(Icons.attach_file, size: 14, color: KColors.primary),
                  const SizedBox(width: 4),
                  Text('Receipt attached', style: KTypography.bodySmall.copyWith(color: KColors.primary)),
                ],
              ),
            ),
          if (status == 'APPROVED' && payable > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Text('Payable after advance settlement: ', style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                  KMoney(payable, size: KMoneySize.small, style: TextStyle(fontWeight: FontWeight.w700, color: KColors.success)),
                ],
              ),
            ),
          if (status == 'SUBMITTED' || status == 'APPROVED')
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 8,
                children: [
                  if (status == 'SUBMITTED') ...[
                    KButton.primary(label: 'Approve', size: KButtonSize.small, onPressed: () => _approve(id)),
                    KButton.outlined(label: 'Reject', size: KButtonSize.small, onPressed: () => _reject(id)),
                  ],
                  if (status == 'APPROVED')
                    KButton.primary(label: 'Mark Paid', size: KButtonSize.small, onPressed: () => _pay(id)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SubmitReimbursementSheet extends StatefulWidget {
  final List<Map<String, dynamic>> employees;
  final List<Map<String, dynamic>> expenseAccounts;
  final Future<void> Function(Map<String, dynamic>, PlatformFile?) onSubmit;
  const _SubmitReimbursementSheet({required this.employees, required this.expenseAccounts, required this.onSubmit});
  @override State<_SubmitReimbursementSheet> createState() => _SubmitReimbursementSheetState();
}

class _SubmitReimbursementSheetState extends State<_SubmitReimbursementSheet> {
  final _amount = TextEditingController();
  final _description = TextEditingController();
  final _category = TextEditingController(text: 'Travel');
  String? _employeeId;
  String? _accountId;
  PlatformFile? _receipt;
  bool _saving = false;
  String _date() { final d = DateTime.now(); return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'; }
  @override void dispose() { _amount.dispose(); _description.dispose(); _category.dispose(); super.dispose(); }
  Future<void> _pickReceipt() async { final result = await FilePicker.platform.pickFiles(withData: true, type: FileType.image); if (result != null && result.files.isNotEmpty) setState(() => _receipt = result.files.first); }
  Future<void> _submit() async {
    final value = double.tryParse(_amount.text.trim());
    if (value == null || value <= 0 || _accountId == null || _description.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter amount, expense account, and description'))); return; }
    setState(() => _saving = true);
    try { await widget.onSubmit({'expenseDate': _date(), if (_employeeId != null) 'employeeId': _employeeId, 'accountId': _accountId, 'category': _category.text.trim(), 'description': _description.text.trim(), 'amount': value, 'receiptUrl': _receipt?.name}, _receipt); if (mounted) Navigator.pop(context, _receipt); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
    finally { if (mounted) setState(() => _saving = false); }
  }
  @override Widget build(BuildContext context) => Padding(padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.viewInsetsOf(context).bottom + 20), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('New Employee Reimbursement', style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 16),
    DropdownButtonFormField<String>(decoration: const InputDecoration(labelText: 'Employee / salesperson (optional)'), initialValue: _employeeId, isExpanded: true, items: widget.employees.map((e) => DropdownMenuItem(value: e['id']?.toString(), child: Text('${e['fullName'] ?? ''} ${e['employeeCode'] == null ? '' : '(${e['employeeCode']})'}'))).toList(), onChanged: (v) => setState(() => _employeeId = v)),
    const SizedBox(height: 10),
    DropdownButtonFormField<String>(decoration: const InputDecoration(labelText: 'Expense account *'), initialValue: _accountId, isExpanded: true, items: widget.expenseAccounts.map((a) => DropdownMenuItem(value: a['id']?.toString(), child: Text('${a['code']} — ${a['name']}'))).toList(), onChanged: (v) => setState(() => _accountId = v)),
    const SizedBox(height: 10),
    KTextField(label: 'Category', controller: _category), const SizedBox(height: 10),
    KTextField.amount(label: 'Amount', controller: _amount, isRequired: true), const SizedBox(height: 10),
    KTextField(label: 'Description', controller: _description, maxLines: 3, isRequired: true), const SizedBox(height: 12),
    OutlinedButton.icon(onPressed: _pickReceipt, icon: const Icon(Icons.attach_file), label: Text(_receipt == null ? 'Attach receipt' : _receipt!.name)), const SizedBox(height: 18),
    KButton.primary(label: _saving ? 'Submitting...' : 'Submit for approval', onPressed: _saving ? null : _submit, fullWidth: true),
  ])));
}

class _CreateAdvanceSheet extends StatefulWidget {
  final List<Map<String, dynamic>> employees;
  final List<Map<String, dynamic>> paidThroughAccounts;
  final Future<void> Function(Map<String, dynamic>) onCreate;

  const _CreateAdvanceSheet({
    required this.employees,
    required this.paidThroughAccounts,
    required this.onCreate,
  });

  @override
  State<_CreateAdvanceSheet> createState() => _CreateAdvanceSheetState();
}

class _CreateAdvanceSheetState extends State<_CreateAdvanceSheet> {
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  String? _employeeId;
  String? _paidThroughId;
  bool _saving = false;

  String _date() {
    final d = DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final amount = double.tryParse(_amount.text.trim());
    if (_employeeId == null || _paidThroughId == null || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select employee, payment account, and enter a valid amount')));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onCreate({
        'employeeId': _employeeId,
        'advanceDate': _date(),
        'amount': amount,
        'paidThroughId': _paidThroughId,
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('New Employee Advance', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Employee / salesperson *'),
              initialValue: _employeeId,
              isExpanded: true,
              items: widget.employees.map((e) => DropdownMenuItem(
                value: e['id']?.toString(),
                child: Text('${e['fullName'] ?? e['name'] ?? ''} ${e['employeeCode'] == null ? '' : '(${e['employeeCode']})'}'),
              )).toList(),
              onChanged: (v) => setState(() => _employeeId = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Pay from *'),
              initialValue: _paidThroughId,
              isExpanded: true,
              items: widget.paidThroughAccounts.map((a) => DropdownMenuItem(
                value: a['id']?.toString(),
                child: Text('${a['code']} - ${a['name']}'),
              )).toList(),
              onChanged: (v) => setState(() => _paidThroughId = v),
            ),
            const SizedBox(height: 10),
            KTextField.amount(label: 'Advance amount', controller: _amount, isRequired: true),
            const SizedBox(height: 10),
            KTextField(label: 'Notes', controller: _notes, maxLines: 3),
            const SizedBox(height: 18),
            KButton.primary(label: _saving ? 'Creating...' : 'Create advance', onPressed: _saving ? null : _create, fullWidth: true),
          ]),
        ),
      );
}
class _AccountDialog extends StatelessWidget { final List<Map<String, dynamic>> accounts; final String title; const _AccountDialog({required this.accounts, required this.title}); @override Widget build(BuildContext context) => AlertDialog(title: Text(title), content: SizedBox(width: 400, child: ListView(shrinkWrap: true, children: accounts.map((a) => ListTile(title: Text('${a['code']} — ${a['name']}'), onTap: () => Navigator.pop(context, a['id']?.toString()))).toList()))); }
