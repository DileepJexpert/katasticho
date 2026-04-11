import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../data/auth_repository.dart';

/// Industry options matching backend's supported industries.
const _industries = [
  ('KIRANA', 'Kirana / General Store', Icons.storefront),
  ('PHARMACY', 'Pharmacy / Medical Store', Icons.local_pharmacy),
  ('CLOTH_MANUFACTURING', 'Cloth / Textile Manufacturing', Icons.checkroom),
  ('TRADING', 'Trading / Distribution', Icons.local_shipping),
  ('FOOD_BEVERAGE', 'Food & Beverage / Restaurant', Icons.restaurant),
  ('SERVICES', 'Professional Services', Icons.business_center),
];

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _orgNameController = TextEditingController();
  final _gstinController = TextEditingController();

  String _selectedIndustry = 'KIRANA';
  String _selectedCountry = 'IN';
  bool _isLoading = false;
  String? _errorMessage;
  int _currentStep = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _orgNameController.dispose();
    _gstinController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final phone = _phoneController.text.trim();

      // Request OTP first, then go to OTP screen with signup context
      await authRepo.requestOtp(phone);

      if (mounted) {
        context.go(Routes.otp, extra: {
          'phone': phone,
          'isSignup': true,
          'fullName': _nameController.text.trim(),
          'orgName': _orgNameController.text.trim(),
          'industry': _selectedIndustry,
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Registration failed. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: KColors.textPrimary),
          onPressed: () => context.go(Routes.login),
        ),
        title: Text(
          'Create Account',
          style: KTypography.h3.copyWith(color: KColors.textPrimary),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Step indicator
                    Row(
                      children: [
                        _StepDot(active: _currentStep >= 0, label: '1'),
                        Expanded(
                          child: Container(
                            height: 2,
                            color: _currentStep >= 1
                                ? KColors.primary
                                : KColors.divider,
                          ),
                        ),
                        _StepDot(active: _currentStep >= 1, label: '2'),
                        Expanded(
                          child: Container(
                            height: 2,
                            color: _currentStep >= 2
                                ? KColors.primary
                                : KColors.divider,
                          ),
                        ),
                        _StepDot(active: _currentStep >= 2, label: '3'),
                      ],
                    ),
                    KSpacing.vGapLg,

                    if (_errorMessage != null) ...[
                      KErrorBanner(
                        message: _errorMessage!,
                        onDismiss: () =>
                            setState(() => _errorMessage = null),
                      ),
                      KSpacing.vGapMd,
                    ],

                    // Step 0: Personal Details
                    if (_currentStep == 0) ...[
                      Text('Personal Details', style: KTypography.h2),
                      KSpacing.vGapMd,
                      KTextField(
                        label: 'Full Name',
                        controller: _nameController,
                        prefixIcon: Icons.person_outline,
                        validator: (v) =>
                            v?.trim().isEmpty == true ? 'Name is required' : null,
                      ),
                      KSpacing.vGapMd,
                      KTextField(
                        label: 'Phone Number',
                        controller: _phoneController,
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[+\d\s]')),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Phone number is required';
                          }
                          return null;
                        },
                      ),
                      KSpacing.vGapMd,
                      KTextField(
                        label: 'Email',
                        controller: _emailController,
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                    ],

                    // Step 1: Business Details
                    if (_currentStep == 1) ...[
                      Text('Business Details', style: KTypography.h2),
                      KSpacing.vGapMd,
                      KTextField(
                        label: 'Business Name',
                        controller: _orgNameController,
                        prefixIcon: Icons.business_outlined,
                        validator: (v) => v?.trim().isEmpty == true
                            ? 'Business name is required'
                            : null,
                      ),
                      KSpacing.vGapMd,
                      DropdownButtonFormField<String>(
                        value: _selectedCountry,
                        decoration: const InputDecoration(
                          labelText: 'Country',
                          prefixIcon: Icon(Icons.public),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'IN', child: Text('India')),
                          DropdownMenuItem(value: 'KE', child: Text('Kenya')),
                          DropdownMenuItem(value: 'NG', child: Text('Nigeria')),
                          DropdownMenuItem(value: 'ZA', child: Text('South Africa')),
                        ],
                        onChanged: (v) => setState(() => _selectedCountry = v!),
                      ),
                      if (_selectedCountry == 'IN') ...[
                        KSpacing.vGapMd,
                        KTextField(
                          label: 'GSTIN (Optional)',
                          controller: _gstinController,
                          hint: '22AAAAA0000A1Z5',
                          prefixIcon: Icons.receipt_long_outlined,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(15),
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Z0-9]'),
                            ),
                          ],
                        ),
                      ],
                    ],

                    // Step 2: Industry Selection
                    if (_currentStep == 2) ...[
                      Text('Select Your Industry', style: KTypography.h2),
                      KSpacing.vGapSm,
                      Text(
                        'This personalizes your dashboard and workflow',
                        style: KTypography.bodySmall,
                      ),
                      KSpacing.vGapMd,
                      ..._industries.map((industry) {
                        final isSelected =
                            _selectedIndustry == industry.$1;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () => setState(
                                () => _selectedIndustry = industry.$1),
                            borderRadius: KSpacing.borderRadiusMd,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? KColors.primary.withValues(alpha: 0.06)
                                    : KColors.surface,
                                borderRadius: KSpacing.borderRadiusMd,
                                border: Border.all(
                                  color: isSelected
                                      ? KColors.primary
                                      : KColors.divider,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    industry.$3,
                                    color: isSelected
                                        ? KColors.primary
                                        : KColors.textSecondary,
                                  ),
                                  KSpacing.hGapMd,
                                  Expanded(
                                    child: Text(
                                      industry.$2,
                                      style: KTypography.bodyLarge.copyWith(
                                        color: isSelected
                                            ? KColors.primary
                                            : KColors.textPrimary,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle,
                                      color: KColors.primary,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],

                    KSpacing.vGapXl,

                    // Navigation buttons
                    Row(
                      children: [
                        if (_currentStep > 0)
                          Expanded(
                            child: KButton(
                              label: 'Back',
                              variant: KButtonVariant.outlined,
                              onPressed: () =>
                                  setState(() => _currentStep--),
                            ),
                          ),
                        if (_currentStep > 0) KSpacing.hGapMd,
                        Expanded(
                          child: _currentStep < 2
                              ? KButton(
                                  label: 'Next',
                                  onPressed: () {
                                    if (_currentStep == 0 &&
                                        _formKey.currentState!.validate()) {
                                      setState(() => _currentStep++);
                                    } else if (_currentStep == 1) {
                                      if (_orgNameController.text
                                          .trim()
                                          .isNotEmpty) {
                                        setState(() => _currentStep++);
                                      }
                                    }
                                  },
                                  fullWidth: true,
                                )
                              : KButton(
                                  label: 'Create Account',
                                  onPressed: _handleSignup,
                                  isLoading: _isLoading,
                                  fullWidth: true,
                                  size: KButtonSize.large,
                                ),
                        ),
                      ],
                    ),
                    KSpacing.vGapLg,

                    // Login link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: KTypography.bodyMedium.copyWith(
                            color: KColors.textSecondary,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.go(Routes.login),
                          child: Text(
                            'Login',
                            style: KTypography.labelLarge.copyWith(
                              color: KColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final bool active;
  final String label;

  const _StepDot({required this.active, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: active ? KColors.primary : KColors.divider,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : KColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
