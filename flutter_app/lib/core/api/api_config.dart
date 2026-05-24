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
  static const String register = '/api/v1/auth/register';
  static const String requestOtp = '/api/v1/auth/otp/request';
  static const String verifyOtp = '/api/v1/auth/otp/verify';
  static const String signup = '/api/v1/auth/signup';
  static const String refreshToken = '/api/v1/auth/refresh';
  static const String forgotPassword = '/api/v1/auth/password/forgot';
  static const String resetPassword = '/api/v1/auth/password/reset';
  static const String forgotPasswordEmail = '/api/v1/auth/forgot-password';
  static const String resetPasswordToken = '/api/v1/auth/reset-password';
  static const String verifyEmail = '/api/v1/auth/verify-email';
  static const String resendVerification = '/api/v1/auth/verify-email/resend';
  static const String changePassword = '/api/v1/auth/change-password';
  static const String me = '/api/v1/auth/me';
  static const String myOrgs = '/api/v1/users/me/organisations';
  static const String switchOrg = '/api/v1/users/me/switch-org';
  static const String createAdditionalOrg = '/api/v1/users/me/create-org';

  // Organisation
  static const String organisations = '/api/v1/organisations';
  static String organisationById(String id) => '/api/v1/organisations/$id';

  // Accounting
  static const String chartOfAccounts = '/api/v1/accounts';
  static const String journalEntries = '/api/v1/journal-entries';
  static const String fiscalPeriods = '/api/v1/accounting/periods';
  static String closeFiscalPeriod(int year, int month) =>
      '/api/v1/accounting/periods/$year/$month/close';
  static String reopenFiscalPeriod(int year, int month) =>
      '/api/v1/accounting/periods/$year/$month/reopen';
  static String lockFiscalPeriod(int year, int month) =>
      '/api/v1/accounting/periods/$year/$month/lock';

  // Reports
  static const String trialBalance = '/api/v1/reports/trial-balance';
  static const String profitLoss = '/api/v1/reports/profit-loss';
  static const String balanceSheet = '/api/v1/reports/balance-sheet';
  static String generalLedger(String accountId) =>
      '/api/v1/reports/general-ledger/$accountId';
  static String operationalReport(String key) => '/api/v1/reports/$key';

  // AR
  static const String invoices = '/api/v1/invoices';
  static String invoiceById(String id) => '/api/v1/invoices/$id';
  static String invoicesByContact(String contactId) =>
      '/api/v1/invoices/contact/$contactId';
  static String invoiceWhatsAppLink(String id) =>
      '/api/v1/invoices/$id/whatsapp-link';
  static String invoiceWhatsAppReminder(String id) =>
      '/api/v1/invoices/$id/whatsapp-reminder';
  static String sendInvoice(String id) => '/api/v1/invoices/$id/send';
  static String cancelInvoice(String id) => '/api/v1/invoices/$id/cancel';
  static String invoicePayments(String invoiceId) =>
      '/api/v1/invoices/$invoiceId/payments';
  static String invoicePdf(String id) => '/api/v1/invoices/$id/pdf';
  static const String creditNotes = '/api/v1/credit-notes';
  static String creditNoteById(String id) => '/api/v1/credit-notes/$id';
  static String creditNotePdf(String id) => '/api/v1/credit-notes/$id/pdf';
  static String issueCreditNote(String id) => '/api/v1/credit-notes/$id/issue';

  // AR Reports
  static const String ageingReport = '/api/v1/ar/reports/ageing';

  // GST Returns
  static const String gstr1 = '/api/v1/gst/gstr1';
  static const String gstr3b = '/api/v1/gst/gstr3b';
  static const String gstReviewCenter = '/api/v1/gst/review-center';
  static const String gstr1Export = '/api/v1/gst/gstr1/export';
  static const String gstr3bExport = '/api/v1/gst/gstr3b/export';

  // AI Model Settings
  static const String aiSettings = '/api/v1/settings/ai';
  static const String aiSettingsTest = '/api/v1/settings/ai/test';

  // Contact Ledger
  static String contactLedger(String id) => '/api/v1/contacts/$id/ledger';

  // AP Reports
  static const String apAgeingReport = '/api/v1/ap/reports/ageing';

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
  static String batchesByItem(String itemId) => '/api/v1/batches/item/$itemId';

  /// FEFO-ordered list of batches with non-zero quantity available.
  /// Omit [warehouseId] to fall back to the org's default warehouse
  /// (the backend resolves it via TenantContext).
  static String batchesAvailable(String itemId, {String? warehouseId}) {
    final base = '/api/v1/batches/item/$itemId/available';
    return warehouseId == null ? base : '$base?warehouseId=$warehouseId';
  }

  static String batchById(String id) => '/api/v1/batches/$id';

  // Near-expiry dashboard
  static String nearExpiryBatches({int days = 90}) =>
      '/api/v1/batches/near-expiry?days=$days';
  static const String expirySummary = '/api/v1/batches/expiry-summary';

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
  static String estimatePdf(String id) => '/api/v1/estimates/$id/pdf';
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
  static const String contactImportTemplate =
      '/api/v1/contacts/import/template';
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
  static const String aiSuggestions = '/api/v1/ai/suggestions';
  static const String aiSuggestionsSummary = '/api/v1/ai/suggestions/summary';
  static String aiSuggestionById(String id) => '/api/v1/ai/suggestions/$id';
  static String aiSuggestionReview(String id) =>
      '/api/v1/ai/suggestions/$id/review';
  static const String aiScanBill = '/api/v1/ai/scan-bill';
  static const String aiScanProductLabel = '/api/v1/ai/scan-product-label';
  static const String aiScanPurchaseInvoice =
      '/api/v1/ai/scan-purchase-invoice';

  // Banking / reconciliation
  static const String bankingTransactions = '/api/v1/banking/transactions';
  static const String bankingImportCsv =
      '/api/v1/banking/transactions/import-csv';
  static String bankingRerunMatch(String id) =>
      '/api/v1/banking/transactions/$id/rerun-match';
  static String bankingIgnoreTransaction(String id) =>
      '/api/v1/banking/transactions/$id/ignore';
  static String bankingAcceptMatch(String id) =>
      '/api/v1/banking/matches/$id/accept';
  static String bankingRejectMatch(String id) =>
      '/api/v1/banking/matches/$id/reject';

  // Branches (multi-branch rollup)
  static const String branches = '/api/v1/branches';
  static String branchById(String id) => '/api/v1/branches/$id';

  // Dashboard aggregation
  static const String dashboardTodaySales = '/api/v1/dashboard/today-sales';
  static const String dashboardTopSelling = '/api/v1/dashboard/top-selling';
  static const String dashboardApSummary = '/api/v1/dashboard/ap-summary';
  static const String dashboardRecentBills = '/api/v1/dashboard/recent-bills';
  static const String dashboardReceivables = '/api/v1/dashboard/receivables';
  static const String dashboardMonthlyProfit =
      '/api/v1/dashboard/monthly-profit';
  static const String dashboardRevenueTrend = '/api/v1/dashboard/revenue-trend';
  static const String dashboardDailySummary = '/api/v1/dashboard/daily-summary';
  static const String dashboardExpiringSoon = '/api/v1/dashboard/expiring-soon';
  static const String dashboardOutstandingReceivable =
      '/api/v1/dashboard/outstanding-receivable';
  static const String dashboardCashFlow = '/api/v1/dashboard/cash-flow';
  static const String dashboardRecentJournals =
      '/api/v1/dashboard/recent-journals';
  static const String profitLossReport = '/api/v1/reports/profit-loss';
  static const String arAgeing = '/api/v1/ar/reports/ageing';
  static const String apAgeing = '/api/v1/ap/reports/ageing';

  // Team / User Management
  static const String orgUsers = '/api/v1/org/users';
  static const String orgPendingInvites = '/api/v1/org/users/invites';
  static const String orgInvite = '/api/v1/org/users/invite';
  static String orgUserRole(String userId) => '/api/v1/org/users/$userId/role';
  static String orgUserDeactivate(String userId) =>
      '/api/v1/org/users/$userId/deactivate';
  static String orgUserReactivate(String userId) =>
      '/api/v1/org/users/$userId/reactivate';
  static String orgInviteResend(String inviteId) =>
      '/api/v1/org/users/invites/$inviteId/resend';
  static String orgInviteCancel(String inviteId) =>
      '/api/v1/org/users/invites/$inviteId';

  // Platform admin (v1 — legacy)
  static const String platformOrganisations =
      '/api/v1/platform-admin/organisations';
  static String platformOrgUsers(String orgId) =>
      '/api/v1/platform-admin/organisations/$orgId/users';
  static String platformApproveOrg(String orgId) =>
      '/api/v1/platform-admin/organisations/$orgId/approve';
  static String platformRejectOrg(String orgId) =>
      '/api/v1/platform-admin/organisations/$orgId/reject';
  static String platformResetPassword(String userId) =>
      '/api/v1/platform-admin/users/$userId/reset-password';

  // Platform admin v2 (new base path)
  static const String platformAdminLogin = '/api/platform-admin/v1/auth/login';
  static const String platformAdminStats =
      '/api/platform-admin/v1/dashboard/stats';
  static const String platformAdminOrgsV2 = '/api/platform-admin/v1/orgs';
  static String platformAdminOrgDetailV2(String orgId) =>
      '/api/platform-admin/v1/orgs/$orgId';
  static String platformAdminApproveOrgV2(String orgId) =>
      '/api/platform-admin/v1/orgs/$orgId/approve';
  static String platformAdminRejectOrgV2(String orgId) =>
      '/api/platform-admin/v1/orgs/$orgId/reject';
  static String platformAdminSuspendOrg(String orgId) =>
      '/api/platform-admin/v1/orgs/$orgId/suspend';
  static String platformAdminReactivateOrg(String orgId) =>
      '/api/platform-admin/v1/orgs/$orgId/reactivate';
  static const String platformAdminUsersV2 = '/api/platform-admin/v1/users';
  static String platformAdminUserDetailV2(String userId) =>
      '/api/platform-admin/v1/users/$userId';
  static String platformAdminResetUserPasswordV2(String userId) =>
      '/api/platform-admin/v1/users/$userId/reset-password';
  static String platformAdminDeactivateUser(String userId) =>
      '/api/platform-admin/v1/users/$userId/deactivate';
  static String platformAdminReactivateUser(String userId) =>
      '/api/platform-admin/v1/users/$userId/reactivate';
  static const String platformAdminAuditLog =
      '/api/platform-admin/v1/audit-log';

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

  // Credit Reminders
  static const String creditRemindersOverdue =
      '/api/v1/ar/credit-reminders/overdue';
  static String creditReminderOutstanding(String contactId) =>
      '/api/v1/ar/credit-reminders/$contactId/outstanding';
  static String creditReminderText(String contactId) =>
      '/api/v1/ar/credit-reminders/$contactId/reminder-text';
  static String creditReminderMarkSent(String contactId) =>
      '/api/v1/ar/credit-reminders/$contactId/mark-sent';

  // POS — Sales Receipts
  static const String salesReceipts = '/api/v1/sales-receipts';
  static String salesReceiptById(String id) => '/api/v1/sales-receipts/$id';
  static String salesReceiptPrint(String id) =>
      '/api/v1/sales-receipts/$id/print';
  static String salesReceiptWhatsAppLink(String id) =>
      '/api/v1/sales-receipts/$id/whatsapp-link';
  static String customerPurchaseHistory(String contactId) =>
      '/api/v1/sales-receipts/customer/$contactId/history';
  static const String posSearch = '/api/v1/items/pos-search';

  // Sales Orders
  static const String salesOrders = '/api/v1/sales-orders';
  static String salesOrderById(String id) => '/api/v1/sales-orders/$id';
  static String confirmSalesOrder(String id) =>
      '/api/v1/sales-orders/$id/confirm';
  static String cancelSalesOrder(String id) =>
      '/api/v1/sales-orders/$id/cancel';
  static String convertSalesOrderToInvoice(String id) =>
      '/api/v1/sales-orders/$id/convert-to-invoice';
  static String salesOrderFromEstimate(String estimateId) =>
      '/api/v1/sales-orders/from-estimate/$estimateId';
  static String salesOrderReservations(String id) =>
      '/api/v1/sales-orders/$id/reservations';
  static String salesOrderInvoices(String id) =>
      '/api/v1/sales-orders/$id/invoices';
  static String salesOrderPdf(String id) => '/api/v1/sales-orders/$id/pdf';

  // Delivery Challans
  static const String deliveryChallans = '/api/v1/delivery-challans';
  static String deliveryChallanById(String id) =>
      '/api/v1/delivery-challans/$id';
  static String dispatchChallan(String id) =>
      '/api/v1/delivery-challans/$id/dispatch';
  static String deliverChallan(String id) =>
      '/api/v1/delivery-challans/$id/deliver';
  static String cancelChallan(String id) =>
      '/api/v1/delivery-challans/$id/cancel';
  static String deliveryChallanPdf(String id) =>
      '/api/v1/delivery-challans/$id/pdf';
  static String challansBySalesOrder(String soId) =>
      '/api/v1/delivery-challans/by-sales-order/$soId';

  // Pricing (v2 — F3 price lists)
  static const String priceLists = '/api/v1/price-lists';
  static String priceListById(String id) => '/api/v1/price-lists/$id';
  static String priceListItems(String listId) =>
      '/api/v1/price-lists/$listId/items';
  static String priceListItemById(String itemRowId) =>
      '/api/v1/price-lists/items/$itemRowId';

  // Schemes (promotional offers — Buy X Get Y, % discount)
  static const String schemes = '/api/v1/schemes';
  static String schemeById(String id) => '/api/v1/schemes/$id';
  static String schemesApplicable(String itemId, double qty) =>
      '/api/v1/schemes/applicable?itemId=$itemId&quantity=$qty';

  // Purchase Orders
  static const String purchaseOrders = '/api/v1/purchase-orders';
  static String purchaseOrderById(String id) => '/api/v1/purchase-orders/$id';
  static String sendPurchaseOrder(String id) =>
      '/api/v1/purchase-orders/$id/send';
  static String cancelPurchaseOrder(String id) =>
      '/api/v1/purchase-orders/$id/cancel';
}
