import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../routing/app_router.dart';
import '../data/credit_note_providers.dart';

class CreditNoteListScreen extends ConsumerWidget {
  const CreditNoteListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creditNotesAsync = ref.watch(creditNoteListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Credit Notes'),
      ),
      body: creditNotesAsync.when(
        loading: () => const KShimmerList(),
        error: (err, _) => KErrorView(
          message: 'Failed to load credit notes',
          onRetry: () => ref.invalidate(creditNoteListProvider),
        ),
        data: (data) {
          final content = data['data'];
          if (content == null) {
            return KEmptyState(
              icon: Icons.note_alt_outlined,
              title: 'No credit notes yet',
              subtitle: 'Create a credit note to issue refunds or adjustments',
              actionLabel: 'Create Credit Note',
              onAction: () => context.go(Routes.creditNoteCreate),
            );
          }

          final creditNotes = (content is List)
              ? content
              : (content['content'] as List?) ?? [];

          if (creditNotes.isEmpty) {
            return KEmptyState(
              icon: Icons.note_alt_outlined,
              title: 'No credit notes found',
              subtitle: 'Create a credit note to get started',
              actionLabel: 'Create Credit Note',
              onAction: () => context.go(Routes.creditNoteCreate),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(creditNoteListProvider),
            child: ListView.separated(
              padding: KSpacing.pagePadding,
              itemCount: creditNotes.length,
              separatorBuilder: (_, __) => KSpacing.vGapSm,
              itemBuilder: (context, index) {
                final cn = creditNotes[index] as Map<String, dynamic>;
                return _CreditNoteCard(creditNote: cn);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(Routes.creditNoteCreate),
        icon: const Icon(Icons.add),
        label: const Text('New Credit Note'),
      ),
    );
  }
}

class _CreditNoteCard extends StatelessWidget {
  final Map<String, dynamic> creditNote;

  const _CreditNoteCard({required this.creditNote});

  @override
  Widget build(BuildContext context) {
    final status = creditNote['status'] as String? ?? 'DRAFT';
    final totalAmount =
        (creditNote['totalAmount'] as num?)?.toDouble() ?? 0;
    final customerName =
        creditNote['customerName'] as String? ?? 'Unknown';
    final creditNoteNumber =
        creditNote['creditNoteNumber'] as String? ?? '--';
    final invoiceNumber = creditNote['invoiceNumber'] as String?;
    final reason = creditNote['reason'] as String? ?? '';

    return KCard(
      onTap: () {
        final id = creditNote['id']?.toString();
        if (id != null) {
          context.go('/credit-notes/$id');
        }
      },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: KColors.error.withValues(alpha: 0.1),
              borderRadius: KSpacing.borderRadiusMd,
            ),
            child: const Icon(
              Icons.note_alt_outlined,
              color: KColors.error,
              size: 24,
            ),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(creditNoteNumber, style: KTypography.labelLarge),
                    KSpacing.hGapSm,
                    KStatusChip(status: status),
                  ],
                ),
                KSpacing.vGapXs,
                Text(
                  customerName,
                  style: KTypography.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                if (invoiceNumber != null) ...[
                  KSpacing.vGapXs,
                  Text(
                    'Against: $invoiceNumber',
                    style: KTypography.bodySmall,
                  ),
                ],
                if (reason.isNotEmpty) ...[
                  KSpacing.vGapXs,
                  Text(
                    reason,
                    style: KTypography.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Text(
            CurrencyFormatter.formatIndian(totalAmount),
            style: KTypography.amountMedium.copyWith(
              color: KColors.error,
            ),
          ),
          KSpacing.hGapSm,
          const Icon(Icons.chevron_right, color: KColors.textHint),
        ],
      ),
    );
  }
}
