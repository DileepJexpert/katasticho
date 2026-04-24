import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/auth/auth_state.dart';
import '../core/commands/command_registry.dart';
import '../core/shell/shell_providers.dart';
import '../core/theme/k_colors.dart';
import '../core/theme/k_spacing.dart';
import '../core/widgets/k_assistant_fab.dart';
import '../core/widgets/k_command_palette.dart';
import '../core/widgets/k_quick_create_menu.dart';
import '../core/widgets/k_top_bar.dart';
import '../core/widgets/theme_mode_switcher.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/dashboard/data/dashboard_repository.dart';
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
    label: 'Sales Orders',
    icon: Icons.assignment_outlined,
    activeIcon: Icons.assignment_rounded,
    route: Routes.salesOrders,
  ),
  NavItem(
    label: 'Delivery Challans',
    icon: Icons.local_shipping_outlined,
    activeIcon: Icons.local_shipping_rounded,
    route: Routes.deliveryChallans,
  ),
  NavItem(
    label: 'Quick POS',
    icon: Icons.point_of_sale_outlined,
    activeIcon: Icons.point_of_sale_rounded,
    route: Routes.pos,
  ),
  NavItem(
    label: 'Sales Receipts',
    icon: Icons.receipt_long_outlined,
    activeIcon: Icons.receipt_long_rounded,
    route: Routes.salesReceipts,
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

const _accountingNavItems = [
  NavItem(
    label: 'Accounting Dashboard',
    icon: Icons.analytics_outlined,
    activeIcon: Icons.analytics_rounded,
    route: '/accounting/dashboard',
  ),
  NavItem(
    label: 'Chart of Accounts',
    icon: Icons.account_balance_outlined,
    activeIcon: Icons.account_balance_rounded,
    route: Routes.chartOfAccounts,
  ),
  NavItem(
    label: 'Journal Entries',
    icon: Icons.menu_book_outlined,
    activeIcon: Icons.menu_book_rounded,
    route: '/accounting/journal-entries',
  ),
];

const _secondaryNavItems = [
  NavItem(
    label: 'Credit Ledger',
    icon: Icons.menu_book_outlined,
    activeIcon: Icons.menu_book_rounded,
    route: Routes.creditLedger,
  ),
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

/// Convenience used by the shell to decide where to anchor the FAB.
bool _isMobile(double width) => width < KSpacing.tabletBreakpoint;

/// Wraps its child in a local [Theme] override driven by
/// [KColors.sidebarSeed] / [KColors.sidebarBrightness], so the sidebar
/// (and tablet rail) can run on a palette that's independent of the
/// app-wide brand seed. All `Theme.of(context).colorScheme.*` calls
/// inside the child resolve to the sidebar palette.
class _SidebarTheme extends StatelessWidget {
  final Widget child;
  const _SidebarTheme({required this.child});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: KColors.sidebarSeed,
          brightness: KColors.sidebarBrightness,
        ),
      ),
      child: child,
    );
  }
}

/// Responsive shell: sidebar on desktop/tablet, bottom nav on mobile.
///
/// Also installs the global Cmd/Ctrl+K shortcut for the command palette and
/// the floating AI assistant (desktop/tablet only).
class ShellScreen extends ConsumerStatefulWidget {
  final Widget child;

  const ShellScreen({super.key, required this.child});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    super.dispose();
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.keyK) return false;
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final mod = pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight);
    if (!mod) return false;
    KCommandPalette.show(context, commands: buildAppCommands());
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= KSpacing.desktopBreakpoint;
    final isTablet = width >= KSpacing.tabletBreakpoint && !isDesktop;

    final Widget shell;
    if (isDesktop) {
      shell = _DesktopShell(child: widget.child);
    } else if (isTablet) {
      shell = _TabletShell(child: widget.child);
    } else {
      shell = _MobileShell(child: widget.child);
    }

    return shell;
  }
}

// ── Desktop: Fixed sidebar + content area ────────────────────────────

