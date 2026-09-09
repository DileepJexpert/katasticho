import { Suspense } from 'react'
import { createBrowserRouter, Navigate, Outlet } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { lazyNamed } from '@/app/lazy-named'
import { AppShell } from '@/app/shell/app-shell'
import { useSessionStore } from '@/shared/session/session-store'
import { useAdminSessionBootstrap } from '@/shared/session/use-admin-session-bootstrap'

const AiCommandCenterPage = lazyNamed(() => import('@/features/ai/ai-command-center-page'), 'AiCommandCenterPage')
const AiSettingsPage = lazyNamed(() => import('@/features/ai/ai-settings-page'), 'AiSettingsPage')
const CaDashboardPage = lazyNamed(() => import('@/features/ca/ca-dashboard-page'), 'CaDashboardPage')
const CaCompliancePage = lazyNamed(() => import('@/features/ca/ca-compliance-page'), 'CaCompliancePage')
const CaAlertsPage = lazyNamed(() => import('@/features/ca/ca-alerts-page'), 'CaAlertsPage')
const CaDispatchPage = lazyNamed(() => import('@/features/ca/ca-dispatch-page'), 'CaDispatchPage')
const AccountDetailPage = lazyNamed(() => import('@/features/accounts/account-detail-page'), 'AccountDetailPage')
const AccountsPage = lazyNamed(() => import('@/features/accounts/accounts-page'), 'AccountsPage')
const BudgetsPage = lazyNamed(() => import('@/features/budgets/budgets-page'), 'BudgetsPage')
const FiscalPeriodsPage = lazyNamed(() => import('@/features/fiscal-periods/fiscal-periods-page'), 'FiscalPeriodsPage')
const AmortizationDetailPage = lazyNamed(() => import('@/features/amortization/amortization-detail-page'), 'AmortizationDetailPage')
const AmortizationPage = lazyNamed(() => import('@/features/amortization/amortization-page'), 'AmortizationPage')
const ApAgingReportPage = lazyNamed(() => import('@/features/ap/ap-aging-report-page'), 'ApAgingReportPage')
const BeatDetailPage = lazyNamed(() => import('@/features/field-sales/beat-detail-page'), 'BeatDetailPage')
const BeatsPage = lazyNamed(() => import('@/features/field-sales/beats-page'), 'BeatsPage')
const RoutesPage = lazyNamed(() => import('@/features/field-sales/routes-page'), 'RoutesPage')
const RouteDetailPage = lazyNamed(() => import('@/features/field-sales/route-detail-page'), 'RouteDetailPage')
const RouteExecutionsPage = lazyNamed(() => import('@/features/field-sales/route-executions-page'), 'RouteExecutionsPage')
const RouteExecutionDetailPage = lazyNamed(() => import('@/features/field-sales/route-execution-detail-page'), 'RouteExecutionDetailPage')
const DayClosePage = lazyNamed(() => import('@/features/field-sales/day-close-page'), 'DayClosePage')
const SalesmanTargetsPage = lazyNamed(() => import('@/features/field-sales/salesman-targets-page'), 'SalesmanTargetsPage')
const StoreMerchandisingPage = lazyNamed(() => import('@/features/field-sales/store-merchandising-page'), 'StoreMerchandisingPage')
const SalesmanDashboardPage = lazyNamed(() => import('@/features/field-sales/salesman-dashboard-page'), 'SalesmanDashboardPage')
const LiveTrackingPage = lazyNamed(() => import('@/features/field-sales/live-tracking-page'), 'LiveTrackingPage')
const FieldCoveragePage = lazyNamed(() => import('@/features/field-sales/field-coverage-page'), 'FieldCoveragePage')
const FieldAttendancePage = lazyNamed(() => import('@/features/field-sales/field-attendance-page'), 'FieldAttendancePage')
const FieldOrgChartPage = lazyNamed(() => import('@/features/field-sales/field-org-chart-page'), 'FieldOrgChartPage')
const TeamAssignmentsPage = lazyNamed(() => import('@/features/field-sales/team-assignments-page'), 'TeamAssignmentsPage')
const DcrPage = lazyNamed(() => import('@/features/mr/dcr-page'), 'DcrPage')
const DcrDetailPage = lazyNamed(() => import('@/features/mr/dcr-detail-page'), 'DcrDetailPage')
const TourPlansPage = lazyNamed(() => import('@/features/mr/tour-plans-page'), 'TourPlansPage')
const TourPlanDetailPage = lazyNamed(() => import('@/features/mr/tour-plan-detail-page'), 'TourPlanDetailPage')
const DetailAidsPage = lazyNamed(() => import('@/features/mr/detail-aids-page'), 'DetailAidsPage')
const FieldSamplesPage = lazyNamed(() => import('@/features/mr/field-samples-page'), 'FieldSamplesPage')
const RcpaPage = lazyNamed(() => import('@/features/mr/rcpa-page'), 'RcpaPage')
const SecondarySalesPage = lazyNamed(() => import('@/features/mr/secondary-sales-page'), 'SecondarySalesPage')
const MrApprovalsPage = lazyNamed(() => import('@/features/mr/mr-approvals-page'), 'MrApprovalsPage')
const BankingPage = lazyNamed(() => import('@/features/banking/banking-page'), 'BankingPage')
const BillsPage = lazyNamed(() => import('@/features/bills/bills-page'), 'BillsPage')
const BillCreatePage = lazyNamed(() => import('@/features/bills/bill-create-page'), 'BillCreatePage')
const BillDetailPage = lazyNamed(() => import('@/features/bills/bill-detail-page'), 'BillDetailPage')
const ThreeWayMatchPage = lazyNamed(() => import('@/features/bills/three-way-match-page'), 'ThreeWayMatchPage')
const ThreeWayMatchWorkbenchPage = lazyNamed(() => import('@/features/bills/three-way-match-workbench-page'), 'ThreeWayMatchWorkbenchPage')
const BomManagerPage = lazyNamed(() => import('@/features/bom/bom-manager-page'), 'BomManagerPage')
const CapaDetailPage = lazyNamed(() => import('@/features/capa/capa-detail-page'), 'CapaDetailPage')
const CapaPage = lazyNamed(() => import('@/features/capa/capa-page'), 'CapaPage')
const ContactsPage = lazyNamed(() => import('@/features/contacts/contacts-page'), 'ContactsPage')
const ContactCreatePage = lazyNamed(() => import('@/features/contacts/contact-create-page'), 'ContactCreatePage')
const ContactDetailPage = lazyNamed(() => import('@/features/contacts/contact-detail-page'), 'ContactDetailPage')
const ContactStatementPage = lazyNamed(() => import('@/features/contacts/contact-statement-page'), 'ContactStatementPage')
const CreditNoteDetailPage = lazyNamed(() => import('@/features/credit-notes/credit-note-detail-page'), 'CreditNoteDetailPage')
const CreditNoteCreatePage = lazyNamed(() => import('@/features/credit-notes/credit-note-create-page'), 'CreditNoteCreatePage')
const CreditNotesPage = lazyNamed(() => import('@/features/credit-notes/credit-notes-page'), 'CreditNotesPage')
const AccountingDashboardPage = lazyNamed(() => import('@/features/dashboard/accounting-dashboard-page'), 'AccountingDashboardPage')
const DashboardPage = lazyNamed(() => import('@/features/dashboard/dashboard-page'), 'DashboardPage')
const DebitNoteDetailPage = lazyNamed(() => import('@/features/debit-notes/debit-note-detail-page'), 'DebitNoteDetailPage')
const DebitNoteCreatePage = lazyNamed(() => import('@/features/debit-notes/debit-note-create-page'), 'DebitNoteCreatePage')
const DebitNotesPage = lazyNamed(() => import('@/features/debit-notes/debit-notes-page'), 'DebitNotesPage')
const DeliveryChallanDetailPage = lazyNamed(() => import('@/features/delivery-challans/delivery-challan-detail-page'), 'DeliveryChallanDetailPage')
const DeliveryChallanCreatePage = lazyNamed(() => import('@/features/delivery-challans/delivery-challan-create-page'), 'DeliveryChallanCreatePage')
const DeliveryChallansPage = lazyNamed(() => import('@/features/delivery-challans/delivery-challans-page'), 'DeliveryChallansPage')
const AttendancePage = lazyNamed(() => import('@/features/hr/attendance-page'), 'AttendancePage')
const BiometricDevicesPage = lazyNamed(() => import('@/features/hr/biometric-devices-page'), 'BiometricDevicesPage')
const HrTicketDetailPage = lazyNamed(() => import('@/features/hr/hr-ticket-detail-page'), 'HrTicketDetailPage')
const HrTicketsPage = lazyNamed(() => import('@/features/hr/hr-tickets-page'), 'HrTicketsPage')
const LeavesPage = lazyNamed(() => import('@/features/hr/leaves-page'), 'LeavesPage')
const OffboardingDetailPage = lazyNamed(() => import('@/features/hr/offboarding-detail-page'), 'OffboardingDetailPage')
const OffboardingPage = lazyNamed(() => import('@/features/hr/offboarding-page'), 'OffboardingPage')
const ShiftsPage = lazyNamed(() => import('@/features/hr/shifts-page'), 'ShiftsPage')
const TimesheetsPage = lazyNamed(() => import('@/features/hr/timesheets-page'), 'TimesheetsPage')
const EmployeeDocumentsPage = lazyNamed(() => import('@/features/hr/employee-documents-page'), 'EmployeeDocumentsPage')
const HrAnalyticsPage = lazyNamed(() => import('@/features/hr/hr-analytics-page'), 'HrAnalyticsPage')
const MyProfilePage = lazyNamed(() => import('@/features/hr/my-profile-page'), 'MyProfilePage')
const EmployeeDetailPage = lazyNamed(() => import('@/features/payroll/employee-detail-page'), 'EmployeeDetailPage')
const EmployeesPage = lazyNamed(() => import('@/features/payroll/employees-page'), 'EmployeesPage')
const PayrollSettingsPage = lazyNamed(() => import('@/features/payroll/payroll-settings-page'), 'PayrollSettingsPage')
const TaxDeclarationPage = lazyNamed(() => import('@/features/payroll/tax-declaration-page'), 'TaxDeclarationPage')
const LaborPayPreviewPage = lazyNamed(() => import('@/features/payroll/labor-pay-preview-page'), 'LaborPayPreviewPage')
const KenyaPayeCalculatorPage = lazyNamed(() => import('@/features/payroll/kenya-paye-calculator-page'), 'KenyaPayeCalculatorPage')
const FixedAssetDetailPage = lazyNamed(() => import('@/features/fixed-assets/fixed-asset-detail-page'), 'FixedAssetDetailPage')
const FixedAssetsPage = lazyNamed(() => import('@/features/fixed-assets/fixed-assets-page'), 'FixedAssetsPage')
const GstCompliancePage = lazyNamed(() => import('@/features/gst/gst-compliance-page'), 'GstCompliancePage')
const TdsCompliancePage = lazyNamed(() => import('@/features/tax/tds-compliance-page'), 'TdsCompliancePage')
const TcsCompliancePage = lazyNamed(() => import('@/features/tax/tcs-compliance-page'), 'TcsCompliancePage')
const TaxAccountMappingsPage = lazyNamed(() => import('@/features/tax/tax-account-mappings-page'), 'TaxAccountMappingsPage')
const TaxGroupsPage = lazyNamed(() => import('@/features/tax/tax-groups-page'), 'TaxGroupsPage')
const UomsPage = lazyNamed(() => import('@/features/inventory/uoms-page'), 'UomsPage')
const RackLocationsPage = lazyNamed(() => import('@/features/inventory/rack-locations-page'), 'RackLocationsPage')
const PutawayTasksPage = lazyNamed(() => import('@/features/inventory/putaway-tasks-page'), 'PutawayTasksPage')
const PutawayCreatePage = lazyNamed(() => import('@/features/inventory/putaway-create-page'), 'PutawayCreatePage')
const PutawayDetailPage = lazyNamed(() => import('@/features/inventory/putaway-detail-page'), 'PutawayDetailPage')
const SerialNumbersPage = lazyNamed(() => import('@/features/inventory/serial-numbers-page'), 'SerialNumbersPage')
const FranchisePage = lazyNamed(() => import('@/features/franchise/franchise-page'), 'FranchisePage')
const FranchiseNodeDetailPage = lazyNamed(() => import('@/features/franchise/franchise-node-detail-page'), 'FranchiseNodeDetailPage')
const KenyaCompliancePage = lazyNamed(() => import('@/features/kenya/kenya-compliance-page'), 'KenyaCompliancePage')
const CashRunwayPage = lazyNamed(() => import('@/features/analytics/cash-runway-page'), 'CashRunwayPage')
const FluxCommentaryPage = lazyNamed(() => import('@/features/analytics/flux-commentary-page'), 'FluxCommentaryPage')
const UsersPage = lazyNamed(() => import('@/features/settings/users-page'), 'UsersPage')
const PaymentTermsPage = lazyNamed(() => import('@/features/settings/payment-terms-page'), 'PaymentTermsPage')
const PdfTemplateCustomizerPage = lazyNamed(() => import('@/features/settings/pdf-template-customizer-page'), 'PdfTemplateCustomizerPage')
const ItemDetailPage = lazyNamed(() => import('@/features/items/item-detail-page'), 'ItemDetailPage')
const ItemImportPage = lazyNamed(() => import('@/features/items/item-import-page'), 'ItemImportPage')
const ItemFormPage = lazyNamed(() => import('@/features/items/item-form-page'), 'ItemFormPage')
const ItemsPage = lazyNamed(() => import('@/features/items/items-page'), 'ItemsPage')
const StockSummaryPage = lazyNamed(() => import('@/features/inventory/stock-summary-page'), 'StockSummaryPage')
const SchemesPage = lazyNamed(() => import('@/features/pricing/schemes-page'), 'SchemesPage')
const BatchTracePage = lazyNamed(() => import('@/features/inventory/batch-trace-page'), 'BatchTracePage')
const ShortbookPage = lazyNamed(() => import('@/features/inventory/shortbook-page'), 'ShortbookPage')
const ConsignmentsPage = lazyNamed(() => import('@/features/inventory/consignments-page'), 'ConsignmentsPage')
const BarcodeLabelsPage = lazyNamed(() => import('@/features/inventory/barcode-labels-page'), 'BarcodeLabelsPage')
const JobWorkDetailPage = lazyNamed(() => import('@/features/job-work/job-work-detail-page'), 'JobWorkDetailPage')
const JobWorkPage = lazyNamed(() => import('@/features/job-work/job-work-page'), 'JobWorkPage')
const JournalDetailPage = lazyNamed(() => import('@/features/journals/journal-detail-page'), 'JournalDetailPage')
const JournalCreatePage = lazyNamed(() => import('@/features/journals/journal-create-page'), 'JournalCreatePage')
const JournalsPage = lazyNamed(() => import('@/features/journals/journals-page'), 'JournalsPage')
const LoginPage = lazyNamed(() => import('@/features/auth/login-page'), 'LoginPage')
const MaintenanceSchedulesPage = lazyNamed(() => import('@/features/maintenance/maintenance-schedules-page'), 'MaintenanceSchedulesPage')
const MaintenanceWorkOrderDetailPage = lazyNamed(() => import('@/features/maintenance/maintenance-work-order-detail-page'), 'MaintenanceWorkOrderDetailPage')
const MaintenanceWorkOrdersPage = lazyNamed(() => import('@/features/maintenance/maintenance-work-orders-page'), 'MaintenanceWorkOrdersPage')
const ManufacturingReportsPage = lazyNamed(() => import('@/features/manufacturing/manufacturing-reports-page'), 'ManufacturingReportsPage')
const MrpPage = lazyNamed(() => import('@/features/mrp/mrp-page'), 'MrpPage')
const NcrDetailPage = lazyNamed(() => import('@/features/ncrs/ncr-detail-page'), 'NcrDetailPage')
const NcrsPage = lazyNamed(() => import('@/features/ncrs/ncrs-page'), 'NcrsPage')
const PaymentDetailPage = lazyNamed(() => import('@/features/payments/payment-detail-page'), 'PaymentDetailPage')
const PaymentCreatePage = lazyNamed(() => import('@/features/payments/payment-create-page'), 'PaymentCreatePage')
const PaymentsPage = lazyNamed(() => import('@/features/payments/payments-page'), 'PaymentsPage')
const PayrollRunDetailPage = lazyNamed(() => import('@/features/payroll/payroll-run-detail-page'), 'PayrollRunDetailPage')
const PayrollRunsPage = lazyNamed(() => import('@/features/payroll/payroll-runs-page'), 'PayrollRunsPage')
const PharmacyMastersPage = lazyNamed(() => import('@/features/pharmacy/pharmacy-masters-page'), 'PharmacyMastersPage')
const NearExpiryPage = lazyNamed(() => import('@/features/pharmacy/near-expiry-page'), 'NearExpiryPage')
const CashRegisterPage = lazyNamed(() => import('@/features/pos/cash-register-page'), 'CashRegisterPage')
const PosCheckoutPage = lazyNamed(() => import('@/features/pos/pos-checkout-page'), 'PosCheckoutPage')
const PosOfflineSyncPage = lazyNamed(() => import('@/features/pos/pos-offline-sync-page'), 'PosOfflineSyncPage')
const PosReceiptSettingsPage = lazyNamed(() => import('@/features/pos/pos-receipt-settings-page'), 'PosReceiptSettingsPage')
const SalesReceiptDetailPage = lazyNamed(() => import('@/features/pos/sales-receipt-detail-page'), 'SalesReceiptDetailPage')
const SalesReceiptsPage = lazyNamed(() => import('@/features/pos/sales-receipts-page'), 'SalesReceiptsPage')
const LoyaltyPage = lazyNamed(() => import('@/features/loyalty/loyalty-page'), 'LoyaltyPage')
const PicklistDetailPage = lazyNamed(() => import('@/features/picklists/picklist-detail-page'), 'PicklistDetailPage')
const PicklistsPage = lazyNamed(() => import('@/features/picklists/picklists-page'), 'PicklistsPage')
const PriceListDetailPage = lazyNamed(() => import('@/features/price-lists/price-list-detail-page'), 'PriceListDetailPage')
const PriceListsPage = lazyNamed(() => import('@/features/price-lists/price-lists-page'), 'PriceListsPage')
const PurchaseOrderDetailPage = lazyNamed(() => import('@/features/purchase-orders/purchase-order-detail-page'), 'PurchaseOrderDetailPage')
const PurchaseOrderCreatePage = lazyNamed(() => import('@/features/purchase-orders/purchase-order-create-page'), 'PurchaseOrderCreatePage')
const PurchaseOrdersPage = lazyNamed(() => import('@/features/purchase-orders/purchase-orders-page'), 'PurchaseOrdersPage')
const QcInspectionDetailPage = lazyNamed(() => import('@/features/qc-inspections/qc-inspection-detail-page'), 'QcInspectionDetailPage')
const QcInspectionsPage = lazyNamed(() => import('@/features/qc-inspections/qc-inspections-page'), 'QcInspectionsPage')
const QcTemplatesPage = lazyNamed(() => import('@/features/qc-inspections/qc-templates-page'), 'QcTemplatesPage')
const RoutingsPage = lazyNamed(() => import('@/features/routings/routings-page'), 'RoutingsPage')
const InvoiceDetailPage = lazyNamed(() => import('@/features/invoices/invoice-detail-page'), 'InvoiceDetailPage')
const InvoiceCreatePage = lazyNamed(() => import('@/features/invoices/invoice-create-page'), 'InvoiceCreatePage')
const InvoicesPage = lazyNamed(() => import('@/features/invoices/invoices-page'), 'InvoicesPage')
const EstimatesPage = lazyNamed(() => import('@/features/estimates/estimates-page'), 'EstimatesPage')
const EstimateCreatePage = lazyNamed(() => import('@/features/estimates/estimate-create-page'), 'EstimateCreatePage')
const EstimateDetailPage = lazyNamed(() => import('@/features/estimates/estimate-detail-page'), 'EstimateDetailPage')
const RecurringInvoicesPage = lazyNamed(() => import('@/features/recurring/recurring-invoices-page'), 'RecurringInvoicesPage')
const RecurringInvoiceDetailPage = lazyNamed(() => import('@/features/recurring/recurring-invoice-detail-page'), 'RecurringInvoiceDetailPage')
const RecurringBillsPage = lazyNamed(() => import('@/features/recurring/recurring-bills-page'), 'RecurringBillsPage')
const RecurringBillDetailPage = lazyNamed(() => import('@/features/recurring/recurring-bill-detail-page'), 'RecurringBillDetailPage')
const RecurringJournalsPage = lazyNamed(() => import('@/features/recurring/recurring-journals-page'), 'RecurringJournalsPage')
const RecurringJournalDetailPage = lazyNamed(() => import('@/features/recurring/recurring-journal-detail-page'), 'RecurringJournalDetailPage')
const ReportsHubPage = lazyNamed(() => import('@/features/reports/reports-hub-page'), 'ReportsHubPage')
const ReportViewerPage = lazyNamed(() => import('@/features/reports/report-viewer-page'), 'ReportViewerPage')
const SavedReportDetailPage = lazyNamed(() => import('@/features/reports/saved-report-detail-page'), 'SavedReportDetailPage')
const SavedReportsPage = lazyNamed(() => import('@/features/reports/saved-reports-page'), 'SavedReportsPage')
const SalesOrderDetailPage = lazyNamed(() => import('@/features/sales-orders/sales-order-detail-page'), 'SalesOrderDetailPage')
const SalesOrderCreatePage = lazyNamed(() => import('@/features/sales-orders/sales-order-create-page'), 'SalesOrderCreatePage')
const SalesOrdersPage = lazyNamed(() => import('@/features/sales-orders/sales-orders-page'), 'SalesOrdersPage')
const StockCountDetailPage = lazyNamed(() => import('@/features/stock-counts/stock-count-detail-page'), 'StockCountDetailPage')
const StockCountsPage = lazyNamed(() => import('@/features/stock-counts/stock-counts-page'), 'StockCountsPage')
const StockReceiptDetailPage = lazyNamed(() => import('@/features/stock-receipts/stock-receipt-detail-page'), 'StockReceiptDetailPage')
const StockReceiptCreatePage = lazyNamed(() => import('@/features/stock-receipts/stock-receipt-create-page'), 'StockReceiptCreatePage')
const StockReceiptsPage = lazyNamed(() => import('@/features/stock-receipts/stock-receipts-page'), 'StockReceiptsPage')
const TransferOrderDetailPage = lazyNamed(() => import('@/features/inventory/transfer-order-detail-page'), 'TransferOrderDetailPage')
const TransferOrdersPage = lazyNamed(() => import('@/features/inventory/transfer-orders-page'), 'TransferOrdersPage')
const TransferOrderCreatePage = lazyNamed(() => import('@/features/inventory/transfer-order-create-page'), 'TransferOrderCreatePage')
const BatchesPage = lazyNamed(() => import('@/features/inventory/batches-page'), 'BatchesPage')
const VanDetailPage = lazyNamed(() => import('@/features/field-sales/van-detail-page'), 'VanDetailPage')
const VansPage = lazyNamed(() => import('@/features/field-sales/vans-page'), 'VansPage')
const VendorCreditDetailPage = lazyNamed(() => import('@/features/vendor-credits/vendor-credit-detail-page'), 'VendorCreditDetailPage')
const VendorCreditsPage = lazyNamed(() => import('@/features/vendor-credits/vendor-credits-page'), 'VendorCreditsPage')
const VendorPaymentDetailPage = lazyNamed(() => import('@/features/vendor-payments/vendor-payment-detail-page'), 'VendorPaymentDetailPage')
const VendorPaymentCreatePage = lazyNamed(() => import('@/features/vendor-payments/vendor-payment-create-page'), 'VendorPaymentCreatePage')
const VendorPaymentsPage = lazyNamed(() => import('@/features/vendor-payments/vendor-payments-page'), 'VendorPaymentsPage')
const WarehouseDetailPage = lazyNamed(() => import('@/features/warehouses/warehouse-detail-page'), 'WarehouseDetailPage')
const WarehousesPage = lazyNamed(() => import('@/features/warehouses/warehouses-page'), 'WarehousesPage')
const WorkCenterDetailPage = lazyNamed(() => import('@/features/maintenance/work-center-detail-page'), 'WorkCenterDetailPage')
const WorkCentersPage = lazyNamed(() => import('@/features/maintenance/work-centers-page'), 'WorkCentersPage')
const WorkOrderDetailPage = lazyNamed(() => import('@/features/work-orders/work-order-detail-page'), 'WorkOrderDetailPage')
const WorkOrdersPage = lazyNamed(() => import('@/features/work-orders/work-orders-page'), 'WorkOrdersPage')
const CourierShipmentsPage = lazyNamed(() => import('@/features/transport/courier-shipments-page'), 'CourierShipmentsPage')
const CourierShipmentDetailPage = lazyNamed(() => import('@/features/transport/courier-shipment-detail-page'), 'CourierShipmentDetailPage')
const CodRemittancesPage = lazyNamed(() => import('@/features/transport/cod-remittances-page'), 'CodRemittancesPage')
const CodRemittanceDetailPage = lazyNamed(() => import('@/features/transport/cod-remittance-detail-page'), 'CodRemittanceDetailPage')
const CourierSettingsPage = lazyNamed(() => import('@/features/transport/courier-settings-page'), 'CourierSettingsPage')
const LorryReceiptsPage = lazyNamed(() => import('@/features/transport/lorry-receipts-page'), 'LorryReceiptsPage')
const LorryReceiptDetailPage = lazyNamed(() => import('@/features/transport/lorry-receipt-detail-page'), 'LorryReceiptDetailPage')
const FreightRateCardsPage = lazyNamed(() => import('@/features/transport/freight-rate-cards-page'), 'FreightRateCardsPage')
const VehicleLogsPage = lazyNamed(() => import('@/features/transport/vehicle-logs-page'), 'VehicleLogsPage')

