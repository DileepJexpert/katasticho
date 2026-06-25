import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api/api_client.dart';
import '../core/auth/business_capabilities.dart';
import '../core/auth/auth_state.dart';
import '../core/auth/nav_overrides.dart';
import '../core/intl/country_currency.dart';
import '../core/commands/command_registry.dart';
import '../core/shell/shell_providers.dart';
import '../core/shortcuts/k_shortcuts.dart';
import '../core/theme/k_colors.dart';
import '../core/theme/k_spacing.dart';
import '../core/widgets/k_assistant_fab.dart';
import '../core/widgets/k_command_palette.dart';
import '../core/widgets/k_quick_create_menu.dart';
import '../core/widgets/k_shortcut_help_overlay.dart';
import '../core/widgets/k_top_bar.dart';
import '../core/widgets/theme_mode_switcher.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/dashboard/data/dashboard_repository.dart';
import '../features/notifications/data/notification_repository.dart';
import 'app_router.dart';

/// Navigation item definition.
///
/// `id` (optional) is a stable string identifier used by the per-org disable
/// list (`org_settings.nav.disabled`). Entries without an `id` cannot be
/// disabled by an org admin — that's fine for tabs / sub-items that should
/// always be reachable.
///
/// `roles` / `industries` / `countries` (optional) are additive filters
/// applied on top of the capability check. Null = no constraint (default).
/// Non-null = only the listed values pass. PLATFORM_ADMIN bypasses these.
class NavItem {
  final String? id;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;
  final List<String>? roles;
  final List<String>? industries;
  final List<String>? countries;

  const NavItem({
    this.id,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
    this.roles,
    this.industries,
    this.countries,
  });
}

// ── Top-level nav items used by compact tablet/mobile shells ──
const _baseTopNavItems = [
  NavItem(
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    activeIcon: Icons.dashboard_rounded,
    route: Routes.dashboard,
  ),
  NavItem(
    label: 'AI',
    icon: Icons.auto_awesome_outlined,
    activeIcon: Icons.auto_awesome_rounded,
    route: Routes.aiChat,
  ),
  NavItem(
    label: 'POS',
    icon: Icons.point_of_sale_outlined,
    activeIcon: Icons.point_of_sale_rounded,
    route: Routes.pos,
  ),
  NavItem(
    label: 'Contacts',
    icon: Icons.people_outline_rounded,
    activeIcon: Icons.people_rounded,
    route: Routes.contacts,
  ),
  NavItem(
    label: 'Settings',
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings_rounded,
    route: Routes.settings,
  ),
];

const _dashboardNavItem = NavItem(
  id: 'dashboard',
  label: 'Dashboard',
  icon: Icons.dashboard_outlined,
  activeIcon: Icons.dashboard_rounded,
  route: Routes.dashboard,
);

const _caConsoleNavItem = NavItem(
  id: 'ca_console',
  label: 'CA Console',
  icon: Icons.account_balance_outlined,
  activeIcon: Icons.account_balance_rounded,
  route: Routes.caConsole,
);

const _aiCommandCenterNavItem = NavItem(
  id: 'ai',
  label: 'AI Command Center',
  icon: Icons.auto_awesome_outlined,
  activeIcon: Icons.auto_awesome_rounded,
  route: Routes.aiChat,
);

const _posNavItem = NavItem(
  id: 'pos',
  label: 'POS',
  icon: Icons.point_of_sale_outlined,
  activeIcon: Icons.point_of_sale_rounded,
  route: Routes.pos,
);

const _contactsNavItem = NavItem(
  id: 'contacts',
  label: 'Contacts',
  icon: Icons.people_outline_rounded,
  activeIcon: Icons.people_rounded,
  route: Routes.contacts,
);

const _settingsNavItem = NavItem(
  id: 'settings',
  label: 'Settings',
  icon: Icons.settings_outlined,
  activeIcon: Icons.settings_rounded,
  route: Routes.settings,
);

/// A group of nav items that collapse into a popup overlay.
///
/// `id` (optional) is a stable string identifier used by the per-org disable
/// list. Disabling a group hides the whole group + every child.
class NavGroup {
  final String? id;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final List<NavItem> children;
  final List<String>? roles;
  final List<String>? industries;
  final List<String>? countries;
  const NavGroup({
    this.id,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.children,
    this.roles,
    this.industries,
    this.countries,
  });
}

const _salesGroup = NavGroup(
  id: 'sales',
  label: 'Sales',
  icon: Icons.storefront_outlined,
  activeIcon: Icons.storefront_rounded,
  children: [
    NavItem(
        id: 'sales.invoices',
        label: 'Invoices',
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long_rounded,
        route: Routes.invoices),
    NavItem(
        id: 'sales.estimates',
        label: 'Estimates / Quotes',
        icon: Icons.request_quote_outlined,
        activeIcon: Icons.request_quote_rounded,
        route: Routes.estimates),
    NavItem(
        id: 'sales.sales_orders',
        label: 'Sales Orders',
        icon: Icons.assignment_outlined,
        activeIcon: Icons.assignment_rounded,
        route: Routes.salesOrders),
    NavItem(
        id: 'sales.delivery_challans',
        label: 'Delivery Challans',
        icon: Icons.local_shipping_outlined,
        activeIcon: Icons.local_shipping_rounded,
        route: Routes.deliveryChallans),
    NavItem(
        id: 'sales.proof_of_delivery',
        label: 'Proof of Delivery',
        icon: Icons.assignment_turned_in_outlined,
        activeIcon: Icons.assignment_turned_in_rounded,
        route: Routes.proofOfDelivery),
    NavItem(
        id: 'sales.receipts',
        label: 'Receipts',
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long_rounded,
        route: Routes.salesReceipts),
    NavItem(
        id: 'sales.credit_notes',
        label: 'Credit Notes',
        icon: Icons.note_alt_outlined,
        activeIcon: Icons.note_alt_rounded,
        route: Routes.creditNotes),
    NavItem(
        id: 'sales.customer_receipts',
        label: 'Customer Receipts',
        icon: Icons.payments_outlined,
        activeIcon: Icons.payments_rounded,
        route: Routes.customerReceipts),
    NavItem(
        id: 'sales.receivables',
        label: 'Receivables',
        icon: Icons.account_balance_wallet_outlined,
        activeIcon: Icons.account_balance_wallet_rounded,
        route: Routes.ageingReport),
    NavItem(
        id: 'sales.credit_reminders',
        label: 'Credit Reminders',
        icon: Icons.notification_important_outlined,
        activeIcon: Icons.notification_important_rounded,
        route: Routes.creditReminders),
    NavItem(
        id: 'sales.recurring',
        label: 'Recurring',
        icon: Icons.autorenew_outlined,
        activeIcon: Icons.autorenew_rounded,
        route: Routes.recurringInvoices),
  ],
);

const _purchasesGroup = NavGroup(
  id: 'purchases',
  label: 'Purchases',
  icon: Icons.shopping_cart_outlined,
  activeIcon: Icons.shopping_cart_rounded,
  children: [
    NavItem(
        id: 'purchases.suppliers',
        label: 'Suppliers',
        icon: Icons.local_shipping_outlined,
        activeIcon: Icons.local_shipping_rounded,
        route: Routes.suppliers),
    NavItem(
        id: 'purchases.purchase_orders',
        label: 'Purchase Orders',
        icon: Icons.shopping_cart_outlined,
        activeIcon: Icons.shopping_cart_rounded,
        route: Routes.purchaseOrders),
    NavItem(
        id: 'purchases.goods_receipts',
        label: 'Goods Receipts',
        icon: Icons.local_shipping_outlined,
        activeIcon: Icons.local_shipping_rounded,
        route: Routes.stockReceipts),
    NavItem(
        id: 'purchases.bills',
        label: 'Bills',
        icon: Icons.receipt_outlined,
        activeIcon: Icons.receipt_rounded,
        route: Routes.bills),
    NavItem(
        id: 'purchases.three_way_match',
        label: '3-Way Match',
        icon: Icons.fact_check_outlined,
        activeIcon: Icons.fact_check_rounded,
        route: Routes.threeWayMatch),
    NavItem(
        id: 'purchases.vendor_payments',
        label: 'Vendor Payments',
        icon: Icons.payments_outlined,
        activeIcon: Icons.payments_rounded,
        route: Routes.vendorPayments),
    NavItem(
        id: 'purchases.vendor_credits',
        label: 'Vendor Credits',
        icon: Icons.note_alt_outlined,
        activeIcon: Icons.note_alt_rounded,
        route: Routes.vendorCredits),
    NavItem(
        id: 'purchases.expenses',
        label: 'Expenses',
        icon: Icons.payments_outlined,
        activeIcon: Icons.payments_rounded,
        route: Routes.expenses),
    NavItem(
        id: 'purchases.payables',
        label: 'Payables',
        icon: Icons.account_balance_wallet_outlined,
        activeIcon: Icons.account_balance_wallet_rounded,
        route: Routes.payables),
    NavItem(
        id: 'purchases.rfq',
        label: 'RFQ',
        icon: Icons.request_quote_outlined,
        activeIcon: Icons.request_quote,
        route: Routes.rfq),
    NavItem(
        id: 'purchases.rate_contracts',
        label: 'Rate Contracts',
        icon: Icons.handshake_outlined,
        activeIcon: Icons.handshake,
        route: Routes.rateContracts),
  ],
);

