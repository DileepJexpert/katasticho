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
    {'code': 'PHARMACY', 'label': 'Pharmacy', 'subtitle': 'Medicines, drugs, healthcare', 'icon': Icons.local_pharmacy_rounded},
    {'code': 'GROCERY', 'label': 'Grocery', 'subtitle': 'Food, kirana, supermarket', 'icon': Icons.shopping_basket_rounded},
    {'code': 'ELECTRONICS', 'label': 'Electronics', 'subtitle': 'Devices, appliances, mobile', 'icon': Icons.devices_rounded},
    {'code': 'HARDWARE', 'label': 'Hardware', 'subtitle': 'Tools, paint, plumbing', 'icon': Icons.build_rounded},
    {'code': 'GARMENTS', 'label': 'Garments', 'subtitle': 'Clothing, fabric, footwear', 'icon': Icons.checkroom_rounded},
    {'code': 'FOOD_RESTAURANT', 'label': 'Food & Restaurant', 'subtitle': 'Bakery, catering, cafe', 'icon': Icons.restaurant_rounded},
    {'code': 'AUTO_PARTS', 'label': 'Auto Parts', 'subtitle': 'Vehicle parts & accessories', 'icon': Icons.directions_car_rounded},
    {'code': 'SERVICE', 'label': 'Services', 'subtitle': 'Repairs, consulting, rentals', 'icon': Icons.handyman_rounded},
    {'code': 'OTHER_RETAIL', 'label': 'General Retail', 'subtitle': 'Something else', 'icon': Icons.storefront_rounded},
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
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: _industries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final ind = _industries[i];
                    final isSelected = selected == ind['code'];
                    return _IndustryRow(
                      label: ind['label'] as String,
                      subtitle: ind['subtitle'] as String,
                      icon: ind['icon'] as IconData,
                      selected: isSelected,
                      onTap: () => ref
                          .read(onboardingProvider.notifier)
                          .setIndustry(ind['code'] as String, ind['label'] as String),
                    );
                  },
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

class _IndustryRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _IndustryRow({
    required this.label,
    required this.subtitle,
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected
                      ? KColors.primary.withValues(alpha: 0.12)
                      : KColors.divider.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: selected ? KColors.primary : KColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: KTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: KColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? KColors.primary : Colors.transparent,
                  border: Border.all(
                    color: selected ? KColors.primary : KColors.divider,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
