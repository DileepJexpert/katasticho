import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/k_spacing.dart';
import '../theme/k_typography.dart';
import '../../routing/app_router.dart';

/// AI assistant button — renders full-width when placed in a sidebar,
/// or inline when used elsewhere.
class KAssistantFab extends StatelessWidget {
  final VoidCallback onTap;

  const KAssistantFab({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(KSpacing.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KSpacing.radiusMd),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [cs.primary, cs.tertiary],
            ),
            borderRadius: BorderRadius.circular(KSpacing.radiusMd),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                'Ask AI',
                style: KTypography.labelMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quick-launch panel anchored to the bottom-right of the viewport.
///
/// Shows suggested prompts; tapping any of them (or "Open chat") routes
/// to the full AI chat screen.
class KAssistantPanel extends StatelessWidget {
  const KAssistantPanel({super.key});

  static Future<void> show(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.18),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, anim, secondary) {
        return Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 20, bottom: 76),
            child: Material(
              color: Colors.transparent,
              child: const KAssistantPanel(),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, secondary, widget) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(position: offset, child: widget),
        );
      },
    );
  }

  static const _suggestions = [
    ("What's my total revenue this month?", Icons.trending_up_rounded),
    ('Show me overdue invoices', Icons.warning_amber_rounded),
    ("What's my cash balance?", Icons.account_balance_wallet_rounded),
    ('Compare this month vs last', Icons.compare_arrows_rounded),
  ];

  void _open(BuildContext context, [String? prompt]) {
    Navigator.of(context).pop();
    context.go(Routes.aiChat);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(KSpacing.radiusXl);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: radius,
          border: Border.all(color: cs.outlineVariant, width: 1),
          boxShadow: KSpacing.shadowLg,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.primary.withValues(alpha: 0.1),
                      cs.tertiary.withValues(alpha: 0.06),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [cs.primary, cs.tertiary],
                        ),
                        borderRadius:
                            BorderRadius.circular(KSpacing.radiusMd),
                      ),
                      child: const Icon(Icons.auto_awesome_rounded,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Ask AI',
                            style: KTypography.h4.copyWith(
                              color: cs.onSurface,
                            ),
                          ),
                          Text(
                            'Your finance assistant',
                            style: KTypography.bodySmall.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: cs.onSurfaceVariant,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1, color: cs.outlineVariant),

              // Suggestions
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Text(
                  'TRY ASKING',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
              ..._suggestions.map(
                (s) => _SuggestionRow(
                  label: s.$1,
                  icon: s.$2,
                  onTap: () => _open(context, s.$1),
                ),
              ),

              // Footer CTA
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Material(
                  color: cs.primary,
                  borderRadius:
                      BorderRadius.circular(KSpacing.radiusMd),
                  child: InkWell(
                    borderRadius:
                        BorderRadius.circular(KSpacing.radiusMd),
                    onTap: () => _open(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                              size: 16, color: cs.onPrimary),
                          const SizedBox(width: 8),
                          Text(
                            'Open full chat',
                            style: KTypography.button.copyWith(
                              color: cs.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SuggestionRow({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Icon(icon, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: KTypography.bodyMedium.copyWith(
                  color: cs.onSurface,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_rounded,
                size: 14, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
