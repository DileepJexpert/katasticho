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
import '../features/customers/presentation/customer_list_screen.dart';
import '../features/customers/presentation/customer_detail_screen.dart';
import '../features/reports/presentation/reports_hub_screen.dart';
import '../features/reports/presentation/trial_balance_screen.dart';
import '../features/reports/presentation/profit_loss_screen.dart';
import '../features/reports/presentation/balance_sheet_screen.dart';
import '../features/reports/presentation/general_ledger_screen.dart';
import '../features/reports/presentation/ageing_report_screen.dart';
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
  static const customers = '/customers';
  static const customerDetail = '/customers/:id';
  static const items = '/items';
  static const itemCreate = '/items/create';
  static const itemDetail = '/items/:id';
  static const reports = '/reports';
  static const trialBalance = '/reports/trial-balance';
  static const profitLoss = '/reports/profit-loss';
  static const balanceSheet = '/reports/balance-sheet';
  static const generalLedger = '/reports/general-ledger';
  static const ageingReport = '/reports/ageing';
  static const creditNotes = '/credit-notes';
  static const creditNoteCreate = '/credit-notes/create';
  static const creditNoteDetail = '/credit-notes/:id';
  static const recordPayment = '/invoices/:id/pay';
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
            path: '/items/:id',
            builder: (context, state) => ItemDetailScreen(
              itemId: state.pathParameters['id']!,
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