const _inventoryGroup = NavGroup(
  id: 'inventory',
  label: 'Inventory',
  icon: Icons.inventory_2_outlined,
  activeIcon: Icons.inventory_2_rounded,
  children: [
    NavItem(
        id: 'inventory.items',
        label: 'Items',
        icon: Icons.inventory_2_outlined,
        activeIcon: Icons.inventory_2_rounded,
        route: Routes.items),
    NavItem(
        id: 'inventory.item_groups',
        label: 'Item Groups',
        icon: Icons.category_outlined,
        activeIcon: Icons.category_rounded,
        route: Routes.itemGroups),
    NavItem(
        id: 'inventory.stock_summary',
        label: 'Stock Summary',
        icon: Icons.summarize_outlined,
        activeIcon: Icons.summarize_rounded,
        route: '/reports/operational/stock-summary'),
    NavItem(
        id: 'inventory.stock_movements',
        label: 'Stock Movements',
        icon: Icons.swap_vert_outlined,
        activeIcon: Icons.swap_vert_rounded,
        route: '/reports/operational/stock-movement'),
    NavItem(
        id: 'inventory.reorder',
        label: 'Reorder Alerts',
        icon: Icons.shopping_cart_outlined,
        activeIcon: Icons.shopping_cart_rounded,
        route: Routes.reorder),
    NavItem(
        id: 'inventory.shortbook',
        label: 'Shortbook',
        icon: Icons.playlist_add_check_outlined,
        activeIcon: Icons.playlist_add_check_rounded,
        route: Routes.shortbook),
    NavItem(
        id: 'inventory.near_expiry',
        label: 'Expiry Alerts',
        icon: Icons.timer_outlined,
        activeIcon: Icons.timer_rounded,
        route: Routes.nearExpiry),
    NavItem(
        id: 'inventory.rack_locations',
        label: 'Rack Locations',
        icon: Icons.grid_view_outlined,
        activeIcon: Icons.grid_view_rounded,
        route: Routes.rackLocations),
    NavItem(
        id: 'inventory.hsn_master',
        label: 'HSN / GST Rates',
        icon: Icons.percent_outlined,
        activeIcon: Icons.percent_rounded,
        route: Routes.hsnMaster),
    NavItem(
        id: 'inventory.stock_counts',
        label: 'Stock Counts',
        icon: Icons.fact_check_outlined,
        activeIcon: Icons.fact_check_rounded,
        route: Routes.stockCounts),
    NavItem(
        id: 'inventory.transfer_orders',
        label: 'Transfer Orders',
        icon: Icons.swap_horiz_outlined,
        activeIcon: Icons.swap_horiz_rounded,
        route: Routes.transferOrders),
    NavItem(
        id: 'inventory.picklists',
        label: 'Picklists',
        icon: Icons.checklist_outlined,
        activeIcon: Icons.checklist_rounded,
        route: Routes.picklists),
    NavItem(
        id: 'inventory.price_lists',
        label: 'Price Lists',
        icon: Icons.sell_outlined,
        activeIcon: Icons.sell_rounded,
        route: Routes.priceLists),
    NavItem(
        id: 'inventory.schemes',
        label: 'Schemes',
        icon: Icons.local_offer_outlined,
        activeIcon: Icons.local_offer_rounded,
        route: Routes.schemes),
    NavItem(
        id: 'inventory.item_import',
        label: 'Import Items',
        icon: Icons.upload_file_outlined,
        activeIcon: Icons.upload_file_rounded,
        route: Routes.itemImport),
    NavItem(
        id: 'inventory.warehouses',
        label: 'Warehouses',
        icon: Icons.warehouse_outlined,
        activeIcon: Icons.warehouse_rounded,
        route: Routes.warehouses),
    NavItem(
        id: 'inventory.warehouse_zones',
        label: 'Warehouse Zones',
        icon: Icons.grid_view_outlined,
        activeIcon: Icons.grid_view_rounded,
        route: Routes.warehouseZones),
    NavItem(
        id: 'inventory.batch_trace',
        label: 'Batch Trace',
        icon: Icons.account_tree_outlined,
        activeIcon: Icons.account_tree_rounded,
        route: Routes.batchTrace),
    NavItem(
        id: 'inventory.batch_recall',
        label: 'Batch Recall',
        icon: Icons.report_outlined,
        activeIcon: Icons.report_rounded,
        route: Routes.batchRecall),
  ],
);

const _bankingGroup = NavGroup(
  id: 'banking',
  label: 'Banking',
  icon: Icons.account_balance_outlined,
  activeIcon: Icons.account_balance_rounded,
  children: [
    NavItem(
      id: 'banking.accounts',
      label: 'Bank Accounts',
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet_rounded,
      route: Routes.bankAccounts,
    ),
    NavItem(
      id: 'banking.reconciliation',
      label: 'Reconciliation',
      icon: Icons.compare_arrows_outlined,
      activeIcon: Icons.compare_arrows_rounded,
      route: Routes.bankReconciliation,
    ),
  ],
);

const _accountingGroup = NavGroup(
  id: 'accounting',
  label: 'Accounting',
  icon: Icons.account_balance_outlined,
  activeIcon: Icons.account_balance_rounded,
  children: [
    NavItem(
        id: 'accounting.dashboard',
        label: 'Accounting Dashboard',
        icon: Icons.analytics_outlined,
        activeIcon: Icons.analytics_rounded,
        route: '/accounting/dashboard'),
    NavItem(
        id: 'accounting.guided_transaction',
        label: 'Create Transaction',
        icon: Icons.auto_awesome_motion_outlined,
        activeIcon: Icons.auto_awesome_motion_rounded,
        route: Routes.guidedTransactionCreate),
    NavItem(
        id: 'accounting.chart_of_accounts',
        label: 'Chart of Accounts',
        icon: Icons.account_balance_outlined,
        activeIcon: Icons.account_balance_rounded,
        route: Routes.chartOfAccounts),
    NavItem(
        id: 'accounting.journal_entries',
        label: 'Manual Journals',
        icon: Icons.menu_book_outlined,
        activeIcon: Icons.menu_book_rounded,
        route: Routes.journalEntries),
    NavItem(
        id: 'accounting.credit_ledger',
        label: 'Credit Ledger',
        icon: Icons.menu_book_outlined,
        activeIcon: Icons.menu_book_rounded,
        route: Routes.creditLedger),
    NavItem(
        id: 'accounting.period_close',
        label: 'Period Close',
        icon: Icons.event_busy_outlined,
        activeIcon: Icons.event_busy_rounded,
        route: Routes.periodClose),
    NavItem(
        id: 'accounting.fixed_assets',
        label: 'Fixed Assets',
        icon: Icons.precision_manufacturing_outlined,
        activeIcon: Icons.precision_manufacturing,
        route: Routes.fixedAssets),
    NavItem(
        id: 'accounting.amortization',
        label: 'Amortization',
        icon: Icons.schedule_outlined,
        activeIcon: Icons.schedule,
        route: Routes.amortization),
  ],
);

