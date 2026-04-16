import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/auth/auth_state.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/otp_screen.dart';
import '../features/auth/presentation/signup_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/invoices/presentation/invoice_list_screen.dart';
import '../features/invoices/presentation/invoice_create_screen.dart';
import '../features/invoices/presentation/invoice_detail_screen.dart';
import '../features/contacts/presentation/contact_list_screen.dart';
import '../features/contacts/presentation/contact_create_screen.dart';
import '../features/contacts/presentation/contact_detail_screen.dart';
import '../features/customers/presentation/customer_list_screen.dart';
import '../features/customers/presentation/customer_detail_screen.dart';
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
import '../features/ai_chat/presentation/ai_chat_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
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
import '../features/procurement/presentation/stock_receipt_list_screen.dart';
import '../features/procurement/presentation/stock_receipt_create_screen.dart';
import '../features/procurement/presentation/stock_receipt_detail_screen.dart';
import '../features/pricing/presentation/price_list_list_screen.dart';
import '../features/pricing/presentation/price_list_create_screen.dart';
import '../features/pricing/presentation/price_list_detail_screen.dart';
import '../features/bills/presentation/bill_list_screen.dart';
import '../features/bills/presentation/bill_detail_screen.dart';
import '../features/bills/presentation/bill_create_screen.dart';
import '../features/vendor_payments/presentation/vendor_payment_list_screen.dart';
import '../features/vendor_payments/presentation/vendor_payment_detail_screen.dart';
import '../features/vendor_credits/presentation/vendor_credit_list_screen.dart';
import '../features/vendor_credits/presentation/vendor_credit_detail_screen.dart';
import '../features/vendor_credits/presentation/vendor_credit_create_screen.dart';
import '../features/pos/presentation/pos_screen.dart';
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
  static const customers = '/customers';
  static const customerDetail = '/customers/:id';
  static const items = '/items';
  static const itemCreate = '/items/create';
  static const itemImport = '/items/import';
  static const itemDetail = '/items/:id';
  static const itemGroups = '/item-groups';
  static const itemGroupCreate = '/item-groups/create';
  static const itemGroupDetail = '/item-groups/:id';
  static const itemGroupEdit = '/item-groups/:id/edit';
  static const itemGroupGenerate = '/item-groups/:id/generate-variants';
  static const stockReceipts = '/stock-receipts';
  static const stockReceiptCreate = '/stock-receipts/create';
  static const stockReceiptDetail = '/stock-receipts/:id';
  static const reports = '/reports';
  static const trialBalance = '/reports/trial-balance';
  static const profitLoss = '/reports/profit-loss';
  static const balanceSheet = '/reports/balance-sheet';
  static const generalLedger = '/reports/general-ledger';
  static const ageingReport = '/reports/ageing';
  static const apAgeingReport = '/reports/ap-ageing';
  static const creditNotes = '/credit-notes';
  static const creditNoteCreate = '/credit-notes/create';
  static const creditNoteDetail = '/credit-notes/:id';
  static const priceLists = '/price-lists';
  static const priceListCreate = '/price-lists/create';
  static const priceListDetail = '/price-lists/:id';
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
  // POS
  static const pos = '/pos';
  static const aiChat = '/ai-chat';
  static const gst = '/gst';
  static const settings = '/settings';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: Routes.dashboard,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final isAuthRoute = state.matchedLocation == Routes.login ||
          state.matchedLocation == Routes.otp ||
          state.matchedLocation == Routes.signup;

      debugPrint('[Router] redirect check -> location: ${state.matchedLocation}, authStatus: ${authState.status}, isAuthenticated: $isAuthenticated, isAuthRoute: $isAuthRoute');

      if (authState.status == AuthStatus.initial ||
          authState.status == AuthStatus.loading) {
        debugPrint('[Router] Auth still loading, no redirect');
        return null; // Still loading, don't redirect
      }

      if (!isAuthenticated && !isAuthRoute) {
        debugPrint('[Router] Not authenticated, redirecting to login');
        return Routes.login;
      }

      if (isAuthenticated && isAuthRoute) {
        debugPrint('[Router] Authenticated on auth route, redirecting to dashboard');
        return Routes.dashboard;
      }

      debugPrint('[Router] No redirect needed');
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
            path: Routes.customers,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CustomerListScreen(),
            ),
          ),
          GoRoute(
            path: '/customers/:id',
            builder: (context, state) => CustomerDetailScreen(
              customerId: state.pathParameters['id']!,
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
            path: '/items/:id',
            builder: (context, state) => ItemDetailScreen(
              itemId: state.pathParameters['id']!,
            ),
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
            builder: (context, state) => const StockReceiptCreateScreen(),
          ),
          GoRoute(
            path: '/stock-receipts/:id',
            builder: (context, state) => StockReceiptDetailScreen(
              receiptId: state.pathParameters['id']!,
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
        ],
      ),
    ],
  );
});
