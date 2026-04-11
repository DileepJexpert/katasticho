import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/auth/auth_state.dart';
import '../core/theme/k_colors.dart';
import '../core/theme/k_spacing.dart';
import '../core/theme/k_typography.dart';
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
    activeIcon: Icons.dashboard,
    route: Routes.dashboard,
  ),
  NavItem(
    label: 'Invoices',
    icon: Icons.receipt_long_outlined,
    activeIcon: Icons.receipt_long,
    route: Routes.invoices,
  ),
  NavItem(
    label: 'Customers',
    icon: Icons.people_outline,
    activeIcon: Icons.people,
    route: Routes.customers,
  ),
  NavItem(
    label: 'Reports',
    icon: Icons.bar_chart_outlined,
    activeIcon: Icons.bar_chart,
    route: Routes.reports,
  ),
  NavItem(
    label: 'AI Chat',
    icon: Icons.auto_awesome_outlined,
    activeIcon: Icons.auto_awesome,
    route: Routes.aiChat,
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
    final isMobile = !isDesktop && !isTablet;

    if (isDesktop) {
      return _DesktopShell(child: child);
    } else if (isTablet) {
      return _TabletShell(child: child);
    } else {
      return _MobileShell(child: child);
    }
  }
}

// ── Desktop: Fixed sidebar + content area ──

class _DesktopShell extends ConsumerWidget {
  final Widget child;

  const _DesktopShell({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: KSpacing.sidebarWidth,
            decoration: const BoxDecoration(
              color: KColors.primary,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Logo / Brand
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: KColors.accent,
                          borderRadius: KSpacing.borderRadiusMd,
                        ),
                        child: const Center(
                          child: Text(
                            'K',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      KSpacing.hGapMd,
                      const Text(
                        'Katasticho',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),
                KSpacing.vGapSm,

                // Nav Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      ..._navItems.map((item) => _SidebarNavItem(item: item)),
                      KSpacing.vGapSm,
                      const Divider(color: Colors.white24, height: 1),
                      KSpacing.vGapSm,
                      _SidebarNavItem(
                        item: const NavItem(
                          label: 'Credit Notes',
                          icon: Icons.note_alt_outlined,
                          activeIcon: Icons.note_alt,
                          route: Routes.creditNotes,
                        ),
                      ),
                      _SidebarNavItem(
                        item: const NavItem(
                          label: 'GST',
                          icon: Icons.account_balance_outlined,
                          activeIcon: Icons.account_balance,
                          route: Routes.gst,
                        ),
                      ),
                      _SidebarNavItem(
                        item: const NavItem(
                          label: 'Settings',
                          icon: Icons.settings_outlined,
                          activeIcon: Icons.settings,
                          route: Routes.settings,
                        ),
                      ),
                    ],
                  ),
                ),

                // User info
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: KColors.accent,
                        child: Text(
                          (authState.userName ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      KSpacing.hGapSm,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              authState.userName ?? 'User',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              authState.orgName ?? 'Organisation',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
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

class _SidebarNavItem extends StatelessWidget {
  final NavItem item;

  const _SidebarNavItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final isActive = currentRoute == item.route ||
        (item.route != '/' && currentRoute.startsWith(item.route));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(
          borderRadius: KSpacing.borderRadiusMd,
        ),
        leading: Icon(
          isActive ? item.activeIcon : item.icon,
          color: isActive ? KColors.accent : Colors.white70,
          size: 22,
        ),
        title: Text(
          item.label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white70,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            fontSize: 14,
          ),
        ),
        tileColor: isActive ? Colors.white.withValues(alpha: 0.12) : null,
        onTap: () => context.go(item.route),
      ),
    );
  }
}

// ── Tablet: Rail navigation + content ──

class _TabletShell extends StatelessWidget {
  final Widget child;

  const _TabletShell({required this.child});

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
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            backgroundColor: KColors.primary,
            indicatorColor: Colors.white.withValues(alpha: 0.15),
            onDestinationSelected: (index) {
              context.go(_navItems[index].route);
            },
            labelType: NavigationRailLabelType.all,
            leading: Container(
              margin: const EdgeInsets.only(bottom: 8),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: KColors.accent,
                borderRadius: KSpacing.borderRadiusMd,
              ),
              child: const Center(
                child: Text(
                  'K',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            destinations: _navItems
                .map((item) => NavigationRailDestination(
                      icon: Icon(item.icon, color: Colors.white70),
                      selectedIcon:
                          Icon(item.activeIcon, color: KColors.accent),
                      label: Text(
                        item.label,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                      ),
                    ))
                .toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ── Mobile: Bottom navigation bar ──

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
        backgroundColor: KColors.surface,
        indicatorColor: KColors.primary.withValues(alpha: 0.12),
        destinations: _navItems
            .map((item) => NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.activeIcon, color: KColors.primary),
                  label: item.label,
                ))
            .toList(),
      ),
    );
  }
}
