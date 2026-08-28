import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_error_view.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_money.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../data/partner_network_repository.dart';

class SupplierSearchScreen extends ConsumerStatefulWidget {
  const SupplierSearchScreen({super.key});

  @override
  ConsumerState<SupplierSearchScreen> createState() => _SupplierSearchScreenState();
}

class _SupplierSearchScreenState extends ConsumerState<SupplierSearchScreen> {
  final _searchCtl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = _searchCtl.text.trim();
      final results = await ref
          .read(partnerNetworkRepositoryProvider)
          .searchSuppliers(search: query.isEmpty ? null : query);
      if (mounted) setState(() => _results = results);
    } catch (e) {
      if (mounted) setState(() => _error = ApiErrorParser.message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Supplier Search'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _search,
          ),
        ],
      ),
      body: ListView(
        padding: KSpacing.pagePadding,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Explore Supplier Catalogs',
                style: KTypography.h2.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Search available inventory, PTR pricing, and pack sizes across all connected network suppliers.',
                style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          KSpacing.vGapMd,
          TextField(
            controller: _searchCtl,
            decoration: InputDecoration(
              hintText: 'Search products by title, SKU, or manufacturer...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(KSpacing.radiusMd)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                onPressed: () {
                  _searchCtl.clear();
                  _search();
                },
              ),
            ),
            onSubmitted: (_) => _search(),
          ),
          KSpacing.vGapMd,
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: KSpacing.md),
              child: KErrorView(message: _error!, onRetry: _search),
            ),
          if (_loading)
            const KLoading(message: 'Searching supplier items across partner network...')
          else if (_results.isEmpty)
            const KEmptyState(
              icon: Icons.search_off_rounded,
              title: 'No supplier products found',
              subtitle: 'No items match your search term from connected suppliers.',
            )
          else
            ..._results.map((item) => _SupplierItemCard(item: item)),
        ],
      ),
    );
  }
}

class _SupplierItemCard extends StatelessWidget {
  const _SupplierItemCard({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = item['displayName']?.toString() ?? 'Unnamed Product';
    final manufacturer = item['manufacturer']?.toString();
    final mrp = (item['publishedMrp'] as num?)?.toDouble();
    final ptr = (item['publishedPtr'] as num?)?.toDouble();
    final availability = item['availabilityStatus']?.toString() ?? 'AVAILABLE';
    final packSize = item['packSize']?.toString();
    final minQty = item['minOrderQty'];

    return KCard(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      padding: const EdgeInsets.all(KSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: KTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              KStatusChip(
                status: availability,
                label: availability.replaceAll('_', ' '),
              ),
            ],
          ),
          if (manufacturer != null && manufacturer.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.precision_manufacturing_outlined, size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  'Manufacturer: $manufacturer',
                  style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              if (mrp != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('MRP: ', style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant)),
                    KMoney(mrp, style: KTypography.bodySmall),
                  ],
                ),
              if (ptr != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('PTR: ', style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant)),
                    KMoney(ptr, style: KTypography.titleSmall.copyWith(color: KColors.primary)),
                  ],
                ),
              if (packSize != null && packSize.isNotEmpty)
                Text('Pack: $packSize', style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant)),
              if (minQty != null)
                Text('Min Order: $minQty units', style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}
