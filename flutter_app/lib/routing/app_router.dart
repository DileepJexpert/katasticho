import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/auth/business_capabilities.dart';
import '../core/auth/auth_state.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/otp_screen.dart';
import '../features/auth/presentation/signup_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/dashboard/presentation/accounting_dashboard_screen.dart';
import '../features/invoices/presentation/invoice_list_screen.dart';
import '../features/invoices/presentation/invoice_create_screen.dart';
import '../features/invoices/presentation/invoice_detail_screen.dart';
import '../features/contacts/presentation/contact_list_screen.dart';
import '../features/contacts/presentation/contact_create_screen.dart';
import '../features/contacts/presentation/contact_detail_screen.dart';
import '../features/contacts/presentation/contact_import_screen.dart';
import '../features/accounts/presentation/account_list_screen.dart';
import '../features/accounts/presentation/account_create_screen.dart';
import '../features/accounts/presentation/account_detail_screen.dart';

import '../features/expenses/presentation/expense_list_screen.dart';
import '../features/expenses/presentation/expense_create_screen.dart';
import '../features/expenses/presentation/expense_detail_screen.dart';
import '../features/estimates/presentation/estimate_list_screen.dart';
import '../features/estimates/presentation/estimate_create_screen.dart';
import '../features/estimates/presentation/estimate_detail_screen.dart';
import '../features/recurring_invoices/presentation/recurring_invoice_list_screen.dart';
import '../features/recurring_invoices/presentation/recurring_invoice_create_screen.dart';
import '../features/recurring_invoices/presentation/recurring_invoice_detail_screen.dart';
import '../features/notifications/presentation/notification_list_screen.dart';
import '../features/reports/presentation/reports_hub_screen.dart';
import '../features/reports/presentation/trial_balance_screen.dart';
import '../features/reports/presentation/profit_loss_screen.dart';
import '../features/reports/presentation/balance_sheet_screen.dart';
import '../features/reports/presentation/general_ledger_screen.dart';
import '../features/reports/presentation/ageing_report_screen.dart';
import '../features/reports/presentation/ap_ageing_screen.dart';
import '../features/reports/presentation/operational_report_screen.dart';
import '../features/ai_chat/presentation/ai_chat_screen.dart';
import '../features/banking/presentation/bank_reconciliation_screen.dart';
import '../features/settings/presentation/business_configuration_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/inventory_features_screen.dart';
import '../features/settings/presentation/org_details_screen.dart';
import '../features/settings/presentation/branches_screen.dart';
import '../features/default_accounts/presentation/default_accounts_screen.dart';
import '../features/tax_account_mapping/presentation/tax_account_mapping_screen.dart';
import '../features/onboarding/presentation/business_type_screen.dart';
import '../features/onboarding/presentation/industry_screen.dart';
import '../features/onboarding/presentation/sub_category_screen.dart';
import '../features/onboarding/presentation/business_details_screen.dart';
import '../features/onboarding/presentation/setup_complete_screen.dart';
import '../features/gst/presentation/gst_dashboard_screen.dart';
import '../features/credit_notes/presentation/credit_note_list_screen.dart';
import '../features/credit_notes/presentation/credit_note_detail_screen.dart';
import '../features/credit_notes/presentation/credit_note_create_screen.dart';
import '../features/payments/presentation/record_payment_screen.dart';
import '../features/inventory/presentation/item_list_screen.dart';
import '../features/inventory/presentation/item_create_screen.dart';
import '../features/inventory/presentation/item_detail_screen.dart';
import '../features/inventory/presentation/item_import_screen.dart';
import '../features/inventory/presentation/item_group_list_screen.dart';
import '../features/inventory/presentation/item_group_create_screen.dart';
import '../features/inventory/presentation/item_group_detail_screen.dart';
import '../features/inventory/presentation/generate_variants_screen.dart';
import '../features/inventory/presentation/rack_locations_screen.dart';
import '../features/procurement/presentation/stock_receipt_list_screen.dart';
import '../features/procurement/presentation/stock_receipt_create_screen.dart';
import '../features/procurement/presentation/stock_receipt_detail_screen.dart';
import '../features/procurement/presentation/purchase_order_list_screen.dart';
import '../features/procurement/presentation/purchase_order_create_screen.dart';
import '../features/procurement/presentation/purchase_order_detail_screen.dart';
import '../features/procurement/presentation/debit_notes_screen.dart';
import '../features/procurement/presentation/create_debit_note_screen.dart';
import '../features/procurement/presentation/debit_note_detail_screen.dart';
import '../features/pricing/presentation/price_list_list_screen.dart';
import '../features/pricing/presentation/price_list_create_screen.dart';
import '../features/pricing/presentation/price_list_detail_screen.dart';
import '../features/pricing/presentation/scheme_list_screen.dart';
import '../features/bills/presentation/bill_list_screen.dart';
import '../features/bills/presentation/bill_detail_screen.dart';
import '../features/bills/presentation/bill_create_screen.dart';
import '../features/vendor_payments/presentation/vendor_payment_list_screen.dart';
import '../features/vendor_payments/presentation/vendor_payment_detail_screen.dart';
import '../features/vendor_credits/presentation/vendor_credit_list_screen.dart';
import '../features/vendor_credits/presentation/vendor_credit_detail_screen.dart';
import '../features/vendor_credits/presentation/vendor_credit_create_screen.dart';
import '../features/pos/presentation/pos_screen.dart';
import '../features/sales_orders/presentation/sales_order_list_screen.dart';
import '../features/sales_orders/presentation/sales_order_create_screen.dart';
import '../features/sales_orders/presentation/sales_order_detail_screen.dart';
import '../features/delivery_challans/presentation/delivery_challan_list_screen.dart';
import '../features/delivery_challans/presentation/delivery_challan_create_screen.dart';
import '../features/delivery_challans/presentation/delivery_challan_detail_screen.dart';
import '../features/delivery_challans/presentation/delivery_challan_pdf_screen.dart';
import '../features/pos/presentation/pos_receipt_settings_screen.dart';
import '../features/pos/presentation/sales_receipt_list_screen.dart';
import '../features/pos/presentation/sales_receipt_detail_screen.dart';
import '../features/credit_ledger/presentation/credit_ledger_screen.dart';
import '../features/credit_ledger/presentation/credit_ledger_detail_screen.dart';
import '../features/credit_ledger/presentation/overdue_customers_screen.dart';
import '../features/journals/presentation/journal_list_screen.dart';
import '../features/journals/presentation/journal_detail_screen.dart';
import '../features/journals/presentation/journal_create_screen.dart';
import '../features/journals/presentation/guided_transaction_screen.dart';
import '../features/accounting_periods/presentation/period_close_screen.dart';
import '../features/contacts/presentation/contact_statement_screen.dart';
import '../features/inventory/presentation/near_expiry_screen.dart';
import '../features/inventory/presentation/stock_count_list_screen.dart';
import '../features/inventory/presentation/stock_count_create_screen.dart';
import '../features/inventory/presentation/stock_count_detail_screen.dart';
import '../features/inventory/presentation/transfer_order_list_screen.dart';
import '../features/inventory/presentation/transfer_order_create_screen.dart';
import '../features/inventory/presentation/transfer_order_detail_screen.dart';
import '../features/inventory/presentation/picklist_list_screen.dart';
import '../features/inventory/presentation/reorder_screen.dart';
import '../features/inventory/presentation/shortbook_screen.dart';
import '../features/team/presentation/team_screen.dart';
import '../features/settings/presentation/ai_model_settings_screen.dart';
import '../features/settings/presentation/business_policy_settings_screen.dart';
import '../features/ca_console/presentation/ca_console_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/auth/presentation/verify_email_pending_screen.dart';
import '../features/auth/presentation/account_pending_approval_screen.dart';
import '../features/platform_admin/presentation/platform_admin_screen.dart';
import '../features/platform_admin/presentation/platform_admin_login_screen.dart';
import '../features/platform_admin/presentation/platform_admin_dashboard_screen.dart';
import '../features/platform_admin/presentation/platform_admin_pending_screen.dart';
import '../features/platform_admin/presentation/platform_admin_orgs_screen.dart';
import '../features/platform_admin/presentation/platform_admin_users_screen.dart';
import '../features/platform_admin/presentation/platform_admin_audit_screen.dart';
import '../features/platform_admin/data/platform_admin_auth_state.dart';
import '../features/pharma/presentation/drug_licenses_screen.dart';
import '../features/pharma/presentation/prescription_history_screen.dart';
import '../features/loyalty/presentation/wallet_history_screen.dart';
import '../features/workflow/presentation/approval_inbox_screen.dart';
import '../features/workflow/presentation/workflow_settings_screen.dart';
import 'shell_screen.dart';

