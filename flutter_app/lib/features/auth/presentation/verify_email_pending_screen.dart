import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../routing/app_router.dart';
import '../data/auth_repository.dart';

class VerifyEmailPendingScreen extends ConsumerStatefulWidget {
  final String email;

  const VerifyEmailPendingScreen({super.key, required this.email});

  @override
  ConsumerState<VerifyEmailPendingScreen> createState() =>
      _VerifyEmailPendingScreenState();
}

class _VerifyEmailPendingScreenState
    extends ConsumerState<VerifyEmailPendingScreen> {
  int _countdown = 60;
  Timer? _timer;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _countdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _countdown--;
        if (_countdown <= 0) timer.cancel();
      });
    });
  }

  Future<void> _handleResend() async {
    setState(() => _isResending = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .resendVerificationEmail(widget.email);
      if (mounted) {
        _startCountdown();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Email resent!'),
            backgroundColor: KColors.success,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to resend. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.email_outlined,
                    size: 64,
                    color: KColors.primary,
                  ),
                  KSpacing.vGapLg,
                  Text(
                    'Check your email',
                    style: KTypography.h1,
                    textAlign: TextAlign.center,
                  ),
                  KSpacing.vGapMd,
                  Text(
                    "We've sent a verification link to ${widget.email}.\nThe link expires in 24 hours.",
                    style: KTypography.bodyMedium
                        .copyWith(color: KColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  KSpacing.vGapXl,
                  if (_countdown > 0)
                    Text(
                      'Resend in ${_countdown}s',
                      style: KTypography.bodyMedium
                          .copyWith(color: KColors.textHint),
                    )
                  else
                    TextButton(
                      onPressed: _isResending ? null : _handleResend,
                      child: _isResending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'Resend Email',
                              style: KTypography.labelMedium
                                  .copyWith(color: KColors.primary),
                            ),
                    ),
                  KSpacing.vGapLg,
                  TextButton(
                    onPressed: () => context.go(Routes.login),
                    child: Text(
                      'Back to Login',
                      style: KTypography.labelMedium
                          .copyWith(color: KColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
