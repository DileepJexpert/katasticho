import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/k_colors.dart';
import '../../../../core/theme/k_spacing.dart';
import '../../../../core/theme/k_typography.dart';
import '../../../../core/widgets/k_card.dart';
import '../../data/demo_info_repository.dart';

/// "Demo credentials" card shown on the login screen when the backend reports
/// `app.demo.enabled=true` — surfaces the 8 demo logins so the demo-er doesn't
/// have to dig phone numbers out of a doc. One tap fills the form.
///
/// When demo mode is off (or the endpoint fails), this widget renders nothing.
class DemoCredentialsCard extends ConsumerStatefulWidget {
  /// Invoked with the tapped row's phone + password so the parent can fill
  /// its [TextEditingController]s.
  final void Function(String phone, String password) onPick;

  const DemoCredentialsCard({super.key, required this.onPick});

  @override
  ConsumerState<DemoCredentialsCard> createState() =>
      _DemoCredentialsCardState();
}

class _DemoCredentialsCardState extends ConsumerState<DemoCredentialsCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final demoAsync = ref.watch(demoInfoProvider);
    return demoAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (info) {
        if (!info.enabled || info.users.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: KSpacing.md),
          child: KCard(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            borderColor: KColors.brandSeed.withValues(alpha: 0.35),
            backgroundColor: KColors.brandSeed.withValues(alpha: 0.04),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _Header(
                  orgName: info.orgName,
                  count: info.users.length,
                  expanded: _expanded,
                  onToggle: () => setState(() => _expanded = !_expanded),
                ),
                if (_expanded) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Tap a row to fill the form. Password for every user is '
                    '${info.users.first.password}.',
                    style: KTypography.caption.copyWith(
                      color: KColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...info.users.map(
                    (u) => _LoginRow(
                      login: u,
                      onTap: () => widget.onPick(u.phone, u.password),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final String orgName;
  final int count;
  final bool expanded;
  final VoidCallback onToggle;
  const _Header({
    required this.orgName,
    required this.count,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(KSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(Icons.bolt_rounded, size: 16, color: KColors.brandSeed),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Demo credentials · $orgName',
                style: KTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: KColors.brandSeed,
                ),
              ),
            ),
            Text(
              '$count users',
              style: KTypography.caption.copyWith(
                color: KColors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: KColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginRow extends StatelessWidget {
  final DemoLogin login;
  final VoidCallback onTap;
  const _LoginRow({required this.login, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            _RolePill(role: login.role),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(login.fullName, style: KTypography.bodySmall),
                  KTypography.mono(
                    login.phone,
                    fontSize: 11,
                    color: KColors.textSecondary,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Copy phone',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: Icon(Icons.copy_rounded, size: 14, color: KColors.textSecondary),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: login.phone));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied ${login.phone}'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
            Icon(
              Icons.touch_app_outlined,
              size: 14,
              color: KColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  final String role;
  const _RolePill({required this.role});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (role) {
      case 'OWNER':
        color = KColors.brandSeed;
        break;
      case 'ADMIN':
        color = KColors.info;
        break;
      case 'ACCOUNTANT':
        color = KColors.secondary;
        break;
      case 'VIEWER':
        color = KColors.textHint;
        break;
      default:
        color = KColors.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(KSpacing.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        role,
        style: KTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 9,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