/// Route paths.
class Routes {
  Routes._();

  static const login = '/login';
  static const otp = '/otp';
  static const signup = '/signup';
  static const dashboard = '/';
  static const invoices = '/invoices';
  static const invoiceCreate = '/invoices/create';
  static const invoiceDetail = '/invoices/:id';
  static const contacts = '/contacts';
  static const contactCreate = '/contacts/create';
  static const contactImport = '/contacts/import';
  static const contactDetail = '/contacts/:id';
  static const contactEdit = '/contacts/:id/edit';
  static const notifications = '/notifications';
  static const expenses = '/expenses';
  static const expenseCreate = '/expenses/create';
  static const expenseDetail = '/expenses/:id';
  static const estimates = '/estimates';
  static const estimateCreate = '/estimates/create';
  static const estimateDetail = '/estimates/:id';
  static const recurringInvoices = '/recurring-invoices';
  static const recurringInvoiceCreate = '/recurring-invoices/create';
  static const recurringInvoiceDetail = '/recurring-invoices/:id';

  static const items = '/items';
  static const itemCreate = '/items/create';
  static const itemImport = '/items/import';
  static const rackLocations = '/inventory/rack-locations';
  static const itemDetail = '/items/:id';
  static const itemGroups = '/item-groups';
  static const itemGroupCreate = '/item-groups/create';
  static const itemGroupDetail = '/item-groups/:id';
  static const itemGroupEdit = '/item-groups/:id/edit';
  static const itemGroupGenerate = '/item-groups/:id/generate-variants';
  static const stockReceipts = '/stock-receipts';
  static const stockReceiptCreate = '/stock-receipts/create';
  static const stockReceiptDetail = '/stock-receipts/:id';
  static const purchaseOrders = '/purchase-orders';
  static const purchaseOrderCreate = '/purchase-orders/create';
  static const purchaseOrderDetail = '/purchase-orders/:id';
  // Debit Notes (Purchase Returns)
  static const debitNotes = '/debit-notes';
  static const debitNoteCreate = '/debit-notes/create';
  static const debitNoteDetail = '/debit-notes/:id';
  static const reports = '/reports';
  static const trialBalance = '/reports/trial-balance';
  static const profitLoss = '/reports/profit-loss';
  static const balanceSheet = '/reports/balance-sheet';
  static const generalLedger = '/reports/general-ledger';
  static const ageingReport = '/reports/ageing';
  static const apAgeingReport = '/reports/ap-ageing';
  static const operationalReport = '/reports/operational/:key';
  static const creditNotes = '/credit-notes';
  static const creditNoteCreate = '/credit-notes/create';
  static const creditNoteDetail = '/credit-notes/:id';
  static const priceLists = '/price-lists';
  static const priceListCreate = '/price-lists/create';
  static const priceListDetail = '/price-lists/:id';
  static const schemes = '/schemes';
  static const recordPayment = '/invoices/:id/pay';
  // AP — Bills
  static const bills = '/bills';
  static const billCreate = '/bills/create';
  static const billDetail = '/bills/:id';
  // AP — Vendor Payments
  static const vendorPayments = '/vendor-payments';
  static const vendorPaymentDetail = '/vendor-payments/:id';
  // AP — Vendor Credits
  static const vendorCredits = '/vendor-credits';
  static const vendorCreditCreate = '/vendor-credits/create';
  static const vendorCreditDetail = '/vendor-credits/:id';
  // Sales Orders
  static const salesOrders = '/sales-orders';
  static const salesOrderCreate = '/sales-orders/create';
  static const salesOrderDetail = '/sales-orders/:id';
  // Delivery Challans
  static const deliveryChallans = '/delivery-challans';
  static const deliveryChallanCreate = '/delivery-challans/create';
  static const deliveryChallanDetail = '/delivery-challans/:id';
  static const deliveryChallanPdf = '/delivery-challans/:id/pdf';
  // POS
  static const pos = '/pos';
  static const salesReceipts = '/sales-receipts';
  static const salesReceiptDetail = '/sales-receipts/:id';
  static const receiptSettings = '/pos/receipt-settings';
  static const aiChat = '/ai-chat';
  static const bankReconciliation = '/banking/reconciliation';
  static const gst = '/gst';
  static const reorder = '/reorder';
  static const shortbook = '/shortbook';
  static const nearExpiry = '/inventory/near-expiry';
  static const stockCounts = '/inventory/stock-counts';
  static const stockCountCreate = '/inventory/stock-counts/create';
  static const transferOrders = '/inventory/transfer-orders';
  static const transferOrderCreate = '/inventory/transfer-orders/create';
  static const picklists = '/inventory/picklists';
  static const contactStatement = '/contacts/:id/statement';
  static const settings = '/settings';
  static const businessConfiguration = '/settings/business-configuration';
  static const orgDetails = '/settings/org-details';
  static const branches = '/settings/branches';
  static const businessPolicies = '/settings/business-policies';
  static const workflowSettings = '/settings/workflows';
  static const approvals = '/approvals';
  static const defaultAccounts = '/settings/default-accounts';
  static const taxAccountMappings = '/settings/tax-accounts';
  static const inventoryFeatures = '/settings/inventory-features';
  static const teamMembers = '/settings/team';
  static const aiSettings = '/settings/ai';
  // Onboarding wizard
  static const onboardingBusinessType = '/onboarding/business-type';
  static const onboardingIndustry = '/onboarding/industry';
  static const onboardingSubCategory = '/onboarding/sub-category';
  static const onboardingDetails = '/onboarding/details';
  static const onboardingComplete = '/onboarding/complete';
  // Accounting — Chart of Accounts
  static const chartOfAccounts = '/accounts';
  static const accountCreate = '/accounts/create';
  static const accountDetail = '/accounts/:id';
  static const accountEdit = '/accounts/:id/edit';
  // Credit Ledger
  static const creditLedger = '/credit-ledger';
  static const creditLedgerDetail = '/credit-ledger/:id';
  static const creditReminders = '/credit-reminders';
  // Journal Entries
  static const guidedTransactionCreate = '/accounting/create-transaction';
  static const journalEntries = '/accounting/journal-entries';
  static const journalEntryCreate = '/accounting/journal-entries/create';
  static const journalEntryDetail = '/accounting/journal-entries/:id';
  static const periodClose = '/accounting/period-close';
  static const caConsole = '/ca';
  static const caCalendar = '/ca/calendar';
  static const caAlerts = '/ca/alerts';
  static const caReports = '/ca/reports';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const verifyEmailPending = '/verify-email-pending';
  static const accountPendingApproval = '/account-pending-approval';
  // Pharma features
  static const drugLicenses = '/pharma/drug-licenses';
  static const prescriptionHistory = '/pharma/prescriptions/:contactId';
  static String prescriptionHistoryPath(String contactId) =>
      '/pharma/prescriptions/$contactId';
  // Loyalty Wallet
  static const walletHistory = '/loyalty/wallet/:contactId';
  static String walletHistoryPath(String contactId) =>
      '/loyalty/wallet/$contactId';

