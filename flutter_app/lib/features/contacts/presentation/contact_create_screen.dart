import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/utils/form_error_handler.dart';
import '../../../core/widgets/widgets.dart';
import '../data/contact_repository.dart';

class ContactCreateScreen extends ConsumerStatefulWidget {
  final String? contactId;

  const ContactCreateScreen({super.key, this.contactId});

  @override
  ConsumerState<ContactCreateScreen> createState() =>
      _ContactCreateScreenState();
}

class _ContactCreateScreenState extends ConsumerState<ContactCreateScreen>
    with FormErrorHandler {
  final _formKey = GlobalKey<FormState>();

  String _contactType = 'CUSTOMER';
  final _displayNameCtrl = TextEditingController();
  final _companyNameCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();

  final _gstinCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  String _gstTreatment = 'UNREGISTERED';

  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();

  final _billAddr1Ctrl = TextEditingController();
  final _billCityCtrl = TextEditingController();
  final _billStateCtrl = TextEditingController();
  final _billStateCodeCtrl = TextEditingController();
  final _billPostalCtrl = TextEditingController();
  final _billCountryCtrl = TextEditingController(text: 'IN');

  final _creditLimitCtrl = TextEditingController(text: '0');
  int _paymentTermsDays = 30;

  bool _loading = false;
  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    if (widget.contactId != null) {
      _isEdit = true;
      _loadContact();
    }
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _companyNameCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _gstinCtrl.dispose();
    _panCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _mobileCtrl.dispose();
    _billAddr1Ctrl.dispose();
    _billCityCtrl.dispose();
    _billStateCtrl.dispose();
    _billStateCodeCtrl.dispose();
    _billPostalCtrl.dispose();
    _billCountryCtrl.dispose();
    _creditLimitCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadContact() async {
    final repo = ref.read(contactRepositoryProvider);
    final result = await repo.getContact(widget.contactId!);
    final c = (result['data'] ?? result) as Map<String, dynamic>;
    setState(() {
      _contactType = c['contactType'] as String? ?? 'CUSTOMER';
      _displayNameCtrl.text = c['displayName'] as String? ?? '';
      _companyNameCtrl.text = c['companyName'] as String? ?? '';
      _firstNameCtrl.text = c['firstName'] as String? ?? '';
      _lastNameCtrl.text = c['lastName'] as String? ?? '';
      _gstinCtrl.text = c['gstin'] as String? ?? '';
      _panCtrl.text = c['pan'] as String? ?? '';
      _gstTreatment = c['gstTreatment'] as String? ?? 'UNREGISTERED';
      _emailCtrl.text = c['email'] as String? ?? '';
      _phoneCtrl.text = c['phone'] as String? ?? '';
      _mobileCtrl.text = c['mobile'] as String? ?? '';
      _billAddr1Ctrl.text = c['billingAddressLine1'] as String? ?? '';
      _billCityCtrl.text = c['billingCity'] as String? ?? '';
      _billStateCtrl.text = c['billingState'] as String? ?? '';
      _billStateCodeCtrl.text = c['billingStateCode'] as String? ?? '';
      _billPostalCtrl.text = c['billingPostalCode'] as String? ?? '';
      _billCountryCtrl.text = c['billingCountry'] as String? ?? 'IN';
      _creditLimitCtrl.text =
          (c['creditLimit'] as num?)?.toString() ?? '0';
      _paymentTermsDays = (c['paymentTermsDays'] as num?)?.toInt() ?? 30;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Contact' : 'Add Contact'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: KSpacing.pagePadding,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'CUSTOMER', label: Text('Customer')),
                ButtonSegment(value: 'VENDOR', label: Text('Vendor')),
                ButtonSegment(value: 'BOTH', label: Text('Both')),
              ],
              selected: {_contactType},
              onSelectionChanged: (s) =>
                  setState(() => _contactType = s.first),
            ),
            KSpacing.vGapSm,

            KCollapsibleSection(
              title: 'Basic Information',
              icon: Icons.person_outline,
              initiallyExpanded: true,
              children: [
                KTextField(
                  label: 'Display Name',
                  isRequired: true,
                  controller: _displayNameCtrl,
                  prefixIcon: Icons.person_outline,
                  serverError: serverErrors['displayName'],
                  validator: (v) => fieldError('displayName',
                      (v == null || v.trim().isEmpty) ? 'Display name is required' : null),
                ),
                KSpacing.vGapSm,
                KTextField(
                  label: 'Company Name',
                  controller: _companyNameCtrl,
                  prefixIcon: Icons.business_outlined,
                  serverError: serverErrors['companyName'],
                ),
                KSpacing.vGapSm,
                KCompactRow(children: [
                  KTextField(
                    label: 'First Name',
                    controller: _firstNameCtrl,
                  ),
                  KTextField(
                    label: 'Last Name',
                    controller: _lastNameCtrl,
                  ),
                ]),
              ],
            ),

            KCollapsibleSection(
              title: 'Contact Details',
              icon: Icons.phone_outlined,
              children: [
                KTextField(
                  label: 'Email',
                  controller: _emailCtrl,
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  serverError: serverErrors['email'],
                  validator: (v) => fieldError('email',
                      (v != null && v.isNotEmpty && !v.contains('@')) ? 'Enter a valid email' : null),
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
                    label: 'Mobile',
                    controller: _mobileCtrl,
                    prefixIcon: Icons.smartphone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                ]),
              ],
            ),

            KCollapsibleSection(
              title: 'Tax Information',
              icon: Icons.receipt_long_outlined,
              children: [
                KCompactRow(children: [
                  KTextField(
                    label: 'GSTIN',
                    controller: _gstinCtrl,
                    prefixIcon: Icons.receipt_long_outlined,
                    maxLength: 15,
                    serverError: serverErrors['gstin'],
                    validator: (v) => fieldError('gstin',
                        (v != null && v.isNotEmpty && v.length != 15) ? 'GSTIN must be 15 characters' : null),
                    onChanged: (v) {
                      if (v.length == 15) {
                        setState(() => _gstTreatment = 'REGISTERED');
                      } else if (_gstTreatment == 'REGISTERED') {
                        setState(() => _gstTreatment = 'UNREGISTERED');
                      }
                    },
                  ),
                  KTextField(
                    label: 'PAN',
                    controller: _panCtrl,
                    prefixIcon: Icons.credit_card_outlined,
                    maxLength: 10,
                    serverError: serverErrors['pan'],
                    validator: (v) => fieldError('pan',
                        (v != null && v.isNotEmpty && v.length != 10) ? 'PAN must be 10 characters' : null),
                  ),
                ]),
                KSpacing.vGapSm,
                DropdownButtonFormField<String>(
                  value: _gstTreatment,
                  decoration: const InputDecoration(
                    labelText: 'GST Treatment',
                    prefixIcon: Icon(Icons.account_balance_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'REGISTERED', child: Text('Registered')),
                    DropdownMenuItem(
                        value: 'UNREGISTERED', child: Text('Unregistered')),
                    DropdownMenuItem(
                        value: 'COMPOSITION', child: Text('Composition Scheme')),
                    DropdownMenuItem(
                        value: 'CONSUMER', child: Text('Consumer')),
                    DropdownMenuItem(value: 'OVERSEAS', child: Text('Overseas')),
                    DropdownMenuItem(value: 'SEZ', child: Text('SEZ')),
                  ],
                  onChanged: (v) =>
                      setState(() => _gstTreatment = v ?? 'UNREGISTERED'),
                ),
              ],
            ),

            KCollapsibleSection(
              title: 'Billing Address',
              icon: Icons.location_on_outlined,
              children: [
                KTextField(
                  label: 'Address Line 1',
                  controller: _billAddr1Ctrl,
                ),
                KSpacing.vGapSm,
                KCompactRow(flex: const [2, 1], children: [
                  KTextField(
                    label: 'City',
                    controller: _billCityCtrl,
                  ),
                  KTextField(
                    label: 'Postal Code',
                    controller: _billPostalCtrl,
                    keyboardType: TextInputType.number,
                  ),
                ]),
                KSpacing.vGapSm,
                KCompactRow(flex: const [2, 1, 1], children: [
                  KTextField(
                    label: 'State',
                    controller: _billStateCtrl,
                  ),
                  KTextField(
                    label: 'Code',
                    controller: _billStateCodeCtrl,
                    maxLength: 5,
                    hint: 'e.g. 29',
                  ),
                  KTextField(
                    label: 'Country',
                    controller: _billCountryCtrl,
                    maxLength: 2,
                  ),
                ]),
              ],
            ),

            KCollapsibleSection(
              title: 'Financial Terms',
              icon: Icons.account_balance_wallet_outlined,
              children: [
                KCompactRow(children: [
                  KTextField(
                    label: 'Credit Limit (₹)',
                    controller: _creditLimitCtrl,
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.account_balance_wallet_outlined,
                  ),
                  DropdownButtonFormField<int>(
                    value: _paymentTermsDays,
                    decoration: const InputDecoration(
                      labelText: 'Payment Terms',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Due on Receipt')),
                      DropdownMenuItem(value: 15, child: Text('Net 15')),
                      DropdownMenuItem(value: 30, child: Text('Net 30')),
                      DropdownMenuItem(value: 45, child: Text('Net 45')),
                      DropdownMenuItem(value: 60, child: Text('Net 60')),
                      DropdownMenuItem(value: 90, child: Text('Net 90')),
                    ],
                    onChanged: (v) =>
                        setState(() => _paymentTermsDays = v ?? 30),
                  ),
                ]),
              ],
            ),
            KSpacing.vGapMd,
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    clearServerErrors();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final data = <String, dynamic>{
      'contactType': _contactType,
      'displayName': _displayNameCtrl.text.trim(),
      if (_companyNameCtrl.text.isNotEmpty)
        'companyName': _companyNameCtrl.text.trim(),
      if (_firstNameCtrl.text.isNotEmpty)
        'firstName': _firstNameCtrl.text.trim(),
      if (_lastNameCtrl.text.isNotEmpty) 'lastName': _lastNameCtrl.text.trim(),
      if (_gstinCtrl.text.isNotEmpty) 'gstin': _gstinCtrl.text.trim(),
      if (_panCtrl.text.isNotEmpty) 'pan': _panCtrl.text.trim(),
      'gstTreatment': _gstTreatment,
      if (_emailCtrl.text.isNotEmpty) 'email': _emailCtrl.text.trim(),
      if (_phoneCtrl.text.isNotEmpty) 'phone': _phoneCtrl.text.trim(),
      if (_mobileCtrl.text.isNotEmpty) 'mobile': _mobileCtrl.text.trim(),
      if (_billAddr1Ctrl.text.isNotEmpty)
        'billingAddressLine1': _billAddr1Ctrl.text.trim(),
      if (_billCityCtrl.text.isNotEmpty)
        'billingCity': _billCityCtrl.text.trim(),
      if (_billStateCtrl.text.isNotEmpty)
        'billingState': _billStateCtrl.text.trim(),
      if (_billStateCodeCtrl.text.isNotEmpty)
        'billingStateCode': _billStateCodeCtrl.text.trim(),
      if (_billPostalCtrl.text.isNotEmpty)
        'billingPostalCode': _billPostalCtrl.text.trim(),
      'billingCountry':
          _billCountryCtrl.text.trim().isEmpty ? 'IN' : _billCountryCtrl.text.trim(),
      'creditLimit': double.tryParse(_creditLimitCtrl.text) ?? 0.0,
      'paymentTermsDays': _paymentTermsDays,
    };

    try {
      final repo = ref.read(contactRepositoryProvider);
      if (_isEdit) {
        await repo.updateContact(widget.contactId!, data);
      } else {
        await repo.createContact(data);
      }
      ref.invalidate(contactListProvider);
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      handleSaveError(e, _formKey);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
