import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../data/onboarding_state.dart';

class BusinessTypeScreen extends ConsumerWidget {
  const BusinessTypeScreen({super.key});

  static const _types = [
    {'value': 'RETAILER', 'label': 'Retailer', 'subtitle': 'Sell directly to customers', 'icon': Icons.storefront_rounded},
    {'value': 'DISTRIBUTOR', 'label': 'Distributor', 'subtitle': 'Wholesale & distribution', 'icon': Icons.local_shipping_rounded},
    {'value': 'MANUFACTURER', 'label': 'Manufacturer', 'subtitle': 'Make & sell products', 'icon': Icons.precision_manufacturing_rounded},
    {'value': 'SERVICE_PROVIDER', 'label': 'Service Provider', 'subtitle': 'Provide services', 'icon': Icons.handyman_rounded},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingProvider).businessType;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: KSpacing.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KSpacing.vGapXl,
              Text('What type of business\ndo you run?', style: KTypography.h1),
              KSpacing.vGapSm,
              Text(
                'This helps us tailor the app for your needs.',
                style: KTypography.bodyMedium.copyWith(color: KColors.textSecondary),
              ),
              KSpacing.vGapXl,
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: _types.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final t = _types[i];
                    final isSelected = selected == t['value'];
                    return _TypeRow(
                      label: t['label'] as String,
                      subtitle: t['subtitle'] as String,
                      icon: t['icon'] as IconData,
                      selected: isSelected,
                      onTap: () => ref
                          .read(onboardingProvider.notifier)
                          .setBusinessType(t['value'] as String),
                    );
                  },
                ),
              ),
              KSpacing.vGapLg,
              KButton(
                label: 'Continue',
                fullWidth: true,
                size: KButtonSize.large,
                onPressed: () => context.go(Routes.onboardingIndustry),
              ),
              KSpacing.vGapMd,
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeRow({
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? KColors.primary.withValues(alpha: 0.12)
                      : KColors.divider.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: selected ? KColors.primary : KColors.textSecondary,
                ),
              ),
              const SizedBox(width: 14),
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
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? KColors.primary : Colors.transparent,
                  border: Border.all(
                    color: selected ? KColors.primary : KColors.divider,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
