import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/business_capabilities.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../../onboarding/data/organisation_repository.dart';
import '../data/feature_flag_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final capabilities = ref.watch(businessCapabilitiesProvider);
    final previewAllModules = ref.watch(previewAllModulesProvider);
    final featureFlagsAsync = ref.watch(featureFlagsProvider);
    final orgDetailsAsync = ref.watch(orgDetailsProvider);
    final role = authState.role?.toUpperCase() ?? 'OWNER';
    final canManageBusiness = role == 'OWNER' || role == 'ADMIN';

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: KSpacing.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile card
            KCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: KColors.primary,
                    child: Text(
                      (authState.userName ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  KSpacing.hGapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authState.userName ?? 'User',
                          style: KTypography.h3,
                        ),
                        Text(
                          authState.role ?? 'Owner',
                          style: KTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            KSpacing.vGapLg,

            Text('Business Model & Modules', style: KTypography.h3),
            KSpacing.vGapSm,
            _BusinessProfileCard(
              authState: authState,
              orgDetailsAsync: orgDetailsAsync,
              capabilities: capabilities,
              featureFlagsAsync: featureFlagsAsync,
              previewAllModules: previewAllModules,
              canManageBusiness: canManageBusiness,
            ),
            _SettingsTile(
              icon: Icons.domain_verification_outlined,
              title: 'Business Configuration',
              subtitle: canManageBusiness
                  ? 'Primary business, industry template, and subcategories'
                  : 'Review business profile and enabled modules',
              onTap: () => context.push(Routes.businessConfiguration),
            ),
            KSpacing.vGapLg,

            // Organisation
            Text('Organisation', style: KTypography.h3),
            KSpacing.vGapSm,
            _SettingsTile(
              icon: Icons.business,
              title: authState.orgName ?? 'Organisation',
              subtitle: 'Business name, address, GSTIN',
              onTap: () => context.push(Routes.orgDetails),
            ),
            _SettingsTile(
              icon: Icons.account_tree_outlined,
              title: 'Branches',
              subtitle: 'Add and manage branch locations',
              onTap: () => context.push(Routes.branches),
            ),
            _SettingsTile(
              icon: Icons.manage_accounts_outlined,
              title: 'Team Members',
              subtitle: 'Manage users & roles',
              onTap: () => context.push(Routes.teamMembers),
            ),
            _SettingsTile(
              icon: Icons.fact_check_outlined,
              title: 'Approval Inbox',
              subtitle: 'Review pending workflow approvals',
              onTap: () => context.push(Routes.approvals),
            ),
            _SettingsTile(
              icon: Icons.policy_outlined,
              title: 'Business Policies',
              subtitle: 'Credit, overdue, batch, and dispatch behavior',
              onTap: () => context.push(Routes.businessPolicies),
            ),
            _SettingsTile(
              icon: Icons.account_tree_outlined,
              title: 'Workflows',
              subtitle: canManageBusiness
                  ? 'Configure approvals, triggers, and approver roles'
                  : 'Review approval workflows configured for this organisation',
              onTap: () => context.push(Routes.workflowSettings),
            ),
            _SettingsTile(
              icon: Icons.table_chart_outlined,
              title: 'Chart of Accounts',
              subtitle: 'Manage account structure',
              onTap: () => context.push(Routes.chartOfAccounts),
            ),
            _SettingsTile(
              icon: Icons.account_balance_outlined,
              title: 'Default Accounts',
              subtitle: 'AR, AP, Cash, Bank, Sales, etc.',
              onTap: () => context.push(Routes.defaultAccounts),
            ),
            KSpacing.vGapLg,

            // Inventory
            Text('Inventory', style: KTypography.h3),
            KSpacing.vGapSm,
            if (capabilities.canUseInventory)
              _SettingsTile(
                icon: Icons.tune,
                title: 'Inventory Features',
                subtitle: 'Enable batch tracking, MRP, variants & more',
                onTap: () => context.push(Routes.inventoryFeatures),
              )
            else
              _SettingsTile(
                icon: Icons.tune,
                title: 'Inventory Features',
                subtitle: 'Enable inventory in your business configuration',
                onTap: () => _showComingSoon(context,
                    'Inventory module is not enabled for this business'),
              ),
            KSpacing.vGapLg,

            // Tax & Compliance
            Text('Tax & Compliance', style: KTypography.h3),
            KSpacing.vGapSm,
            _SettingsTile(
              icon: Icons.receipt_long_outlined,
              title: 'GST Settings',
              subtitle: 'GSTIN, filing frequency',
              onTap: () => _showComingSoon(context, 'GST Settings'),
            ),
            _SettingsTile(
              icon: Icons.format_list_numbered,
              title: 'Invoice Numbering',
              subtitle: 'Prefix, sequence, format',
              onTap: () => _showComingSoon(context, 'Invoice Numbering'),
            ),
            _SettingsTile(
              icon: Icons.percent,
              title: 'Tax Rates',
              subtitle: 'GST slabs & HSN mapping',
              onTap: () => _showComingSoon(context, 'Tax Rates'),
            ),
            _SettingsTile(
              icon: Icons.swap_horiz_outlined,
              title: 'Tax Account Mapping',
              subtitle: 'Bind tax rates to GL accounts',
              onTap: () => context.push(Routes.taxAccountMappings),
            ),
            KSpacing.vGapLg,

            // POS
            Text('Point of Sale', style: KTypography.h3),
            KSpacing.vGapSm,
            if (capabilities.canUsePos)
              _SettingsTile(
                icon: Icons.receipt_outlined,
                title: 'Receipt Template',
                subtitle: 'Paper size, logo, footer, HSN codes',
                onTap: () => context.push(Routes.receiptSettings),
              ),
            KSpacing.vGapLg,

            // Preferences
            Text('Preferences', style: KTypography.h3),
            KSpacing.vGapSm,
            _SettingsTile(
              icon: Icons.smart_toy_outlined,
              title: 'AI & Scanning Model',
              subtitle: 'Choose OCR model for bill & label scanning',
              onTap: () => context.push(Routes.aiSettings),
            ),
            _SettingsTile(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'Push, email & SMS alerts',
              onTap: () => _showComingSoon(context, 'Notifications'),
            ),
            _SettingsTile(
              icon: Icons.language,
              title: 'Language',
              subtitle: 'English',
              onTap: () => _showComingSoon(context, 'Language'),
            ),
            _SettingsTile(
              icon: Icons.currency_rupee,
              title: 'Currency',
              subtitle: 'INR - Indian Rupee',
              onTap: () => _showComingSoon(context, 'Currency'),
            ),
            if (kDebugMode) ...[
              KSpacing.vGapLg,
              Text('Developer Tools', style: KTypography.h3),
              KSpacing.vGapSm,
              _PreviewModulesCard(
                enabled: previewAllModules,
                onChanged: (value) => ref
                    .read(previewAllModulesProvider.notifier)
                    .setEnabled(value),
                onReset: () => ref
                    .read(previewAllModulesProvider.notifier)
                    .resetToDefault(),
              ),
            ],
            KSpacing.vGapLg,

            // Support
            Text('Support', style: KTypography.h3),
            KSpacing.vGapSm,
            _SettingsTile(
              icon: Icons.help_outline,
              title: 'Help & Support',
              subtitle: 'FAQs, tutorials, contact us',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.info_outline,
              title: 'About',
              subtitle: 'Version 1.0.0',
              onTap: () {},
            ),
            KSpacing.vGapLg,

            // Logout
            SizedBox(
              width: double.infinity,
              child: KButton(
                label: 'Logout',
                variant: KButtonVariant.danger,
                icon: Icons.logout,
                fullWidth: true,
                onPressed: () => _showLogoutConfirmation(context, ref),
              ),
            ),
            KSpacing.vGapXl,
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — coming soon')),
    );
  }

  void _showLogoutConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go(Routes.login);
              }
            },
            style: TextButton.styleFrom(foregroundColor: KColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _PreviewModulesCard extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final VoidCallback onReset;

  const _PreviewModulesCard({
    required this.enabled,
    required this.onChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile.adaptive(
            value: enabled,
            onChanged: onChanged,
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Show All Modules',
              style: KTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              'Developer-only preview. Shows all vertical modules in navigation and dashboard for local testing.',
              style: KTypography.bodySmall.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Turn this off before production validation. Release builds ignore this toggle.',
                  style: KTypography.bodySmall.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton(
                onPressed: onReset,
                child: const Text('Reset'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BusinessProfileCard extends StatelessWidget {
  final AuthState authState;
  final AsyncValue<Map<String, dynamic>> orgDetailsAsync;
  final BusinessCapabilities capabilities;
  final AsyncValue<Set<String>> featureFlagsAsync;
  final bool previewAllModules;
  final bool canManageBusiness;

  const _BusinessProfileCard({
    required this.authState,
    required this.orgDetailsAsync,
    required this.capabilities,
    required this.featureFlagsAsync,
    required this.previewAllModules,
    required this.canManageBusiness,
  });

  static const _moduleLabels = <String, String>{
    'ACCOUNTING': 'Accounting',
    'AI_INBOX': 'AI',
    'POS': 'POS',
    'INVENTORY': 'Inventory',
    'DISTRIBUTION': 'Distribution',
    'PHARMA': 'Pharma',
    'MANUFACTURING': 'Manufacturing',
    'BATCH_EXPIRY': 'Batch & Expiry',
    'BANK_RECON': 'Banking',
    'REPORTS': 'Reports',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final org = orgDetailsAsync.valueOrNull;
    final businessType =
        org?['businessType'] as String? ?? authState.businessType ?? 'Not set';
    final industry = org?['industryCode'] as String? ??
        authState.industryCode ??
        authState.industry ??
        'Not set';

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Primary business',
                        style: KTypography.labelSmall
                            .copyWith(color: KColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(
                      _prettyLabel(businessType),
                      style: KTypography.h4,
                    ),
                    const SizedBox(height: 10),
                    Text('Industry template',
                        style: KTypography.labelSmall
                            .copyWith(color: KColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(
                      _prettyLabel(industry),
                      style: KTypography.bodyMedium,
                    ),
                    if (orgDetailsAsync.isLoading) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(minHeight: 2),
                    ],
                  ],
                ),
              ),
              if (previewAllModules)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Dev Preview',
                    style: KTypography.labelSmall.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          KSpacing.vGapMd,
          Text(
            'Enabled modules',
            style: KTypography.labelLarge.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          featureFlagsAsync.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (_, __) => _CapabilityChipWrap(
              labels: _labelsFromCapabilities(capabilities),
            ),
            data: (features) => _CapabilityChipWrap(
              labels: _labelsFromFeatures(features),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            canManageBusiness
                ? 'Major modules are controlled by subscription and business configuration. Inventory feature toggles remain available below.'
                : 'Module availability is managed by your organisation owner or admin.',
            style: KTypography.bodySmall
                .copyWith(color: cs.onSurfaceVariant, height: 1.35),
          ),
        ],
      ),
    );
  }

  static List<String> _labelsFromFeatures(Set<String> features) {
    final labels = features
        .where(_moduleLabels.containsKey)
        .map((f) => _moduleLabels[f]!)
        .toList(growable: false);
    labels.sort();
    return labels;
  }

  static List<String> _labelsFromCapabilities(
      BusinessCapabilities capabilities) {
    final labels = <String>[
      if (capabilities.canUseAccounting) 'Accounting',
      if (capabilities.canUseAiInbox) 'AI',
      if (capabilities.canUsePos) 'POS',
      if (capabilities.canUseInventory) 'Inventory',
      if (capabilities.canUseDistribution) 'Distribution',
      if (capabilities.canUsePharma) 'Pharma',
      if (capabilities.canUseManufacturing) 'Manufacturing',
      if (capabilities.canUseBatchExpiry) 'Batch & Expiry',
      if (capabilities.canUseBankRecon) 'Banking',
      if (capabilities.canUseReports) 'Reports',
    ];
    labels.sort();
    return labels;
  }

  static String _prettyLabel(String value) {
    return value
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }
}

class _CapabilityChipWrap extends StatelessWidget {
  final List<String> labels;

  const _CapabilityChipWrap({required this.labels});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: labels
          .map(
            (label) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cs.secondaryContainer.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: Text(
                label,
                style: KTypography.labelSmall.copyWith(
                  color: cs.onSecondaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: KColors.primary.withValues(alpha: 0.06),
          borderRadius: KSpacing.borderRadiusMd,
        ),
        child: Icon(icon, color: KColors.primary, size: 22),
      ),
      title: Text(title, style: KTypography.bodyMedium),
      subtitle: Text(subtitle, style: KTypography.bodySmall),
      trailing: const Icon(Icons.chevron_right, color: KColors.textHint),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }
}
