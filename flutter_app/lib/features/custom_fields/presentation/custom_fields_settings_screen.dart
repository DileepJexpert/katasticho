import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../../../core/widgets/k_text_field.dart';
import '../data/custom_field_models.dart';
import '../data/custom_field_repository.dart';

class CustomFieldsSettingsScreen extends ConsumerStatefulWidget {
  const CustomFieldsSettingsScreen({super.key});

  @override
  ConsumerState<CustomFieldsSettingsScreen> createState() =>
      _CustomFieldsSettingsScreenState();
}

class _CustomFieldsSettingsScreenState
    extends ConsumerState<CustomFieldsSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const List<Map<String, String>> _entityTabs = [
    {'type': 'CONTACT', 'label': 'Contacts'},
    {'type': 'ITEM', 'label': 'Items / Products'},
    {'type': 'INVOICE', 'label': 'Sales Invoices'},
    {'type': 'SALES_ORDER', 'label': 'Sales Orders'},
    {'type': 'PURCHASE_BILL', 'label': 'Purchase Bills'},
    {'type': 'DELIVERY_CHALLAN', 'label': 'Delivery Challans'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _entityTabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _currentEntityType =>
      _entityTabs[_tabController.index]['type']!;

  void _openFieldDialog({CustomFieldDefinition? field}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomFieldFormModal(
        entityType: _currentEntityType,
        existingField: field,
        onSaved: () {
          ref.invalidate(customFieldDefinitionsProvider(_currentEntityType));
          ref.invalidate(allCustomFieldDefinitionsProvider);
        },
      ),
    );
  }

  Future<void> _deleteField(CustomFieldDefinition field) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Custom Field'),
        content: Text(
          'Are you sure you want to delete "${field.fieldLabel}"? Existing recorded values will be archived.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: KColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(customFieldRepositoryProvider).deleteDefinition(field.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Field deleted successfully')),
          );
          ref.invalidate(customFieldDefinitionsProvider(_currentEntityType));
          ref.invalidate(allCustomFieldDefinitionsProvider);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete field: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User-Defined Custom Fields (UDF)'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: KSpacing.md),
            child: KButton(
              label: 'Add Custom Field',
              icon: Icons.add,
              onPressed: () => _openFieldDialog(),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: KColors.primary,
          unselectedLabelColor: KColors.textSecondary,
          indicatorColor: KColors.primary,
          tabs: _entityTabs
              .map((tab) => Tab(text: tab['label']))
              .toList(),
          onTap: (_) => setState(() {}),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _entityTabs.map((tab) {
          return _EntityFieldsList(
            entityType: tab['type']!,
            onEdit: (field) => _openFieldDialog(field: field),
            onDelete: _deleteField,
          );
        }).toList(),
      ),
    );
  }
}

class _EntityFieldsList extends ConsumerWidget {
  final String entityType;
  final void Function(CustomFieldDefinition) onEdit;
  final void Function(CustomFieldDefinition) onDelete;

