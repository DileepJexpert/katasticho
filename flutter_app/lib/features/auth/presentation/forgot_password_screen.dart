import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../data/auth_repository.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();

  bool _isLoading = false;
  bool _successShown = false;
  String? _errorMessage;

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  Future<void> _handleSendResetLink() async {
    if (_successShown) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final identifier = _identifierController.text.trim();
      final isEmail = identifier.contains('@');
      await ref.read(authRepositoryProvider).forgotPasswordEmail(
            email: isEmail ? identifier : null,
            phone: isEmail ? null : identifier,
          );
      if (mounted) {
        setState(() => _successShown = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "If an account exists, you'll receive reset instructions shortly.",
            ),
            backgroundColor: KColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to send reset instructions. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.login),
        ),
      ),
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
                      'Forgot Password',
                      style: KTypography.h1,
                      textAlign: TextAlign.center,
                    ),
                    KSpacing.vGapSm,
                    Text(
                      'Enter your email or phone to receive reset instructions',
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

                    KTextField(
                      label: 'Email or Phone',
                      hint: 'name@example.com or +91 98765 43210',
                      controller: _identifierController,
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Email or phone is required';
                        }
                        return null;
                      },
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleSendResetLink(),
                    ),
                    KSpacing.vGapLg,

                    KButton(
                      label: _successShown
                          ? 'Instructions Sent'
                          : 'Send Reset Link',
                      onPressed:
                          _successShown ? null : _handleSendResetLink,
                      isLoading: _isLoading,
                      fullWidth: true,
                      size: KButtonSize.large,
                    ),
                    KSpacing.vGapLg,

                    Center(
                      child: TextButton(
                        onPressed: () => context.go(Routes.login),
                        child: Text(
                          'Back to Login',
                          style: KTypography.labelMedium
                              .copyWith(color: KColors.primary),
                        ),
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
