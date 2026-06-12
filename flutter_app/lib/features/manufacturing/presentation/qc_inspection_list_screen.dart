import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/k_keyboard_list_wrapper.dart';
import '../../../core/widgets/widgets.dart';
import '../data/qc_repository.dart';

class QcInspectionListScreen extends ConsumerStatefulWidget {
  const QcInspectionListScreen({super.key});

  @override
  ConsumerState<QcInspectionListScreen> createState() =>
      _QcInspectionListScreenState();
}

class _QcInspectionListScreenState
    extends ConsumerState<QcInspectionListScreen> {
  String? _statusFilter;
  String? _typeFilter;

  @override
  Widget build(BuildContext context) {
    final filter = inspectionFilter(status: _statusFilter, type: _typeFilter);
    final inspectionsAsync = ref.watch(qcInspectionsProvider(filter));

    return KKeyboardListWrapper(
      itemCount: () => inspectionsAsync.valueOrNull?.length ?? 0,
      onNew: () => _showCreateSheet(context),
      onRefresh: () => ref.invalidate(qcInspectionsProvider(filter)),
      onOpen: (index) {
        final inspections = inspectionsAsync.valueOrNull;
        if (inspections != null && index < inspections.length) {
          final id = inspections[index]['id']?.toString();
          if (id != null) context.go('/manufacturing/qc-inspections/$id');
        }
      },
      child: Scaffold(
      body: Column(
        children: [
          const KListPageHeader(
            title: 'QC Inspections',
            subtitle: 'Track incoming, in-process, and outgoing quality checks.',
          ),

          // ── Status filter row ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _statusFilter == null,
                    onTap: () => _setStatus(null),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Pending',
                    selected: _statusFilter == 'PENDING',
                    onTap: () => _setStatus('PENDING'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'In Progress',
                    selected: _statusFilter == 'IN_PROGRESS',
                    onTap: () => _setStatus('IN_PROGRESS'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Passed',
                    selected: _statusFilter == 'PASSED',
                    onTap: () => _setStatus('PASSED'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Failed',
                    selected: _statusFilter == 'FAILED',
                    onTap: () => _setStatus('FAILED'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Partial',
                    selected: _statusFilter == 'PARTIAL',
                    onTap: () => _setStatus('PARTIAL'),
                  ),
                ],
              ),
            ),
          ),

          // ── Type filter row ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All Types',
                    selected: _typeFilter == null,
                    onTap: () => _setType(null),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Incoming',
                    selected: _typeFilter == 'INCOMING',
                    onTap: () => _setType('INCOMING'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'In-Process',
                    selected: _typeFilter == 'IN_PROCESS',
                    onTap: () => _setType('IN_PROCESS'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Outgoing',
                    selected: _typeFilter == 'OUTGOING',
                    onTap: () => _setType('OUTGOING'),
                  ),
                ],
              ),
            ),
          ),

          // ── List ───────────────────────────────────────────────────────
          Expanded(
            child: inspectionsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => KErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(qcInspectionsProvider(filter)),
              ),
              data: (inspections) {
                if (inspections.isEmpty) {
                  return const KEmptyState(
                    icon: Icons.science_outlined,
                    title: 'No inspections',
                    subtitle: 'Create an inspection to begin quality control.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(qcInspectionsProvider(filter)),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: inspections.length,
                    itemBuilder: (ctx, i) => _InspectionCard(
                      inspection: inspections[i],
                      onTap: () {
                        final id = inspections[i]['id']?.toString();
                        if (id != null) {
                          context.go('/manufacturing/qc-inspections/$id');
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('New Inspection'),
        tooltip: 'New Inspection (N)',
      ),
    ),
    );
  }

  void _setStatus(String? status) => setState(() => _statusFilter = status);
  void _setType(String? type) => setState(() => _typeFilter = type);

  Future<void> _showCreateSheet(BuildContext context) async {
    final filter = inspectionFilter(status: _statusFilter, type: _typeFilter);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _CreateInspectionSheet(
        onCreated: () {
          ref.invalidate(qcInspectionsProvider(filter));
        },
      ),
    );
  }
}

// ── Filter chip ─────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

// ── Inspection list card ─────────────────────────────────────────────────────

class _InspectionCard extends StatelessWidget {
  const _InspectionCard({
    required this.inspection,
    required this.onTap,
  });
  final Map<String, dynamic> inspection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final number =
        inspection['inspectionNumber']?.toString() ?? 'QC-?';
    final status = inspection['status']?.toString() ?? '';
    final type = inspection['inspectionType']?.toString() ?? '';
    final rawItemId = inspection['itemId']?.toString() ?? '';
    final itemId = rawItemId.length > 8
        ? '${rawItemId.substring(0, 8)}...'
        : rawItemId;
    final inspectedQty =
        inspection['inspectedQty']?.toString() ?? '0';
    final inspectedAt = inspection['inspectedAt']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KCard(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      number,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  KStatusChip(label: status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _TypeBadge(type: type),
                  const SizedBox(width: 12),
                  if (itemId.isNotEmpty)
                    Text(
                      'Item: $itemId',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 16,
                children: [
                  Text(
                    'Qty: $inspectedQty',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (inspectedAt != null)
                    Text(
                      _formatDate(inspectedAt),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}';
    } catch (_) {
      return raw;
    }
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      'INCOMING' => ('IQC', Colors.teal),
      'IN_PROCESS' => ('IPQC', Colors.orange),
      'OUTGOING' => ('OQC', Colors.indigo),
      _ => (type, Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

// ── Create inspection bottom sheet ───────────────────────────────────────────

class _CreateInspectionSheet extends ConsumerStatefulWidget {
  const _CreateInspectionSheet({required this.onCreated});
  final VoidCallback onCreated;

  @override
  ConsumerState<_CreateInspectionSheet> createState() =>
      _CreateInspectionSheetState();
}

class _CreateInspectionSheetState
    extends ConsumerState<_CreateInspectionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _itemIdCtl = TextEditingController();
  final _inspectedQtyCtl = TextEditingController();
  final _templateIdCtl = TextEditingController();
  final _referenceTypeCtl = TextEditingController();
  final _referenceIdCtl = TextEditingController();

  String _inspectionType = 'INCOMING';
  bool _submitting = false;

  @override
  void dispose() {
    _itemIdCtl.dispose();
    _inspectedQtyCtl.dispose();
    _templateIdCtl.dispose();
    _referenceTypeCtl.dispose();
    _referenceIdCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'New Inspection',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Inspection type
              DropdownButtonFormField<String>(
                value: _inspectionType,
                decoration: const InputDecoration(
                  labelText: 'Inspection Type *',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'INCOMING', child: Text('Incoming (IQC)')),
                  DropdownMenuItem(
                      value: 'IN_PROCESS', child: Text('In-Process (IPQC)')),
                  DropdownMenuItem(
                      value: 'OUTGOING', child: Text('Outgoing (OQC)')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _inspectionType = v);
                },
              ),
              const SizedBox(height: 12),

              // Item ID
              TextFormField(
                controller: _itemIdCtl,
                decoration: const InputDecoration(
                  labelText: 'Item ID (UUID) *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Inspected qty
              TextFormField(
                controller: _inspectedQtyCtl,
                decoration: const InputDecoration(
                  labelText: 'Inspected Qty *',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (double.tryParse(v.trim()) == null) {
                    return 'Enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Template ID (optional)
              TextFormField(
                controller: _templateIdCtl,
                decoration: const InputDecoration(
                  labelText: 'Template ID (UUID, optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // Reference type (optional)
              TextFormField(
                controller: _referenceTypeCtl,
                decoration: const InputDecoration(
                  labelText: 'Reference Type (optional)',
                  hintText: 'e.g. WORK_ORDER, GRN',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // Reference ID (optional)
              TextFormField(
                controller: _referenceIdCtl,
                decoration: const InputDecoration(
                  labelText: 'Reference ID (UUID, optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Create Inspection'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref.read(qcRepositoryProvider).createInspection(
            inspectionType: _inspectionType,
            itemId: _itemIdCtl.text.trim(),
            inspectedQty:
                double.parse(_inspectedQtyCtl.text.trim()),
            templateId: _templateIdCtl.text.trim().isEmpty
                ? null
                : _templateIdCtl.text.trim(),
            referenceType: _referenceTypeCtl.text.trim().isEmpty
                ? null
                : _referenceTypeCtl.text.trim(),
            referenceId: _referenceIdCtl.text.trim().isEmpty
                ? null
                : _referenceIdCtl.text.trim(),
          );
      widget.onCreated();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inspection created'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