class _DesktopShell extends ConsumerWidget {
  final Widget child;

  const _DesktopShell({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final collapsed = ref.watch(sidebarCollapsedProvider);
    final notifCount =
        ref.watch(unreadCountProvider).valueOrNull ?? 0;

    final sidebarWidth =
        collapsed ? KSpacing.sidebarCollapsedWidth : KSpacing.sidebarWidth;

    return Scaffold(
      body: Column(
        children: [
          // ── Full-width top bar ──────────────────────────────────
          KTopBar(
            notificationCount: notifCount,
            onNotifications: () => context.push(Routes.notifications),
          ),

          // ── Sidebar + Content row ───────────────────────────────
          Expanded(
            child: Row(
              children: [
                _SidebarTheme(
                  child: Builder(builder: (context) {
                    final scs = Theme.of(context).colorScheme;
                    final sIsDark =
                        Theme.of(context).brightness == Brightness.dark;
                    return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: sidebarWidth,
                  decoration: BoxDecoration(
                    color: scs.surface,
                    border: Border(
                      right: BorderSide(
                        color: scs.outlineVariant
                            .withValues(alpha: sIsDark ? 0.4 : 0.6),
                        width: 1,
                      ),
                    ),
                  ),
                  child: ClipRect(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                      // Derive display mode from actual animated width so
                      // labels don't appear before the container is wide enough.
                      final collapsed = constraints.maxWidth < 160;
                      return Column(
                      children: [
                        // Brand logo — always uses brand seeds (identity),
                        // independent of sidebar palette.
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                              collapsed ? 12 : 16, 14, collapsed ? 12 : 16, 10),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      KColors.brandSeed,
                                      KColors.accentSeed,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: KColors.brandSeed
                                          .withValues(alpha: 0.22),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    'K',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 17,
                                    ),
                                  ),
                                ),
                              ),
                              if (!collapsed) ...[
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Katasticho',
                                    overflow: TextOverflow.clip,
                                    softWrap: false,
                                    style: TextStyle(
                                      color: scs.onSurface,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Quick Create button
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: collapsed ? 8 : 12),
                          child: KQuickCreateMenu(expanded: !collapsed),
                        ),
                        const SizedBox(height: 8),

                        // Nav items
                        Expanded(
                          child: ListView(
                            padding: EdgeInsets.symmetric(
                                horizontal: collapsed ? 8 : 12),
                            children: _buildSidebarSections(
                              collapsed: collapsed,
                              role: authState.role?.toUpperCase() ?? 'OWNER',
                            ),
                          ),
                        ),

                        // Ask AI
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                              collapsed ? 8 : 12, 0, collapsed ? 8 : 12, 8),
                          child: _AskAiButton(
                            collapsed: collapsed,
                            onTap: () => KAssistantPanel.show(context),
                          ),
                        ),

                        // User footer
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                              collapsed ? 8 : 12, 4, collapsed ? 8 : 12, 12),
                          child: Column(
                            children: [
                              Divider(
                                color: scs.outlineVariant
                                    .withValues(alpha: 0.5),
                                height: 1,
                              ),
                              const SizedBox(height: 8),
                              Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: collapsed
                                      ? null
                                      : () => _showOrgSwitcher(context, ref),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 4),
                                    child: Row(
                                      children: [
                                        Tooltip(
                                          message: collapsed
                                              ? (authState.userName ?? 'User')
                                              : '',
                                          child: CircleAvatar(
                                            radius: 17,
                                            backgroundColor:
                                                scs.primaryContainer,
                                            child: Text(
                                              (authState.userName ?? 'U')[0]
                                                  .toUpperCase(),
                                              style: TextStyle(
                                                color: scs.onPrimaryContainer,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (!collapsed) ...[
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  authState.userName ?? 'User',
                                                  style: TextStyle(
                                                    color: scs.onSurface,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  authState.orgName ??
                                                      'Organisation',
                                                  style: TextStyle(
                                                    color:
                                                        scs.onSurfaceVariant,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.unfold_more_rounded,
                                            size: 16,
                                            color: scs.onSurfaceVariant,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      );
                      },
                    ),
                  ),
                );
                  }),
                ),

                // Main content
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

List<Widget> _buildSidebarSections({
  required bool collapsed,
  required String role,
}) {
  final isCashier = role == 'OPERATOR' || role == 'CASHIER';

  return [
    if (!collapsed) const _NavSectionLabel(label: 'WORKSPACE'),
    ..._navItems.map((item) => _SidebarNavItem(item: item, collapsed: collapsed)),
    KSpacing.vGapMd,
    if (!collapsed) const _NavSectionLabel(label: 'SALES'),
    ..._salesNavItems.map((item) => _SidebarNavItem(item: item, collapsed: collapsed)),
    KSpacing.vGapMd,
    if (!isCashier) ...[
      if (!collapsed) const _NavSectionLabel(label: 'PURCHASES'),
      ..._purchasesNavItems.map((item) => _SidebarNavItem(item: item, collapsed: collapsed)),
      KSpacing.vGapMd,
      if (!collapsed) const _NavSectionLabel(label: 'ACCOUNTING'),
      ..._accountingNavItems.map((item) => _SidebarNavItem(item: item, collapsed: collapsed)),
      KSpacing.vGapMd,
    ],
    if (!collapsed) const _NavSectionLabel(label: 'MORE'),
    ..._secondaryNavItems
        .where((item) => !isCashier || item.route == Routes.settings || item.route == Routes.pos)
        .map((item) => _SidebarNavItem(item: item, collapsed: collapsed)),
  ];
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
  for (final other in [..._navItems, ..._salesNavItems, ..._purchasesNavItems, ..._accountingNavItems, ..._secondaryNavItems]) {
    if (other.route == itemRoute) continue;
    if (other.route.length > itemRoute.length && matchesSelfOrChild(other.route)) {
      return false;
    }
  }
  return true;
}

class _SidebarNavItem extends StatelessWidget {
  final NavItem item;
  final bool collapsed;

  const _SidebarNavItem({required this.item, this.collapsed = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final isActive = _isNavActive(currentRoute, item.route);

    final tile = Material(
      color: isActive ? cs.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go(item.route),
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 0 : 12, vertical: 11),
          child: collapsed
              ? Center(
                  child: Icon(
                    isActive ? item.activeIcon : item.icon,
                    color: isActive ? cs.primary : cs.onSurfaceVariant,
                    size: 22,
                  ),
                )
              : Row(
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
                        overflow: TextOverflow.clip,
                        softWrap: false,
                        style: TextStyle(
                          color:
                              isActive ? cs.onPrimaryContainer : cs.onSurface,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w500,
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
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: collapsed
          ? Tooltip(
              message: item.label,
              waitDuration: const Duration(milliseconds: 400),
              child: tile,
            )
          : tile,
    );
  }
}

/// Ask-AI button — expanded variant is a full-width gradient pill with
/// label; collapsed variant is a 40×40 gradient square with just the icon.
///
/// The gradient uses brand seeds directly so the "AI moment" stays brand-
/// colored even when hosted inside a sidebar running on a different palette.
class _AskAiButton extends StatelessWidget {
  final bool collapsed;
  final VoidCallback onTap;

  const _AskAiButton({required this.collapsed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (!collapsed) {
      return KAssistantFab(onTap: onTap);
    }
    return Tooltip(
      message: 'Ask AI',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(KSpacing.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KSpacing.radiusMd),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [KColors.brandSeed, KColors.accentSeed],
              ),
              borderRadius: BorderRadius.circular(KSpacing.radiusMd),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tablet: Rail navigation + content ────────────────────────────────

class _TabletShell extends ConsumerWidget {
  final Widget child;

  const _TabletShell({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final notifCount =
        ref.watch(unreadCountProvider).valueOrNull ?? 0;

    int selectedIndex = _navItems.indexWhere(
      (item) =>
          currentRoute == item.route ||
          (item.route != '/' && currentRoute.startsWith(item.route)),
    );
    if (selectedIndex < 0) selectedIndex = 0;

    return Scaffold(
      body: Column(
        children: [
          KTopBar(
            notificationCount: notifCount,
            onNotifications: () => context.push(Routes.notifications),
          ),
          Expanded(
            child: Row(
              children: [
                _SidebarTheme(
                  child: Builder(builder: (context) {
                    final scs = Theme.of(context).colorScheme;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        NavigationRail(
                          selectedIndex: selectedIndex,
                          backgroundColor: scs.surface,
                          indicatorColor: scs.primaryContainer,
                          indicatorShape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onDestinationSelected: (index) {
                            context.go(_navItems[index].route);
                          },
                          labelType: NavigationRailLabelType.all,
                          leading: const Padding(
                            padding: EdgeInsets.only(top: 12, bottom: 12),
                            child: KQuickCreateMenu(expanded: false),
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
                          color: scs.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ],
                    );
                  }),
                ),
                Expanded(child: child),
              ],
            ),
          ),
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

// ── Org Switcher ──────────────────────────────────────────────────────

void _showOrgSwitcher(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ProviderScope(
      parent: ProviderScope.containerOf(context),
      child: const _OrgSwitcherSheet(),
    ),
  );
}

class _OrgSwitcherSheet extends ConsumerStatefulWidget {
  const _OrgSwitcherSheet();

  @override
  ConsumerState<_OrgSwitcherSheet> createState() => _OrgSwitcherSheetState();
}

class _OrgSwitcherSheetState extends ConsumerState<_OrgSwitcherSheet> {
  bool _switching = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final orgsAsync = ref.watch(myOrgsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Switch Organisation',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            orgsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Failed to load organisations',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error),
                ),
              ),
              data: (orgs) => Column(
                children: orgs.map((org) {
                  final orgId = org['orgId'] as String;
                  final orgName = org['orgName'] as String? ?? 'Organisation';
                  final role = org['role'] as String? ?? '';
                  final isCurrent = orgId == authState.orgId;

                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: isCurrent
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Text(
                        orgName[0].toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isCurrent
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    title: Text(orgName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(role,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        )),
                    trailing: isCurrent
                        ? Icon(Icons.check_circle_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20)
                        : null,
                    onTap: isCurrent || _switching
                        ? null
                        : () => _doSwitch(orgId),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 24),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: CircleAvatar(
                radius: 20,
                backgroundColor:
                    Theme.of(context).colorScheme.secondaryContainer,
                child: Icon(
                  Icons.add_rounded,
                  color: Theme.of(context).colorScheme.secondary,
                  size: 20,
                ),
              ),
              title: const Text('Add New Organisation',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Create a separate workspace'),
              onTap: _switching
                  ? null
                  : () {
                      Navigator.pop(context);
                      context.go(Routes.onboardingBusinessType);
                    },
            ),
            if (_switching)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _doSwitch(String targetOrgId) async {
    setState(() => _switching = true);
    final authRepo = ref.read(authRepositoryProvider);
    final success = await ref.read(authProvider.notifier).switchOrg(
          targetOrgId: targetOrgId,
          switchFn: authRepo.switchOrg,
        );
    if (!mounted) return;
    if (success) {
      // Clear org-scoped providers that survive navigation (not autoDispose or
      // kept alive by the shell). Screen-specific autoDispose providers clear
      // themselves when the screen unmounts via context.go().
      ref.invalidate(unreadCountProvider);
      ref.invalidate(dashboardFilterProvider);
      Navigator.pop(context);
      context.go(Routes.dashboard);
    } else {
      setState(() => _switching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to switch organisation')),
      );
    }
  }
}

// ── Notification Bell ─────────────────────────────────────────────────
// The standalone NotificationBell widget lives in
// features/notifications/presentation/notification_bell.dart and is
// used by KTopBar (desktop/tablet). The private _NotificationBell class
// that was previously here has been replaced by the public widget.
