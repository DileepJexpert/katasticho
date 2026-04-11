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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.requestOtp(_phoneController.text.trim());

      if (mounted) {
        context.go(Routes.otp, extra: _phoneController.text.trim());
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to send OTP. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: KColors.primary,
                          borderRadius: KSpacing.borderRadiusLg,
                        ),
                        child: const Center(
                          child: Text(
                            'K',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    KSpacing.vGapLg,

                    // Title
                    Text(
                      'Welcome to Katasticho',
                      style: KTypography.h1,
                      textAlign: TextAlign.center,
                    ),
                    KSpacing.vGapSm,
                    Text(
                      'Enter your phone number to get started',
                      style: KTypography.bodyMedium.copyWith(
                        color: KColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    KSpacing.vGapXl,

                    // Error banner
                    if (_errorMessage != null) ...[
                      KErrorBanner(
                        message: _errorMessage!,
                        onDismiss: () =>
                            setState(() => _errorMessage = null),
                      ),
                      KSpacing.vGapMd,
                    ],

                    // Phone input
                    KTextField(
                      label: 'Phone Number',
                      hint: '+91 98765 43210',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone_outlined,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[+\d\s]'),
                        ),
                        LengthLimitingTextInputFormatter(15),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Phone number is required';
                        }
                        final digits =
                            value.replaceAll(RegExp(r'[^\d]'), '');
                        if (digits.length < 10) {
                          return 'Enter a valid phone number';
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.done,
                    ),
                    KSpacing.vGapLg,

                    // Login button
                    KButton(
                      label: 'Send OTP',
                      onPressed: _handleLogin,
                      isLoading: _isLoading,
                      fullWidth: true,
                      size: KButtonSize.large,
                    ),
                    KSpacing.vGapMd,

                    // Signup link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: KTypography.bodyMedium.copyWith(
                            color: KColors.textSecondary,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.go(Routes.signup),
                          child: Text(
                            'Sign Up',
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
