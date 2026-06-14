import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/field_sales_repository.dart';

class VanListScreen extends ConsumerStatefulWidget {
  const VanListScreen({super.key});

  @override
  ConsumerState<VanListScreen> createState() => _VanListScreenState();
}

class _VanListScreenState extends ConsumerState<VanListScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _vans = [];

  @override
  void initState() {
    super.initState();
    _loadVans();
  }

  Future<void> _loadVans() async {
    setState(() => _isLoading = true);
    try {
      final vans = await ref.read(fieldSalesRepositoryProvider).listVans();
      if (mounted) setState(() => _vans = vans);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load vans: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showCreateDialog() async {
    final codeCtl = TextEditingController();
    final vehicleNumberCtl = TextEditingController();
    final nameCtl = TextEditingController();
    final capacityWeightCtl = TextEditingController();
    final capacityVolumeCtl = TextEditingController();
    String selectedType = 'VAN';

    final vehicleTypes = ['VAN', 'TRUCK', 'BIKE', 'AUTO'];

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create Van'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeCtl,
                  decoration: const InputDecoration(
                    labelText: 'Code *',
                    hintText: 'e.g. VAN-001',
                  ),
                ),
                KSpacing.vGapSm,
                TextField(
                  controller: vehicleNumberCtl,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Number *',
                    hintText: 'e.g. KA-01-AB-1234',
                  ),
                ),
                KSpacing.vGapSm,
                TextField(
                  controller: nameCtl,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g. North Zone Van',
                  ),
                ),
                KSpacing.vGapSm,
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Vehicle Type'),
                  items: vehicleTypes
                      .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t[0] + t.substring(1).toLowerCase())))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedType = val);
                    }
                  },
                ),
                KSpacing.vGapSm,
                TextField(
                  controller: capacityWeightCtl,
                  decoration: const InputDecoration(
                    labelText: 'Capacity Weight (kg)',
                    hintText: 'e.g. 500',
                  ),
                  keyboardType: TextInputType.number,
                ),
                KSpacing.vGapSm,
                TextField(
                  controller: capacityVolumeCtl,
                  decoration: const InputDecoration(
                    labelText: 'Capacity Volume (litres)',
                    hintText: 'e.g. 1000',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (codeCtl.text.trim().isEmpty ||
                    vehicleNumberCtl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Code and Vehicle Number are required')),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (result != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(fieldSalesRepositoryProvider).createVan({
        'code': codeCtl.text.trim(),
        'vehicleNumber': vehicleNumberCtl.text.trim(),
        if (nameCtl.text.trim().isNotEmpty) 'name': nameCtl.text.trim(),
        'vehicleType': selectedType,
        if (capacityWeightCtl.text.trim().isNotEmpty)
          'capacityWeightKg':
              double.tryParse(capacityWeightCtl.text.trim()) ?? 0,
        if (capacityVolumeCtl.text.trim().isNotEmpty)
          'capacityVolumeLitre':
              double.tryParse(capacityVolumeCtl.text.trim()) ?? 0,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Van created successfully'),
            backgroundColor: KColors.success,
          ),
        );
      }
      await _loadVans();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create van: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showVanStockSheet(Map<String, dynamic> van) async {
    final vanId = van['id']?.toString();
    if (vanId == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _VanStockSheet(
        vanName: van['name']?.toString() ?? van['code']?.toString() ?? 'Van',
        vanId: vanId,
        repo: ref.read(fieldSalesRepositoryProvider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KKeyboardListWrapper(
      itemCount: () => _vans.length,
      onNew: _showCreateDialog,
      onRefresh: () => _loadVans(),
      onOpen: (i) => _showVanStockSheet(_vans[i]),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vans'),
        ),
        body: _isLoading
            ? const KLoading()
            : _vans.isEmpty
                ? KEmptyState(
                    icon: Icons.local_shipping_outlined,
                    title: 'No vans yet',
                    subtitle:
                        'Add vans to manage your field delivery vehicles.',
                    actionLabel: 'New Van',
                    onAction: _showCreateDialog,
                  )
                : RefreshIndicator(
                    onRefresh: _loadVans,
                    child: ListView.separated(
                      padding: KSpacing.pagePadding,
                      itemCount: _vans.length,
                      separatorBuilder: (_, __) => KSpacing.vGapSm,
                      itemBuilder: (context, index) {
                        final van = _vans[index];
                        return _VanCard(
                          van: van,
                          onTap: () => _showVanStockSheet(van),
                        );
                      },
                    ),
                  ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showCreateDialog,
          icon: const Icon(Icons.add),
          label: const Text('New Van'),
          tooltip: 'New Van (N)',
        ),
      ),
    );
  }
}

