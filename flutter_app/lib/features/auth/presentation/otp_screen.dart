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
  final bool isSignup;
  final String? fullName;
  final String? orgName;
  final String? industry;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
    this.isSignup = false,
    this.fullName,
    this.orgName,
    this.industry,
  });

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
    debugPrint('[OtpScreen] _handleVerify called, otp length: ${otp.length}, isSignup: ${widget.isSignup}');
    if (otp.length != 6) {
      debugPrint('[OtpScreen] OTP incomplete, showing error');
      setState(() => _errorMessage = 'Please enter the 6-digit OTP');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final Map<String, dynamic> response;

      if (widget.isSignup) {
        // Signup flow: send OTP + user details together
        debugPrint('[OtpScreen] Calling signup API with phone: ${widget.phoneNumber}, fullName: ${widget.fullName}, orgName: ${widget.orgName}, industry: ${widget.industry}');
        response = await authRepo.signup(
          phone: widget.phoneNumber,
          otp: otp,
          fullName: widget.fullName!,
          orgName: widget.orgName!,
          industry: widget.industry,
        );
      } else {
        // Login flow: verify OTP only
        debugPrint('[OtpScreen] Calling verifyOtp API with phone: ${widget.phoneNumber}');
        response = await authRepo.verifyOtp(widget.phoneNumber, otp);
      }

      debugPrint('[OtpScreen] Raw response: $response');

      final data = response['data'] as Map<String, dynamic>;
      debugPrint('[OtpScreen] Parsed data: $data');

      final user = data['user'] as Map<String, dynamic>;
      debugPrint('[OtpScreen] Parsed user: $user');

      debugPrint('[OtpScreen] Extracted values -> userId: ${user['id']}, userName: ${user['fullName']}, role: ${user['role']}, orgId: ${user['orgId']}, orgName: ${user['orgName']}, industry: ${user['industry']}');

      await ref.read(authProvider.notifier).onLoginSuccess(
            accessToken: data['accessToken'] as String,
            refreshToken: data['refreshToken'] as String,
            userId: user['id'].toString(),
            userName: user['fullName'] as String,
            role: user['role'] as String,
            orgId: user['orgId'].toString(),
            orgName: user['orgName'] as String,
            industry: user['industry'] as String?,
          );

      debugPrint('[OtpScreen] onLoginSuccess completed, navigating to dashboard');

      if (mounted) {
        context.go(Routes.dashboard);
      }
    } catch (e, st) {
      debugPrint('[OtpScreen] Verify/Signup FAILED: $e');
      debugPrint('[OtpScreen] Stack trace: $st');
      setState(() {
        _errorMessage = widget.isSignup
            ? 'Signup failed. Please try again.'
            : 'Invalid OTP. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResend() async {
    debugPrint('[OtpScreen] _handleResend called for phone: ${widget.phoneNumber}');
    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.requestOtp(widget.phoneNumber);
      debugPrint('[OtpScreen] Resend OTP success');
      _startResendTimer();
    } catch (e, st) {
      debugPrint('[OtpScreen] Resend OTP FAILED: $e');
      debugPrint('[OtpScreen] Stack trace: $st');
      setState(() => _errorMessage = 'Failed to resend OTP.');
    }
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
                    label: widget.isSignup ? 'Create Account' : 'Verify',
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
