import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/contact_repository.dart';

/// Modal contact picker. Returns the selected contact map
/// (with id, displayName, phone, etc.) or null if cancelled.
Future<Map<String, dynamic>?> showContactPicker(
  BuildContext context, {
  bool showQuickCreate = false,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => _ContactPickerSheet(
        scrollController: scrollController,
        showQuickCreate: showQuickCreate,
      ),
    ),
  );
}

class _ContactPickerSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final bool showQuickCreate;
  const _ContactPickerSheet({
    required this.scrollController,
    this.showQuickCreate = false,
  });

  @override
  ConsumerState<_ContactPickerSheet> createState() =>
      _ContactPickerSheetState();
}

class _ContactPickerSheetState extends ConsumerState<_ContactPickerSheet> {
  final _searchController = TextEditingController();
  String? _query;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _quickCreateCustomer() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _QuickCreateCustomerSheet(),
    );
    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactSearchProvider(
        (type: 'CUSTOMER', search: _query)));

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
                      child: Text(
                        widget.showQuickCreate
                            ? 'Customer (optional — leave empty for walk-in)'
                            : 'Select Customer',
                        style: KTypography.h3,
                      ),
                    ),
                    if (widget.showQuickCreate)
                      FilledButton.tonalIcon(
                        onPressed: _quickCreateCustomer,
                        icon: const Icon(Icons.person_add, size: 16),
                        label: const Text('New'),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                  ],
                ),
                KSpacing.vGapSm,
                KTextField.search(
                  controller: _searchController,
                  hint: 'Search by name or phone',
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
            child: contactsAsync.when(
              loading: () => const KShimmerList(),
              error: (err, st) {
                debugPrint('[ContactPicker] ERROR: $err\n$st');
                return KErrorView(message: 'Failed to load contacts');
              },
              data: (data) {
                final content = data['data'];
                final contacts = content is List
                    ? content
                    : (content is Map
                        ? (content['content'] as List?) ?? []
                        : []);

                if (contacts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _query == null
                                ? 'No customers yet'
                                : 'No matches for "$_query"',
                            style: KTypography.bodyMedium,
                          ),
                          if (widget.showQuickCreate) ...[
                            KSpacing.vGapMd,
                            FilledButton.icon(
                              onPressed: _quickCreateCustomer,
                              icon: const Icon(Icons.person_add),
                              label: const Text('Create New Customer'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  controller: widget.scrollController,
                  padding: KSpacing.pagePadding,
                  itemCount: contacts.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final contact =
                        contacts[index] as Map<String, dynamic>;
                    final name =
                        contact['displayName']?.toString() ?? '';
                    final phone =
                        contact['phone']?.toString() ?? '';
                    final email =
                        contact['email']?.toString() ?? '';

                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor:
                            KColors.primarySoft,
                        radius: 20,
                        child: Text(
                          name.isNotEmpty
                              ? name[0].toUpperCase()
                              : '?',
                          style: KTypography.labelLarge
                              .copyWith(color: KColors.primary),
                        ),
                      ),
                      title: Text(name,
                          style: KTypography.labelLarge),
                      subtitle: Text(
                        [phone, email]
                            .where((s) => s.isNotEmpty)
                            .join(' · '),
                        style: KTypography.bodySmall,
                      ),
                      onTap: () =>
                          Navigator.pop(context, contact),
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

/// Minimal quick-create customer sheet for POS flow.
class _QuickCreateCustomerSheet extends ConsumerStatefulWidget {
  const _QuickCreateCustomerSheet();

  @override
  ConsumerState<_QuickCreateCustomerSheet> createState() =>
      _QuickCreateCustomerSheetState();
}

class _QuickCreateCustomerSheetState
    extends ConsumerState<_QuickCreateCustomerSheet> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final repo = ref.read(contactRepositoryProvider);
      final response = await repo.createContact({
        'displayName': name,
        'contactType': 'CUSTOMER',
        if (_phoneController.text.trim().isNotEmpty)
          'phone': _phoneController.text.trim(),
      });
      if (!mounted) return;
      final data = response['data'] is Map
          ? response['data'] as Map<String, dynamic>
          : response;
      Navigator.pop(context, data);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Failed to create customer: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: KSpacing.md,
        right: KSpacing.md,
        top: KSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New Customer', style: KTypography.h3),
          KSpacing.vGapMd,
          KTextField(
            label: 'Display Name *',
            hint: 'e.g. Rajesh Kumar',
            controller: _nameController,
            onFieldSubmitted: (_) => _save(),
          ),
          KSpacing.vGapSm,
          KTextField(
            label: 'Phone',
            hint: 'e.g. 9876543210',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            onFieldSubmitted: (_) => _save(),
          ),
          if (_error != null) ...[
            KSpacing.vGapSm,
            Text(_error!, style: TextStyle(color: KColors.error, fontSize: 12)),
          ],
          KSpacing.vGapMd,
          KButton(
            label: 'Save & Select',
            icon: Icons.check,
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
          KSpacing.vGapLg,
        ],
      ),
    );
  }
}
