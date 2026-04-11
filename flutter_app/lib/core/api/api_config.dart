/// API configuration constants.
class ApiConfig {
  ApiConfig._();

  // Base URL — override per environment via build flavors
  static const String baseUrl = 'http://localhost:8080';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Auth endpoints
  static const String login = '/api/v1/auth/login';
  static const String verifyOtp = '/api/v1/auth/verify-otp';
  static const String register = '/api/v1/auth/register';
  static const String refreshToken = '/api/v1/auth/refresh';
  static const String me = '/api/v1/auth/me';

  // Organisation
  static const String organisations = '/api/v1/organisations';

  // Accounting
  static const String chartOfAccounts = '/api/v1/accounts';
  static const String journalEntries = '/api/v1/journal-entries';

  // Reports
  static const String trialBalance = '/api/v1/reports/trial-balance';
  static const String profitLoss = '/api/v1/reports/profit-loss';
  static const String balanceSheet = '/api/v1/reports/balance-sheet';
  static String generalLedger(String accountId) =>
      '/api/v1/reports/general-ledger/$accountId';

  // AR
  static const String customers = '/api/v1/customers';
  static const String invoices = '/api/v1/invoices';
  static String invoiceById(String id) => '/api/v1/invoices/$id';
  static String sendInvoice(String id) => '/api/v1/invoices/$id/send';
  static String cancelInvoice(String id) => '/api/v1/invoices/$id/cancel';
  static String invoicePayments(String invoiceId) =>
      '/api/v1/invoices/$invoiceId/payments';
  static const String creditNotes = '/api/v1/credit-notes';
  static String issueCreditNote(String id) => '/api/v1/credit-notes/$id/issue';

  // AR Reports
  static const String ageingReport = '/api/v1/ar-reports/ageing';
  static const String gstr1 = '/api/v1/ar-reports/gstr1';

  // AI
  static const String aiQuery = '/api/v1/ai/query';
  static const String aiScanBill = '/api/v1/ai/scan-bill';
}
