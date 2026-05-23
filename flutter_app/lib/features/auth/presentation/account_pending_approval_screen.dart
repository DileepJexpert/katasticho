import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/theme/k_colors.dart';
import '../../../routing/app_router.dart';

class AccountPendingApprovalScreen extends StatelessWidget {
  const AccountPendingApprovalScreen({super.key});

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
                    Icons.hourglass_top_rounded,
                    size: 64,
                    color: KColors.warning,
                  ),
                  KSpacing.vGapLg,
                  Text(
                    'Account Under Review',
                    style: KTypography.h1,
                    textAlign: TextAlign.center,
                  ),
                  KSpacing.vGapMd,
                  Text(
                    "Thank you for signing up!\nYour account is being reviewed.\nWe'll notify you by email within 24 hours.",
                    style: KTypography.bodyMedium
                        .copyWith(color: KColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  KSpacing.vGapXl,
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
