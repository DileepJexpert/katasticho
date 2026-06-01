import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../onboarding/data/onboarding_state.dart';
import '../../onboarding/data/organisation_repository.dart';
import '../data/feature_flag_repository.dart';

class BusinessConfigurationScreen extends ConsumerStatefulWidget {
  const BusinessConfigurationScreen({super.key});

  @override
  ConsumerState<BusinessConfigurationScreen> createState() =>
      _BusinessConfigurationScreenState();
}

class _BusinessConfigurationScreenState
    extends ConsumerState<BusinessConfigurationScreen> {
  static const _moduleLabels = <String, String>{
    'ACCOUNTING': 'Accounting',
    'AR': 'Receivables',
    'AP': 'Payables',
    'GST': 'GST',
    'BANK_RECON': 'Banking',
    'AI_INBOX': 'AI',
    'REPORTS': 'Reports',
    'COLLECTIONS': 'Collections',
    'PAYMENTS': 'Payments',
    'POS': 'POS',
    'INVENTORY': 'Inventory',
    'DISTRIBUTION': 'Distribution',
    'PHARMA': 'Pharma',
    'MANUFACTURING': 'Manufacturing',
    'BATCH_EXPIRY': 'Batch & Expiry',
    'RECURRING_BILLING': 'Recurring',
    'MULTI_ENTITY': 'Multi Entity',
    'CA_CONSOLE': 'CA Console',
  };

  static const _planModules = <String, List<String>>{
    'BASIC': [
      'ACCOUNTING',
      'AR',
      'AP',
      'GST',
      'REPORTS',
      'PAYMENTS',
    ],
    'FINANCE_PRO': [
      'ACCOUNTING',
      'AR',
      'AP',
      'GST',
      'BANK_RECON',
      'AI_INBOX',
      'REPORTS',
      'COLLECTIONS',
      'PAYMENTS',
    ],
    'RETAIL': [
      'ACCOUNTING',
      'AR',
      'AP',
      'GST',
      'REPORTS',
      'PAYMENTS',
      'POS',
      'INVENTORY',
    ],
    'DISTRIBUTOR': [
      'ACCOUNTING',
      'AR',
      'AP',
      'GST',
      'BANK_RECON',
      'REPORTS',
      'COLLECTIONS',
      'PAYMENTS',
      'INVENTORY',
      'DISTRIBUTION',
    ],
    'PHARMA': [
      'ACCOUNTING',
      'AR',
      'AP',
      'GST',
      'BANK_RECON',
      'AI_INBOX',
      'REPORTS',
      'PAYMENTS',
      'INVENTORY',
      'PHARMA',
      'BATCH_EXPIRY',
    ],
    'RETAIL_DISTRIBUTOR': [
      'ACCOUNTING',
      'AR',
      'AP',
      'GST',
      'BANK_RECON',
      'REPORTS',
      'COLLECTIONS',
      'PAYMENTS',
      'POS',
      'INVENTORY',
      'DISTRIBUTION',
    ],
    'PHARMA_DISTRIBUTOR': [
      'ACCOUNTING',
      'AR',
      'AP',
      'GST',
      'BANK_RECON',
      'AI_INBOX',
      'REPORTS',
      'COLLECTIONS',
      'PAYMENTS',
      'INVENTORY',
      'DISTRIBUTION',
      'PHARMA',
      'BATCH_EXPIRY',
    ],
    'MANUFACTURER_DISTRIBUTOR': [
      'ACCOUNTING',
      'AR',
      'AP',
      'GST',
      'BANK_RECON',
      'REPORTS',
      'COLLECTIONS',
      'PAYMENTS',
      'INVENTORY',
      'DISTRIBUTION',
      'MANUFACTURING',
    ],
    'ENTERPRISE': [
      'ACCOUNTING',
      'AR',
      'AP',
      'GST',
      'BANK_RECON',
      'AI_INBOX',
      'REPORTS',
      'COLLECTIONS',
      'POS',
      'INVENTORY',
      'DISTRIBUTION',
      'PHARMA',
      'MANUFACTURING',
      'RECURRING_BILLING',
      'MULTI_ENTITY',
      'PAYMENTS',
      'BATCH_EXPIRY',
      'CA_CONSOLE',
    ],
  };

  static const _businessTypes = [
    (
      value: 'RETAILER',
      label: 'Retailer',
      subtitle: 'Counter sales and direct customer billing',
      icon: Icons.storefront_rounded,
    ),
    (
      value: 'DISTRIBUTOR',
      label: 'Distributor',
      subtitle: 'Wholesale, dispatch, and dealer supply',
      icon: Icons.local_shipping_rounded,
    ),
    (
      value: 'MANUFACTURER',
      label: 'Manufacturer',
      subtitle: 'Production, materials, and dispatch',
      icon: Icons.precision_manufacturing_rounded,
    ),
    (
      value: 'SERVICE_PROVIDER',
      label: 'Service Provider',
      subtitle: 'Billing, projects, and client delivery',
      icon: Icons.handyman_rounded,
    ),
  ];

  static const _industries = [
    (
      code: 'PHARMACY',
      label: 'Pharmacy',
      subtitle: 'Medicines, drugs, and healthcare inventory',
      icon: Icons.local_pharmacy_rounded,
    ),
    (
      code: 'GROCERY',
      label: 'Grocery',
      subtitle: 'Kirana, supermarket, and daily essentials',
      icon: Icons.shopping_basket_rounded,
    ),
    (
      code: 'ELECTRONICS',
      label: 'Electronics',
      subtitle: 'Devices, appliances, and accessories',
      icon: Icons.devices_rounded,
    ),
    (
      code: 'HARDWARE',
      label: 'Hardware',
      subtitle: 'Tools, paint, plumbing, and building supply',
      icon: Icons.build_rounded,
    ),
    (
      code: 'GARMENTS',
      label: 'Garments',
      subtitle: 'Clothing, fabric, and footwear',
      icon: Icons.checkroom_rounded,
    ),
    (
      code: 'FOOD_RESTAURANT',
      label: 'Food & Restaurant',
      subtitle: 'Cafe, bakery, catering, and food service',
      icon: Icons.restaurant_rounded,
    ),
    (
      code: 'AUTO_PARTS',
      label: 'Auto Parts',
      subtitle: 'Vehicle parts and accessories',
      icon: Icons.directions_car_rounded,
    ),
    (
      code: 'SERVICE',
      label: 'Services',
      subtitle: 'Repairs, consulting, and rentals',
      icon: Icons.miscellaneous_services_rounded,
    ),
    (
      code: 'OTHER_RETAIL',
      label: 'General Retail',
      subtitle: 'Use the broad retail template',
      icon: Icons.store_rounded,
    ),
  ];

  bool _initialized = false;
  bool _saving = false;
  String? _businessType;
  String? _industryCode;
  final Set<String> _selectedSubCategories = {};

  bool get _canSave {
    final role = ref.read(authProvider).role?.toUpperCase() ?? 'OWNER';
    return role == 'OWNER' || role == 'ADMIN';
  }

  void _initializeFromOrg(Map<String, dynamic> org) {
    if (_initialized) return;
    _businessType = (org['businessType'] as String?) ?? 'RETAILER';
    _industryCode = (org['industryCode'] as String?) ?? 'OTHER_RETAIL';
    final subCategories =
        (org['subCategories'] as List?)?.map((e) => e.toString()).toSet() ??
            <String>{};
    _selectedSubCategories
      ..clear()
      ..addAll(subCategories);
    _initialized = true;
  }

  Future<void> _save() async {
    final orgId = ref.read(authProvider).orgId;
    if (orgId == null || _businessType == null || _industryCode == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(organisationRepositoryProvider).updateIndustry(
            orgId: orgId,
            businessType: _businessType!,
            industryCode: _industryCode!,
            subCategories: _selectedSubCategories.toList()..sort(),
          );
      final industryLabel = _industries
          .firstWhere(
            (industry) => industry.code == _industryCode,
            orElse: () => _industries.last,
          )
          .label;
      await ref.read(authProvider.notifier).updateBusinessProfile(
            businessType: _businessType!,
            industryCode: _industryCode!,
            industryDisplayName: industryLabel,
          );
      ref.invalidate(featureFlagsProvider);
      ref.invalidate(orgDetailsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Business configuration updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update business configuration: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(orgDetailsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Configuration'),
        actions: [
          if (_canSave)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
        ],
      ),
      body: configAsync.when(
        loading: () => const KLoading(),
        error: (e, _) => KErrorView(
          message: 'Failed to load business configuration',
          onRetry: () => ref.invalidate(orgDetailsProvider),
        ),
        data: (org) {
          _initializeFromOrg(org);
          final subCategories =
              kSubCategoriesByIndustry[_industryCode ?? 'OTHER_RETAIL'] ??
                  const [];

          return SingleChildScrollView(
            padding: KSpacing.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PlanSummaryCard(
                  planTier: (org['planTier'] as String?) ?? 'FREE_BETA',
                  moduleLabels: _moduleLabels,
                  planModules: _planModules,
                ),
                KSpacing.vGapMd,
                KCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Primary business profile',
                        style: KTypography.labelLarge
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _canSave
                            ? 'Choose the main operating model for this organisation. Licensed modules remain controlled separately.'
                            : 'This organisation’s profile and modules are managed by an owner or admin.',
                        style: KTypography.bodySmall
                            .copyWith(color: cs.onSurfaceVariant, height: 1.35),
                      ),
                    ],
                  ),
                ),
                KSpacing.vGapMd,
                Text('Business type', style: KTypography.h3),
                KSpacing.vGapSm,
                ..._businessTypes.map(
                  (type) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SelectionRow(
                      label: type.label,
                      subtitle: type.subtitle,
                      icon: type.icon,
                      selected: _businessType == type.value,
                      enabled: _canSave,
                      onTap: () => setState(() => _businessType = type.value),
                    ),
                  ),
                ),
                KSpacing.vGapLg,
                Text('Industry template', style: KTypography.h3),
                KSpacing.vGapSm,
                ..._industries.map(
                  (industry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SelectionRow(
                      label: industry.label,
                      subtitle: industry.subtitle,
                      icon: industry.icon,
                      selected: _industryCode == industry.code,
                      enabled: _canSave,
                      onTap: () => setState(() {
                        _industryCode = industry.code;
                        _selectedSubCategories.clear();
                      }),
                    ),
                  ),
                ),
                KSpacing.vGapLg,
                Text('Subcategories', style: KTypography.h3),
                KSpacing.vGapSm,
                Text(
                  'These refine defaults and feature seeding inside the selected industry.',
                  style: KTypography.bodySmall
                      .copyWith(color: cs.onSurfaceVariant),
                ),
                KSpacing.vGapSm,
                if (subCategories.isEmpty)
                  KCard(
                    child: Text(
                      'No subcategories are defined for this template.',
                      style: KTypography.bodySmall
                          .copyWith(color: cs.onSurfaceVariant),
                    ),
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: subCategories.map((cat) {
                      final code = cat['code']!;
                      final label = cat['label']!;
                      final selected = _selectedSubCategories.contains(code);
                      return FilterChip(
                        selected: selected,
                        onSelected: !_canSave
                            ? null
                            : (value) {
                                setState(() {
                                  if (value) {
                                    _selectedSubCategories.add(code);
                                  } else {
                                    _selectedSubCategories.remove(code);
                                  }
                                });
                              },
                        label: Text(label),
                      );
                    }).toList(growable: false),
                  ),
                KSpacing.vGapLg,
                KCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What changes when you save',
                        style: KTypography.labelLarge
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      _ImpactBullet(
                        text:
                            'Business type and industry template are updated for this organisation.',
                      ),
                      _ImpactBullet(
                        text:
                            'Feature defaults are re-seeded for the selected profile and subcategories.',
                      ),
                      _ImpactBullet(
                        text:
                            'Licensed modules still depend on subscription entitlements and platform control.',
                      ),
                    ],
                  ),
                ),
                if (!_canSave) ...[
                  KSpacing.vGapMd,
                  KCard(
                    child: Text(
                      'You can review the business profile here, but only an owner or admin can change it.',
                      style: KTypography.bodySmall.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
                KSpacing.vGapXl,
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SelectionRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _SelectionRow({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: KSpacing.borderRadiusLg,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: selected
                ? cs.primaryContainer.withValues(alpha: 0.65)
                : Theme.of(context).cardColor,
            border: Border.all(
              color: selected ? cs.primary : cs.outlineVariant,
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
                      ? cs.primary.withValues(alpha: 0.12)
                      : cs.surfaceContainerHighest.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
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
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: KTypography.bodySmall
                          .copyWith(color: cs.onSurfaceVariant),
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
                  color: selected ? cs.primary : Colors.transparent,
                  border: Border.all(
                    color: selected ? cs.primary : cs.outlineVariant,
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

class _ImpactBullet extends StatelessWidget {
  final String text;

  const _ImpactBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child:
                Icon(Icons.check_circle_rounded, size: 16, color: cs.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: KTypography.bodySmall
                  .copyWith(color: cs.onSurfaceVariant, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanSummaryCard extends StatelessWidget {
  final String planTier;
  final Map<String, String> moduleLabels;
  final Map<String, List<String>> planModules;

  const _PlanSummaryCard({
    required this.planTier,
    required this.moduleLabels,
    required this.planModules,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entitledModules = (planModules[planTier] ?? const <String>[])
        .map((code) => moduleLabels[code] ?? code)
        .toList(growable: false);

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Licensed Modules',
                      style: KTypography.labelLarge
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Subscription plan controls which major modules can be enabled.',
                      style: KTypography.bodySmall
                          .copyWith(color: cs.onSurfaceVariant, height: 1.35),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _prettyPlan(planTier),
                  style: KTypography.labelSmall.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (entitledModules.isEmpty)
            Text(
              'This plan does not have a mapped module bundle yet. Contact platform admin to review entitlements.',
              style: KTypography.bodySmall
                  .copyWith(color: cs.onSurfaceVariant, height: 1.35),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: entitledModules
                  .map(
                    (label) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.tertiaryContainer.withValues(alpha: 0.60),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Text(
                        label,
                        style: KTypography.labelSmall.copyWith(
                          color: cs.onTertiaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          const SizedBox(height: 10),
          Text(
            'To unlock additional major modules, update the organisation plan or entitlement configuration. Business profile changes alone will not grant access.',
            style: KTypography.bodySmall
                .copyWith(color: cs.onSurfaceVariant, height: 1.35),
          ),
        ],
      ),
    );
  }

  String _prettyPlan(String value) {
    return value
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }
}
