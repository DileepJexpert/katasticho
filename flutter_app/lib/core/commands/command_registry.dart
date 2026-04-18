import 'package:flutter/material.dart';
import '../widgets/k_command_palette.dart';
import '../../routing/app_router.dart';

/// Static catalogue of commands surfaced by the Cmd/Ctrl+K palette.
///
/// Action commands (e.g. "New Invoice") are wired by passing the current
/// router/context through [navigationCommands] — the route is enough.
List<KCommand> buildAppCommands() {
  return const [
    // ── Navigation ─────────────────────────────────────────────────
    KCommand(
      label: 'Dashboard',
      icon: Icons.dashboard_rounded,
      section: 'Navigate',
      route: Routes.dashboard,
      keywords: ['home', 'overview'],
    ),
    KCommand(
      label: 'Invoices',
      icon: Icons.receipt_long_rounded,
      section: 'Navigate',
      route: Routes.invoices,
      keywords: ['ar', 'sales', 'receivables'],
    ),
    KCommand(
      label: 'Estimates',
      icon: Icons.request_quote_rounded,
      section: 'Navigate',
      route: Routes.estimates,
      keywords: ['quotes', 'proposals'],
    ),
    KCommand(
      label: 'Recurring Invoices',
      icon: Icons.autorenew_rounded,
      section: 'Navigate',
      route: Routes.recurringInvoices,
      keywords: ['subscription', 'profile'],
    ),
    KCommand(
      label: 'Credit Notes',
      icon: Icons.note_alt_rounded,
      section: 'Navigate',
      route: Routes.creditNotes,
      keywords: ['refund', 'cn'],
    ),
    KCommand(
      label: 'Bills',
      icon: Icons.receipt_rounded,
      section: 'Navigate',
      route: Routes.bills,
      keywords: ['ap', 'purchases', 'payable'],
    ),
    KCommand(
      label: 'Vendor Payments',
      icon: Icons.payments_rounded,
      section: 'Navigate',
      route: Routes.vendorPayments,
      keywords: ['ap', 'pay vendor'],
    ),
    KCommand(
      label: 'Vendor Credits',
      icon: Icons.note_alt_rounded,
      section: 'Navigate',
      route: Routes.vendorCredits,
      keywords: ['ap', 'refund'],
    ),
    KCommand(
      label: 'Expenses',
      icon: Icons.payments_rounded,
      section: 'Navigate',
      route: Routes.expenses,
    ),
    KCommand(
      label: 'Contacts',
      icon: Icons.people_rounded,
      section: 'Navigate',
      route: Routes.contacts,
      keywords: ['customers', 'vendors'],
    ),
    KCommand(
      label: 'Items',
      icon: Icons.inventory_2_rounded,
      section: 'Navigate',
      route: Routes.items,
      keywords: ['products', 'inventory', 'stock'],
    ),
    KCommand(
      label: 'Stock Receipts',
      icon: Icons.local_shipping_rounded,
      section: 'Navigate',
      route: Routes.stockReceipts,
      keywords: ['grn', 'goods received'],
    ),
    KCommand(
      label: 'Price Lists',
      icon: Icons.sell_rounded,
      section: 'Navigate',
      route: Routes.priceLists,
      keywords: ['pricing', 'tier'],
    ),
    KCommand(
      label: 'POS',
      icon: Icons.point_of_sale_rounded,
      section: 'Navigate',
      route: Routes.pos,
      keywords: ['point of sale', 'till'],
    ),
    KCommand(
      label: 'AI Chat',
      icon: Icons.auto_awesome_rounded,
      section: 'Navigate',
      route: Routes.aiChat,
      keywords: ['assistant', 'ai'],
    ),
    KCommand(
      label: 'GST Dashboard',
      icon: Icons.account_balance_rounded,
      section: 'Navigate',
      route: Routes.gst,
      keywords: ['tax', 'india', 'gstr'],
    ),

    // ── Reports ────────────────────────────────────────────────────
    KCommand(
      label: 'Reports Hub',
      icon: Icons.bar_chart_rounded,
      section: 'Reports',
      route: Routes.reports,
    ),
    KCommand(
      label: 'Trial Balance',
      icon: Icons.balance_rounded,
      section: 'Reports',
      route: Routes.trialBalance,
      subtitle: 'All ledger debits and credits',
    ),
    KCommand(
      label: 'Profit & Loss',
      icon: Icons.show_chart_rounded,
      section: 'Reports',
      route: Routes.profitLoss,
      subtitle: 'Income statement',
      keywords: ['p&l', 'pnl', 'income'],
    ),
    KCommand(
      label: 'Balance Sheet',
      icon: Icons.account_tree_rounded,
      section: 'Reports',
      route: Routes.balanceSheet,
    ),
    KCommand(
      label: 'General Ledger',
      icon: Icons.menu_book_rounded,
      section: 'Reports',
      route: Routes.generalLedger,
      keywords: ['gl'],
    ),
    KCommand(
      label: 'AR Ageing',
      icon: Icons.hourglass_bottom_rounded,
      section: 'Reports',
      route: Routes.ageingReport,
      subtitle: 'Receivables by age bucket',
    ),
    KCommand(
      label: 'AP Ageing',
      icon: Icons.hourglass_bottom_rounded,
      section: 'Reports',
      route: Routes.apAgeingReport,
      subtitle: 'Payables by age bucket',
    ),

    // ── Create ─────────────────────────────────────────────────────
    KCommand(
      label: 'New Invoice',
      icon: Icons.add_rounded,
      section: 'Create',
      route: Routes.invoiceCreate,
      keywords: ['create invoice', 'new sale'],
    ),
    KCommand(
      label: 'New Estimate',
      icon: Icons.add_rounded,
      section: 'Create',
      route: Routes.estimateCreate,
      keywords: ['quote', 'proposal'],
    ),
    KCommand(
      label: 'New Bill',
      icon: Icons.add_rounded,
      section: 'Create',
      route: Routes.billCreate,
      keywords: ['purchase'],
    ),
    KCommand(
      label: 'New Expense',
      icon: Icons.add_rounded,
      section: 'Create',
      route: Routes.expenseCreate,
    ),
    KCommand(
      label: 'New Contact',
      icon: Icons.person_add_rounded,
      section: 'Create',
      route: Routes.contactCreate,
      keywords: ['customer', 'vendor'],
    ),
    KCommand(
      label: 'New Item',
      icon: Icons.add_rounded,
      section: 'Create',
      route: Routes.itemCreate,
      keywords: ['product'],
    ),
    KCommand(
      label: 'New Credit Note',
      icon: Icons.add_rounded,
      section: 'Create',
      route: Routes.creditNoteCreate,
      keywords: ['refund'],
    ),
    KCommand(
      label: 'New Vendor Credit',
      icon: Icons.add_rounded,
      section: 'Create',
      route: Routes.vendorCreditCreate,
    ),

    // ── Settings ───────────────────────────────────────────────────
    KCommand(
      label: 'Settings',
      icon: Icons.settings_rounded,
      section: 'Settings',
      route: Routes.settings,
    ),
    KCommand(
      label: 'Default Accounts',
      icon: Icons.tune_rounded,
      section: 'Settings',
      route: Routes.defaultAccounts,
    ),
    KCommand(
      label: 'Tax Account Mappings',
      icon: Icons.receipt_long_rounded,
      section: 'Settings',
      route: Routes.taxAccountMappings,
    ),
  ];
}