const _reportsGroup = NavGroup(
  id: 'reports',
  label: 'Reports',
  icon: Icons.bar_chart_outlined,
  activeIcon: Icons.bar_chart_rounded,
  children: [
    NavItem(
        id: 'reports.hub',
        label: 'Reports Hub',
        icon: Icons.bar_chart_outlined,
        activeIcon: Icons.bar_chart_rounded,
        route: Routes.reports),
    NavItem(
        id: 'reports.trial_balance',
        label: 'Trial Balance',
        icon: Icons.balance_outlined,
        activeIcon: Icons.balance_rounded,
        route: Routes.trialBalance),
    NavItem(
        id: 'reports.profit_loss',
        label: 'Profit & Loss',
        icon: Icons.trending_up_outlined,
        activeIcon: Icons.trending_up_rounded,
        route: Routes.profitLoss),
    NavItem(
        id: 'reports.balance_sheet',
        label: 'Balance Sheet',
        icon: Icons.account_balance_outlined,
        activeIcon: Icons.account_balance_rounded,
        route: Routes.balanceSheet),
    NavItem(
        id: 'reports.general_ledger',
        label: 'General Ledger',
        icon: Icons.menu_book_outlined,
        activeIcon: Icons.menu_book_rounded,
        route: Routes.generalLedger),
    NavItem(
        id: 'reports.ar_ageing',
        label: 'AR Ageing',
        icon: Icons.account_balance_wallet_outlined,
        activeIcon: Icons.account_balance_wallet_rounded,
        route: Routes.ageingReport),
    NavItem(
        id: 'reports.ap_ageing',
        label: 'AP Ageing',
        icon: Icons.account_balance_wallet_outlined,
        activeIcon: Icons.account_balance_wallet_rounded,
        route: Routes.apAgeingReport),
    NavItem(
        id: 'reports.sales_register',
        label: 'Sales Register',
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long_rounded,
        route: '/reports/operational/sales-register'),
    NavItem(
        id: 'reports.pending_dispatch',
        label: 'Pending Dispatch',
        icon: Icons.local_shipping_outlined,
        activeIcon: Icons.local_shipping_rounded,
        route: '/reports/operational/pending-dispatch'),
    NavItem(
        id: 'reports.challan_not_invoiced',
        label: 'Challan Not Invoiced',
        icon: Icons.assignment_late_outlined,
        activeIcon: Icons.assignment_late_rounded,
        route: '/reports/operational/challan-not-invoiced'),
    NavItem(
        id: 'reports.purchase_register',
        label: 'Purchase Register',
        icon: Icons.receipt_outlined,
        activeIcon: Icons.receipt_rounded,
        route: '/reports/operational/purchase-register'),
    NavItem(
        id: 'reports.daily_sales',
        label: 'Daily Sales',
        icon: Icons.today_outlined,
        activeIcon: Icons.today_rounded,
        route: '/reports/operational/daily-sales'),
  ],
);

/// HR & Payroll — merged into one ERP-canonical group. Order: employee
/// master + self-service first, then HR sub-modules, then payroll runs.
const _hrPayrollGroup = NavGroup(
  id: 'hr_payroll',
  label: 'HR & Payroll',
  icon: Icons.groups_outlined,
  activeIcon: Icons.groups_rounded,
  children: [
    NavItem(
        id: 'payroll.employees',
        label: 'Employees',
        icon: Icons.badge_outlined,
        activeIcon: Icons.badge_rounded,
        route: Routes.payrollEmployees),
    NavItem(
        id: 'hr.leave',
        label: 'Leave',
        icon: Icons.beach_access_outlined,
        activeIcon: Icons.beach_access_rounded,
        route: Routes.hrLeave),
    NavItem(
        id: 'hr.attendance',
        label: 'Attendance',
        icon: Icons.co_present_outlined,
        activeIcon: Icons.co_present_rounded,
        route: Routes.hrAttendance),
    NavItem(
        id: 'hr.shifts',
        label: 'Shifts',
        icon: Icons.access_time_outlined,
        activeIcon: Icons.access_time_filled,
        route: Routes.hrShifts),
    NavItem(
        id: 'hr.timesheets',
        label: 'Timesheets',
        icon: Icons.timer_outlined,
        activeIcon: Icons.timer,
        route: Routes.hrTimesheets),
    NavItem(
        id: 'hr.helpdesk',
        label: 'Help Desk',
        icon: Icons.support_agent_outlined,
        activeIcon: Icons.support_agent,
        route: Routes.hrHelpdesk),
    NavItem(
        id: 'hr.documents',
        label: 'Documents',
        icon: Icons.folder_outlined,
        activeIcon: Icons.folder,
        route: Routes.hrDocuments),
    NavItem(
        id: 'hr.analytics',
        label: 'Analytics',
        icon: Icons.insights_outlined,
        activeIcon: Icons.insights,
        route: Routes.hrAnalytics),
    NavItem(
        id: 'hr.offboarding',
        label: 'Offboarding',
        icon: Icons.logout_outlined,
        activeIcon: Icons.logout,
        route: Routes.hrOffboarding),
    NavItem(
        id: 'hr.my_profile',
        label: 'My Profile',
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        route: Routes.hrMyProfile),
    // Payroll sub-modules — accountants only run these.
    NavItem(
        id: 'payroll.runs',
        label: 'Payroll Runs',
        icon: Icons.calculate_outlined,
        activeIcon: Icons.calculate_rounded,
        route: Routes.payrollRuns,
        roles: ['OWNER', 'ADMIN', 'ACCOUNTANT']),
    NavItem(
        id: 'payroll.labor_pay_preview',
        label: 'Labor Pay Preview',
        icon: Icons.preview_outlined,
        activeIcon: Icons.preview_rounded,
        route: Routes.payrollLaborPayPreview,
        roles: ['OWNER', 'ADMIN', 'ACCOUNTANT']),
    NavItem(
        id: 'payroll.settings',
        label: 'Payroll Settings',
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings_rounded,
        route: Routes.payrollSettings,
        roles: ['OWNER', 'ADMIN', 'ACCOUNTANT']),
  ],
);

/// Tax & Compliance — cross-cutting group for GST, e-invoice, e-way, TDS,
/// TCS, and industry-specific statutory registers (pharma H1/Schedule-X/
/// Narcotics; FSSAI for food). Most entries are role-gated to accountants;
/// industry-specific entries are industry-gated. India-only by country.
const _taxComplianceGroup = NavGroup(
  id: 'tax_compliance',
  label: 'Tax & Compliance',
  icon: Icons.gavel_outlined,
  activeIcon: Icons.gavel_rounded,
  children: [
    NavItem(
        id: 'tax.gst_dashboard',
        label: 'GST Dashboard',
        icon: Icons.percent_outlined,
        activeIcon: Icons.percent_rounded,
        route: Routes.gst,
        roles: ['OWNER', 'ADMIN', 'ACCOUNTANT'],
        countries: ['IN']),
    NavItem(
        id: 'tax.itc_risk',
        label: 'ITC Risk',
        icon: Icons.warning_amber_outlined,
        activeIcon: Icons.warning_amber_rounded,
        route: Routes.gstItcRisk,
        roles: ['OWNER', 'ADMIN', 'ACCOUNTANT'],
        countries: ['IN']),
    NavItem(
        id: 'tax.statutory_registers',
        label: 'Statutory Registers',
        icon: Icons.menu_book_outlined,
        activeIcon: Icons.menu_book_rounded,
        route: Routes.statutoryRegisters,
        industries: ['PHARMACY', 'PHARMA_DISTRIBUTOR', 'PHARMA_MANUFACTURER'],
        countries: ['IN']),
    NavItem(
        id: 'tax.drug_licenses',
        label: 'Drug Licenses',
        icon: Icons.medical_information_outlined,
        activeIcon: Icons.medical_information_rounded,
        route: Routes.drugLicenses,
        industries: ['PHARMACY', 'PHARMA_DISTRIBUTOR', 'PHARMA_MANUFACTURER'],
        countries: ['IN']),
    NavItem(
        id: 'tax.fssai',
        label: 'FSSAI Compliance',
        icon: Icons.verified_outlined,
        activeIcon: Icons.verified_rounded,
        route: Routes.fssaiCompliance,
        industries: ['FOOD_BEVERAGE', 'FOOD_MANUFACTURER'],
        countries: ['IN']),
  ],
);

