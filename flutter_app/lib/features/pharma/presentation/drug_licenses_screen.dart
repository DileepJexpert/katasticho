import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/drug_license_repository.dart';

// ── License type display mapping ──────────────────────────────────────────────

const _licenseTypeValues = [
  'DRUG_LICENSE',
  'FSSAI',
  'DEA',
  'WHOLESALE_DRUG',
  'RETAIL_DRUG',
];

const _licenseTypeLabels = {
  'DRUG_LICENSE': 'Drug License',
  'FSSAI': 'FSSAI',
  'DEA': 'DEA',
  'WHOLESALE_DRUG': 'Wholesale Drug License',
  'RETAIL_DRUG': 'Retail Drug License',
};

String _licenseLabel(String type) => _licenseTypeLabels[type] ?? type;

// ── Status colors ─────────────────────────────────────────────────────────────

Color _statusColor(String status) => switch (status.toUpperCase()) {
      'EXPIRED' => KColors.error,
      'CRITICAL' => const Color(0xFFEA580C),
      'WARNING' => KColors.warning,
      _ => KColors.success,
    };

Color _statusBgColor(String status) => switch (status.toUpperCase()) {
      'EXPIRED' => KColors.errorLight,
      'CRITICAL' => const Color(0xFFFFF7ED),
      'WARNING' => KColors.warningLight,
      _ => KColors.successLight,
    };

IconData _statusIcon(String status) => switch (status.toUpperCase()) {
      'EXPIRED' => Icons.error_outline,
      'CRITICAL' => Icons.warning_amber_rounded,
      'WARNING' => Icons.schedule,
      _ => Icons.verified_outlined,
    };

String _statusLabel(String status) => switch (status.toUpperCase()) {
      'EXPIRED' => 'Expired',
      'CRITICAL' => 'Critical',
      'WARNING' => 'Warning',
      _ => 'OK',
    };

// ── Main screen ───────────────────────────────────────────────────────────────

