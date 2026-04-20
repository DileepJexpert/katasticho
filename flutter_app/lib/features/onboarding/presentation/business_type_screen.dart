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
    {'value': 'RETAILER', 'label': 'Retailer', 'subtitle': 'Sell directly to customers', 'icon': Icons.storefront},
    {'value': 'DISTRIBUTOR', 'label': 'Distributor', 'subtitle': 'Wholesale & distribution', 'icon': Icons.local_shipping_outlined},
    {'value': 'MANUFACTURER', 'label': 'Manufacturer', 'subtitle': 'Make & sell products', 'icon': Icons.factory_outlined},
    {'value': 'SERVICE_PROVIDER', 'label': 'Service Provider', 'subtitle': 'Provide services', 'icon': Icons.miscellaneous_services_outlined},
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
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.2,
                  children: _types.map((t) {
                    final isSelected = selected == t['value'];
                    return _TypeCard(
                      label: t['label'] as String,
                      subtitle: t['subtitle'] as String,
                      icon: t['icon'] as IconData,
                      selected: isSelected,
                      onTap: () => ref
                          .read(onboardingProvider.notifier)
                          .setBusinessType(t['value'] as String),
                    );
                  }).toList(),
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

class _TypeCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selected
              ? KColors.primary.withValues(alpha: 0.08)
              : Theme.of(context).cardColor,
          border: Border.all(
            color: selected ? KColors.primary : KColors.divider,
            width: selected ? 2 : 1,
          ),
          borderRadius: KSpacing.borderRadiusLg,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 32,
                color: selected ? KColors.primary : KColors.textSecondary),
            const SizedBox(height: 8),
            Text(label,
                style: KTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: selected ? KColors.primary : KColors.textPrimary,
                ),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(subtitle,
                style: KTypography.bodySmall
                    .copyWith(color: KColors.textSecondary),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
