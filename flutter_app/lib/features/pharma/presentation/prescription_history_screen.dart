import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';
import '../data/prescription_repository.dart';
import 'add_prescription_screen.dart';

class PrescriptionHistoryScreen extends ConsumerWidget {
  final String contactId;
  final String? contactName;

  const PrescriptionHistoryScreen({
    super.key,
    required this.contactId,
    this.contactName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPrescriptions =
        ref.watch(contactPrescriptionsProvider(contactId));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Prescription History', style: KTypography.h3),
            if (contactName != null)
              Text(contactName!,
                  style: KTypography.bodySmall
                      .copyWith(color: KColors.textSecondary)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add prescription',
            onPressed: () => _openAddScreen(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddScreen(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Prescription'),
        tooltip: 'Add Prescription (N)',
      ),
      body: asyncPrescriptions.when(
        loading: () => const KLoading(),
        error: (err, _) => KErrorView(message: ApiErrorParser.message(err)),
        data: (prescriptions) {
          if (prescriptions.isEmpty) {
            return _EmptyState(
              onAdd: () => _openAddScreen(context, ref),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
                KSpacing.md, KSpacing.md, KSpacing.md, 100),
            itemCount: prescriptions.length,
            separatorBuilder: (_, __) => const SizedBox(height: KSpacing.sm),
            itemBuilder: (context, index) {
              final rx = prescriptions[index];
              return _PrescriptionTile(
                prescription: rx,
                onDelete: () => _confirmDelete(context, ref, rx),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openAddScreen(BuildContext context, WidgetRef ref) async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddPrescriptionScreen(
          contactId: contactId,
          contactName: contactName,
        ),
      ),
    );
    if (added == true) {
      ref.invalidate(contactPrescriptionsProvider(contactId));
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> rx,
  ) async {
    final rxNumber = rx['prescriptionNumber']?.toString() ?? 'this prescription';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Prescription?'),
        content: Text('Remove Rx $rxNumber? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: KColors.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    final id = rx['id']?.toString();
    if (id == null) return;

    try {
      await ref.read(prescriptionRepositoryProvider).delete(id);
      ref.invalidate(contactPrescriptionsProvider(contactId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiErrorParser.message(e)),
            backgroundColor: KColors.error,
          ),
        );
      }
    }
  }
}

// ── Empty state ───────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 64, color: KColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: KSpacing.md),
            Text(
              'No prescriptions recorded for this patient',
              style: KTypography.bodyMedium.copyWith(color: KColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: KSpacing.lg),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add Prescription'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Prescription tile with swipe-to-delete ────────────────────

class _PrescriptionTile extends StatelessWidget {
  final Map<String, dynamic> prescription;
  final VoidCallback onDelete;

  const _PrescriptionTile({
    required this.prescription,
    required this.onDelete,
  });

  bool _isValid() {
    final validUntilStr = prescription['validUntil'] as String?;
    if (validUntilStr == null) return true;
    try {
      final validUntil = DateTime.parse(validUntilStr);
      return validUntil.isAfter(DateTime.now());
    } catch (_) {
      return true;
    }
  }

  String _fmtDate(String? isoDate) {
    if (isoDate == null) return '—';
    try {
      final d = DateTime.parse(isoDate);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rxNumber =
        prescription['prescriptionNumber']?.toString() ?? 'No Rx';
    final doctorName = prescription['doctorName']?.toString();
    final prescribedDate = prescription['prescribedDate'] as String?;
    final items = prescription['items'];
    final itemNames = items is List
        ? items
            .map((i) => (i as Map<String, dynamic>)['itemName']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .join(', ')
        : null;

    final valid = _isValid();

    return Dismissible(
      key: ValueKey(prescription['id']),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false; // we handle list refresh ourselves via provider invalidation
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: KSpacing.md),
        decoration: BoxDecoration(
          color: KColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: KColors.error),
      ),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ─────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Rx: $rxNumber',
                      style: KTypography.bodyLarge
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: KSpacing.sm),
                  _ValidityChip(valid: valid),
                ],
              ),
              // ── Doctor ─────────────────────────────────────
              if (doctorName != null && doctorName.isNotEmpty) ...[
                const SizedBox(height: KSpacing.xs),
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 14, color: KColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'Dr. $doctorName',
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textSecondary),
                    ),
                  ],
                ),
              ],
              // ── Date ───────────────────────────────────────
              if (prescribedDate != null) ...[
                const SizedBox(height: KSpacing.xs),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 14, color: KColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      _fmtDate(prescribedDate),
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textSecondary),
                    ),
                  ],
                ),
              ],
              // ── Items ──────────────────────────────────────
              if (itemNames != null && itemNames.isNotEmpty) ...[
                const SizedBox(height: KSpacing.sm),
                const Divider(height: 1),
                const SizedBox(height: KSpacing.sm),
                Text(
                  itemNames,
                  style: KTypography.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ValidityChip extends StatelessWidget {
  final bool valid;
  const _ValidityChip({required this.valid});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: valid
            ? KColors.success.withValues(alpha: 0.12)
            : KColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        valid ? 'Valid' : 'Expired',
        style: KTypography.labelSmall.copyWith(
          color: valid ? KColors.success : KColors.error,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