const _fieldSalesGroup = NavGroup(
  id: 'field_sales',
  label: 'Field Sales',
  icon: Icons.directions_car_outlined,
  activeIcon: Icons.directions_car_rounded,
  children: [
    NavItem(
        id: 'field_sales.dashboard',
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        route: Routes.fieldSalesDashboard),
    NavItem(
        id: 'field_sales.live_tracking',
        label: 'Live Tracking',
        icon: Icons.my_location_outlined,
        activeIcon: Icons.my_location,
        route: Routes.fieldSalesLiveTracking),
    NavItem(
        id: 'field_sales.mr_approvals',
        label: 'MR Approvals',
        icon: Icons.fact_check_outlined,
        activeIcon: Icons.fact_check,
        route: Routes.fieldSalesMrApprovals),
    NavItem(
        id: 'field_sales.samples',
        label: 'Samples & TA/DA',
        icon: Icons.inventory_2_outlined,
        activeIcon: Icons.inventory_2,
        route: Routes.fieldSalesSamples),
    NavItem(
        id: 'field_sales.coverage',
        label: 'Coverage',
        icon: Icons.insights_outlined,
        activeIcon: Icons.insights,
        route: Routes.fieldSalesCoverage),
    NavItem(
        id: 'field_sales.targets',
        label: 'Targets',
        icon: Icons.flag_outlined,
        activeIcon: Icons.flag,
        route: Routes.fieldSalesTargets),
    NavItem(
        id: 'field_sales.attendance',
        label: 'Attendance',
        icon: Icons.badge_outlined,
        activeIcon: Icons.badge,
        route: Routes.fieldSalesAttendance),
    NavItem(
        id: 'field_sales.detail_aids',
        label: 'Detail Aids',
        icon: Icons.auto_stories_outlined,
        activeIcon: Icons.auto_stories,
        route: Routes.fieldSalesDetailAids),
    NavItem(
        id: 'field_sales.secondary_sales',
        label: 'Secondary Sales',
        icon: Icons.inventory_2_outlined,
        activeIcon: Icons.inventory_2,
        route: Routes.fieldSalesSecondarySales),
    NavItem(
        id: 'field_sales.rcpa',
        label: 'RCPA',
        icon: Icons.fact_check_outlined,
        activeIcon: Icons.fact_check,
        route: Routes.fieldSalesRcpa),
    NavItem(
        id: 'field_sales.org_chart',
        label: 'Org Chart',
        icon: Icons.account_tree_outlined,
        activeIcon: Icons.account_tree,
        route: Routes.fieldSalesOrgChart),
    NavItem(
        id: 'field_sales.beats',
        label: 'Beats',
        icon: Icons.location_on_outlined,
        activeIcon: Icons.location_on_rounded,
        route: Routes.fieldSalesBeats),
    NavItem(
        id: 'field_sales.routes',
        label: 'Routes',
        icon: Icons.route_outlined,
        activeIcon: Icons.route_rounded,
        route: Routes.fieldSalesRoutes),
    NavItem(
        id: 'field_sales.vans',
        label: 'Vans',
        icon: Icons.local_shipping_outlined,
        activeIcon: Icons.local_shipping_rounded,
        route: Routes.fieldSalesVans),
    NavItem(
        id: 'field_sales.executions',
        label: "Today's Routes",
        icon: Icons.play_circle_outline,
        activeIcon: Icons.play_circle_filled,
        route: Routes.fieldSalesExecutions),
    NavItem(
        id: 'field_sales.day_close',
        label: 'Day Close',
        icon: Icons.nightlight_outlined,
        activeIcon: Icons.nightlight_rounded,
        route: Routes.fieldSalesDayClose),
  ],
);

const _partnerNetworkGroup = NavGroup(
  id: 'partner_network',
  label: 'Partner Network',
  icon: Icons.handshake_outlined,
  activeIcon: Icons.handshake_rounded,
  children: [
    NavItem(
        id: 'partner_network.partners',
        label: 'Partners',
        icon: Icons.people_outline,
        activeIcon: Icons.people_rounded,
        route: Routes.partnerNetworkPartners),
    NavItem(
        id: 'partner_network.catalog',
        label: 'My Catalog',
        icon: Icons.storefront_outlined,
        activeIcon: Icons.storefront_rounded,
        route: Routes.partnerNetworkCatalog),
    NavItem(
        id: 'partner_network.supplier_search',
        label: 'Supplier Search',
        icon: Icons.search_outlined,
        activeIcon: Icons.search_rounded,
        route: Routes.partnerNetworkSupplierSearch),
    NavItem(
        id: 'partner_network.outgoing_orders',
        label: 'Outgoing Orders',
        icon: Icons.outbox_outlined,
        activeIcon: Icons.outbox_rounded,
        route: Routes.partnerNetworkOutgoingOrders),
    NavItem(
        id: 'partner_network.incoming_orders',
        label: 'Incoming Orders',
        icon: Icons.inbox_outlined,
        activeIcon: Icons.inbox_rounded,
        route: Routes.partnerNetworkIncomingOrders),
  ],
);

const _manufacturingGroup = NavGroup(
  id: 'manufacturing',
  label: 'Manufacturing',
  icon: Icons.precision_manufacturing_outlined,
  activeIcon: Icons.precision_manufacturing_rounded,
  children: [
    NavItem(
        id: 'manufacturing.work_orders',
        label: 'Work Orders',
        icon: Icons.assignment_outlined,
        activeIcon: Icons.assignment_rounded,
        route: Routes.manufacturingWorkOrders),
    NavItem(
        id: 'manufacturing.routings',
        label: 'Routings',
        icon: Icons.route_outlined,
        activeIcon: Icons.route_rounded,
        route: Routes.manufacturingRoutings),
    NavItem(
        id: 'manufacturing.job_work',
        label: 'Job Work',
        icon: Icons.handyman_outlined,
        activeIcon: Icons.handyman_rounded,
        route: Routes.manufacturingJobWork),
    NavItem(
        id: 'manufacturing.qc',
        label: 'Quality Control',
        icon: Icons.verified_outlined,
        activeIcon: Icons.verified_rounded,
        route: Routes.manufacturingQcInspections),
    NavItem(
        id: 'manufacturing.scrap',
        label: 'Scrap',
        icon: Icons.delete_sweep_outlined,
        activeIcon: Icons.delete_sweep_rounded,
        route: Routes.manufacturingScrap),
    NavItem(
        id: 'manufacturing.maintenance',
        label: 'Maintenance',
        icon: Icons.build_outlined,
        activeIcon: Icons.build_rounded,
        route: Routes.manufacturingMaintenance),
    NavItem(
        id: 'manufacturing.shop_floor',
        label: 'Shop floor',
        icon: Icons.precision_manufacturing_outlined,
        activeIcon: Icons.precision_manufacturing_rounded,
        route: Routes.manufacturingShopFloor),
    NavItem(
        id: 'manufacturing.mrp_runs',
        label: 'MRP Runs',
        icon: Icons.calculate_outlined,
        activeIcon: Icons.calculate_rounded,
        route: Routes.manufacturingMrpRuns),
    NavItem(
        id: 'manufacturing.capa',
        label: 'CAPA',
        icon: Icons.assignment_turned_in_outlined,
        activeIcon: Icons.assignment_turned_in_rounded,
        route: Routes.manufacturingCapa),
    NavItem(
        id: 'manufacturing.workstation_load',
        label: 'Workstation Load',
        icon: Icons.speed_outlined,
        activeIcon: Icons.speed_rounded,
        route: Routes.manufacturingWorkstationLoad),
    NavItem(
        id: 'manufacturing.reliability',
        label: 'Equipment Reliability',
        icon: Icons.monitor_heart_outlined,
        activeIcon: Icons.monitor_heart_rounded,
        route: Routes.manufacturingReliability),
    NavItem(
        id: 'manufacturing.analytics',
        label: 'Production Analytics',
        icon: Icons.analytics_outlined,
        activeIcon: Icons.analytics_rounded,
        route: Routes.manufacturingAnalytics),
  ],
);

const _courierGroup = NavGroup(
  id: 'courier',
  label: 'Courier & Transport',
  icon: Icons.local_post_office_outlined,
  activeIcon: Icons.local_post_office,
  children: [
    NavItem(
        id: 'courier.shipments',
        label: 'Courier Shipments',
        icon: Icons.local_shipping_outlined,
        activeIcon: Icons.local_shipping_rounded,
        route: Routes.courierShipments),
    NavItem(
        id: 'courier.cod',
        label: 'COD Remittances',
        icon: Icons.payments_outlined,
        activeIcon: Icons.payments_rounded,
        route: Routes.courierCod),
    NavItem(
        id: 'courier.lorry_receipts',
        label: 'Lorry Receipts',
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long_rounded,
        route: Routes.lorryReceipts),
    NavItem(
        id: 'courier.freight_rate_cards',
        label: 'Freight Rate Cards',
        icon: Icons.price_change_outlined,
        activeIcon: Icons.price_change_rounded,
        route: Routes.freightRateCards),
    NavItem(
        id: 'courier.vehicle_logs',
        label: 'Vehicle Log',
        icon: Icons.directions_car_outlined,
        activeIcon: Icons.directions_car,
        route: Routes.vehicleLogs),
    NavItem(
        id: 'courier.proof_of_delivery',
        label: 'Proof of Delivery',
        icon: Icons.verified_outlined,
        activeIcon: Icons.verified,
        route: Routes.proofOfDelivery),
  ],
);

const _supplyChainGroup = NavGroup(
  id: 'supply_chain',
  label: 'Supply Planning',
  icon: Icons.hub_outlined,
  activeIcon: Icons.hub_rounded,
  children: [
    NavItem(
        id: 'supply_chain.dashboard',
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        route: Routes.supplyChainDashboard),
    NavItem(
        id: 'supply_chain.requisitions',
        label: 'Requisitions',
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long_rounded,
        route: Routes.supplyChainRequisitions),
    NavItem(
        id: 'supply_chain.shipments',
        label: 'Shipments',
        icon: Icons.local_shipping_outlined,
        activeIcon: Icons.local_shipping_rounded,
        route: Routes.supplyChainShipments),
    NavItem(
        id: 'supply_chain.returns',
        label: 'Returns',
        icon: Icons.assignment_return_outlined,
        activeIcon: Icons.assignment_return_rounded,
        route: Routes.supplyChainReturns),
    NavItem(
        id: 'supply_chain.alerts',
        label: 'Alerts',
        icon: Icons.notifications_active_outlined,
        activeIcon: Icons.notifications_active_rounded,
        route: Routes.supplyChainAlerts),
    NavItem(
        id: 'supply_chain.supplier_rankings',
        label: 'Supplier Rankings',
        icon: Icons.leaderboard_outlined,
        activeIcon: Icons.leaderboard_rounded,
        route: Routes.supplyChainSupplierRankings),
    NavItem(
        id: 'supply_chain.analytics',
        label: 'Analytics',
        icon: Icons.analytics_outlined,
        activeIcon: Icons.analytics_rounded,
        route: Routes.supplyChainTurnover),
  ],
);

