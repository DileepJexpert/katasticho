import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/k_keyboard_list_wrapper.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
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
  List<Map<String, dynamic>> _currentContacts = const [];
  String? _selectedType;
  String _searchQuery = '';
  final Set<String> _selectedIds = {};

  void _openAtIndex(int index) {
    if (index < 0 || index >= _currentContacts.length) return;
    final id = _currentContacts[index]['id']?.toString();
    if (id != null) context.go('/contacts/$id');
  }

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
    return KKeyboardListWrapper(
      itemCount: _currentContacts.length,
      onNew: () => context.go(Routes.contactCreate),
      onRefresh: () => ref.invalidate(contactListProvider(_selectedType)),
      onOpen: _openAtIndex,
      child: Scaffold(
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
            actions: inSelection
                ? null
                : [
                    IconButton(
                      icon: const Icon(Icons.upload_file_outlined, size: 20),
                      tooltip: 'Import contacts',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => context.push(Routes.contactImport),
                    ),
                  ],
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
              onItemsLoaded: (items) => _currentContacts = items,
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
  final ValueChanged<List<Map<String, dynamic>>> onItemsLoaded;

  const _ContactTabBody({
    required this.type,
    required this.search,
    required this.selectedIds,
    required this.inSelection,
    required this.onToggleSelect,
    required this.onItemsLoaded,
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
            return (m['displayName'] as String? ?? '')
                    .toLowerCase()
                    .contains(q) ||
                (m['companyName'] as String? ?? '').toLowerCase().contains(q) ||
                (m['email'] as String? ?? '').toLowerCase().contains(q) ||
                (m['phone'] as String? ?? '').contains(q) ||
                (m['gstin'] as String? ?? '').contains(q);
          }).toList();
        }

        if (contacts.isEmpty) {
          return KEmptyState(
            icon: Icons.people_outline,
            title: search.isNotEmpty
                ? 'No contacts match "$search"'
                : 'No contacts yet',
            subtitle: search.isEmpty
                ? 'Add customers and vendors in one place'
                : null,
            actionLabel: search.isEmpty ? 'Add Contact' : null,
            onAction:
                search.isEmpty ? () => context.push('/contacts/create') : null,
          );
        }

        final contactMaps = contacts
            .whereType<Map>()
            .map((contact) => contact.cast<String, dynamic>())
            .toList();
        onItemsLoaded(contactMaps);

        return KResponsiveEntityList<Map<String, dynamic>>(
          items: contactMaps,
          onRefresh: () async => ref.invalidate(contactListProvider(type)),
          mobileItemBuilder: (context, contact) {
            final id = contact['id']?.toString() ?? '';
            return _ContactCard(
              contact: contact,
              selected: selectedIds.contains(id),
              inSelection: inSelection,
              onToggleSelect: () => onToggleSelect(id),
            );
          },
          tableBuilder: (context) => _ContactTable(
            contacts: contactMaps,
            selectedIds: selectedIds,
            onToggleSelect: onToggleSelect,
          ),
        );
      },
    );
  }
}

class _ContactTable extends StatelessWidget {
  final List<Map<String, dynamic>> contacts;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggleSelect;

  const _ContactTable({
    required this.contacts,
    required this.selectedIds,
    required this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    return KEntityDataTable(
      columnSpacing: 12,
      horizontalMargin: 10,
      columns: const [
        DataColumn(label: SizedBox(width: 32, child: Text(''))),
        DataColumn(label: Text('Contact')),
        DataColumn(label: Text('Type')),
        DataColumn(label: Text('Company')),
        DataColumn(label: Text('Phone')),
        DataColumn(label: Text('AR')),
        DataColumn(label: Text('AP')),
        DataColumn(label: Text('Status')),
        DataColumn(label: SizedBox(width: 32, child: Text(''))),
      ],
      rows: contacts.map((contact) {
        final id = contact['id']?.toString() ?? '';
        final displayName = contact['displayName'] as String? ?? 'Unknown';
        final companyName = contact['companyName'] as String? ?? '--';
        final contactType = contact['contactType'] as String? ?? 'CUSTOMER';
        final phone =
            contact['phone'] as String? ?? contact['mobile'] as String? ?? '--';
        final outstandingAr = (contact['outstandingAr'] as num?)?.toDouble() ??
            (contact['outstandingAR'] as num?)?.toDouble() ??
            (contact['outstanding_ar'] as num?)?.toDouble() ??
            0;
        final outstandingAp = (contact['outstandingAp'] as num?)?.toDouble() ??
            (contact['outstandingAP'] as num?)?.toDouble() ??
            (contact['outstanding_ap'] as num?)?.toDouble() ??
            0;
        final active =
            contact['active'] as bool? ?? contact['isActive'] as bool? ?? true;
        final selected = selectedIds.contains(id);

        return DataRow(
          selected: selected,
          color: kEntityRowColor(context, selected: selected),
          onSelectChanged: (_) => onToggleSelect(id),
          cells: [
            DataCell(KTableSelectionCell(
              selected: selected,
              onChanged: (_) => onToggleSelect(id),
            )),
            DataCell(_ContactNameCell(
              name: displayName,
              type: contactType,
            )),
            DataCell(_ContactTypeCell(type: contactType)),
            DataCell(KTableTextCell(value: companyName, width: 130)),
            DataCell(KTableTextCell(value: phone, width: 108)),
            DataCell(_ContactAmountCell(value: outstandingAr)),
            DataCell(_ContactAmountCell(value: outstandingAp)),
            DataCell(KStatusChip(
              status: active ? 'PAID' : 'CANCELLED',
              label: active ? 'Active' : 'Inactive',
              dense: true,
            )),
            DataCell(KTableOpenActionCell(
              tooltip: 'Open contact',
              onPressed:
                  id.isEmpty ? null : () => context.push('/contacts/$id'),
            )),
          ],
        );
      }).toList(),
    );
  }
}

class _ContactNameCell extends StatelessWidget {
  final String name;
  final String type;

