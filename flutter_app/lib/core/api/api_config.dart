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
  // F4 BOM — composite item bill of materials (only valid for
  // itemType=COMPOSITE parents; the resolver at invoice-send time is
  // server-side and never hit over HTTP).
  static String itemBom(String parentId) => '/api/v1/items/$parentId/bom';
  static String itemBomComponentById(String componentId) =>
      '/api/v1/items/bom/$componentId';

  // F5 Item groups — variant template + matrix bulk-create.
  // The group is a presentation/inheritance layer; variants stay as
  // regular Item rows with group_id + variant_attributes, so every
  // existing item endpoint (stock, BOM, batches, invoices, GRN, …)
  // keeps working unchanged.
  static const String itemGroups = '/api/v1/item-groups';
  static String itemGroupById(String id) => '/api/v1/item-groups/$id';
  static String itemGroupVariants(String id) => '/api/v1/item-groups/$id/items';
  static String generateVariants(String id) =>
      '/api/v1/item-groups/$id/generate-variants';
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

  // Batches (v2 — perishables / FEFO)
  static String batchesByItem(String itemId) =>
      '/api/v1/batches/item/$itemId';
  /// FEFO-ordered list of batches with non-zero quantity available.
  /// Omit [warehouseId] to fall back to the org's default warehouse
  /// (the backend resolves it via TenantContext).
  static String batchesAvailable(String itemId, {String? warehouseId}) {
    final base = '/api/v1/batches/item/$itemId/available';
    return warehouseId == null ? base : '$base?warehouseId=$warehouseId';
  }
  static String batchById(String id) => '/api/v1/batches/$id';

  // Procurement
  static const String suppliers = '/api/v1/suppliers';
  static String supplierById(String id) => '/api/v1/suppliers/$id';
  static const String stockReceipts = '/api/v1/stock-receipts';
  static String stockReceiptById(String id) => '/api/v1/stock-receipts/$id';
  static String receiveStockReceipt(String id) =>
      '/api/v1/stock-receipts/$id/receive';
  static String cancelStockReceipt(String id) =>
      '/api/v1/stock-receipts/$id/cancel';

  // F7: Expenses
  static const String expenses = '/api/v1/expenses';
  static String expenseById(String id) => '/api/v1/expenses/$id';

  // F9: Estimates / Quotations
  static const String estimates = '/api/v1/estimates';
  static String estimateById(String id) => '/api/v1/estimates/$id';
  static String sendEstimate(String id) => '/api/v1/estimates/$id/send';
  static String acceptEstimate(String id) => '/api/v1/estimates/$id/accept';
  static String declineEstimate(String id) => '/api/v1/estimates/$id/decline';
  static String convertEstimate(String id) =>
      '/api/v1/estimates/$id/convert-to-invoice';

  // F8: Recurring Invoices (templates)
  static const String recurringInvoices = '/api/v1/recurring-invoices';
  static String recurringInvoiceById(String id) =>
      '/api/v1/recurring-invoices/$id';
  static String stopRecurringInvoice(String id) =>
      '/api/v1/recurring-invoices/$id/stop';
  static String resumeRecurringInvoice(String id) =>
      '/api/v1/recurring-invoices/$id/resume';
  static String generateRecurringInvoice(String id) =>
      '/api/v1/recurring-invoices/$id/generate-now';
  static String recurringInvoiceGenerated(String id) =>
      '/api/v1/recurring-invoices/$id/generated-invoices';

  // F6: Contacts (unified customer + vendor)
  static const String contacts = '/api/v1/contacts';
  static String contactById(String id) => '/api/v1/contacts/$id';
  static String contactPersons(String contactId) =>
      '/api/v1/contacts/$contactId/persons';
  static String contactPersonById(String contactId, String personId) =>
      '/api/v1/contacts/$contactId/persons/$personId';

  // F6: Notifications
  static const String notifications = '/api/v1/notifications';
  static const String notificationsUnreadCount =
      '/api/v1/notifications/unread-count';
  static const String notificationsReadAll = '/api/v1/notifications/read-all';

  // Comments
  static String comments(String entityType, String entityId) =>
      '/api/v1/comments/$entityType/$entityId';
  static String commentById(String id) => '/api/v1/comments/$id';

  // AI
  static const String aiQuery = '/api/v1/ai/query';
  static const String aiScanBill = '/api/v1/ai/scan-bill';

  // Pricing (v2 — F3 price lists)
  static const String priceLists = '/api/v1/price-lists';
  static String priceListById(String id) => '/api/v1/price-lists/$id';
  static String priceListItems(String listId) =>
      '/api/v1/price-lists/$listId/items';
  static String priceListItemById(String itemRowId) =>
      '/api/v1/price-lists/items/$itemRowId';
}