/// Public registry export — every group that carries an `id` (and has at
/// least one id'd child) and the small set of top-level NavItems with IDs.
/// Used by the Sidebar Customisation settings screen to render the toggle
/// list. Order here matches the sidebar render order.
List<NavGroup> allConfigurableGroups() => List.unmodifiable([
      for (final g in _allGroups)
        if (g.id != null && g.children.any((c) => c.id != null)) g,
    ]);

List<NavItem> allConfigurableTopLevelItems() => List.unmodifiable([
      _dashboardNavItem,
      _aiCommandCenterNavItem,
      _posNavItem,
      _contactsNavItem,
      _settingsNavItem,
    ]);

/// All groups for route-matching.
const _allGroups = [
  _salesGroup,
  _purchasesGroup,
  _inventoryGroup,
  _accountingGroup,
  _bankingGroup,
  _taxComplianceGroup,
  _reportsGroup,
  _hrPayrollGroup,
  _fieldSalesGroup,
  _partnerNetworkGroup,
  _manufacturingGroup,
  _supplyChainGroup,
  _courierGroup,
];

/// Flat list of every route across top-level items and groups (for active-state matching).
List<NavItem> get _allNavItems => [
      ..._baseTopNavItems,
      for (final g in _allGroups) ...g.children,
    ];

/// Wraps its child in a local [Theme] override driven by
/// [KColors.sidebarSeed] / [KColors.sidebarBrightness], so the sidebar
/// (and tablet rail) can run on a palette that's independent of the
/// app-wide brand seed. All `Theme.of(context).colorScheme.*` calls
/// inside the child resolve to the sidebar palette.
class _SidebarTheme extends StatelessWidget {
  final Widget child;
  const _SidebarTheme({required this.child});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: KColors.sidebarSeed,
          brightness: KColors.sidebarBrightness,
        ),
      ),
      child: child,
    );
  }
}

/// Responsive shell: sidebar on desktop/tablet, bottom nav on mobile.
///
/// Also installs the global Cmd/Ctrl+K shortcut for the command palette and
/// the floating AI assistant (desktop/tablet only).
class ShellScreen extends ConsumerStatefulWidget {
  final Widget child;

  const ShellScreen({super.key, required this.child});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    super.dispose();
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final hasModifier = KShortcuts.isControlOrMetaPressed();

    if (hasModifier && event.logicalKey == LogicalKeyboardKey.keyK) {
      KCommandPalette.show(context, commands: buildAppCommands());
      return true;
    }

    if (hasModifier && event.logicalKey == LogicalKeyboardKey.keyN) {
      _contextAwareNew();
      return true;
    }

    // `?` opens context-aware shortcut help. Centralized here (rather than in
    // per-screen Focus handlers) because HardwareKeyboard handlers do NOT
    // consume events from the focus tree — a second per-screen handler would
    // stack a second dialog on the same keypress. The overlay's own Focus
    // handles `?`-to-dismiss while `isOpen` makes this a no-op.
    if (!hasModifier &&
        !KShortcutHelpOverlay.isOpen &&
        !_isTextFieldFocused() &&
        KShortcutHelpOverlay.isHelpKey(event)) {
      final location = GoRouterState.of(context).uri.toString();
      final isPos = location.startsWith(Routes.pos);
      KShortcutHelpOverlay.show(
        context,
        showPosShortcuts: isPos,
        showListShortcuts: !isPos,
        showFormShortcuts: !isPos,
      );
      return true;
    }

    return false;
  }

  void _contextAwareNew() {
    final location = GoRouterState.of(context).uri.toString();
    String? createRoute;
    if (location.startsWith('/invoices')) {
      createRoute = Routes.invoiceCreate;
    } else if (location.startsWith('/bills')) {
      createRoute = Routes.billCreate;
    } else if (location.startsWith('/sales-orders')) {
      createRoute = Routes.salesOrderCreate;
    } else if (location.startsWith('/purchase-orders')) {
      createRoute = Routes.purchaseOrderCreate;
    } else if (location.startsWith('/delivery-challans')) {
      createRoute = Routes.deliveryChallanCreate;
    } else if (location.startsWith('/estimates')) {
      createRoute = Routes.estimateCreate;
    } else if (location.startsWith('/expenses')) {
      createRoute = Routes.expenseCreate;
    } else if (location.startsWith('/contacts')) {
      createRoute = Routes.contactCreate;
    } else if (location.startsWith('/items')) {
      createRoute = Routes.itemCreate;
    } else if (location.startsWith('/credit-notes')) {
      createRoute = Routes.creditNoteCreate;
    } else if (location.startsWith('/vendor-credits')) {
      createRoute = Routes.vendorCreditCreate;
    } else if (location.startsWith('/stock-receipts')) {
      createRoute = Routes.stockReceiptCreate;
    } else if (location.startsWith('/accounting/journal-entries')) {
      createRoute = Routes.journalEntryCreate;
    } else if (location.startsWith('/payroll/employees')) {
      createRoute = Routes.payrollEmployeeCreate;
    } else if (location.startsWith('/manufacturing/work-orders')) {
      createRoute = Routes.manufacturingWorkOrderCreate;
    } else if (location.startsWith('/accounts') || location.startsWith('/chart-of-accounts')) {
      createRoute = Routes.accountCreate;
    } else if (location.startsWith('/item-groups')) {
      createRoute = Routes.itemGroupCreate;
    } else if (location.startsWith('/inventory/transfer-orders')) {
      createRoute = Routes.transferOrderCreate;
    } else if (location.startsWith('/inventory/stock-counts')) {
      createRoute = Routes.stockCountCreate;
    } else if (location.startsWith('/price-lists')) {
      createRoute = Routes.priceListCreate;
    } else if (location.startsWith('/manufacturing/routings')) {
      createRoute = Routes.manufacturingRoutingCreate;
    } else if (location.startsWith('/manufacturing/job-work')) {
      createRoute = Routes.manufacturingJobWorkCreate;
    }
    if (createRoute != null) {
      context.go(createRoute);
    } else {
      KCommandPalette.show(context, commands: buildAppCommands());
    }
  }

  bool _isTextFieldFocused() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return false;
    final ctx = focus.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText;
  }

  @override
  Widget build(BuildContext context) {
    // Resolve the org's country profile once after login → applies the org's
    // currency (₹ / AED / OMR …) to CurrencyFormatter so KMoney renders right.
    ref.watch(countryProfileProvider);

    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= KSpacing.desktopBreakpoint;
    final isTablet = width >= KSpacing.tabletBreakpoint && !isDesktop;

    final Widget shell;
    if (isDesktop) {
      shell = _DesktopShell(child: widget.child);
    } else if (isTablet) {
      shell = _TabletShell(child: widget.child);
    } else {
      shell = _MobileShell(child: widget.child);
    }

    return shell;
  }
}

// ── Desktop: Fixed sidebar + content area ────────────────────────────

class _DesktopShell extends ConsumerWidget {
  final Widget child;