class _VanCard extends StatelessWidget {
  final Map<String, dynamic> van;
  final VoidCallback onTap;

  const _VanCard({required this.van, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final code = van['code']?.toString() ?? '--';
    final name = van['name']?.toString() ?? 'Unnamed Van';
    final vehicleNumber = van['vehicleNumber']?.toString() ?? '--';
    final vehicleType = van['vehicleType']?.toString() ?? 'VAN';
    final capacityWeight = (van['capacityWeightKg'] as num?)?.toDouble();
    final capacityVolume = (van['capacityVolumeLitre'] as num?)?.toDouble();

    Color typeColor;
    switch (vehicleType) {
      case 'TRUCK':
        typeColor = KColors.warning;
        break;
      case 'BIKE':
        typeColor = KColors.info;
        break;
      case 'AUTO':
        typeColor = KColors.success;
        break;
      default:
        typeColor = KColors.primary;
    }

    return KCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.local_shipping_outlined,
                color: typeColor, size: 20),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(name,
                          style: KTypography.labelLarge,
                          overflow: TextOverflow.ellipsis),
                    ),
                    KSpacing.hGapSm,
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        vehicleType,
                        style: KTypography.bodySmall.copyWith(
                            color: typeColor, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                KSpacing.vGapXs,
                Row(
                  children: [
                    Text(code,
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary)),
                    const SizedBox(width: 8),
                    Icon(Icons.directions_car_outlined,
                        size: 12, color: KColors.textSecondary),
                    const SizedBox(width: 2),
                    Text(vehicleNumber,
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary)),
                  ],
                ),
                if (capacityWeight != null || capacityVolume != null) ...[
                  KSpacing.vGapXs,
                  Wrap(
                    spacing: 12,
                    children: [
                      if (capacityWeight != null)
                        _InfoChip(
                            icon: Icons.fitness_center,
                            label:
                                '${capacityWeight.toStringAsFixed(0)} kg'),
                      if (capacityVolume != null)
                        _InfoChip(
                            icon: Icons.water_drop_outlined,
                            label:
                                '${capacityVolume.toStringAsFixed(0)} L'),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: KColors.textHint),
        ],
      ),
    );
  }
}

class _VanStockSheet extends StatefulWidget {
  final String vanName;
  final String vanId;
  final FieldSalesRepository repo;

  const _VanStockSheet({
    required this.vanName,
    required this.vanId,
    required this.repo,
  });

  @override
  State<_VanStockSheet> createState() => _VanStockSheetState();
}

class _VanStockSheetState extends State<_VanStockSheet> {
  bool _loading = true;
  List<Map<String, dynamic>> _stock = [];

  @override
  void initState() {
    super.initState();
    _loadStock();
  }

  Future<void> _loadStock() async {
    try {
      final stock = await widget.repo.getVanStock(widget.vanId);
      if (mounted) setState(() => _stock = stock);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load van stock: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                KSpacing.md, KSpacing.md, KSpacing.md, KSpacing.sm),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 20),
                KSpacing.hGapSm,
                Expanded(
                  child: Text('${widget.vanName} — Stock',
                      style: KTypography.labelLarge),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _stock.isEmpty
                    ? const Center(child: Text('No stock in this van'))
                    : ListView.separated(
                        controller: scrollController,
                        padding: KSpacing.pagePadding,
                        itemCount: _stock.length,
                        separatorBuilder: (_, __) => KSpacing.vGapSm,
                        itemBuilder: (context, index) {
                          final item = _stock[index];
                          final itemName = item['itemName']?.toString() ??
                              item['name']?.toString() ??
                              'Item ${item['itemId'] ?? ''}';
                          final qty =
                              (item['quantity'] as num?)?.toDouble() ?? 0;
                          final uom = item['uom']?.toString() ?? '';
                          return Row(
                            children: [
                              Expanded(
                                child: Text(itemName,
                                    style: KTypography.bodyMedium),
                              ),
                              Text(
                                '${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 2)} $uom',
                                style: KTypography.labelMedium,
                              ),
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: KColors.textSecondary),
        const SizedBox(width: 3),
        Text(label,
            style:
                KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
      ],
    );
  }
}
