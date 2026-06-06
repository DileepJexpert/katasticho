import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/widgets.dart';
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

  Future<void> _search() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await ref.read(partnerNetworkRepositoryProvider)
          .searchSuppliers(search: _searchCtl.text.trim().isEmpty ? null : _searchCtl.text.trim());
      if (mounted) setState(() => _results = results);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          const KListPageHeader(
            title: 'Supplier Search',
            subtitle: 'Search published catalogs from your approved suppliers.',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtl,
              decoration: InputDecoration(
                hintText: 'Search by name, SKU, or manufacturer…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () { _searchCtl.clear(); _search(); },
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: KErrorView(message: _error!, onRetry: _search),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? const KEmptyState(
                        icon: Icons.search_off,
                        title: 'No results',
                        subtitle: 'No items found from your approved suppliers.',
                      )
                    : RefreshIndicator(
                        onRefresh: _search,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _results.length,
                          itemBuilder: (ctx, i) => _SupplierItemCard(item: _results[i]),
                        ),
                      ),
          ),
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
    final theme = Theme.of(context);
    final name = item['displayName']?.toString() ?? 'Unnamed';
    final manufacturer = item['manufacturer']?.toString();
    final mrp = item['publishedMrp'];
    final ptr = item['publishedPtr'];
    final availability = item['availabilityStatus']?.toString() ?? 'AVAILABLE';
    final packSize = item['packSize']?.toString();
    final minQty = item['minOrderQty'];

    final availColor = switch (availability) {
      'AVAILABLE' => Colors.green,
      'LOW_STOCK' => Colors.orange,
      'OUT_OF_STOCK' => Colors.red,
      _ => Colors.grey,
    };

    return KCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(name,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: availColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(availability.replaceAll('_', ' '),
                      style: theme.textTheme.labelSmall?.copyWith(color: availColor)),
                ),
              ],
            ),
            if (manufacturer != null) ...[
              const SizedBox(height: 4),
              Text(manufacturer, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 6),
            Wrap(
              spacing: 16,
              children: [
                if (mrp != null) Text('MRP: ₹$mrp', style: theme.textTheme.bodySmall),
                if (ptr != null) Text('PTR: ₹$ptr',
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                if (packSize != null) Text('Pack: $packSize', style: theme.textTheme.bodySmall),
                if (minQty != null) Text('Min Qty: $minQty', style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
