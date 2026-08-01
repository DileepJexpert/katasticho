import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../commands/command_registry.dart';
import '../auth/auth_state.dart';
import '../shortcuts/k_shortcuts.dart';
import '../shell/shell_providers.dart';
import '../theme/k_spacing.dart';
import '../theme/k_typography.dart';
import 'brand_palette_switcher.dart';
import 'language_switcher.dart';
import 'k_command_palette.dart';
import 'k_quick_create_menu.dart';
import 'theme_mode_switcher.dart';

/// Full-width top bar — **Katasticho 2026 / Phase 4**.
///
/// Contains (left → right):
///   [≡]  collapse toggle
///   [Katasticho]  brand name (hidden when sidebar is expanded — sidebar owns it)
///   [Search ⌘K]  clickable pill that opens the command palette
///   [+]  Quick Create icon-button
///   [🔔]  notifications
///   [☀]  theme toggle
///
/// Sits above the Row(sidebar, content) in the desktop shell only.
class KTopBar extends ConsumerWidget implements PreferredSizeWidget {
  final VoidCallback? onNotifications;
  final int notificationCount;

  const KTopBar({
    super.key,
    this.onNotifications,
    this.notificationCount = 0,
  });

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final collapsed = ref.watch(sidebarCollapsedProvider);
    final auth = ref.watch(authProvider);
    final industry = (auth.industryCode ?? auth.industry ?? '').toUpperCase();
    final isPharma =
        industry == 'PHARMACY' || industry.contains('PHARMA');

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.4 : 0.6),
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            // Sidebar collapse toggle
            IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  collapsed ? Icons.menu_open_rounded : Icons.menu_rounded,
                  key: ValueKey(collapsed),
                  size: 19,
                ),
              ),
              color: cs.onSurfaceVariant,
              tooltip: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
              visualDensity: VisualDensity.compact,
              onPressed: () =>
                  ref.read(sidebarCollapsedProvider.notifier).toggle(),
            ),

            // Brand name (only when sidebar collapsed)
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: collapsed
                  ? Padding(
                      padding: const EdgeInsets.only(left: 4, right: 12),
                      child: Text(
                        'Katasticho',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // ⌘K Search pill
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: GestureDetector(
                    onTap: () => KCommandPalette.show(
                      context,
                      commands: buildAppCommands(isPharma: isPharma),
                    ),
                    child: Container(
                      height: 30,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color:
                            cs.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(KSpacing.radiusMd),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.6),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded,
                              size: 15, color: cs.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Search or jump to...',
                              style: KTypography.bodySmall.copyWith(
                                color:
                                    cs.onSurfaceVariant.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: cs.outlineVariant, width: 1),
                            ),
                            child: Text(
                              KShortcuts.commandPalette,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Quick Create +
            const KQuickCreateMenu(expanded: false),

            // Notifications
            if (onNotifications != null)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, size: 19),
                    tooltip: 'Notifications',
                    color: cs.onSurfaceVariant,
                    visualDensity: VisualDensity.compact,
                    onPressed: onNotifications,
                  ),
                  if (notificationCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: IgnorePointer(
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.error,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              notificationCount > 9
                                  ? '9+'
                                  : '$notificationCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),

            // Language + brand palette + theme toggle
            const LanguageSwitcher(),
            const BrandPaletteSwitcher(),
            const ThemeModeIconButton(),
          ],
        ),
      ),
    );
  }
}
