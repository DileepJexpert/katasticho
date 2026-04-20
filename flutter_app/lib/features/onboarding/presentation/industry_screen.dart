import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../data/onboarding_state.dart';

class IndustryScreen extends ConsumerWidget {
  const IndustryScreen({super.key});

  static const _industries = [
    {'code': 'PHARMACY', 'label': 'Pharmacy', 'icon': Icons.local_pharmacy_rounded},
    {'code': 'GROCERY', 'label': 'Grocery', 'icon': Icons.shopping_basket_rounded},
    {'code': 'ELECTRONICS', 'label': 'Electronics', 'icon': Icons.devices_rounded},
    {'code': 'HARDWARE', 'label': 'Hardware', 'icon': Icons.build_rounded},
    {'code': 'GARMENTS', 'label': 'Garments', 'icon': Icons.checkroom_rounded},
    {'code': 'FOOD_RESTAURANT', 'label': 'Food', 'icon': Icons.restaurant_rounded},
    {'code': 'AUTO_PARTS', 'label': 'Auto Parts', 'icon': Icons.directions_car_rounded},
    {'code': 'SERVICE', 'label': 'Services', 'icon': Icons.handyman_rounded},
    {'code': 'OTHER_RETAIL', 'label': 'General', 'icon': Icons.storefront_rounded},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingProvider).industryCode;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: KColors.textPrimary),
          onPressed: () => context.go(Routes.onboardingBusinessType),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: KSpacing.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What industry are\nyou in?', style: KTypography.h1),
              KSpacing.vGapSm,
              Text(
                'We\'ll enable the right features for your business.',
                style: KTypography.bodyMedium.copyWith(color: KColors.textSecondary),
              ),
              KSpacing.vGapLg,
              Expanded(
                child: GridView.count(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.0,
                  children: _industries.map((ind) {
                    final isSelected = selected == ind['code'];
                    return _IndustryCard(
                      label: ind['label'] as String,
                      icon: ind['icon'] as IconData,
                      selected: isSelected,
                      onTap: () => ref
                          .read(onboardingProvider.notifier)
                          .setIndustry(ind['code'] as String, ind['label'] as String),
                    );
                  }).toList(),
                ),
              ),
              KSpacing.vGapLg,
              KButton(
                label: 'Continue',
                fullWidth: true,
                size: KButtonSize.large,
                onPressed: () => context.go(Routes.onboardingSubCategory),
              ),
              KSpacing.vGapMd,
            ],
          ),
        ),
      ),
    );
  }
}

class _IndustryCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _IndustryCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: KSpacing.borderRadiusLg,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: selected
                ? KColors.primary.withValues(alpha: 0.06)
                : Theme.of(context).cardColor,
            border: Border.all(
              color: selected ? KColors.primary : KColors.divider,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: KSpacing.borderRadiusLg,
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? KColors.primary.withValues(alpha: 0.12)
                      : KColors.divider.withValues(alpha: 0.4),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: selected ? KColors.primary : KColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: KTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: selected ? KColors.primary : KColors.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
