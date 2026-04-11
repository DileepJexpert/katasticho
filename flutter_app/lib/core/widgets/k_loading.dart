import 'package:flutter/material.dart';
import '../theme/k_colors.dart';
import '../theme/k_spacing.dart';

/// Full-page loading indicator.
class KLoading extends StatelessWidget {
  final String? message;

  const KLoading({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: KColors.primary),
          if (message != null) ...[
            KSpacing.vGapMd,
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: KColors.textSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shimmer loading placeholder for cards.
class KShimmerCard extends StatelessWidget {
  final double? height;
  final double? width;

  const KShimmerCard({super.key, this.height, this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height ?? 100,
      width: width ?? double.infinity,
      decoration: BoxDecoration(
        color: KColors.divider.withValues(alpha: 0.3),
        borderRadius: KSpacing.borderRadiusMd,
      ),
    );
  }
}

/// Shimmer list for loading states.
class KShimmerList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const KShimmerList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 80,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: KSpacing.pagePadding,
      itemCount: itemCount,
      separatorBuilder: (_, __) => KSpacing.vGapSm,
      itemBuilder: (_, __) => KShimmerCard(height: itemHeight),
    );
  }
}