function SessionLoading() {
  return (
    <main className="session-loading" aria-live="polite">
      <span className="brand-mark" aria-hidden="true">K</span>
      <p>Restoring your workspace</p>
    </main>
  )
}

function ProtectedRoute() {
  useAdminSessionBootstrap()
  const status = useSessionStore((state) => state.status)

  if (status === 'booting') return <SessionLoading />
  if (status !== 'authenticated') return <Navigate to="/login" replace />
  return <Suspense fallback={<SessionLoading />}><Outlet /></Suspense>
}

function PublicRoute() {
  useAdminSessionBootstrap()
  const status = useSessionStore((state) => state.status)

  if (status === 'booting') return <SessionLoading />
  if (status === 'authenticated') return <Navigate to={appRoutes.overview} replace />
  return <Suspense fallback={<SessionLoading />}><Outlet /></Suspense>
}

export const router = createBrowserRouter([
  { path: '/portal/login', lazy: async () => ({ Component: (await import('@/features/portal/portal-auth-page')).PortalAuthPage }) },
  { path: '/portal/accept-invite', lazy: async () => ({ Component: (await import('@/features/portal/portal-auth-page')).PortalAuthPage }) },
  { path: '/portal', lazy: async () => ({ Component: (await import('@/features/portal/portal-page')).PortalPage }) },
  {
    element: <PublicRoute />,
    children: [
      {
        path: '/login',
        element: <LoginPage />,
      },
    ],
  },
  {
    element: <ProtectedRoute />,
    children: [
      {
        path: '/',
        element: <AppShell />,
        children: [
          {
            index: true,
            element: <DashboardPage />,
          },
          {
            path: 'contacts',
            element: <ContactsPage />,
          },
          {
            path: 'contacts/new',
            element: <ContactCreatePage />,
          },
          {
            path: 'contacts/:contactId',
            element: <ContactDetailPage />,
          },
          {
            path: 'contacts/:contactId/statement',
            element: <ContactStatementPage />,
          },
          {
            path: 'items',
            element: <ItemsPage />,
          },
          {
            path: 'items/new',
            element: <ItemFormPage />,
          },
          {
            path: 'items/import',
            element: <ItemImportPage />,
          },
          {
            path: 'items/:itemId/edit',
            element: <ItemFormPage />,
          },
          {
            path: 'items/:itemId',
            element: <ItemDetailPage />,
          },
          {
            path: 'inventory/stock-summary',
            element: <StockSummaryPage />,
          },
          {
            path: 'batch-trace',
            element: <BatchTracePage />,
          },
          {
            path: 'shortbook',
            element: <ShortbookPage />,
          },
          {
            path: 'consignments',
            element: <ConsignmentsPage />,
          },
          {
            path: 'barcode-labels',
            element: <BarcodeLabelsPage />,
          },
          {
            path: 'picklists',
            element: <PicklistsPage />,
          },
          {
            path: 'picklists/:picklistId',
            element: <PicklistDetailPage />,
          },
          {
            path: 'transfer-orders',
            element: <TransferOrdersPage />,
          },
          {
            path: 'transfer-orders/new',
            element: <TransferOrderCreatePage />,
          },
          {
            path: 'transfer-orders/:transferOrderId',
            element: <TransferOrderDetailPage />,
          },
          {
            path: 'inventory/transfers',
            element: <TransferOrdersPage />,
          },
          {
            path: 'inventory/transfers/new',
            element: <TransferOrderCreatePage />,
          },
          {
            path: 'inventory/transfers/:transferOrderId',
            element: <TransferOrderDetailPage />,
          },
          {
            path: 'stock-counts',
            element: <StockCountsPage />,
          },
          {
            path: 'stock-counts/:countId',
            element: <StockCountDetailPage />,
          },
          {
            path: 'inventory/stock-count',
            element: <StockCountsPage />,
          },
          {
            path: 'inventory/stock-count/:countId',
            element: <StockCountDetailPage />,
          },
          {
            path: 'inventory/batches',
            element: <BatchesPage />,
          },
          {
            path: 'warehouses',
            element: <WarehousesPage />,
          },
          {
            path: 'warehouses/:warehouseId',
            element: <WarehouseDetailPage />,
          },
          {
            path: 'price-lists',
            element: <PriceListsPage />,
          },
          {
            path: 'schemes',
            element: <SchemesPage />,
          },
          {
            path: 'price-lists/:priceListId',
            element: <PriceListDetailPage />,
          },
          {
            path: 'inventory/uoms',
            element: <UomsPage />,
          },
          {
            path: 'inventory/rack-locations',
            element: <RackLocationsPage />,
          },
          {
            path: 'inventory/putaway-tasks',
            element: <PutawayTasksPage />,
          },
          {
            path: 'inventory/putaway-tasks/new',
            element: <PutawayCreatePage />,
          },
          {
            path: 'inventory/putaway-tasks/:taskId',
            element: <PutawayDetailPage />,
          },
          {
            path: 'inventory/serial-numbers',
            element: <SerialNumbersPage />,
          },
          {
            path: 'sales-orders',
            element: <SalesOrdersPage />,
          },
          {
            path: 'sales-orders/new',
            element: <SalesOrderCreatePage />,
          },
          {
            path: 'sales-orders/:orderId',
            element: <SalesOrderDetailPage />,
          },
          {
            path: 'delivery-challans',
            element: <DeliveryChallansPage />,
          },
          {
            path: 'delivery-challans/new',
            element: <DeliveryChallanCreatePage />,
          },
          {
            path: 'delivery-challans/:challanId',
            element: <DeliveryChallanDetailPage />,
          },
          {
            path: 'invoices',
            element: <InvoicesPage />,
          },
          {
            path: 'invoices/new',
            element: <InvoiceCreatePage />,
          },
          {
            path: 'invoices/:invoiceId',
            element: <InvoiceDetailPage />,
          },
          {
            path: 'payments',
            element: <PaymentsPage />,
          },
          {
            path: 'payments/new',
            element: <PaymentCreatePage />,
          },
          {
            path: 'payments/:paymentId',
            element: <PaymentDetailPage />,
          },
          {
            path: 'credit-notes',
            element: <CreditNotesPage />,
          },
          {
            path: 'credit-notes/new',
            element: <CreditNoteCreatePage />,
          },
          {
            path: 'credit-notes/:creditNoteId',
            element: <CreditNoteDetailPage />,
          },
          {
            path: 'estimates',
            element: <EstimatesPage />,
          },
          {
            path: 'estimates/new',
            element: <EstimateCreatePage />,
          },
          {
            path: 'estimates/:estimateId',
            element: <EstimateDetailPage />,
          },
          {
            path: 'recurring-invoices',
            element: <RecurringInvoicesPage />,
          },
          {
            path: 'recurring-invoices/:profileId',
            element: <RecurringInvoiceDetailPage />,
          },
          {
            path: 'recurring-bills',
            element: <RecurringBillsPage />,
          },
          {
            path: 'recurring-bills/:profileId',
            element: <RecurringBillDetailPage />,
          },
          {
            path: 'recurring-journals',
            element: <RecurringJournalsPage />,
          },
          {
            path: 'recurring-journals/:profileId',
            element: <RecurringJournalDetailPage />,
          },
          {
            path: 'pos',
            element: <PosCheckoutPage />,
          },
          {
            path: 'pos/receipts',
            element: <SalesReceiptsPage />,
          },
          {
            path: 'pos/receipts/:receiptId',
            element: <SalesReceiptDetailPage />,
          },
          {
            path: 'pos/cash-registers',
            element: <CashRegisterPage />,
          },
          {
            path: 'pos/register',
            element: <CashRegisterPage />,
          },
          {
            path: 'pos/offline-sync',
            element: <PosOfflineSyncPage />,
          },
          {
            path: 'pos/settings',
            element: <PosReceiptSettingsPage />,
          },
          {
            path: 'settings/pos-receipt',
            element: <PosReceiptSettingsPage />,
          },
          {
            path: 'sales-receipts',
            element: <SalesReceiptsPage />,
          },
          {
            path: 'sales-receipts/:receiptId',
            element: <SalesReceiptDetailPage />,
          },
          {
            path: 'loyalty',
            element: <LoyaltyPage />,
          },
          {
            path: 'purchase-orders',
            element: <PurchaseOrdersPage />,
          },
          {
            path: 'purchase-orders/new',
            element: <PurchaseOrderCreatePage />,
          },
          {
            path: 'purchase-orders/:orderId',
            element: <PurchaseOrderDetailPage />,
          },
          {
            path: 'stock-receipts',
            element: <StockReceiptsPage />,
          },
          {
            path: 'stock-receipts/new',
            element: <StockReceiptCreatePage />,
          },
          {
            path: 'stock-receipts/:receiptId',
            element: <StockReceiptDetailPage />,
          },
          {
            path: 'bills',
            element: <BillsPage />,
          },
          {
            path: 'bills/new',
            element: <BillCreatePage />,
          },
          {
            path: 'bills/:billId',
            element: <BillDetailPage />,
          },
          {
            path: 'bills/:billId/three-way-match',
            element: <ThreeWayMatchWorkbenchPage />,
          },
          {
            path: 'three-way-match',
            element: <ThreeWayMatchPage />,
          },
          {
            path: 'vendor-credits',
            element: <VendorCreditsPage />,
          },
          {
            path: 'vendor-credits/:creditId',
            element: <VendorCreditDetailPage />,
          },
          {
            path: 'reports/ap-aging',
            element: <ApAgingReportPage />,
          },
          {
            path: 'vendor-payments',
            element: <VendorPaymentsPage />,
          },
          {
            path: 'vendor-payments/new',
            element: <VendorPaymentCreatePage />,
          },
          {
            path: 'vendor-payments/:paymentId',
            element: <VendorPaymentDetailPage />,
          },
          {
            path: 'debit-notes',
            element: <DebitNotesPage />,
          },
          {
            path: 'debit-notes/new',
            element: <DebitNoteCreatePage />,
          },
          {
            path: 'debit-notes/:noteId',
            element: <DebitNoteDetailPage />,
          },
          {
            path: 'work-orders',
            element: <WorkOrdersPage />,
          },
          {
            path: 'work-orders/:orderId',
            element: <WorkOrderDetailPage />,
          },
          {
            path: 'bom-manager',
            element: <BomManagerPage />,
          },
          {
            path: 'bom-manager/:itemId',
            element: <BomManagerPage />,
          },
          {
            path: 'routings',
            element: <RoutingsPage />,
          },
          {
            path: 'mrp',
            element: <MrpPage />,
          },
          {
            path: 'job-work',
            element: <JobWorkPage />,
          },
          {
            path: 'job-work/:jobWorkId',
            element: <JobWorkDetailPage />,
          },
          {
            path: 'qc-inspections',
            element: <QcInspectionsPage />,
          },
          {
            path: 'qc-inspections/:inspectionId',
            element: <QcInspectionDetailPage />,
          },
          {
            path: 'qc-templates',
            element: <QcTemplatesPage />,
          },
          {
            path: 'ncrs',
            element: <NcrsPage />,
          },
          {
            path: 'ncrs/:ncrId',
            element: <NcrDetailPage />,
          },
          {
            path: 'capa',
            element: <CapaPage />,
          },
          {
            path: 'capa/:capaId',
            element: <CapaDetailPage />,
          },
          {
            path: 'work-centers',
            element: <WorkCentersPage />,
          },
          {
            path: 'work-centers/:workCenterId',
            element: <WorkCenterDetailPage />,
          },
          {
            path: 'maintenance-schedules',
            element: <MaintenanceSchedulesPage />,
          },
          {
            path: 'maintenance-work-orders',
            element: <MaintenanceWorkOrdersPage />,
          },
          {
            path: 'maintenance-work-orders/:orderId',
            element: <MaintenanceWorkOrderDetailPage />,
          },
          {
            path: 'reports/manufacturing',
            element: <ManufacturingReportsPage />,
          },
          {
            path: 'field-sales/dashboard',
            element: <SalesmanDashboardPage />,
          },
          {
            path: 'field-sales/live-tracking',
            element: <LiveTrackingPage />,
          },
          {
            path: 'field-sales/merchandising',
            element: <StoreMerchandisingPage />,
          },
          {
            path: 'field-sales/tour-plans',
            element: <TourPlansPage />,
          },
          {
            path: 'field-sales/tour-plans/:planId',
            element: <TourPlanDetailPage />,
          },
          {
            path: 'field-sales/dcr',
            element: <DcrPage />,
          },
          {
            path: 'field-sales/dcr/:dcrId',
            element: <DcrDetailPage />,
          },
          {
            path: 'field-sales/mr-approvals',
            element: <MrApprovalsPage />,
          },
          {
            path: 'field-sales/approvals',
            element: <MrApprovalsPage />,
          },
          {
            path: 'field-sales/samples',
            element: <FieldSamplesPage />,
          },
          {
            path: 'field-sales/coverage',
            element: <FieldCoveragePage />,
          },
          {
            path: 'field-sales/targets',
            element: <SalesmanTargetsPage />,
          },
          {
            path: 'field-sales/attendance',
            element: <FieldAttendancePage />,
          },
          {
            path: 'field-sales/detail-aids',
            element: <DetailAidsPage />,
          },
          {
            path: 'field-sales/secondary-sales',
            element: <SecondarySalesPage />,
          },
          {
            path: 'field-sales/rcpa',
            element: <RcpaPage />,
          },
          {
            path: 'field-sales/org-chart',
            element: <FieldOrgChartPage />,
          },
          {
            path: 'field-sales/beats',
            element: <BeatsPage />,
          },
          {
            path: 'field-sales/beats/:beatId',
            element: <BeatDetailPage />,
          },
          {
            path: 'field-sales/routes',
            element: <RoutesPage />,
          },
          {
            path: 'field-sales/routes/:routeId',
            element: <RouteDetailPage />,
          },
          {
            path: 'field-sales/assignments',
            element: <TeamAssignmentsPage />,
          },
          {
            path: 'field-sales/vans',
            element: <VansPage />,
          },
          {
            path: 'field-sales/vans/:vanId',
            element: <VanDetailPage />,
          },
          {
            path: 'field-sales/executions',
            element: <RouteExecutionsPage />,
          },
          {
            path: 'field-sales/executions/:executionId',
            element: <RouteExecutionDetailPage />,
          },
          {
            path: 'field-sales/day-close',
            element: <DayClosePage />,
          },
          {
            path: 'beats',
            element: <BeatsPage />,
          },
          {
            path: 'beats/:beatId',
            element: <BeatDetailPage />,
          },
          {
            path: 'routes',
            element: <RoutesPage />,
          },
          {
            path: 'routes/:routeId',
            element: <RouteDetailPage />,
          },
          {
            path: 'vans',
            element: <VansPage />,
          },
          {
            path: 'vans/:vanId',
            element: <VanDetailPage />,
          },
          {
            path: 'mr/dcr',
            element: <DcrPage />,
          },
          {
            path: 'mr/dcr/:dcrId',
            element: <DcrDetailPage />,
          },
          {
            path: 'mr/tour-plans',
            element: <TourPlansPage />,
          },
          {
            path: 'mr/tour-plans/:planId',
            element: <TourPlanDetailPage />,
          },
          {
            path: 'mr/detail-aids',
            element: <DetailAidsPage />,
          },
          {
            path: 'mr/samples',
            element: <FieldSamplesPage />,
          },
          {
            path: 'mr/rcpa',
            element: <RcpaPage />,
          },
          {
            path: 'mr/secondary-sales',
            element: <SecondarySalesPage />,
          },
          {
            path: 'mr/approvals',
            element: <MrApprovalsPage />,
          },
          {
            path: 'accounting/dashboard',
            element: <AccountingDashboardPage />,
          },
          {
            path: 'budgets',
            element: <BudgetsPage />,
          },
          {
            path: 'fiscal-periods',
            element: <FiscalPeriodsPage />,
          },
          {
            path: 'accounts',
            element: <AccountsPage />,
          },
          {
            path: 'accounts/:accountId',
            element: <AccountDetailPage />,
          },
          {
            path: 'journals',
            element: <JournalsPage />,
          },
          {
            path: 'journals/new',
            element: <JournalCreatePage />,
          },
          {
            path: 'journals/:journalId',
            element: <JournalDetailPage />,
          },
          {
            path: 'fixed-assets',
            element: <FixedAssetsPage />,
          },
          {
            path: 'fixed-assets/:assetId',
            element: <FixedAssetDetailPage />,
          },
          {
            path: 'amortization',
            element: <AmortizationPage />,
          },
          {
            path: 'amortization/:scheduleId',
            element: <AmortizationDetailPage />,
          },
          {
            path: 'banking',
            element: <BankingPage />,
          },
          {
            path: 'employees',
            element: <EmployeesPage />,
          },
          {
            path: 'employees/:employeeId',
            element: <EmployeeDetailPage />,
          },
          {
            path: 'payroll/employees',
            element: <EmployeesPage />,
          },
          {
            path: 'payroll/employees/:employeeId',
            element: <EmployeeDetailPage />,
          },
          {
            path: 'payroll-runs',
            element: <PayrollRunsPage />,
          },
          {
            path: 'payroll-runs/:runId',
            element: <PayrollRunDetailPage />,
          },
          {
            path: 'payroll/runs',
            element: <PayrollRunsPage />,
          },
          {
            path: 'payroll/runs/:runId',
            element: <PayrollRunDetailPage />,
          },
          {
            path: 'settings/payroll',
            element: <PayrollSettingsPage />,
          },
          {
            path: 'payroll/settings',
            element: <PayrollSettingsPage />,
          },
          {
            path: 'payroll/tax-declaration',
            element: <TaxDeclarationPage />,
          },
          {
            path: 'payroll/labor-pay-preview',
            element: <LaborPayPreviewPage />,
          },
          {
            path: 'payroll/kenya-paye',
            element: <KenyaPayeCalculatorPage />,
          },
          {
            path: 'attendance',
            element: <AttendancePage />,
          },
          {
            path: 'hr/attendance',
            element: <AttendancePage />,
          },
          {
            path: 'leaves',
            element: <LeavesPage />,
          },
          {
            path: 'hr/leave',
            element: <LeavesPage />,
          },
          {
            path: 'shifts',
            element: <ShiftsPage />,
          },
          {
            path: 'hr/shifts',
            element: <ShiftsPage />,
          },
          {
            path: 'timesheets',
            element: <TimesheetsPage />,
          },
          {
            path: 'hr/timesheets',
            element: <TimesheetsPage />,
          },
          {
            path: 'hr-tickets',
            element: <HrTicketsPage />,
          },
          {
            path: 'hr-tickets/:ticketId',
            element: <HrTicketDetailPage />,
          },
          {
            path: 'hr/helpdesk',
            element: <HrTicketsPage />,
          },
          {
            path: 'hr/helpdesk/:ticketId',
            element: <HrTicketDetailPage />,
          },
          {
            path: 'hr/documents',
            element: <EmployeeDocumentsPage />,
          },
          {
            path: 'hr/analytics',
            element: <HrAnalyticsPage />,
          },
          {
            path: 'offboarding',
            element: <OffboardingPage />,
          },
          {
            path: 'offboarding/:offboardingId',
            element: <OffboardingDetailPage />,
          },
          {
            path: 'hr/offboarding',
            element: <OffboardingPage />,
          },
          {
            path: 'hr/offboarding/:offboardingId',
            element: <OffboardingDetailPage />,
          },
          {
            path: 'hr/my-profile',
            element: <MyProfilePage />,
          },
          {
            path: 'biometric-devices',
            element: <BiometricDevicesPage />,
          },
          {
            path: 'hr/biometric',
            element: <BiometricDevicesPage />,
          },
          {
            path: 'reports',
            element: <ReportsHubPage />,
          },
          {
            path: 'reports/:reportKey',
            element: <ReportViewerPage />,
          },
          {
            path: 'saved-reports',
            element: <SavedReportsPage />,
          },
          {
            path: 'saved-reports/:reportId',
            element: <SavedReportDetailPage />,
          },
          {
            path: 'gst',
            element: <GstCompliancePage />,
          },
          {
            path: 'compliance/tds',
            element: <TdsCompliancePage />,
          },
          {
            path: 'compliance/tcs',
            element: <TcsCompliancePage />,
          },
          {
            path: 'settings/tax-accounts',
            element: <TaxAccountMappingsPage />,
          },
          {
            path: 'tax-groups',
            element: <TaxGroupsPage />,
          },
          {
            path: 'franchise',
            element: <FranchisePage />,
          },
          {
            path: 'franchise/:nodeId',
            element: <FranchiseNodeDetailPage />,
          },
          {
            path: 'compliance/kenya',
            element: <KenyaCompliancePage />,
          },
          {
            path: 'reports/cash-runway',
            element: <CashRunwayPage />,
          },
          {
            path: 'reports/flux-commentary',
            element: <FluxCommentaryPage />,
          },
          {
            path: 'settings/users',
            element: <UsersPage />,
          },
          {
            path: 'settings/payment-terms',
            element: <PaymentTermsPage />,
          },
          {
            path: 'settings/pdf-templates',
            element: <PdfTemplateCustomizerPage />,
          },
          {
            path: 'pharmacy-masters',
            element: <PharmacyMastersPage />,
          },
          {
            path: 'near-expiry',
            element: <NearExpiryPage />,
          },
          {
            path: 'courier/shipments',
            element: <CourierShipmentsPage />,
          },
          {
            path: 'courier/shipments/:shipmentId',
            element: <CourierShipmentDetailPage />,
          },
          {
            path: 'courier/cod-remittances',
            element: <CodRemittancesPage />,
          },
          {
            path: 'courier/cod-remittances/:remittanceId',
            element: <CodRemittanceDetailPage />,
          },
          {
            path: 'settings/couriers',
            element: <CourierSettingsPage />,
          },
          {
            path: 'transport/lorry-receipts',
            element: <LorryReceiptsPage />,
          },
          {
            path: 'transport/lorry-receipts/:lrId',
            element: <LorryReceiptDetailPage />,
          },
          {
            path: 'transport/rate-cards',
            element: <FreightRateCardsPage />,
          },
          {
            path: 'transport/vehicle-logs',
            element: <VehicleLogsPage />,
          },
          {
            path: 'ai',
            element: <AiCommandCenterPage />,
          },
          {
            path: 'settings/ai',
            element: <AiSettingsPage />,
          },
          {
            path: 'ca',
            element: <CaDashboardPage />,
          },
          {
            path: 'ca/compliance',
            element: <CaCompliancePage />,
          },
          {
            path: 'ca/alerts',
            element: <CaAlertsPage />,
          },
          {
            path: 'ca/dispatch',
            element: <CaDispatchPage />,
          },
          { path: 'partner-network/partners', lazy: async () => ({ Component: (await import('@/features/partner-network/partners-page')).PartnersPage }) },
          { path: 'partner-network/catalog', lazy: async () => ({ Component: (await import('@/features/partner-network/catalog-page')).CatalogPage }) },
          { path: 'partner-network/supplier-search', lazy: async () => { const { CatalogPage } = await import('@/features/partner-network/catalog-page'); return { Component: () => <CatalogPage supplier /> } } },
          { path: 'partner-network/outgoing', lazy: async () => { const { NetworkOrdersPage } = await import('@/features/partner-network/network-orders-page'); return { Component: () => <NetworkOrdersPage direction="outgoing" /> } } },
          { path: 'partner-network/incoming', lazy: async () => { const { NetworkOrdersPage } = await import('@/features/partner-network/network-orders-page'); return { Component: () => <NetworkOrdersPage direction="incoming" /> } } },
          { path: 'partner-network/orders/:orderId', lazy: async () => ({ Component: (await import('@/features/partner-network/network-orders-page')).NetworkOrderDetailPage }) },
          { path: 'supply-chain', lazy: async () => ({ Component: (await import('@/features/supply-chain/planning-dashboard-page')).PlanningDashboardPage }) },
          { path: 'supply-chain/requisitions', lazy: async () => ({ Component: (await import('@/features/supply-chain/requisitions-page')).RequisitionsPage }) },
          { path: 'supply-chain/requisitions/:requisitionId', lazy: async () => ({ Component: (await import('@/features/supply-chain/requisitions-page')).RequisitionDetailPage }) },
          { path: 'supply-chain/shipments', lazy: async () => ({ Component: (await import('@/features/supply-chain/shipments-page')).SupplyShipmentsPage }) },
          { path: 'supply-chain/shipments/:shipmentId', lazy: async () => ({ Component: (await import('@/features/supply-chain/shipments-page')).SupplyShipmentDetailPage }) },
          { path: 'supply-chain/returns', lazy: async () => ({ Component: (await import('@/features/supply-chain/supply-returns-page')).SupplyReturnsPage }) },
          { path: 'supply-chain/alerts', lazy: async () => ({ Component: (await import('@/features/supply-chain/supply-alerts-page')).SupplyAlertsPage }) },
          { path: 'supply-chain/forecasts', lazy: async () => ({ Component: (await import('@/features/supply-chain/forecasts-page')).ForecastsPage }) },
          { path: 'supply-chain/reorder-policies', lazy: async () => ({ Component: (await import('@/features/supply-chain/reorder-policies-page')).ReorderPoliciesPage }) },
          { path: 'supply-chain/item-suppliers', lazy: async () => ({ Component: (await import('@/features/supply-chain/item-suppliers-page')).ItemSuppliersPage }) },
          { path: 'supply-chain/supplier-performance', lazy: async () => ({ Component: (await import('@/features/supply-chain/supplier-performance-page')).SupplierPerformancePage }) },
          { path: 'supply-chain/turnover', lazy: async () => ({ Component: (await import('@/features/supply-chain/turnover-page')).InventoryTurnoverPage }) },
          { path: 'settings/portal-users', lazy: async () => ({ Component: (await import('@/features/portal-admin/portal-accounts-page')).PortalAccountsPage }) },
        ],
      },
    ],
  },
  {
    path: '*',
    element: <Navigate to={appRoutes.overview} replace />,
  },
])
