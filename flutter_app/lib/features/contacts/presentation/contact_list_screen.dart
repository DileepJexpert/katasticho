import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/contact_repository.dart';

const _contactTabs = [
  KListTab(label: 'All'),
  KListTab(label: 'Customers', value: 'CUSTOMER'),
  KListTab(label: 'Vendors', value: 'VENDOR'),
];

class ContactListScreen extends ConsumerStatefulWidget {
  const ContactListScreen({super.key});

  @override
  ConsumerState<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends ConsumerState<ContactListScreen> {
  String? _selectedType;
  String _searchQuery = '';
  final Set<String> _selectedIds = {};

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _clearSelection() => setState(_selectedIds.clear);

  Future<void> _bulkDelete() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $count contact${count == 1 ? '' : 's'}?'),
        content: const Text(
            'This action cannot be undone. Contacts with transactions may fail to delete.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: KColors.error.withValues(alpha: 0.12),
              foregroundColor: KColors.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final repo = ref.read(contactRepositoryProvider);
    final ids = _selectedIds.toList();
    int success = 0;
    int failed = 0;
    for (final id in ids) {
      try {
        await repo.deleteContact(id);
        success++;
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    setState(_selectedIds.clear);
    ref.invalidate(contactListProvider(_selectedType));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? 'Deleted $success contact${success == 1 ? '' : 's'}'
              : 'Deleted $success, $failed failed',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inSelection = _selectedIds.isNotEmpty;
    return Scaffold(
      body: Column(
        children: [
          KListPageHeader(
            title: 'Contacts',
            searchHint: 'Search by name, email, phone, GSTIN…',
            tabs: _contactTabs,
            selectedTab: _selectedType,
            onTabChanged: (v) => setState(() => _selectedType = v),
            onSearchChanged: (q) => setState(() => _searchQuery = q),
            selectionCount: _selectedIds.length,
            onClearSelection: _clearSelection,
            selectionActions: [
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                tooltip: 'Delete selected',
                color: KColors.error,
                visualDensity: VisualDensity.compact,
                onPressed: _bulkDelete,
              ),
            ],
          ),
          Expanded(
            child: _ContactTabBody(
              type: _selectedType,
              search: _searchQuery,
              selectedIds: _selectedIds,
              inSelection: inSelection,
              onToggleSelect: _toggleSelect,
            ),
          ),
        ],
      ),
      floatingActionButton: inSelection
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/contacts/create'),
              icon: const Icon(Icons.person_add),
              label: const Text('Add Contact'),
            ),
    );
  }
}

class _ContactTabBody extends ConsumerWidget {
  final String? type;
  final String search;
  final Set<String> selectedIds;
  final bool inSelection;
  final ValueChanged<String> onToggleSelect;

  const _ContactTabBody({
    required this.type,
    required this.search,
    required this.selectedIds,
    required this.inSelection,
    required this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncContacts = ref.watch(contactListProvider(type));

    return asyncContacts.when(
      loading: () => const KShimmerList(),
      error: (err, _) => KErrorView(
        message: 'Failed to load contacts',
        onRetry: () => ref.invalidate(contactListProvider(type)),
      ),
      data: (data) {
        final content = data['data'];
        List<dynamic> contacts = content is List
            ? content
            : (content is Map ? (content['content'] as List?) ?? [] : []);

        if (search.isNotEmpty) {
          final q = search.toLowerCase();
          contacts = contacts.where((c) {
            final m = c as Map<String, dynamic>;
            return (m['displayName'] as String? ?? '').toLowerCase().contains(q) ||
                (m['companyName'] as String? ?? '').toLowerCase().contains(q) ||
                (m['email'] as String? ?? '').toLowerCase().contains(q) ||
                (m['phone'] as String? ?? '').contains(q) ||
                (m['gstin'] as String? ?? '').contains(q);
          }).toList();
        }

        if (contacts.isEmpty) {
          return KEmptyState(
            icon: Icons.people_outline,
            title: search.isNotEmpty ? 'No contacts match "$search"' : 'No contacts yet',
            subtitle: search.isEmpty ? 'Add customers and vendors in one place' : null,
            actionLabel: search.isEmpty ? 'Add Contact' : null,
            onAction: search.isEmpty ? () => context.push('/contacts/create') : null,
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(contactListProvider(type)),
          child: ListView.separated(
            padding: KSpacing.pagePadding,
            itemCount: contacts.length,
            separatorBuilder: (_, __) => KSpacing.vGapSm,
            itemBuilder: (context, index) {
              final contact = contacts[index] as Map<String, dynamic>;
              final id = contact['id']?.toString() ?? '';
              return _ContactCard(
                contact: contact,
                selected: selectedIds.contains(id),
                inSelection: inSelection,
                onToggleSelect: () => onToggleSelect(id),
              );
            },
          ),
        );
      },
    );
  }
}

class _ContactCard extends StatelessWidget {
  final Map<String, dynamic> contact;
  final bool selected;
  final bool inSelection;
  final VoidCallback onToggleSelect;

  const _ContactCard({
    required this.contact,
    required this.selected,
    required this.inSelection,
    required this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final displayName = contact['displayName'] as String? ?? 'Unknown';
    final companyName = contact['companyName'] as String?;
    final contactType = contact['contactType'] as String? ?? 'CUSTOMER';
    final gstin = contact['gstin'] as String?;
    final email = contact['email'] as String?;

    final typeColor = contactType == 'VENDOR'
        ? KColors.info
        : contactType == 'BOTH'
            ? KColors.warning
            : KColors.success;

    final typeLabel = contactType == 'BOTH' ? 'Both' : contactType.capitalize();

    return KCard(
      onTap: () {
        if (inSelection) {
          onToggleSelect();
          return;
        }
        final id = contact['id']?.toString();
        if (id != null) context.push('/contacts/$id');
      },
      onLongPress: onToggleSelect,
      borderColor: selected ? cs.primary : null,
      backgroundColor: selected ? cs.primary.withValues(alpha: 0.06) : null,
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: inSelection
                ? Center(
                    child: Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: selected ? cs.primary : cs.onSurfaceVariant,
                      size: 26,
                    ),
                  )
                : CircleAvatar(
                    radius: 24,
                    backgroundColor: typeColor.withValues(alpha: 0.15),
                    child: Text(
                      displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : '?',
                      style: KTypography.h3.copyWith(color: typeColor),
                    ),
                  ),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: KTypography.labelLarge),
                if (companyName != null && companyName.isNotEmpty) ...[
                  KSpacing.vGapXs,
                  Text(companyName, style: KTypography.bodySmall),
                ] else if (email != null && email.isNotEmpty) ...[
                  KSpacing.vGapXs,
                  Text(email, style: KTypography.bodySmall),
                ],
                if (gstin != null && gstin.isNotEmpty) ...[
                  KSpacing.vGapXs,
                  Text('GSTIN: $gstin', style: KTypography.labelSmall),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  typeLabel,
                  style: KTypography.labelSmall.copyWith(color: typeColor),
                ),
              ),
            ],
          ),
          KSpacing.hGapSm,
          if (!inSelection)
            const Icon(Icons.chevron_right, color: KColors.textHint),
        ],
      ),
    );
  }
}

extension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
}
