import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

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

            // Organisation
            Text('Organisation', style: KTypography.h3),
            KSpacing.vGapSm,
            _SettingsTile(
              icon: Icons.business,
              title: authState.orgName ?? 'Organisation',
              subtitle: 'Business profile & details',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.people_outline,
              title: 'Team Members',
              subtitle: 'Manage users & roles',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.account_tree_outlined,
              title: 'Chart of Accounts',
              subtitle: 'Manage account structure',
              onTap: () {},
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
            _SettingsTile(
              icon: Icons.tune,
              title: 'Inventory Features',
              subtitle: 'Enable batch tracking, MRP, variants & more',
              onTap: () => context.push(Routes.inventoryFeatures),
            ),
            KSpacing.vGapLg,

            // Tax & Compliance
            Text('Tax & Compliance', style: KTypography.h3),
            KSpacing.vGapSm,
            _SettingsTile(
              icon: Icons.receipt_long_outlined,
              title: 'GST Settings',
              subtitle: 'GSTIN, filing frequency',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.format_list_numbered,
              title: 'Invoice Numbering',
              subtitle: 'Prefix, sequence, format',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.percent,
              title: 'Tax Rates',
              subtitle: 'GST slabs & HSN mapping',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.swap_horiz_outlined,
              title: 'Tax Account Mapping',
              subtitle: 'Bind tax rates to GL accounts',
              onTap: () => context.push(Routes.taxAccountMappings),
            ),
            KSpacing.vGapLg,

            // Preferences
            Text('Preferences', style: KTypography.h3),
            KSpacing.vGapSm,
            _SettingsTile(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'Push, email & SMS alerts',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.language,
              title: 'Language',
              subtitle: 'English',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.currency_rupee,
              title: 'Currency',
              subtitle: 'INR - Indian Rupee',
              onTap: () {},
            ),
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
