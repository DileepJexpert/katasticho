import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../features/custom_fields/data/custom_field_models.dart';
import '../../features/custom_fields/data/custom_field_repository.dart';
import '../theme/k_colors.dart';
import '../theme/k_spacing.dart';
import '../theme/k_typography.dart';
import 'k_card.dart';
import 'k_text_field.dart';

class KCustomFieldsRenderer extends ConsumerStatefulWidget {
  final String entityType;
  final String? entityId;
  final List<CustomFieldValueDTO>? initialValues;
  final void Function(List<CustomFieldValueInput> values)? onChanged;

  const KCustomFieldsRenderer({
    super.key,
    required this.entityType,
    this.entityId,
    this.initialValues,
    this.onChanged,
  });

  @override
  ConsumerState<KCustomFieldsRenderer> createState() => KCustomFieldsRendererState();
}

class KCustomFieldsRendererState extends ConsumerState<KCustomFieldsRenderer> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _boolValues = {};
  final Map<String, String?> _dropdownValues = {};
  final Map<String, String?> _dateValues = {};
  List<CustomFieldDefinition> _definitions = [];
  bool _initialized = false;

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _initializeValues(List<CustomFieldDefinition> definitions) {
    if (_initialized) return;
    _definitions = definitions;

    final initialMap = <String, String>{};
    if (widget.initialValues != null) {
      for (final val in widget.initialValues!) {
        initialMap[val.fieldDefinitionId] = val.displayValue;
      }
    }

    for (final def in definitions) {
      final initVal = initialMap[def.id] ?? def.defaultValue ?? '';
      if (def.fieldType == FieldType.boolean) {
        _boolValues[def.id] = initVal.toLowerCase() == 'true' ||
            initVal == '1' ||
            initVal.toLowerCase() == 'yes';
      } else if (def.fieldType == FieldType.dropdown) {
        _dropdownValues[def.id] = def.options.contains(initVal)
            ? initVal
            : (def.options.isNotEmpty ? def.options.first : null);
      } else if (def.fieldType == FieldType.date) {
        _dateValues[def.id] = initVal.isNotEmpty ? initVal : null;
        _controllers[def.id] = TextEditingController(text: initVal);
      } else {
        _controllers[def.id] = TextEditingController(text: initVal);
      }
    }
    _initialized = true;
  }

  List<CustomFieldValueInput> getValues() {
    final results = <CustomFieldValueInput>[];
    for (final def in _definitions) {
      String? val;
      if (def.fieldType == FieldType.boolean) {
        val = (_boolValues[def.id] ?? false).toString();
      } else if (def.fieldType == FieldType.dropdown) {
        val = _dropdownValues[def.id] ?? '';
      } else if (def.fieldType == FieldType.date) {
        val = _dateValues[def.id] ?? _controllers[def.id]?.text ?? '';
      } else {
        val = _controllers[def.id]?.text.trim() ?? '';
      }

      results.add(CustomFieldValueInput(
        fieldDefinitionId: def.id,
        fieldName: def.fieldName,
        value: val,
      ));
    }
    return results;
  }

  void _notifyChange() {
    if (widget.onChanged != null) {
      widget.onChanged!(getValues());
    }
  }

  Future<void> _pickDate(String defId, BuildContext context) async {
    final initialDate = DateTime.tryParse(_dateValues[defId] ?? '') ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2099),
    );
    if (picked != null) {
      final formatted = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {
        _dateValues[defId] = formatted;
        _controllers[defId]?.text = formatted;
      });
      _notifyChange();
    }
  }

  @override
  Widget build(BuildContext context) {
    final defsAsync = ref.watch(customFieldDefinitionsProvider(widget.entityType));

    return defsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (definitions) {
        if (definitions.isEmpty) return const SizedBox.shrink();
        _initializeValues(definitions);

        return KCard(
          padding: const EdgeInsets.all(KSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune_outlined, size: 18, color: KColors.primary),
                  KSpacing.hGapSm,
                  Text('Custom Fields (UDF)', style: KTypography.h4),
                ],
              ),
              KSpacing.vGapMd,
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 600;
                  return Wrap(
                    spacing: KSpacing.md,
                    runSpacing: KSpacing.md,
                    children: definitions.map((def) {
                      final itemWidth = isWide
                          ? (constraints.maxWidth - KSpacing.md) / 2
                          : constraints.maxWidth;
                      return SizedBox(
                        width: itemWidth,
                        child: _buildField(def),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildField(CustomFieldDefinition def) {
    final label = def.fieldLabel;

    switch (def.fieldType) {
      case FieldType.boolean:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${def.fieldLabel}${def.isRequired ? ' *' : ''}',
              style: KTypography.labelLarge,
            ),
            Switch.adaptive(
              value: _boolValues[def.id] ?? false,
              activeTrackColor: KColors.primary,
              onChanged: (val) {
                setState(() => _boolValues[def.id] = val);
                _notifyChange();
              },
            ),
          ],
        );

      case FieldType.dropdown:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${def.fieldLabel}${def.isRequired ? ' *' : ''}',
              style: KTypography.labelLarge,
            ),
            KSpacing.vGapXs,
            DropdownButtonFormField<String>(
              initialValue: _dropdownValues[def.id],
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: KSpacing.md,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(KSpacing.radiusMd),
                  borderSide: const BorderSide(color: KColors.border),
                ),
              ),
              items: def.options.map((opt) {
                return DropdownMenuItem<String>(
                  value: opt,
                  child: Text(opt, style: KTypography.bodyMedium),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => _dropdownValues[def.id] = val);
                _notifyChange();
              },
            ),
          ],
        );

      case FieldType.date:
        return KTextField(
          controller: _controllers[def.id],
          label: label,
          isRequired: def.isRequired,
          readOnly: true,
          suffixIcon: Icons.calendar_today,
          onTap: () => _pickDate(def.id, context),
        );

      case FieldType.number:
        return KTextField(
          controller: _controllers[def.id],
          label: label,
          isRequired: def.isRequired,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => _notifyChange(),
        );

      case FieldType.url:
        return KTextField(
          controller: _controllers[def.id],
          label: label,
          isRequired: def.isRequired,
          keyboardType: TextInputType.url,
          suffixIcon: Icons.link,
          onChanged: (_) => _notifyChange(),
        );

      case FieldType.text:
        return KTextField(
          controller: _controllers[def.id],
          label: label,
          isRequired: def.isRequired,
          onChanged: (_) => _notifyChange(),
        );
    }
  }
}
