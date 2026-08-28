import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../data/debit_note_repository.dart';

class DebitNoteDetailScreen extends ConsumerWidget {
  final String debitNoteId;

  const DebitNoteDetailScreen({super.key, required this.debitNoteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteAsync = ref.watch(debitNoteDetailProvider(debitNoteId));

    return Scaffold(
      appBar: AppBar(
        title: noteAsync.maybeWhen(
          data: (n) =>
              Text(n['debitNoteNumber'] as String? ?? 'Debit Note'),
          orElse: () => const Text('Debit Note'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.debitNotes),
        ),
        actions: [
          noteAsync.maybeWhen(
            data: (note) {
              final status = note['status'] as String? ?? '';
              if (status != 'DRAFT') return const SizedBox.shrink();
              return PopupMenuButton<String>(
                onSelected: (v) =>
                    _handleMenuAction(context, ref, note, v),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete',
                        style: TextStyle(color: KColors.error)),
                  ),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: noteAsync.when(
        loading: () => const KLoading(message: 'Loading debit note...'),
        error: (err, st) {
          debugPrint('[DNDetail] ERROR: $err\n$st');
          return KErrorView(
            message: 'Failed to load debit note',
            onRetry: () =>
                ref.invalidate(debitNoteDetailProvider(debitNoteId)),
          );
        },
        data: (note) => _DnBody(note: note),
      ),
      bottomNavigationBar: noteAsync.whenOrNull(
        data: (note) {
          final status = note['status'] as String? ?? '';
          if (status != 'DRAFT') return null;

          return Container(
            padding: const EdgeInsets.all(KSpacing.md),
            decoration: BoxDecoration(
              color: KColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Total', style: KTypography.bodySmall),
                      KMoney(
                        (note['totalAmount'] as num?)?.toDouble() ?? 0,
                        size: KMoneySize.large,
                        style: const TextStyle(
                          color: KColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  KButton.primary(
                    label: 'Submit',
                    icon: Icons.send_outlined,
                    onPressed: () => _confirmSubmit(context, ref, note),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleMenuAction(BuildContext context, WidgetRef ref,
      Map<String, dynamic> note, String action) async {
    if (action == 'delete') {
      await _confirmDelete(context, ref, note);
    }
  }

  Future<void> _confirmSubmit(
      BuildContext context, WidgetRef ref, Map<String, dynamic> note) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit Debit Note?'),
        content: const Text(
          'This will send the debit note to the supplier for acceptance. '
          'You will not be able to edit it after submission.',
        ),
        actions: [
          KButton.outlined(
            label: 'Cancel',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          KSpacing.hGapSm,
          KButton.primary(
            label: 'Submit',
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final repo = ref.read(debitNoteRepositoryProvider);
      await repo.submit(note['id']?.toString() ?? '');
      ref.invalidate(debitNoteDetailProvider(debitNoteId));
      ref.invalidate(debitNotesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debit note submitted')),
        );
      }
    } catch (e) {
      debugPrint('[DNDetail] submit failed: $e');
      final msg = _extractError(e, 'Failed to submit debit note');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: KColors.error),
        );
      }
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Map<String, dynamic> note) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Debit Note?'),
        content: const Text(
          'This will permanently delete the draft debit note. '
          'This action cannot be undone.',
        ),
        actions: [
          KButton.outlined(
            label: 'Cancel',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          KSpacing.hGapSm,
          KButton.danger(
            label: 'Delete',
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final repo = ref.read(debitNoteRepositoryProvider);
      await repo.delete(note['id']?.toString() ?? '');
      ref.invalidate(debitNotesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debit note deleted')),
        );
        context.go(Routes.debitNotes);
      }
    } catch (e) {
      debugPrint('[DNDetail] delete failed: $e');
      final msg = _extractError(e, 'Failed to delete debit note');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: KColors.error),
        );
      }
    }
  }

  String _extractError(Object e, String fallback) {
    if (e is DioException) {
      final body = e.response?.data;
      if (body is Map) {
        return body['message'] as String? ??
            body['error'] as String? ??
            fallback;
      }
    }
    return fallback;
  }
}

// ── Body ──

class _DnBody extends StatelessWidget {
  final Map<String, dynamic> note;
  const _DnBody({required this.note});

  @override
  Widget build(BuildContext context) {
    final dnNumber = note['debitNoteNumber'] as String? ?? '--';
    final status = note['status'] as String? ?? 'DRAFT';
    final supplierName =
        note['supplierName'] as String? ?? 'Unknown supplier';
    final noteDateRaw = note['noteDate'] as String?;
    final returnReason = note['returnReason'] as String?;
    final referenceBillId = note['referenceBillId'] as String?;
    final notes = note['notes'] as String?;
    final subtotal = (note['subtotal'] as num?)?.toDouble() ?? 0;
    final taxAmount = (note['taxAmount'] as num?)?.toDouble() ?? 0;
    final totalAmount = (note['totalAmount'] as num?)?.toDouble() ?? 0;
    final lines =
        (note['lines'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return ListView(
      padding: KSpacing.pagePadding,
      children: [
        // ── Document header ──
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: KSpacing.borderRadiusLg,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: KDocumentHeader(
            title: dnNumber,
            subtitle: supplierName,
            status: KStatusChip(status: status),
            amount: CurrencyFormatter.formatIndian(totalAmount),
            icon: Icons.assignment_return_outlined,
            metrics: [
              KDocumentHeaderMetric(
                label: 'Lines',
                value: lines.length.toString(),
                icon: Icons.format_list_numbered,
              ),
              KDocumentHeaderMetric(
                label: 'Total',
                value: CurrencyFormatter.formatIndian(totalAmount),
                icon: Icons.currency_rupee_outlined,
              ),
            ],
          ),
        ),
        KSpacing.vGapMd,

        // ── Info panel ──
        KCard(
          title: 'Note Information',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KDetailRow(label: 'Supplier', value: supplierName),
              if (noteDateRaw != null)
                KDetailRow(
                  label: 'Note Date',
                  value: DateFormatter.display(DateTime.parse(noteDateRaw)),
                ),
              if (returnReason != null)
                KDetailRow(
                  label: 'Return Reason',
                  value: _formatReason(returnReason),
                ),
              if (referenceBillId != null && referenceBillId.isNotEmpty)
                KDetailRow(
                  label: 'Reference Bill',
                  value: referenceBillId,
                ),
              if (status == 'SUBMITTED') ...[
                KSpacing.vGapMd,
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(KSpacing.md),
                  decoration: BoxDecoration(
                    color: KColors.infoLight,
                    borderRadius:
                        BorderRadius.circular(KSpacing.radiusMd),
                    border: Border.all(
                        color: KColors.info.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: KColors.info, size: 18),
                      KSpacing.hGapSm,
                      Expanded(
                        child: Text(
                          'Awaiting supplier acceptance',
                          style: KTypography.bodyMedium
                              .copyWith(color: KColors.info),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (notes != null && notes.isNotEmpty) ...[
                KSpacing.vGapMd,
                _TextBlock(title: 'Notes', value: notes),
              ],
            ],
          ),
        ),
        KSpacing.vGapMd,

        // ── Lines table ──
        _DnLinesPanel(lines: lines),
        KSpacing.vGapMd,

        // ── Summary ──
        KCard(
          title: 'Summary',
          child: Column(
            children: [
              _DetailSummaryRow(label: 'Subtotal', amount: subtotal),
              _DetailSummaryRow(label: 'Tax', amount: taxAmount),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: KTypography.labelLarge.copyWith(fontWeight: FontWeight.w700)),
                  KMoney(
                    totalAmount,
                    size: KMoneySize.medium,
                    style: const TextStyle(
                      color: KColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        KSpacing.vGapLg,
      ],
    );
  }
}

// ── Lines table panel ──

class _DnLinesPanel extends StatelessWidget {
  final List<Map<String, dynamic>> lines;
  const _DnLinesPanel({required this.lines});

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return const KCard(
        title: 'Return Items',
        child: KEmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'No items on this debit note',
          subtitle: 'Items will appear here once added.',
        ),
      );
    }

    return KCard(
      title: 'Return Items',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: KSpacing.lg,
          headingRowHeight: 44,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 80,
          columns: const [
            DataColumn(label: Text('Item')),
            DataColumn(label: Text('Batch')),
            DataColumn(label: Text('Expiry')),
            DataColumn(label: Text('Qty'), numeric: true),
            DataColumn(label: Text('Rate'), numeric: true),
            DataColumn(label: Text('Tax %'), numeric: true),
            DataColumn(label: Text('Tax Amt'), numeric: true),
            DataColumn(label: Text('Total'), numeric: true),
          ],
          rows: lines.map((line) {
            final desc =
                line['description'] as String? ?? 'Item';
            final batchNumber =
                line['batchNumber'] as String? ?? '--';
            final expiryRaw = line['expiryDate'] as String?;
            final qty = (line['quantity'] as num?)?.toDouble() ?? 0;
            final unitPrice =
                (line['unitPrice'] as num?)?.toDouble() ?? 0;
            final taxRate =
                (line['taxRate'] as num?)?.toDouble() ?? 0;
            final taxAmt =
                (line['taxAmount'] as num?)?.toDouble() ?? 0;
            final lineTotal =
                (line['lineTotal'] as num?)?.toDouble() ?? 0;

            final qtyFmt = qty.toStringAsFixed(
                qty.truncateToDouble() == qty ? 0 : 2);

            String expiryDisplay = '--';
            if (expiryRaw != null && expiryRaw.isNotEmpty) {
              try {
                expiryDisplay = DateFormatter.display(
                    DateTime.parse(expiryRaw));
              } catch (_) {
                expiryDisplay = expiryRaw;
              }
            }

            return DataRow(
              cells: [
                DataCell(
                  ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: 200),
                    child: Text(desc,
                        style: KTypography.bodyMedium,
                        overflow: TextOverflow.ellipsis),
                  ),
                ),
                DataCell(Text(batchNumber,
                    style: KTypography.bodySmall)),
                DataCell(Text(expiryDisplay,
                    style: KTypography.bodySmall)),
                DataCell(Text(qtyFmt)),
                DataCell(KMoney(unitPrice, size: KMoneySize.small)),
                DataCell(Text(
                    '${taxRate.toStringAsFixed(taxRate.truncateToDouble() == taxRate ? 0 : 1)}%')),
                DataCell(KMoney(taxAmt, size: KMoneySize.small)),
                DataCell(KMoney(
                  lineTotal,
                  size: KMoneySize.small,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                )),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Helpers ──

String _formatReason(String? reason) {
  return switch (reason) {
    'EXPIRED' => 'Expired Medicines',
    'DAMAGED' => 'Damaged',
    'WRONG_ITEM' => 'Wrong Item Received',
    'QUALITY_ISSUE' => 'Quality Issue',
    'EXCESS_STOCK' => 'Excess Stock',
    _ => reason ?? '--',
  };
}

class _TextBlock extends StatelessWidget {
  final String title;
  final String value;

  const _TextBlock({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(KSpacing.radiusMd),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: KTypography.labelMedium),
          KSpacing.vGapXs,
          Text(value, style: KTypography.bodyMedium),
        ],
      ),
    );
  }
}

class _DetailSummaryRow extends StatelessWidget {
  final String label;
  final double amount;

  const _DetailSummaryRow({
    required this.label,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: KTypography.bodyMedium.copyWith(color: KColors.textSecondary)),
          KMoney(amount, size: KMoneySize.small),
        ],
      ),
    );
  }
}