  static const platformAdmin = '/platform-admin';
  static const platformAdminLogin = '/platform-admin/login';
  static const platformAdminDashboard = '/platform-admin/dashboard';
  static const platformAdminPending = '/platform-admin/pending';
  static const platformAdminOrgs = '/platform-admin/orgs';
  static const platformAdminUsers = '/platform-admin/users';
  static const platformAdminAudit = '/platform-admin/audit';
}

final routerProvider = Provider<GoRouter>((ref) {
  final routerRefresh = _RouterRefreshNotifier(ref);
  ref.onDispose(routerRefresh.dispose);

  return GoRouter(
    initialLocation: Routes.login,
    debugLogDiagnostics: true,
    refreshListenable: routerRefresh,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final businessCapabilities = ref.read(businessCapabilitiesProvider);
      final isAuthenticated = authState.isAuthenticated;
      final onboardingCompleted = authState.onboardingCompleted;
      final loc = state.matchedLocation;

      final isAuthRoute = loc == Routes.login ||
          loc == Routes.otp ||
          loc == Routes.signup ||
          loc == Routes.forgotPassword ||
          loc.startsWith('/reset-password') ||
          loc == Routes.verifyEmailPending ||
          loc == Routes.accountPendingApproval;
      final isPlatformAdminRoute = loc.startsWith('/platform-admin');
      final isOnboardingRoute = loc.startsWith('/onboarding');

      debugPrint(
          '[Router] redirect -> loc: $loc, auth: ${authState.status}, onboarded: $onboardingCompleted');

      if (authState.status == AuthStatus.initial ||
          authState.status == AuthStatus.loading) {
        return null;
      }

      // Platform admin routes handle their own auth — skip main auth redirect
      if (isPlatformAdminRoute) {
        return null;
      }

      if (!isAuthenticated && !isAuthRoute) {
        return Routes.login;
      }

      if (isAuthenticated && isAuthRoute) {
        final role = authState.role?.toUpperCase();
        return onboardingCompleted
            ? (role == 'PLATFORM_ADMIN'
                ? Routes.platformAdmin
                : role == 'CA_PARTNER' || role == 'CA_STAFF'
                    ? Routes.caConsole
                    : Routes.dashboard)
            : Routes.onboardingBusinessType;
      }

      final role = authState.role?.toUpperCase();
      if (isAuthenticated &&
          role == 'PLATFORM_ADMIN' &&
          loc != Routes.platformAdmin) {
        return Routes.platformAdmin;
      }

      if (isAuthenticated && !onboardingCompleted && !isOnboardingRoute) {
        return Routes.onboardingBusinessType;
      }

      if (isAuthenticated &&
          onboardingCompleted &&
          loc == Routes.dashboard &&
          (role == 'CA_PARTNER' ||
              role == 'CA_STAFF' ||
              role == 'PLATFORM_ADMIN')) {
        return role == 'PLATFORM_ADMIN'
            ? Routes.platformAdmin
            : Routes.caConsole;
      }

      final capabilityRedirect =
          _capabilityRedirectForLocation(loc, businessCapabilities);
      if (isAuthenticated &&
          onboardingCompleted &&
          !isAuthRoute &&
          !isOnboardingRoute &&
          !isPlatformAdminRoute &&
          capabilityRedirect != null) {
        return capabilityRedirect;
      }

      return null;
    },
    routes: [
      // ── Auth Routes (no shell) ──
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.otp,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Map<String, dynamic>) {
            // Signup flow: carries signup details
            return OtpScreen(
              phoneNumber: extra['phone'] as String? ?? '',
              isSignup: extra['isSignup'] as bool? ?? false,
              fullName: extra['fullName'] as String?,
              orgName: extra['orgName'] as String?,
              industry: extra['industry'] as String?,
            );
          }
          // Login flow: just phone number
          return OtpScreen(phoneNumber: extra as String? ?? '');
        },
      ),
      GoRoute(
        path: Routes.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: Routes.resetPassword,
        builder: (context, state) {
          final token = state.uri.queryParameters['token'] ?? '';
          return ResetPasswordScreen(token: token);
        },
      ),
      GoRoute(
        path: Routes.verifyEmailPending,
        builder: (context, state) {
          final email = state.extra as String? ?? '';
          return VerifyEmailPendingScreen(email: email);
        },
      ),
      GoRoute(
        path: Routes.accountPendingApproval,
        builder: (context, state) => const AccountPendingApprovalScreen(),
      ),

      // ── Platform Admin (separate auth — no shell) ──
      GoRoute(
        path: Routes.platformAdminLogin,
        builder: (context, state) => const PlatformAdminLoginScreen(),
      ),
      GoRoute(
        path: Routes.platformAdminDashboard,
        redirect: (context, state) {
          final token = ref.read(platformAdminTokenProvider);
          if (token == null) return Routes.platformAdminLogin;
          return null;
        },
        builder: (context, state) => const PlatformAdminDashboardScreen(),
      ),
      GoRoute(
        path: Routes.platformAdminPending,
        redirect: (context, state) {
          final token = ref.read(platformAdminTokenProvider);
          if (token == null) return Routes.platformAdminLogin;
          return null;
        },
        builder: (context, state) => const PlatformAdminPendingScreen(),
      ),
      GoRoute(
        path: Routes.platformAdminOrgs,
        redirect: (context, state) {
          final token = ref.read(platformAdminTokenProvider);
          if (token == null) return Routes.platformAdminLogin;
          return null;
        },
        builder: (context, state) => const PlatformAdminOrgsScreen(),
      ),
      GoRoute(
        path: Routes.platformAdminUsers,
        redirect: (context, state) {
          final token = ref.read(platformAdminTokenProvider);
          if (token == null) return Routes.platformAdminLogin;
          return null;
        },
        builder: (context, state) => const PlatformAdminUsersScreen(),
      ),
      GoRoute(
        path: Routes.platformAdminAudit,
        redirect: (context, state) {
          final token = ref.read(platformAdminTokenProvider);
          if (token == null) return Routes.platformAdminLogin;
          return null;
        },
        builder: (context, state) => const PlatformAdminAuditScreen(),
      ),

      // ── Onboarding wizard (no shell, no nav bar) ──
      GoRoute(
        path: Routes.onboardingBusinessType,
        builder: (context, state) => const BusinessTypeScreen(),
      ),
      GoRoute(
        path: Routes.onboardingIndustry,
        builder: (context, state) => const IndustryScreen(),
      ),
      GoRoute(
        path: Routes.onboardingSubCategory,
        builder: (context, state) => const SubCategoryScreen(),
      ),
      GoRoute(
        path: Routes.onboardingDetails,
        builder: (context, state) => const BusinessDetailsScreen(),
      ),
      GoRoute(
        path: Routes.onboardingComplete,
        builder: (context, state) => const SetupCompleteScreen(),
      ),

      // ── App Shell with navigation ──
      ShellRoute(
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          GoRoute(
            path: Routes.dashboard,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DashboardScreen(),
            ),
          ),
          GoRoute(
            path: Routes.caConsole,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CaConsoleScreen(initialTab: 0),
            ),
          ),
          GoRoute(
            path: Routes.caCalendar,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CaConsoleScreen(initialTab: 1),
            ),
          ),
          GoRoute(
            path: Routes.caAlerts,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CaConsoleScreen(initialTab: 2),
            ),
          ),
          GoRoute(
            path: Routes.caReports,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CaConsoleScreen(initialTab: 3),
            ),
          ),
          GoRoute(
            path: Routes.platformAdmin,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PlatformAdminScreen(),
            ),
          ),
          GoRoute(
            path: '/accounting/dashboard',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AccountingDashboardScreen(),
            ),
          ),
          GoRoute(
            path: Routes.invoices,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: InvoiceListScreen(),
            ),
          ),
          GoRoute(
            path: Routes.invoiceCreate,
            builder: (context, state) => const InvoiceCreateScreen(),
          ),
          GoRoute(
            path: '/invoices/:id/pay',
            builder: (context, state) => RecordPaymentScreen(
              invoiceId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/invoices/:id',
            builder: (context, state) => InvoiceDetailScreen(
              invoiceId: state.pathParameters['id']!,
            ),
          ),
          // F6: Contacts
          GoRoute(
            path: Routes.contacts,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ContactListScreen(),
            ),
          ),
          GoRoute(
            path: Routes.contactCreate,
            builder: (context, state) => const ContactCreateScreen(),
          ),
          GoRoute(
            path: Routes.contactImport,
            builder: (context, state) => const ContactImportScreen(),
          ),
          GoRoute(
            path: '/contacts/:id/edit',
            builder: (context, state) => ContactCreateScreen(
              contactId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/contacts/:id',
            builder: (context, state) => ContactDetailScreen(
              contactId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/contacts/:id/statement',
            builder: (context, state) => ContactStatementScreen(
              contactId: state.pathParameters['id']!,
              contactName: state.extra as String?,
            ),
          ),
          // Credit Ledger
          GoRoute(
            path: Routes.creditLedger,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CreditLedgerScreen(),
            ),
          ),
          GoRoute(
            path: '/credit-ledger/:id',
            builder: (context, state) => CreditLedgerDetailScreen(
              contactId: state.pathParameters['id']!,
              contactData: state.extra as Map<String, dynamic>?,
            ),
          ),
          GoRoute(
            path: Routes.creditReminders,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: OverdueCustomersScreen(),
            ),
          ),
          // Journal Entries
          GoRoute(
            path: Routes.guidedTransactionCreate,
            builder: (context, state) => const GuidedTransactionScreen(),
          ),
          GoRoute(
            path: Routes.journalEntries,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: JournalListScreen(),
            ),
          ),
          GoRoute(
            path: Routes.journalEntryCreate,
            builder: (context, state) => const JournalCreateScreen(),
          ),
          GoRoute(
            path: '/accounting/journal-entries/:id',
            builder: (context, state) => JournalDetailScreen(
              journalId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: Routes.periodClose,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PeriodCloseScreen(),
            ),
          ),
          // Chart of Accounts
          GoRoute(
            path: Routes.chartOfAccounts,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AccountListScreen(),
            ),
          ),
          GoRoute(
            path: Routes.accountCreate,
            builder: (context, state) => const AccountCreateScreen(),
          ),
          GoRoute(
            path: '/accounts/:id/edit',
            builder: (context, state) => AccountCreateScreen(
              accountId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/accounts/:id',
            builder: (context, state) => AccountDetailScreen(
              accountId: state.pathParameters['id']!,
            ),
          ),
          // F6: Notifications
          GoRoute(
            path: Routes.notifications,
            builder: (context, state) => const NotificationListScreen(),
          ),
          // F7: Expenses
          GoRoute(
            path: Routes.expenses,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ExpenseListScreen(),
            ),
          ),
          GoRoute(
            path: Routes.expenseCreate,
            builder: (context, state) => const ExpenseCreateScreen(),
          ),
          GoRoute(
            path: '/expenses/:id',
            builder: (context, state) => ExpenseDetailScreen(
              expenseId: state.pathParameters['id']!,
            ),
          ),
          // F9: Estimates / Quotations
          GoRoute(
            path: Routes.estimates,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: EstimateListScreen(),
            ),
          ),
          GoRoute(
            path: Routes.estimateCreate,
            builder: (context, state) => const EstimateCreateScreen(),
          ),
          GoRoute(
            path: '/estimates/:id',
            builder: (context, state) => EstimateDetailScreen(
              estimateId: state.pathParameters['id']!,
            ),
          ),
          // Sales Orders
          GoRoute(
            path: Routes.salesOrders,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SalesOrderListScreen(),
            ),
          ),
          GoRoute(
            path: Routes.salesOrderCreate,
            builder: (context, state) => const SalesOrderCreateScreen(),
          ),
          GoRoute(
            path: '/sales-orders/:id',
            builder: (context, state) => SalesOrderDetailScreen(
              salesOrderId: state.pathParameters['id']!,
            ),
          ),
          // Delivery Challans
          GoRoute(
            path: Routes.deliveryChallans,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DeliveryChallanListScreen(),
            ),
          ),
          GoRoute(
            path: Routes.deliveryChallanCreate,
            builder: (context, state) => DeliveryChallanCreateScreen(
              salesOrderId: state.uri.queryParameters['salesOrderId'],
            ),
          ),
          GoRoute(
            path: '/delivery-challans/:id',
            builder: (context, state) => DeliveryChallanDetailScreen(
              challanId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/delivery-challans/:id/pdf',
            builder: (context, state) {
              final challan = state.extra as Map<String, dynamic>? ?? {};
              return DeliveryChallanPdfScreen(challan: challan);
            },
          ),
          // Sales Receipts
          GoRoute(
            path: Routes.salesReceipts,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SalesReceiptListScreen(),
            ),
          ),
          GoRoute(
            path: '/sales-receipts/:id',
            builder: (context, state) => SalesReceiptDetailScreen(
              receiptId: state.pathParameters['id']!,
            ),
          ),
          // Receipt Settings
          GoRoute(
            path: Routes.receiptSettings,
            builder: (context, state) => const PosReceiptSettingsScreen(),
          ),
          // F8: Recurring Invoices
          GoRoute(
            path: Routes.recurringInvoices,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: RecurringInvoiceListScreen(),
            ),
          ),
          GoRoute(
            path: Routes.recurringInvoiceCreate,
            builder: (context, state) => const RecurringInvoiceCreateScreen(),
          ),
          GoRoute(
            path: '/recurring-invoices/:id',
            builder: (context, state) => RecurringInvoiceDetailScreen(
              templateId: state.pathParameters['id']!,
            ),
          ),

          GoRoute(
            path: Routes.items,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ItemListScreen(),
            ),
          ),
          GoRoute(
            path: Routes.itemCreate,
            builder: (context, state) => const ItemCreateScreen(),
          ),
          GoRoute(
            path: Routes.itemImport,
            builder: (context, state) => const ItemImportScreen(),
          ),
          GoRoute(
            path: Routes.rackLocations,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: RackLocationsScreen(),
            ),
          ),
          GoRoute(
            path: '/items/:id',
            builder: (context, state) => ItemDetailScreen(
              itemId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: Routes.reorder,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ReorderScreen(),
            ),
          ),
          GoRoute(
            path: Routes.shortbook,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ShortbookScreen(),
            ),
          ),
          GoRoute(
            path: Routes.nearExpiry,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: NearExpiryScreen(),
            ),
          ),
          GoRoute(
            path: Routes.stockCounts,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: StockCountListScreen(),
            ),
          ),
          GoRoute(
            path: Routes.stockCountCreate,
            builder: (context, state) => const StockCountCreateScreen(),
          ),
          GoRoute(
            path: '/inventory/stock-counts/:id',
            builder: (context, state) => StockCountDetailScreen(
              id: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: Routes.transferOrders,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TransferOrderListScreen(),
            ),
          ),
          GoRoute(
            path: Routes.transferOrderCreate,
            builder: (context, state) => const TransferOrderCreateScreen(),
          ),
          GoRoute(
            path: '/inventory/transfer-orders/:id',
            builder: (context, state) => TransferOrderDetailScreen(
              id: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: Routes.picklists,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PicklistListScreen(),
            ),
          ),
          // Pharma — Drug Licenses & Compliance
          GoRoute(
            path: Routes.drugLicenses,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DrugLicensesScreen(),
            ),
          ),
          // Pharma — Prescription History (per patient)
          GoRoute(
            path: Routes.prescriptionHistory,
            builder: (context, state) {
              final contactId = state.pathParameters['contactId']!;
              final extra = state.extra;
              String? contactName;
              if (extra is Map<String, dynamic>) {
                contactName = extra['contactName'] as String?;
              } else if (extra is String) {
                contactName = extra;
              }
              return PrescriptionHistoryScreen(
                contactId: contactId,
                contactName: contactName,
              );
            },
          ),
          // Loyalty — Wallet History (per contact)
          GoRoute(
            path: Routes.walletHistory,
            builder: (context, state) {
              final contactId = state.pathParameters['contactId']!;
              final extra = state.extra;
              String? contactName;
              if (extra is Map<String, dynamic>) {
                contactName = extra['contactName'] as String?;
              } else if (extra is String) {
                contactName = extra;
              }
              return WalletHistoryScreen(
                contactId: contactId,
                contactName: contactName,
              );
            },
          ),
          // F5 — item groups (variant templates).
          GoRoute(
            path: Routes.itemGroups,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ItemGroupListScreen(),
            ),
          ),
          GoRoute(
            path: Routes.itemGroupCreate,
            builder: (context, state) => const ItemGroupCreateScreen(),
          ),
          GoRoute(
            path: '/item-groups/:id',
            builder: (context, state) => ItemGroupDetailScreen(
              groupId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/item-groups/:id/edit',
            builder: (context, state) => ItemGroupCreateScreen(
              groupId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/item-groups/:id/generate-variants',
            builder: (context, state) => GenerateVariantsScreen(
              groupId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: Routes.stockReceipts,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: StockReceiptListScreen(),
            ),
          ),
          GoRoute(
            path: Routes.stockReceiptCreate,
            builder: (context, state) {
              final extra = state.extra;
              if (extra is StockReceiptPrefill) {
                return StockReceiptCreateScreen(
                  prefillItems: extra.items,
                  prefillSupplier: extra.supplier,
                );
              }
              return StockReceiptCreateScreen(
                prefillItems: extra as List<Map<String, dynamic>>?,
              );
            },
          ),
          GoRoute(
            path: '/stock-receipts/:id',
            builder: (context, state) => StockReceiptDetailScreen(
              receiptId: state.pathParameters['id']!,
            ),
          ),
          // Purchase Orders
          GoRoute(
            path: Routes.purchaseOrders,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PurchaseOrderListScreen(),
            ),
          ),
          GoRoute(
            path: Routes.purchaseOrderCreate,
            builder: (context, state) {
              final extra = state.extra;
              if (extra is PurchaseOrderPrefill) {
                return PurchaseOrderCreateScreen(prefillItems: extra.items);
              }
              return PurchaseOrderCreateScreen(
                prefillItems: extra as List<Map<String, dynamic>>?,
              );
            },
          ),
          GoRoute(
            path: '/purchase-orders/:id',
            builder: (context, state) => PurchaseOrderDetailScreen(
              poId: state.pathParameters['id']!,
            ),
          ),
          // Debit Notes (Purchase Returns)
          GoRoute(
            path: Routes.debitNotes,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DebitNotesScreen(),
            ),
          ),
          GoRoute(
            path: Routes.debitNoteCreate,
            builder: (context, state) {
              final extra = state.extra;
              return CreateDebitNoteScreen(
                prefillExpiryDate: extra is DateTime ? extra : null,
                prefill: extra is Map<String, dynamic> ? extra : null,
              );
            },
          ),
          GoRoute(
            path: '/debit-notes/:id',
            builder: (context, state) => DebitNoteDetailScreen(
              debitNoteId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: Routes.reports,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ReportsHubScreen(),
            ),
          ),
          GoRoute(
            path: Routes.trialBalance,
            builder: (context, state) => const TrialBalanceScreen(),
          ),
          GoRoute(
            path: Routes.profitLoss,
            builder: (context, state) => const ProfitLossScreen(),
          ),
          GoRoute(
            path: Routes.balanceSheet,
            builder: (context, state) => const BalanceSheetScreen(),
          ),
          GoRoute(
            path: Routes.generalLedger,
            builder: (context, state) => const GeneralLedgerScreen(),
          ),
          GoRoute(
            path: Routes.ageingReport,
            builder: (context, state) => const AgeingReportScreen(),
          ),
          GoRoute(
            path: Routes.apAgeingReport,
            builder: (context, state) => const ApAgeingScreen(),
          ),
          GoRoute(
            path: Routes.operationalReport,
            builder: (context, state) => OperationalReportScreen(
              reportKey: state.pathParameters['key']!,
              fallbackTitle: state.uri.queryParameters['title'] ?? 'Report',
              dateRange: state.uri.queryParameters['dateRange'] != 'false',
            ),
          ),
          GoRoute(
            path: Routes.creditNotes,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CreditNoteListScreen(),
            ),
          ),
          GoRoute(
            path: Routes.creditNoteCreate,
            builder: (context, state) => const CreditNoteCreateScreen(),
          ),
          GoRoute(
            path: '/credit-notes/:id',
            builder: (context, state) => CreditNoteDetailScreen(
              creditNoteId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: Routes.priceLists,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PriceListListScreen(),
            ),
          ),
          GoRoute(
            path: Routes.priceListCreate,
            builder: (context, state) => const PriceListCreateScreen(),
          ),
          GoRoute(
            path: '/price-lists/:id',
            builder: (context, state) => PriceListDetailScreen(
              listId: state.pathParameters['id']!,
            ),
          ),
          // Schemes — promotional offers (Buy X Get Y, % discount)
          GoRoute(
            path: Routes.schemes,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SchemeListScreen(),
            ),
          ),
          // AP — Bills
          GoRoute(
            path: Routes.bills,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: BillListScreen(),
            ),
          ),
          GoRoute(
            path: Routes.billCreate,
            builder: (context, state) => const BillCreateScreen(),
          ),
          GoRoute(
            path: '/bills/:id',
            builder: (context, state) => BillDetailScreen(
              billId: state.pathParameters['id']!,
            ),
          ),
          // AP — Vendor Payments
          GoRoute(
            path: Routes.vendorPayments,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: VendorPaymentListScreen(),
            ),
          ),
          GoRoute(
            path: '/vendor-payments/:id',
            builder: (context, state) => VendorPaymentDetailScreen(
              paymentId: state.pathParameters['id']!,
            ),
          ),
          // AP — Vendor Credits
          GoRoute(
            path: Routes.vendorCredits,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: VendorCreditListScreen(),
            ),
          ),
          GoRoute(
            path: Routes.vendorCreditCreate,
            builder: (context, state) => const VendorCreditCreateScreen(),
          ),
          GoRoute(
            path: '/vendor-credits/:id',
            builder: (context, state) => VendorCreditDetailScreen(
              creditId: state.pathParameters['id']!,
            ),
          ),
          // POS
          GoRoute(
            path: Routes.pos,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PosScreen(),
            ),
          ),
          GoRoute(
            path: Routes.aiChat,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AiChatScreen(),
            ),
          ),
          GoRoute(
            path: Routes.bankReconciliation,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: BankReconciliationScreen(),
            ),
          ),
          GoRoute(
            path: Routes.gst,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: GstDashboardScreen(),
            ),
          ),
          GoRoute(
            path: Routes.settings,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
          GoRoute(
            path: Routes.businessConfiguration,
            builder: (context, state) => const BusinessConfigurationScreen(),
          ),
          GoRoute(
            path: Routes.orgDetails,
            builder: (context, state) => const OrgDetailsScreen(),
          ),
          GoRoute(
            path: Routes.branches,
            builder: (context, state) => const BranchesScreen(),
          ),
          GoRoute(
            path: Routes.businessPolicies,
            builder: (context, state) => const BusinessPolicySettingsScreen(),
          ),
          GoRoute(
            path: Routes.workflowSettings,
            builder: (context, state) => const WorkflowSettingsScreen(),
          ),
          GoRoute(
            path: Routes.approvals,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ApprovalInboxScreen(),
            ),
          ),
          GoRoute(
            path: Routes.defaultAccounts,
            builder: (context, state) => const DefaultAccountsScreen(),
          ),
          GoRoute(
            path: Routes.taxAccountMappings,
            builder: (context, state) => const TaxAccountMappingScreen(),
          ),
          GoRoute(
            path: Routes.inventoryFeatures,
            builder: (context, state) => const InventoryFeaturesScreen(),
          ),
          GoRoute(
            path: Routes.teamMembers,
            builder: (context, state) => const TeamScreen(),
          ),
          GoRoute(
            path: Routes.aiSettings,
            builder: (context, state) => const AiModelSettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
    _ref.listen<BusinessCapabilities>(
      businessCapabilitiesProvider,
      (_, __) => notifyListeners(),
    );
  }

  final Ref _ref;
}

