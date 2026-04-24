import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../settings/data/feature_flag_repository.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';
import '../data/item_group_repository.dart';
import '../data/item_repository.dart';
import '../data/uom_repository.dart';

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

  // Opening batch fields (shown when trackBatches=true AND openingStock > 0)
  final _openingBatchNumberController = TextEditingController();
  DateTime? _openingMfgDate;
  DateTime? _openingExpiryDate;

  String _itemType = 'GOODS';
  bool _trackInventory = true;
  bool _trackBatches = false;
  bool _prescriptionRequired = false;
  bool _saving = false;
  bool _loading = false;
  Map<String, String> _serverErrors = {};

  // Purchase & Sales Units
  bool _hasDifferentPurchaseUnit = false;
  String? _purchaseUomAbbr;
  final _purchaseConversionController = TextEditingController();
  final _purchasePricePerUomController = TextEditingController();
  List<_SecondaryUnit> _secondaryUnits = [];
  List<Map<String, dynamic>> _availableUoms = [];

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
    _loadUoms();
    if (widget.initial != null) {
      _populateFromMap(widget.initial!);
    } else if (_isEdit) {
      _loadItem();
    }
  }

  Future<void> _loadUoms() async {
    try {
      final repo = ref.read(uomRepositoryProvider);
      final uoms = await repo.listUoms();
      if (mounted) setState(() => _availableUoms = uoms);
    } catch (_) {}
  }

  void _syncPurchasePrice() {
    final conv = double.tryParse(_purchaseConversionController.text) ?? 0;
    final pricePerUom = double.tryParse(_purchasePricePerUomController.text) ?? 0;
    if (conv > 0 && pricePerUom > 0) {
      final perBase = (pricePerUom / conv).toStringAsFixed(2);
      _purchasePriceController.text = perBase;
    }
    setState(() {});
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
    // Purchase UoM
    final pUom = data['purchaseUom']?.toString();
    if (pUom != null && pUom.isNotEmpty) {
      _hasDifferentPurchaseUnit = true;
      _purchaseUomAbbr = pUom;
      _purchaseConversionController.text = (data['purchaseUomConversion'] ?? '').toString();
      _purchasePricePerUomController.text = (data['purchasePricePerUom'] ?? '').toString();
    }
    // Secondary units
    final secUnits = data['secondaryUnits'] as List?;
    if (secUnits != null && secUnits.isNotEmpty) {
      _secondaryUnits = secUnits.map((u) {
        final su = _SecondaryUnit();
        su.uomAbbr = u['uomAbbreviation']?.toString();
        su.conversionController.text = (u['conversionFactor'] ?? '').toString();
        su.priceController.text = (u['customPrice'] ?? '').toString();
        return su;
      }).toList();
    }

    if (_groupId != null) {
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
    _openingBatchNumberController.dispose();
    _purchaseConversionController.dispose();
    _purchasePricePerUomController.dispose();
    for (final su in _secondaryUnits) {
      su.conversionController.dispose();
      su.priceController.dispose();
    }
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
      final openingStock = double.tryParse(_openingStockController.text) ?? 0;
      payload['openingStock'] = openingStock;
      if (_trackBatches && openingStock > 0) {
        payload['openingBatchNumber'] = _openingBatchNumberController.text.trim();
        if (_openingMfgDate != null) {
          payload['openingMfgDate'] = _openingMfgDate!.toIso8601String().substring(0, 10);
        }
        if (_openingExpiryDate != null) {
          payload['openingExpiryDate'] = _openingExpiryDate!.toIso8601String().substring(0, 10);
        }
      }
    }

    // Purchase UoM
    if (_hasDifferentPurchaseUnit && _purchaseUomAbbr != null) {
      payload['purchaseUom'] = _purchaseUomAbbr;
      payload['purchaseUomConversion'] = double.tryParse(_purchaseConversionController.text);
      payload['purchasePricePerUom'] = double.tryParse(_purchasePricePerUomController.text);
    }

    // Secondary units
    if (_secondaryUnits.isNotEmpty) {
      payload['secondaryUnits'] = _secondaryUnits
          .where((su) => su.uomAbbr != null && su.uomAbbr!.isNotEmpty)
          .map((su) {
            final m = <String, dynamic>{
              'uomAbbreviation': su.uomAbbr,
              'conversionFactor': double.tryParse(su.conversionController.text) ?? 1,
            };
            final p = double.tryParse(su.priceController.text);
            if (p != null && p > 0) m['customPrice'] = p;
            return m;
          })
          .toList();
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

  Widget _buildPurchaseSalesUnitsSection() {
    final baseUnit = _uomController.text.trim().isEmpty ? 'PCS' : _uomController.text.trim();
    final uomItems = _availableUoms
        .map((u) => u['abbreviation']?.toString() ?? '')
        .where((a) => a.isNotEmpty)
        .toList();

    // Auto-calculate cost per base unit
    String costPerBase = '';
    final conv = double.tryParse(_purchaseConversionController.text) ?? 0;
    final pricePerUom = double.tryParse(_purchasePricePerUomController.text) ?? 0;
    if (conv > 0 && pricePerUom > 0) {
      costPerBase = CurrencyFormatter.formatIndian(pricePerUom / conv);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Purchase & Sales Units', style: KTypography.h3),
        KSpacing.vGapXs,
        Text('How do you buy & sell this item?', style: KTypography.bodySmall),
        KSpacing.vGapMd,

        // Selling unit (base unit)
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: uomItems.contains(baseUnit.toUpperCase()) ? baseUnit.toUpperCase()
                    : (uomItems.contains(baseUnit) ? baseUnit : null),
                decoration: const InputDecoration(
                  labelText: 'Selling Unit (base)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  if (!uomItems.contains(baseUnit) && !uomItems.contains(baseUnit.toUpperCase()))
                    DropdownMenuItem(value: baseUnit, child: Text(baseUnit)),
                  ...uomItems.map((a) => DropdownMenuItem(value: a, child: Text(a))),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _uomController.text = v);
                  }
                },
              ),
            ),
            KSpacing.hGapMd,
            Expanded(
              child: KTextField.amount(
                label: 'Selling Price',
                controller: _salePriceController,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        KSpacing.vGapMd,

        // Purchase unit toggle
        DropdownButtonFormField<bool>(
          value: _hasDifferentPurchaseUnit,
          decoration: const InputDecoration(
            labelText: 'Purchase Unit',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: const [
            DropdownMenuItem(value: false, child: Text('Same as selling unit')),
            DropdownMenuItem(value: true, child: Text('Different unit')),
          ],
          onChanged: (v) => setState(() {
            _hasDifferentPurchaseUnit = v ?? false;
            if (!_hasDifferentPurchaseUnit) {
              _purchaseUomAbbr = null;
              _purchaseConversionController.clear();
              _purchasePricePerUomController.clear();
            }
          }),
        ),

        if (_hasDifferentPurchaseUnit) ...[
          KSpacing.vGapMd,
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: _purchaseUomAbbr,
                  decoration: const InputDecoration(
                    labelText: 'Purchase Unit',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: uomItems
                      .where((a) => a != baseUnit && a != baseUnit.toUpperCase())
                      .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                      .toList(),
                  onChanged: (v) => setState(() => _purchaseUomAbbr = v),
                ),
                KSpacing.vGapMd,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('1 ${_purchaseUomAbbr ?? '?'} = ', style: KTypography.labelLarge),
                    Expanded(
                      child: KTextField(
                        label: baseUnit,
                        controller: _purchaseConversionController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => _syncPurchasePrice(),
                      ),
                    ),
                  ],
                ),
                KSpacing.vGapMd,
                KTextField.amount(
                  label: 'Purchase Price per ${_purchaseUomAbbr ?? 'unit'}',
                  controller: _purchasePricePerUomController,
                  onChanged: (_) => _syncPurchasePrice(),
                ),
                if (costPerBase.isNotEmpty) ...[
                  KSpacing.vGapSm,
                  Row(
                    children: [
                      Icon(Icons.calculate_outlined, size: 14, color: KColors.success),
                      const SizedBox(width: 4),
                      Text(
                        'Auto-calculated: $costPerBase per $baseUnit',
                        style: KTypography.labelSmall.copyWith(
                          color: KColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],

        // Secondary selling units
        KSpacing.vGapMd,
        if (_secondaryUnits.isNotEmpty)
          ..._secondaryUnits.asMap().entries.map((entry) {
            final idx = entry.key;
            final su = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: KSpacing.md),
              child: KCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            idx == 0 ? 'Also sold as' : 'Additional unit',
                            style: KTypography.labelLarge,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            setState(() {
                              _secondaryUnits[idx].conversionController.dispose();
                              _secondaryUnits[idx].priceController.dispose();
                              _secondaryUnits.removeAt(idx);
                            });
                          },
                        ),
                      ],
                    ),
                    KSpacing.vGapSm,
                    DropdownButtonFormField<String>(
                      value: su.uomAbbr,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: uomItems
                          .where((a) => a != baseUnit && a != baseUnit.toUpperCase())
                          .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                          .toList(),
                      onChanged: (v) => setState(() => su.uomAbbr = v),
                    ),
                    KSpacing.vGapSm,
                    Row(
                      children: [
                        Text('1 $baseUnit = ', style: KTypography.labelLarge),
                        Expanded(
                          child: KTextField(
                            label: su.uomAbbr ?? 'units',
                            controller: su.conversionController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ),
                    KSpacing.vGapSm,
                    KTextField.amount(
                      label: 'Custom price per ${su.uomAbbr ?? 'unit'} (optional)',
                      controller: su.priceController,
                    ),
                  ],
                ),
              ),
            );
          }),
        OutlinedButton.icon(
          onPressed: () {
            setState(() => _secondaryUnits.add(_SecondaryUnit()));
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add another selling unit'),
        ),
      ],
    );
  }

  Widget _buildMrpMarginHint() {
    final mrp = double.tryParse(_mrpController.text) ?? 0;
    final purchasePrice = double.tryParse(_purchasePriceController.text) ?? 0;
    final salePrice = double.tryParse(_salePriceController.text) ?? 0;

    if (mrp <= 0) return const SizedBox.shrink();

    final margin = ((mrp - purchasePrice) / mrp * 100);
    final sellingAtLoss = salePrice > 0 && salePrice < purchasePrice;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (purchasePrice > 0)
            Row(
              children: [
                Icon(Icons.trending_up, size: 14, color: KColors.success),
                const SizedBox(width: 4),
                Text(
                  'Margin: ${margin.toStringAsFixed(1)}%',
                  style: KTypography.labelSmall.copyWith(
                    color: margin >= 0 ? KColors.success : KColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(MRP ${CurrencyFormatter.formatIndian(mrp)} − Cost ${CurrencyFormatter.formatIndian(purchasePrice)})',
                  style: KTypography.labelSmall.copyWith(
                    color: KColors.textHint,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          if (sellingAtLoss)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 14, color: KColors.warning),
                  const SizedBox(width: 4),
                  Text(
                    'Sale price is below purchase price — selling at loss',
                    style: KTypography.labelSmall.copyWith(
                      color: KColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
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
                  // ── Basic Info (always open) ──
                  KCollapsibleSection(
                    title: 'Basic Info',
                    icon: Icons.info_outline,
                    initiallyExpanded: true,
                    children: [
                      KCompactRow(children: [
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
                        KTextField(
                          label: 'Barcode',
                          controller: _barcodeController,
                          prefixIcon: Icons.barcode_reader,
                        ),
                      ]),
                      KSpacing.vGapSm,
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
                      KSpacing.vGapSm,
                      KTextField(
                        label: 'Description',
                        controller: _descriptionController,
                        maxLines: 2,
                      ),
                      KSpacing.vGapSm,
                      KCompactRow(flex: const [1, 1, 1], children: [
                        KTextField(
                          label: 'Category',
                          controller: _categoryController,
                        ),
                        KTextField(
                          label: 'Brand',
                          controller: _brandController,
                        ),
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
                      ]),
                      KSpacing.vGapSm,
                      KTextField(
                        label: 'Manufacturer',
                        controller: _manufacturerController,
                      ),
                      if (_itemType == 'GOODS') ...[
                        KSpacing.vGapSm,
                        _buildGroupSection(),
                      ],
                    ],
                  ),

                  // ── Pricing & Tax (always open) ──
                  KCollapsibleSection(
                    title: 'Pricing & Tax',
                    icon: Icons.currency_rupee,
                    initiallyExpanded: true,
                    children: [
                      KCompactRow(children: [
                        KTextField.amount(
                          label: 'Purchase Price',
                          controller: _purchasePriceController,
                          onChanged: (_) => setState(() {}),
                          validator: (v) => _serverErrors['purchasePrice'],
                        ),
                        KTextField.amount(
                          label: 'Sale Price',
                          controller: _salePriceController,
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            if (_serverErrors.containsKey('salePrice')) {
                              return _serverErrors['salePrice'];
                            }
                            final salePrice = double.tryParse(v ?? '') ?? 0;
                            final mrp = double.tryParse(_mrpController.text) ?? 0;
                            if (mrp > 0 && salePrice > mrp) {
                              return 'Cannot exceed MRP';
                            }
                            return null;
                          },
                        ),
                      ]),
                      if (ref.watch(featureFlagsProvider).valueOrNull?.contains('MRP_PRICING') == true) ...[
                        KSpacing.vGapSm,
                        KTextField.amount(
                          label: 'MRP (Maximum Retail Price)',
                          controller: _mrpController,
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            final mrp = double.tryParse(v ?? '') ?? 0;
                            final salePrice = double.tryParse(_salePriceController.text) ?? 0;
                            if (mrp > 0 && salePrice > mrp) {
                              return 'Sale price cannot exceed MRP';
                            }
                            return null;
                          },
                        ),
                        _buildMrpMarginHint(),
                      ],
                      KSpacing.vGapSm,
                      KCompactRow(children: [
                        KTextField(
                          label: _itemType == 'SERVICE' ? 'SAC Code' : 'HSN Code',
                          controller: _hsnController,
                        ),
                        KTextField(
                          label: 'GST Rate (%)',
                          controller: _gstRateController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          selectAllOnFocus: true,
                        ),
                      ]),
                      if (_itemType != 'SERVICE') ...[
                        KSpacing.vGapSm,
                        _buildPurchaseSalesUnitsSection(),
                      ],
                    ],
                  ),

                  if (_itemType == 'COMPOSITE') ...[
                    KSpacing.vGapSm,
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
                  ],

                  // ── Inventory (collapsed by default) ──
                  if (_itemType == 'GOODS')
                    KCollapsibleSection(
                      title: 'Inventory',
                      icon: Icons.inventory_2_outlined,
                      initiallyExpanded: false,
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text('Track inventory'),
                          subtitle: const Text(
                              'Stock levels tracked through invoices and adjustments'),
                          value: _trackInventory,
                          onChanged: (v) => setState(() => _trackInventory = v),
                        ),
                        if (_trackInventory) ...[
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: const Text('Track batches (FEFO)'),
                            subtitle: const Text(
                                'Batch/lot tracking with expiry dates'),
                            value: _trackBatches,
                            onChanged: (v) => setState(() => _trackBatches = v),
                          ),
                          KSpacing.vGapSm,
                          KCompactRow(children: [
                            KTextField(
                              label: 'Reorder Level',
                              controller: _reorderLevelController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                            KTextField(
                              label: 'Reorder Qty',
                              controller: _reorderQtyController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ]),
                          if (!_isEdit) ...[
                            KSpacing.vGapSm,
                            KTextField(
                              label: 'Opening Stock',
                              controller: _openingStockController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              prefixIcon: Icons.inventory_outlined,
                              onChanged: (_) => setState(() {}),
                            ),
                            if (_trackBatches && (double.tryParse(_openingStockController.text) ?? 0) > 0) ...[
                              KSpacing.vGapSm,
                              KCard(
                                padding: const EdgeInsets.all(KSpacing.sm),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Opening Batch', style: KTypography.labelLarge),
                                    KSpacing.vGapSm,
                                    KTextField(
                                      label: 'Batch Number *',
                                      controller: _openingBatchNumberController,
                                      prefixIcon: Icons.confirmation_number_outlined,
                                      hint: 'From product packaging',
                                      validator: (v) {
                                        if (_trackBatches && (double.tryParse(_openingStockController.text) ?? 0) > 0) {
                                          if (v == null || v.trim().isEmpty) return 'Batch number is required';
                                        }
                                        return null;
                                      },
                                    ),
                                    KSpacing.vGapSm,
                                    KCompactRow(children: [
                                      _DatePickerField(
                                        label: 'Mfg Date',
                                        value: _openingMfgDate,
                                        onPicked: (d) => setState(() => _openingMfgDate = d),
                                      ),
                                      _DatePickerField(
                                        label: 'Expiry Date',
                                        value: _openingExpiryDate,
                                        onPicked: (d) => setState(() => _openingExpiryDate = d),
                                      ),
                                    ]),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ],
                      ],
                    ),

                  // ── Physical Properties (collapsed) ──
                  if (_itemType == 'GOODS')
                    KCollapsibleSection(
                      title: 'Physical Properties',
                      icon: Icons.straighten_outlined,
                      children: [
                        KCompactRow(flex: const [2, 1], children: [
                          KTextField(
                            label: 'Weight',
                            controller: _weightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                          KTextField(
                            label: 'Unit',
                            controller: _weightUnitController,
                          ),
                        ]),
                        KSpacing.vGapSm,
                        KCompactRow(flex: const [1, 1, 1, 1], children: [
                          KTextField(
                            label: 'L',
                            controller: _lengthController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                          KTextField(
                            label: 'W',
                            controller: _widthController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                          KTextField(
                            label: 'H',
                            controller: _heightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                          KTextField(
                            label: 'Unit',
                            controller: _dimensionUnitController,
                          ),
                        ]),
                      ],
                    ),

                  // ── Accounting (collapsed) ──
                  KCollapsibleSection(
                    title: 'Accounting',
                    icon: Icons.account_balance_outlined,
                    children: [
                      KTextField(
                        label: 'Revenue Account Code',
                        controller: _revenueAccountController,
                        prefixIcon: Icons.account_balance_outlined,
                      ),
                      KSpacing.vGapSm,
                      KTextField(
                        label: 'COGS Account Code',
                        controller: _cogsAccountController,
                        prefixIcon: Icons.account_balance_outlined,
                      ),
                      KSpacing.vGapSm,
                      KTextField(
                        label: 'Inventory Account Code',
                        controller: _inventoryAccountController,
                        prefixIcon: Icons.account_balance_outlined,
                      ),
                    ],
                  ),

                  // ── Pharmacy (collapsed, conditional) ──
                  if (ref.watch(featureFlagsProvider).valueOrNull?.contains('DRUG_SCHEDULE_FIELDS') == true)
                    KCollapsibleSection(
                      title: 'Pharmacy',
                      icon: Icons.local_pharmacy_outlined,
                      children: [
                        KCompactRow(children: [
                          KTextField(
                            label: 'Drug Schedule',
                            controller: _drugScheduleController,
                          ),
                          KTextField(
                            label: 'Dosage Form',
                            controller: _dosageFormController,
                          ),
                        ]),
                        KSpacing.vGapSm,
                        KTextField(
                          label: 'Composition / Salt',
                          controller: _compositionController,
                          maxLines: 2,
                        ),
                        KSpacing.vGapSm,
                        KCompactRow(children: [
                          KTextField(
                            label: 'Pack Size',
                            controller: _packSizeController,
                          ),
                          KTextField(
                            label: 'Storage Condition',
                            controller: _storageConditionController,
                          ),
                        ]),
                        KSpacing.vGapSm,
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text('Prescription Required'),
                          value: _prescriptionRequired,
                          onChanged: (v) => setState(() => _prescriptionRequired = v),
                        ),
                      ],
                    ),

                  KSpacing.vGapLg,
                  KButton(
                    label: _isEdit ? 'Update' : 'Create Item',
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

class _SecondaryUnit {
  String? uomAbbr;
  final conversionController = TextEditingController();
  final priceController = TextEditingController();
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onPicked;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    final display = value != null
        ? '${value!.day.toString().padLeft(2, '0')}-${value!.month.toString().padLeft(2, '0')}-${value!.year}'
        : '';
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        onPicked(picked);
      },
      child: AbsorbPointer(
        child: TextFormField(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: value != null
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => onPicked(null),
                  )
                : const Icon(Icons.calendar_today, size: 18),
          ),
          controller: TextEditingController(text: display),
        ),
      ),
    );
  }
}

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