  const _ContactNameCell({
    required this.name,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final color = _contactTypeColor(type);
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 190,
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: KTypography.labelMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          KSpacing.hGapSm,
          Expanded(
            child: Text(
              name,
              style: KTypography.labelLarge.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactTypeCell extends StatelessWidget {
  final String type;

  const _ContactTypeCell({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = _contactTypeColor(type);
    final label = type == 'BOTH' ? 'Both' : type.capitalize();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: KTypography.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ContactAmountCell extends StatelessWidget {
  final double value;

  const _ContactAmountCell({required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      child: Text(
        value == 0 ? '--' : CurrencyFormatter.formatIndian(value),
        textAlign: TextAlign.end,
        style: KTypography.amountSmall.copyWith(
          color: value == 0 ? KColors.textHint : KColors.textPrimary,
        ),
      ),
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
    final phone = contact['phone'] as String? ?? contact['mobile'] as String?;

    final typeColor = _contactTypeColor(contactType);

    final typeLabel = contactType == 'BOTH' ? 'Both' : contactType.capitalize();

    // Build the compact subtitle chips: prefer company, then phone, then email.
    final subtitleChips = <_InfoChipData>[
      if (companyName != null && companyName.isNotEmpty)
        _InfoChipData(Icons.business_outlined, companyName),
      if (phone != null && phone.isNotEmpty)
        _InfoChipData(Icons.phone_outlined, phone),
      if (email != null && email.isNotEmpty)
        _InfoChipData(Icons.mail_outline, email),
    ];

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: inSelection
                ? Center(
                    child: Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: selected ? cs.primary : cs.onSurfaceVariant,
                      size: 24,
                    ),
                  )
                : CircleAvatar(
                    radius: 20,
                    backgroundColor: typeColor.withValues(alpha: 0.15),
                    child: Text(
                      displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : '?',
                      style: KTypography.labelLarge.copyWith(
                        color: typeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        style: KTypography.labelLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        typeLabel,
                        style:
                            KTypography.labelSmall.copyWith(color: typeColor),
                      ),
                    ),
                  ],
                ),
                if (subtitleChips.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  _InfoChipRow(chips: subtitleChips),
                ],
                if (gstin != null && gstin.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'GSTIN: $gstin',
                    style: KTypography.labelSmall
                        .copyWith(color: KColors.textHint),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (!inSelection) ...[
            KSpacing.hGapXs,
            const Icon(Icons.chevron_right, color: KColors.textHint, size: 18),
          ],
        ],
      ),
    );
  }
}

class _InfoChipData {
  final IconData icon;
  final String text;
  const _InfoChipData(this.icon, this.text);
}

class _InfoChipRow extends StatelessWidget {
  final List<_InfoChipData> chips;
  const _InfoChipRow({required this.chips});

  @override
  Widget build(BuildContext context) {
    // Inline chips separated by a bullet dot, truncated if overflow.
    final children = <Widget>[];
    for (var i = 0; i < chips.length; i++) {
      if (i > 0) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text('·',
              style: KTypography.bodySmall.copyWith(color: KColors.textHint)),
        ));
      }
      final c = chips[i];
      children.add(Icon(c.icon, size: 11, color: KColors.textHint));
      children.add(const SizedBox(width: 3));
      children.add(Flexible(
        child: Text(
          c.text,
          style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ));
    }
    return Row(children: children);
  }
}

extension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
}

Color _contactTypeColor(String type) {
  return type == 'VENDOR'
      ? KColors.info
      : type == 'BOTH'
          ? KColors.warning
          : KColors.success;
}
