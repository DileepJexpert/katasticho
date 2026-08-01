import 'package:flutter/material.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';

/// A repeatable, in-product manual QA path for the private-label FMCG flow.
///
/// This is intentionally static. It gives a tester the correct business order
/// without coupling the guide to test data or making test actions in the app.
class TestingGuideScreen extends StatelessWidget {
  const TestingGuideScreen({super.key});

  static const _sections = <_GuideSection>[
    _GuideSection(
      title: '1. Start with the demo organisation',
      purpose: 'Verify the tenant and roles before creating business data.',
      steps: [
        'Confirm business type DISTRIBUTOR and industry FMCG_DISTRIBUTOR.',
        'Confirm Inventory, Purchases, Sales, Accounting, Reports and Field Sales are enabled.',
        'Use separate logins for Owner, Admin, Accountant, Salesman and Viewer.',
      ],
      checkpoint: 'The login user must never be shared between partners.',
    ),
    _GuideSection(
      title: '2. Set up capital and accounting',
      purpose: 'Create the opening financial position before transactions.',
      steps: [
        'Create Partner A, Partner B and Partner C equity accounts if they do not exist.',
        'Post one journal: debit Bank Account Rs 3,00,000 and credit each partner Rs 1,00,000.',
        'Open the journal detail and verify it is POSTED and balanced.',
      ],
      checkpoint: 'Trial Balance must show total debit equal to total credit.',
    ),
    _GuideSection(
      title: '3. Create suppliers, customers and items',
      purpose: 'Build the private-label FMCG master data.',
      steps: [
        'Create Badi Foods, Grain Foods and Vinegar Foods as suppliers.',
        'Create kirana, retail and wholesale customers with cash and credit terms.',
        'Create Badi, Dal Mix, Dalia, Vinegar, Sattu and Besan items.',
        'For loose goods use KG as the selling unit and BAG as the purchase unit.',
        'Example: 1 BAG = 50 KG, purchase Rs 2,500 per bag, sale Rs 55 per KG.',
      ],
      checkpoint: 'Verify SKU, HSN, GST, price, reorder level and batch settings.',
    ),
    _GuideSection(
      title: '4. Purchase and receive stock',
      purpose: 'Prove that supplier stock enters inventory only on receipt.',
      steps: [
        'Create purchase orders for the three suppliers.',
        'Create a Goods Receipt from a purchase order.',
        'Enter actual quantity, warehouse, batch, expiry, rack and landed charges.',
        'Save as draft and confirm stock has not increased.',
        'Receive stock once, then try again to confirm no duplicate movement.',
        'Create the supplier bill and record a full or partial supplier payment.',
      ],
      checkpoint: 'Verify stock, batch, landed cost, payable and purchase reports.',
    ),
    _GuideSection(
      title: '5. Sell for cash and credit',
      purpose: 'Test the complete order-to-cash flow.',
      steps: [
        'Create a cash Sales Order, confirm it and create a Delivery Challan.',
        'Dispatch the actual quantity and create the Sales Invoice.',
        'Record full customer payment and verify outstanding becomes zero.',
        'Create a credit sale, post the invoice and record partial collection.',
        'Complete the collection later and verify customer ageing.',
      ],
      checkpoint: 'Stock decreases once; revenue, GST, COGS and receivable are correct.',
    ),
    _GuideSection(
      title: '6. Test expenses and audit history',
      purpose: 'Verify that partner changes are attributable and recoverable.',
      steps: [
        'Create a transport expense of Rs 1,000 as Accountant.',
        'With another authorised user, change it to Rs 1,500.',
        'Open Accounting > Audit Trail and filter EXPENSE.',
        'Verify the old value, new value, user and timestamp.',
        'Open the journals and verify the old journal was reversed and the new one posted.',
      ],
      checkpoint: 'Posted journal rows are not edited; corrections use reversal entries.',
    ),
    _GuideSection(
      title: '7. Configure field sales',
      purpose: 'Prepare daily market visits for the salesman app.',
      steps: [
        'Create beats and add customers in visit order.',
        'Create routes and attach beats by day.',
        'Assign Salesman 1 and Salesman 2 to different routes.',
        'Start today\'s route execution from ERP.',
        'In the field app, check in, record order, collect payment, add notes and check out.',
      ],
      checkpoint: 'A salesman sees and edits only the execution assigned to that user.',
    ),
    _GuideSection(
      title: '8. Tracking, expenses and day close',
      purpose: 'Reconcile the salesman\'s daily activity.',
      steps: [
        'Allow location permission and verify Live Tracking from ERP.',
        'Record field travel or food expense and customer collections.',
        'Complete the route and submit Day Close.',
        'Enter opening cash, collections, expenses, closing cash and deposit.',
        'Approve or reject Day Close as Admin and submit the daily report.',
      ],
      checkpoint: 'Opening cash + collections - expenses equals expected closing cash.',
    ),
    _GuideSection(
      title: '9. Permissions and negative tests',
      purpose: 'Prove that users cannot cross business boundaries.',
      steps: [
        'Viewer must not create, edit, post, receive, dispatch or approve.',
        'Salesman 1 must not access Salesman 2\'s visits or collections.',
        'Try receiving twice, dispatching more than stock and posting a bill twice.',
        'Try selling an unavailable or expired batch.',
        'Refresh or retry requests and check for duplicate stock or journals.',
      ],
      checkpoint: 'Invalid operations fail clearly and do not partially post.',
    ),
    _GuideSection(
      title: '10. Finish with reconciliation',
      purpose: 'Compare operational totals with accounting totals.',
      steps: [
        'Opening stock + receipts - sales equals closing stock.',
        'Supplier bills - vendor payments equals supplier outstanding.',
        'Sales invoices - customer receipts equals customer outstanding.',
        'Warehouse stock + van stock equals total owned stock.',
        'Revenue - COGS - approved expenses equals expected contribution.',
      ],
      checkpoint: 'Every posted journal has one business reference and no duplicates.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Testing Guide'),
        actions: [
          IconButton(
            tooltip: 'Testing guide is read-only',
            onPressed: null,
            icon: Icon(Icons.checklist_rounded, color: colors.primary),
          ),
        ],
      ),
      body: ListView(
        padding: KSpacing.pagePaddingLg,
        children: [
          KCard(
            leading: const Icon(Icons.route_rounded, color: KColors.primary),
            title: 'Private-label FMCG distributor',
            subtitle: 'Manufacturer -> purchase -> warehouse -> market visit -> collection',
            child: Text(
              'Use this guide after a fresh demo reset. Complete the sections in order and verify each checkpoint before continuing.',
              style: KTypography.bodyMedium.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
          KSpacing.vGapLg,
          KCard(
            title: 'Demo logins',
            subtitle: 'Password for every demo user: Demo@1234',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _LoginRow('Demo Owner', '9000000001', 'OWNER'),
                _LoginRow('Demo Admin', '9000000002', 'ADMIN'),
                _LoginRow('Demo Accountant', '9000000003', 'ACCOUNTANT'),
                _LoginRow('Demo Salesman', '9000000005', 'OPERATOR / Field app'),
                _LoginRow('Demo Viewer', '9000000007', 'VIEWER'),
              ],
            ),
          ),
          KSpacing.vGapLg,
          Text('Test sequence', style: KTypography.h2),
          KSpacing.vGapSm,
          ..._sections.map((section) => _GuideCard(section: section)),
          KSpacing.vGapMd,
          KCard(
            leading: const Icon(Icons.info_outline_rounded, color: KColors.warning),
            title: 'Outsourced manufacturing boundary',
            child: Text(
              'For this test, buy finished goods from each external manufacturer. Raw material issue, outsourced conversion, yield, wastage and finished-batch cost roll-up are not represented by the primary distributor flow yet.',
              style: KTypography.bodyMedium.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  final _GuideSection section;

  const _GuideCard({required this.section});

  @override
  Widget build(BuildContext context) {
    return KCard(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(section.title, style: KTypography.h3),
        subtitle: Text(section.purpose, style: KTypography.bodySmall),
        children: [
          const Divider(height: KSpacing.lg),
          ...section.steps.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: KSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${entry.key + 1}.', style: KTypography.mono()),
                      KSpacing.hGapSm,
                      Expanded(child: Text(entry.value, style: KTypography.bodyMedium)),
                    ],
                  ),
                ),
              ),
          KCard(
            margin: const EdgeInsets.only(top: KSpacing.xs),
            padding: const EdgeInsets.all(KSpacing.sm),
            backgroundColor: KColors.success.withValues(alpha: 0.06),
            borderColor: KColors.success.withValues(alpha: 0.35),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.verified_outlined, size: 18, color: KColors.success),
                KSpacing.hGapSm,
                Expanded(child: Text(section.checkpoint, style: KTypography.bodySmall)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginRow extends StatelessWidget {
  final String name;
  final String phone;
  final String role;

  const _LoginRow(this.name, this.phone, this.role);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(name, style: KTypography.labelLarge)),
          Text(phone, style: KTypography.mono()),
          KSpacing.hGapMd,
          SizedBox(width: 150, child: Text(role, style: KTypography.bodySmall)),
        ],
      ),
    );
  }
}

class _GuideSection {
  final String title;
  final String purpose;
  final List<String> steps;
  final String checkpoint;

  const _GuideSection({
    required this.title,
    required this.purpose,
    required this.steps,
    required this.checkpoint,
  });
}
