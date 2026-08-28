import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/supplier_repository.dart';

/// Supplier (vendor) master — list + create/edit.
///
/// The backend CRUD (`/api/v1/suppliers`) and [SupplierRepository] already
/// existed; only a picker sheet shipped before, so GSTIN / PAN / payment-terms
/// could never be set from a proper master screen. This is that screen.
class SupplierListScreen extends ConsumerStatefulWidget {
  const SupplierListScreen({super.key});

  @override
  ConsumerState<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends ConsumerState<SupplierListScreen> {
  final _searchController = TextEditingController();
  String? _query;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    if (existing == null) {
      await context.push('/contacts/create?type=VENDOR');
      if (mounted) ref.invalidate(supplierListProvider);
      return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => SupplierFormSheet(existing: existing),
    );
    if (saved == true) ref.invalidate(supplierListProvider);
  }

  List<Map<String, dynamic>> _extractList(Map<String, dynamic> response) {
    final inner = response['data'];
    final content = inner is List
        ? inner
        : (inner is Map ? (inner['content'] as List?) ?? const [] : const []);
    return content
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(supplierListProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suppliers & Vendors'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: KSpacing.md),
            child: KButton.primary(
              size: KButtonSize.small,
              icon: Icons.add,
              label: 'New Supplier',
              onPressed: () => _openForm(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(KSpacing.md),
            child: KTextField.search(
              hint: 'Search by supplier name, GSTIN, city…',
              controller: _searchController,
              onChanged: (v) => setState(
                  () => _query = v.trim().isEmpty ? null : v.trim()),
              onClear: () {
                _searchController.clear();
                setState(() => _query = null);
              },
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const KShimmerList(),
              error: (e, _) => KErrorView(
                message: 'Failed to load suppliers',
                onRetry: () => ref.invalidate(supplierListProvider),
              ),
              data: (response) {
                final list = _extractList(response);
                if (list.isEmpty) {
                  return Center(
                    child: KEmptyState(
                      icon: Icons.local_shipping_outlined,
                      title: _query == null ? 'No Suppliers Registered' : 'No Matching Suppliers',
                      actionLabel: _query == null ? 'Add Supplier' : null,
                      onAction: _query == null ? () => _openForm() : null,
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      KSpacing.md, 0, KSpacing.md, KSpacing.xl),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => KSpacing.vGapSm,
                  itemBuilder: (_, i) {
                    final s = list[i];
                    final name = s['name']?.toString() ?? '';
                    final gstin = s['gstin']?.toString() ?? '';
                    final phone = s['phone']?.toString() ?? '';
                    final city = s['city']?.toString() ?? '';
                    final paymentTerms = s['paymentTermsDays'] != null
                        ? '${s['paymentTermsDays']} Days'
                        : null;
                    final active = s['active'] != false;
                    return KCard(
                      onTap: () => _openForm(existing: s),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: KColors.primarySoft,
                              borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'S',
                              style: KTypography.titleMedium.copyWith(
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
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: KTypography.titleMedium,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    KSpacing.hGapSm,
                                    KStatusChip(status: active ? 'ACTIVE' : 'INACTIVE'),
                                  ],
                                ),
                                KSpacing.vGapXs,
                                Row(
                                  children: [
                                    if (gstin.isNotEmpty) ...[
                                      Text(
                                        'GSTIN: ',
                                        style: KTypography.caption,
                                      ),
                                      Text(
                                        gstin,
                                        style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                      KSpacing.hGapMd,
                                    ],
                                    if (phone.isNotEmpty) ...[
                                      Icon(Icons.phone_outlined, size: 13, color: KColors.textHint),
                                      const SizedBox(width: 4),
                                      Text(phone, style: KTypography.bodySmall),
                                      KSpacing.hGapMd,
                                    ],
                                    if (city.isNotEmpty) ...[
                                      Icon(Icons.location_on_outlined, size: 13, color: KColors.textHint),
                                      const SizedBox(width: 4),
                                      Text(city, style: KTypography.bodySmall),
                                    ],
                                  ],
                                ),
                                if (paymentTerms != null) ...[
                                  KSpacing.vGapXs,
                                  Row(
                                    children: [
                                      Text('Payment Terms: ', style: KTypography.caption),
                                      Text(
                                        paymentTerms,
                                        style: KTypography.mono(fontSize: 11, fontWeight: FontWeight.w600, color: KColors.primary),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          KSpacing.hGapSm,
                          Icon(Icons.chevron_right, color: KColors.textHint),
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

/// Create / edit a supplier. Pops `true` when a save succeeds so the caller
/// can refresh its list. Pass [existing] (a supplier map) to edit.
class SupplierFormSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  const SupplierFormSheet({super.key, this.existing});

  @override
  ConsumerState<SupplierFormSheet> createState() => _SupplierFormSheetState();
}

class _SupplierFormSheetState extends ConsumerState<SupplierFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _gstin;
  late final TextEditingController _pan;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address1;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _postalCode;
  late final TextEditingController _paymentTerms;
  late final TextEditingController _notes;
  bool _active = true;
  bool _saving = false;
  String? _error;

  Map<String, dynamic>? get _existing => widget.existing;
  bool get _isEdit => _existing != null && _existing!['id'] != null;

  @override
  void initState() {
    super.initState();
    final e = _existing ?? const {};
    _name = TextEditingController(text: e['name']?.toString() ?? '');
    _gstin = TextEditingController(text: e['gstin']?.toString() ?? '');
    _pan = TextEditingController(text: e['pan']?.toString() ?? '');
    _phone = TextEditingController(text: e['phone']?.toString() ?? '');
    _email = TextEditingController(text: e['email']?.toString() ?? '');
    _address1 = TextEditingController(text: e['addressLine1']?.toString() ?? '');
    _city = TextEditingController(text: e['city']?.toString() ?? '');
    _state = TextEditingController(text: e['state']?.toString() ?? '');
    _postalCode = TextEditingController(text: e['postalCode']?.toString() ?? '');
    _paymentTerms = TextEditingController(
        text: e['paymentTermsDays'] != null
            ? e['paymentTermsDays'].toString()
            : '');
    _notes = TextEditingController(text: e['notes']?.toString() ?? '');
    _active = e['active'] != false;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _gstin,
      _pan,
      _phone,
      _email,
      _address1,
      _city,
      _state,
      _postalCode,
      _paymentTerms,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    String t(TextEditingController c) => c.text.trim();
    final payload = <String, dynamic>{
      'name': t(_name),
      if (t(_gstin).isNotEmpty) 'gstin': t(_gstin),
      if (t(_pan).isNotEmpty) 'pan': t(_pan),
      if (t(_phone).isNotEmpty) 'phone': t(_phone),
      if (t(_email).isNotEmpty) 'email': t(_email),
      if (t(_address1).isNotEmpty) 'addressLine1': t(_address1),
      if (t(_city).isNotEmpty) 'city': t(_city),
      if (t(_state).isNotEmpty) 'state': t(_state),
      if (t(_postalCode).isNotEmpty) 'postalCode': t(_postalCode),
      if (int.tryParse(t(_paymentTerms)) != null)
        'paymentTermsDays': int.parse(t(_paymentTerms)),
      if (t(_notes).isNotEmpty) 'notes': t(_notes),
      'active': _active,
    };
    try {
      final repo = ref.read(supplierRepositoryProvider);
      if (_isEdit) {
        await repo.updateSupplier(_existing!['id'].toString(), payload);
      } else {
        await repo.createSupplier(payload);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = 'Failed to save supplier');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(KSpacing.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_isEdit ? 'Edit Supplier' : 'New Supplier',
                  style: KTypography.h3),
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: KTextField(
                      label: 'GSTIN',
                      controller: _gstin,
                      hint: '27AAAAA0000A1Z5',
                    ),
                  ),
                  KSpacing.hGapSm,
                  Expanded(
                    child: KTextField(label: 'PAN', controller: _pan),
                  ),
                ],
              ),
              KSpacing.vGapSm,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: KTextField(
                      label: 'Phone',
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  KSpacing.hGapSm,
                  Expanded(
                    child: KTextField(
                      label: 'Email',
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                ],
              ),
              KSpacing.vGapSm,
              KTextField(label: 'Address', controller: _address1),
              KSpacing.vGapSm,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: KTextField(label: 'City', controller: _city),
                  ),
                  KSpacing.hGapSm,
                  Expanded(
                    child: KTextField(label: 'State', controller: _state),
                  ),
                ],
              ),
              KSpacing.vGapSm,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: KTextField(
                        label: 'Postal Code', controller: _postalCode),
                  ),
                  KSpacing.hGapSm,
                  Expanded(
                    child: KTextField(
                      label: 'Payment Terms (days)',
                      controller: _paymentTerms,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              KSpacing.vGapSm,
              KTextField(
                label: 'Notes',
                controller: _notes,
                maxLines: 2,
              ),
              KSpacing.vGapSm,
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text('Active Supplier', style: KTypography.bodyMedium),
                subtitle: Text('Allow issuing purchase orders to this vendor', style: KTypography.caption),
                value: _active,
                activeTrackColor: KColors.primary,
                onChanged: (v) => setState(() => _active = v),
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
                      label: _isEdit ? 'Save Changes' : 'Create Supplier',
                      isLoading: _saving,
                      onPressed: _saving ? null : _save,
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
