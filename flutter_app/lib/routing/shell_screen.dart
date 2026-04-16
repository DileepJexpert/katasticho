import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/auth/auth_state.dart';
import '../core/theme/k_colors.dart';
import '../core/theme/k_spacing.dart';
import '../core/widgets/theme_mode_switcher.dart';
import '../features/notifications/data/notification_repository.dart';
import 'app_router.dart';

/// Navigation item definition.
class NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;

  const NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
  });
}

const _navItems = [
  NavItem(
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    activeIcon: Icons.dashboard_rounded,
    route: Routes.dashboard,
  ),
  NavItem(
    label: 'Invoices',
    icon: Icons.receipt_long_outlined,
    activeIcon: Icons.receipt_long_rounded,
    route: Routes.invoices,
  ),
  NavItem(
    label: 'Contacts',
    icon: Icons.people_outline_rounded,
    activeIcon: Icons.people_rounded,
    route: Routes.contacts,
  ),
  NavItem(
    label: 'Items',
    icon: Icons.inventory_2_outlined,
    activeIcon: Icons.inventory_2_rounded,
    route: Routes.items,
  ),
  NavItem(
    label: 'Expenses',
    icon: Icons.payments_outlined,
    activeIcon: Icons.payments_rounded,
    route: Routes.expenses,
  ),
  NavItem(
    label: 'Reports',
    icon: Icons.bar_chart_outlined,
    activeIcon: Icons.bar_chart_rounded,
    route: Routes.reports,
  ),
  NavItem(
    label: 'AI Chat',
    icon: Icons.auto_awesome_outlined,
    activeIcon: Icons.auto_awesome_rounded,
    route: Routes.aiChat,
  ),
];

const _salesNavItems = [
  NavItem(
    label: 'Quick POS',
    icon: Icons.point_of_sale_outlined,
    activeIcon: Icons.point_of_sale_rounded,
    route: Routes.pos,
  ),
];

const _purchasesNavItems = [
  NavItem(
    label: 'Bills',
    icon: Icons.receipt_outlined,
    activeIcon: Icons.receipt_rounded,
    route: Routes.bills,
  ),
  NavItem(
    label: 'Payments',
    icon: Icons.payments_outlined,
    activeIcon: Icons.payments_rounded,
    route: Routes.vendorPayments,
  ),
  NavItem(
    label: 'Credits',
    icon: Icons.note_alt_outlined,
    activeIcon: Icons.note_alt_rounded,
    route: Routes.vendorCredits,
  ),
];

const _secondaryNavItems = [
  NavItem(
    label: 'Estimates',
    icon: Icons.request_quote_outlined,
    activeIcon: Icons.request_quote_rounded,
    route: Routes.estimates,
  ),
  NavItem(
    label: 'Recurring',
    icon: Icons.autorenew_outlined,
    activeIcon: Icons.autorenew_rounded,
    route: Routes.recurringInvoices,
  ),
  NavItem(
    label: 'Import Items',
    icon: Icons.upload_file_outlined,
    activeIcon: Icons.upload_file_rounded,
    route: Routes.itemImport,
  ),
  NavItem(
    label: 'Goods Receipts',
    icon: Icons.local_shipping_outlined,
    activeIcon: Icons.local_shipping_rounded,
    route: Routes.stockReceipts,
  ),
  NavItem(
    label: 'Credit Notes',
    icon: Icons.note_alt_outlined,
    activeIcon: Icons.note_alt_rounded,
    route: Routes.creditNotes,
  ),
  NavItem(
    label: 'Price Lists',
    icon: Icons.sell_outlined,
    activeIcon: Icons.sell_rounded,
    route: Routes.priceLists,
  ),
  NavItem(
    label: 'GST',
    icon: Icons.account_balance_outlined,
    activeIcon: Icons.account_balance_rounded,
    route: Routes.gst,
  ),
  NavItem(
    label: 'Settings',
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings_rounded,
    route: Routes.settings,
  ),
];

/// Responsive shell: sidebar on desktop/tablet, bottom nav on mobile.
class ShellScreen extends ConsumerWidget {
  final Widget child;

  const ShellScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= KSpacing.desktopBreakpoint;
    final isTablet = width >= KSpacing.tabletBreakpoint && !isDesktop;

    if (isDesktop) {
      return _DesktopShell(child: child);
    } else if (isTablet) {
      return _TabletShell(child: child);
    } else {
      return _MobileShell(child: child);
    }
  }
}

// ── Desktop: Fixed sidebar + content area ────────────────────────────

class _DesktopShell extends ConsumerWidget {
  final Widget child;

