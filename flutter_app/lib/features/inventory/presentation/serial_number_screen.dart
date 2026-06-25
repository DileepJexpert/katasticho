import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/inventory_repository.dart';
import '../data/serial_number_repository.dart';
import 'item_picker_sheet.dart';

/// Serial-number tracking — pick a serialised item, see every unit with its
/// status (in stock / sold / damaged / returned), bulk-receive new units, and
/// mark individual units damaged or returned. Sale assignment is invoice-driven
/// and happens at billing, so it isn't exposed here.
class SerialNumberScreen extends ConsumerStatefulWidget {
  const SerialNumberScreen({super.key});

  @override
  ConsumerState<SerialNumberScreen> createState() => _SerialNumberScreenState();
}

class _SerialNumberScreenState extends ConsumerState<SerialNumberScreen> {
  String? _itemId;
  String? _itemName;
  List<Map<String, dynamic>> _serials = [];
  bool _loading = false;
  String _filter = 'ALL'; // ALL / IN_STOCK / SOLD / DAMAGED / RETURNED

  SerialNumberRepository get _repo =>
      ref.read(serialNumberRepositoryProvider);

  static const _statuses = ['ALL', 'IN_STOCK', 'SOLD', 'DAMAGED', 'RETURNED'];

  Future<void> _pickItem() async {
    final item = await showItemPicker(context);
    if (item == null) return;
    setState(() {
      _itemId = item['id']?.toString();
      _itemName = item['name']?.toString() ?? item['sku']?.toString();
      _serials = [];
    });
    await _load();
  }