String? _capabilityRedirectForLocation(
  String location,
  BusinessCapabilities capabilities,
) {
  if ((location == Routes.pos ||
          location == Routes.salesReceipts ||
          location == Routes.receiptSettings) &&
      !capabilities.canUsePos) {
    return Routes.dashboard;
  }
  final isSalesOrderRoute = location == Routes.salesOrders ||
      location == Routes.salesOrderCreate ||
      location.startsWith('/sales-orders/');

  final isDeliveryChallanRoute = location == Routes.deliveryChallans ||
      location == Routes.deliveryChallanCreate ||
      location.startsWith('/delivery-challans/');

  if (isSalesOrderRoute &&
      !(capabilities.canUseDistribution || capabilities.canUsePharma)) {
    return Routes.dashboard;
  }

  if (isDeliveryChallanRoute && !capabilities.canUseDistribution) {
    return Routes.dashboard;
  }
  if ((location == Routes.items ||
          location == Routes.itemCreate ||
          location == Routes.itemImport ||
          location == Routes.rackLocations ||
          location.startsWith('/items/') ||
          location == Routes.itemGroups ||
          location.startsWith('/item-groups/') ||
          location == Routes.stockReceipts ||
          location == Routes.stockReceiptCreate ||
          location.startsWith('/stock-receipts/') ||
          location == Routes.purchaseOrders ||
          location == Routes.purchaseOrderCreate ||
          location.startsWith('/purchase-orders/') ||
          location == Routes.reorder ||
          location == Routes.shortbook ||
          location == Routes.priceLists ||
          location == Routes.priceListCreate ||
          location.startsWith('/price-lists/') ||
          location == Routes.schemes) &&
      !capabilities.canUseInventory) {
    return Routes.dashboard;
  }
  if ((location == Routes.nearExpiry) && !capabilities.canUseBatchExpiry) {
    return Routes.dashboard;
  }
  if ((location == Routes.drugLicenses ||
          location.startsWith('/pharma/prescriptions/')) &&
      !capabilities.canUsePharma) {
    return Routes.dashboard;
  }
  if (location == Routes.bankReconciliation && !capabilities.canUseBankRecon) {
    return Routes.dashboard;
  }
  return null;
}
