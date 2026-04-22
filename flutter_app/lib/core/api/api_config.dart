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
  static const String myOrgs = '/api/v1/users/me/organisations';
  static const String switchOrg = '/api/v1/users/me/switch-org';

  // Organisation
  static const String organisations = '/api/v1/organisations';
  static String organisationById(String id) => '/api/v1/organisations/$id';

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
  static const String invoices = '/api/v1/invoices';
  static String invoiceById(String id) => '/api/v1/invoices/$id';
  static String invoiceWhatsAppLink(String id) =>
      '/api/v1/invoices/$id/whatsapp-link';
  static String invoiceWhatsAppReminder(String id) =>
      '/api/v1/invoices/$id/whatsapp-reminder';
  static String sendInvoice(String id) => '/api/v1/invoices/$id/send';
  static String cancelInvoice(String id) => '/api/v1/invoices/$id/cancel';
  static String invoicePayments(String invoiceId) =>
      '/api/v1/invoices/$invoiceId/payments';
  static const String creditNotes = '/api/v1/credit-notes';
  static String issueCreditNote(String id) => '/api/v1/credit-notes/$id/issue';

  // AR Reports
  static const String ageingReport = '/api/v1/ar-reports/ageing';
  static const String gstr1 = '/api/v1/ar-reports/gstr1';

  // AP Reports
  static const String apAgeingReport = '/api/v1/reports/ap-ageing';

  // Inventory
  static const String items = '/api/v1/items';
  static String itemById(String id) => '/api/v1/items/$id';
  static const String itemImport = '/api/v1/items/import';
  static const String itemImportPreview = '/api/v1/items/import/preview';
  static const String itemImportTemplate = '/api/v1/items/import/template';
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
  static String estimateWhatsAppLink(String id) =>
      '/api/v1/estimates/$id/whatsapp-link';
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
  static const String contactImport = '/api/v1/contacts/import';
  static const String contactImportPreview = '/api/v1/contacts/import/preview';
  static const String contactImportTemplate = '/api/v1/contacts/import/template';
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

  // Branches (multi-branch rollup)
  static const String branches = '/api/v1/branches';
  static String branchById(String id) => '/api/v1/branches/$id';

  // Dashboard aggregation
  static const String dashboardTodaySales = '/api/v1/dashboard/today-sales';
  static const String dashboardTopSelling = '/api/v1/dashboard/top-selling';
  static const String dashboardApSummary = '/api/v1/dashboard/ap-summary';
  static const String dashboardRecentBills = '/api/v1/dashboard/recent-bills';
  static const String dashboardReceivables = '/api/v1/dashboard/receivables';
  static const String dashboardMonthlyProfit = '/api/v1/dashboard/monthly-profit';
  static const String dashboardRevenueTrend = '/api/v1/dashboard/revenue-trend';
  static const String dashboardDailySummary = '/api/v1/dashboard/daily-summary';
  static const String dashboardExpiringSoon = '/api/v1/dashboard/expiring-soon';
  static const String dashboardOutstandingReceivable = '/api/v1/dashboard/outstanding-receivable';
  static const String dashboardCashFlow = '/api/v1/dashboard/cash-flow';
  static const String dashboardRecentJournals = '/api/v1/dashboard/recent-journals';
  static const String profitLossReport = '/api/v1/reports/profit-loss';
  static const String arAgeing = '/api/v1/ar/reports/ageing';
  static const String apAgeing = '/api/v1/ap/reports/ageing';

  // Demo seeding (owner-only, idempotent)
  static const String demoSeedSharmaMedical =
      '/api/v1/demo/seed-sharma-medical';

  // AP — Purchase Bills
  static const String bills = '/api/v1/bills';
  static String billById(String id) => '/api/v1/bills/$id';
  static String billWhatsAppLink(String id) =>
      '/api/v1/bills/$id/whatsapp-link';
  static String postBill(String id) => '/api/v1/bills/$id/post';
  static String voidBill(String id) => '/api/v1/bills/$id/void';
  static String billPdf(String id) => '/api/v1/bills/$id/pdf';
  static String billPayments(String id) => '/api/v1/bills/$id/payments';
  static String billComments(String id) => '/api/v1/bills/$id/comments';
  static String billAttachments(String id) => '/api/v1/bills/$id/attachments';

  // Bulk operations
  static const String bulkSendInvoices = '/api/v1/invoices/bulk-send';
  static const String bulkCancelInvoices = '/api/v1/invoices/bulk-cancel';
  static const String bulkSendEstimates = '/api/v1/estimates/bulk-send';
  static const String bulkDeleteEstimates = '/api/v1/estimates/bulk-delete';
  static const String bulkPostBills = '/api/v1/bills/bulk-post';
  static const String bulkVoidBills = '/api/v1/bills/bulk-void';

  // AP — Vendor Payments
  static const String vendorPayments = '/api/v1/vendor-payments';
  static String vendorPaymentById(String id) => '/api/v1/vendor-payments/$id';
  static String voidVendorPayment(String id) =>
      '/api/v1/vendor-payments/$id/void';

  // AP — Vendor Credits
  static const String vendorCredits = '/api/v1/vendor-credits';
  static String vendorCreditById(String id) => '/api/v1/vendor-credits/$id';
  static String postVendorCredit(String id) =>
      '/api/v1/vendor-credits/$id/post';
  static String voidVendorCredit(String id) =>
      '/api/v1/vendor-credits/$id/void';
  static String applyVendorCredit(String id) =>
      '/api/v1/vendor-credits/$id/apply';

  // AP — Tax Groups
  static const String taxGroups = '/api/v1/tax-groups';
  static String taxGroupById(String id) => '/api/v1/tax-groups/$id';

  // Settings — Default GL Accounts (per org, by purpose)
  static const String defaultAccounts = '/api/v1/settings/default-accounts';

  // Settings — Tax Account Mapping (per-rate GL bindings)
  static const String taxAccountMappings = '/api/v1/settings/tax-accounts';
  static const String taxAccountMappingsReset =
      '/api/v1/settings/tax-accounts/reset';

  // POS — Sales Receipts
  static const String salesReceipts = '/api/v1/sales-receipts';
  static String salesReceiptById(String id) => '/api/v1/sales-receipts/$id';
  static String salesReceiptPrint(String id) => '/api/v1/sales-receipts/$id/print';
  static String salesReceiptWhatsAppLink(String id) =>
      '/api/v1/sales-receipts/$id/whatsapp-link';
  static const String posSearch = '/api/v1/items/pos-search';

  // Sales Orders
  static const String salesOrders = '/api/v1/sales-orders';
  static String salesOrderById(String id) => '/api/v1/sales-orders/$id';
  static String confirmSalesOrder(String id) => '/api/v1/sales-orders/$id/confirm';
  static String cancelSalesOrder(String id) => '/api/v1/sales-orders/$id/cancel';
  static String convertSalesOrderToInvoice(String id) => '/api/v1/sales-orders/$id/convert-to-invoice';
  static String salesOrderFromEstimate(String estimateId) => '/api/v1/sales-orders/from-estimate/$estimateId';
  static String salesOrderReservations(String id) => '/api/v1/sales-orders/$id/reservations';
  static String salesOrderInvoices(String id) => '/api/v1/sales-orders/$id/invoices';

  // Delivery Challans
  static const String deliveryChallans = '/api/v1/delivery-challans';
  static String deliveryChallanById(String id) => '/api/v1/delivery-challans/$id';
  static String dispatchChallan(String id) => '/api/v1/delivery-challans/$id/dispatch';
  static String deliverChallan(String id) => '/api/v1/delivery-challans/$id/deliver';
  static String cancelChallan(String id) => '/api/v1/delivery-challans/$id/cancel';
  static String challansBySalesOrder(String soId) => '/api/v1/delivery-challans/by-sales-order/$soId';

  // Pricing (v2 — F3 price lists)
  static const String priceLists = '/api/v1/price-lists';
  static String priceListById(String id) => '/api/v1/price-lists/$id';
  static String priceListItems(String listId) =>
      '/api/v1/price-lists/$listId/items';
  static String priceListItemById(String itemRowId) =>
      '/api/v1/price-lists/items/$itemRowId';
}