  const _EntityFieldsList({
    required this.entityType,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fieldsAsync = ref.watch(customFieldDefinitionsProvider(entityType));

    return fieldsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Error loading fields: $e', style: KTypography.bodySmall),
      ),
      data: (fields) {
        if (fields.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.tune_outlined, size: 48, color: KColors.textSecondary),
                KSpacing.vGapMd,
                Text('No custom fields defined yet', style: KTypography.h4),
                KSpacing.vGapXs,
                Text(
                  'Click "Add Custom Field" to attach metadata to this module.',
                  style: KTypography.bodySmall,
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(KSpacing.md),
          itemCount: fields.length,
          separatorBuilder: (_, __) => KSpacing.vGapSm,
          itemBuilder: (context, index) {
            final field = fields[index];
            return KCard(
              padding: const EdgeInsets.all(KSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: KColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(KSpacing.radiusMd),
                    ),
                    child: Center(
                      child: Text(
                        '#${index + 1}',
                        style: KTypography.amountLarge.copyWith(
                          fontSize: 13,
                          color: KColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  KSpacing.hGapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(field.fieldLabel, style: KTypography.h4),
                            if (field.isRequired) ...[
                              KSpacing.hGapXs,
                              const Text('*', style: TextStyle(color: KColors.error, fontWeight: FontWeight.bold)),
                            ],
                            KSpacing.hGapSm,
                            KStatusChip(status: field.fieldType.label),
                            if (!field.isActive) ...[
                              KSpacing.hGapXs,
                              const KStatusChip(status: 'INACTIVE'),
                            ],
                          ],
                        ),
                        KSpacing.vGapXs,
                        Row(
                          children: [
                            Text('Key: ', style: KTypography.caption),
                            Text(
                              field.fieldName,
                              style: KTypography.caption.copyWith(fontWeight: FontWeight.w600),
                            ),
                            if (field.showInPdf) ...[
                              KSpacing.hGapMd,
                              const Icon(Icons.picture_as_pdf_outlined, size: 14, color: KColors.textSecondary),
                              KSpacing.hGapXs,
                              Text('Print on PDF', style: KTypography.caption),
                            ],
                            if (field.showInGrid) ...[
                              KSpacing.hGapMd,
                              const Icon(Icons.table_chart_outlined, size: 14, color: KColors.textSecondary),
                              KSpacing.hGapXs,
                              Text('Table Grid', style: KTypography.caption),
                            ],
                          ],
                        ),
                        if (field.options.isNotEmpty) ...[
                          KSpacing.vGapXs,
                          Text(
                            'Options: ${field.options.join(", ")}',
                            style: KTypography.caption.copyWith(color: KColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: 'Edit Field',
                    onPressed: () => onEdit(field),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: KColors.error),
                    tooltip: 'Delete Field',
                    onPressed: () => onDelete(field),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CustomFieldFormModal extends ConsumerStatefulWidget {
  final String entityType;
  final CustomFieldDefinition? existingField;
  final VoidCallback onSaved;

  const _CustomFieldFormModal({
    required this.entityType,
    this.existingField,
    required this.onSaved,
  });

  @override
  ConsumerState<_CustomFieldFormModal> createState() =>
      _CustomFieldFormModalState();
}

class _CustomFieldFormModalState extends ConsumerState<_CustomFieldFormModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _defaultCtrl;
  late final TextEditingController _regexCtrl;
  late final TextEditingController _optionsCtrl;

  late FieldType _fieldType;
  late bool _isRequired;
  late bool _showInGrid;
  late bool _showInPdf;
  late bool _isActive;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final f = widget.existingField;
    _labelCtrl = TextEditingController(text: f?.fieldLabel ?? '');
    _nameCtrl = TextEditingController(text: f?.fieldName ?? '');
    _defaultCtrl = TextEditingController(text: f?.defaultValue ?? '');
    _regexCtrl = TextEditingController(text: f?.validationRegex ?? '');
    _optionsCtrl = TextEditingController(text: f?.options.join(', ') ?? '');

    _fieldType = f?.fieldType ?? FieldType.text;
    _isRequired = f?.isRequired ?? false;
    _showInGrid = f?.showInGrid ?? false;
    _showInPdf = f?.showInPdf ?? false;
    _isActive = f?.isActive ?? true;

    _labelCtrl.addListener(_autoGenerateFieldName);
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _nameCtrl.dispose();
    _defaultCtrl.dispose();
    _regexCtrl.dispose();
    _optionsCtrl.dispose();
    super.dispose();
  }

  void _autoGenerateFieldName() {
    if (widget.existingField != null) return;
    final slug = _labelCtrl.text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    _nameCtrl.text = slug;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final options = _fieldType == FieldType.dropdown
          ? _optionsCtrl.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList()
          : <String>[];

      final payload = {
        'entityType': widget.entityType,
        'fieldName': _nameCtrl.text.trim(),
        'fieldLabel': _labelCtrl.text.trim(),
        'fieldType': _fieldType.name.toUpperCase(),
        'isRequired': _isRequired,
        'defaultValue': _defaultCtrl.text.trim().isEmpty ? null : _defaultCtrl.text.trim(),
        'options': options,
        'validationRegex': _regexCtrl.text.trim().isEmpty ? null : _regexCtrl.text.trim(),
        'showInGrid': _showInGrid,
        'showInPdf': _showInPdf,
        'isActive': _isActive,
      };

      if (widget.existingField == null) {
        await ref.read(customFieldRepositoryProvider).createDefinition(payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Custom field created successfully')),
          );
        }
      } else {
        await ref
            .read(customFieldRepositoryProvider)
            .updateDefinition(widget.existingField!.id, payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Custom field updated successfully')),
          );
        }
      }

      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving field: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(KSpacing.radiusLg)),
      ),
      padding: EdgeInsets.only(
        top: KSpacing.lg,
        left: KSpacing.lg,
        right: KSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + KSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existingField == null
                        ? 'New Custom Field'
                        : 'Edit Custom Field',
                    style: KTypography.h3,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              KSpacing.vGapMd,
              KTextField(
                controller: _labelCtrl,
                label: 'Field Label',
                isRequired: true,
                hint: 'e.g. Drug License Number, FSSAI Code',
                validator: (v) => v == null || v.trim().isEmpty ? 'Label is required' : null,
              ),
              KSpacing.vGapSm,
              KTextField(
                controller: _nameCtrl,
                label: 'Field Key (Slug)',
                isRequired: true,
                hint: 'e.g. drug_license_no',
                readOnly: widget.existingField != null,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Key is required';
                  if (!RegExp(r'^[a-z0-9_]{2,50}$').hasMatch(v.trim())) {
                    return 'Must be 2-50 lowercase alphanumeric characters with underscores';
                  }
                  return null;
                },
              ),
              KSpacing.vGapSm,
              Text('Field Type', style: KTypography.labelLarge),
              KSpacing.vGapXs,
              DropdownButtonFormField<FieldType>(
                initialValue: _fieldType,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: KSpacing.md, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(KSpacing.radiusMd)),
                ),
                items: FieldType.values.map((t) {
                  return DropdownMenuItem(value: t, child: Text(t.label));
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _fieldType = v);
                },
              ),
              if (_fieldType == FieldType.dropdown) ...[
                KSpacing.vGapSm,
                KTextField(
                  controller: _optionsCtrl,
                  label: 'Dropdown Options (comma separated)',
                  isRequired: true,
                  hint: 'e.g. Category A, Category B, Category C',
                  validator: (v) => v == null || v.trim().isEmpty ? 'Options are required for dropdown' : null,
                ),
              ],
              KSpacing.vGapSm,
              KTextField(
                controller: _defaultCtrl,
                label: 'Default Value (Optional)',
                hint: 'Default value when creating records',
              ),
              KSpacing.vGapSm,
              KTextField(
                controller: _regexCtrl,
                label: 'Validation Regex Pattern (Optional)',
                hint: r'e.g. ^[0-9]{2}[A-Z]{5}[0-9]{4}$',
              ),
              KSpacing.vGapMd,
              const Divider(color: KColors.border),
              SwitchListTile.adaptive(
                title: const Text('Mandatory (Required Field)'),
                subtitle: const Text('Prevent saving document/record if this field is empty'),
                value: _isRequired,
                activeTrackColor: KColors.primary,
                onChanged: (v) => setState(() => _isRequired = v),
              ),
              SwitchListTile.adaptive(
                title: const Text('Print on PDF Vouchers'),
                subtitle: const Text('Include this custom field on generated invoice / challan printouts'),
                value: _showInPdf,
                activeTrackColor: KColors.primary,
                onChanged: (v) => setState(() => _showInPdf = v),
              ),
              SwitchListTile.adaptive(
                title: const Text('Show as Table Column'),
                subtitle: const Text('Display this field in the main data grid view'),
                value: _showInGrid,
                activeTrackColor: KColors.primary,
                onChanged: (v) => setState(() => _showInGrid = v),
              ),
              KSpacing.vGapLg,
              SizedBox(
                width: double.infinity,
                child: KButton(
                  label: _saving ? 'Saving...' : 'Save Custom Field',
                  icon: Icons.check,
                  isLoading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
