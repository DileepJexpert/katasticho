import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/item_repository.dart';

/// Form for creating a new inventory item or editing an existing one.
/// When [itemId] is provided, the screen loads that item and updates it on save.
class ItemCreateScreen extends ConsumerStatefulWidget {
  final String? itemId;
  final Map<String, dynamic>? initial;

  const ItemCreateScreen({super.key, this.itemId, this.initial});

  @override
  ConsumerState<ItemCreateScreen> createState() => _ItemCreateScreenState();
}

class _ItemCreateScreenState extends ConsumerState<ItemCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  final _skuController = TextEditingController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _hsnController = TextEditingController();
  final _uomController = TextEditingController(text: 'PCS');
  final _purchasePriceController = TextEditingController(text: '0');
  final _salePriceController = TextEditingController(text: '0');
  final _gstRateController = TextEditingController(text: '18');
  final _reorderLevelController = TextEditingController(text: '0');
  final _reorderQtyController = TextEditingController(text: '0');
  final _openingStockController = TextEditingController(text: '0');

  String _itemType = 'GOODS';
  bool _trackInventory = true;
  bool _saving = false;
  bool _loading = false;

  bool get _isEdit => widget.itemId != null;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _populateFromMap(widget.initial!);
    } else if (_isEdit) {
      _loadItem();
    }
  }

  Future<void> _loadItem() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(itemRepositoryProvider);
      final result = await repo.getItem(widget.itemId!);
      final data = (result['data'] ?? result) as Map<String, dynamic>;
      _populateFromMap(data);
    } catch (e) {
      debugPrint('[ItemCreateScreen] load FAILED: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _populateFromMap(Map<String, dynamic> data) {
    _skuController.text = data['sku']?.toString() ?? '';
    _nameController.text = data['name']?.toString() ?? '';
    _descriptionController.text = data['description']?.toString() ?? '';
    _categoryController.text = data['category']?.toString() ?? '';
    _hsnController.text = data['hsnCode']?.toString() ?? '';
    _uomController.text = data['unitOfMeasure']?.toString() ?? 'PCS';
    _purchasePriceController.text = (data['purchasePrice'] ?? 0).toString();
    _salePriceController.text = (data['salePrice'] ?? 0).toString();
    _gstRateController.text = (data['gstRate'] ?? 18).toString();
    _reorderLevelController.text = (data['reorderLevel'] ?? 0).toString();
    _reorderQtyController.text = (data['reorderQuantity'] ?? 0).toString();
    _itemType = data['itemType']?.toString() ?? 'GOODS';
    _trackInventory = data['trackInventory'] as bool? ?? true;
    setState(() {});
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _hsnController.dispose();
    _uomController.dispose();
    _purchasePriceController.dispose();
    _salePriceController.dispose();
    _gstRateController.dispose();
    _reorderLevelController.dispose();
    _reorderQtyController.dispose();
    _openingStockController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final repo = ref.read(itemRepositoryProvider);

    final payload = <String, dynamic>{
      'sku': _skuController.text.trim(),
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      'category': _categoryController.text.trim().isEmpty
          ? null
          : _categoryController.text.trim(),
      'hsnCode': _hsnController.text.trim().isEmpty ? null : _hsnController.text.trim(),
      'unitOfMeasure': _uomController.text.trim().isEmpty ? 'PCS' : _uomController.text.trim(),
      'itemType': _itemType,
      'purchasePrice': double.tryParse(_purchasePriceController.text) ?? 0,
      'salePrice': double.tryParse(_salePriceController.text) ?? 0,
      'gstRate': double.tryParse(_gstRateController.text) ?? 0,
      'trackInventory': _trackInventory && _itemType == 'GOODS',
      'reorderLevel': double.tryParse(_reorderLevelController.text) ?? 0,
      'reorderQuantity': double.tryParse(_reorderQtyController.text) ?? 0,
    };

    if (!_isEdit && _itemType == 'GOODS' && _trackInventory) {
      payload['openingStock'] = double.tryParse(_openingStockController.text) ?? 0;
    }

    try {
      if (_isEdit) {
        await repo.updateItem(widget.itemId!, payload);
      } else {
        await repo.createItem(payload);
      }
      ref.invalidate(itemListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEdit ? 'Item updated' : 'Item created')),
      );
      context.pop();
    } catch (e, st) {
      debugPrint('[ItemCreateScreen] save FAILED: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Item' : 'New Item'),
      ),
      body: _loading
          ? const KLoading()
          : Form(
              key: _formKey,
              child: ListView(
                padding: KSpacing.pagePadding,
                children: [
                  Text('Identification', style: KTypography.h3),
                  KSpacing.vGapMd,
                  KTextField(
                    label: 'SKU *',
                    controller: _skuController,
                    prefixIcon: Icons.qr_code,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'SKU is required' : null,
                  ),
                  KSpacing.vGapMd,
                  KTextField(
                    label: 'Name *',
                    controller: _nameController,
                    prefixIcon: Icons.label_outline,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  KSpacing.vGapMd,
                  KTextField(
                    label: 'Description',
                    controller: _descriptionController,
                    maxLines: 2,
                  ),
                  KSpacing.vGapMd,
                  Row(
                    children: [
                      Expanded(
                        child: KTextField(
                          label: 'Category',
                          controller: _categoryController,
                        ),
                      ),
                      KSpacing.hGapMd,
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _itemType,
                          decoration: const InputDecoration(labelText: 'Type'),
                          items: const [
                            DropdownMenuItem(value: 'GOODS', child: Text('Goods')),
                            DropdownMenuItem(value: 'SERVICE', child: Text('Service')),
                            DropdownMenuItem(
                                value: 'COMPOSITE', child: Text('Composite (kit)')),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _itemType = v ?? 'GOODS';
                              // Non-goods types never track stock directly.
                              // For COMPOSITE the parent is an abstraction
                              // over its BOM children; the backend rejects
                              // trackInventory=true for this type.
                              if (_itemType != 'GOODS') {
                                _trackInventory = false;
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  KSpacing.vGapLg,

                  Text('Pricing & Tax', style: KTypography.h3),
                  KSpacing.vGapMd,
                  Row(
                    children: [
                      Expanded(
                        child: KTextField.amount(
                          label: 'Purchase Price',
                          controller: _purchasePriceController,
                        ),
                      ),
                      KSpacing.hGapMd,
                      Expanded(
                        child: KTextField.amount(
                          label: 'Sale Price',
                          controller: _salePriceController,
                        ),
                      ),
                    ],
                  ),
                  KSpacing.vGapMd,
                  Row(
                    children: [
                      Expanded(
                        child: KTextField(
                          label: 'HSN Code',
                          controller: _hsnController,
                        ),
                      ),
                      KSpacing.hGapMd,
                      Expanded(
                        child: KTextField(
                          label: 'GST Rate (%)',
                          controller: _gstRateController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                  KSpacing.vGapMd,
                  KTextField(
                    label: 'Unit of Measure',
                    controller: _uomController,
                    prefixIcon: Icons.straighten,
                  ),
                  KSpacing.vGapLg,

                  if (_itemType == 'COMPOSITE') ...[
                    KCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              size: 18, color: KColors.primary),
                          KSpacing.hGapSm,
                          Expanded(
                            child: Text(
                              _isEdit
                                  ? 'Add or edit components under "Bill of Materials" below. This item never carries stock — selling it deducts its components.'
                                  : 'Save this item first, then add its components from the item detail screen. Composite items never carry stock directly.',
                              style: KTypography.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                    KSpacing.vGapLg,
                  ],
                  if (_itemType == 'GOODS') ...[
                    Text('Inventory', style: KTypography.h3),
                    KSpacing.vGapMd,
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Track inventory'),
                      subtitle: const Text(
                          'Stock levels will be tracked through invoices and adjustments'),
                      value: _trackInventory,
                      onChanged: (v) => setState(() => _trackInventory = v),
                    ),
                    if (_trackInventory) ...[
                      KSpacing.vGapMd,
                      Row(
                        children: [
                          Expanded(
                            child: KTextField(
                              label: 'Reorder Level',
                              controller: _reorderLevelController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          KSpacing.hGapMd,
                          Expanded(
                            child: KTextField(
                              label: 'Reorder Qty',
                              controller: _reorderQtyController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                        ],
                      ),
                      if (!_isEdit) ...[
                        KSpacing.vGapMd,
                        KTextField(
                          label: 'Opening Stock',
                          controller: _openingStockController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          prefixIcon: Icons.inventory_outlined,
                        ),
                      ],
                    ],
                  ],
                  KSpacing.vGapXl,
                  KButton(
                    label: _isEdit ? 'Save Changes' : 'Create Item',
                    fullWidth: true,
                    isLoading: _saving,
                    onPressed: _save,
                  ),
                  KSpacing.vGapMd,
                ],
              ),
            ),
    );
  }
}
