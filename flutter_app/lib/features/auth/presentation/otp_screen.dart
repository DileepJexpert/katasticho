import 'dart:async';
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

class OtpScreen extends ConsumerStatefulWidget {
  final String phoneNumber;

  const OtpScreen({super.key, required this.phoneNumber});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  String? _errorMessage;
  int _resendTimer = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _otpCode =>
      _otpControllers.map((c) => c.text).join();

  Future<void> _handleVerify() async {
    final otp = _otpCode;
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit OTP');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final response = await authRepo.verifyOtp(widget.phoneNumber, otp);

      final data = response['data'] as Map<String, dynamic>;

      await ref.read(authProvider.notifier).onLoginSuccess(
            accessToken: data['accessToken'] as String,
            refreshToken: data['refreshToken'] as String,
            userId: data['userId'] as String,
            userName: data['fullName'] as String,
            role: data['role'] as String,
            orgId: data['orgId'] as String,
            orgName: data['orgName'] as String,
            industry: data['industry'] as String?,
          );

      if (mounted) {
        context.go(Routes.dashboard);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Invalid OTP. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResend() async {
    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.login(widget.phoneNumber);
      _startResendTimer();
    } catch (_) {
      setState(() => _errorMessage = 'Failed to resend OTP.');
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
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: KColors.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      size: 40,
                      color: KColors.primary,
                    ),
                  ),
                  KSpacing.vGapLg,

                  Text(
                    'Verify OTP',
                    style: KTypography.h1,
                    textAlign: TextAlign.center,
                  ),
                  KSpacing.vGapSm,
                  Text(
                    'Enter the 6-digit code sent to\n${widget.phoneNumber}',
                    style: KTypography.bodyMedium.copyWith(
                      color: KColors.textSecondary,
                    ),
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

                  // OTP input boxes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) {
                      return Container(
                        width: 48,
                        height: 56,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: TextField(
                          controller: _otpControllers[index],
                          focusNode: _focusNodes[index],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: KTypography.h2,
                          decoration: InputDecoration(
                            counterText: '',
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                              borderRadius: KSpacing.borderRadiusMd,
                            ),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (value) {
                            if (value.isNotEmpty && index < 5) {
                              _focusNodes[index + 1].requestFocus();
                            }
                            if (value.isEmpty && index > 0) {
                              _focusNodes[index - 1].requestFocus();
                            }
                            // Auto-submit when all 6 digits entered
                            if (_otpCode.length == 6) {
                              _handleVerify();
                            }
                          },
                        ),
                      );
                    }),
                  ),
                  KSpacing.vGapXl,

                  // Verify button
                  KButton(
                    label: 'Verify',
                    onPressed: _handleVerify,
                    isLoading: _isLoading,
                    fullWidth: true,
                    size: KButtonSize.large,
                  ),
                  KSpacing.vGapLg,

                  // Resend
                  _resendTimer > 0
                      ? Text(
                          'Resend OTP in ${_resendTimer}s',
                          style: KTypography.bodySmall,
                        )
                      : TextButton(
                          onPressed: _handleResend,
                          child: const Text('Resend OTP'),
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
