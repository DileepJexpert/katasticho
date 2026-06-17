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
  // GSTR-2B reconciliation
  static const String gstr2bUpload = '/api/v1/gst/gstr2b/upload';
  static const String gstr2b = '/api/v1/gst/gstr2b';
  static const String gstr2bSummary = '/api/v1/gst/gstr2b/summary';
  // e-Way bills
  static const String ewayBills = '/api/v1/gst/eway-bills';
  static String ewayBillRecord(String id) => '/api/v1/gst/eway-bills/$id/record';
  static String ewayBillCancel(String id) => '/api/v1/gst/eway-bills/$id/cancel';
  static String ewayBillPortalJson(String id) =>
      '/api/v1/gst/eway-bills/$id/portal-json';
  static const String ewayBillCheckVehicle =
      '/api/v1/gst/eway-bills/check-vehicle';
  // Compliance calendar
  static const String gstComplianceCalendar = '/api/v1/gst/compliance-calendar';
  // e-Invoice (IRN)
  static const String eInvoices = '/api/v1/gst/einvoices';
  static String eInvoiceRecord(String id) => '/api/v1/gst/einvoices/$id/record';
  static String eInvoiceCancel(String id) => '/api/v1/gst/einvoices/$id/cancel';
  static String eInvoicePortalJson(String id) =>
      '/api/v1/gst/einvoices/$id/portal-json';
  static const String eInvoiceSettings = '/api/v1/gst/einvoices/settings';
  // TDS
  static const String tdsRegister = '/api/v1/tds/register';
  static const String tds26q = '/api/v1/tds/26q';

  // TCS 206C(1H) (auto-collected on invoices past ₹50L/buyer/FY)
  static const String tcsRegister = '/api/v1/tcs/register';
  static const String tcs27eq = '/api/v1/tcs/27eq';
  static const String tcsSettings = '/api/v1/tcs/settings';

  // GST composition scheme (CMP-08 quarterly + GSTR-4 annual)
  static const String gstCmp08 = '/api/v1/gst/composition/cmp08';
  static const String gstCompositionSettings = '/api/v1/gst/composition/settings';

  // Tally migration
  static const String tallyImportPreview = '/api/v1/migration/tally/preview';
  static const String tallyImport = '/api/v1/migration/tally/import';
  static const String tallyVoucherPreview = '/api/v1/migration/tally/vouchers/preview';
  static const String tallyVoucherImport = '/api/v1/migration/tally/vouchers/import';
  static const String tallyVerifyTb = '/api/v1/migration/tally/verify-trial-balance';
  static const String tallyExportVouchers = '/api/v1/migration/tally/export-vouchers';

  // POS Cash Register
  static const String cashRegisterToday   = '/api/v1/pos/cash-register/today';
  static const String cashRegisterOpen    = '/api/v1/pos/cash-register/open';
  static const String cashRegisterClose   = '/api/v1/pos/cash-register/close';
  static const String cashRegisterExpense = '/api/v1/pos/cash-register/expense';
  static const String cashRegisterHistory = '/api/v1/pos/cash-register/history';
  static String cashRegisterDeleteExpense(String id) => '/api/v1/pos/cash-register/expense/$id';
  static String cashRegisterByDate(String date) => '/api/v1/pos/cash-register/$date';

  // AI Model Settings
  static const String orgSettings = '/api/v1/settings';
  static const String upiSettings = '/api/v1/settings/upi';
  static const String smsSettings = '/api/v1/settings/sms';
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

  // Barcode lookup
  static String itemByBarcode(String barcode) =>
      '/api/v1/items/by-barcode/$barcode';

  // Stock Counts
  static const String stockCounts = '/api/v1/stock-counts';
  static String stockCountById(String id) => '/api/v1/stock-counts/$id';
  static String postStockCount(String id) => '/api/v1/stock-counts/$id/post';
  static String cancelStockCount(String id) =>
      '/api/v1/stock-counts/$id/cancel';

  // Transfer Orders
  static const String transferOrders = '/api/v1/transfer-orders';
  static String transferOrderById(String id) =>
      '/api/v1/transfer-orders/$id';
  static String shipTransferOrder(String id) =>
      '/api/v1/transfer-orders/$id/ship';
  static String receiveTransferOrder(String id) =>
      '/api/v1/transfer-orders/$id/receive';
  static String cancelTransferOrder(String id) =>
      '/api/v1/transfer-orders/$id/cancel';

  // Picklists
  static const String picklists = '/api/v1/picklists';
  static String picklistById(String id) => '/api/v1/picklists/$id';
  static String picklistsBySalesOrder(String soId) =>
      '/api/v1/picklists/by-sales-order/$soId';
  static String startPicklist(String id) => '/api/v1/picklists/$id/start';
  static String picklistLines(String id) => '/api/v1/picklists/$id/lines';
  static String completePicklist(String id) =>
      '/api/v1/picklists/$id/complete';
  static String cancelPicklist(String id) => '/api/v1/picklists/$id/cancel';

  // Serial Numbers
  static const String serialNumbers = '/api/v1/serial-numbers';
  static String serialNumbersReceive = '/api/v1/serial-numbers/receive';
  static String serialNumbersAssignSale = '/api/v1/serial-numbers/assign-sale';
  static String serialNumbersByItem(String itemId) =>
      '/api/v1/serial-numbers/by-item/$itemId';
  static String serialNumbersAvailable(String itemId) =>
      '/api/v1/serial-numbers/available/$itemId';

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
  // API keys (programmatic access / MCP server)
  static const String apiKeys = '/api/v1/api-keys';
  static String apiKeyById(String id) => '/api/v1/api-keys/$id';
  // AI-first bill drafting ("draft, don't type")
  static const String aiBillDrafts = '/api/v1/ai/bill-drafts';
  static String aiBillDraftApprove(String suggestionId) =>
      '/api/v1/ai/bill-drafts/$suggestionId/approve';
  static String aiBillDraftReject(String suggestionId) =>
      '/api/v1/ai/bill-drafts/$suggestionId/reject';

  // Proactive agents (collections, month-close, anomalies)
  static const String aiProactiveRun = '/api/v1/ai/agents/proactive/run';

  // Conversational entry ("type a sentence, get a drafted transaction")
  static const String aiEntry = '/api/v1/ai/entry';
  static String aiEntryApprove(String suggestionId) =>
      '/api/v1/ai/entry/$suggestionId/approve';
  static String aiEntryReject(String suggestionId) =>
      '/api/v1/ai/entry/$suggestionId/reject';

  // Banking / reconciliation
  static const String bankingTransactions = '/api/v1/banking/transactions';
  static const String bankingImportCsv =
      '/api/v1/banking/transactions/import-csv';
  static const String bankingImportFile =
      '/api/v1/banking/transactions/import-file';
  static const String bankingSummary = '/api/v1/banking/summary';
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
  static const String dashboardSoAlerts = '/api/v1/dashboard/so-alerts';
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
  static String platformAdminUpdateOrgPlan(String orgId) =>
      '/api/platform-admin/v1/orgs/$orgId/plan';
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
  static const String creditRemindersRisk = '/api/v1/ar/credit-reminders/risk';
  static String creditReminderOutstanding(String contactId) =>
      '/api/v1/ar/credit-reminders/$contactId/outstanding';
  static String creditReminderText(String contactId) =>
      '/api/v1/ar/credit-reminders/$contactId/reminder-text';
  static String creditReminderMarkSent(String contactId) =>
      '/api/v1/ar/credit-reminders/$contactId/mark-sent';
  static String creditReminderFollowUps(String contactId) =>
      '/api/v1/ar/credit-reminders/$contactId/follow-ups';

  // Loyalty / Customer Wallet
  static const String wallet = '/api/v1/wallet';
  static String walletByContact(String contactId) =>
      '/api/v1/wallet/contact/$contactId';
  static String walletTransactions(String contactId) =>
      '/api/v1/wallet/contact/$contactId/transactions';
  static String walletRedeemable(String contactId) =>
      '/api/v1/wallet/contact/$contactId/redeemable';
  static const String walletEarn = '/api/v1/wallet/earn';
  static const String walletRedeem = '/api/v1/wallet/redeem';

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
  static String posCreateFromDrug(String drugId) =>
      '/api/v1/items/from-drug/$drugId';

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

  // Drug Licenses & Compliance (pharma)
  static const String drugLicenses = '/api/v1/drug-licenses';
  static String drugLicenseById(String id) => '/api/v1/drug-licenses/$id';
  static const String drugLicensesExpiring = '/api/v1/drug-licenses/expiring';

  // Pharma — Prescriptions
  static const String prescriptions = '/api/v1/prescriptions';
  static String prescriptionById(String id) => '/api/v1/prescriptions/$id';
  static String prescriptionsByContact(String contactId) =>
      '/api/v1/prescriptions/by-contact/$contactId';
  static String prescriptionsByReceipt(String receiptId) =>
      '/api/v1/prescriptions/by-receipt/$receiptId';

  // Purchase Orders
  static const String purchaseOrders = '/api/v1/purchase-orders';
  static String purchaseOrderById(String id) => '/api/v1/purchase-orders/$id';
  static String sendPurchaseOrder(String id) =>
      '/api/v1/purchase-orders/$id/send';
  static String cancelPurchaseOrder(String id) =>
      '/api/v1/purchase-orders/$id/cancel';

  // Debit Notes (Supplier / Purchase Returns)
  static const String debitNotes = '/api/v1/debit-notes';
  static String debitNoteById(String id) => '/api/v1/debit-notes/$id';
  static String submitDebitNote(String id) => '/api/v1/debit-notes/$id/submit';

  // Drug Master (platform reference — all pharma clients)
  static const String drugMasterSearch = '/api/v1/drug-master/search';
  static String drugMasterById(String id) => '/api/v1/drug-master/$id';
  static const String saltMasterSearch = '/api/v1/drug-master/salts/search';

  // Pharmacy reference masters
  static const String manufacturerMasterSearch =
      '/api/v1/pharmacy-masters/manufacturers/search';
  static const String hsnGstMasterSearch =
      '/api/v1/pharmacy-masters/hsn/search';
  static const String pharmacyHsnUpsert = '/api/v1/pharmacy-masters/hsn';
  static String hsnGstByCode(String code) =>
      '/api/v1/pharmacy-masters/hsn/$code';
  // GST reference (ungated — all orgs need state codes for address/GSTIN entry)
  static const String gstStateCodes = '/api/v1/reference/state-codes';
  static String gstStateByGstin(String gstin) =>
      '/api/v1/reference/state-codes/by-gstin/$gstin';

  static const String rackLocations = '/api/v1/pharmacy-masters/rack-locations';
  static const String rackLocationsSeedDemo =
      '/api/v1/pharmacy-masters/rack-locations/seed-demo';
  static const String genericSubstitutions =
      '/api/v1/pharmacy-masters/substitutions';
  static const String drugInteractionCheck =
      '/api/v1/pharmacy-masters/interactions/check';
  static const String drugInteractionCheckByComposition =
      '/api/v1/pharmacy-masters/interactions/check-by-composition';

  // HR portal — Leave management
  static const String hrLeaveTypes = '/api/v1/hr/leave/types';
  static const String hrLeaveApply = '/api/v1/hr/leave/apply';
  static String hrLeaveApprove(String id) => '/api/v1/hr/leave/$id/approve';
  static String hrLeaveReject(String id) => '/api/v1/hr/leave/$id/reject';
  static String hrLeaveCancel(String id) => '/api/v1/hr/leave/$id/cancel';
  static const String hrLeaveMine = '/api/v1/hr/leave/me';
  static const String hrLeavePending = '/api/v1/hr/leave/pending';
  static const String hrLeaveBalances = '/api/v1/hr/leave/my-balances';
  static const String hrHolidays = '/api/v1/hr/leave/holidays';

  // HR portal — Attendance management
  static const String hrAttendanceRegs = '/api/v1/hr/attendance/regularizations';
  static const String hrAttendanceRegsMine =
      '/api/v1/hr/attendance/regularizations/me';
  static const String hrAttendanceRegsPending =
      '/api/v1/hr/attendance/regularizations/pending';
  static String hrAttendanceRegApprove(String id) =>
      '/api/v1/hr/attendance/regularizations/$id/approve';
  static String hrAttendanceRegReject(String id) =>
      '/api/v1/hr/attendance/regularizations/$id/reject';
  static const String hrAttendanceSummaryMe = '/api/v1/hr/attendance/summary/me';

  // HR portal — Shift management
  static const String hrShifts = '/api/v1/hr/shifts';
  static const String hrShiftAssignments = '/api/v1/hr/shifts/assignments';

  // HR portal — Timesheets
  static const String hrTimesheets = '/api/v1/hr/timesheets';
  static const String hrTimesheetSubmit = '/api/v1/hr/timesheets/submit';
  static const String hrTimesheetMine = '/api/v1/hr/timesheets/me';
  static const String hrTimesheetPending = '/api/v1/hr/timesheets/pending';
  static const String hrTimesheetSummary = '/api/v1/hr/timesheets/summary';
  static String hrTimesheetApprove(String id) =>
      '/api/v1/hr/timesheets/$id/approve';
  static String hrTimesheetReject(String id) => '/api/v1/hr/timesheets/$id/reject';

  // HR portal — Help Desk
  static const String hrHelpdeskTickets = '/api/v1/hr/helpdesk/tickets';
  static const String hrHelpdeskMine = '/api/v1/hr/helpdesk/tickets/me';
  static const String hrHelpdeskOpen = '/api/v1/hr/helpdesk/tickets/open';
  static String hrHelpdeskTicket(String id) => '/api/v1/hr/helpdesk/tickets/$id';
  static String hrHelpdeskComments(String id) =>
      '/api/v1/hr/helpdesk/tickets/$id/comments';
  static String hrHelpdeskAssign(String id) =>
      '/api/v1/hr/helpdesk/tickets/$id/assign';
  static String hrHelpdeskStatus(String id) =>
      '/api/v1/hr/helpdesk/tickets/$id/status';

  // HR portal — Employee documents
  static const String hrDocumentsMine = '/api/v1/hr/documents/me';
  static const String hrDocumentsExpiring = '/api/v1/hr/documents/expiring';
  static String hrDocumentById(String id) => '/api/v1/hr/documents/$id';

  // HR portal — Analytics
  static const String hrAnalyticsDashboard = '/api/v1/hr/analytics/dashboard';

  // HR portal — Offboarding
  static const String hrOffboarding = '/api/v1/hr/offboarding';
  static String hrOffboardingById(String id) => '/api/v1/hr/offboarding/$id';
  static String hrOffboardingTaskComplete(String taskId) =>
      '/api/v1/hr/offboarding/tasks/$taskId/complete';
  static String hrOffboardingFnf(String id) => '/api/v1/hr/offboarding/$id/fnf';
  static String hrOffboardingComplete(String id) =>
      '/api/v1/hr/offboarding/$id/complete';
  static String hrOffboardingCancel(String id) =>
      '/api/v1/hr/offboarding/$id/cancel';

  // HR portal — Employee depth + self-service (module 2)
  static const String hrMyProfile = '/api/v1/hr/employees/me';
  static const String hrMyFamily = '/api/v1/hr/employees/me/family';
  static String hrMyFamilyById(String id) => '/api/v1/hr/employees/me/family/$id';
  static const String hrMyEducation = '/api/v1/hr/employees/me/education';
  static String hrMyEducationById(String id) =>
      '/api/v1/hr/employees/me/education/$id';
  static const String hrMyExperience = '/api/v1/hr/employees/me/experience';
  static String hrMyExperienceById(String id) =>
      '/api/v1/hr/employees/me/experience/$id';
  static String hrEmployeeFamily(String employeeId) =>
      '/api/v1/hr/employees/$employeeId/family';
  static String hrEmployeeEducation(String employeeId) =>
      '/api/v1/hr/employees/$employeeId/education';
  static String hrEmployeeExperience(String employeeId) =>
      '/api/v1/hr/employees/$employeeId/experience';

  // Payroll
  static const String payrollSettings = '/api/v1/payroll/settings';
  static const String payrollEmployees = '/api/v1/payroll/employees';
  static String payrollEmployee(String id) => '/api/v1/payroll/employees/$id';
  static String employeeSalaryStructure(String employeeId) =>
      '/api/v1/payroll/employees/$employeeId/salary-structure';
  static const String salaryComponents = '/api/v1/payroll/salary-components';
  static String salaryComponent(String id) =>
      '/api/v1/payroll/salary-components/$id';
  static const String payrollRuns = '/api/v1/payroll/runs';
  static String payrollRun(String id) => '/api/v1/payroll/runs/$id';
  static String calculatePayrollRun(String id) =>
      '/api/v1/payroll/runs/$id/calculate';
  static String approvePayrollRun(String id) =>
      '/api/v1/payroll/runs/$id/approve';
  static String postPayrollRun(String id) => '/api/v1/payroll/runs/$id/post';
  static String cancelPayrollRun(String id) =>
      '/api/v1/payroll/runs/$id/cancel';
  static String payrollRunPayslips(String runId) =>
      '/api/v1/payroll/runs/$runId/payslips';
  static String payslip(String id) => '/api/v1/payroll/payslips/$id';
  static String payrollRunPayment(String runId) =>
      '/api/v1/payroll/runs/$runId/payment';
  static const String statutoryPayments = '/api/v1/payroll/statutory-payments';

  // Field Sales / FMCG Execution
  static const String fieldSalesBeats = '/api/v1/field-sales/beats';
  static String fieldSalesBeatById(String id) =>
      '/api/v1/field-sales/beats/$id';
  static String fieldSalesBeatCustomers(String beatId) =>
      '/api/v1/field-sales/beats/$beatId/customers';
  static String fieldSalesBeatCustomer(String beatId, String contactId) =>
      '/api/v1/field-sales/beats/$beatId/customers/$contactId';
  static const String fieldSalesRoutes = '/api/v1/field-sales/routes';
  static String fieldSalesRouteById(String id) =>
      '/api/v1/field-sales/routes/$id';
  static String fieldSalesRouteBeats(String routeId) =>
      '/api/v1/field-sales/routes/$routeId/beats';
  static const String fieldSalesVans = '/api/v1/field-sales/vans';
  static String fieldSalesVanById(String id) =>
      '/api/v1/field-sales/vans/$id';
  static String fieldSalesVanStock(String vanId) =>
      '/api/v1/field-sales/vans/$vanId/stock';
  static const String fieldSalesAssignments = '/api/v1/field-sales/assignments';
  static String fieldSalesAssignmentsBySalesperson(String id) =>
      '/api/v1/field-sales/assignments/salesperson/$id';
  static const String fieldSalesVanTransfersLoad =
      '/api/v1/field-sales/van-transfers/load';
  static const String fieldSalesVanTransfersReturn =
      '/api/v1/field-sales/van-transfers/return';
  static String fieldSalesVanTransferConfirmLoad(String id) =>
      '/api/v1/field-sales/van-transfers/$id/confirm-load';
  static String fieldSalesVanTransferConfirmReturn(String id) =>
      '/api/v1/field-sales/van-transfers/$id/confirm-return';
  static String fieldSalesVanTransfersByVan(String vanId) =>
      '/api/v1/field-sales/van-transfers/van/$vanId';
  static String fieldSalesVanTransferLines(String id) =>
      '/api/v1/field-sales/van-transfers/$id/lines';
  static const String fieldSalesExecutions = '/api/v1/field-sales/executions';
  static String fieldSalesExecutionById(String id) =>
      '/api/v1/field-sales/executions/$id';
  static String fieldSalesExecutionsByDate(String date) =>
      '/api/v1/field-sales/executions/date/$date';
  static String fieldSalesExecutionStart(String id) =>
      '/api/v1/field-sales/executions/$id/start';
  static String fieldSalesExecutionComplete(String id) =>
      '/api/v1/field-sales/executions/$id/complete';
  static String fieldSalesExecutionVisits(String executionId) =>
      '/api/v1/field-sales/executions/$executionId/visits';
  static String fieldSalesVisitCheckIn(String id) =>
      '/api/v1/field-sales/visits/$id/check-in';
  static String fieldSalesVisitCheckOut(String id) =>
      '/api/v1/field-sales/visits/$id/check-out';
  static String fieldSalesVisitSkip(String id) =>
      '/api/v1/field-sales/visits/$id/skip';
  static String fieldSalesVisitRecordOrder(String id) =>
      '/api/v1/field-sales/visits/$id/record-order';
  static String fieldSalesVisitRecordCollection(String id) =>
      '/api/v1/field-sales/visits/$id/record-collection';
  static String fieldSalesDayCloseInitiate(String routeExecutionId) =>
      '/api/v1/field-sales/day-close/initiate/$routeExecutionId';
  static String fieldSalesDayCloseById(String id) =>
      '/api/v1/field-sales/day-close/$id';
  static String fieldSalesDayCloseSubmit(String id) =>
      '/api/v1/field-sales/day-close/$id/submit';
  static String fieldSalesDayCloseApprove(String id) =>
      '/api/v1/field-sales/day-close/$id/approve';
  static String fieldSalesDayCloseReject(String id) =>
      '/api/v1/field-sales/day-close/$id/reject';
  static const String fieldSalesTargets = '/api/v1/field-sales/targets';
  static String fieldSalesTargetsBySalesperson(String id) =>
      '/api/v1/field-sales/targets/salesperson/$id';
  static String fieldSalesTargetAchievement(String id) =>
      '/api/v1/field-sales/targets/$id/achievement';
  static const String fieldSalesDashboard = '/api/v1/field-sales/dashboard';
  static const String fieldSalesLiveLocations =
      '/api/v1/field-sales/locations/live';
  static String fieldSalesLocationTrail(String executionId) =>
      '/api/v1/field-sales/locations/trail/$executionId';

  // MR Reporting (tour plans + DCR)
  static const String mrTourPlans = '/api/v1/mr/tour-plans';
  static const String mrTourPlansPending = '/api/v1/mr/tour-plans/pending';
  static String mrTourPlanById(String id) => '/api/v1/mr/tour-plans/$id';
  static String mrTourPlanApprove(String id) =>
      '/api/v1/mr/tour-plans/$id/approve';
  static String mrTourPlanReject(String id) =>
      '/api/v1/mr/tour-plans/$id/reject';
  static const String mrDcrPending = '/api/v1/mr/dcr/pending';
  static String mrDcrApprove(String id) => '/api/v1/mr/dcr/$id/approve';
  static String mrDcrReject(String id) => '/api/v1/mr/dcr/$id/reject';

  // Detail aids (e-detailing)
  static const String mrDetailAids = '/api/v1/mr/detail-aids';
  static const String mrDetailAidsManage = '/api/v1/mr/detail-aids/manage';
  static String mrDetailAidById(String id) => '/api/v1/mr/detail-aids/$id';
  static String mrVisitDetailAids(String visitId) =>
      '/api/v1/mr/visits/$visitId/detail-aids';

  // Field samples + allowance (all verticals)
  static const String fieldSamplesIssue = '/api/v1/field-sales/samples/issue';
  static const String fieldSamplesReturn = '/api/v1/field-sales/samples/return';
  static String fieldSamplesBalance(String salespersonId) =>
      '/api/v1/field-sales/samples/balance/$salespersonId';
  static String fieldSamplesTransactions(String salespersonId) =>
      '/api/v1/field-sales/samples/transactions/$salespersonId';

  // Coverage reports
  static const String mrTeamDashboard = '/api/v1/mr/reports/team-dashboard';
  static const String mrDeviationReport = '/api/v1/mr/reports/deviation';
  static const String mrFrequencyCompliance =
      '/api/v1/mr/reports/frequency-compliance';

  // Attendance + leave
  static const String attendanceTeam = '/api/v1/attendance/team';
  static const String attendanceLeavePending = '/api/v1/attendance/leave/pending';
  static String attendanceLeaveApprove(String id) =>
      '/api/v1/attendance/leave/$id/approve';
  static String attendanceLeaveReject(String id) =>
      '/api/v1/attendance/leave/$id/reject';

  // Partner Network
  static const String partnerNetworkPartners = '/api/v1/partner-network/partners';
  static const String partnerNetworkPartnersPending = '/api/v1/partner-network/partners/pending';
  static String partnerNetworkPartnerById(String id) => '/api/v1/partner-network/partners/$id';
  static const String partnerNetworkPartnerRequest = '/api/v1/partner-network/partners/request';
  static String partnerNetworkPartnerApprove(String id) => '/api/v1/partner-network/partners/$id/approve';
  static String partnerNetworkPartnerReject(String id) => '/api/v1/partner-network/partners/$id/reject';
  static String partnerNetworkPartnerSuspend(String id) => '/api/v1/partner-network/partners/$id/suspend';
  static const String partnerNetworkCatalog = '/api/v1/partner-network/catalog';
  static String partnerNetworkCatalogUnpublish(String id) => '/api/v1/partner-network/catalog/$id/unpublish';
  static const String partnerNetworkSupplierSearch = '/api/v1/partner-network/supplier-search';
  static String partnerNetworkSupplierSearchByDrug(String drugMasterId) =>
      '/api/v1/partner-network/supplier-search/by-drug/$drugMasterId';
  static const String partnerNetworkOrders = '/api/v1/partner-network/orders';
  static const String partnerNetworkOrdersOutgoing = '/api/v1/partner-network/orders/outgoing';
  static const String partnerNetworkOrdersIncoming = '/api/v1/partner-network/orders/incoming';
  static const String partnerNetworkOrdersIncomingPending = '/api/v1/partner-network/orders/incoming/pending';
  static String partnerNetworkOrderById(String id) => '/api/v1/partner-network/orders/$id';
  static String partnerNetworkOrderEvents(String id) => '/api/v1/partner-network/orders/$id/events';
  static String partnerNetworkOrderConfirm(String id) => '/api/v1/partner-network/orders/$id/confirm';
  static String partnerNetworkOrderReject(String id) => '/api/v1/partner-network/orders/$id/reject';
  static String partnerNetworkOrderCancel(String id) => '/api/v1/partner-network/orders/$id/cancel';
  static String partnerNetworkOrderDispatch(String id) => '/api/v1/partner-network/orders/$id/dispatch';
  static String partnerNetworkOrderDeliver(String id) => '/api/v1/partner-network/orders/$id/deliver';
  static String partnerNetworkOrderLinkPo(String id) => '/api/v1/partner-network/orders/$id/link-po';
  static String partnerNetworkOrderLinkSo(String id) => '/api/v1/partner-network/orders/$id/link-so';

  // Manufacturing
  static const String manufacturingWorkOrders = '/api/v1/manufacturing/work-orders';
  static String manufacturingWorkOrderById(String id) => '/api/v1/manufacturing/work-orders/$id';
  static String manufacturingWorkOrderIssue(String id) => '/api/v1/manufacturing/work-orders/$id/issue';
  static String manufacturingWorkOrderReceive(String id) => '/api/v1/manufacturing/work-orders/$id/receive';
  static String manufacturingWorkOrderCosts(String id) => '/api/v1/manufacturing/work-orders/$id/costs';
  static String manufacturingWorkOrderCancel(String id) => '/api/v1/manufacturing/work-orders/$id/cancel';
  static String manufacturingWorkOrderFromSo = '/api/v1/manufacturing/work-orders/from-sales-order';
  static String manufacturingWorkOrderJobCards(String id) => '/api/v1/manufacturing/work-orders/$id/job-cards';
  static String manufacturingWorkOrderScrap(String id) => '/api/v1/manufacturing/work-orders/$id/scrap';

  // Manufacturing — Workstations & Operations & Routings
  static const String manufacturingWorkstations = '/api/v1/manufacturing/workstations';
  static String manufacturingWorkstationById(String id) => '/api/v1/manufacturing/workstations/$id';
  static const String manufacturingOperations = '/api/v1/manufacturing/operations';
  static String manufacturingOperationById(String id) => '/api/v1/manufacturing/operations/$id';
  static const String manufacturingRoutings = '/api/v1/manufacturing/routings';
  static String manufacturingRoutingById(String id) => '/api/v1/manufacturing/routings/$id';

  // Manufacturing — Job Cards
  static String manufacturingJobCardStart(String id) => '/api/v1/manufacturing/job-cards/$id/start';
  static String manufacturingJobCardComplete(String id) => '/api/v1/manufacturing/job-cards/$id/complete';

  // Manufacturing — Job Work
  static const String manufacturingJobWork = '/api/v1/manufacturing/job-work';
  static String manufacturingJobWorkById(String id) => '/api/v1/manufacturing/job-work/$id';
  static String manufacturingJobWorkSend(String id) => '/api/v1/manufacturing/job-work/$id/send';
  static String manufacturingJobWorkReceive(String id) => '/api/v1/manufacturing/job-work/$id/receive';
  static String manufacturingJobWorkCancel(String id) => '/api/v1/manufacturing/job-work/$id/cancel';
  static const String manufacturingJobWorkGstAlerts = '/api/v1/manufacturing/job-work/gst-alerts';

  // Manufacturing — Quality Control
  static const String manufacturingQcTemplates = '/api/v1/manufacturing/qc/templates';
  static String manufacturingQcTemplateById(String id) => '/api/v1/manufacturing/qc/templates/$id';
  static const String manufacturingQcInspections = '/api/v1/manufacturing/qc/inspections';
  static String manufacturingQcInspectionById(String id) => '/api/v1/manufacturing/qc/inspections/$id';
  static String manufacturingQcInspectionResults(String id) => '/api/v1/manufacturing/qc/inspections/$id/results';
  static String manufacturingQcInspectionFinalize(String id) => '/api/v1/manufacturing/qc/inspections/$id/finalize';

  // Manufacturing — Scrap
  static const String manufacturingScrap = '/api/v1/manufacturing/scrap';
  static const String manufacturingScrapReasonCodes = '/api/v1/manufacturing/scrap/reason-codes';

  // Manufacturing — Tier 2: Disassembly, BOM Versioning, Reports
  static const String manufacturingDisassembly = '/api/v1/manufacturing/work-orders/disassembly';
  static String manufacturingDisassemble(String id) => '/api/v1/manufacturing/work-orders/$id/disassemble';
  static String manufacturingBomVersion(String itemId) => '/api/v1/manufacturing/bom/$itemId/version';
  static String manufacturingBomVersionGet(String itemId, int version) =>
      '/api/v1/manufacturing/bom/$itemId/version/$version';
  static String manufacturingBomLatestVersion(String itemId) =>
      '/api/v1/manufacturing/bom/$itemId/latest-version';
  static const String manufacturingCostVariance = '/api/v1/manufacturing/reports/cost-variance';
  static String manufacturingCostVarianceById(String woId) =>
      '/api/v1/manufacturing/reports/cost-variance/$woId';
  static const String manufacturingWipValuation = '/api/v1/manufacturing/reports/wip-valuation';
  static const String manufacturingConsumption = '/api/v1/manufacturing/reports/consumption';

  // POS — Cash Register / Day Close
  static const String cashRegister = '/api/v1/pos/cash-register';
  static String cashRegisterDate(String date) => '/api/v1/pos/cash-register/$date';

  // WhatsApp document templates
  static const String whatsappSettings = '/api/v1/settings/whatsapp';
  static const String whatsappMessages = '/api/v1/whatsapp/messages';
  static String whatsappSendInvoice(String id) => '/api/v1/whatsapp/invoices/$id';
  static String whatsappSendReceipt(String id) => '/api/v1/whatsapp/receipts/$id';
  static String whatsappSendReminder(String contactId) =>
      '/api/v1/whatsapp/reminders/$contactId';
  static String whatsappSendStatement(String contactId) =>
      '/api/v1/whatsapp/statements/$contactId';

  // GSP direct e-invoice / e-way bill generation
  static const String gspSettings = '/api/v1/gst/gsp-settings';
  static String einvoiceGenerateViaGsp(String id) =>
      '/api/v1/gst/einvoices/$id/generate-gsp';
  static String ewayBillGenerateViaGsp(String id) =>
      '/api/v1/gst/eway-bills/$id/generate-gsp';

  // MRP (Manufacturing Requirements Planning)
  static const String manufacturingMrpRun = '/api/v1/manufacturing/mrp/run';
  static const String manufacturingMrpRuns = '/api/v1/manufacturing/mrp/runs';
  static String manufacturingMrpRunById(String id) =>
      '/api/v1/manufacturing/mrp/runs/$id';
  static String manufacturingMrpOrderConvert(String orderId) =>
      '/api/v1/manufacturing/mrp/planned-orders/$orderId/convert';

  // Shipments (Supply Chain)
  static const String supplyChainShipments = '/api/v1/supply-chain/shipments';
  static String supplyChainShipmentById(String id) =>
      '/api/v1/supply-chain/shipments/$id';
  static String supplyChainShipmentDispatch(String id) =>
      '/api/v1/supply-chain/shipments/$id/dispatch';
  static String supplyChainShipmentDeliver(String id) =>
      '/api/v1/supply-chain/shipments/$id/deliver';
  static String supplyChainShipmentCancel(String id) =>
      '/api/v1/supply-chain/shipments/$id/cancel';

  // Warehouse Zones
  static const String warehouseZones = '/api/v1/inventory/warehouse-zones';
  static String warehouseZoneById(String id) =>
      '/api/v1/inventory/warehouse-zones/$id';

  // Batch Traceability
  static String batchTraceForward(String batchId) =>
      '/api/v1/inventory/batch-trace/forward/$batchId';
  static String batchTraceBackward(String batchId) =>
      '/api/v1/inventory/batch-trace/backward/$batchId';

  // Currencies
  static const String currencies = '/api/v1/currencies';
  static String currencyByCode(String code) => '/api/v1/currencies/$code';
  static const String currencyRates = '/api/v1/currencies/rates';
  static const String currencyConvert = '/api/v1/currencies/convert';

  // Consignment
  static const String consignmentItems = '/api/v1/inventory/consignment/items';
  static const String consignmentReceipts =
      '/api/v1/inventory/consignment/receipts';
  static String consignmentReceiptById(String id) =>
      '/api/v1/inventory/consignment/receipts/$id';
  static String consignmentSettle(String id) =>
      '/api/v1/inventory/consignment/receipts/$id/settle';
  static String consignmentReturn(String id) =>
      '/api/v1/inventory/consignment/receipts/$id/return';

  // Integrations
  static const String integrations = '/api/v1/integrations';
  static String integrationById(String id) => '/api/v1/integrations/$id';
  static String integrationTestConnection(String id) =>
      '/api/v1/integrations/$id/test-connection';
  static String integrationSync(String id) => '/api/v1/integrations/$id/sync';
  static String integrationEnable(String id) =>
      '/api/v1/integrations/$id/enable';
  static String integrationDisable(String id) =>
      '/api/v1/integrations/$id/disable';

  // Forecast variants (seasonal + weighted MA)
  static const String supplyChainForecastGenerateSeasonal =
      '/api/v1/supply-chain/forecasts/generate-seasonal';
  static const String supplyChainForecastGenerateWeighted =
      '/api/v1/supply-chain/forecasts/generate-weighted';

  // Supply Chain
  static const String supplyChainItemSuppliers = '/api/v1/supply-chain/item-suppliers';
  static String supplyChainItemSuppliersByItem(String itemId) =>
      '/api/v1/supply-chain/item-suppliers/by-item/$itemId';
  static String supplyChainItemSuppliersBySupplier(String supplierId) =>
      '/api/v1/supply-chain/item-suppliers/by-supplier/$supplierId';
  static String supplyChainSetPreferred(String itemId, String supplierId) =>
      '/api/v1/supply-chain/item-suppliers/$itemId/preferred/$supplierId';
  static const String supplyChainForecastGenerate = '/api/v1/supply-chain/forecasts/generate';
  static String supplyChainForecastsByItem(String itemId) =>
      '/api/v1/supply-chain/forecasts/by-item/$itemId';
  static const String supplyChainForecasts = '/api/v1/supply-chain/forecasts';
  static const String supplyChainAbcRun = '/api/v1/supply-chain/abc/run';
  static const String supplyChainReorderPolicies = '/api/v1/supply-chain/reorder-policies';
  static String supplyChainAbcClass(String cls) => '/api/v1/supply-chain/abc/$cls';
  static String supplyChainReorderParams(String itemId) =>
      '/api/v1/supply-chain/reorder-params/$itemId';
  static const String supplyChainRequisitions = '/api/v1/supply-chain/requisitions';
  static const String supplyChainRequisitionsAuto = '/api/v1/supply-chain/requisitions/auto';
  static String supplyChainRequisition(String id) => '/api/v1/supply-chain/requisitions/$id';
  static String supplyChainRequisitionSubmit(String id) =>
      '/api/v1/supply-chain/requisitions/$id/submit';
  static String supplyChainRequisitionApprove(String id) =>
      '/api/v1/supply-chain/requisitions/$id/approve';
  static String supplyChainRequisitionReject(String id) =>
      '/api/v1/supply-chain/requisitions/$id/reject';
  static const String supplyChainReturns = '/api/v1/supply-chain/returns';
  static String supplyChainReturn(String id) => '/api/v1/supply-chain/returns/$id';
  static String supplyChainReturnApprove(String id) =>
      '/api/v1/supply-chain/returns/$id/approve';
  static String supplyChainReturnProcess(String id) =>
      '/api/v1/supply-chain/returns/$id/process';
  static String supplyChainReturnCancel(String id) =>
      '/api/v1/supply-chain/returns/$id/cancel';
  static const String supplyChainAlerts = '/api/v1/supply-chain/alerts';
  static String supplyChainAlertResolve(String id) =>
      '/api/v1/supply-chain/alerts/$id/resolve';
  static const String supplyChainAlertScan = '/api/v1/supply-chain/alerts/scan';
  static String supplyChainSupplierPerformance(String supplierId) =>
      '/api/v1/supply-chain/supplier-performance/$supplierId';
  static const String supplyChainSupplierRankings = '/api/v1/supply-chain/supplier-rankings';
  static String supplyChainSupplierPerformanceCalc(String supplierId) =>
      '/api/v1/supply-chain/supplier-performance/$supplierId/calculate';
  static const String supplyChainTurnover = '/api/v1/supply-chain/analytics/turnover';
  static const String supplyChainDashboard = '/api/v1/supply-chain/dashboard';
}
