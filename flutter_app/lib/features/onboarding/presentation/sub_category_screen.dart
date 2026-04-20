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
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: subCats.map((cat) {
                        final code = cat['code']!;
                        final label = cat['label']!;
                        final isChecked = selected.contains(code);
                        return _SubCategoryChip(
                          label: label,
                          selected: isChecked,
                          onTap: () => ref
                              .read(onboardingProvider.notifier)
                              .toggleSubCategory(code),
                        );
                      }).toList(),
                    ),
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

class _SubCategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SubCategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? KColors.primary.withValues(alpha: 0.08)
                : Theme.of(context).cardColor,
            border: Border.all(
              color: selected ? KColors.primary : KColors.divider,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(Icons.check_rounded,
                    size: 16, color: KColors.primary),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: KTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: selected ? KColors.primary : KColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
