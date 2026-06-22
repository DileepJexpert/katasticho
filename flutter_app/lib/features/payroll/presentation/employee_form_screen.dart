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

  // V18 Personal info
  DateTime? _dateOfBirth;
  String? _gender;
  String? _maritalStatus;
  final _bloodGroupCtrl = TextEditingController();
  final _nationalityCtrl = TextEditingController();
  final _personalEmailCtrl = TextEditingController();

  // V18 Current address
  final _currAddr1Ctrl = TextEditingController();
  final _currAddr2Ctrl = TextEditingController();
  final _currCityCtrl = TextEditingController();
  final _currStateCtrl = TextEditingController();
  final _currPincodeCtrl = TextEditingController();

  // V18 Permanent address
  final _permAddr1Ctrl = TextEditingController();
  final _permAddr2Ctrl = TextEditingController();
  final _permCityCtrl = TextEditingController();
  final _permStateCtrl = TextEditingController();
  final _permPincodeCtrl = TextEditingController();

  // V18 Emergency contact
  final _emerNameCtrl = TextEditingController();
  final _emerRelCtrl = TextEditingController();
  final _emerPhoneCtrl = TextEditingController();

  // V18 Work info
  String? _employmentType;
  final _workLocationCtrl = TextEditingController();
  DateTime? _probationEndDate;
  DateTime? _confirmationDate;
  final _noticePeriodDaysCtrl = TextEditingController();

  // Link to the app login (powers attendance/leave → payroll LOP)
  String? _userId;
  List<Map<String, dynamic>> _orgUsers = [];

  @override
  void initState() {
    super.initState();
    _loadOrgUsers();
    if (_isEdit) {
      _initialLoading = true;
      _loadEmployee();
    }
  }

  Future<void> _loadOrgUsers() async {
    try {
      final res = await ref.read(apiClientProvider).get(ApiConfig.orgUsers);
      final list = (res.data['data'] as List?) ?? const [];
      if (!mounted) return;
      setState(() => _orgUsers =
          list.map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } catch (_) {/* user link is optional */}
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
    _bloodGroupCtrl.dispose();
    _nationalityCtrl.dispose();
    _personalEmailCtrl.dispose();
    _currAddr1Ctrl.dispose();
    _currAddr2Ctrl.dispose();
    _currCityCtrl.dispose();
    _currStateCtrl.dispose();
    _currPincodeCtrl.dispose();
    _permAddr1Ctrl.dispose();
    _permAddr2Ctrl.dispose();
    _permCityCtrl.dispose();
    _permStateCtrl.dispose();
    _permPincodeCtrl.dispose();
    _emerNameCtrl.dispose();
    _emerRelCtrl.dispose();
    _emerPhoneCtrl.dispose();
    _workLocationCtrl.dispose();
    _noticePeriodDaysCtrl.dispose();
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

        // V18 depth
        final dob = data['dateOfBirth'] as String?;
        if (dob != null && dob.isNotEmpty) _dateOfBirth = DateTime.tryParse(dob);
        _gender = data['gender'] as String?;
        _maritalStatus = data['maritalStatus'] as String?;
        _bloodGroupCtrl.text = data['bloodGroup'] as String? ?? '';
        _nationalityCtrl.text = data['nationality'] as String? ?? '';
        _personalEmailCtrl.text = data['personalEmail'] as String? ?? '';

        _currAddr1Ctrl.text = data['currentAddressLine1'] as String? ?? '';
        _currAddr2Ctrl.text = data['currentAddressLine2'] as String? ?? '';
        _currCityCtrl.text = data['currentCity'] as String? ?? '';
        _currStateCtrl.text = data['currentState'] as String? ?? '';
        _currPincodeCtrl.text = data['currentPincode'] as String? ?? '';

        _permAddr1Ctrl.text = data['permanentAddressLine1'] as String? ?? '';
        _permAddr2Ctrl.text = data['permanentAddressLine2'] as String? ?? '';
        _permCityCtrl.text = data['permanentCity'] as String? ?? '';
        _permStateCtrl.text = data['permanentState'] as String? ?? '';
        _permPincodeCtrl.text = data['permanentPincode'] as String? ?? '';

        _emerNameCtrl.text = data['emergencyContactName'] as String? ?? '';
        _emerRelCtrl.text =
            data['emergencyContactRelationship'] as String? ?? '';
        _emerPhoneCtrl.text =
            data['emergencyContactPhone'] as String? ?? '';

        _employmentType = data['employmentType'] as String?;
        _workLocationCtrl.text = data['workLocation'] as String? ?? '';
        final probEnd = data['probationEndDate'] as String?;
        if (probEnd != null && probEnd.isNotEmpty) {
          _probationEndDate = DateTime.tryParse(probEnd);
        }
        final confDate = data['confirmationDate'] as String?;
        if (confDate != null && confDate.isNotEmpty) {
          _confirmationDate = DateTime.tryParse(confDate);
        }
        final notice = data['noticePeriodDays'];
        if (notice != null) {
          _noticePeriodDaysCtrl.text = notice.toString();
        }

        _userId = data['userId'] as String?;

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
                  _buildWorkInfoSection(),
                  _buildPersonalInfoSection(),
                  _buildAddressSection(),
                  _buildEmergencyContactSection(),
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
          KSpacing.vGapSm,
          DropdownButtonFormField<String?>(
            initialValue: _userId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'App login (for attendance / leave → payroll LOP)',
              prefixIcon: Icon(Icons.link_outlined),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Not linked'),
              ),
              ..._orgUsers.map((u) {
                final id = (u['userId'] ?? u['id'])?.toString();
                final name = (u['fullName'] ?? u['email'] ?? id)?.toString() ?? '';
                return DropdownMenuItem<String?>(
                  value: id,
                  child: Text(name, overflow: TextOverflow.ellipsis),
                );
              }),
            ],
            onChanged: (v) => setState(() => _userId = v),
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

  // ── V18: Work Info ──

  Widget _buildWorkInfoSection() {
    return KCollapsibleSection(
      title: 'Work Info',
      icon: Icons.work_history_outlined,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _employmentType,
          decoration: const InputDecoration(
            labelText: 'Employment type',
            prefixIcon: Icon(Icons.work_outline),
          ),
          items: const [
            DropdownMenuItem(value: 'FULL_TIME', child: Text('Full-time')),
            DropdownMenuItem(value: 'PART_TIME', child: Text('Part-time')),
            DropdownMenuItem(value: 'CONTRACT', child: Text('Contract')),
            DropdownMenuItem(value: 'INTERN', child: Text('Intern')),
            DropdownMenuItem(value: 'CONSULTANT', child: Text('Consultant')),
          ],
          onChanged: (v) => setState(() => _employmentType = v),
        ),
        KSpacing.vGapSm,
        KTextField(
          label: 'Work location',
          controller: _workLocationCtrl,
          prefixIcon: Icons.location_city_outlined,
        ),
        KSpacing.vGapSm,
        KCompactRow(children: [
          _datePickerTile(
            label: 'Probation end',
            value: _probationEndDate,
            icon: Icons.timer_outlined,
            onPick: (d) => setState(() => _probationEndDate = d),
          ),
          _datePickerTile(
            label: 'Confirmation date',
            value: _confirmationDate,
            icon: Icons.verified_outlined,
            onPick: (d) => setState(() => _confirmationDate = d),
          ),
        ]),
        KSpacing.vGapSm,
        KTextField(
          label: 'Notice period (days)',
          controller: _noticePeriodDaysCtrl,
          prefixIcon: Icons.exit_to_app_outlined,
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  // ── V18: Personal Info ──

  Widget _buildPersonalInfoSection() {
    return KCollapsibleSection(
      title: 'Personal Info',
      icon: Icons.badge_outlined,
      children: [
        _datePickerTile(
          label: 'Date of birth',
          value: _dateOfBirth,
          icon: Icons.cake_outlined,
          onPick: (d) => setState(() => _dateOfBirth = d),
        ),
        KSpacing.vGapSm,
        KCompactRow(children: [
          DropdownButtonFormField<String>(
            initialValue: _gender,
            decoration: const InputDecoration(
              labelText: 'Gender',
              prefixIcon: Icon(Icons.person_outline),
            ),
            items: const [
              DropdownMenuItem(value: 'MALE', child: Text('Male')),
              DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
              DropdownMenuItem(value: 'OTHER', child: Text('Other')),
              DropdownMenuItem(
                value: 'PREFER_NOT_TO_SAY',
                child: Text('Prefer not to say'),
              ),
            ],
            onChanged: (v) => setState(() => _gender = v),
          ),
          DropdownButtonFormField<String>(
            initialValue: _maritalStatus,
            decoration: const InputDecoration(
              labelText: 'Marital status',
              prefixIcon: Icon(Icons.favorite_border),
            ),
            items: const [
              DropdownMenuItem(value: 'SINGLE', child: Text('Single')),
              DropdownMenuItem(value: 'MARRIED', child: Text('Married')),
              DropdownMenuItem(value: 'DIVORCED', child: Text('Divorced')),
              DropdownMenuItem(value: 'WIDOWED', child: Text('Widowed')),
            ],
            onChanged: (v) => setState(() => _maritalStatus = v),
          ),
        ]),
        KSpacing.vGapSm,
        KCompactRow(children: [
          KTextField(
            label: 'Blood group',
            controller: _bloodGroupCtrl,
            prefixIcon: Icons.bloodtype_outlined,
          ),
          KTextField(
            label: 'Nationality',
            controller: _nationalityCtrl,
            prefixIcon: Icons.flag_outlined,
          ),
        ]),
        KSpacing.vGapSm,
        KTextField(
          label: 'Personal email',
          controller: _personalEmailCtrl,
          prefixIcon: Icons.alternate_email,
          keyboardType: TextInputType.emailAddress,
        ),
      ],
    );
  }

  // ── V18: Addresses ──

  Widget _buildAddressSection() {
    return KCollapsibleSection(
      title: 'Address',
      icon: Icons.home_outlined,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            'Current address',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        KTextField(
          label: 'Line 1',
          controller: _currAddr1Ctrl,
          prefixIcon: Icons.home_work_outlined,
        ),
        KSpacing.vGapSm,
        KTextField(label: 'Line 2', controller: _currAddr2Ctrl),
        KSpacing.vGapSm,
        KCompactRow(children: [
          KTextField(label: 'City', controller: _currCityCtrl),
          KTextField(label: 'State', controller: _currStateCtrl),
          KTextField(
            label: 'Pincode',
            controller: _currPincodeCtrl,
            keyboardType: TextInputType.number,
          ),
        ]),
        KSpacing.vGapMd,
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            'Permanent address',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        KTextField(
          label: 'Line 1',
          controller: _permAddr1Ctrl,
          prefixIcon: Icons.house_outlined,
        ),
        KSpacing.vGapSm,
        KTextField(label: 'Line 2', controller: _permAddr2Ctrl),
        KSpacing.vGapSm,
        KCompactRow(children: [
          KTextField(label: 'City', controller: _permCityCtrl),
          KTextField(label: 'State', controller: _permStateCtrl),
          KTextField(
            label: 'Pincode',
            controller: _permPincodeCtrl,
            keyboardType: TextInputType.number,
          ),
        ]),
      ],
    );
  }

  // ── V18: Emergency Contact ──

  Widget _buildEmergencyContactSection() {
    return KCollapsibleSection(
      title: 'Emergency Contact',
      icon: Icons.contact_emergency_outlined,
      children: [
        KTextField(
          label: 'Name',
          controller: _emerNameCtrl,
          prefixIcon: Icons.person_outline,
        ),
        KSpacing.vGapSm,
        KCompactRow(children: [
          KTextField(
            label: 'Relationship',
            controller: _emerRelCtrl,
            prefixIcon: Icons.family_restroom,
          ),
          KTextField(
            label: 'Phone',
            controller: _emerPhoneCtrl,
            prefixIcon: Icons.phone,
            keyboardType: TextInputType.phone,
          ),
        ]),
      ],
    );
  }

  Widget _datePickerTile({
    required String label,
    required DateTime? value,
    required IconData icon,
    required void Function(DateTime?) onPick,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: value == null
            ? IconButton(
                icon: const Icon(Icons.calendar_today_outlined),
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: value ?? now,
                    firstDate: DateTime(1950),
                    lastDate: DateTime(now.year + 5),
                  );
                  if (picked != null) onPick(picked);
                },
              )
            : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => onPick(null),
              ),
      ),
      child: Text(value == null ? 'Not set' : _formatDate(value)),
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

      // V18 depth — only send when set
      if (_dateOfBirth != null) 'dateOfBirth': _formatDate(_dateOfBirth!),
      if (_gender != null) 'gender': _gender,
      if (_maritalStatus != null) 'maritalStatus': _maritalStatus,
      if (_bloodGroupCtrl.text.trim().isNotEmpty)
        'bloodGroup': _bloodGroupCtrl.text.trim(),
      if (_nationalityCtrl.text.trim().isNotEmpty)
        'nationality': _nationalityCtrl.text.trim(),
      if (_personalEmailCtrl.text.trim().isNotEmpty)
        'personalEmail': _personalEmailCtrl.text.trim(),

      if (_currAddr1Ctrl.text.trim().isNotEmpty)
        'currentAddressLine1': _currAddr1Ctrl.text.trim(),
      if (_currAddr2Ctrl.text.trim().isNotEmpty)
        'currentAddressLine2': _currAddr2Ctrl.text.trim(),
      if (_currCityCtrl.text.trim().isNotEmpty)
        'currentCity': _currCityCtrl.text.trim(),
      if (_currStateCtrl.text.trim().isNotEmpty)
        'currentState': _currStateCtrl.text.trim(),
      if (_currPincodeCtrl.text.trim().isNotEmpty)
        'currentPincode': _currPincodeCtrl.text.trim(),

      if (_permAddr1Ctrl.text.trim().isNotEmpty)
        'permanentAddressLine1': _permAddr1Ctrl.text.trim(),
      if (_permAddr2Ctrl.text.trim().isNotEmpty)
        'permanentAddressLine2': _permAddr2Ctrl.text.trim(),
      if (_permCityCtrl.text.trim().isNotEmpty)
        'permanentCity': _permCityCtrl.text.trim(),
      if (_permStateCtrl.text.trim().isNotEmpty)
        'permanentState': _permStateCtrl.text.trim(),
      if (_permPincodeCtrl.text.trim().isNotEmpty)
        'permanentPincode': _permPincodeCtrl.text.trim(),

      if (_emerNameCtrl.text.trim().isNotEmpty)
        'emergencyContactName': _emerNameCtrl.text.trim(),
      if (_emerRelCtrl.text.trim().isNotEmpty)
        'emergencyContactRelationship': _emerRelCtrl.text.trim(),
      if (_emerPhoneCtrl.text.trim().isNotEmpty)
        'emergencyContactPhone': _emerPhoneCtrl.text.trim(),

      if (_employmentType != null) 'employmentType': _employmentType,
      if (_workLocationCtrl.text.trim().isNotEmpty)
        'workLocation': _workLocationCtrl.text.trim(),
      if (_probationEndDate != null)
        'probationEndDate': _formatDate(_probationEndDate!),
      if (_confirmationDate != null)
        'confirmationDate': _formatDate(_confirmationDate!),
      if (_noticePeriodDaysCtrl.text.trim().isNotEmpty)
        'noticePeriodDays': int.tryParse(_noticePeriodDaysCtrl.text.trim()),
      if (_userId != null) 'userId': _userId,
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
