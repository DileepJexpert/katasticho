import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/routing_repository.dart';

class RoutingCreateScreen extends ConsumerStatefulWidget {
  const RoutingCreateScreen({super.key});

  @override
  ConsumerState<RoutingCreateScreen> createState() =>
      _RoutingCreateScreenState();
}

class _RoutingCreateScreenState extends ConsumerState<RoutingCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _itemIdCtl = TextEditingController();
  bool _isDefault = false;
  bool _submitting = false;

  final List<_OperationRow> _operationRows = [];

  @override
  void initState() {
    super.initState();
    _addRow();
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _itemIdCtl.dispose();
    for (final row in _operationRows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() {
      _operationRows.add(_OperationRow(
        sequenceNumber: _operationRows.length + 1,
      ));
    });
  }

  void _removeRow(int index) {
    setState(() {
      _operationRows[index].dispose();
      _operationRows.removeAt(index);
      for (var i = 0; i < _operationRows.length; i++) {
        _operationRows[i].sequenceNumber = i + 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return KKeyboardFormWrapper(
      onSubmit: _submit,
      onCancel: () => context.pop(),
      child: Scaffold(
        appBar: AppBar(title: const Text('New Routing')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: KSpacing.pagePadding,
            children: [
              // ---- Basic Info ------------------------------------------------
              KTextField(
                controller: _nameCtl,
                label: 'Routing Name *',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              KSpacing.vGapMd,
              KTextField(
                controller: _itemIdCtl,
                label: 'Item ID (UUID) *',
                hint: 'e.g. 550e8400-e29b-41d4-a716-446655440000',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              KSpacing.vGapMd,
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Set as Default Routing',
                    style: KTypography.bodyMedium),
                subtitle: Text(
                  'Default routing is used when creating job cards without specifying a routing.',
                  style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                ),
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
              ),

              KSpacing.vGapLg,

              // ---- Operations Section ----------------------------------------
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Operations',
                      style: KTypography.titleSmall,
                    ),
                  ),
                  KButton.outlined(
                    size: KButtonSize.small,
                    onPressed: _addRow,
                    icon: Icons.add,
                    label: 'Add Operation',
                  ),
                ],
              ),
              KSpacing.vGapXs,
              Text(
                'At least one operation is required. Operations are executed in sequence order.',
                style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
              ),
              KSpacing.vGapSm,

              if (_operationRows.isEmpty)
                Container(
                  padding: const EdgeInsets.all(KSpacing.md),
                  decoration: BoxDecoration(
                    border: Border.all(color: KColors.error.withValues(alpha: 0.3)),
                    borderRadius: KSpacing.borderRadiusMd,
                    color: KColors.error.withValues(alpha: 0.05),
                  ),
                  child: Text(
                    'Please add at least one operation.',
                    style: KTypography.bodySmall.copyWith(color: KColors.error),
                  ),
                )
              else
                ..._operationRows.asMap().entries.map((entry) {
                  final i = entry.key;
                  final row = entry.value;
                  return _OperationRowWidget(
                    key: ValueKey(row.key),
                    row: row,
                    canRemove: _operationRows.length > 1,
                    onRemove: () => _removeRow(i),
                  );
                }),

              KSpacing.vGapLg,
              KButton.primary(
                onPressed: _submitting ? null : _submit,
                isLoading: _submitting,
                icon: Icons.check,
                label: 'Create Routing',
              ),
              KSpacing.vGapMd,
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_operationRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one operation'), backgroundColor: KColors.error),
      );
      return;
    }

    for (final row in _operationRows) {
      if (row.operationIdCtl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Operation ID is required for step ${row.sequenceNumber}'),
            backgroundColor: KColors.error,
          ),
        );
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final operations = _operationRows
          .map((row) => {
                'sequenceNumber': row.sequenceNumber,
                'operationId': row.operationIdCtl.text.trim(),
                if (row.workstationIdCtl.text.trim().isNotEmpty)
                  'workstationId': row.workstationIdCtl.text.trim(),
              })
          .toList();

      final result = await ref.read(routingRepositoryProvider).createRouting(
            name: _nameCtl.text.trim(),
            itemId: _itemIdCtl.text.trim(),
            isDefault: _isDefault,
            operations: operations,
          );

      ref.invalidate(routingsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Routing "${result['name'] ?? ''}" created successfully'),
            backgroundColor: KColors.success,
          ),
        );
        context.go('/manufacturing/routings');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: KColors.error));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Operation row model
// ---------------------------------------------------------------------------

class _OperationRow {
  _OperationRow({required this.sequenceNumber})
      : key = UniqueKey(),
        operationIdCtl = TextEditingController(),
        workstationIdCtl = TextEditingController();

  final Key key;
  int sequenceNumber;
  final TextEditingController operationIdCtl;
  final TextEditingController workstationIdCtl;

  void dispose() {
    operationIdCtl.dispose();
    workstationIdCtl.dispose();
  }
}

// ---------------------------------------------------------------------------
// Operation row widget
// ---------------------------------------------------------------------------

class _OperationRowWidget extends StatelessWidget {
  const _OperationRowWidget({
    super.key,
    required this.row,
    required this.canRemove,
    required this.onRemove,
  });

  final _OperationRow row;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: KCard(
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: KColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${row.sequenceNumber}',
                      style: KTypography.mono(
                        fontSize: 12,
                        color: KColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  KSpacing.hGapSm,
                  Expanded(
                    child: Text(
                      'Step ${row.sequenceNumber}',
                      style: KTypography.labelLarge,
                    ),
                  ),
                  if (canRemove)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: onRemove,
                      tooltip: 'Remove step',
                      color: KColors.error,
                    ),
                ],
              ),
              KSpacing.vGapSm,
              KTextField(
                controller: row.operationIdCtl,
                label: 'Operation ID (UUID) *',
                hint: 'e.g. 550e8400-e29b-41d4-a716-446655440000',
              ),
              KSpacing.vGapSm,
              KTextField(
                controller: row.workstationIdCtl,
                label: 'Workstation ID (UUID, optional)',
                hint: 'Leave blank to use operation default',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
