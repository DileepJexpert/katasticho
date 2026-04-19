import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';
import '../data/item_group_repository.dart';
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
  final _mrpController = TextEditingController();
  final _gstRateController = TextEditingController(text: '18');
  final _reorderLevelController = TextEditingController(text: '0');
  final _reorderQtyController = TextEditingController(text: '0');
  final _openingStockController = TextEditingController(text: '0');
  final _barcodeController = TextEditingController();
  final _brandController = TextEditingController();
  final _manufacturerController = TextEditingController();
  final _weightController = TextEditingController();
  final _weightUnitController = TextEditingController(text: 'kg');
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  final _dimensionUnitController = TextEditingController(text: 'cm');
  final _revenueAccountController = TextEditingController();
  final _cogsAccountController = TextEditingController();
  final _inventoryAccountController = TextEditingController();
  // Pharmacy
  final _drugScheduleController = TextEditingController();
  final _compositionController = TextEditingController();
  final _dosageFormController = TextEditingController();
  final _packSizeController = TextEditingController();
  final _storageConditionController = TextEditingController();

  String _itemType = 'GOODS';
  bool _trackInventory = true;
  bool _trackBatches = false;
  bool _prescriptionRequired = false;
  bool _saving = false;
  bool _loading = false;
  Map<String, String> _serverErrors = {};

  /// F5: when set, the item is created as a variant of this group.
  /// `_selectedGroup` is the cached group map (carries name + defs +
  /// defaults) so the attribute editor can render without an extra
  /// fetch. `_variantAttrs` holds the operator's selections keyed by
  /// the attribute key.
  String? _groupId;
  Map<String, dynamic>? _selectedGroup;
  final Map<String, String> _variantAttrs = {};

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
    _mrpController.text = data['mrp'] != null ? data['mrp'].toString() : '';
    _barcodeController.text = data['barcode']?.toString() ?? '';
    _brandController.text = data['brand']?.toString() ?? '';
    _manufacturerController.text = data['manufacturer']?.toString() ?? '';
    _weightController.text = data['weight'] != null ? data['weight'].toString() : '';
    _weightUnitController.text = data['weightUnit']?.toString() ?? 'kg';
    _lengthController.text = data['length'] != null ? data['length'].toString() : '';
    _widthController.text = data['width'] != null ? data['width'].toString() : '';
    _heightController.text = data['height'] != null ? data['height'].toString() : '';
    _dimensionUnitController.text = data['dimensionUnit']?.toString() ?? 'cm';
    _revenueAccountController.text = data['revenueAccountCode']?.toString() ?? '';
    _cogsAccountController.text = data['cogsAccountCode']?.toString() ?? '';
    _inventoryAccountController.text = data['inventoryAccountCode']?.toString() ?? '';
    _drugScheduleController.text = data['drugSchedule']?.toString() ?? '';
    _compositionController.text = data['composition']?.toString() ?? '';
    _dosageFormController.text = data['dosageForm']?.toString() ?? '';
    _packSizeController.text = data['packSize']?.toString() ?? '';
    _storageConditionController.text = data['storageCondition']?.toString() ?? '';
    _trackBatches = data['trackBatches'] as bool? ?? false;
    _prescriptionRequired = data['prescriptionRequired'] as bool? ?? false;
    _itemType = data['itemType']?.toString() ?? 'GOODS';
    _trackInventory = data['trackInventory'] as bool? ?? true;
    _groupId = data['groupId']?.toString();
    final attrs = data['variantAttributes'];
    if (attrs is Map) {
      _variantAttrs.clear();
      attrs.forEach((k, v) => _variantAttrs[k.toString()] = v.toString());
    }
    if (_groupId != null) {
      // Defer the group fetch — initState/_load is already async.
      // ignore: discarded_futures
      _loadGroupCache(_groupId!);
    }
    setState(() {});
  }

  Future<void> _loadGroupCache(String id) async {
    try {
      final repo = ref.read(itemGroupRepositoryProvider);
      final result = await repo.getGroup(id);
      final group = (result['data'] ?? result) as Map<String, dynamic>;
      if (mounted) setState(() => _selectedGroup = group);
    } catch (e) {
      debugPrint('[ItemCreateScreen] loadGroupCache FAILED: $e');
    }
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
    _mrpController.dispose();
    _gstRateController.dispose();
    _reorderLevelController.dispose();
    _reorderQtyController.dispose();
    _openingStockController.dispose();
    _barcodeController.dispose();
    _brandController.dispose();
    _manufacturerController.dispose();
    _weightController.dispose();
    _weightUnitController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _dimensionUnitController.dispose();
    _revenueAccountController.dispose();
    _cogsAccountController.dispose();
    _inventoryAccountController.dispose();
    _drugScheduleController.dispose();
    _compositionController.dispose();
    _dosageFormController.dispose();
    _packSizeController.dispose();
    _storageConditionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _serverErrors = {});
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final repo = ref.read(itemRepositoryProvider);

    String? _nullIfEmpty(String s) => s.trim().isEmpty ? null : s.trim();
    double? _doubleOrNull(TextEditingController c) {
      final v = double.tryParse(c.text);
      return v != null && v != 0 ? v : null;
    }

    final payload = <String, dynamic>{
      'sku': _skuController.text.trim(),
      'name': _nameController.text.trim(),
      'description': _nullIfEmpty(_descriptionController.text),
      'category': _nullIfEmpty(_categoryController.text),
      'brand': _nullIfEmpty(_brandController.text),
      'hsnCode': _nullIfEmpty(_hsnController.text),
      'unitOfMeasure': _itemType == 'SERVICE'
          ? null
          : (_uomController.text.trim().isEmpty ? 'PCS' : _uomController.text.trim()),
      'itemType': _itemType,
      'purchasePrice': double.tryParse(_purchasePriceController.text) ?? 0,
      'salePrice': double.tryParse(_salePriceController.text) ?? 0,
      'mrp': _doubleOrNull(_mrpController),
      'gstRate': double.tryParse(_gstRateController.text) ?? 0,
      'trackInventory': _trackInventory && _itemType == 'GOODS',
      'trackBatches': _trackBatches && _itemType == 'GOODS',
      'reorderLevel': double.tryParse(_reorderLevelController.text) ?? 0,
      'reorderQuantity': double.tryParse(_reorderQtyController.text) ?? 0,
      'barcode': _nullIfEmpty(_barcodeController.text),
      'manufacturer': _nullIfEmpty(_manufacturerController.text),
      'weight': _doubleOrNull(_weightController),
      'weightUnit': _nullIfEmpty(_weightUnitController.text),
      'length': _doubleOrNull(_lengthController),
      'width': _doubleOrNull(_widthController),
      'height': _doubleOrNull(_heightController),
      'dimensionUnit': _nullIfEmpty(_dimensionUnitController.text),
      'drugSchedule': _nullIfEmpty(_drugScheduleController.text),
      'composition': _nullIfEmpty(_compositionController.text),
      'dosageForm': _nullIfEmpty(_dosageFormController.text),
      'packSize': _nullIfEmpty(_packSizeController.text),
      'storageCondition': _nullIfEmpty(_storageConditionController.text),
      'prescriptionRequired': _prescriptionRequired,
      'revenueAccountCode': _nullIfEmpty(_revenueAccountController.text),
      'cogsAccountCode': _nullIfEmpty(_cogsAccountController.text),
      'inventoryAccountCode': _nullIfEmpty(_inventoryAccountController.text),
    };

    if (!_isEdit && _itemType == 'GOODS' && _trackInventory) {
      payload['openingStock'] = double.tryParse(_openingStockController.text) ?? 0;
    }

    // F5: variant linkage. The backend rejects variant_attributes
    // without a group_id and vice-versa; we mirror that here so the
    // operator gets a snackbar instead of a 400.
    if (_groupId != null) {
      final defs = (_selectedGroup?['attributeDefinitions'] as List?) ?? const [];
      for (final d in defs) {
        final def = d as Map<String, dynamic>;
        final key = def['key']?.toString() ?? '';
        if (_variantAttrs[key] == null || _variantAttrs[key]!.isEmpty) {
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Pick a value for "$key"')),
          );
          return;
        }
      }
      payload['groupId'] = _groupId;
      payload['variantAttributes'] = Map<String, String>.from(_variantAttrs);
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
      if (e is DioException) {
        final fieldErrs = ApiErrorParser.fieldErrors(e);
        if (fieldErrs.isNotEmpty) {
          setState(() => _serverErrors = fieldErrs);
          _formKey.currentState!.validate();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please fix the errors below')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ApiErrorParser.message(e))),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// "Group & Variant" section. Tap-to-pick a group from the list,
  /// then render a dropdown per attribute key. Clearing the group
  /// resets `variantAttributes` so the payload doesn't smuggle stale
  /// values.
  Widget _buildGroupSection() {
    final defs = (_selectedGroup?['attributeDefinitions'] as List?) ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Group & Variant', style: KTypography.h3),
        KSpacing.vGapXs,
        Text(
          'Optionally link this item to a group to inherit defaults and pick a variant combination.',
          style: KTypography.bodySmall,
        ),
        KSpacing.vGapMd,
        InkWell(
          onTap: _pickGroup,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(KSpacing.md),
            decoration: BoxDecoration(
              border: Border.all(color: KColors.textHint.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.category_outlined, color: KColors.primary),
                KSpacing.hGapSm,
                Expanded(
                  child: Text(
                    _selectedGroup == null
                        ? (_groupId == null
                            ? 'No group (standalone item)'
                            : 'Loading group…')
                        : (_selectedGroup!['name']?.toString() ?? ''),
                    style: KTypography.labelLarge,
                  ),
                ),
                if (_groupId != null)
                  IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      setState(() {
                        _groupId = null;
                        _selectedGroup = null;
                        _variantAttrs.clear();
                      });
                    },
                  )
                else
                  const Icon(Icons.chevron_right, color: KColors.textHint),
              ],
            ),
          ),
        ),
        if (_selectedGroup != null && defs.isNotEmpty) ...[
          KSpacing.vGapMd,
          Text('Variant attributes', style: KTypography.labelLarge),
          KSpacing.vGapSm,
          ...defs.map<Widget>((d) {
            final def = d as Map<String, dynamic>;
            final key = def['key']?.toString() ?? '';
            final values = ((def['values'] as List?) ?? const [])
                .map((v) => v.toString())
                .toList();
            return Padding(
              padding: const EdgeInsets.only(bottom: KSpacing.md),
              child: DropdownButtonFormField<String>(
                value: _variantAttrs[key],
                decoration: InputDecoration(labelText: key),
                items: values
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    if (v == null) {
                      _variantAttrs.remove(key);
                    } else {
                      _variantAttrs[key] = v;
                    }
                  });
                },
              ),
            );
          }),
        ],
      ],
    );
  }

  Future<void> _pickGroup() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) =>
            _GroupPickerSheet(scrollController: scrollController),
      ),
    );
    if (picked == null) return;
    setState(() {
      _groupId = picked['id']?.toString();
      _selectedGroup = picked;
      _variantAttrs.clear();
    });
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
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'SKU is required';
                      if (_serverErrors.containsKey('sku')) return _serverErrors['sku'];
                      return null;
                    },
                  ),
                  KSpacing.vGapMd,
                  KTextField(
                    label: 'Barcode',
                    controller: _barcodeController,
                    prefixIcon: Icons.barcode_reader,
                  ),
                  KSpacing.vGapMd,
                  KTextField(
                    label: 'Name *',
                    controller: _nameController,
                    prefixIcon: Icons.label_outline,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Name is required';
                      if (_serverErrors.containsKey('name')) return _serverErrors['name'];
                      return null;
                    },
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
                        child: KTextField(
                          label: 'Brand',
                          controller: _brandController,
                        ),
                      ),
                    ],
                  ),
                  KSpacing.vGapMd,
                  KTextField(
                    label: 'Manufacturer',
                    controller: _manufacturerController,
                  ),
                  KSpacing.vGapMd,
                  DropdownButtonFormField<String>(
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
                        if (_itemType != 'GOODS') {
                          _trackInventory = false;
                          _groupId = null;
                          _selectedGroup = null;
                          _variantAttrs.clear();
                        }
                      });
                    },
                  ),
                  KSpacing.vGapLg,

                  // F5 — group picker. Only shown for GOODS items (the
                  // backend rejects composites in groups for v1).
                  if (_itemType == 'GOODS') ...[
                    _buildGroupSection(),
                    KSpacing.vGapLg,
                  ],

                  Text('Pricing & Tax', style: KTypography.h3),
                  KSpacing.vGapMd,
                  Row(
                    children: [
                      Expanded(
                        child: KTextField.amount(
                          label: 'Purchase Price',
                          controller: _purchasePriceController,
                          validator: (v) => _serverErrors['purchasePrice'],
                        ),
                      ),
                      KSpacing.hGapMd,
                      Expanded(
                        child: KTextField.amount(
                          label: 'Sale Price',
                          controller: _salePriceController,
                          validator: (v) => _serverErrors['salePrice'],
                        ),
                      ),
                    ],
                  ),
                  KSpacing.vGapMd,
                  KTextField.amount(
                    label: 'MRP',
                    controller: _mrpController,
                  ),
                  KSpacing.vGapMd,
                  Row(
                    children: [
                      Expanded(
                        child: KTextField(
                          label: _itemType == 'SERVICE' ? 'SAC Code' : 'HSN Code',
                          controller: _hsnController,
                        ),
                      ),
                      KSpacing.hGapMd,
                      Expanded(
                        child: KTextField(
                          label: 'GST Rate (%)',
                          controller: _gstRateController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          selectAllOnFocus: true,
                        ),
                      ),
                    ],
                  ),
                  if (_itemType != 'SERVICE') ...[
                    KSpacing.vGapMd,
                    KTextField(
                      label: 'Unit of Measure',
                      controller: _uomController,
                      prefixIcon: Icons.straighten,
                    ),
                  ],
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
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Track batches (FEFO)'),
                        subtitle: const Text(
                            'Enable batch/lot tracking with expiry dates'),
                        value: _trackBatches,
                        onChanged: (v) => setState(() => _trackBatches = v),
                      ),
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
                  KSpacing.vGapLg,

                  // ── Physical Properties ──
                  Text('Physical Properties', style: KTypography.h3),
                  KSpacing.vGapMd,
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: KTextField(
                          label: 'Weight',
                          controller: _weightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      KSpacing.hGapMd,
                      Expanded(
                        child: KTextField(
                          label: 'Unit',
                          controller: _weightUnitController,
                        ),
                      ),
                    ],
                  ),
                  KSpacing.vGapMd,
                  Row(
                    children: [
                      Expanded(
                        child: KTextField(
                          label: 'L',
                          controller: _lengthController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      KSpacing.hGapSm,
                      Expanded(
                        child: KTextField(
                          label: 'W',
                          controller: _widthController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      KSpacing.hGapSm,
                      Expanded(
                        child: KTextField(
                          label: 'H',
                          controller: _heightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      KSpacing.hGapSm,
                      SizedBox(
                        width: 60,
                        child: KTextField(
                          label: 'Unit',
                          controller: _dimensionUnitController,
                        ),
                      ),
                    ],
                  ),
                  KSpacing.vGapLg,

                  // ── Accounting ──
                  Text('Accounting', style: KTypography.h3),
                  KSpacing.vGapMd,
                  KTextField(
                    label: 'Revenue Account Code',
                    controller: _revenueAccountController,
                    prefixIcon: Icons.account_balance_outlined,
                  ),
                  KSpacing.vGapMd,
                  KTextField(
                    label: 'COGS Account Code',
                    controller: _cogsAccountController,
                    prefixIcon: Icons.account_balance_outlined,
                  ),
                  KSpacing.vGapMd,
                  KTextField(
                    label: 'Inventory Account Code',
                    controller: _inventoryAccountController,
                    prefixIcon: Icons.account_balance_outlined,
                  ),
                  KSpacing.vGapLg,

                  // ── Pharmacy (conditional) ──
                  if (ref.watch(authProvider).industry?.toUpperCase() == 'PHARMACY') ...[
                    Text('Pharmacy', style: KTypography.h3),
                    KSpacing.vGapMd,
                    Row(
                      children: [
                        Expanded(
                          child: KTextField(
                            label: 'Drug Schedule',
                            controller: _drugScheduleController,
                          ),
                        ),
                        KSpacing.hGapMd,
                        Expanded(
                          child: KTextField(
                            label: 'Dosage Form',
                            controller: _dosageFormController,
                          ),
                        ),
                      ],
                    ),
                    KSpacing.vGapMd,
                    KTextField(
                      label: 'Composition / Salt',
                      controller: _compositionController,
                      maxLines: 2,
                    ),
                    KSpacing.vGapMd,
                    Row(
                      children: [
                        Expanded(
                          child: KTextField(
                            label: 'Pack Size',
                            controller: _packSizeController,
                          ),
                        ),
                        KSpacing.hGapMd,
                        Expanded(
                          child: KTextField(
                            label: 'Storage Condition',
                            controller: _storageConditionController,
                          ),
                        ),
                      ],
                    ),
                    KSpacing.vGapMd,
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Prescription Required'),
                      value: _prescriptionRequired,
                      onChanged: (v) => setState(() => _prescriptionRequired = v),
                    ),
                    KSpacing.vGapLg,
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

/// Bottom sheet that lists item groups for selection. Returns the
/// picked group map (so the caller can read attributeDefinitions
/// without an extra round-trip) or null on dismiss.
class _GroupPickerSheet extends ConsumerWidget {
  final ScrollController scrollController;
  const _GroupPickerSheet({required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(itemGroupListProvider);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                KSpacing.md, KSpacing.md, KSpacing.md, KSpacing.sm),
            child: Text('Select Group', style: KTypography.h3),
          ),
          const Divider(height: 1),
          Flexible(
            child: groupsAsync.when(
              loading: () => const KShimmerList(),
              error: (err, st) => KErrorView(message: 'Failed: $err'),
              data: (data) {
                final content = data['data'];
                final groups = content is List
                    ? content
                    : (content is Map ? (content['content'] as List?) ?? [] : []);
                if (groups.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No item groups yet — create one first.',
                        style: KTypography.bodyMedium,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  controller: scrollController,
                  padding: KSpacing.pagePadding,
                  itemCount: groups.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final group = groups[index] as Map<String, dynamic>;
                    final defs =
                        (group['attributeDefinitions'] as List?) ?? const [];
                    return ListTile(
                      leading: const Icon(Icons.category_outlined,
                          color: KColors.primary),
                      title: Text(group['name']?.toString() ?? '',
                          style: KTypography.labelLarge),
                      subtitle: Text(
                        defs
                            .map<String>((d) =>
                                (d as Map<String, dynamic>)['key']?.toString() ?? '')
                            .where((k) => k.isNotEmpty)
                            .join(', '),
                        style: KTypography.bodySmall,
                      ),
                      onTap: () => Navigator.pop(context, group),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
