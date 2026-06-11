import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/widgets.dart';
import '../data/partner_network_repository.dart';

class PartnerListScreen extends ConsumerWidget {
  const PartnerListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partnersAsync = ref.watch(partnersProvider);
    final pendingAsync = ref.watch(pendingPartnersProvider);
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Column(
          children: [
            const KListPageHeader(
              title: 'Trading Partners',
            ),
            TabBar(
              tabs: const [
                Tab(text: 'All Partners'),
                Tab(text: 'Pending Requests'),
              ],
              labelColor: theme.colorScheme.primary,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _AllPartnersTab(partnersAsync: partnersAsync, ref: ref),
                  _PendingTab(pendingAsync: pendingAsync, ref: ref),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showRequestDialog(context, ref),
          icon: const Icon(Icons.handshake),
          label: const Text('Request Partnership'),
          tooltip: 'Request Partnership (N)',
        ),
      ),
    );
  }

  Future<void> _showRequestDialog(BuildContext context, WidgetRef ref) async {
    final orgIdCtl = TextEditingController();
    final notesCtl = TextEditingController();
    String role = 'BUYER';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Request Partnership'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: orgIdCtl,
                decoration: const InputDecoration(
                  labelText: 'Partner Organisation ID *',
                  hintText: 'UUID of the organisation',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(labelText: 'Your Role'),
                items: const [
                  DropdownMenuItem(value: 'BUYER', child: Text('I am Buyer (they sell to me)')),
                  DropdownMenuItem(value: 'SELLER', child: Text('I am Seller (I sell to them)')),
                ],
                onChanged: (v) => setState(() => role = v ?? 'BUYER'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtl,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (orgIdCtl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Send Request'),
            ),
          ],
        ),
      ),
    );

    if (result != true || !context.mounted) return;

    try {
      await ref.read(partnerNetworkRepositoryProvider).requestPartnership(
        targetOrgId: orgIdCtl.text.trim(),
        role: role,
        notes: notesCtl.text.trim().isEmpty ? null : notesCtl.text.trim(),
      );
      ref.invalidate(partnersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Partnership request sent'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }
}

class _AllPartnersTab extends StatelessWidget {
  const _AllPartnersTab({required this.partnersAsync, required this.ref});
  final AsyncValue<List<Map<String, dynamic>>> partnersAsync;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return partnersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => KErrorView(message: e.toString(), onRetry: () => ref.invalidate(partnersProvider)),
      data: (partners) {
        if (partners.isEmpty) {
          return const KEmptyState(
            icon: Icons.handshake_outlined,
            title: 'No partners yet',
            subtitle: 'Request a partnership to start B2B ordering.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(partnersProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: partners.length,
            itemBuilder: (ctx, i) => _PartnerCard(partner: partners[i]),
          ),
        );
      },
    );
  }
}

class _PendingTab extends StatelessWidget {
  const _PendingTab({required this.pendingAsync, required this.ref});
  final AsyncValue<List<Map<String, dynamic>>> pendingAsync;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return pendingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => KErrorView(message: e.toString(), onRetry: () => ref.invalidate(pendingPartnersProvider)),
      data: (pending) {
        if (pending.isEmpty) {
          return const KEmptyState(
            icon: Icons.inbox_outlined,
            title: 'No pending requests',
            subtitle: 'Partnership requests from other orgs will appear here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(pendingPartnersProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pending.length,
            itemBuilder: (ctx, i) => _PendingPartnerCard(
              partner: pending[i],
              onApprove: () async {
                final id = pending[i]['id']?.toString();
                if (id == null) return;
                await ref.read(partnerNetworkRepositoryProvider).approvePartner(id);
                ref.invalidate(pendingPartnersProvider);
                ref.invalidate(partnersProvider);
              },
              onReject: () async {
                final id = pending[i]['id']?.toString();
                if (id == null) return;
                await ref.read(partnerNetworkRepositoryProvider).rejectPartner(id);
                ref.invalidate(pendingPartnersProvider);
              },
            ),
          ),
        );
      },
    );
  }
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({required this.partner});
  final Map<String, dynamic> partner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = partner['status']?.toString() ?? '';
    final sellerName = partner['sellerOrgName']?.toString() ?? 'Unknown';
    final buyerName = partner['buyerOrgName']?.toString() ?? 'Unknown';

    return KCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('$sellerName → $buyerName',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                ),
                KStatusChip(status: status),
              ],
            ),
            if (partner['paymentTerms'] != null) ...[
              const SizedBox(height: 4),
              Text('Terms: ${partner['paymentTerms']}', style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _PendingPartnerCard extends StatelessWidget {
  const _PendingPartnerCard({required this.partner, required this.onApprove, required this.onReject});
  final Map<String, dynamic> partner;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sellerName = partner['sellerOrgName']?.toString() ?? 'Unknown';
    final buyerName = partner['buyerOrgName']?.toString() ?? 'Unknown';

    return KCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$sellerName → $buyerName',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            if (partner['notes'] != null) ...[
              const SizedBox(height: 4),
              Text(partner['notes'].toString(), style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(onPressed: onReject, child: const Text('Reject')),
                const SizedBox(width: 8),
                FilledButton(onPressed: onApprove, child: const Text('Approve')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
