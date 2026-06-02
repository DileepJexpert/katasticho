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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneOtpController = TextEditingController();

  bool _useOtp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _phoneOtpController.dispose();
    super.dispose();
  }

  Future<void> _handlePasswordLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final response = await authRepo.loginWithPassword(
        identifier: _identifierController.text.trim(),
        password: _passwordController.text,
      );
      final data = response['data'] as Map<String, dynamic>;
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

      // Auth state change refreshes the router. Keep navigation centralized
      // so login and onboarding redirects cannot race each other.
    } catch (e) {
      setState(() {
        _errorMessage = _friendlyError(e.toString());
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleOtpRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final phone = _phoneOtpController.text.trim();
      await ref.read(authRepositoryProvider).requestOtp(phone);
      if (mounted) context.go(Routes.otp, extra: phone);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to send OTP. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final phoneController = TextEditingController(text: _identifierController.text.trim());
    final otpController = TextEditingController();
    final newPasswordController = TextEditingController();
    bool otpSent = false;
    bool loading = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> sendOtp() async {
              final phone = phoneController.text.trim();
              if (phone.isEmpty) {
                setDialogState(() => error = 'Phone number is required');
                return;
              }
              setDialogState(() {
                loading = true;
                error = null;
              });
              try {
                await ref.read(authRepositoryProvider).forgotPassword(phone: phone);
                setDialogState(() => otpSent = true);
              } catch (_) {
                setDialogState(() => error = 'Could not send reset OTP.');
              } finally {
                setDialogState(() => loading = false);
              }
            }

            Future<void> reset() async {
              if (otpController.text.trim().length < 4 ||
                  newPasswordController.text.length < 8) {
                setDialogState(() => error =
                    'Enter the OTP and a new password with at least 8 characters.');
                return;
              }
              setDialogState(() {
                loading = true;
                error = null;
              });
              try {
                await ref.read(authRepositoryProvider).resetPassword(
                      phone: phoneController.text.trim(),
                      otp: otpController.text.trim(),
                      newPassword: newPasswordController.text,
                    );
                if (mounted && dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Password reset successfully.')),
                  );
                }
              } catch (_) {
                if (dialogContext.mounted) {
                  setDialogState(() => error = 'Reset failed. Check OTP and try again.');
                }
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() => loading = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('Reset password'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    KTextField(
                      label: 'Phone Number',
                      controller: phoneController,
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    if (otpSent) ...[
                      KSpacing.vGapMd,
                      KTextField(
                        label: 'OTP',
                        controller: otpController,
                        prefixIcon: Icons.password_outlined,
                        keyboardType: TextInputType.number,
                      ),
                      KSpacing.vGapMd,
                      KTextField(
                        label: 'New Password',
                        controller: newPasswordController,
                        prefixIcon: Icons.lock_outline,
                        obscureText: true,
                      ),
                    ],
                    if (error != null) ...[
                      KSpacing.vGapMd,
                      Text(error!, style: const TextStyle(color: KColors.error)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: loading ? null : (otpSent ? reset : sendOtp),
                  child: Text(otpSent ? 'Reset Password' : 'Send OTP'),
                ),
              ],
            );
          },
        );
      },
    );

    phoneController.dispose();
    otpController.dispose();
    newPasswordController.dispose();
  }

  String _friendlyError(String raw) {
    if (raw.contains('AUTH_BAD_CREDENTIALS') || raw.contains('401')) {
      return 'Incorrect phone number or password.';
    }
    if (raw.contains('AUTH_ACCOUNT_LOCKED') || raw.contains('429')) {
      return 'Account locked after too many attempts. Try again in 30 minutes.';
    }
    if (raw.contains('AUTH_ORG_PENDING_APPROVAL')) {
      return 'Your account is waiting for Katixo admin approval.';
    }
    if (raw.contains('AUTH_ACCOUNT_INACTIVE') || raw.contains('403')) {
      return 'Your account has been deactivated. Contact your administrator.';
    }
    return 'Login failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

                    Text(
                      'Welcome to Katixo',
                      style: KTypography.h1,
                      textAlign: TextAlign.center,
                    ),
                    KSpacing.vGapSm,
                    Text(
                      _useOtp
                          ? 'Enter your phone number to get OTP'
                          : 'Sign in with your phone and password',
                      style: KTypography.bodyMedium
                          .copyWith(color: KColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    KSpacing.vGapXl,

                    if (_errorMessage != null) ...[
                      KErrorBanner(
                        message: _errorMessage!,
                        onDismiss: () =>
                            setState(() => _errorMessage = null),
                      ),
                      KSpacing.vGapMd,
                    ],

                    if (_useOtp) ...[
                      // OTP mode
                      KTextField(
                        label: 'Phone Number',
                        hint: '+91 98765 43210',
                        controller: _phoneOtpController,
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_outlined,
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
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleOtpRequest(),
                      ),
                      KSpacing.vGapLg,
                      KButton(
                        label: 'Send OTP',
                        onPressed: _handleOtpRequest,
                        isLoading: _isLoading,
                        fullWidth: true,
                        size: KButtonSize.large,
                      ),
                    ] else ...[
                      // Password mode
                      KTextField(
                        label: 'Phone Number',
                        hint: '+91 98765 43210',
                        controller: _identifierController,
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_outlined,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[+\d\s]')),
                          LengthLimitingTextInputFormatter(15),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Phone number is required';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      ),
                      KSpacing.vGapMd,
                      KTextField(
                        label: 'Password',
                        controller: _passwordController,
                        prefixIcon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        suffixIcon: _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        onSuffixTap: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Password is required';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handlePasswordLogin(),
                      ),
                      KSpacing.vGapLg,
                      KButton(
                        label: 'Login',
                        onPressed: _handlePasswordLogin,
                        isLoading: _isLoading,
                        fullWidth: true,
                        size: KButtonSize.large,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading ? null : _showForgotPasswordDialog,
                          child: const Text('Forgot password?'),
                        ),
                      ),
                    ],

                    KSpacing.vGapMd,

                    // Toggle OTP / Password
                    Center(
                      child: TextButton(
                        onPressed: () => setState(() {
                          _useOtp = !_useOtp;
                          _errorMessage = null;
                        }),
                        child: Text(
                          _useOtp
                              ? 'Login with password instead'
                              : 'Login with OTP instead',
                          style: KTypography.labelMedium
                              .copyWith(color: KColors.primary),
                        ),
                      ),
                    ),

                    KSpacing.vGapSm,

                    // Signup link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: KTypography.bodyMedium
                              .copyWith(color: KColors.textSecondary),
                        ),
                        GestureDetector(
                          onTap: () => context.go(Routes.signup),
                          child: Text(
                            'Sign Up',
                            style: KTypography.labelLarge
                                .copyWith(color: KColors.primary),
                          ),
                        ),
                      ],
                    ),
                    KSpacing.vGapLg,
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: KColors.draftBg,
                        borderRadius: KSpacing.borderRadiusMd,
                        border: Border.all(color: KColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Platform administration',
                            style: KTypography.labelLarge,
                            textAlign: TextAlign.center,
                          ),
                          KSpacing.vGapXs,
                          Text(
                            'Use the separate admin portal for approvals, plan control, and tenant operations.',
                            style: KTypography.bodySmall
                                .copyWith(color: KColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                          KSpacing.vGapMd,
                          OutlinedButton.icon(
                            onPressed: () => context.go(Routes.platformAdminLogin),
                            icon: const Icon(Icons.admin_panel_settings_outlined),
                            label: const Text('Open Platform Admin Portal'),
                          ),
                        ],
                      ),
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
