import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../data/platform_admin_auth_state.dart';
import '../data/platform_admin_repository.dart';

class PlatformAdminLoginScreen extends ConsumerStatefulWidget {
  const PlatformAdminLoginScreen({super.key});

  @override
  ConsumerState<PlatformAdminLoginScreen> createState() =>
      _PlatformAdminLoginScreenState();
}

class _PlatformAdminLoginScreenState
    extends ConsumerState<PlatformAdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(platformAdminRepositoryProvider);
      final response = await repo.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      final data = response['data'] as Map<String, dynamic>? ?? response;
      final token = data['accessToken'] as String;

      await ref.read(platformAdminTokenProvider.notifier).setToken(token);

      if (mounted) {
        context.go(Routes.platformAdminDashboard);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Invalid email or password.';
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
                      'Katixo Platform Admin',
                      style: KTypography.h1,
                      textAlign: TextAlign.center,
                    ),
                    KSpacing.vGapSm,
                    Text(
                      'Separate control plane for approvals, plans, users, and tenant operations',
                      style: KTypography.bodyMedium
                          .copyWith(color: KColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    KSpacing.vGapSm,
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: KColors.draftBg,
                        borderRadius: KSpacing.borderRadiusMd,
                        border: Border.all(color: KColors.divider),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.alternate_email, size: 18, color: KColors.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Platform admin uses email + password only. Tenant phone login does not work here.',
                              style: KTypography.bodySmall
                                  .copyWith(color: KColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
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
                      label: 'Email',
                      hint: 'admin@katixo.com',
                      controller: _emailController,
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Email is required';
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
                      onFieldSubmitted: (_) => _handleLogin(),
                    ),
                    KSpacing.vGapLg,

                    KButton(
                      label: 'Sign In',
                      onPressed: _handleLogin,
                      isLoading: _isLoading,
                      fullWidth: true,
                      size: KButtonSize.large,
                    ),
                    KSpacing.vGapMd,
                    Center(
                      child: TextButton(
                        onPressed: () => context.go(Routes.login),
                        child: const Text('Back to tenant login'),
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
