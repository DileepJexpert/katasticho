import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/intl/country_currency.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../../procurement/data/supplier_repository.dart';
import '../data/contact_repository.dart';

class ContactDetailScreen extends ConsumerWidget {
  final String contactId;

  const ContactDetailScreen({super.key, required this.contactId});

  Future<void> _enableSupplier(
      BuildContext context, WidgetRef ref, String displayName) async {
    try {
      await ref.read(supplierRepositoryProvider).enableFromContact(contactId);
      ref.invalidate(supplierListProvider);
      ref.invalidate(contactListProvider);
      ref.invalidate(contactSummaryProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$displayName is now available as a supplier')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not enable supplier: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taxLabel =
        ref.watch(countryProfileProvider).valueOrNull?.taxIdLabel ?? 'GSTIN';
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
        final supplierEnabled = contact['supplierEnabled'] as bool? ?? false;

        final typeColor = contactType == 'VENDOR'
            ? KColors.info
            : contactType == 'BOTH'
                ? KColors.warning
                : KColors.success;

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to contacts',
                onPressed: () => context.go(Routes.contacts),
              ),
              title: Text(displayName),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context.push('/contacts/$contactId/edit'),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'statement') {
                      context.push('/contacts/$contactId/statement',
                          extra: displayName);
                    } else if (v == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete contact?'),
                          content: Text(
                              'Delete $displayName? This cannot be undone.'),
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
                        ref.invalidate(contactSummaryProvider);
                        if (context.mounted) context.pop();
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'statement', child: Text('View Statement')),
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
                _DetailsTab(
                    contact: contact,
                    typeColor: typeColor,
                    taxLabel: taxLabel,
                    onEnableSupplier:
                        !supplierEnabled &&
                                (contactType == 'VENDOR' || contactType == 'BOTH')
                            ? () => _enableSupplier(context, ref, displayName)
                            : null),
                _PersonsTab(contact: contact, contactId: contactId),
                KActivityTimeline(
                  entityType: 'CONTACT',
                  entityId: contactId,
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
  final String taxLabel;
  final VoidCallback? onEnableSupplier;

  const _DetailsTab(
      {required this.contact,
      required this.typeColor,
      required this.taxLabel,
      this.onEnableSupplier});

  @override
  Widget build(BuildContext context) {
    final displayName = contact['displayName'] as String? ?? 'Contact';
    final companyName = contact['companyName'] as String?;
    final contactType = contact['contactType'] as String? ?? 'CUSTOMER';
    final email = contact['email'] as String?;
    final phone = contact['phone'] as String?;
    final mobile = contact['mobile'] as String?;
    final website = contact['website'] as String?;
    final gstin = contact['gstin'] as String?;
    final pan = contact['pan'] as String?;
    final gstTreatment = contact['gstTreatment'] as String? ?? 'UNREGISTERED';
    final msmeRegistered = contact['msmeRegistered'] as bool? ?? false;
    final msmeRegNo = contact['msmeRegistrationNo'] as String?;
    final tdsApplicable = contact['tdsApplicable'] as bool? ?? false;
    final tdsSection = contact['tdsSection'] as String?;
    final tdsRate = contact['tdsRate'] as num?;

    final billingAddr1 = contact['billingAddressLine1'] as String?;
    final billingCity = contact['billingCity'] as String?;
    final billingState = contact['billingState'] as String?;
    final billingPostal = contact['billingPostalCode'] as String?;
    final billingCountry = contact['billingCountry'] as String?;

    final shipAddr1 = contact['shippingAddressLine1'] as String?;
    final shipCity = contact['shippingCity'] as String?;
    final shipState = contact['shippingState'] as String?;
    final shipPostal = contact['shippingPostalCode'] as String?;
    final shipCountry = contact['shippingCountry'] as String?;

    final bankName = contact['bankName'] as String?;
    final bankAccountNo = contact['bankAccountNo'] as String?;
    final bankIfsc = contact['bankIfsc'] as String?;
    final upiId = contact['upiId'] as String?;

    final creditLimit = (contact['creditLimit'] as num?)?.toDouble() ?? 0.0;
    final outstandingAr = (contact['outstandingAr'] as num?)?.toDouble() ?? 0.0;
    final outstandingAp = (contact['outstandingAp'] as num?)?.toDouble() ?? 0.0;
    final openingBalance = (contact['openingBalance'] as num?)?.toDouble() ?? 0.0;
    final paymentTermsDays = contact['paymentTermsDays'] as num?;
    final notes = contact['notes'] as String?;

    final leftColumnWidgets = [
      // Header card
      Center(
        child: Column(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: typeColor.withValues(alpha: 0.15),
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: KTypography.displayLarge.copyWith(color: typeColor),
              ),
            ),
            KSpacing.vGapSm,
            Text(displayName, style: KTypography.h2),
            if (companyName != null && companyName.isNotEmpty) ...[
              KSpacing.vGapXs,
              Text(companyName, style: KTypography.bodyMedium),
            ],
            KSpacing.vGapSm,
            Wrap(
              spacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    contactType,
                    style: KTypography.labelMedium.copyWith(color: typeColor),
                  ),
                ),
                if (msmeRegistered)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: KColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'MSME Reg.',
                      style: KTypography.labelMedium.copyWith(color: KColors.primary),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      KSpacing.vGapLg,

      // Balances Overview Cards
      Row(
        children: [
          Expanded(
            child: KCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Receivables (AR)', style: TextStyle(fontSize: 12, color: KColors.textSecondary)),
                  KSpacing.vGapXs,
                  KMoney(outstandingAr, size: KMoneySize.large),
                ],
              ),
            ),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: KCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payables (AP)', style: TextStyle(fontSize: 12, color: KColors.textSecondary)),
                  KSpacing.vGapXs,
                  KMoney(outstandingAp, size: KMoneySize.large),
                ],
              ),
            ),
          ),
        ],
      ),
      KSpacing.vGapMd,

      // Contact info
      if (email != null || phone != null || mobile != null || website != null) ...[
        _SectionHeader('Contact Information'),
        _InfoRow(Icons.email_outlined, 'Email', email),
        _InfoRow(Icons.phone_outlined, 'Phone', phone),
        _InfoRow(Icons.smartphone_outlined, 'Mobile', mobile),
        _InfoRow(Icons.language_outlined, 'Website', website),
        KSpacing.vGapMd,
      ],

      // Addresses
      _SectionHeader('Addresses'),
      _InfoRow(
        Icons.location_on_outlined,
        'Billing Address',
        [billingAddr1, billingCity, billingState, billingPostal, billingCountry]
            .where((s) => s != null && s.isNotEmpty)
            .join(', '),
      ),
      if (shipAddr1 != null && shipAddr1.isNotEmpty)
        _InfoRow(
          Icons.local_shipping_outlined,
          'Shipping Address',
          [shipAddr1, shipCity, shipState, shipPostal, shipCountry]
              .where((s) => s != null && s.isNotEmpty)
              .join(', '),
        ),
    ];

    final contactId = contact['id']?.toString() ?? '';

    final rightColumnWidgets = [
      // Tax & Statutory info
      _SectionHeader('Tax & Statutory'),
      _InfoRow(Icons.receipt_long_outlined, taxLabel, gstin, isMono: true),
      _InfoRow(Icons.credit_card_outlined, 'PAN', pan, isMono: true),
      _InfoRow(Icons.account_balance_outlined, 'GST Treatment', gstTreatment),
      if (msmeRegistered)
        _InfoRow(Icons.verified_outlined, 'MSME Registration No', msmeRegNo ?? 'Registered', isMono: true),
      if (tdsApplicable)
        _InfoRow(Icons.percent_outlined, 'TDS Configuration',
            'Section $tdsSection @ ${tdsRate ?? 1.0}%'),
      KSpacing.vGapMd,

      // Bank Details
      if (bankName != null || bankAccountNo != null || bankIfsc != null || upiId != null) ...[
        _SectionHeader('Bank & Payout Details'),
        _InfoRow(Icons.account_balance_outlined, 'Bank Name', bankName),
        _InfoRow(Icons.pin_outlined, 'Account Number', bankAccountNo, isMono: true),
        _InfoRow(Icons.code_outlined, 'IFSC Code', bankIfsc, isMono: true),
        _InfoRow(Icons.payment_outlined, 'UPI ID / VPA', upiId, isMono: true),
        KSpacing.vGapMd,
      ],

      // Financial Terms
      _SectionHeader('Financial Setup'),
      _InfoRow(
        Icons.account_balance_wallet_outlined,
        'Opening Balance',
        null,
        valueWidget: KMoney(openingBalance, size: KMoneySize.small),
      ),
      _InfoRow(
        Icons.security_outlined,
        'Credit Limit',
        null,
        valueWidget: KMoney(creditLimit, size: KMoneySize.small),
      ),
      _InfoRow(
        Icons.calendar_today_outlined,
        'Payment Terms',
        paymentTermsDays != null
            ? (paymentTermsDays == 0
                ? 'Due on Receipt'
                : 'Net ${paymentTermsDays.toInt()} days')
            : 'Net 30 days',
      ),
      if (notes != null && notes.isNotEmpty) ...[
        KSpacing.vGapMd,
        _SectionHeader('Notes'),
        Text(notes, style: KTypography.bodyMedium),
      ],
      if (contactId.isNotEmpty) ...[
        KSpacing.vGapMd,
        KCustomFieldsCard(
          entityType: 'CONTACT',
          entityId: contactId,
        ),
      ],

      if (onEnableSupplier != null) ...[
        KSpacing.vGapLg,
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.local_shipping_outlined, color: KColors.primary),
                  SizedBox(width: KSpacing.md),
                  Text('Procurement Supplier Role', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              KSpacing.vGapSm,
              const Text(
                'Enable this vendor in Purchase Orders and Goods Receipts.',
                style: TextStyle(fontSize: 12, color: KColors.textSecondary),
              ),
              KSpacing.vGapMd,
              KButton(
                label: 'Enable Supplier',
                variant: KButtonVariant.outlined,
                icon: Icons.add_business_outlined,
                onPressed: onEnableSupplier,
                fullWidth: true,
              ),
            ],
          ),
        ),
      ],
    ];

    return SingleChildScrollView(
      padding: KSpacing.pagePadding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 960) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: leftColumnWidgets,
                  ),
                ),
                KSpacing.hGapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: rightColumnWidgets,
                  ),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...leftColumnWidgets,
              KSpacing.vGapMd,
              ...rightColumnWidgets,
            ],
          );
        },
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
                  style: KTypography.labelMedium.copyWith(color: KColors.primary),
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
  final Widget? valueWidget;
  final bool isMono;

  const _InfoRow(
    this.icon,
    this.label,
    this.value, {
    this.valueWidget,
    this.isMono = false,
  });

  @override
  Widget build(BuildContext context) {
    if (valueWidget == null && (value == null || value!.isEmpty)) {
      return const SizedBox.shrink();
    }
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
                if (valueWidget != null)
                  valueWidget!
                else
                  Text(
                    value!,
                    style: isMono
                        ? KTypography.mono(fontSize: 13)
                        : KTypography.bodyMedium,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
