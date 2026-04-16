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
Future<Map<String, dynamic>?> showContactPicker(BuildContext context) {
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
      ),
    ),
  );
}

class _ContactPickerSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  const _ContactPickerSheet({required this.scrollController});

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
                Text('Select Customer', style: KTypography.h3),
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
                      child: Text(
                        _query == null
                            ? 'No customers yet'
                            : 'No matches',
                        style: KTypography.bodyMedium,
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
