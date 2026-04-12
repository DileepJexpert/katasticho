import '../config/env_config.dart';

/// API configuration constants.
class ApiConfig {
  ApiConfig._();

  // Base URL — resolved from EnvConfig (--dart-define at build time)
  static String get baseUrl => EnvConfig.apiBaseUrl;

  // Timeouts — longer in dev for debugging
  static Duration get connectTimeout => EnvConfig.connectTimeout;
  static Duration get receiveTimeout => EnvConfig.receiveTimeout;

  // Auth endpoints
  static const String login = '/api/v1/auth/login';
  static const String requestOtp = '/api/v1/auth/otp/request';
  static const String verifyOtp = '/api/v1/auth/otp/verify';
  static const String signup = '/api/v1/auth/signup';
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

  // Inventory
  static const String items = '/api/v1/items';
  static String itemById(String id) => '/api/v1/items/$id';
  static const String itemImport = '/api/v1/items/import';
  static const String itemImportPreview = '/api/v1/items/import/preview';
  static const String warehouses = '/api/v1/warehouses';
  static const String stockAdjust = '/api/v1/stock/adjust';
  static String stockReverse(String movementId) =>
      '/api/v1/stock/movements/$movementId/reverse';
  static String itemMovements(String itemId) =>
      '/api/v1/stock/items/$itemId/movements';
  static String itemBalances(String itemId) =>
      '/api/v1/stock/items/$itemId/balances';
  static const String lowStock = '/api/v1/stock/low-stock';
  static const String uoms = '/api/v1/uoms';
  static String uomById(String id) => '/api/v1/uoms/$id';

  // Procurement
  static const String suppliers = '/api/v1/suppliers';
  static String supplierById(String id) => '/api/v1/suppliers/$id';
  static const String stockReceipts = '/api/v1/stock-receipts';
  static String stockReceiptById(String id) => '/api/v1/stock-receipts/$id';
  static String receiveStockReceipt(String id) =>
      '/api/v1/stock-receipts/$id/receive';
  static String cancelStockReceipt(String id) =>
      '/api/v1/stock-receipts/$id/cancel';

  // AI
  static const String aiQuery = '/api/v1/ai/query';
  static const String aiScanBill = '/api/v1/ai/scan-bill';
}
