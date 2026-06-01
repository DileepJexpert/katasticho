import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';
import '../data/workflow_repository.dart';

class ApprovalInboxScreen extends ConsumerStatefulWidget {
  const ApprovalInboxScreen({super.key});

  @override
  ConsumerState<ApprovalInboxScreen> createState() =>
      _ApprovalInboxScreenState();
}

class _ApprovalInboxScreenState extends ConsumerState<ApprovalInboxScreen> {
  final Set<String> _busyIds = {};

  Future<void> _decide(ApprovalRequest request, bool approve) async {
    final note = await _promptNote(approve);
    if (!mounted) return;
    setState(() => _busyIds.add(request.id));
    try {
      final repo = ref.read(workflowRepositoryProvider);
      if (approve) {
        await repo.approve(request.id, note: note);
      } else {
        await repo.reject(request.id, note: note);
      }
      ref.invalidate(approvalRequestsProvider);
      _showSnack(approve ? 'Approved' : 'Rejected');
    } catch (e) {
      _showSnack(ApiErrorParser.message(e));
    } finally {
      if (mounted) setState(() => _busyIds.remove(request.id));
    }
  }

  Future<String?> _promptNote(bool approve) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'Approve request' : 'Reject request'),
        content: TextField(
          controller: controller,
          autofocus: !approve,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Note',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: !approve
                ? FilledButton.styleFrom(backgroundColor: KColors.error)
                : null,
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(approvalRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Approvals'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(approvalRequestsProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: requestsAsync.when(
        loading: () => const KLoading(),
        error: (e, _) => KErrorView(
          message: 'Failed to load approval requests',
          onRetry: () => ref.invalidate(approvalRequestsProvider),
        ),
        data: (requests) {
          if (requests.isEmpty) {
            return const KEmptyState(
              icon: Icons.fact_check_outlined,
              title: 'No pending approvals',
              subtitle: 'Requests that need your approval will appear here.',
            );
          }

          return ListView.separated(
            padding: KSpacing.pagePadding,
            itemCount: requests.length,
            separatorBuilder: (_, __) => KSpacing.vGapMd,
            itemBuilder: (context, index) {
              final request = requests[index];
              final busy = _busyIds.contains(request.id);
              return _ApprovalRequestCard(
                request: request,
                busy: busy,
                onOpenDocument: () => _openDocument(request),
                onApprove: () => _decide(request, true),
                onReject: () => _decide(request, false),
              );
            },
          );
        },
      ),
    );
  }

  void _openDocument(ApprovalRequest request) {
    if (request.documentType == 'SALES_ORDER') {
      context.push('/sales-orders/${request.documentId}');
      return;
    }
    if (request.documentType == 'PAYMENT') {
      _showSnack('Open the related invoice Payments tab to view this payment');
      return;
    }
    _showSnack('Document view is not available for ${request.documentType}');
  }
}

class _ApprovalRequestCard extends StatelessWidget {
  final ApprovalRequest request;
  final bool busy;
  final VoidCallback onOpenDocument;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ApprovalRequestCard({
    required this.request,
    required this.busy,
    required this.onOpenDocument,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _iconFor(request.documentType),
                  color: cs.onPrimaryContainer,
                ),
              ),
              KSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.workflowName, style: KTypography.h4),
                    const SizedBox(height: 4),
                    Text(
                      '${_label(request.documentType)} - Step ${request.currentStep}',
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textSecondary),
                    ),
                  ],
                ),
              ),
              _PendingChip(status: request.status),
            ],
          ),
          if (request.triggerReason.isNotEmpty) ...[
            KSpacing.vGapMd,
            Text(
              request.triggerReason,
              style: KTypography.bodyMedium.copyWith(height: 1.35),
            ),
          ],
          KSpacing.vGapMd,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: busy ? null : onOpenDocument,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open document'),
              ),
              FilledButton.icon(
                onPressed: busy ? null : onApprove,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('Approve'),
              ),
              TextButton.icon(
                onPressed: busy ? null : onReject,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Reject'),
                style: TextButton.styleFrom(foregroundColor: KColors.error),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _label(String value) {
    return value
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  static IconData _iconFor(String documentType) {
    return switch (documentType) {
      'SALES_ORDER' => Icons.assignment_rounded,
      'CREDIT_NOTE' => Icons.assignment_return_rounded,
      'PAYMENT' => Icons.payments_rounded,
      _ => Icons.fact_check_outlined,
    };
  }
}

class _PendingChip extends StatelessWidget {
  final String status;

  const _PendingChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: KColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: KTypography.labelSmall.copyWith(
          color: KColors.warning,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
