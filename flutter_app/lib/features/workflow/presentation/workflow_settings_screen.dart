import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';
import '../data/workflow_repository.dart';

class WorkflowSettingsScreen extends ConsumerWidget {
  const WorkflowSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workflowsAsync = ref.watch(workflowsProvider);
    final role = ref.watch(authProvider).role?.toUpperCase() ?? '';
    final canEdit = role == 'OWNER' || role == 'ADMIN';

    return Scaffold(
      appBar: AppBar(title: const Text('Workflows')),
      body: workflowsAsync.when(
        loading: () => const KLoading(),
        error: (e, _) => KErrorView(
          message: 'Failed to load workflows',
          onRetry: () => ref.invalidate(workflowsProvider),
        ),
        data: (workflows) {
          if (workflows.isEmpty) {
            return const KEmptyState(
              icon: Icons.account_tree_outlined,
              title: 'No workflows configured',
              subtitle:
                  'Default workflows are created during organisation setup.',
            );
          }

          return ListView.separated(
            padding: KSpacing.pagePadding,
            itemCount: workflows.length,
            separatorBuilder: (_, __) => KSpacing.vGapMd,
            itemBuilder: (context, index) {
              final workflow = workflows[index];
              return _WorkflowEditor(
                key: ValueKey(workflow.id),
                workflow: workflow,
                canEdit: canEdit,
              );
            },
          );
        },
      ),
    );
  }
}

class _WorkflowEditor extends ConsumerStatefulWidget {
  final WorkflowDefinition workflow;
  final bool canEdit;

  const _WorkflowEditor({
    super.key,
    required this.workflow,
    required this.canEdit,
  });

  @override
  ConsumerState<_WorkflowEditor> createState() => _WorkflowEditorState();
}

class _WorkflowEditorState extends ConsumerState<_WorkflowEditor> {
  late bool _active;
  late TextEditingController _triggerController;
  late List<_EditableStep> _steps;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadFromWidget();
  }

  @override
  void didUpdateWidget(covariant _WorkflowEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workflow.id != widget.workflow.id ||
        oldWidget.workflow.active != widget.workflow.active ||
        oldWidget.workflow.triggerCondition !=
            widget.workflow.triggerCondition) {
      _triggerController.dispose();
      _loadFromWidget();
    }
  }

  @override
  void dispose() {
    _triggerController.dispose();
    super.dispose();
  }

  void _loadFromWidget() {
    _active = widget.workflow.active;
    _triggerController = TextEditingController(
        text: _prettyJson(widget.workflow.triggerCondition));
    _steps = widget.workflow.steps.isEmpty
        ? [_EditableStep(stepNumber: 1)]
        : widget.workflow.steps
            .map((s) => _EditableStep(
                  stepNumber: s.stepNumber,
                  approverRole: s.approverRole ?? 'OWNER',
                  timeoutHours: s.timeoutHours,
                  onTimeout: s.onTimeout,
                ))
            .toList();
  }

  Future<void> _save() async {
    Object? parsed;
    try {
      parsed = jsonDecode(_triggerController.text.trim());
    } catch (_) {
      _showSnack('Trigger condition must be valid JSON');
      return;
    }
    if (parsed is! Map<String, dynamic>) {
      _showSnack('Trigger condition must be a JSON object');
      return;
    }
    if (_steps.any((s) => s.approverRole.trim().isEmpty)) {
      _showSnack('Each step needs an approver role');
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(workflowRepositoryProvider);
      final normalizedSteps = <WorkflowStep>[];
      for (var i = 0; i < _steps.length; i++) {
        final step = _steps[i];
        normalizedSteps.add(WorkflowStep(
          stepNumber: i + 1,
          approverRole: step.approverRole,
          timeoutHours: step.timeoutHours,
          onTimeout: step.onTimeout,
        ));
      }
      await repo.replaceSteps(widget.workflow.id, normalizedSteps);
      await repo.updateWorkflow(
        widget.workflow.id,
        active: _active,
        triggerCondition: jsonEncode(parsed),
      );
      ref.invalidate(workflowsProvider);
      _showSnack('Workflow saved');
    } catch (e) {
      _showSnack(ApiErrorParser.message(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addStep() {
    setState(() {
      _steps.add(_EditableStep(stepNumber: _steps.length + 1));
    });
  }

  void _removeStep(int index) {
    setState(() {
      _steps.removeAt(index);
      for (var i = 0; i < _steps.length; i++) {
        _steps[i] = _steps[i].copyWith(stepNumber: i + 1);
      }
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final w = widget.workflow;

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.account_tree_outlined,
                  color: cs.onPrimaryContainer,
                ),
              ),
              KSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w.name, style: KTypography.h4),
                    const SizedBox(height: 4),
                    Text(
                      '${_label(w.documentType)} - ${w.code}',
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _active,
                onChanged: widget.canEdit && !_saving
                    ? (value) => setState(() => _active = value)
                    : null,
              ),
            ],
          ),
          KSpacing.vGapMd,
          Text('Approval steps',
              style: KTypography.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
              )),
          KSpacing.vGapSm,
          ..._steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            return _StepEditorRow(
              step: step,
              canEdit: widget.canEdit && !_saving,
              canRemove: widget.canEdit && !_saving && _steps.length > 1,
              onChanged: (updated) => setState(() => _steps[index] = updated),
              onRemove: () => _removeStep(index),
            );
          }),
          if (widget.canEdit)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _saving ? null : _addStep,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add step'),
              ),
            ),
          KSpacing.vGapMd,
          Text('Trigger condition',
              style: KTypography.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 8),
          TextField(
            controller: _triggerController,
            enabled: widget.canEdit && !_saving,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText:
                  '{"field":"credit.exposureAmount","operator":"GT","valueField":"credit.creditLimit"}',
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
          KSpacing.vGapMd,
          Row(
            children: [
              _StatusChip(active: _active),
              const Spacer(),
              if (widget.canEdit)
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _prettyJson(String raw) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(jsonDecode(raw));
    } catch (_) {
      return raw;
    }
  }

  static String _label(String value) {
    return value
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }
}

