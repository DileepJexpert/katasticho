import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/contact_repository.dart';

class ContactDetailScreen extends ConsumerWidget {
  final String contactId;

  const ContactDetailScreen({super.key, required this.contactId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Map<String, dynamic>>(
      future: ref.read(contactRepositoryProvider).getContact(contactId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: KLoading());
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Contact')),
            body: KErrorView(message: 'Failed to load contact'),
          );
        }

        final raw = snapshot.data!;
        final contact = (raw['data'] ?? raw) as Map<String, dynamic>;
        final displayName = contact['displayName'] as String? ?? 'Contact';
        final contactType = contact['contactType'] as String? ?? 'CUSTOMER';

        final typeColor = contactType == 'VENDOR'
            ? KColors.info
            : contactType == 'BOTH'
                ? KColors.warning
                : KColors.success;

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(displayName),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () =>
                      context.push('/contacts/$contactId/edit'),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete contact?'),
                          content: Text('Delete $displayName? This cannot be undone.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel')),
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete',
                                    style: TextStyle(color: KColors.error))),
                          ],
                        ),
                      );
                      if (confirm == true && context.mounted) {
                        await ref
                            .read(contactRepositoryProvider)
                            .deleteContact(contactId);
                        ref.invalidate(contactListProvider);
                        if (context.mounted) context.pop();
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Details'),
                  Tab(text: 'Persons'),
                  Tab(text: 'Activity'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _DetailsTab(contact: contact, typeColor: typeColor),
                _PersonsTab(
                    contact: contact, contactId: contactId),
                KActivityTimeline(
                  entityType: 'CONTACT',
                  entityId: contactId,
                  systemEvents: _contactEvents(contact),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DetailsTab extends StatelessWidget {
  final Map<String, dynamic> contact;
  final Color typeColor;

  const _DetailsTab({required this.contact, required this.typeColor});

  @override
  Widget build(BuildContext context) {
    final displayName = contact['displayName'] as String? ?? 'Contact';
    final companyName = contact['companyName'] as String?;
    final contactType = contact['contactType'] as String? ?? 'CUSTOMER';
    final email = contact['email'] as String?;
    final phone = contact['phone'] as String?;
    final mobile = contact['mobile'] as String?;
    final gstin = contact['gstin'] as String?;
    final pan = contact['pan'] as String?;
    final gstTreatment = contact['gstTreatment'] as String? ?? 'UNREGISTERED';
    final billingCity = contact['billingCity'] as String?;
    final billingState = contact['billingState'] as String?;
    final billingCountry = contact['billingCountry'] as String?;
    final creditLimit = contact['creditLimit'] as num?;
    final paymentTermsDays = contact['paymentTermsDays'] as num?;

    return SingleChildScrollView(
      padding: KSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: typeColor.withValues(alpha: 0.15),
                  child: Text(
                    displayName[0].toUpperCase(),
                    style:
                        KTypography.displayLarge.copyWith(color: typeColor),
                  ),
                ),
                KSpacing.vGapMd,
                Text(displayName, style: KTypography.h2),
                if (companyName != null && companyName.isNotEmpty) ...[
                  KSpacing.vGapXs,
                  Text(companyName, style: KTypography.bodyMedium),
                ],
                KSpacing.vGapSm,
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    contactType,
                    style: KTypography.labelMedium.copyWith(color: typeColor),
                  ),
                ),
              ],
            ),
          ),
          KSpacing.vGapLg,

          // Contact info
          if (email != null || phone != null || mobile != null) ...[
            _SectionHeader('Contact'),
            _InfoRow(Icons.email_outlined, 'Email', email),
            _InfoRow(Icons.phone_outlined, 'Phone', phone),
            _InfoRow(Icons.smartphone_outlined, 'Mobile', mobile),
            KSpacing.vGapMd,
          ],

          // Tax info
          if (gstin != null || pan != null) ...[
            _SectionHeader('Tax'),
            _InfoRow(Icons.receipt_long_outlined, 'GSTIN', gstin),
            _InfoRow(Icons.credit_card_outlined, 'PAN', pan),
            _InfoRow(Icons.account_balance_outlined, 'GST Treatment',
                gstTreatment),
            KSpacing.vGapMd,
          ],

          // Address
          if (billingCity != null || billingState != null) ...[
            _SectionHeader('Billing Address'),
            _InfoRow(
                Icons.location_on_outlined,
                'Location',
                [billingCity, billingState, billingCountry]
                    .where((s) => s != null && s.isNotEmpty)
                    .join(', ')),
            KSpacing.vGapMd,
          ],

          // Financial
          _SectionHeader('Financial Terms'),
          _InfoRow(
              Icons.account_balance_wallet_outlined,
              'Credit Limit',
              creditLimit != null
                  ? '₹${creditLimit.toStringAsFixed(0)}'
                  : '₹0'),
          _InfoRow(
              Icons.calendar_today_outlined,
              'Payment Terms',
              paymentTermsDays != null
                  ? (paymentTermsDays == 0
                      ? 'Due on Receipt'
                      : 'Net ${paymentTermsDays.toInt()} days')
                  : 'Net 30 days'),
          KSpacing.vGapXl,
        ],
      ),
    );
  }
}

