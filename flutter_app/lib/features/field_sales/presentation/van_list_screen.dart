import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
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
          SnackBar(
            content: Text('Failed to load vans: ${ApiErrorParser.message(e)}'),
            backgroundColor: KColors.error,
          ),
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
          title: const Text('Add Field Delivery Van'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KTextField(
                    controller: codeCtl,
                    label: 'Van Code *',
                    hint: 'e.g. VAN-001',
                    isRequired: true,
                  ),
                  KSpacing.vGapSm,
                  KTextField(
                    controller: vehicleNumberCtl,
                    label: 'Vehicle Registration Number *',
                    hint: 'e.g. KA-01-AB-1234',
                    isRequired: true,
                  ),
                  KSpacing.vGapSm,
                  KTextField(
                    controller: nameCtl,
                    label: 'Van Name / Route Nickname',
                    hint: 'e.g. North Zone Express',
                  ),
                  KSpacing.vGapSm,
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Type',
                      border: OutlineInputBorder(),
                    ),
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
                  KTextField(
                    controller: capacityWeightCtl,
                    label: 'Payload Capacity (kg)',
                    hint: 'e.g. 500',
                    keyboardType: TextInputType.number,
                  ),
                  KSpacing.vGapSm,
                  KTextField(
                    controller: capacityVolumeCtl,
                    label: 'Cargo Volume (litres)',
                    hint: 'e.g. 1000',
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            KButton.outlined(
              size: KButtonSize.small,
              onPressed: () => Navigator.pop(ctx, false),
              label: 'Cancel',
            ),
            KSpacing.hGapSm,
            KButton.primary(
              size: KButtonSize.small,
              label: 'Create Van',
              onPressed: () {
                if (codeCtl.text.trim().isEmpty ||
                    vehicleNumberCtl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Code and Vehicle Number are required'),
                      backgroundColor: KColors.error,
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
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
          SnackBar(
            content: Text('Failed to create van: ${ApiErrorParser.message(e)}'),
            backgroundColor: KColors.error,
          ),
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
          title: const Text('Field Delivery Vans & Inventory'),
        ),
        body: _isLoading
            ? const Center(child: KLoading())
            : _vans.isEmpty
                ? KEmptyState(
                    icon: Icons.local_shipping_outlined,
                    title: 'No vans registered yet',
                    subtitle:
                        'Add delivery vans and mobile inventory units to manage field logistics.',
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
          backgroundColor: KColors.primary,
          foregroundColor: Colors.white,
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

    return KCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: KColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              color: KColors.primary,
              size: 22,
            ),
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
                        name,
                        style: KTypography.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    KSpacing.hGapSm,
                    KStatusChip(
                      status: vehicleType,
                      label: vehicleType,
                    ),
                  ],
                ),
                KSpacing.vGapXs,
                Row(
                  children: [
                    Text(
                      code,
                      style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w600, color: KColors.textSecondary),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.directions_car_outlined, size: 13, color: KColors.textSecondary),
                    const SizedBox(width: 3),
                    Text(
                      vehicleNumber,
                      style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w600, color: KColors.textSecondary),
                    ),
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
                          label: '${capacityWeight.toStringAsFixed(0)} kg capacity',
                        ),
                      if (capacityVolume != null)
                        _InfoChip(
                          icon: Icons.water_drop_outlined,
                          label: '${capacityVolume.toStringAsFixed(0)} L volume',
                        ),
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
          SnackBar(
            content: Text('Failed to load van stock: $e'),
            backgroundColor: KColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.88,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                KSpacing.md, KSpacing.md, KSpacing.md, KSpacing.sm),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 20, color: KColors.primary),
                KSpacing.hGapSm,
                Expanded(
                  child: Text(
                    '${widget.vanName} — Current Van Stock',
                    style: KTypography.titleLarge,
                  ),
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
                ? const Center(child: KLoading())
                : _stock.isEmpty
                    ? const KEmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'No inventory currently in this van',
                        subtitle: 'Load goods via Van Stock Transfers to equip this delivery vehicle.',
                      )
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
                          return KCard(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.check_box_outline_blank, size: 16, color: KColors.primary),
                                KSpacing.hGapSm,
                                Expanded(
                                  child: Text(itemName,
                                      style: KTypography.bodyMedium.copyWith(fontWeight: FontWeight.w500)),
                                ),
                                Text(
                                  '${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 2)} $uom',
                                  style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
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
