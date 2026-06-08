import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  // Each entry: {operationId, workstationId}
  final List<_OperationRow> _operationRows = [];

  @override
  void initState() {
    super.initState();
    // Start with one empty row
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
      // Renumber
      for (var i = 0; i < _operationRows.length; i++) {
        _operationRows[i].sequenceNumber = i + 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('New Routing')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---- Basic Info ------------------------------------------------
            KTextField(
              controller: _nameCtl,
              label: 'Routing Name *',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            KTextField(
              controller: _itemIdCtl,
              label: 'Item ID (UUID) *',
              hintText: 'e.g. 550e8400-e29b-41d4-a716-446655440000',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Set as Default Routing',
                  style: theme.textTheme.bodyMedium),
              subtitle: Text(
                'Default routing is used when creating job cards without specifying a routing.',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              value: _isDefault,
              onChanged: (v) => setState(() => _isDefault = v),
            ),

            const SizedBox(height: 24),

            // ---- Operations Section ----------------------------------------
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Operations',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton.icon(
                  onPressed: _addRow,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Operation'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'At least one operation is required. Operations are executed in sequence order.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 12),

            if (_operationRows.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.red.shade50,
                ),
                child: Text(
                  'Please add at least one operation.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.red.shade700),
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

            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check),
              label: const Text('Create Routing'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_operationRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one operation')),
      );
      return;
    }

    // Validate operation rows
    for (final row in _operationRows) {
      if (row.operationIdCtl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Operation ID is required for step ${row.sequenceNumber}'),
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
            backgroundColor: Colors.green,
          ),
        );
        context.go('/manufacturing/routings');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: KCard(
        child: Padding(
          padding: const EdgeInsets.all(12),
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
                      color: Colors.indigo.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${row.sequenceNumber}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.indigo,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Step ${row.sequenceNumber}',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: Colors.grey[700]),
                    ),
                  ),
                  if (canRemove)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: onRemove,
                      tooltip: 'Remove step',
                      color: Colors.red,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              KTextField(
                controller: row.operationIdCtl,
                label: 'Operation ID (UUID) *',
                hintText: 'e.g. 550e8400-e29b-41d4-a716-446655440000',
              ),
              const SizedBox(height: 8),
              KTextField(
                controller: row.workstationIdCtl,
                label: 'Workstation ID (UUID, optional)',
                hintText: 'Leave blank to use operation default',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
