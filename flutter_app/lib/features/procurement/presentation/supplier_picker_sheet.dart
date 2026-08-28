import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/supplier_repository.dart';

/// Modal supplier picker. Returns the selected supplier map (with id,
/// name, gstin, etc.) or null if cancelled. Includes a "+ Add new
/// supplier" affordance that pushes the [_SupplierCreateSheet] inline so
/// the user never has to leave the workflow.
Future<Map<String, dynamic>?> showSupplierPicker(BuildContext context) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(KSpacing.radiusLg)),
    ),
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.76,
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
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(KSpacing.radiusLg)),
      ),
      builder: (_) => const _SupplierCreateSheet(),
    );
    if (created != null && mounted) {
      ref.invalidate(selectableSupplierListProvider);
      Navigator.pop(context, created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(selectableSupplierListProvider(_query));

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
                      child: Text('Select Supplier', style: KTypography.titleLarge),
                    ),
                    KButton.primary(
                      size: KButtonSize.small,
                      icon: Icons.add,
                      label: 'New Supplier',
                      onPressed: _addNew,
                    ),
                  ],
                ),
                KSpacing.vGapSm,
                KTextField.search(
                  controller: _searchController,
                  hint: 'Search by supplier name, GSTIN or phone…',
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
                      padding: const EdgeInsets.all(KSpacing.xl),
                      child: KEmptyState(
                        icon: Icons.local_shipping_outlined,
                        title: _query == null ? 'No Suppliers' : 'No Matching Suppliers',
                        subtitle: _query == null
                            ? 'Tap New Supplier to create one.'
                            : 'Try adjusting your search terms.',
                        actionLabel: 'Add Supplier',
                        onAction: _addNew,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  controller: widget.scrollController,
                  padding: KSpacing.pagePadding,
                  itemCount: suppliers.length,
                  separatorBuilder: (_, __) => KSpacing.vGapXs,
                  itemBuilder: (context, index) {
                    final supplier = suppliers[index] as Map<String, dynamic>;
                    final name = supplier['name']?.toString() ?? '';
                    final gstin = supplier['gstin']?.toString() ?? '';
                    final phone = supplier['phone']?.toString() ?? '';
                    final city = supplier['city']?.toString() ?? '';
                    final state = supplier['state']?.toString() ?? '';
                    final location = [city, state]
                        .where((value) => value.isNotEmpty)
                        .join(', ');
                    return KCard(
                      onTap: () => Navigator.pop(context, supplier),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: KColors.primarySoft,
                              borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'S',
                              style: KTypography.titleSmall.copyWith(
                                color: KColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          KSpacing.hGapMd,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: KTypography.labelMedium),
                                KSpacing.vGapXs,
                                Row(
                                  children: [
                                    if (gstin.isNotEmpty) ...[
                                      Text('GSTIN: ', style: KTypography.caption),
                                      Text(
                                        gstin,
                                        style: KTypography.mono(fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                      KSpacing.hGapMd,
                                    ],
                                    if (phone.isNotEmpty) ...[
                                      Text(phone, style: KTypography.bodySmall),
                                      if (location.isNotEmpty) ...[
                                        Text('  ·  ', style: KTypography.caption),
                                        Text(location, style: KTypography.bodySmall),
                                      ],
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          KSpacing.hGapSm,
                          Icon(Icons.chevron_right, color: KColors.textHint, size: 18),
                        ],
                      ),
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
/// success or null on cancel.
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
              KSpacing.vGapLg,
              Row(
                children: [
                  Expanded(
                    child: KButton.outlined(
                      label: 'Cancel',
                      onPressed: _saving ? null : () => Navigator.pop(context),
                    ),
                  ),
                  KSpacing.hGapSm,
                  Expanded(
                    child: KButton.primary(
                      label: 'Save Supplier',
                      onPressed: _saving ? null : _save,
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
