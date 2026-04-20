import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../data/onboarding_state.dart';

class SubCategoryScreen extends ConsumerWidget {
  const SubCategoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(onboardingProvider);
    final industryCode = onboarding.industryCode;
    final selected = onboarding.subCategories;
    final subCats = kSubCategoriesByIndustry[industryCode] ?? [];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: KColors.textPrimary),
          onPressed: () => context.go(Routes.onboardingIndustry),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: KSpacing.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What do you\nprimarily sell?', style: KTypography.h1),
              KSpacing.vGapSm,
              Text(
                'Select all that apply. We\'ll enable matching features.',
                style: KTypography.bodyMedium.copyWith(color: KColors.textSecondary),
              ),
              KSpacing.vGapLg,
              if (subCats.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      'No sub-categories for this industry.',
                      style: KTypography.bodyMedium.copyWith(color: KColors.textSecondary),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: subCats.length,
                    itemBuilder: (context, i) {
                      final cat = subCats[i];
                      final code = cat['code']!;
                      final isChecked = selected.contains(code);
                      return CheckboxListTile(
                        value: isChecked,
                        title: Text(cat['label']!, style: KTypography.bodyMedium),
                        activeColor: KColors.primary,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        onChanged: (_) => ref
                            .read(onboardingProvider.notifier)
                            .toggleSubCategory(code),
                      );
                    },
                  ),
                ),
              KSpacing.vGapLg,
              KButton(
                label: 'Continue',
                fullWidth: true,
                size: KButtonSize.large,
                onPressed: () => context.go(Routes.onboardingDetails),
              ),
              KSpacing.vGapSm,
              TextButton(
                onPressed: () => context.go(Routes.onboardingDetails),
                child: Center(
                  child: Text(
                    'Skip this step',
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
