import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_error_view.dart';
import '../../../core/widgets/k_keyboard_list_wrapper.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../data/partner_network_repository.dart';

class PartnerListScreen extends ConsumerStatefulWidget {
  const PartnerListScreen({super.key});

  @override
  ConsumerState<PartnerListScreen> createState() => _PartnerListScreenState();
}

class _PartnerListScreenState extends ConsumerState<PartnerListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final partnersAsync = ref.watch(partnersProvider);
    final pendingAsync = ref.watch(pendingPartnersProvider);
    final cs = Theme.of(context).colorScheme;

    final pendingCount = pendingAsync.valueOrNull?.length ?? 0;

    return KKeyboardListWrapper(
      itemCount: () => partnersAsync.valueOrNull?.length ?? 0,
      onNew: () => _showRequestDialog(context, ref),
      onRefresh: () {
        ref.invalidate(partnersProvider);
        ref.invalidate(pendingPartnersProvider);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Partner Network (B2B EDI)'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                ref.invalidate(partnersProvider);
                ref.invalidate(pendingPartnersProvider);
              },
            ),
          ],
        ),
        body: ListView(
          padding: KSpacing.pagePadding,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trading Partners & Connections',
                        style: KTypography.h2.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Connect with certified buyers and sellers for automated EDI order exchange.',
                        style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                KButton.primary(
                  label: 'Request Partnership',
                  icon: Icons.handshake_rounded,
                  onPressed: () => _showRequestDialog(context, ref),
                ),
              ],
            ),
            KSpacing.vGapMd,
            TabBar(
              controller: _tabController,
              tabs: [
                const Tab(text: 'Connected Partners'),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Pending Requests'),
                      if (pendingCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: KColors.warning,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$pendingCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            KSpacing.vGapMd,
            TextFormField(
              decoration: InputDecoration(
                hintText: 'Search partners by organisation name...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(KSpacing.radiusMd)),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            KSpacing.vGapMd,
            SizedBox(
              height: 580,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _AllPartnersTab(
                    partnersAsync: partnersAsync,
                    ref: ref,
                    searchQuery: _searchQuery,
                  ),
                  _PendingTab(
                    pendingAsync: pendingAsync,
                    ref: ref,
                    searchQuery: _searchQuery,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRequestDialog(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final orgIdCtl = TextEditingController();
    final notesCtl = TextEditingController();
    String role = 'BUYER';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.handshake_rounded, color: KColors.primary),
              SizedBox(width: 8),
              Text('Request Trading Partnership'),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Send an electronic partnership invite to another organisation in the network.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                KSpacing.vGapMd,
                TextField(
                  controller: orgIdCtl,
                  decoration: const InputDecoration(
                    labelText: 'Partner Organisation ID *',
                    hintText: 'UUID of the partner organization',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                KSpacing.vGapSm,
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(
                    labelText: 'Your Relationship Role',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'BUYER', child: Text('I am Buyer (They supply to me)')),
                    DropdownMenuItem(value: 'SELLER', child: Text('I am Seller (I supply to them)')),
                  ],
                  onChanged: (v) => setDialogState(() => role = v ?? 'BUYER'),
                ),
                KSpacing.vGapSm,
                TextField(
                  controller: notesCtl,
                  decoration: const InputDecoration(
                    labelText: 'Invitation Message & Credit Terms',
                    hintText: 'Proposed credit limit, billing days, or intro notes',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            KButton.primary(
              label: 'Send Request',
              icon: Icons.send_rounded,
              onPressed: () {
                if (orgIdCtl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
            ),
          ],
        ),
      ),
    );

    if (result != true || !mounted) return;

    try {
      await ref.read(partnerNetworkRepositoryProvider).requestPartnership(
        targetOrgId: orgIdCtl.text.trim(),
        role: role,
        notes: notesCtl.text.trim().isEmpty ? null : notesCtl.text.trim(),
      );
      ref.invalidate(partnersProvider);
      ref.invalidate(pendingPartnersProvider);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Partnership request sent successfully'),
          backgroundColor: KColors.success,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to send request: ${ApiErrorParser.message(e)}'),
          backgroundColor: KColors.error,
        ),
      );
    }
  }
}

class _AllPartnersTab extends StatelessWidget {
  const _AllPartnersTab({
    required this.partnersAsync,
    required this.ref,
    required this.searchQuery,
  });

  final AsyncValue<List<Map<String, dynamic>>> partnersAsync;
  final WidgetRef ref;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return partnersAsync.when(
      loading: () => const KLoading(message: 'Loading connected trading partners...'),
      error: (e, _) => KErrorView(
        message: ApiErrorParser.message(e),
        onRetry: () => ref.invalidate(partnersProvider),
      ),
      data: (partners) {
        final filtered = partners.where((p) {
          if (searchQuery.isEmpty) return true;
          final seller = (p['sellerOrgName'] ?? '').toString().toLowerCase();
          final buyer = (p['buyerOrgName'] ?? '').toString().toLowerCase();
          final q = searchQuery.toLowerCase();
          return seller.contains(q) || buyer.contains(q);
        }).toList();

        if (filtered.isEmpty) {
          return KEmptyState(
            icon: Icons.handshake_outlined,
            title: 'No connected trading partners',
            subtitle: searchQuery.isNotEmpty
                ? 'No partners match "$searchQuery".'
                : 'Send a partnership request using the button above to link with suppliers and buyers.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(partnersProvider),
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (ctx, i) => _PartnerCard(partner: filtered[i]),
          ),
        );
      },
    );
  }
}

class _PendingTab extends StatelessWidget {
  const _PendingTab({
    required this.pendingAsync,
    required this.ref,
    required this.searchQuery,
  });

  final AsyncValue<List<Map<String, dynamic>>> pendingAsync;
  final WidgetRef ref;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return pendingAsync.when(
      loading: () => const KLoading(message: 'Checking pending requests...'),
      error: (e, _) => KErrorView(
        message: ApiErrorParser.message(e),
        onRetry: () => ref.invalidate(pendingPartnersProvider),
      ),
      data: (pending) {
        final filtered = pending.where((p) {
          if (searchQuery.isEmpty) return true;
          final seller = (p['sellerOrgName'] ?? '').toString().toLowerCase();
          final buyer = (p['buyerOrgName'] ?? '').toString().toLowerCase();
          final q = searchQuery.toLowerCase();
          return seller.contains(q) || buyer.contains(q);
        }).toList();

        if (filtered.isEmpty) {
          return const KEmptyState(
            icon: Icons.inbox_outlined,
            title: 'No pending requests',
            subtitle: 'New connection invites from network organisations will appear here for approval.',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(pendingPartnersProvider),
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (ctx, i) => _PendingPartnerCard(
              partner: filtered[i],
              onApprove: () async {
                final messenger = ScaffoldMessenger.of(context);
                final id = filtered[i]['id']?.toString();
                if (id == null) return;
                try {
                  await ref.read(partnerNetworkRepositoryProvider).approvePartner(id);
                  ref.invalidate(pendingPartnersProvider);
                  ref.invalidate(partnersProvider);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Partnership connection approved'), backgroundColor: KColors.success),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(ApiErrorParser.message(e)), backgroundColor: KColors.error),
                  );
                }
              },
              onReject: () async {
                final messenger = ScaffoldMessenger.of(context);
                final id = filtered[i]['id']?.toString();
                if (id == null) return;
                try {
                  await ref.read(partnerNetworkRepositoryProvider).rejectPartner(id);
                  ref.invalidate(pendingPartnersProvider);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Partnership request rejected')),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(ApiErrorParser.message(e)), backgroundColor: KColors.error),
                  );
                }
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
    final cs = Theme.of(context).colorScheme;
    final status = partner['status']?.toString() ?? 'ACTIVE';
    final sellerName = partner['sellerOrgName']?.toString() ?? 'Supplier Org';
    final buyerName = partner['buyerOrgName']?.toString() ?? 'Buyer Org';
    final paymentTerms = partner['paymentTerms']?.toString();

    return KCard(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      padding: const EdgeInsets.all(KSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(KSpacing.radiusMd),
            ),
            child: Icon(Icons.business_rounded, color: cs.primary, size: 20),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$sellerName ➔ $buyerName',
                        style: KTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    KStatusChip(status: status),
                  ],
                ),
                if (paymentTerms != null && paymentTerms.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.payment_rounded, size: 14, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        'Terms: $paymentTerms',
                        style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingPartnerCard extends StatelessWidget {
  const _PendingPartnerCard({
    required this.partner,
    required this.onApprove,
    required this.onReject,
  });

  final Map<String, dynamic> partner;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sellerName = partner['sellerOrgName']?.toString() ?? 'Supplier Org';
    final buyerName = partner['buyerOrgName']?.toString() ?? 'Buyer Org';
    final notes = partner['notes']?.toString();

    return KCard(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      padding: const EdgeInsets.all(KSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: KColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                ),
                child: Icon(Icons.pending_actions_rounded, color: KColors.warning, size: 18),
              ),
              KSpacing.hGapSm,
              Expanded(
                child: Text(
                  '$sellerName ➔ $buyerName',
                  style: KTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const KStatusChip(status: 'PENDING'),
            ],
          ),
          if (notes != null && notes.isNotEmpty) ...[
            KSpacing.vGapSm,
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(KSpacing.radiusSm),
              ),
              child: Text(
                notes,
                style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
          KSpacing.vGapSm,
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              KButton.outlined(
                label: 'Decline',
                size: KButtonSize.small,
                onPressed: onReject,
              ),
              KSpacing.hGapSm,
              KButton.primary(
                label: 'Approve Partner',
                size: KButtonSize.small,
                icon: Icons.check_rounded,
                onPressed: onApprove,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
