import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/saved_report_dto.dart';
import '../data/saved_report_repository.dart';

class ReportBuilderScreen extends ConsumerStatefulWidget {
  final SavedReportDto? editing;
  const ReportBuilderScreen({super.key, this.editing});

  @override
  ConsumerState<ReportBuilderScreen> createState() => _ReportBuilderScreenState();
}

class _ReportBuilderScreenState extends ConsumerState<ReportBuilderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();

  BaseReportOption? _selectedBase;
  Set<String> _selectedColumns = {};
  bool _isPublic = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _descCtrl.text = e.description;
      _tagsCtrl.text = e.tags.join(', ');
      _isPublic = e.isPublic;
      _selectedBase = BaseReportOption.all.where((o) => o.key == e.baseReportKey).firstOrNull;
      _selectedColumns = Set.from(e.columnKeys);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  String get _screenTitle => widget.editing != null ? 'Edit Report' : 'New Custom Report';

  void _onBaseChanged(BaseReportOption? opt) {
    setState(() {
      _selectedBase = opt;
      // pre-select all columns when first picking a base report
      _selectedColumns = opt != null ? Set.from(opt.availableColumns) : {};
    });
  }

  String _humanise(String col) {
    final result = col.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[0]}');
    return result[0].toUpperCase() + result.substring(1);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBase == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a base report')));
      return;
    }
    if (_selectedColumns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one column')));
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(savedReportRepositoryProvider);
      final tags = _tagsCtrl.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
      final columns = _selectedBase!.availableColumns.where(_selectedColumns.contains).toList();
      if (widget.editing != null) {
        await repo.update(
          widget.editing!.id,
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
          baseReportKey: _selectedBase!.key,
          columnKeys: columns,
          tags: tags,
          isPublic: _isPublic,
        );
      } else {
        await repo.create(
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
          baseReportKey: _selectedBase!.key,
          columnKeys: columns,
          tags: tags,
          isPublic: _isPublic,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: KColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_screenTitle),
        actions: [
          if (_saving)
            const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
          else
            TextButton(
              onPressed: _save,
              child: Text('Save', style: KTypography.labelLarge.copyWith(color: KColors.primary)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: KSpacing.pagePadding,
          children: [
            // -- Step 1: Name & Base Report --
            Text('1. Report Details', style: KTypography.h3),
            KSpacing.vGapMd,
            KTextField(
              controller: _nameCtrl,
              label: 'Report Name',
              hint: 'e.g. Monthly Sales Summary',
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            KSpacing.vGapMd,
            KTextField(
              controller: _descCtrl,
              label: 'Description (optional)',
              hint: 'What does this report track?',
              maxLines: 2,
            ),
            KSpacing.vGapMd,
            KTextField(
              controller: _tagsCtrl,
              label: 'Tags (optional, comma-separated)',
              hint: 'e.g. monthly, finance, sales',
            ),
            KSpacing.vGapMd,
            Row(
              children: [
                InkWell(
                  onTap: () => setState(() => _isPublic = !_isPublic),
                  borderRadius: KSpacing.borderRadiusMd,
                  child: Row(
                    children: [
                      Icon(
                        _isPublic ? Icons.check_box : Icons.check_box_outline_blank,
                        color: _isPublic ? KColors.primary : KColors.textHint,
                        size: 20,
                      ),
                      KSpacing.hGapSm,
                      Text('Visible to all org users (Public)', style: KTypography.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),

            KSpacing.vGapXl,
            const Divider(),
            KSpacing.vGapMd,

            // -- Step 2: Base Report --
            Text('2. Base Report', style: KTypography.h3),
            KSpacing.vGapMd,
            Text('Select the data source for this report:', style: KTypography.bodyMedium.copyWith(color: KColors.textSecondary)),
            KSpacing.vGapMd,
            ...BaseReportOption.all.fold<Map<String, List<BaseReportOption>>>({}, (map, o) {
              (map[o.group] ??= []).add(o);
              return map;
            }).entries.map((entry) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.key, style: KTypography.labelMedium.copyWith(color: KColors.textSecondary)),
                KSpacing.vGapXs,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: entry.value.map((opt) {
                    final selected = _selectedBase?.key == opt.key;
                    return InkWell(
                      onTap: () => _onBaseChanged(opt),
                      borderRadius: KSpacing.borderRadiusMd,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? KColors.primary.withValues(alpha: 0.1) : KColors.surface,
                          border: Border.all(color: selected ? KColors.primary : KColors.border, width: selected ? 1.5 : 1),
                          borderRadius: KSpacing.borderRadiusMd,
                        ),
                        child: Text(opt.label, style: KTypography.bodyMedium.copyWith(
                          color: selected ? KColors.primary : KColors.textPrimary,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        )),
                      ),
                    );
                  }).toList(),
                ),
                KSpacing.vGapMd,
              ],
            )),

            if (_selectedBase != null) ...[
              KSpacing.vGapXs,
              const Divider(),
              KSpacing.vGapMd,

              // -- Step 3: Column Selection --
              Row(
                children: [
                  Text('3. Columns', style: KTypography.h3),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _selectedColumns = Set.from(_selectedBase!.availableColumns)),
                    child: const Text('Select All'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _selectedColumns = {}),
                    child: const Text('Clear'),
                  ),
                ],
              ),
              Text('Choose which columns to include in this report:', style: KTypography.bodyMedium.copyWith(color: KColors.textSecondary)),
              KSpacing.vGapMd,
              KCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: _selectedBase!.availableColumns.asMap().entries.map((e) {
                    final col = e.value;
                    final isSelected = _selectedColumns.contains(col);
                    final isLast = e.key == _selectedBase!.availableColumns.length - 1;
                    return Column(
                      children: [
                        InkWell(
                          onTap: () => setState(() {
                            if (isSelected) {
                              _selectedColumns.remove(col);
                            } else {
                              _selectedColumns.add(col);
                            }
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: KSpacing.md, vertical: 12),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                                  color: isSelected ? KColors.primary : KColors.textHint,
                                  size: 20,
                                ),
                                KSpacing.hGapMd,
                                Expanded(child: Text(_humanise(col), style: KTypography.bodyMedium)),
                                Text(col, style: KTypography.mono(fontSize: 11, color: KColors.textHint)),
                              ],
                            ),
                          ),
                        ),
                        if (!isLast) const Divider(height: 1),
                      ],
                    );
                  }).toList(),
                ),
              ),
              KSpacing.vGapMd,
              Text('${_selectedColumns.length} of ${_selectedBase!.availableColumns.length} columns selected',
                  style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
            ],

            KSpacing.vGapXl,
            KButton.primary(
              label: _saving ? 'Saving�' : (widget.editing != null ? 'Update Report' : 'Save Report'),
              icon: Icons.save_outlined,
              onPressed: _saving ? null : _save,
            ),
            KSpacing.vGapLg,
          ],
        ),
      ),
    );
  }
}