  Future<void> _load() async {
    final id = _itemId;
    if (id == null) return;
    setState(() => _loading = true);
    try {
      final rows = await _repo.listByItem(id);
      if (mounted) setState(() => _serials = rows);
    } catch (e) {
      _toast('Could not load: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered => _filter == 'ALL'
      ? _serials
      : _serials
          .where((s) => (s['status']?.toString() ?? 'IN_STOCK') == _filter)
          .toList();

  int _countOf(String status) =>
      _serials.where((s) => (s['status']?.toString() ?? 'IN_STOCK') == status).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Serial Numbers'),
        actions: [
          if (_itemId != null)
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : _load,
            ),
        ],
      ),
      floatingActionButton: _itemId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _openReceiveSheet,
              icon: const Icon(Icons.add),
              label: const Text('Receive serials'),
            ),
      body: Column(
        children: [
          Padding(
            padding: KSpacing.pagePadding,
            child: KCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_itemName ?? 'No item selected',
                            style: KTypography.labelLarge),
                        KSpacing.vGapXs,
                        Text(
                          _itemId == null
                              ? 'Pick a serialised item to view its units'
                              : '${_serials.length} unit(s) tracked',
                          style: KTypography.bodySmall
                              .copyWith(color: KColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  KButton(
                    label: _itemId == null ? 'Pick item' : 'Change',
                    icon: Icons.inventory_2_outlined,
                    variant: KButtonVariant.outlined,
                    onPressed: _pickItem,
                  ),
                ],
              ),
            ),
          ),
          if (_itemId != null)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
                children: _statuses.map((s) {
                  final label = s == 'ALL'
                      ? 'All ${_serials.length}'
                      : '${_pretty(s)} ${_countOf(s)}';
                  return Padding(
                    padding: const EdgeInsets.only(right: KSpacing.sm),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _filter == s,
                      onSelected: (_) => setState(() => _filter = s),
                    ),
                  );
                }).toList(),
              ),
            ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_itemId == null) {
      return KEmptyState(
        icon: Icons.qr_code_2,
        title: 'Track serial numbers',
        subtitle:
            'Pick a serialised item to receive units, then mark them damaged '
            'or returned as needed.',
        actionLabel: 'Pick item',
        onAction: _pickItem,
      );
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    final rows = _filtered;
    if (rows.isEmpty) {
      return Center(
        child: Text(
          _filter == 'ALL'
              ? 'No serials yet — tap "Receive serials" to add units'
              : 'No ${_pretty(_filter).toLowerCase()} units',
          style: KTypography.bodyMedium.copyWith(color: KColors.textHint),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: KSpacing.pagePadding,
        itemCount: rows.length,
        separatorBuilder: (_, __) => KSpacing.vGapSm,
        itemBuilder: (_, i) => _serialCard(rows[i]),
      ),
    );
  }

  Widget _serialCard(Map<String, dynamic> s) {
    final status = s['status']?.toString() ?? 'IN_STOCK';
    final id = s['id'].toString();
    return KCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s['serial']?.toString() ?? '—',
                    style: KTypography.mono(size: 14)),
                KSpacing.vGapXs,
                Text(
                  [
                    if ((s['batchId']?.toString() ?? '').isNotEmpty) 'batch-linked',
                    if ((s['notes']?.toString() ?? '').isNotEmpty)
                      s['notes'].toString(),
                  ].where((e) => e.isNotEmpty).join(' · '),
                  style: KTypography.bodySmall
                      .copyWith(color: KColors.textSecondary),
                ),
              ],
            ),
          ),
          KStatusChip(status: _pretty(status)),
          if (status == 'IN_STOCK' || status == 'SOLD' || status == 'DAMAGED')
            PopupMenuButton<String>(
              onSelected: (v) => _onAction(id, v),
              itemBuilder: (_) => [
                if (status == 'IN_STOCK')
                  const PopupMenuItem(
                      value: 'damage', child: Text('Mark damaged')),
                if (status == 'SOLD' || status == 'DAMAGED')
                  const PopupMenuItem(
                      value: 'return', child: Text('Mark returned')),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _onAction(String id, String action) async {
    try {
      if (action == 'damage') {
        final notes = await _promptNotes();
        if (notes == null) return; // cancelled
        await _repo.markDamaged(id, notes: notes.isEmpty ? null : notes);
      } else if (action == 'return') {
        await _repo.markReturned(id);
      }
      await _load();
    } catch (e) {
      _toast('Failed: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  Future<String?> _promptNotes() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark damaged'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Reason / notes (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Mark damaged')),
        ],
      ),
    );
  }

  // ── Receive ──────────────────────────────────────────────────────────

  Future<void> _openReceiveSheet() async {
    final warehouses = await ref.read(inventoryRepositoryProvider).getWarehouses();
    if (!mounted) return;
    final serialsCtrl = TextEditingController();
    String? warehouseId;

    final received = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: EdgeInsets.only(
              left: KSpacing.lg,
              right: KSpacing.lg,
              top: KSpacing.lg,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + KSpacing.lg,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Receive serials — ${_itemName ?? ''}',
                      style: KTypography.h3),
                  KSpacing.vGapMd,
                  if (warehouses.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: warehouseId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Warehouse (optional)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: warehouses.map((w) {
                        final m = Map<String, dynamic>.from(w as Map);
                        return DropdownMenuItem(
                          value: m['id']?.toString(),
                          child: Text(
                              m['name']?.toString() ?? m['code']?.toString() ?? '',
                              overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (v) => setSheet(() => warehouseId = v),
                    ),
                  KSpacing.vGapMd,
                  TextField(
                    controller: serialsCtrl,
                    autofocus: true,
                    maxLines: 8,
                    minLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Serial numbers',
                      helperText: 'One per line (or comma-separated)',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  KSpacing.vGapLg,
                  KButton(
                    label: 'Receive',
                    icon: Icons.check,
                    onPressed: () async {
                      final serials = serialsCtrl.text
                          .split(RegExp(r'[\n,]'))
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList();
                      if (serials.isEmpty) {
                        _toast('Enter at least one serial number');
                        return;
                      }
                      try {
                        await _repo.receive(
                          itemId: _itemId!,
                          warehouseId: warehouseId,
                          serials: serials,
                        );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        _toast(
                            'Could not receive: ${e.toString().replaceAll('Exception: ', '')}');
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (received == true) {
      _toast('Serials received');
      await _load();
    }
  }

  String _pretty(String status) => switch (status) {
        'IN_STOCK' => 'In stock',
        'SOLD' => 'Sold',
        'DAMAGED' => 'Damaged',
        'RETURNED' => 'Returned',
        _ => status,
      };

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
