import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../data/dashboard_repository.dart';

class RecentJournalsWidget extends ConsumerWidget {
  const RecentJournalsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recentJournalsProvider);

    return async.when(
      loading: () => const KCard(
        title: 'Recent Journal Entries',
        child: SizedBox(height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (err, _) => KCard(
        title: 'Recent Journal Entries',
        child: KErrorBanner(message: 'Failed to load: $err'),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return const KCard(
            title: 'Recent Journal Entries',
            child: KEmptyState(
              icon: Icons.menu_book_outlined,
              title: 'No entries yet',
              subtitle: 'Journal entries will appear here',
            ),
          );
        }

        final cs = Theme.of(context).colorScheme;
        final dateFmt = DateFormat('dd MMM');

        return KCard(
          title: 'Recent Journal Entries',
          action: TextButton(
            onPressed: () => context.go('/accounting/journal-entries'),
            child: const Text('View All'),
          ),
          child: Column(
            children: entries.take(5).map((je) {
              final isPosted = je.status == 'POSTED';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: (isPosted ? KColors.success : KColors.draft).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        isPosted ? Icons.check_circle_outline : Icons.edit_note,
                        size: 16,
                        color: isPosted ? KColors.success : KColors.draft,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            je.entryNumber,
                            style: KTypography.labelMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            je.description ?? je.sourceModule,
                            style: KTypography.labelSmall.copyWith(
                              color: cs.onSurfaceVariant, fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.formatCompact(je.totalDebit),
                          style: KTypography.amountSmall,
                        ),
                        Text(
                          dateFmt.format(je.effectiveDate),
                          style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
