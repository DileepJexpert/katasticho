import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/intl/country_currency.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/form_error_handler.dart';
import '../../../core/widgets/widgets.dart';
import '../../payment_terms/data/payment_terms_repository.dart';
import '../data/contact_repository.dart';

class ContactCreateScreen extends ConsumerStatefulWidget {
  final String? contactId;
  final String? initialType;

  const ContactCreateScreen({super.key, this.contactId, this.initialType});

  @override
  ConsumerState<ContactCreateScreen> createState() =>
      _ContactCreateScreenState();
}

class _ContactCreateScreenState extends ConsumerState<ContactCreateScreen>
    with FormErrorHandler {
  final _formKey = GlobalKey<FormState>();

  String _contactType = 'CUSTOMER';
  bool _supplierEnabled = false;
  final _displayNameCtrl = TextEditingController();
  final _companyNameCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();

  final _gstinCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  String _gstTreatment = 'UNREGISTERED';
  String? _lastGstinPrefix;

  // MSME & TDS
  bool _msmeRegistered = false;
  final _msmeRegNoCtrl = TextEditingController();
  bool _tdsApplicable = false;
  String _tdsSection = '194C';
  final _tdsRateCtrl = TextEditingController(text: '1.0');

  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();

  // Billing address
  final _billAddr1Ctrl = TextEditingController();
  final _billCityCtrl = TextEditingController();
  final _billStateCtrl = TextEditingController();
  final _billStateCodeCtrl = TextEditingController();
  final _billPostalCtrl = TextEditingController();
  final _billCountryCtrl = TextEditingController(text: 'IN');

  // Shipping address
  bool _sameAsBilling = true;
  final _shipAddr1Ctrl = TextEditingController();
  final _shipCityCtrl = TextEditingController();
  final _shipStateCtrl = TextEditingController();
  final _shipStateCodeCtrl = TextEditingController();
  final _shipPostalCtrl = TextEditingController();
  final _shipCountryCtrl = TextEditingController(text: 'IN');

  // Bank & Payout
  final _bankNameCtrl = TextEditingController();
  final _bankAccountNoCtrl = TextEditingController();
  final _bankIfscCtrl = TextEditingController();
  final _upiIdCtrl = TextEditingController();

  // Financial terms
  final _openingBalanceCtrl = TextEditingController(text: '0');
  String _openingBalanceType = 'DEBIT'; // DEBIT = AR (Customer), CREDIT = AP (Vendor)
  final _creditLimitCtrl = TextEditingController(text: '0');
  int _paymentTermsDays = 30;

  // Notes
  final _notesCtrl = TextEditingController();

  // Pharma MR profile
  String? _medicalCategory;
  String? _mrClass;
  final _specialtyCtrl = TextEditingController();
  final _visitsPerMonthCtrl = TextEditingController();

  bool _loading = false;
  bool _isEdit = false;

  bool get _isPharmacyOrg {
    final auth = ref.watch(authProvider);
    final industry = (auth.industryCode ?? auth.industry ?? '').toUpperCase();
    return industry == 'PHARMACY' || industry.contains('PHARMA');
  }

  @override
  void initState() {
    super.initState();
    if (widget.contactId != null) {
      _isEdit = true;
      _loadContact();
    } else if (widget.initialType != null) {
      final t = widget.initialType!.toUpperCase();
      if (t == 'VENDOR' || t == 'SUPPLIER') {
        _contactType = 'VENDOR';
        _supplierEnabled = true;
        _openingBalanceType = 'CREDIT';
      } else if (t == 'BOTH') {
        _contactType = 'BOTH';
        _supplierEnabled = true;
      } else {
        _contactType = 'CUSTOMER';
        _openingBalanceType = 'DEBIT';
      }
    }
  }

  /// Smart GSTIN Parser: Derives State + Code + auto-populates PAN (chars 3-12)
  void _onGstinChanged(String raw) {
    final gstin = raw.trim().toUpperCase();
    if (gstin.length == 15) {
      setState(() {
        _gstTreatment = 'REGISTERED';
        if (_panCtrl.text.trim().isEmpty) {
          _panCtrl.text = gstin.substring(2, 12);
        }
      });
    } else if (gstin.isEmpty && _gstTreatment == 'REGISTERED') {
      setState(() => _gstTreatment = 'UNREGISTERED');
    }
    if (gstin.length >= 2) {
      _resolveBillingStateFromGstin(gstin);
    }
  }

  /// Marg-style: derive billing State + Code from the GSTIN's leading two digits
  Future<void> _resolveBillingStateFromGstin(String gstin) async {
    if (gstin.length < 2) return;
    final prefix = gstin.substring(0, 2);
    if (prefix == _lastGstinPrefix || int.tryParse(prefix) == null) return;
    _lastGstinPrefix = prefix;
    try {
      final res =
          await ref.read(apiClientProvider).get(ApiConfig.gstStateByGstin(prefix));
      final data = (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
      if (data != null && mounted) {
        setState(() {
          _billStateCtrl.text = data['stateName'] as String? ?? _billStateCtrl.text;
          _billStateCodeCtrl.text = data['code'] as String? ?? _billStateCodeCtrl.text;
        });
      }
    } catch (_) {
      // ignore lookup error
    }
  }

  void _copyBillingToShipping() {
    setState(() {
      _shipAddr1Ctrl.text = _billAddr1Ctrl.text;
      _shipCityCtrl.text = _billCityCtrl.text;
      _shipStateCtrl.text = _billStateCtrl.text;
      _shipStateCodeCtrl.text = _billStateCodeCtrl.text;
      _shipPostalCtrl.text = _billPostalCtrl.text;
      _shipCountryCtrl.text = _billCountryCtrl.text;
    });
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _companyNameCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _gstinCtrl.dispose();
    _panCtrl.dispose();
    _msmeRegNoCtrl.dispose();
    _tdsRateCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _mobileCtrl.dispose();
    _websiteCtrl.dispose();
    _billAddr1Ctrl.dispose();
    _billCityCtrl.dispose();
    _billStateCtrl.dispose();
    _billStateCodeCtrl.dispose();
    _billPostalCtrl.dispose();
    _billCountryCtrl.dispose();
    _shipAddr1Ctrl.dispose();
    _shipCityCtrl.dispose();
    _shipStateCtrl.dispose();
    _shipStateCodeCtrl.dispose();
    _shipPostalCtrl.dispose();
    _shipCountryCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankAccountNoCtrl.dispose();
    _bankIfscCtrl.dispose();
    _upiIdCtrl.dispose();
    _openingBalanceCtrl.dispose();
    _creditLimitCtrl.dispose();
    _notesCtrl.dispose();
    _specialtyCtrl.dispose();
    _visitsPerMonthCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadContact() async {
    final repo = ref.read(contactRepositoryProvider);
    final result = await repo.getContact(widget.contactId!);
    final c = (result['data'] ?? result) as Map<String, dynamic>;
    setState(() {
      _contactType = c['contactType'] as String? ?? 'CUSTOMER';
      _supplierEnabled = c['supplierEnabled'] as bool? ?? false;
      _displayNameCtrl.text = c['displayName'] as String? ?? '';
      _companyNameCtrl.text = c['companyName'] as String? ?? '';
      _firstNameCtrl.text = c['firstName'] as String? ?? '';
      _lastNameCtrl.text = c['lastName'] as String? ?? '';
      _gstinCtrl.text = c['gstin'] as String? ?? '';
      _panCtrl.text = c['pan'] as String? ?? '';
      _gstTreatment = c['gstTreatment'] as String? ?? 'UNREGISTERED';
      _msmeRegistered = c['msmeRegistered'] as bool? ?? false;
      _msmeRegNoCtrl.text = c['msmeRegistrationNo'] as String? ?? '';
      _tdsApplicable = c['tdsApplicable'] as bool? ?? false;
      _tdsSection = c['tdsSection'] as String? ?? '194C';
      _tdsRateCtrl.text = (c['tdsRate'] as num?)?.toString() ?? '1.0';
      _emailCtrl.text = c['email'] as String? ?? '';
      _phoneCtrl.text = c['phone'] as String? ?? '';
      _mobileCtrl.text = c['mobile'] as String? ?? '';
      _websiteCtrl.text = c['website'] as String? ?? '';
      _billAddr1Ctrl.text = c['billingAddressLine1'] as String? ?? '';
      _billCityCtrl.text = c['billingCity'] as String? ?? '';
      _billStateCtrl.text = c['billingState'] as String? ?? '';
      _billStateCodeCtrl.text = c['billingStateCode'] as String? ?? '';
      _billPostalCtrl.text = c['billingPostalCode'] as String? ?? '';
      _billCountryCtrl.text = c['billingCountry'] as String? ?? 'IN';
      _shipAddr1Ctrl.text = c['shippingAddressLine1'] as String? ?? '';
      _shipCityCtrl.text = c['shippingCity'] as String? ?? '';
      _shipStateCtrl.text = c['shippingState'] as String? ?? '';
      _shipStateCodeCtrl.text = c['shippingStateCode'] as String? ?? '';
      _shipPostalCtrl.text = c['shippingPostalCode'] as String? ?? '';
      _shipCountryCtrl.text = c['shippingCountry'] as String? ?? 'IN';
      _sameAsBilling = _shipAddr1Ctrl.text.isEmpty ||
          _shipAddr1Ctrl.text == _billAddr1Ctrl.text;
      _bankNameCtrl.text = c['bankName'] as String? ?? '';
      _bankAccountNoCtrl.text = c['bankAccountNo'] as String? ?? '';
      _bankIfscCtrl.text = c['bankIfsc'] as String? ?? '';
      _upiIdCtrl.text = c['upiId'] as String? ?? '';
      final ob = (c['openingBalance'] as num?)?.toDouble() ?? 0.0;
      _openingBalanceCtrl.text = ob.abs().toString();
      _openingBalanceType = ob < 0 ? 'CREDIT' : 'DEBIT';
      _creditLimitCtrl.text = (c['creditLimit'] as num?)?.toString() ?? '0';
      _paymentTermsDays = (c['paymentTermsDays'] as num?)?.toInt() ?? 30;
      _notesCtrl.text = c['notes'] as String? ?? '';
      _medicalCategory = c['medicalCategory'] as String?;
      _mrClass = c['mrClass'] as String?;
      _specialtyCtrl.text = c['specialty'] as String? ?? '';
      _visitsPerMonthCtrl.text =
          (c['visitsPerMonth'] as num?)?.toString() ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final taxLabel =
        ref.watch(countryProfileProvider).valueOrNull?.taxIdLabel ?? 'GSTIN';
    final isGstin = taxLabel == 'GSTIN';
    final isVendorType = _contactType == 'VENDOR' || _contactType == 'BOTH';
    final paymentTermsAsync = ref.watch(paymentTermsListProvider);

    return KKeyboardFormWrapper(
      onSubmit: _save,
      onCancel: () => context.pop(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit
              ? 'Edit Contact'
              : (_contactType == 'VENDOR'
                  ? 'Add Vendor / Supplier'
                  : 'Add Customer')),
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
              // Contact Role Switcher & Procurement Role Header
              KCard(
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'CUSTOMER',
                            label: Text('Customer'),
                            icon: Icon(Icons.person_outline, size: 18),
                          ),
                          ButtonSegment(
                            value: 'VENDOR',
                            label: Text('Vendor'),
                            icon: Icon(Icons.storefront_outlined, size: 18),
                          ),
                          ButtonSegment(
                            value: 'BOTH',
                            label: Text('Both'),
                            icon: Icon(Icons.swap_horiz_outlined, size: 18),
                          ),
                        ],
                        selected: {_contactType},
                        onSelectionChanged: (s) => setState(() {
                          _contactType = s.first;
                          if (_contactType == 'CUSTOMER') {
                            _supplierEnabled = false;
                            _openingBalanceType = 'DEBIT';
                          } else if (_contactType == 'VENDOR') {
                            _supplierEnabled = true;
                            _openingBalanceType = 'CREDIT';
                          }
                        }),
                      ),
                    ),
                    if (isVendorType) ...[
                      KSpacing.hGapLg,
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_shipping_outlined, color: KColors.primary, size: 20),
                          KSpacing.hGapSm,
                          const Text('Procurement Supplier Role', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          KSpacing.hGapSm,
                          Switch(
                            value: _supplierEnabled,
                            onChanged: _isEdit && _supplierEnabled
                                ? null
                                : (value) => setState(() => _supplierEnabled = value),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              KSpacing.vGapSm,

              // ── 1. Basic & Contact Information (High Density) ──
              KCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 18, color: KColors.primary),
                        KSpacing.hGapSm,
                        Text('Basic & Contact Information', style: KTypography.labelLarge.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    KSpacing.vGapSm,
                    KCompactRow(
                      flex: const [3, 3, 2, 2],
                      stackBelow: 760,
                      children: [
                        KTextField(
                          label: 'Display Name',
                          isRequired: true,
                          controller: _displayNameCtrl,
                          prefixIcon: Icons.person_outline,
                          serverError: serverErrors['displayName'],
                          validator: (v) => fieldError(
                              'displayName',
                              (v == null || v.trim().isEmpty)
                                  ? 'Display name is required'
                                  : null),
                        ),
                        KTextField(
                          label: 'Company / Business Name',
                          controller: _companyNameCtrl,
                          prefixIcon: Icons.business_outlined,
                          serverError: serverErrors['companyName'],
                        ),
                        KTextField(
                          label: 'First Name',
                          controller: _firstNameCtrl,
                        ),
                        KTextField(
                          label: 'Last Name',
                          controller: _lastNameCtrl,
                        ),
                      ],
                    ),
                    KSpacing.vGapSm,
                    KCompactRow(
                      flex: const [3, 3, 2, 2],
                      stackBelow: 760,
                      children: [
                        KTextField(
                          label: 'Email Address',
                          controller: _emailCtrl,
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          serverError: serverErrors['email'],
                          validator: (v) => fieldError(
                              'email',
                              (v != null && v.isNotEmpty && !v.contains('@'))
                                  ? 'Enter a valid email'
                                  : null),
                        ),
                        KTextField(
                          label: 'Website',
                          controller: _websiteCtrl,
                          prefixIcon: Icons.language_outlined,
                          hint: 'https://example.com',
                        ),
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
                      ],
                    ),
                  ],
                ),
              ),
              KSpacing.vGapSm,

              // ── 2. Tax, MSME & Statutory Compliance (High Density) ──
              KCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 18, color: KColors.primary),
                        KSpacing.hGapSm,
                        Text('Tax & Statutory Compliance', style: KTypography.labelLarge.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    KSpacing.vGapSm,
                    KCompactRow(
                      flex: const [3, 3, 2],
                      stackBelow: 680,
                      children: [
                        KDropdownField<String>(
                          label: 'GST Treatment',
                          value: _gstTreatment,
                          prefixIcon: Icons.account_balance_outlined,
                          items: const [
                            DropdownMenuItem(value: 'REGISTERED', child: Text('Registered', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'UNREGISTERED', child: Text('Unregistered', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'COMPOSITION', child: Text('Composition', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'CONSUMER', child: Text('Consumer', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'OVERSEAS', child: Text('Overseas / Export', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'SEZ', child: Text('SEZ Developer / Unit', overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (v) =>
                              setState(() => _gstTreatment = v ?? 'UNREGISTERED'),
                        ),
                        KTextField(
                          label: taxLabel,
                          controller: _gstinCtrl,
                          prefixIcon: Icons.receipt_long_outlined,
                          maxLength: isGstin ? 15 : null,
                          serverError: serverErrors['gstin'],
                          validator: (v) => fieldError(
                              'gstin',
                              (isGstin && v != null && v.isNotEmpty && v.length != 15)
                                  ? 'GSTIN must be 15 characters'
                                  : null),
                          onChanged: _onGstinChanged,
                        ),
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
                                  : null),
                        ),
                      ],
                    ),
                    KSpacing.vGapSm,
                    KCompactRow(
                      flex: isVendorType ? const [1, 1] : const [1],
                      stackBelow: 680,
                      children: [
                        // MSME inline row
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.verified_outlined, size: 18, color: KColors.primary),
                              KSpacing.hGapSm,
                              const Text('MSME Reg.', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              KSpacing.hGapSm,
                              Switch(
                                value: _msmeRegistered,
                                onChanged: (v) => setState(() => _msmeRegistered = v),
                              ),
                              if (_msmeRegistered) ...[
                                KSpacing.hGapSm,
                                Expanded(
                                  child: KTextField(
                                    label: 'Udyam Registration No',
                                    controller: _msmeRegNoCtrl,
                                    hint: 'UDYAM-XX-00-0000000',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // TDS inline row (Vendor only)
                        if (isVendorType)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.percent_outlined, size: 18, color: KColors.primary),
                                KSpacing.hGapSm,
                                const Text('TDS Deduct', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                KSpacing.hGapSm,
                                Switch(
                                  value: _tdsApplicable,
                                  onChanged: (v) => setState(() => _tdsApplicable = v),
                                ),
                                if (_tdsApplicable) ...[
                                  KSpacing.hGapSm,
                                  Expanded(
                                    flex: 3,
                                    child: KDropdownField<String>(
                                      label: 'TDS Section',
                                      value: _tdsSection,
                                      prefixIcon: Icons.gavel_outlined,
                                      items: const [
                                        DropdownMenuItem(value: '194C', child: Text('194C (1/2%)', overflow: TextOverflow.ellipsis)),
                                        DropdownMenuItem(value: '194J', child: Text('194J (10%)', overflow: TextOverflow.ellipsis)),
                                        DropdownMenuItem(value: '194Q', child: Text('194Q (0.1%)', overflow: TextOverflow.ellipsis)),
                                        DropdownMenuItem(value: '194H', child: Text('194H (5%)', overflow: TextOverflow.ellipsis)),
                                        DropdownMenuItem(value: '194I', child: Text('194I (2/10%)', overflow: TextOverflow.ellipsis)),
                                      ],
                                      onChanged: (v) => setState(() => _tdsSection = v ?? '194C'),
                                    ),
                                  ),
                                  KSpacing.hGapSm,
                                  Expanded(
                                    flex: 2,
                                    child: KTextField(
                                      label: 'Rate %',
                                      controller: _tdsRateCtrl,
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              KSpacing.vGapSm,

              // ── 3. Addresses (Billing & Shipping) (High Density) ──
              KCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 18, color: KColors.primary),
                        KSpacing.hGapSm,
                        Text('Addresses', style: KTypography.labelLarge.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    KSpacing.vGapSm,
                    const Text('Billing Address', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    KSpacing.vGapXs,
                    KCompactRow(
                      flex: const [4, 2, 2, 1, 1, 1],
                      stackBelow: 760,
                      children: [
                        KTextField(
                          label: 'Address (Building / Street)',
                          controller: _billAddr1Ctrl,
                        ),
                        KTextField(
                          label: 'City',
                          controller: _billCityCtrl,
                        ),
                        KTextField(
                          label: 'State',
                          controller: _billStateCtrl,
                        ),
                        KTextField(
                          label: 'State Code',
                          controller: _billStateCodeCtrl,
                          maxLength: 5,
                          hint: '29',
                        ),
                        KTextField(
                          label: 'Postal Code',
                          controller: _billPostalCtrl,
                          keyboardType: TextInputType.number,
                        ),
                        KTextField(
                          label: 'Country',
                          controller: _billCountryCtrl,
                          maxLength: 2,
                        ),
                      ],
                    ),
                    KSpacing.vGapSm,
                    Row(
                      children: [
                        Checkbox(
                          value: _sameAsBilling,
                          onChanged: (v) => setState(() {
                            _sameAsBilling = v ?? true;
                            if (_sameAsBilling) _copyBillingToShipping();
                          }),
                        ),
                        const Text('Shipping address is same as billing address', style: TextStyle(fontSize: 13)),
                        const Spacer(),
                        if (!_sameAsBilling)
                          TextButton.icon(
                            onPressed: _copyBillingToShipping,
                            icon: const Icon(Icons.copy_outlined, size: 14),
                            label: const Text('Copy Billing', style: TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                    if (!_sameAsBilling) ...[
                      KSpacing.vGapXs,
                      const Text('Shipping Address', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      KSpacing.vGapXs,
                      KCompactRow(
                        flex: const [4, 2, 2, 1, 1, 1],
                        stackBelow: 760,
                        children: [
                          KTextField(
                            label: 'Shipping Address (Building / Street)',
                            controller: _shipAddr1Ctrl,
                          ),
                          KTextField(
                            label: 'City',
                            controller: _shipCityCtrl,
                          ),
                          KTextField(
                            label: 'State',
                            controller: _shipStateCtrl,
                          ),
                          KTextField(
                            label: 'State Code',
                            controller: _shipStateCodeCtrl,
                            maxLength: 5,
                          ),
                          KTextField(
                            label: 'Postal Code',
                            controller: _shipPostalCtrl,
                            keyboardType: TextInputType.number,
                          ),
                          KTextField(
                            label: 'Country',
                            controller: _shipCountryCtrl,
                            maxLength: 2,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              KSpacing.vGapSm,

              // ── 4. Banking, Financial Terms & Notes (High Density) ──
              KCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance_outlined, size: 18, color: KColors.primary),
                        KSpacing.hGapSm,
                        Text('Banking, Financial Terms & Notes', style: KTypography.labelLarge.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    KSpacing.vGapSm,
                    // Bank info row
                    KCompactRow(
                      flex: const [3, 3, 2, 2],
                      stackBelow: 760,
                      children: [
                        KTextField(
                          label: 'Bank Name',
                          controller: _bankNameCtrl,
                          prefixIcon: Icons.account_balance_outlined,
                          hint: 'e.g. HDFC Bank',
                        ),
                        KTextField(
                          label: 'Account Number',
                          controller: _bankAccountNoCtrl,
                          prefixIcon: Icons.pin_outlined,
                          keyboardType: TextInputType.number,
                        ),
                        KTextField(
                          label: 'IFSC Code',
                          controller: _bankIfscCtrl,
                          prefixIcon: Icons.code_outlined,
                          maxLength: 11,
                          hint: 'HDFC0001234',
                          inputFormatters: [
                            TextInputFormatter.withFunction((oldVal, newVal) =>
                                newVal.copyWith(text: newVal.text.toUpperCase())),
                          ],
                        ),
                        KTextField(
                          label: 'UPI ID / VPA',
                          controller: _upiIdCtrl,
                          prefixIcon: Icons.payment_outlined,
                          hint: 'vendor@upi',
                        ),
                      ],
                    ),
                    KSpacing.vGapSm,
                    // Financial Terms row
                    KCompactRow(
                      flex: const [2, 2, 2, 3],
                      stackBelow: 760,
                      children: [
                        KTextField(
                          label: 'Opening Balance (₹)',
                          controller: _openingBalanceCtrl,
                          keyboardType: TextInputType.number,
                          prefixIcon: Icons.account_balance_wallet_outlined,
                        ),
                        KDropdownField<String>(
                          label: 'Balance Type',
                          value: _openingBalanceType,
                          prefixIcon: Icons.swap_vert_outlined,
                          items: const [
                            DropdownMenuItem(value: 'DEBIT', child: Text('Debit', overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'CREDIT', child: Text('Credit', overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (v) => setState(() => _openingBalanceType = v ?? 'DEBIT'),
                        ),
                        KTextField(
                          label: 'Credit Limit (₹)',
                          controller: _creditLimitCtrl,
                          keyboardType: TextInputType.number,
                          prefixIcon: Icons.security_outlined,
                        ),
                        paymentTermsAsync.when(
                          loading: () => KDropdownField<int>(
                            label: 'Payment Terms',
                            value: _paymentTermsDays,
                            prefixIcon: Icons.calendar_today_outlined,
                            items: [
                              DropdownMenuItem(value: _paymentTermsDays, child: Text('Net $_paymentTermsDays days', overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: null,
                          ),
                          error: (_, __) => KDropdownField<int>(
                            label: 'Payment Terms',
                            value: _paymentTermsDays,
                            prefixIcon: Icons.calendar_today_outlined,
                            items: const [
                              DropdownMenuItem(value: 0, child: Text('Due on Receipt', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 15, child: Text('Net 15 days', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 30, child: Text('Net 30 days', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 45, child: Text('Net 45 days', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 60, child: Text('Net 60 days', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 90, child: Text('Net 90 days', overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (v) => setState(() => _paymentTermsDays = v ?? 30),
                          ),
                          data: (list) {
                            final items = <DropdownMenuItem<int>>[
                              const DropdownMenuItem(value: 0, child: Text('Due on Receipt', overflow: TextOverflow.ellipsis)),
                              const DropdownMenuItem(value: 15, child: Text('Net 15 days', overflow: TextOverflow.ellipsis)),
                              const DropdownMenuItem(value: 30, child: Text('Net 30 days', overflow: TextOverflow.ellipsis)),
                              const DropdownMenuItem(value: 45, child: Text('Net 45 days', overflow: TextOverflow.ellipsis)),
                              const DropdownMenuItem(value: 60, child: Text('Net 60 days', overflow: TextOverflow.ellipsis)),
                              const DropdownMenuItem(value: 90, child: Text('Net 90 days', overflow: TextOverflow.ellipsis)),
                            ];
                            for (final term in list) {
                              final days = (term['daysOffset'] as num?)?.toInt() ?? 30;
                              final name = term['name'] as String? ?? 'Term';
                              if (!items.any((e) => e.value == days)) {
                                items.add(DropdownMenuItem(value: days, child: Text('$name ($days d)', overflow: TextOverflow.ellipsis)));
                              }
                            }
                            return KDropdownField<int>(
                              label: 'Payment Terms',
                              value: items.any((e) => e.value == _paymentTermsDays)
                                  ? _paymentTermsDays
                                  : 30,
                              prefixIcon: Icons.calendar_today_outlined,
                              items: items,
                              onChanged: (v) => setState(() => _paymentTermsDays = v ?? 30),
                            );
                          },
                        ),
                      ],
                    ),
                    KSpacing.vGapSm,
                    KTextField(
                      label: 'Internal Notes & Remarks',
                      controller: _notesCtrl,
                      hint: 'Additional notes or payment instructions...',
                    ),
                    if (_isPharmacyOrg) ...[
                      KSpacing.vGapSm,
                      const Divider(height: 1),
                      KSpacing.vGapSm,
                      Row(
                        children: [
                          const Icon(Icons.medical_services_outlined, size: 18, color: KColors.primary),
                          KSpacing.hGapSm,
                          Text('MR Profile (Doctor / Chemist)', style: KTypography.labelLarge.copyWith(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      KSpacing.vGapSm,
                      KCompactRow(
                        flex: const [2, 1, 3, 2],
                        stackBelow: 680,
                        children: [
                          KDropdownField<String?>(
                            label: 'Category',
                            value: _medicalCategory,
                            prefixIcon: Icons.medical_services_outlined,
                            items: const [
                              DropdownMenuItem(value: null, child: Text('None', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'DOCTOR', child: Text('Doctor', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'CHEMIST', child: Text('Chemist', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'STOCKIST', child: Text('Stockist', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'HOSPITAL', child: Text('Hospital', overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (v) => setState(() => _medicalCategory = v),
                          ),
                          KDropdownField<String?>(
                            label: 'Class',
                            value: _mrClass,
                            prefixIcon: Icons.star_outline,
                            items: const [
                              DropdownMenuItem(value: null, child: Text('None', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'A', child: Text('A', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'B', child: Text('B', overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'C', child: Text('C', overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (v) => setState(() => _mrClass = v),
                          ),
                          KTextField(
                            label: 'Specialty',
                            controller: _specialtyCtrl,
                            hint: 'e.g. Cardiologist',
                          ),
                          KTextField(
                            label: 'Visits / Month',
                            controller: _visitsPerMonthCtrl,
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              KSpacing.vGapLg,
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    clearServerErrors();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final rawOb = double.tryParse(_openingBalanceCtrl.text.trim()) ?? 0.0;
    final signedOb = _openingBalanceType == 'CREDIT' ? -rawOb.abs() : rawOb.abs();

    final data = <String, dynamic>{
      'contactType': _contactType,
      'supplierEnabled': _supplierEnabled,
      'displayName': _displayNameCtrl.text.trim(),
      if (_companyNameCtrl.text.isNotEmpty)
        'companyName': _companyNameCtrl.text.trim(),
      if (_firstNameCtrl.text.isNotEmpty)
        'firstName': _firstNameCtrl.text.trim(),
      if (_lastNameCtrl.text.isNotEmpty) 'lastName': _lastNameCtrl.text.trim(),
      if (_gstinCtrl.text.isNotEmpty) 'gstin': _gstinCtrl.text.trim(),
      if (_panCtrl.text.isNotEmpty) 'pan': _panCtrl.text.trim(),
      'gstTreatment': _gstTreatment,
      'msmeRegistered': _msmeRegistered,
      if (_msmeRegistered && _msmeRegNoCtrl.text.isNotEmpty)
        'msmeRegistrationNo': _msmeRegNoCtrl.text.trim(),
      'tdsApplicable': _tdsApplicable,
      if (_tdsApplicable) 'tdsSection': _tdsSection,
      if (_tdsApplicable)
        'tdsRate': double.tryParse(_tdsRateCtrl.text) ?? 1.0,
      if (_emailCtrl.text.isNotEmpty) 'email': _emailCtrl.text.trim(),
      if (_phoneCtrl.text.isNotEmpty) 'phone': _phoneCtrl.text.trim(),
      if (_mobileCtrl.text.isNotEmpty) 'mobile': _mobileCtrl.text.trim(),
      if (_websiteCtrl.text.isNotEmpty) 'website': _websiteCtrl.text.trim(),

      // Billing address
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
      'billingCountry': _billCountryCtrl.text.trim().isEmpty
          ? 'IN'
          : _billCountryCtrl.text.trim(),

      // Shipping address
      'shippingAddressLine1': _sameAsBilling
          ? _billAddr1Ctrl.text.trim()
          : _shipAddr1Ctrl.text.trim(),
      'shippingCity': _sameAsBilling
          ? _billCityCtrl.text.trim()
          : _shipCityCtrl.text.trim(),
      'shippingState': _sameAsBilling
          ? _billStateCtrl.text.trim()
          : _shipStateCtrl.text.trim(),
      'shippingStateCode': _sameAsBilling
          ? _billStateCodeCtrl.text.trim()
          : _shipStateCodeCtrl.text.trim(),
      'shippingPostalCode': _sameAsBilling
          ? _billPostalCtrl.text.trim()
          : _shipPostalCtrl.text.trim(),
      'shippingCountry': _sameAsBilling
          ? (_billCountryCtrl.text.trim().isEmpty ? 'IN' : _billCountryCtrl.text.trim())
          : (_shipCountryCtrl.text.trim().isEmpty ? 'IN' : _shipCountryCtrl.text.trim()),

      // Bank & Payout
      if (_bankNameCtrl.text.isNotEmpty) 'bankName': _bankNameCtrl.text.trim(),
      if (_bankAccountNoCtrl.text.isNotEmpty)
        'bankAccountNo': _bankAccountNoCtrl.text.trim(),
      if (_bankIfscCtrl.text.isNotEmpty) 'bankIfsc': _bankIfscCtrl.text.trim(),
      if (_upiIdCtrl.text.isNotEmpty) 'upiId': _upiIdCtrl.text.trim(),

      'openingBalance': signedOb,
      'creditLimit': double.tryParse(_creditLimitCtrl.text) ?? 0.0,
      'paymentTermsDays': _paymentTermsDays,
      if (_notesCtrl.text.isNotEmpty) 'notes': _notesCtrl.text.trim(),

      if (_isPharmacyOrg && _medicalCategory != null)
        'medicalCategory': _medicalCategory,
      if (_isPharmacyOrg && _mrClass != null) 'mrClass': _mrClass,
      if (_isPharmacyOrg && _specialtyCtrl.text.isNotEmpty)
        'specialty': _specialtyCtrl.text.trim(),
      if (_isPharmacyOrg && _visitsPerMonthCtrl.text.isNotEmpty)
        'visitsPerMonth': int.tryParse(_visitsPerMonthCtrl.text),
    };

    try {
      final repo = ref.read(contactRepositoryProvider);
      if (_isEdit) {
        await repo.updateContact(widget.contactId!, data);
      } else {
        await repo.createContact(data);
      }
      ref.invalidate(contactListProvider);
      ref.invalidate(contactSummaryProvider);
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