class _StepEditorRow extends StatelessWidget {
  static const _roles = ['OWNER', 'ADMIN', 'ACCOUNTANT', 'OPERATOR'];
  static const _timeoutActions = ['ESCALATE', 'REJECT'];

  final _EditableStep step;
  final bool canEdit;
  final bool canRemove;
  final ValueChanged<_EditableStep> onChanged;
  final VoidCallback onRemove;

  const _StepEditorRow({
    required this.step,
    required this.canEdit,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 620;
          final children = [
            SizedBox(
              width: narrow ? double.infinity : 80,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Step',
                  border: OutlineInputBorder(),
                ),
                child: Text(step.stepNumber.toString()),
              ),
            ),
            SizedBox(
              width: narrow ? double.infinity : 190,
              child: DropdownButtonFormField<String>(
                value: _roles.contains(step.approverRole)
                    ? step.approverRole
                    : 'OWNER',
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: _roles
                    .map((role) => DropdownMenuItem(
                          value: role,
                          child: Text(role),
                        ))
                    .toList(),
                onChanged: canEdit
                    ? (value) =>
                        onChanged(step.copyWith(approverRole: value ?? 'OWNER'))
                    : null,
              ),
            ),
            SizedBox(
              width: narrow ? double.infinity : 150,
              child: TextFormField(
                initialValue: step.timeoutHours.toString(),
                enabled: canEdit,
                decoration: const InputDecoration(
                  labelText: 'Timeout hours',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null && parsed > 0) {
                    onChanged(step.copyWith(timeoutHours: parsed));
                  }
                },
              ),
            ),
            SizedBox(
              width: narrow ? double.infinity : 170,
              child: DropdownButtonFormField<String>(
                value: _timeoutActions.contains(step.onTimeout)
                    ? step.onTimeout
                    : 'ESCALATE',
                decoration: const InputDecoration(
                  labelText: 'On timeout',
                  border: OutlineInputBorder(),
                ),
                items: _timeoutActions
                    .map((action) => DropdownMenuItem(
                          value: action,
                          child: Text(action),
                        ))
                    .toList(),
                onChanged: canEdit
                    ? (value) => onChanged(
                          step.copyWith(onTimeout: value ?? 'ESCALATE'),
                        )
                    : null,
              ),
            ),
            IconButton(
              tooltip: 'Remove step',
              onPressed: canRemove ? onRemove : null,
              icon: const Icon(Icons.delete_outline),
            ),
          ];

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children
                  .map((child) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: child,
                      ))
                  .toList(),
            );
          }
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: children,
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool active;

  const _StatusChip({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? KColors.success : KColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? 'Active' : 'Inactive',
        style: KTypography.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EditableStep {
  final int stepNumber;
  final String approverRole;
  final int timeoutHours;
  final String onTimeout;

  const _EditableStep({
    required this.stepNumber,
    this.approverRole = 'OWNER',
    this.timeoutHours = 24,
    this.onTimeout = 'ESCALATE',
  });

  _EditableStep copyWith({
    int? stepNumber,
    String? approverRole,
    int? timeoutHours,
    String? onTimeout,
  }) {
    return _EditableStep(
      stepNumber: stepNumber ?? this.stepNumber,
      approverRole: approverRole ?? this.approverRole,
      timeoutHours: timeoutHours ?? this.timeoutHours,
      onTimeout: onTimeout ?? this.onTimeout,
    );
  }
}
