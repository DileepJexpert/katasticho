import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../data/auth_repository.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _orgNameController = TextEditingController();
  final _gstinController = TextEditingController();

  String _selectedCountry = 'IN';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;
  int _currentStep = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _orgNameController.dispose();
    _gstinController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final response = await authRepo.register(
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
        orgName: _orgNameController.text.trim(),
      );

      final data = response['data'] as Map<String, dynamic>;
      if (data['approvalStatus'] == 'PENDING') {
        if (mounted) {
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              title: const Text('Account submitted'),
              content: Text(
                data['message'] as String? ??
                    'Katixo admin approval is required before you can login.',
              ),
              actions: [
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go(Routes.login);
                  },
                  child: const Text('Back to Login'),
                ),
              ],
            ),
          );
        }
        return;
      }

      final user = data['user'] as Map<String, dynamic>;
      final onboardingCompleted = user['onboardingCompleted'] as bool? ?? false;
      final defaultLandingPage = user['defaultLandingPage'] as String?;

      await ref.read(authProvider.notifier).onLoginSuccess(
            accessToken: data['accessToken'] as String,
            refreshToken: data['refreshToken'] as String,
            userId: user['id'].toString(),
            userName: user['fullName'] as String,
            role: user['role'] as String,
            orgId: user['orgId'].toString(),
            orgName: user['orgName'] as String,
            industry: user['industry'] as String?,
            businessType: user['businessType'] as String?,
            industryCode: user['industryCode'] as String?,
            onboardingCompleted: onboardingCompleted,
            defaultLandingPage: defaultLandingPage,
          );

      if (mounted) {
        context.go(onboardingCompleted
            ? (defaultLandingPage ?? Routes.dashboard)
            : Routes.onboardingBusinessType);
      }
    } catch (e) {
      setState(() {
        _errorMessage = _friendlyError(e.toString());
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('AUTH_PHONE_EXISTS') || raw.contains('409')) {
      return 'This phone number is already registered. Please login instead.';
    }
    return 'Registration failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

                    // Step 0: Personal Details + Password
                    if (_currentStep == 0) ...[
                      Text('Your Details', style: KTypography.h2),
                      Text(
                        'Set up your login credentials',
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary),
                      ),
                      KSpacing.vGapMd,
                      KTextField(
                        label: 'Full Name',
                        controller: _nameController,
                        prefixIcon: Icons.person_outline,
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            v?.trim().isEmpty == true ? 'Name is required' : null,
                      ),
                      KSpacing.vGapMd,
                      KTextField(
                        label: 'Phone Number',
                        controller: _phoneController,
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[+\d\s]')),
                          LengthLimitingTextInputFormatter(15),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Phone number is required';
                          }
                          final digits = v.replaceAll(RegExp(r'[^\d]'), '');
                          if (digits.length < 10) {
                            return 'Enter a valid phone number';
                          }
                          return null;
                        },
                      ),
                      KSpacing.vGapMd,
                      KTextField(
                        label: 'Password',
                        controller: _passwordController,
                        prefixIcon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        suffixIcon: _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        onSuffixTap: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Password is required';
                          }
                          if (v.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          return null;
                        },
                      ),
                      KSpacing.vGapMd,
                      KTextField(
                        label: 'Confirm Password',
                        controller: _confirmPasswordController,
                        prefixIcon: Icons.lock_outline,
                        obscureText: _obscureConfirm,
                        textInputAction: TextInputAction.done,
                        suffixIcon: _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        onSuffixTap: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                        validator: (v) {
                          if (v != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ],

                    // Step 1: Business Details
                    if (_currentStep == 1) ...[
                      Text('Business Details', style: KTypography.h2),
                      Text(
                        'Tell us about your business',
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary),
                      ),
                      KSpacing.vGapMd,
                      KTextField(
                        label: 'Business Name',
                        controller: _orgNameController,
                        prefixIcon: Icons.business_outlined,
                        textInputAction: TextInputAction.next,
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
                          DropdownMenuItem(
                              value: 'NG', child: Text('Nigeria')),
                          DropdownMenuItem(
                              value: 'ZA',
                              child: Text('South Africa')),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedCountry = v!),
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
                                RegExp(r'[A-Z0-9]')),
                          ],
                        ),
                      ],
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
                          child: _currentStep < 1
                              ? KButton(
                                  label: 'Next',
                                  onPressed: () {
                                    if (_formKey.currentState!.validate()) {
                                      setState(() => _currentStep++);
                                    }
                                  },
                                  fullWidth: true,
                                )
                              : KButton(
                                  label: 'Create Account',
                                  onPressed: _handleRegister,
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