  const _DesktopShell({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final capabilities = ref.watch(businessCapabilitiesProvider);
    final collapsed = ref.watch(sidebarCollapsedProvider);
    final notifCount = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    final overrides =
        ref.watch(navOverridesProvider).asData?.value ?? NavOverrides.empty;
    final countryCode =
        ref.watch(countryProfileProvider).asData?.value.countryCode;

    final sidebarWidth =
        collapsed ? KSpacing.sidebarCollapsedWidth : KSpacing.sidebarWidth;

    return Scaffold(
      body: Column(
        children: [
          // ── Full-width top bar ──────────────────────────────────
          KTopBar(
            notificationCount: notifCount,
            onNotifications: () => context.push(Routes.notifications),
          ),

          // ── Sidebar + Content row ───────────────────────────────
          Expanded(
            child: Row(
              children: [
                _SidebarTheme(
                  child: Builder(builder: (context) {
                    final scs = Theme.of(context).colorScheme;
                    final sIsDark =
                        Theme.of(context).brightness == Brightness.dark;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: sidebarWidth,
                      decoration: BoxDecoration(
                        color: scs.surface,
                        border: Border(
                          right: BorderSide(
                            color: scs.outlineVariant
                                .withValues(alpha: sIsDark ? 0.4 : 0.6),
                            width: 1,
                          ),
                        ),
                      ),
                      child: ClipRect(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // Derive display mode from actual animated width so
                            // labels don't appear before the container is wide enough.
                            final collapsed = constraints.maxWidth < 160;
                            return Column(
                              children: [
                                // Brand logo — always uses brand seeds (identity),
                                // independent of sidebar palette.
                                Padding(
                                  padding: EdgeInsets.fromLTRB(
                                      collapsed ? 10 : 12,
                                      10,
                                      collapsed ? 10 : 12,
                                      8),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              KColors.brandSeed,
                                              KColors.accentSeed,
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          boxShadow: [
                                            BoxShadow(
                                              color: KColors.brandSeed
                                                  .withValues(alpha: 0.22),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Center(
                                          child: Text(
                                            'K',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (!collapsed) ...[
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Katasticho',
                                            overflow: TextOverflow.clip,
                                            softWrap: false,
                                            style: TextStyle(
                                              color: scs.onSurface,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                // Quick Create button
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: collapsed ? 8 : 12),
                                  child: KQuickCreateMenu(expanded: !collapsed),
                                ),
                                const SizedBox(height: 6),

                                // Nav items
                                Expanded(
                                  child: ListView(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: collapsed ? 8 : 10),
                                    children: _buildSidebarSections(
                                      collapsed: collapsed,
                                      role: authState.role?.toUpperCase() ??
                                          'OWNER',
                                      capabilities: capabilities,
                                      overrides: overrides,
                                      industryCode: authState.industryCode,
                                      countryCode: countryCode,
                                    ),
                                  ),
                                ),

                                // Ask AI
                                Padding(
                                  padding: EdgeInsets.fromLTRB(
                                      collapsed ? 8 : 12,
                                      0,
                                      collapsed ? 8 : 12,
                                      8),
                                  child: _AskAiButton(
                                    collapsed: collapsed,
                                    onTap: () => KAssistantPanel.show(context),
                                  ),
                                ),

                                // User footer
                                Padding(
                                  padding: EdgeInsets.fromLTRB(
                                      collapsed ? 8 : 12,
                                      4,
                                      collapsed ? 8 : 12,
                                      12),
                                  child: Column(
                                    children: [
                                      Divider(
                                        color: scs.outlineVariant
                                            .withValues(alpha: 0.5),
                                        height: 1,
                                      ),
                                      const SizedBox(height: 8),
                                      Material(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          onTap: collapsed
                                              ? null
                                              : () => _showOrgSwitcher(
                                                  context, ref),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4, vertical: 4),
                                            child: Row(
                                              children: [
                                                Tooltip(
                                                  message: collapsed
                                                      ? (authState.userName ??
                                                          'User')
                                                      : '',
                                                  child: CircleAvatar(
                                                    radius: 17,
                                                    backgroundColor:
                                                        scs.primaryContainer,
                                                    child: Text(
                                                      (authState.userName ??
                                                              'U')[0]
                                                          .toUpperCase(),
                                                      style: TextStyle(
                                                        color: scs
                                                            .onPrimaryContainer,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                if (!collapsed) ...[
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          authState.userName ??
                                                              'User',
                                                          style: TextStyle(
                                                            color:
                                                                scs.onSurface,
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                        Text(
                                                          authState.orgName ??
                                                              'Organisation',
                                                          style: TextStyle(
                                                            color: scs
                                                                .onSurfaceVariant,
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Icon(
                                                    Icons.unfold_more_rounded,
                                                    size: 16,
                                                    color: scs.onSurfaceVariant,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    );
                  }),
                ),

                // Main content
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

List<Widget> _buildSidebarSections({
  required bool collapsed,
  required String role,
  required BusinessCapabilities capabilities,
  required NavOverrides overrides,
  String? industryCode,
  String? countryCode,
}) {
  final isCaUser = role == 'CA_PARTNER' || role == 'CA_STAFF';
  if (isCaUser) {
    return [
      _SidebarNavItem(item: _caConsoleNavItem, collapsed: collapsed),
      _SidebarNavItem(
          item: const NavItem(
              label: 'Calendar',
              icon: Icons.calendar_month_outlined,
              activeIcon: Icons.calendar_month_rounded,
              route: Routes.caCalendar),
          collapsed: collapsed),
      _SidebarNavItem(
          item: const NavItem(
              label: 'Alerts',
              icon: Icons.notifications_active_outlined,
              activeIcon: Icons.notifications_active_rounded,
              route: Routes.caAlerts),
          collapsed: collapsed),
      _SidebarNavItem(
          item: const NavItem(
              label: 'Reports',
              icon: Icons.send_outlined,
              activeIcon: Icons.send_rounded,
              route: Routes.caReports),
          collapsed: collapsed),
      KSpacing.vGapSm,
      _SidebarNavItem(item: _settingsNavItem, collapsed: collapsed),
    ];
  }

  // Role hierarchy (highest to lowest):
  // OWNER → ADMIN → ACCOUNTANT → OPERATOR → VIEWER
  final canManage = role == 'OWNER' || role == 'ADMIN';
  final canAccounting = canManage || role == 'ACCOUNTANT';
  final isOperator = role == 'OPERATOR';
  final isViewer = role == 'VIEWER';
  // ERP-canonical order (top to bottom):
  // Sales → Purchases → Inventory → Manufacturing → Field Sales →
  // Partner Network → Accounting → Banking → Tax & Compliance →
  // HR & Payroll → Supply Planning → Courier & Transport → Reports.
  final salesGroup = _visibleGroup(
      _salesGroup, capabilities, overrides, role, industryCode, countryCode);
  final purchasesGroup = _visibleGroup(_purchasesGroup, capabilities, overrides,
      role, industryCode, countryCode);
  final inventoryGroup = _visibleGroup(_inventoryGroup, capabilities, overrides,
      role, industryCode, countryCode);
  final manufacturingGroup = _visibleGroup(_manufacturingGroup, capabilities,
      overrides, role, industryCode, countryCode);
  final fieldSalesGroup = _visibleGroup(_fieldSalesGroup, capabilities,
      overrides, role, industryCode, countryCode);
  final partnerNetworkGroup = _visibleGroup(_partnerNetworkGroup, capabilities,
      overrides, role, industryCode, countryCode);
  final accountingGroup = _visibleGroup(_accountingGroup, capabilities,
      overrides, role, industryCode, countryCode);
  final bankingGroup = _visibleGroup(_bankingGroup, capabilities, overrides,
      role, industryCode, countryCode);
  final taxComplianceGroup = _visibleGroup(_taxComplianceGroup, capabilities,
      overrides, role, industryCode, countryCode);
  final hrPayrollGroup = _visibleGroup(_hrPayrollGroup, capabilities, overrides,
      role, industryCode, countryCode);
  final supplyChainGroup = _visibleGroup(_supplyChainGroup, capabilities,
      overrides, role, industryCode, countryCode);
  final courierGroup = _visibleGroup(
      _courierGroup, capabilities, overrides, role, industryCode, countryCode);
  final reportsGroup = _visibleGroup(_reportsGroup, capabilities, overrides,
      role, industryCode, countryCode);

  bool topItemOk(NavItem item) =>
      _isItemVisible(item, capabilities, overrides, role, industryCode, countryCode);

  return [
    if (topItemOk(_dashboardNavItem))
      _SidebarNavItem(item: _dashboardNavItem, collapsed: collapsed),
    if (!isViewer &&
        capabilities.canUseAiInbox &&
        topItemOk(_aiCommandCenterNavItem))
      _SidebarNavItem(item: _aiCommandCenterNavItem, collapsed: collapsed),
    if (!isViewer && capabilities.canUsePos && topItemOk(_posNavItem))
      _SidebarNavItem(item: _posNavItem, collapsed: collapsed),
    KSpacing.vGapSm,
    if (!isViewer && salesGroup != null)
      _SidebarNavGroup(group: salesGroup, collapsed: collapsed),
    if (canAccounting && purchasesGroup != null)
      _SidebarNavGroup(group: purchasesGroup, collapsed: collapsed),
    if (!isViewer && inventoryGroup != null)
      _SidebarNavGroup(group: inventoryGroup, collapsed: collapsed),
    if (!isViewer && manufacturingGroup != null)
      _SidebarNavGroup(group: manufacturingGroup, collapsed: collapsed),
    if (!isViewer && fieldSalesGroup != null)
      _SidebarNavGroup(group: fieldSalesGroup, collapsed: collapsed),
    if (!isViewer && partnerNetworkGroup != null)
      _SidebarNavGroup(group: partnerNetworkGroup, collapsed: collapsed),
    if (canAccounting && accountingGroup != null)
      _SidebarNavGroup(group: accountingGroup, collapsed: collapsed),
    if (canAccounting && bankingGroup != null)
      _SidebarNavGroup(group: bankingGroup, collapsed: collapsed),
    if (canAccounting && taxComplianceGroup != null)
      _SidebarNavGroup(group: taxComplianceGroup, collapsed: collapsed),
    if (hrPayrollGroup != null)
      _SidebarNavGroup(group: hrPayrollGroup, collapsed: collapsed),
    if (canAccounting && supplyChainGroup != null)
      _SidebarNavGroup(group: supplyChainGroup, collapsed: collapsed),
    if (!isViewer && courierGroup != null)
      _SidebarNavGroup(group: courierGroup, collapsed: collapsed),
    if (canAccounting && reportsGroup != null)
      _SidebarNavGroup(group: reportsGroup, collapsed: collapsed),
    KSpacing.vGapSm,
    if (!isOperator && !isViewer && topItemOk(_contactsNavItem))
      _SidebarNavItem(item: _contactsNavItem, collapsed: collapsed),
    if (topItemOk(_settingsNavItem))
      _SidebarNavItem(item: _settingsNavItem, collapsed: collapsed),
  ];
}

/// Whether the supplied item passes the capability + override + role +
/// industry + country gates. PLATFORM_ADMIN (via [NavOverrides.isPlatformAdmin])
/// bypasses override + role + industry + country gates so support staff can
/// always reach every screen; the capability gate still applies because we
/// don't want to render e.g. pharma menus to an admin who has logged into a
/// non-pharma org.
bool _isItemVisible(
  NavItem item,
  BusinessCapabilities capabilities,
  NavOverrides overrides,
  String? role,
  String? industryCode,
  String? countryCode,
) {
  if (!_isNavItemVisible(item.route, capabilities)) return false;
  if (overrides.isPlatformAdmin) return true;
  if (overrides.isDisabled(item.id)) return false;
  if (item.roles != null && item.roles!.isNotEmpty) {
    final r = (role ?? '').toUpperCase();
    if (r.isEmpty || !item.roles!.contains(r)) return false;
  }
  if (item.industries != null && item.industries!.isNotEmpty) {
    final i = (industryCode ?? '').toUpperCase();
    if (i.isEmpty || !item.industries!.contains(i)) return false;
  }
  if (item.countries != null && item.countries!.isNotEmpty) {
    final c = (countryCode ?? '').toUpperCase();
    if (c.isEmpty || !item.countries!.contains(c)) return false;
  }
  return true;
}

NavGroup? _visibleGroup(
  NavGroup group,
  BusinessCapabilities capabilities,
  NavOverrides overrides,
  String? role,
  String? industryCode,
  String? countryCode,
) {
  if (!overrides.isPlatformAdmin) {
    if (overrides.isDisabled(group.id)) return null;
    if (group.roles != null && group.roles!.isNotEmpty) {
      final r = (role ?? '').toUpperCase();
      if (r.isEmpty || !group.roles!.contains(r)) return null;
    }
    if (group.industries != null && group.industries!.isNotEmpty) {
      final i = (industryCode ?? '').toUpperCase();
      if (i.isEmpty || !group.industries!.contains(i)) return null;
    }
    if (group.countries != null && group.countries!.isNotEmpty) {
      final c = (countryCode ?? '').toUpperCase();
      if (c.isEmpty || !group.countries!.contains(c)) return null;
    }
  }
  final visibleChildren = group.children
      .where((item) => _isItemVisible(
          item, capabilities, overrides, role, industryCode, countryCode))
      .toList(growable: false);
  if (visibleChildren.isEmpty) return null;
  return NavGroup(
    id: group.id,
    label: group.label,
    icon: group.icon,
    activeIcon: group.activeIcon,
    children: visibleChildren,
    roles: group.roles,
    industries: group.industries,
    countries: group.countries,
  );
}

bool _isNavItemVisible(String route, BusinessCapabilities capabilities) {
  if (route == Routes.aiChat) return capabilities.canUseAiInbox;
  if (route == Routes.pos ||
      route == Routes.salesReceipts ||
      route == Routes.receiptSettings) {
    return capabilities.canUsePos;
  }
  if (route == Routes.salesOrders) {
    return capabilities.canUseDistribution || capabilities.canUsePharma;
  }

  if (route == Routes.deliveryChallans) {
    return capabilities.canUseDistribution;
  }
  if (route == Routes.drugLicenses ||
      route == Routes.statutoryRegisters ||
      route == Routes.prescriptionHistory) {
    return capabilities.canUsePharma;
  }
  if (route == Routes.nearExpiry) return capabilities.canUseBatchExpiry;
  if (route == Routes.stockReceipts ||
      route == Routes.purchaseOrders ||
      route == Routes.items ||
      route == Routes.rackLocations ||
      route == Routes.itemGroups ||
      route == Routes.reorder ||
      route == Routes.shortbook ||
      route == Routes.priceLists ||
      route == Routes.schemes ||
      route == Routes.itemImport ||
      route == Routes.stockCounts ||
      route == Routes.transferOrders ||
      route == Routes.picklists ||
      route == '/reports/operational/stock-summary' ||
      route == '/reports/operational/stock-movement') {
    return capabilities.canUseInventory;
  }
  if (route.startsWith('/field-sales')) return capabilities.canUseFieldSales;
  if (route.startsWith('/partner-network')) return capabilities.canUsePartnerNetwork;
  if (route.startsWith('/manufacturing')) return capabilities.canUseManufacturing;
  if (route == Routes.bankReconciliation) return capabilities.canUseBankRecon;
  if (route == '/accounting/dashboard' ||
      route == Routes.guidedTransactionCreate ||
      route == Routes.chartOfAccounts ||
      route == Routes.journalEntries ||
      route == Routes.creditLedger ||
      route == Routes.periodClose ||
      route == Routes.gst) {
    return capabilities.canUseAccounting;
  }
  if (route == Routes.reports ||
      route == Routes.trialBalance ||
      route == Routes.profitLoss ||
      route == Routes.balanceSheet ||
      route == Routes.generalLedger ||
      route == Routes.ageingReport ||
      route == Routes.apAgeingReport ||
      route == '/reports/operational/sales-register' ||
      route == '/reports/operational/pending-dispatch' ||
      route == '/reports/operational/challan-not-invoiced' ||
      route == '/reports/operational/purchase-register' ||
      route == '/reports/operational/daily-sales') {
    return capabilities.canUseReports;
  }
  return true;
}

/// Longest-prefix match across all nav items. Prevents `Items` (/items)
/// and `Import Items` (/items/import) from both lighting up on /items/import
/// — only the most specific entry wins.
bool _isNavActive(String currentRoute, String itemRoute) {
  if (itemRoute == '/') return currentRoute == '/';
  bool matchesSelfOrChild(String r) =>
      currentRoute == r || currentRoute.startsWith('$r/');
  if (!matchesSelfOrChild(itemRoute)) return false;
  for (final other in _allNavItems) {
    if (other.route == itemRoute) continue;
    if (other.route.length > itemRoute.length &&
        matchesSelfOrChild(other.route)) {
      return false;
    }
  }
  return true;
}

/// Returns true if any child route in a group matches the current route.
bool _isGroupActive(String currentRoute, NavGroup group) {
  return group.children.any((item) => _isNavActive(currentRoute, item.route));
}

class _SidebarNavItem extends StatelessWidget {
  final NavItem item;
  final bool collapsed;

  const _SidebarNavItem({required this.item, this.collapsed = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final isActive = _isNavActive(currentRoute, item.route);

    final tile = Material(
      color: isActive ? cs.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(KSpacing.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(KSpacing.radiusMd),
        onTap: () => context.go(item.route),
        child: Padding(
          padding:
              EdgeInsets.symmetric(horizontal: collapsed ? 0 : 10, vertical: 8),
          child: collapsed
              ? Center(
                  child: Icon(
                    isActive ? item.activeIcon : item.icon,
                    color: isActive ? cs.primary : cs.onSurfaceVariant,
                    size: 20,
                  ),
                )
              : Row(
                  children: [
                    Icon(
                      isActive ? item.activeIcon : item.icon,
                      color: isActive ? cs.primary : cs.onSurfaceVariant,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.label,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                        style: TextStyle(
                          color:
                              isActive ? cs.onPrimaryContainer : cs.onSurface,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (isActive)
                      Container(
                        width: 4,
                        height: 16,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: collapsed
          ? Tooltip(
              message: item.label,
              waitDuration: const Duration(milliseconds: 400),
              child: tile,
            )
          : tile,
    );
  }
}

/// A sidebar row that opens a popup overlay of child NavItems on tap.
class _SidebarNavGroup extends StatelessWidget {
  final NavGroup group;
  final bool collapsed;

  const _SidebarNavGroup({required this.group, this.collapsed = false});

  void _showPopup(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final overlayBox =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final pos = renderBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final size = renderBox.size;
    final overlaySize = overlayBox.size;
    final cs = Theme.of(context).colorScheme;
    final currentRoute = GoRouterState.of(context).matchedLocation;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        pos.dx,
        pos.dy + size.height + 4,
        overlaySize.width - pos.dx - size.width,
        overlaySize.height - pos.dy - size.height - 4,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KSpacing.radiusMd),
        side: BorderSide(color: cs.outlineVariant, width: 1),
      ),
      elevation: 0,
      color: cs.surface,
      items: group.children.map((item) {
        final isActive = _isNavActive(currentRoute, item.route);
        return PopupMenuItem<String>(
          value: item.route,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
          child: Row(
            children: [
              Icon(
                isActive ? item.activeIcon : item.icon,
                size: 15,
                color: isActive ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                item.label,
                style: TextStyle(
                  color: isActive ? cs.primary : cs.onSurface,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ).then((route) {
      if (route != null && context.mounted) {
        context.go(route);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final isActive = _isGroupActive(currentRoute, group);

    final tile = Material(
      color: isActive ? cs.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(KSpacing.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(KSpacing.radiusMd),
        onTap: () => _showPopup(context),
        child: Padding(
          padding:
              EdgeInsets.symmetric(horizontal: collapsed ? 0 : 10, vertical: 8),
          child: collapsed
              ? Center(
                  child: Icon(
                    isActive ? group.activeIcon : group.icon,
                    color: isActive ? cs.primary : cs.onSurfaceVariant,
                    size: 20,
                  ),
                )
              : Row(
                  children: [
                    Icon(
                      isActive ? group.activeIcon : group.icon,
                      color: isActive ? cs.primary : cs.onSurfaceVariant,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        group.label,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                        style: TextStyle(
                          color:
                              isActive ? cs.onPrimaryContainer : cs.onSurface,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: isActive
                          ? cs.primary
                          : cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ],
                ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: collapsed
          ? Tooltip(
              message: group.label,
              waitDuration: const Duration(milliseconds: 400),
              child: tile,
            )
          : tile,
    );
  }
}

/// Ask-AI button — expanded variant is a full-width gradient pill with
/// label; collapsed variant is a 40×40 gradient square with just the icon.
///
/// The gradient uses brand seeds directly so the "AI moment" stays brand-
/// colored even when hosted inside a sidebar running on a different palette.
class _AskAiButton extends StatelessWidget {
  final bool collapsed;
  final VoidCallback onTap;

  const _AskAiButton({required this.collapsed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (!collapsed) {
      return KAssistantFab(onTap: onTap);
    }
    return Tooltip(
      message: 'Ask AI',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(KSpacing.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KSpacing.radiusMd),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [KColors.brandSeed, KColors.accentSeed],
              ),
              borderRadius: BorderRadius.circular(KSpacing.radiusMd),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tablet: Rail navigation + content ────────────────────────────────

class _TabletShell extends ConsumerWidget {
  final Widget child;

  const _TabletShell({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final capabilities = ref.watch(businessCapabilitiesProvider);
    final topNavItems = _buildTopNavItems(capabilities);
    final notifCount = ref.watch(unreadCountProvider).valueOrNull ?? 0;

    int selectedIndex = topNavItems.indexWhere(
      (item) =>
          currentRoute == item.route ||
          (item.route != '/' && currentRoute.startsWith(item.route)),
    );
    if (selectedIndex < 0) selectedIndex = 0;

    return Scaffold(
      body: Column(
        children: [
          KTopBar(
            notificationCount: notifCount,
            onNotifications: () => context.push(Routes.notifications),
          ),
          Expanded(
            child: Row(
              children: [
                _SidebarTheme(
                  child: Builder(builder: (context) {
                    final scs = Theme.of(context).colorScheme;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        NavigationRail(
                          selectedIndex: selectedIndex,
                          backgroundColor: scs.surface,
                          indicatorColor: scs.primaryContainer,
                          indicatorShape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onDestinationSelected: (index) {
                            context.go(topNavItems[index].route);
                          },
                          labelType: NavigationRailLabelType.all,
                          leading: const Padding(
                            padding: EdgeInsets.only(top: 12, bottom: 12),
                            child: KQuickCreateMenu(expanded: false),
                          ),
                          trailing: const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: ThemeModeIconButton(),
                          ),
                          destinations: topNavItems
                              .map(
                                (item) => NavigationRailDestination(
                                  icon: Icon(item.icon),
                                  selectedIcon: Icon(item.activeIcon),
                                  label: Text(item.label),
                                ),
                              )
                              .toList(),
                        ),
                        VerticalDivider(
                          width: 1,
                          color: scs.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ],
                    );
                  }),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mobile: Bottom navigation bar ────────────────────────────────────

class _MobileShell extends ConsumerWidget {
  final Widget child;

  const _MobileShell({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final capabilities = ref.watch(businessCapabilitiesProvider);
    final topNavItems = _buildTopNavItems(capabilities);

    int selectedIndex = topNavItems.indexWhere(
      (item) =>
          currentRoute == item.route ||
          (item.route != '/' && currentRoute.startsWith(item.route)),
    );
    if (selectedIndex < 0) selectedIndex = 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          context.go(topNavItems[index].route);
        },
        destinations: topNavItems
            .map((item) => NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.activeIcon),
                  label: item.label,
                ))
            .toList(),
      ),
    );
  }
}

List<NavItem> _buildTopNavItems(BusinessCapabilities capabilities) {
  return [
    _dashboardNavItem,
    if (capabilities.canUseAiInbox) _aiCommandCenterNavItem,
    if (capabilities.canUsePos) _posNavItem,
    _contactsNavItem,
    _settingsNavItem,
  ];
}

// ── Org Switcher ──────────────────────────────────────────────────────

void _showOrgSwitcher(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => UncontrolledProviderScope(
      container: ProviderScope.containerOf(context),
      child: const _OrgSwitcherSheet(),
    ),
  );
}

class _OrgSwitcherSheet extends ConsumerStatefulWidget {
  const _OrgSwitcherSheet();

  @override
  ConsumerState<_OrgSwitcherSheet> createState() => _OrgSwitcherSheetState();
}

class _OrgSwitcherSheetState extends ConsumerState<_OrgSwitcherSheet> {
  bool _switching = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final orgsAsync = ref.watch(myOrgsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Switch Organisation',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            orgsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Failed to load organisations',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              data: (orgs) => Column(
                children: orgs.map((org) {
                  final orgId = org['orgId'] as String;
                  final orgName = org['orgName'] as String? ?? 'Organisation';
                  final role = org['role'] as String? ?? '';
                  final isCurrent = orgId == authState.orgId;

                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: isCurrent
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      child: Text(
                        orgName[0].toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isCurrent
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    title: Text(orgName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(role,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        )),
                    trailing: isCurrent
                        ? Icon(Icons.check_circle_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20)
                        : null,
                    onTap:
                        isCurrent || _switching ? null : () => _doSwitch(orgId),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 24),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: CircleAvatar(
                radius: 20,
                backgroundColor:
                    Theme.of(context).colorScheme.secondaryContainer,
                child: Icon(
                  Icons.add_rounded,
                  color: Theme.of(context).colorScheme.secondary,
                  size: 20,
                ),
              ),
              title: const Text('Add New Organisation',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Create a separate workspace'),
              onTap: _switching ? null : _addNewOrg,
            ),
            if (_switching)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _doSwitch(String targetOrgId) async {
    setState(() => _switching = true);
    final authRepo = ref.read(authRepositoryProvider);
    final success = await ref.read(authProvider.notifier).switchOrg(
          targetOrgId: targetOrgId,
          switchFn: authRepo.switchOrg,
        );
    if (!mounted) return;
    if (success) {
      // Invalidate the API client — every repository watches it, so this
      // cascades to ALL data providers across the app, forcing a full refetch
      // with the new org's token/context.
      ref.invalidate(apiClientProvider);
      ref.invalidate(unreadCountProvider);
      ref.invalidate(dashboardFilterProvider);
      Navigator.pop(context);
      context.go(Routes.dashboard);
    } else {
      setState(() => _switching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to switch organisation')),
      );
    }
  }

  Future<void> _addNewOrg() async {
    final orgName = await _promptOrgName();
    if (orgName == null || orgName.trim().isEmpty) return;
    if (!mounted) return;

    setState(() => _switching = true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.createAdditionalOrg(name: orgName.trim());

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"$orgName" created. Awaiting Katixo admin approval before you can log in.',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _switching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create organisation: $e')),
      );
    }
  }

  Future<String?> _promptOrgName() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Organisation'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Organisation name',
            hintText: 'e.g. My Second Shop',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

// ── Notification Bell ─────────────────────────────────────────────────
// The standalone NotificationBell widget lives in
// features/notifications/presentation/notification_bell.dart and is
// used by KTopBar (desktop/tablet). The private _NotificationBell class
// that was previously here has been replaced by the public widget.
