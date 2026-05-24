import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../routing/app_router.dart';
import '../data/drug_license_repository.dart';

/// Shows on the pharmacy dashboard when any license is expiring within 60 days.
/// Returns [SizedBox.shrink] if all licenses are valid or there are none.
class DrugLicenseAlertCard extends ConsumerWidget {
  const DrugLicenseAlertCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expiringAsync = ref.watch(expiringLicensesProvider);

    return expiringAsync.when(
      // Show nothing while loading or on error — avoid disrupting the dashboard
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (licenses) {
        // Filter to only show non-OK licenses
        final alertLicenses = licenses
            .where((l) =>
                (l['status']?.toString().toUpperCase() ?? 'OK') != 'OK')
            .toList();

        if (alertLicenses.isEmpty) return const SizedBox.shrink();

        // Determine the worst status across all alert licenses
        final hasExpiredOrCritical = alertLicenses.any((l) {
          final s = l['status']?.toString().toUpperCase() ?? '';
          return s == 'EXPIRED' || s == 'CRITICAL';
        });

        final cardColor =
            hasExpiredOrCritical ? KColors.errorLight : KColors.warningLight;
        final borderColor =
            hasExpiredOrCritical ? KColors.error : KColors.warning;
        final iconColor =
            hasExpiredOrCritical ? KColors.error : KColors.warning;
        final icon = hasExpiredOrCritical
            ? Icons.error_outline
            : Icons.warning_amber_rounded;
        final titleText = hasExpiredOrCritical
            ? '${alertLicenses.length} License${alertLicenses.length == 1 ? '' : 's'} Expired / Critical'
            : '${alertLicenses.length} License${alertLicenses.length == 1 ? '' : 's'} Expiring Soon';

        return Container(
          margin: const EdgeInsets.symmetric(
              horizontal: KSpacing.md, vertical: KSpacing.sm),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: KSpacing.borderRadiusMd,
            border: Border.all(
              color: borderColor.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    KSpacing.md, KSpacing.md, KSpacing.md, KSpacing.sm),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: iconColor),
                    KSpacing.hGapSm,
                    Expanded(
                      child: Text(
                        titleText,
                        style: KTypography.h4.copyWith(color: iconColor),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        if (context.mounted) {
                          context.push(Routes.drugLicenses);
                        }
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: iconColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: KSpacing.sm),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Manage'),
                    ),
                  ],
                ),
              ),
              // License list (up to 3 shown)
              ...alertLicenses.take(3).map((l) => _AlertLicenseRow(license: l)),
              if (alertLicenses.length > 3)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      KSpacing.md, 0, KSpacing.md, KSpacing.sm),
                  child: Text(
                    '+ ${alertLicenses.length - 3} more',
                    style: KTypography.labelSmall.copyWith(color: iconColor),
                  ),
                ),
              KSpacing.vGapSm,
            ],
          ),
        );
      },
    );
  }
}

class _AlertLicenseRow extends StatelessWidget {
  final Map<String, dynamic> license;

  const _AlertLicenseRow({required this.license});

  @override
  Widget build(BuildContext context) {
    final licenseType = license['licenseType']?.toString() ?? '';
    final licenseNumber = license['licenseNumber']?.toString() ?? '';
    final status = license['status']?.toString() ?? 'OK';
    final daysUntilExpiry =
        (license['daysUntilExpiry'] as num?)?.toInt() ?? 0;

    final isExpiredOrCritical =
        status == 'EXPIRED' || status == 'CRITICAL';
    final rowColor =
        isExpiredOrCritical ? KColors.error : KColors.warning;

    const licenseTypeLabels = {
      'DRUG_LICENSE': 'Drug License',
      'FSSAI': 'FSSAI',
      'DEA': 'DEA',
      'WHOLESALE_DRUG': 'Wholesale Drug',
      'RETAIL_DRUG': 'Retail Drug',
    };
    final typeLabel = licenseTypeLabels[licenseType] ?? licenseType;

    String expiryLabel;
    if (status == 'EXPIRED' || daysUntilExpiry < 0) {
      final days = daysUntilExpiry.abs();
      expiryLabel = 'Expired ${days}d ago';
    } else if (daysUntilExpiry == 0) {
      expiryLabel = 'Expires today';
    } else {
      expiryLabel = '${daysUntilExpiry}d left';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          KSpacing.md, 0, KSpacing.md, KSpacing.xs),
      child: Row(
        children: [
          Icon(Icons.circle, size: 6, color: rowColor),
          KSpacing.hGapSm,
          Expanded(
            child: Text(
              '$typeLabel — $licenseNumber',
              style: KTypography.bodySmall.copyWith(
                color: rowColor,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          KSpacing.hGapSm,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: rowColor.withValues(alpha: 0.15),
              borderRadius: KSpacing.borderRadiusXs,
            ),
            child: Text(
              expiryLabel,
              style: KTypography.labelSmall.copyWith(
                color: rowColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
