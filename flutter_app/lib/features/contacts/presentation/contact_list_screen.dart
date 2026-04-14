import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/contact_repository.dart';

class ContactListScreen extends ConsumerStatefulWidget {
  const ContactListScreen({super.key});

  @override
  ConsumerState<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends ConsumerState<ContactListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  static const _tabs = [
    (label: 'All', type: null),
    (label: 'Customers', type: 'CUSTOMER'),
    (label: 'Vendors', type: 'VENDOR'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs.map((t) => Tab(text: t.label)).toList(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                KSpacing.mdVal, KSpacing.smVal, KSpacing.mdVal, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, email, phone, GSTIN…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabs
                  .map((t) => _ContactTabBody(
                        type: t.type,
                        search: _searchQuery,
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
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

  const _ContactTabBody({required this.type, required this.search});

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

        // Client-side search filter (server search could be wired here too)
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
            itemBuilder: (context, index) =>
                _ContactCard(contact: contacts[index] as Map<String, dynamic>),
          ),
        );
      },
    );
  }
}

class _ContactCard extends StatelessWidget {
  final Map<String, dynamic> contact;

  const _ContactCard({required this.contact});

  @override
  Widget build(BuildContext context) {
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
        final id = contact['id']?.toString();
        if (id != null) context.push('/contacts/$id');
      },
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: typeColor.withValues(alpha: 0.15),
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              style: KTypography.h3.copyWith(color: typeColor),
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
