import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/supplier_repository.dart';

/// Modal supplier picker. Returns the selected supplier map (with id,
/// name, gstin, etc.) or null if cancelled. Includes a "+ Add new
/// supplier" affordance that pushes the [SupplierCreateSheet] inline so
/// the user never has to leave the GRN flow.
Future<Map<String, dynamic>?> showSupplierPicker(BuildContext context) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => _SupplierPickerSheet(
        scrollController: scrollController,
      ),
    ),
  );
}

class _SupplierPickerSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  const _SupplierPickerSheet({required this.scrollController});

  @override
  ConsumerState<_SupplierPickerSheet> createState() =>
      _SupplierPickerSheetState();
}

class _SupplierPickerSheetState extends ConsumerState<_SupplierPickerSheet> {
  final _searchController = TextEditingController();
  String? _query;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addNew() async {
    final created = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _SupplierCreateSheet(),
    );
    if (created != null && mounted) {
      // Bounce the new supplier straight back to the caller as the picked one.
      ref.invalidate(supplierListProvider);
      Navigator.pop(context, created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(supplierListProvider(_query));

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Select Supplier', style: KTypography.h3),
                    ),
                    TextButton.icon(
                      onPressed: _addNew,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New'),
                    ),
                  ],
                ),
                KSpacing.vGapSm,
                KTextField.search(
                  controller: _searchController,
                  hint: 'Search by name, GSTIN or phone',
                  onChanged: (v) => setState(
                      () => _query = v.trim().isEmpty ? null : v.trim()),
                  onClear: () {
                    _searchController.clear();
                    setState(() => _query = null);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: suppliersAsync.when(
              loading: () => const KShimmerList(),
              error: (err, st) {
                debugPrint('[SupplierPicker] ERROR: $err\n$st');
                return KErrorView(message: 'Failed to load suppliers');
              },
              data: (data) {
                final content = data['data'];
                final suppliers = content is List
                    ? content
                    : (content is Map
                        ? (content['content'] as List?) ?? []
                        : []);

                if (suppliers.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_shipping_outlined,
                              size: 48,
                              color: KColors.textHint),
                          KSpacing.vGapSm,
                          Text(
                            _query == null
                                ? 'No suppliers yet'
                                : 'No matches',
                            style: KTypography.bodyMedium,
                          ),
                          KSpacing.vGapMd,
                          KButton(
                            label: 'Add Supplier',
                            icon: Icons.add,
                            onPressed: _addNew,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  controller: widget.scrollController,
                  padding: KSpacing.pagePadding,
                  itemCount: suppliers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final supplier = suppliers[index] as Map<String, dynamic>;
                    final gstin = supplier['gstin'] as String? ?? '';
                    final phone = supplier['phone'] as String? ?? '';
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: KColors.primaryLight.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.local_shipping_outlined,
                          color: KColors.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(supplier['name']?.toString() ?? '',
                          style: KTypography.labelLarge),
                      subtitle: Text(
                        gstin.isNotEmpty
                            ? 'GSTIN: $gstin'
                            : (phone.isNotEmpty ? phone : 'No details'),
                        style: KTypography.bodySmall,
                      ),
                      onTap: () => Navigator.pop(context, supplier),
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

/// Inline supplier-create form. Pops with the created supplier map on
/// success or null on cancel. Kept private — the only way to reach it is
/// through the picker, which keeps the data flow simple.
class _SupplierCreateSheet extends ConsumerStatefulWidget {
  const _SupplierCreateSheet();

  @override
  ConsumerState<_SupplierCreateSheet> createState() =>
      _SupplierCreateSheetState();
}

class _SupplierCreateSheetState extends ConsumerState<_SupplierCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _gstin = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _gstin.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(supplierRepositoryProvider);
      final result = await repo.createSupplier({
        'name': _name.text.trim(),
        if (_gstin.text.trim().isNotEmpty) 'gstin': _gstin.text.trim(),
        if (_phone.text.trim().isNotEmpty) 'phone': _phone.text.trim(),
        if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
      });
      final supplier = (result['data'] ?? result) as Map<String, dynamic>;
      if (mounted) Navigator.pop(context, supplier);
    } catch (e) {
      setState(() => _error = 'Failed to create supplier');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(KSpacing.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('New Supplier', style: KTypography.h3),
              KSpacing.vGapMd,
              if (_error != null) ...[
                KErrorBanner(
                    message: _error!,
                    onDismiss: () => setState(() => _error = null)),
                KSpacing.vGapMd,
              ],
              KTextField(
                label: 'Supplier Name *',
                controller: _name,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
              KSpacing.vGapSm,
              KTextField(
                label: 'GSTIN',
                controller: _gstin,
                hint: 'e.g. 27AAAAA0000A1Z5',
              ),
              KSpacing.vGapSm,
              KTextField(
                label: 'Phone',
                controller: _phone,
                keyboardType: TextInputType.phone,
              ),
              KSpacing.vGapSm,
              KTextField(
                label: 'Email',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
              ),
              KSpacing.vGapMd,
              Row(
                children: [
                  Expanded(
                    child: KButton(
                      label: 'Cancel',
                      variant: KButtonVariant.outlined,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  KSpacing.hGapSm,
                  Expanded(
                    child: KButton(
                      label: 'Save',
                      onPressed: _save,
                      isLoading: _saving,
                    ),
                  ),
                ],
              ),
              KSpacing.vGapSm,
            ],
          ),
        ),
      ),
    );
  }
}
