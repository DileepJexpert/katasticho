import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/utils/form_error_handler.dart';
import '../../../core/widgets/widgets.dart';

class EmployeeFormScreen extends ConsumerStatefulWidget {
  final String? employeeId;

  const EmployeeFormScreen({super.key, this.employeeId});

  @override
  ConsumerState<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends ConsumerState<EmployeeFormScreen>
    with FormErrorHandler {
  final _formKey = GlobalKey<FormState>();

  bool get _isEdit => widget.employeeId != null;
  bool _loading = false;
  bool _initialLoading = false;

  // Basic Info
  final _employeeCodeCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  DateTime? _dateOfJoining;
  String _paymentMode = 'BANK_TRANSFER';

  // Bank Details
  final _bankAccountNameCtrl = TextEditingController();
  final _bankAccountNumberCtrl = TextEditingController();
  final _bankIfscCtrl = TextEditingController();

  // Statutory IDs
  final _panCtrl = TextEditingController();
  final _aadhaarLast4Ctrl = TextEditingController();
  final _uanCtrl = TextEditingController();
  final _esiNumberCtrl = TextEditingController();

  // Statutory Applicability
  bool _pfApplicable = true;
  bool _esiApplicable = false;
  bool _ptApplicable = false;
  bool _lwfApplicable = false;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _initialLoading = true;
      _loadEmployee();
    }
  }

  @override
  void dispose() {
    _employeeCodeCtrl.dispose();
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _designationCtrl.dispose();
    _departmentCtrl.dispose();
    _bankAccountNameCtrl.dispose();
    _bankAccountNumberCtrl.dispose();
    _bankIfscCtrl.dispose();
    _panCtrl.dispose();
    _aadhaarLast4Ctrl.dispose();
    _uanCtrl.dispose();
    _esiNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEmployee() async {
    try {
      final api = ref.read(apiClientProvider);
      final response =
          await api.get(ApiConfig.payrollEmployee(widget.employeeId!));
      final data = (response.data['data'] ?? response.data)
          as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _employeeCodeCtrl.text = data['employeeCode'] as String? ?? '';
        _fullNameCtrl.text = data['fullName'] as String? ?? '';
        _phoneCtrl.text = data['phone'] as String? ?? '';
        _emailCtrl.text = data['email'] as String? ?? '';
        _designationCtrl.text = data['designation'] as String? ?? '';
        _departmentCtrl.text = data['department'] as String? ?? '';
        _paymentMode = data['paymentMode'] as String? ?? 'BANK_TRANSFER';

        final doj = data['dateOfJoining'] as String?;
        if (doj != null && doj.isNotEmpty) {
          _dateOfJoining = DateTime.tryParse(doj);
        }

        _bankAccountNameCtrl.text =
            data['bankAccountName'] as String? ?? '';
        _bankAccountNumberCtrl.text =
            data['bankAccountNumber'] as String? ?? '';
        _bankIfscCtrl.text = data['bankIfsc'] as String? ?? '';

        _panCtrl.text = data['pan'] as String? ?? '';
        _aadhaarLast4Ctrl.text =
            data['aadhaarLast4'] as String? ?? '';
        _uanCtrl.text = data['uan'] as String? ?? '';
        _esiNumberCtrl.text = data['esiNumber'] as String? ?? '';

        _pfApplicable = data['pfApplicable'] as bool? ?? true;
        _esiApplicable = data['esiApplicable'] as bool? ?? false;
        _ptApplicable = data['ptApplicable'] as bool? ?? false;
        _lwfApplicable = data['lwfApplicable'] as bool? ?? false;

        _initialLoading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final body = e.response?.data;
      final msg = (body is Map ? body['message'] as String? : null) ??
          'Failed to load employee';
      setState(() => _initialLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _initialLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load employee')),
      );
    }
  }

  Future<void> _pickDateOfJoining() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfJoining ?? now,
      firstDate: DateTime(2000),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _dateOfJoining = picked);
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Employee' : 'Add Employee'),
        actions: [
          TextButton(
            onPressed: (_loading || _initialLoading) ? null : _save,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: _initialLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: KSpacing.pagePadding,
                children: [
                  _buildBasicInfoSection(),
                  _buildBankDetailsSection(),
                  _buildStatutoryIdsSection(),
                  _buildStatutoryApplicabilitySection(),
                  KSpacing.vGapMd,
                ],
              ),
            ),
    );
  }

  // ── Basic Info ──

  Widget _buildBasicInfoSection() {
    return KCollapsibleSection(
      title: 'Basic Info',
      icon: Icons.person_outline,
      initiallyExpanded: true,
      children: [
        KTextField(
          label: 'Employee Code',
          controller: _employeeCodeCtrl,
          prefixIcon: Icons.badge_outlined,
          hint: 'Auto-generated if left empty',
          serverError: serverErrors['employeeCode'],
        ),
        KSpacing.vGapSm,
        KTextField(
          label: 'Full Name',
          isRequired: true,
          controller: _fullNameCtrl,
          prefixIcon: Icons.person_outline,
          serverError: serverErrors['fullName'],
          validator: (v) => fieldError(
            'fullName',
            (v == null || v.trim().isEmpty) ? 'Full name is required' : null,
          ),
        ),
        KSpacing.vGapSm,
        KCompactRow(children: [
          KTextField(
            label: 'Phone',
            controller: _phoneCtrl,
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            serverError: serverErrors['phone'],
          ),
          KTextField(
            label: 'Email',
            controller: _emailCtrl,
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            serverError: serverErrors['email'],
            validator: (v) => fieldError(
              'email',
              (v != null && v.isNotEmpty && !v.contains('@'))
                  ? 'Enter a valid email'
                  : null,
            ),
          ),
        ]),
        KSpacing.vGapSm,
        KCompactRow(children: [
          KTextField(
            label: 'Designation',
            controller: _designationCtrl,
            prefixIcon: Icons.work_outline,
            serverError: serverErrors['designation'],
          ),
          KTextField(
            label: 'Department',
            controller: _departmentCtrl,
            prefixIcon: Icons.business_outlined,
            serverError: serverErrors['department'],
          ),
        ]),
        KSpacing.vGapSm,
        KCompactRow(children: [
          GestureDetector(
            onTap: _pickDateOfJoining,
            child: AbsorbPointer(
              child: KTextField(
                label: 'Date of Joining',
                prefixIcon: Icons.calendar_today_outlined,
                controller: TextEditingController(
                  text: _dateOfJoining != null
                      ? _formatDate(_dateOfJoining!)
                      : '',
                ),
                hint: 'YYYY-MM-DD',
                readOnly: true,
                serverError: serverErrors['dateOfJoining'],
              ),
            ),
          ),
          DropdownButtonFormField<String>(
            initialValue: _paymentMode,
            decoration: const InputDecoration(
              labelText: 'Payment Mode',
              prefixIcon: Icon(Icons.payment_outlined),
            ),
            items: const [
              DropdownMenuItem(
                value: 'BANK_TRANSFER',
                child: Text('Bank Transfer'),
              ),
              DropdownMenuItem(
                value: 'CASH',
                child: Text('Cash'),
              ),
              DropdownMenuItem(
                value: 'CHEQUE',
                child: Text('Cheque'),
              ),
            ],
            onChanged: (v) =>
                setState(() => _paymentMode = v ?? 'BANK_TRANSFER'),
          ),
        ]),
      ],
    );
  }

  // ── Bank Details ──

  Widget _buildBankDetailsSection() {
    return KCollapsibleSection(
      title: 'Bank Details',
      icon: Icons.account_balance_outlined,
      children: [
        KTextField(
          label: 'Bank Account Name',
          controller: _bankAccountNameCtrl,
          prefixIcon: Icons.account_box_outlined,
          serverError: serverErrors['bankAccountName'],
        ),
        KSpacing.vGapSm,
        KCompactRow(children: [
          KTextField(
            label: 'Bank Account Number',
            controller: _bankAccountNumberCtrl,
            prefixIcon: Icons.numbers_outlined,
            keyboardType: TextInputType.number,
            serverError: serverErrors['bankAccountNumber'],
          ),
          KTextField(
            label: 'Bank IFSC',
            controller: _bankIfscCtrl,
            prefixIcon: Icons.code_outlined,
            maxLength: 11,
            serverError: serverErrors['bankIfsc'],
            validator: (v) => fieldError(
              'bankIfsc',
              (v != null && v.isNotEmpty && v.length != 11)
                  ? 'IFSC must be 11 characters'
                  : null,
            ),
          ),
        ]),
      ],
    );
  }

  // ── Statutory IDs ──

  Widget _buildStatutoryIdsSection() {
    return KCollapsibleSection(
      title: 'Statutory IDs',
      icon: Icons.verified_user_outlined,
      children: [
        KCompactRow(children: [
          KTextField(
            label: 'PAN',
            controller: _panCtrl,
            prefixIcon: Icons.credit_card_outlined,
            maxLength: 10,
            serverError: serverErrors['pan'],
            validator: (v) => fieldError(
              'pan',
              (v != null && v.isNotEmpty && v.length != 10)
                  ? 'PAN must be 10 characters'
                  : null,
            ),
          ),
          KTextField(
            label: 'Aadhaar Last 4 Digits',
            controller: _aadhaarLast4Ctrl,
            prefixIcon: Icons.fingerprint_outlined,
            maxLength: 4,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            serverError: serverErrors['aadhaarLast4'],
            validator: (v) => fieldError(
              'aadhaarLast4',
              (v != null && v.isNotEmpty && v.length != 4)
                  ? 'Enter last 4 digits only'
                  : null,
            ),
          ),
        ]),
        KSpacing.vGapSm,
        KCompactRow(children: [
          KTextField(
            label: 'UAN (PF Number)',
            controller: _uanCtrl,
            prefixIcon: Icons.shield_outlined,
            serverError: serverErrors['uan'],
          ),
          KTextField(
            label: 'ESI Number',
            controller: _esiNumberCtrl,
            prefixIcon: Icons.local_hospital_outlined,
            serverError: serverErrors['esiNumber'],
          ),
        ]),
      ],
    );
  }

  // ── Statutory Applicability ──

  Widget _buildStatutoryApplicabilitySection() {
    return KCollapsibleSection(
      title: 'Statutory Applicability',
      icon: Icons.gavel_outlined,
      children: [
        SwitchListTile(
          title: const Text('PF Applicable'),
          subtitle: const Text('Provident Fund deduction'),
          value: _pfApplicable,
          onChanged: (v) => setState(() => _pfApplicable = v),
          contentPadding: EdgeInsets.zero,
        ),
        SwitchListTile(
          title: const Text('ESI Applicable'),
          subtitle: const Text('Employee State Insurance'),
          value: _esiApplicable,
          onChanged: (v) => setState(() => _esiApplicable = v),
          contentPadding: EdgeInsets.zero,
        ),
        SwitchListTile(
          title: const Text('PT Applicable'),
          subtitle: const Text('Professional Tax'),
          value: _ptApplicable,
          onChanged: (v) => setState(() => _ptApplicable = v),
          contentPadding: EdgeInsets.zero,
        ),
        SwitchListTile(
          title: const Text('LWF Applicable'),
          subtitle: const Text('Labour Welfare Fund'),
          value: _lwfApplicable,
          onChanged: (v) => setState(() => _lwfApplicable = v),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  // ── Save ──

  Future<void> _save() async {
    clearServerErrors();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final data = <String, dynamic>{
      'fullName': _fullNameCtrl.text.trim(),
      'paymentMode': _paymentMode,
      'pfApplicable': _pfApplicable,
      'esiApplicable': _esiApplicable,
      'ptApplicable': _ptApplicable,
      'lwfApplicable': _lwfApplicable,
      if (_employeeCodeCtrl.text.trim().isNotEmpty)
        'employeeCode': _employeeCodeCtrl.text.trim(),
      if (_phoneCtrl.text.trim().isNotEmpty)
        'phone': _phoneCtrl.text.trim(),
      if (_emailCtrl.text.trim().isNotEmpty)
        'email': _emailCtrl.text.trim(),
      if (_designationCtrl.text.trim().isNotEmpty)
        'designation': _designationCtrl.text.trim(),
      if (_departmentCtrl.text.trim().isNotEmpty)
        'department': _departmentCtrl.text.trim(),
      if (_dateOfJoining != null)
        'dateOfJoining': _formatDate(_dateOfJoining!),
      if (_bankAccountNameCtrl.text.trim().isNotEmpty)
        'bankAccountName': _bankAccountNameCtrl.text.trim(),
      if (_bankAccountNumberCtrl.text.trim().isNotEmpty)
        'bankAccountNumber': _bankAccountNumberCtrl.text.trim(),
      if (_bankIfscCtrl.text.trim().isNotEmpty)
        'bankIfsc': _bankIfscCtrl.text.trim(),
      if (_panCtrl.text.trim().isNotEmpty)
        'pan': _panCtrl.text.trim(),
      if (_aadhaarLast4Ctrl.text.trim().isNotEmpty)
        'aadhaarLast4': _aadhaarLast4Ctrl.text.trim(),
      if (_uanCtrl.text.trim().isNotEmpty)
        'uan': _uanCtrl.text.trim(),
      if (_esiNumberCtrl.text.trim().isNotEmpty)
        'esiNumber': _esiNumberCtrl.text.trim(),
    };

    try {
      final api = ref.read(apiClientProvider);
      if (_isEdit) {
        await api.put(
          ApiConfig.payrollEmployee(widget.employeeId!),
          data: data,
        );
      } else {
        await api.post(ApiConfig.payrollEmployees, data: data);
      }
      if (!mounted) return;
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      handleSaveError(e, _formKey);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
