import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../data/franchise_repository.dart';

class FranchiseDashboardScreen extends ConsumerStatefulWidget {
  const FranchiseDashboardScreen({super.key});

  @override
  ConsumerState<FranchiseDashboardScreen> createState() => _FranchiseDashboardScreenState();
}

class _FranchiseDashboardScreenState extends ConsumerState<FranchiseDashboardScreen> {
  bool _syncing = false;

  Future<void> _pushCatalogSync() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Push Master Catalog to Network'),
        content: const Text(
          'This will broadcast and synchronize all master items, HSN tax classifications, '
          'and standard pricing across all active connected franchise stores and branches.',
        ),
        actions: [
          KButton.secondary(label: 'Cancel', onPressed: () => Navigator.pop(ctx, false)),
          KButton.primary(label: 'Broadcast Sync', onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _syncing = true);
    try {
      final res = await ref.read(franchiseRepositoryProvider).pushCatalogSync({'syncScope': 'ALL'});
      if (mounted) {
        ref.invalidate(franchiseNodesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Catalog synced to ${res['nodesTargeted'] ?? 0} franchise stores successfully!'),
            backgroundColor: KColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiErrorParser.message(e)), backgroundColor: KColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _showAddNodeDialog([Map<String, dynamic>? editNode]) {
    final codeCtrl = TextEditingController(text: editNode?['nodeCode'] ?? '');
    final nameCtrl = TextEditingController(text: editNode?['nodeName'] ?? '');
    final cityCtrl = TextEditingController(text: editNode?['city'] ?? '');
    final stateCtrl = TextEditingController(text: editNode?['stateCode'] ?? 'DL');
    final royaltyCtrl = TextEditingController(text: editNode?['royaltyRatePercent']?.toString() ?? '5.00');
    final feeCtrl = TextEditingController(text: editNode?['fixedMonthlyFee']?.toString() ?? '0.00');
    String nodeType = editNode?['nodeType'] ?? 'FOFO';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(editNode == null ? 'Register Franchise Store' : 'Edit Franchise Store'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (editNode == null)
                  KTextField(label: 'Store Code (e.g. FR-DL-01)', controller: codeCtrl, isRequired: true),
                KSpacing.vGapSm,
                KTextField(label: 'Store Name', controller: nameCtrl, isRequired: true),
                KSpacing.vGapSm,
                DropdownButtonFormField<String>(
                  initialValue: nodeType,
                  decoration: const InputDecoration(labelText: 'Franchise Model'),
                  items: const [
                    DropdownMenuItem(value: 'FOFO', child: Text('FOFO (Franchisee Owned & Operated)')),
                    DropdownMenuItem(value: 'COCO', child: Text('COCO (Company Owned & Operated)')),
                    DropdownMenuItem(value: 'FICO', child: Text('FICO (Franchisee Invested Company Operated)')),
                  ],
                  onChanged: (v) => setDialogState(() => nodeType = v ?? 'FOFO'),
                ),
                KSpacing.vGapSm,
                Row(
                  children: [
                    Expanded(child: KTextField(label: 'City', controller: cityCtrl)),
                    KSpacing.hGapSm,
                    Expanded(child: KTextField(label: 'State Code', controller: stateCtrl)),
                  ],
                ),
                KSpacing.vGapSm,
                Row(
                  children: [
                    Expanded(child: KTextField.amount(label: 'Royalty %', controller: royaltyCtrl)),
                    KSpacing.hGapSm,
                    Expanded(child: KTextField.amount(label: 'Fixed Fee (₹/Mo)', controller: feeCtrl)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            KButton.secondary(label: 'Cancel', onPressed: () => Navigator.pop(ctx)),
            KButton.primary(
              label: 'Save Store',
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || (editNode == null && codeCtrl.text.trim().isEmpty)) return;
                try {
                  final payload = {
                    if (editNode == null) 'nodeCode': codeCtrl.text.trim(),
                    'nodeName': nameCtrl.text.trim(),
                    'nodeType': nodeType,
                    'city': cityCtrl.text.trim(),
                    'stateCode': stateCtrl.text.trim(),
                    'royaltyRatePercent': double.tryParse(royaltyCtrl.text.trim()) ?? 5.0,
                    'fixedMonthlyFee': double.tryParse(feeCtrl.text.trim()) ?? 0.0,
                  };
                  if (editNode == null) {
                    await ref.read(franchiseRepositoryProvider).createNode(payload);
                  } else {
                    await ref.read(franchiseRepositoryProvider).updateNode(editNode['id'], payload);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  ref.invalidate(franchiseNodesProvider);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(ApiErrorParser.message(e)), backgroundColor: KColors.error),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nodesAsync = ref.watch(franchiseNodesProvider);
    final policyAsync = ref.watch(franchisePolicyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Franchise & Multi-Branch Network'),
        actions: [
          IconButton(
            tooltip: 'Branch Price Overrides',
            icon: const Icon(Icons.price_change_outlined),
            onPressed: () => context.push(Routes.franchisePriceOverrides),
          ),
          IconButton(
            tooltip: 'Royalty Settlements',
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () => context.push(Routes.franchiseSettlements),
          ),
        ],
      ),
      body: nodesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading franchise data: $err')),
        data: (nodes) {
          final totalStores = nodes.length;
          final cocoCount = nodes.where((n) => n['nodeType'] == 'COCO').length;
          final fofoCount = nodes.where((n) => n['nodeType'] == 'FOFO').length;

          return SingleChildScrollView(
            padding: KSpacing.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top KPI Metrics
                Row(
                  children: [
                    Expanded(
                      child: KCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Connected Stores', style: KTypography.caption),
                            KSpacing.vGapXs,
                            Text('$totalStores', style: KTypography.h1),
                            KSpacing.vGapXxs,
                            Text('$cocoCount COCO • $fofoCount FOFO',
                                style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                    KSpacing.hGapMd,
                    Expanded(
                      child: KCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Catalog Governance', style: KTypography.caption),
                            KSpacing.vGapXs,
                            policyAsync.when(
                              data: (p) => Text('${p['minMarginPercent'] ?? 8}% Min Margin', style: KTypography.h2),
                              loading: () => const Text('Loading...'),
                              error: (_, __) => const Text('Active Policy'),
                            ),
                            KSpacing.vGapXxs,
                            Text('Auto-sync enabled for network',
                                style: KTypography.bodySmall.copyWith(color: KColors.success)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                KSpacing.vGapLg,

                // Broadcast Actions Bar
                KCard(
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_sync_outlined, color: KColors.primary, size: 28),
                      KSpacing.hGapMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Central Master Catalog Broadcast', style: KTypography.labelLarge),
                            Text('Push latest SKU updates, HSN rates, and standard MRPs across all stores.',
                                style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                          ],
                        ),
                      ),
                      KButton.primary(
                        label: _syncing ? 'Broadcasting...' : 'Broadcast Catalog Sync',
                        icon: Icons.sync,
                        onPressed: _syncing ? null : _pushCatalogSync,
                      ),
                      KSpacing.hGapSm,
                      KButton.secondary(
                        label: 'Register Store',
                        icon: Icons.add_business_outlined,
                        onPressed: () => _showAddNodeDialog(),
                      ),
                    ],
                  ),
                ),
                KSpacing.vGapLg,

                // Store Nodes Table
                Text('Connected Franchise Stores & Branches', style: KTypography.h3),
                KSpacing.vGapSm,
                if (nodes.isEmpty)
                  const KCard(
                    child: KEmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'No franchise stores registered',
                      subtitle: 'Add your first franchise or branch node using the button above.',
                    ),
                  )
                else
                  KCard(
                    padding: EdgeInsets.zero,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Code')),
                        DataColumn(label: Text('Store Name')),
                        DataColumn(label: Text('Model')),
                        DataColumn(label: Text('Location')),
                        DataColumn(label: Text('Royalty %')),
                        DataColumn(label: Text('Last Synced')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: nodes.map((n) {
                        return DataRow(
                          cells: [
                            DataCell(Text(n['nodeCode'] ?? '--', style: KTypography.mono(fontWeight: FontWeight.w600))),
                            DataCell(Text(n['nodeName'] ?? 'Store', style: KTypography.labelMedium)),
                            DataCell(KStatusChip(status: n['nodeType'] ?? 'FOFO', dense: true)),
                            DataCell(Text('${n['city'] ?? ''}, ${n['stateCode'] ?? ''}')),
                            DataCell(Text('${n['royaltyRatePercent'] ?? 0}%')),
                            DataCell(Text(
                              n['lastSyncAt'] != null ? n['lastSyncAt'].toString().substring(0, 10) : 'Never',
                              style: KTypography.caption,
                            )),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    onPressed: () => _showAddNodeDialog(n),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.price_change_outlined, size: 18),
                                    tooltip: 'Store Price Overrides',
                                    onPressed: () => context.push(Routes.franchisePriceOverrides),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}