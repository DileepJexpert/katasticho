import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/widgets.dart';
import 'item_picker_sheet.dart';

class TransferOrderCreateScreen extends ConsumerStatefulWidget {
  const TransferOrderCreateScreen({super.key});

  @override
  ConsumerState<TransferOrderCreateScreen> createState() =>
      _TransferOrderCreateScreenState();
}

class _TransferOrderCreateScreenState
    extends ConsumerState<TransferOrderCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  String? _fromWarehouseId;
  String? _toWarehouseId;
  DateTime _transferDate = DateTime.now();

  bool _saving = false;
  bool _loadingWarehouses = true;
  List<Map<String, dynamic>> _warehouses = [];
  final List<_TransferLine> _lines = [];

  @override
  void initState() {
    super.initState();
    _fetchWarehouses();
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchWarehouses() async {
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get(ApiConfig.warehouses);
      final data = response.data['data'] ?? response.data;
      final list = data is List ? data : (data is Map ? data['content'] ?? [] : []);
      _warehouses = (list as List)
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    } catch (e) {
      debugPrint('[TransferOrderCreate] Failed to load warehouses: $e');
    }
    if (mounted) setState(() => _loadingWarehouses = false);
  }

  Future<void> _addLine() async {
    final item = await showItemPicker(context);
    if (item == null || !mounted) return;

    final itemId = item['id']?.toString();
    if (itemId == null) return;

    // Prevent adding the same item twice
    if (_lines.any((l) => l.itemId == itemId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item already added')),
      );
      return;
    }

    setState(() {
      _lines.add(_TransferLine(
        itemId: itemId,
        itemName: item['name']?.toString() ?? '',
        sku: item['sku']?.toString() ?? '',
        qtyController: TextEditingController(text: '1'),
        notesController: TextEditingController(),
      ));
    });
  }

  void _removeLine(int index) {
    setState(() {
      _lines[index].dispose();
      _lines.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fromWarehouseId == _toWarehouseId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Source and destination warehouses must differ')),
      );
      return;
    }

    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one line item')),
      );
      return;
    }

    // Validate all quantities are positive
    for (final line in _lines) {
      final qty = double.tryParse(line.qtyController.text.trim()) ?? 0;
      if (qty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Quantity for ${line.itemName} must be greater than 0')),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      final payload = {
        'fromWarehouseId': _fromWarehouseId,
        'toWarehouseId': _toWarehouseId,
        'transferDate': DateFormatter.api(_transferDate),
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        'lines': _lines
            .map((l) => {
                  'itemId': l.itemId,
                  'batchId': null,
                  'quantity': double.parse(l.qtyController.text.trim()),
                  'notes': l.notesController.text.trim().isEmpty
                      ? null
                      : l.notesController.text.trim(),
                })
            .toList(),
      };

      final response =
          await api.post(ApiConfig.transferOrders, data: payload);
      final data = response.data['data'] ?? response.data;
      final newId = data is Map ? data['id']?.toString() : null;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transfer order created')),
      );

      if (newId != null) {
        context.go('/inventory/transfer-orders/$newId');
      } else {
        context.pop();
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final body = e.response?.data;
      final message = (body is Map ? body['message'] as String? : null) ??
          'Failed to create transfer order';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KKeyboardFormWrapper(
      onSubmit: _submit,
      onCancel: () => context.pop(),
      child: Scaffold(
      appBar: AppBar(title: const Text('New Transfer Order')),
      body: _loadingWarehouses
          ? const KLoading(message: 'Loading warehouses...')
          : Form(
              key: _formKey,
              child: ListView(
                padding: KSpacing.pagePadding,
                children: [
                  Text('Transfer Details', style: KTypography.h3),
                  KSpacing.vGapMd,
                  _WarehouseDropdown(
                    label: 'Source Warehouse *',
                    value: _fromWarehouseId,
                    warehouses: _warehouses,
                    excludeId: _toWarehouseId,
                    onChanged: (v) => setState(() => _fromWarehouseId = v),
                    validator: (v) =>
                        v == null ? 'Source warehouse is required' : null,
                  ),
                  KSpacing.vGapMd,
                  _WarehouseDropdown(
                    label: 'Destination Warehouse *',
                    value: _toWarehouseId,
                    warehouses: _warehouses,
                    excludeId: _fromWarehouseId,
                    onChanged: (v) => setState(() => _toWarehouseId = v),
                    validator: (v) =>
                        v == null ? 'Destination warehouse is required' : null,
                  ),
                  KSpacing.vGapMd,
                  KDatePicker(
                    label: 'Transfer Date',
                    value: _transferDate,
                    isRequired: true,
                    onChanged: (v) => setState(() => _transferDate = v),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  ),
                  KSpacing.vGapMd,
                  KTextField(
                    label: 'Notes',
                    controller: _notesController,
                    maxLines: 2,
                    hint: 'Optional notes for this transfer',
                  ),
                  KSpacing.vGapLg,

                  // Line items section
                  Row(
                    children: [
                      Expanded(
                        child: Text('Line Items', style: KTypography.h3),
                      ),
                      TextButton.icon(
                        onPressed: _addLine,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Item'),
                      ),
                    ],
                  ),
                  KSpacing.vGapSm,

                  if (_lines.isEmpty)
                    KCard(
                      child: Padding(
                        padding: const EdgeInsets.all(KSpacing.md),
                        child: Column(
                          children: [
                            const Icon(Icons.inventory_2_outlined,
                                size: 36, color: KColors.textHint),
                            KSpacing.vGapSm,
                            Text('No items added',
                                style: KTypography.labelLarge),
                            KSpacing.vGapXs,
                            Text(
                              'Tap "Add Item" to select items for this transfer.',
                              style: KTypography.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._lines.asMap().entries.map((entry) {
                      final i = entry.key;
                      final line = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: KSpacing.sm),
                        child: _LineItemCard(
                          line: line,
                          onRemove: () => _removeLine(i),
                        ),
                      );
                    }),

                  KSpacing.vGapXl,
                  KButton(
                    label: 'Create Transfer Order',
                    fullWidth: true,
                    isLoading: _saving,
                    onPressed: _submit,
                  ),
                  KSpacing.vGapMd,
                ],
              ),
            ),
    ));
  }
}

class _WarehouseDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<Map<String, dynamic>> warehouses;
  final String? excludeId;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  const _WarehouseDropdown({
    required this.label,
    required this.value,
    required this.warehouses,
    this.excludeId,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final available = warehouses
        .where((w) => w['id']?.toString() != excludeId)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: KTypography.labelLarge.copyWith(color: cs.onSurface),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KSpacing.radiusMd),
            ),
            isDense: true,
          ),
          hint: const Text('Select warehouse'),
          isExpanded: true,
          items: available.map((w) {
            final id = w['id']?.toString() ?? '';
            final name = w['name']?.toString() ?? 'Unnamed';
            return DropdownMenuItem(value: id, child: Text(name));
          }).toList(),
          onChanged: onChanged,
          validator: validator,
        ),
      ],
    );
  }
}