class _PersonsTab extends StatelessWidget {
  final Map<String, dynamic> contact;
  final String contactId;

  const _PersonsTab({required this.contact, required this.contactId});

  @override
  Widget build(BuildContext context) {
    final persons = (contact['persons'] as List?) ?? [];

    if (persons.isEmpty) {
      return KEmptyState(
        icon: Icons.person_outline,
        title: 'No contact persons',
        subtitle: 'Add a contact person for this account',
      );
    }

    return ListView.separated(
      padding: KSpacing.pagePadding,
      itemCount: persons.length,
      separatorBuilder: (_, __) => KSpacing.vGapSm,
      itemBuilder: (context, i) {
        final person = persons[i] as Map<String, dynamic>;
        final firstName = person['firstName'] as String? ?? '';
        final lastName = person['lastName'] as String? ?? '';
        final fullName = '$firstName $lastName'.trim();
        final designation = person['designation'] as String?;
        final email = person['email'] as String?;
        final isPrimary = person['primary'] as bool? ?? false;

        return KCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: KColors.primaryLight.withValues(alpha: 0.15),
                child: Text(
                  fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                  style: KTypography.labelMedium
                      .copyWith(color: KColors.primary),
                ),
              ),
              KSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(fullName.isEmpty ? 'Contact Person' : fullName,
                            style: KTypography.labelLarge),
                        if (isPrimary) ...[
                          KSpacing.hGapSm,
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: KColors.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('Primary',
                                style: KTypography.labelSmall
                                    .copyWith(color: KColors.success)),
                          ),
                        ],
                      ],
                    ),
                    if (designation != null && designation.isNotEmpty) ...[
                      KSpacing.vGapXs,
                      Text(designation, style: KTypography.bodySmall),
                    ],
                    if (email != null && email.isNotEmpty) ...[
                      KSpacing.vGapXs,
                      Text(email, style: KTypography.bodySmall),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: KSpacing.sm),
        child: Text(title, style: KTypography.h3),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;

  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: KColors.textHint),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: KTypography.labelSmall),
                Text(value!, style: KTypography.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

List<KTimelineEvent> _contactEvents(Map<String, dynamic> contact) {
  final events = <KTimelineEvent>[];
  final createdAt = _parseTs(contact['createdAt']);
  if (createdAt != null) {
    events.add(KTimelineEvent.system(
      timestamp: createdAt,
      message: 'Contact created',
      by: contact['createdByName'] as String?,
      icon: Icons.person_add_alt_1_rounded,
      color: KColors.info,
    ));
  }
  final updatedAt = _parseTs(contact['updatedAt']);
  if (updatedAt != null && updatedAt != createdAt) {
    events.add(KTimelineEvent.system(
      timestamp: updatedAt,
      message: 'Contact details updated',
      icon: Icons.edit_note_rounded,
      color: KColors.primary,
    ));
  }
  return events;
}

DateTime? _parseTs(dynamic v) {
  if (v == null) return null;
  try {
    return DateTime.parse(v as String).toLocal();
  } catch (_) {
    return null;
  }
}
