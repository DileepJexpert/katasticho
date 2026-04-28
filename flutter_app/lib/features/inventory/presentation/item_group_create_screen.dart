import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/form_error_handler.dart';
import '../data/item_group_repository.dart';

/// Create or edit an item group. Each attribute definition is a
/// `{key, values}` row in the editor — the screen serialises the rows
/// straight into the `attributeDefinitions` JSONB the backend
/// expects. The matrix bulk-create UI on the detail screen relies on
/// the values list being non-empty, so we validate that here too.
class ItemGroupCreateScreen extends ConsumerStatefulWidget {
  final String? groupId;
  const ItemGroupCreateScreen({super.key, this.groupId});

  @override
  ConsumerState<ItemGroupCreateScreen> createState() =>
      _ItemGroupCreateScreenState();
}

class _ItemGroupCreateScreenState extends ConsumerState<ItemGroupCreateScreen>
    with FormErrorHandler {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _skuPrefixController = TextEditingController();
  final _hsnController = TextEditingController();
  final _gstRateController = TextEditingController();
  final _uomController = TextEditingController(text: 'PCS');
  final _purchasePriceController = TextEditingController();
  final _salePriceController = TextEditingController();

  /// Each row is `{key: TextEditingController, values: TextEditingController}`.
  /// The values controller holds a comma-separated list which is split on save.
  final List<_AttributeRow> _attributes = [];

  bool _saving = false;
  bool _loading = false;

  bool get _isEdit => widget.groupId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _load();
    } else {
      _attributes.add(_AttributeRow.empty());
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(itemGroupRepositoryProvider);
      final result = await repo.getGroup(widget.groupId!);
      final data = (result['data'] ?? result) as Map<String, dynamic>;
      _populateFromMap(data);
    } catch (e) {
      debugPrint('[ItemGroupCreate] load FAILED: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _populateFromMap(Map<String, dynamic> data) {
    _nameController.text = data['name']?.toString() ?? '';
    _descriptionController.text = data['description']?.toString() ?? '';
    _skuPrefixController.text = data['skuPrefix']?.toString() ?? '';
    _hsnController.text = data['hsnCode']?.toString() ?? '';
    _gstRateController.text = data['gstRate']?.toString() ?? '';
    _uomController.text = data['defaultUom']?.toString() ?? 'PCS';
    _purchasePriceController.text =
        data['defaultPurchasePrice']?.toString() ?? '';
    _salePriceController.text = data['defaultSalePrice']?.toString() ?? '';

    _attributes.clear();
    final defs = (data['attributeDefinitions'] as List?) ?? const [];
    for (final d in defs) {
      final def = d as Map<String, dynamic>;
      final values = (def['values'] as List?)?.cast<dynamic>() ?? const [];
      _attributes.add(_AttributeRow(
        keyController: TextEditingController(text: def['key']?.toString() ?? ''),
        valuesController: TextEditingController(text: values.join(', ')),
      ));
    }
    if (_attributes.isEmpty) _attributes.add(_AttributeRow.empty());
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _skuPrefixController.dispose();
    _hsnController.dispose();
    _gstRateController.dispose();
    _uomController.dispose();
    _purchasePriceController.dispose();
    _salePriceController.dispose();
    for (final row in _attributes) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Build the attribute_definitions list — drop blank rows entirely
    // so the operator can leave a trailing empty row in the UI without
    // it being persisted.
    final defs = <Map<String, dynamic>>[];
    final seenKeys = <String>{};
    for (final row in _attributes) {
      final key = row.keyController.text.trim();
      if (key.isEmpty) continue;
      if (!seenKeys.add(key.toLowerCase())) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Duplicate attribute key: $key')),
        );
        return;
      }
      final values = row.valuesController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (values.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Attribute "$key" needs at least one value')),
        );
        return;
      }
      defs.add({'key': key, 'values': values});
    }

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      'skuPrefix': _skuPrefixController.text.trim().isEmpty
          ? null
          : _skuPrefixController.text.trim(),
      'hsnCode': _hsnController.text.trim().isEmpty ? null : _hsnController.text.trim(),
      'gstRate': double.tryParse(_gstRateController.text.trim()),
      'defaultUom': _uomController.text.trim().isEmpty ? null : _uomController.text.trim(),
      'defaultPurchasePrice': double.tryParse(_purchasePriceController.text.trim()),
      'defaultSalePrice': double.tryParse(_salePriceController.text.trim()),
      'attributeDefinitions': defs,
    };

    setState(() => _saving = true);
    try {
      final repo = ref.read(itemGroupRepositoryProvider);
      if (_isEdit) {
        await repo.updateGroup(widget.groupId!, payload);
      } else {
        await repo.createGroup(payload);
      }
      ref.invalidate(itemGroupListProvider);
      if (_isEdit) ref.invalidate(itemGroupDetailProvider(widget.groupId!));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEdit ? 'Group updated' : 'Group created')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      handleSaveError(e, _formKey);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addAttribute() {
    setState(() => _attributes.add(_AttributeRow.empty()));
  }

  void _removeAttribute(int index) {
    setState(() {
      _attributes[index].dispose();
      _attributes.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Group' : 'New Group')),
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
                    label: 'Group Name *',
                    controller: _nameController,
                    prefixIcon: Icons.category_outlined,
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
                  KTextField(
                    label: 'SKU Prefix',
                    controller: _skuPrefixController,
                    prefixIcon: Icons.qr_code,
                    hint: 'e.g. TEE → TEE-S-RED',
                  ),
                  KSpacing.vGapXs,
                  Text(
                    'Used by the variant matrix to mint child SKUs.',
                    style: KTypography.bodySmall,
                  ),
                  KSpacing.vGapLg,

                  Text('Defaults (inherited by new variants)',
                      style: KTypography.h3),
                  KSpacing.vGapXs,
                  Text(
                    'These values are copied onto each new variant only at create time. Editing the group later does not change existing variants.',
                    style: KTypography.bodySmall,
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
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
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
                  KSpacing.vGapMd,
                  Row(
                    children: [
                      Expanded(
                        child: KTextField.amount(
                          label: 'Default Purchase Price',
                          controller: _purchasePriceController,
                        ),
                      ),
                      KSpacing.hGapMd,
                      Expanded(
                        child: KTextField.amount(
                          label: 'Default Sale Price',
                          controller: _salePriceController,
                        ),
                      ),
                    ],
                  ),
                  KSpacing.vGapLg,

                  Row(
                    children: [
                      Expanded(
                        child: Text('Attribute Definitions',
                            style: KTypography.h3),
                      ),
                      TextButton.icon(
                        onPressed: _addAttribute,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  KSpacing.vGapXs,
                  Text(
                    'Each row is a closed list — variants must use only the keys and values defined here. Separate values with commas.',
                    style: KTypography.bodySmall,
                  ),
                  KSpacing.vGapMd,
                  ..._attributes.asMap().entries.map((entry) {
                    final i = entry.key;
                    final row = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: KSpacing.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: KTextField(
                              label: 'Key',
                              controller: row.keyController,
                              hint: 'e.g. size',
                            ),
                          ),
                          KSpacing.hGapSm,
                          Expanded(
                            flex: 4,
                            child: KTextField(
                              label: 'Values (comma-separated)',
                              controller: row.valuesController,
                              hint: 'e.g. S, M, L, XL',
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(Icons.remove_circle_outline,
                                color: KColors.error),
                            onPressed: _attributes.length == 1
                                ? null
                                : () => _removeAttribute(i),
                          ),
                        ],
                      ),
                    );
                  }),
                  KSpacing.vGapXl,
                  KButton(
                    label: _isEdit ? 'Save Changes' : 'Create Group',
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

class _AttributeRow {
  final TextEditingController keyController;
  final TextEditingController valuesController;

  _AttributeRow({required this.keyController, required this.valuesController});

  factory _AttributeRow.empty() => _AttributeRow(
        keyController: TextEditingController(),
        valuesController: TextEditingController(),
      );

  void dispose() {
    keyController.dispose();
    valuesController.dispose();
  }
}