class _LineItemCard extends StatelessWidget {
  final _TransferLine line;
  final VoidCallback onRemove;

  const _LineItemCard({required this.line, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: KColors.primaryLight.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.inventory_2_outlined,
                    color: KColors.primary, size: 18),
              ),
              KSpacing.hGapSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(line.itemName, style: KTypography.labelLarge),
                    if (line.sku.isNotEmpty)
                      Text('SKU: ${line.sku}',
                          style: KTypography.bodySmall
                              .copyWith(color: KColors.textSecondary)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                icon:
                    const Icon(Icons.remove_circle_outline, color: KColors.error),
                onPressed: onRemove,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          KSpacing.vGapSm,
          Row(
            children: [
              Expanded(
                flex: 2,
                child: KTextField(
                  label: 'Quantity *',
                  controller: line.qtyController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final qty = double.tryParse(v.trim());
                    if (qty == null || qty <= 0) return 'Must be > 0';
                    return null;
                  },
                ),
              ),
              KSpacing.hGapMd,
              Expanded(
                flex: 3,
                child: KTextField(
                  label: 'Notes',
                  controller: line.notesController,
                  hint: 'Optional',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransferLine {
  final String itemId;
  final String itemName;
  final String sku;
  final TextEditingController qtyController;
  final TextEditingController notesController;

  _TransferLine({
    required this.itemId,
    required this.itemName,
    required this.sku,
    required this.qtyController,
    required this.notesController,
  });

  void dispose() {
    qtyController.dispose();
    notesController.dispose();
  }
}