class DrugLicensesScreen extends ConsumerWidget {
  const DrugLicensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final licensesAsync = ref.watch(drugLicensesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Drug Licenses'),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'drug-license-add',
        onPressed: () => _showAddEditSheet(context, ref, null),
        tooltip: 'Add License',
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(drugLicensesProvider),
        child: licensesAsync.when(
          loading: () => const KLoading(),
          error: (err, _) => KErrorView(
            message: 'Failed to load drug licenses: $err',
            onRetry: () => ref.invalidate(drugLicensesProvider),
          ),
          data: (licenses) {
            if (licenses.isEmpty) {
              return KEmptyState(
                icon: Icons.assignment_outlined,
                title: 'No drug licenses',
                subtitle:
                    'Add your pharmacy drug licenses and compliance documents to track their expiry.',
                actionLabel: 'Add License',
                onAction: () => _showAddEditSheet(context, ref, null),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  KSpacing.md, KSpacing.md, KSpacing.md, 100),
              itemCount: licenses.length,
              separatorBuilder: (_, __) => KSpacing.vGapSm,
              itemBuilder: (context, index) {
                final license = licenses[index];
                return _LicenseCard(
                  license: license,
                  onTap: () => _showAddEditSheet(context, ref, license),
                  onDelete: () => _confirmDelete(context, ref, license),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _showAddEditSheet(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic>? existing,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _DrugLicenseForm(
        existing: existing,
        onSaved: () {
          ref.invalidate(drugLicensesProvider);
          ref.invalidate(expiringLicensesProvider);
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> license,
  ) async {
    final licenseNumber = license['licenseNumber']?.toString() ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete License'),
        content: Text(
          'Are you sure you want to delete license "$licenseNumber"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: KColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(drugLicenseRepositoryProvider)
          .delete(license['id'].toString());
      ref.invalidate(drugLicensesProvider);
      ref.invalidate(expiringLicensesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('License deleted')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      String msg = 'Failed to delete license';
      if (e is DioException) {
        final body = e.response?.data;
        if (body is Map) msg = body['message'] as String? ?? msg;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: KColors.error),
      );
    }
  }
}

// ── License card ──────────────────────────────────────────────────────────────

class _LicenseCard extends StatelessWidget {
  final Map<String, dynamic> license;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _LicenseCard({
    required this.license,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final licenseType = license['licenseType']?.toString() ?? '';
    final licenseNumber = license['licenseNumber']?.toString() ?? '';
    final issuedBy = license['issuedBy']?.toString() ?? '';
    final expiryDateStr = license['expiryDate']?.toString() ?? '';
    final daysUntilExpiry =
        (license['daysUntilExpiry'] as num?)?.toInt() ?? 0;
    final status = license['status']?.toString() ?? 'OK';

    final statusColor = _statusColor(status);
    final statusBg = _statusBgColor(status);

    String expiryLabel;
    if (daysUntilExpiry < 0) {
      expiryLabel =
          'Expired ${-daysUntilExpiry} day${-daysUntilExpiry == 1 ? '' : 's'} ago';
    } else if (daysUntilExpiry == 0) {
      expiryLabel = 'Expires today';
    } else {
      expiryLabel =
          'Expires in $daysUntilExpiry day${daysUntilExpiry == 1 ? '' : 's'}';
    }

    String formattedExpiry = '';
    if (expiryDateStr.isNotEmpty) {
      try {
        formattedExpiry = DateFormat('dd MMM yyyy')
            .format(DateTime.parse(expiryDateStr));
      } catch (_) {
        formattedExpiry = expiryDateStr;
      }
    }

    return Dismissible(
      key: ValueKey(license['id']),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false; // We handle deletion ourselves after confirmation
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
        decoration: BoxDecoration(
          color: KColors.error,
          borderRadius: KSpacing.borderRadiusMd,
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: KCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: type chip + status badge
            Row(
              children: [
                // License type chip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: KSpacing.borderRadiusSm,
                  ),
                  child: Text(
                    _licenseLabel(licenseType),
                    style: KTypography.labelSmall.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: KSpacing.borderRadiusSm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon(status),
                          size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        _statusLabel(status),
                        style: KTypography.labelSmall.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            KSpacing.vGapSm,
            // License number (bold)
            Text(
              licenseNumber,
              style: KTypography.h4.copyWith(color: cs.onSurface),
            ),
            if (issuedBy.isNotEmpty) ...[
              KSpacing.vGapXxs,
              Text(
                'Issued by: $issuedBy',
                style: KTypography.bodySmall
                    .copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            KSpacing.vGapSm,
            // Expiry row
            Row(
              children: [
                Icon(Icons.event_outlined,
                    size: 14, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  formattedExpiry,
                  style: KTypography.bodySmall.copyWith(color: statusColor),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: KSpacing.borderRadiusSm,
                  ),
                  child: Text(
                    expiryLabel,
                    style: KTypography.labelSmall.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add / Edit bottom sheet form ───────────────────────────────────────────────

class _DrugLicenseForm extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;

  const _DrugLicenseForm({required this.existing, required this.onSaved});

  @override
  ConsumerState<_DrugLicenseForm> createState() => _DrugLicenseFormState();
}

class _DrugLicenseFormState extends ConsumerState<_DrugLicenseForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  late String _licenseType;
  final _licenseNumberCtl = TextEditingController();
  final _issuedByCtl = TextEditingController();
  final _notesCtl = TextEditingController();
  DateTime? _issueDate;
  DateTime? _expiryDate;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _licenseType = ex?['licenseType']?.toString() ?? _licenseTypeValues.first;
    _licenseNumberCtl.text = ex?['licenseNumber']?.toString() ?? '';
    _issuedByCtl.text = ex?['issuedBy']?.toString() ?? '';
    _notesCtl.text = ex?['notes']?.toString() ?? '';
    final issueDateStr = ex?['issueDate']?.toString();
    final expiryDateStr = ex?['expiryDate']?.toString();
    if (issueDateStr != null && issueDateStr.isNotEmpty) {
      try {
        _issueDate = DateTime.parse(issueDateStr);
      } catch (_) {}
    }
    if (expiryDateStr != null && expiryDateStr.isNotEmpty) {
      try {
        _expiryDate = DateTime.parse(expiryDateStr);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _licenseNumberCtl.dispose();
    _issuedByCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(
      {required bool isExpiry}) async {
    final now = DateTime.now();
    final initial = isExpiry
        ? (_expiryDate ?? now.add(const Duration(days: 365)))
        : (_issueDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isExpiry) {
        _expiryDate = picked;
      } else {
        _issueDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an expiry date')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final repo = ref.read(drugLicenseRepositoryProvider);
    final body = <String, dynamic>{
      'licenseType': _licenseType,
      'licenseNumber': _licenseNumberCtl.text.trim(),
      if (_issuedByCtl.text.trim().isNotEmpty)
        'issuedBy': _issuedByCtl.text.trim(),
      if (_issueDate != null)
        'issueDate': DateFormat('yyyy-MM-dd').format(_issueDate!),
      'expiryDate': DateFormat('yyyy-MM-dd').format(_expiryDate!),
      if (_notesCtl.text.trim().isNotEmpty) 'notes': _notesCtl.text.trim(),
    };

    try {
      final id = widget.existing?['id']?.toString();
      if (id != null) {
        await repo.update(id, body);
      } else {
        await repo.create(body);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      String msg = 'Failed to save license';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map) msg = data['message'] as String? ?? msg;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: KColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEditing = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(KSpacing.md),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: KSpacing.md),
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: KSpacing.borderRadiusXl,
                    ),
                  ),
                ),
                Text(
                  isEditing ? 'Edit License' : 'Add Drug License',
                  style: KTypography.h3,
                ),
                KSpacing.vGapMd,

                // License Type dropdown
                DropdownButtonFormField<String>(
                  initialValue: _licenseType,
                  decoration: const InputDecoration(
                    labelText: 'License Type',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _licenseTypeValues
                      .map((v) => DropdownMenuItem(
                            value: v,
                            child: Text(_licenseLabel(v)),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _licenseType = v);
                  },
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Required' : null,
                ),
                KSpacing.vGapMd,

                // License Number
                TextFormField(
                  controller: _licenseNumberCtl,
                  decoration: const InputDecoration(
                    labelText: 'License Number *',
                    hintText: 'e.g. MH-MUM-12345',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                KSpacing.vGapMd,

                // Issued By
                TextFormField(
                  controller: _issuedByCtl,
                  decoration: const InputDecoration(
                    labelText: 'Issued By',
                    hintText: 'e.g. Food & Drug Administration',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                KSpacing.vGapMd,

                // Issue Date + Expiry Date row
                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        label: 'Issue Date',
                        date: _issueDate,
                        onTap: () => _pickDate(isExpiry: false),
                      ),
                    ),
                    KSpacing.hGapMd,
                    Expanded(
                      child: _DateField(
                        label: 'Expiry Date *',
                        date: _expiryDate,
                        onTap: () => _pickDate(isExpiry: true),
                        isRequired: true,
                      ),
                    ),
                  ],
                ),
                KSpacing.vGapMd,

                // Notes
                TextFormField(
                  controller: _notesCtl,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Optional additional notes',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 3,
                ),
                KSpacing.vGapLg,

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _isSaving ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    KSpacing.hGapMd,
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(isEditing ? 'Update' : 'Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Date field widget ─────────────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final bool isRequired;

  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: Icon(Icons.calendar_today_outlined,
              size: 16, color: cs.onSurfaceVariant),
        ),
        child: Text(
          date != null
              ? DateFormat('dd MMM yyyy').format(date!)
              : 'Select date',
          style: KTypography.bodyMedium.copyWith(
            color: date != null ? cs.onSurface : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
