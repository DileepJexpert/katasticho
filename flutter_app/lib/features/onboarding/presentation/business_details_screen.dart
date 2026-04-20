import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../data/onboarding_state.dart';
import '../data/organisation_repository.dart';

class BusinessDetailsScreen extends ConsumerStatefulWidget {
  const BusinessDetailsScreen({super.key});

  @override
  ConsumerState<BusinessDetailsScreen> createState() =>
      _BusinessDetailsScreenState();
}

class _BusinessDetailsScreenState extends ConsumerState<BusinessDetailsScreen> {
  final _gstinController = TextEditingController();
  final _stateController = TextEditingController();
  final _stateCodeController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _gstinController.dispose();
    _stateController.dispose();
    _stateCodeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _skipAndSaveIndustry() async {
    setState(() => _saving = true);
    try {
      final onboarding = ref.read(onboardingProvider);
      final orgId = ref.read(authProvider).orgId;
      if (orgId != null) {
        await ref.read(organisationRepositoryProvider).updateIndustry(
              orgId: orgId,
              businessType: onboarding.businessType,
              industryCode: onboarding.industryCode,
              subCategories: onboarding.subCategories,
            );
      }
    } catch (_) {
      // ignore — proceed to complete regardless
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        context.go(Routes.onboardingComplete);
      }
    }
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final onboarding = ref.read(onboardingProvider);
      final orgId = ref.read(authProvider).orgId;
      if (orgId == null) throw Exception('No org ID in session');

      ref.read(onboardingProvider.notifier).setDetails(
            gstin: _gstinController.text.trim(),
            stateName: _stateController.text.trim(),
            stateCode: _stateCodeController.text.trim(),
            phone: _phoneController.text.trim(),
          );

      await ref.read(organisationRepositoryProvider).updateIndustry(
            orgId: orgId,
            businessType: onboarding.businessType,
            industryCode: onboarding.industryCode,
            subCategories: onboarding.subCategories,
            gstin: _gstinController.text.trim(),
            state: _stateController.text.trim(),
            stateCode: _stateCodeController.text.trim(),
            phone: _phoneController.text.trim(),
          );

      if (mounted) context.go(Routes.onboardingComplete);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
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
          onPressed: () => context.go(Routes.onboardingSubCategory),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: KSpacing.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Business details', style: KTypography.h1),
              KSpacing.vGapSm,
              Text(
                'Optional — you can update these later in Settings.',
                style: KTypography.bodyMedium.copyWith(color: KColors.textSecondary),
              ),
              KSpacing.vGapXl,
              if (_error != null) ...[
                KErrorBanner(
                  message: _error!,
                  onDismiss: () => setState(() => _error = null),
                ),
                KSpacing.vGapMd,
              ],
              KTextField(
                label: 'GSTIN',
                controller: _gstinController,
                hint: 'e.g. 27AABCU9603R1ZX',
                prefixIcon: Icons.receipt_long_outlined,
              ),
              KSpacing.vGapMd,
              KTextField(
                label: 'State',
                controller: _stateController,
                hint: 'e.g. Maharashtra',
                prefixIcon: Icons.location_on_outlined,
              ),
              KSpacing.vGapMd,
              KTextField(
                label: 'State Code',
                controller: _stateCodeController,
                hint: 'e.g. 27',
                prefixIcon: Icons.tag,
              ),
              KSpacing.vGapMd,
              KTextField(
                label: 'Business Phone',
                controller: _phoneController,
                hint: 'e.g. 9876543210',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              KSpacing.vGapXl,
              KButton(
                label: 'Save & Continue',
                fullWidth: true,
                size: KButtonSize.large,
                isLoading: _saving,
                onPressed: _submit,
              ),
              KSpacing.vGapSm,
              TextButton(
                onPressed: _saving ? null : _skipAndSaveIndustry,
                child: Center(
                  child: Text(
                    'Skip for now',
                    style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                  ),
                ),
              ),
              KSpacing.vGapMd,
            ],
          ),
        ),
      ),
    );
  }
}
