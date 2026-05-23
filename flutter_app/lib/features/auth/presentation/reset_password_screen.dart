import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../data/auth_repository.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String token;

  const ResetPasswordScreen({super.key, required this.token});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _tokenExpired = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ── Password strength checks ──

  bool get _hasMinLength => _passwordController.text.length >= 8;
  bool get _hasUppercase =>
      _passwordController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLowercase =>
      _passwordController.text.contains(RegExp(r'[a-z]'));
  bool get _hasDigit => _passwordController.text.contains(RegExp(r'[0-9]'));
  bool get _hasSpecialChar =>
      _passwordController.text.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

  int get _metCount => [
        _hasMinLength,
        _hasUppercase,
        _hasLowercase,
        _hasDigit,
        _hasSpecialChar,
      ].where((v) => v).length;

  bool get _allMet => _metCount == 5;

  bool get _passwordsMatch =>
      _passwordController.text.isNotEmpty &&
      _passwordController.text == _confirmController.text;

  Color get _strengthColor {
    if (_allMet) return KColors.success;
    if (_metCount >= 3) return KColors.warning;
    return KColors.error;
  }

  Future<void> _handleSetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_allMet || !_passwordsMatch) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authRepositoryProvider).resetPasswordWithToken(
            token: widget.token,
            newPassword: _passwordController.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Password set successfully!'),
            backgroundColor: KColors.success,
          ),
        );
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) context.go(Routes.login);
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('expired') || msg.contains('invalid')) {
        setState(() => _tokenExpired = true);
      }
      setState(() {
        _errorMessage = _tokenExpired
            ? 'This reset link has expired. Please request a new one.'
            : 'Failed to set password. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                    Text(
                      'Set New Password',
                      style: KTypography.h1,
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

                    if (_tokenExpired) ...[
                      Center(
                        child: KButton(
                          label: 'Request New Link',
                          onPressed: () => context.go(Routes.forgotPassword),
                          variant: KButtonVariant.outlined,
                        ),
                      ),
                    ] else ...[
                      KTextField(
                        label: 'New Password',
                        controller: _passwordController,
                        prefixIcon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        suffixIcon: _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        onSuffixTap: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Password is required';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      ),
                      KSpacing.vGapSm,

                      // Password strength indicators
                      _PasswordStrengthRow(
                        checks: [
                          _StrengthCheck('8+ chars', _hasMinLength),
                          _StrengthCheck('uppercase', _hasUppercase),
                          _StrengthCheck('number', _hasDigit),
                          _StrengthCheck('special char', _hasSpecialChar),
                        ],
                        color: _strengthColor,
                      ),
                      KSpacing.vGapMd,

                      KTextField(
                        label: 'Confirm Password',
                        controller: _confirmController,
                        prefixIcon: Icons.lock_outline,
                        obscureText: _obscureConfirm,
                        suffixIcon: _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        onSuffixTap: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (v != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleSetPassword(),
                      ),
                      KSpacing.vGapLg,

                      KButton(
                        label: 'Set Password',
                        onPressed: (_allMet && _passwordsMatch)
                            ? _handleSetPassword
                            : null,
                        isLoading: _isLoading,
                        fullWidth: true,
                        size: KButtonSize.large,
                      ),
                    ],
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

class _StrengthCheck {
  final String label;
  final bool met;
  const _StrengthCheck(this.label, this.met);
}

class _PasswordStrengthRow extends StatelessWidget {
  final List<_StrengthCheck> checks;
  final Color color;

  const _PasswordStrengthRow({
    required this.checks,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: checks.map((check) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              check.met ? Icons.check_circle : Icons.circle_outlined,
              size: 14,
              color: check.met ? color : KColors.textHint,
            ),
            const SizedBox(width: 4),
            Text(
              check.label,
              style: KTypography.labelSmall.copyWith(
                color: check.met ? color : KColors.textHint,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
