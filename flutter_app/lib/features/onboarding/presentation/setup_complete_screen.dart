import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../data/organisation_repository.dart';

class SetupCompleteScreen extends ConsumerStatefulWidget {
  const SetupCompleteScreen({super.key});

  @override
  ConsumerState<SetupCompleteScreen> createState() =>
      _SetupCompleteScreenState();
}

class _SetupCompleteScreenState extends ConsumerState<SetupCompleteScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _animController.forward();
    _markComplete();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _markComplete() async {
    setState(() => _completing = true);
    try {
      final orgId = ref.read(authProvider).orgId;
      if (orgId != null) {
        await ref.read(organisationRepositoryProvider).completeOnboarding(orgId);
      }
      ref.read(authProvider.notifier).markOnboardingComplete();
    } catch (e) {
      debugPrint('[SetupComplete] markComplete failed: $e');
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: KSpacing.pagePadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: KColors.success.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    size: 60,
                    color: KColors.success,
                  ),
                ),
              ),
              KSpacing.vGapXl,
              Text(
                "You're all set!",
                style: KTypography.h1,
                textAlign: TextAlign.center,
              ),
              KSpacing.vGapSm,
              Text(
                'Your business has been configured.\nStart managing your inventory, invoices, and more.',
                style: KTypography.bodyMedium.copyWith(color: KColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              KSpacing.vGapXl,
              KSpacing.vGapXl,
              KButton(
                label: 'Go to Dashboard',
                fullWidth: true,
                size: KButtonSize.large,
                isLoading: _completing,
                onPressed: _completing ? null : () => context.go(Routes.dashboard),
              ),
              KSpacing.vGapMd,
            ],
          ),
        ),
      ),
    );
  }
}
