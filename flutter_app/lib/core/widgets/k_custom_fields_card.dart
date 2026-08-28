import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/custom_fields/data/custom_field_repository.dart';
import '../theme/k_colors.dart';
import '../theme/k_spacing.dart';
import '../theme/k_typography.dart';
import 'k_card.dart';

class KCustomFieldsCard extends ConsumerWidget {
  final String entityType;
  final String entityId;
  final String title;

  const KCustomFieldsCard({
    super.key,
    required this.entityType,
    required this.entityId,
    this.title = 'Additional Information (UDF)',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final valuesAsync = ref.watch(
      entityCustomFieldsProvider(
        CustomFieldEntityParam(entityType: entityType, entityId: entityId),
      ),
    );

    return valuesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (values) {
        final filledValues = values.where((v) {
          final disp = v.displayValue;
          return disp.isNotEmpty && disp != '-';
        }).toList();

        if (filledValues.isEmpty) return const SizedBox.shrink();

        return KCard(
          padding: const EdgeInsets.all(KSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: KColors.primary),
                  KSpacing.hGapSm,
                  Text(title, style: KTypography.h4),
                ],
              ),
              KSpacing.vGapMd,
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 500;
                  return Wrap(
                    spacing: KSpacing.lg,
                    runSpacing: KSpacing.md,
                    children: filledValues.map((v) {
                      final itemWidth = isWide
                          ? (constraints.maxWidth - KSpacing.lg) / 2
                          : constraints.maxWidth;
                      return SizedBox(
                        width: itemWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(v.fieldLabel, style: KTypography.caption),
                            KSpacing.vGapXs,
                            Text(v.displayValue, style: KTypography.bodyMedium),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