  const _DesktopShell({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Row(
        children: [
          // Sidebar — soft tinted surface (not solid brand color)
          Container(
            width: KSpacing.sidebarWidth,
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                right: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: isDark ? 0.4 : 0.6),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // Logo / Brand
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [cs.primary, cs.tertiary],
                          ),
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withValues(alpha: 0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'K',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      KSpacing.hGapMd,
                      Text(
                        'Katasticho',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),

                // Nav items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _NavSectionLabel(label: 'WORKSPACE'),
                      ..._navItems.map((item) => _SidebarNavItem(item: item)),
                      KSpacing.vGapMd,
                      _NavSectionLabel(label: 'SALES'),
                      ..._salesNavItems
                          .map((item) => _SidebarNavItem(item: item)),
                      KSpacing.vGapMd,
                      _NavSectionLabel(label: 'PURCHASES'),
                      ..._purchasesNavItems
                          .map((item) => _SidebarNavItem(item: item)),
                      KSpacing.vGapMd,
                      _NavSectionLabel(label: 'MORE'),
                      ..._secondaryNavItems
                          .map((item) => _SidebarNavItem(item: item)),
                    ],
                  ),
                ),

                // Footer: theme switcher + user
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Column(
                    children: [
                      Divider(
                        color: cs.outlineVariant.withValues(alpha: 0.5),
                        height: 1,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: cs.primaryContainer,
                            child: Text(
                              (authState.userName ?? 'U')[0].toUpperCase(),
                              style: TextStyle(
                                color: cs.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          KSpacing.hGapSm,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  authState.userName ?? 'User',
                                  style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  authState.orgName ?? 'Organisation',
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const _NotificationBell(),
                          const SizedBox(width: 4),
                          const ThemeModeIconButton(),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main content
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _NavSectionLabel extends StatelessWidget {
  final String label;
  const _NavSectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Text(
        label,
        style: TextStyle(
          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Longest-prefix match across both nav sections. Prevents `Items` (/items)
/// and `Import Items` (/items/import) from both lighting up on /items/import
/// — only the most specific entry wins. Uses `$r/` suffix guard so `/item`
/// can't false-match `/items`.
bool _isNavActive(String currentRoute, String itemRoute) {
  if (itemRoute == '/') return currentRoute == '/';
  bool matchesSelfOrChild(String r) =>
      currentRoute == r || currentRoute.startsWith('$r/');
  if (!matchesSelfOrChild(itemRoute)) return false;
  for (final other in [..._navItems, ..._salesNavItems, ..._purchasesNavItems, ..._secondaryNavItems]) {
    if (other.route == itemRoute) continue;
    if (other.route.length > itemRoute.length && matchesSelfOrChild(other.route)) {
      return false;
    }
  }
  return true;
}

class _SidebarNavItem extends StatelessWidget {
  final NavItem item;

  const _SidebarNavItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final isActive = _isNavActive(currentRoute, item.route);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isActive ? cs.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.go(item.route),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  isActive ? item.activeIcon : item.icon,
                  color: isActive ? cs.primary : cs.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: isActive ? cs.onPrimaryContainer : cs.onSurface,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (isActive)
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tablet: Rail navigation + content ────────────────────────────────

class _TabletShell extends StatelessWidget {
  final Widget child;

  const _TabletShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentRoute = GoRouterState.of(context).matchedLocation;

    int selectedIndex = _navItems.indexWhere(
      (item) =>
          currentRoute == item.route ||
          (item.route != '/' && currentRoute.startsWith(item.route)),
    );
    if (selectedIndex < 0) selectedIndex = 0;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            backgroundColor: cs.surface,
            indicatorColor: cs.primaryContainer,
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onDestinationSelected: (index) {
              context.go(_navItems[index].route);
            },
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 12),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [cs.primary, cs.tertiary],
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Center(
                  child: Text(
                    'K',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),
            trailing: const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: ThemeModeIconButton(),
            ),
            destinations: _navItems
                .map(
                  (item) => NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.activeIcon),
                    label: Text(item.label),
                  ),
                )
                .toList(),
          ),
          VerticalDivider(
            width: 1,
            color: cs.outlineVariant.withValues(alpha: 0.5),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ── Mobile: Bottom navigation bar ────────────────────────────────────

class _MobileShell extends StatelessWidget {
  final Widget child;

  const _MobileShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;

    int selectedIndex = _navItems.indexWhere(
      (item) =>
          currentRoute == item.route ||
          (item.route != '/' && currentRoute.startsWith(item.route)),
    );
    if (selectedIndex < 0) selectedIndex = 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          context.go(_navItems[index].route);
        },
        destinations: _navItems
            .map((item) => NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.activeIcon),
                  label: item.label,
                ))
            .toList(),
      ),
    );
  }
}

// ── Notification Bell ─────────────────────────────────────────────────

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(unreadCountProvider);
    final count = countAsync.valueOrNull ?? 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, size: 20),
          tooltip: 'Notifications',
          onPressed: () => context.push(Routes.notifications),
        ),
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: IgnorePointer(
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: KColors.error,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
