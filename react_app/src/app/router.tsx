import { AiCommandCenterPage } from '@/features/ai/ai-command-center-page'
import { AiSettingsPage } from '@/features/ai/ai-settings-page'
import { CaDashboardPage } from '@/features/ca/ca-dashboard-page'
import { CaCompliancePage } from '@/features/ca/ca-compliance-page'
import { CaAlertsPage } from '@/features/ca/ca-alerts-page'
import { CaDispatchPage } from '@/features/ca/ca-dispatch-page'
import { createBrowserRouter, Navigate, Outlet } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { AppShell } from '@/app/shell/app-shell'
import { AccountDetailPage } from '@/features/accounts/account-detail-page'
import { AccountsPage } from '@/features/accounts/accounts-page'
import { BudgetsPage } from '@/features/budgets/budgets-page'
import { FiscalPeriodsPage } from '@/features/fiscal-periods/fiscal-periods-page'
import { AmortizationDetailPage } from '@/features/amortization/amortization-detail-page'
import { AmortizationPage } from '@/features/amortization/amortization-page'
import { ApAgingReportPage } from '@/features/ap/ap-aging-report-page'
import { BeatDetailPage } from '@/features/field-sales/beat-detail-page'
import { BeatsPage } from '@/features/field-sales/beats-page'
import { RoutesPage } from '@/features/field-sales/routes-page'
import { RouteDetailPage } from '@/features/field-sales/route-detail-page'
import { RouteExecutionsPage } from '@/features/field-sales/route-executions-page'
import { RouteExecutionDetailPage } from '@/features/field-sales/route-execution-detail-page'
import { DayClosePage } from '@/features/field-sales/day-close-page'
import { SalesmanTargetsPage } from '@/features/field-sales/salesman-targets-page'
import { StoreMerchandisingPage } from '@/features/field-sales/store-merchandising-page'
import { DcrPage } from '@/features/mr/dcr-page'
import { DcrDetailPage } from '@/features/mr/dcr-detail-page'
import { TourPlansPage } from '@/features/mr/tour-plans-page'
import { TourPlanDetailPage } from '@/features/mr/tour-plan-detail-page'
import { DetailAidsPage } from '@/features/mr/detail-aids-page'
import { FieldSamplesPage } from '@/features/mr/field-samples-page'
import { RcpaPage } from '@/features/mr/rcpa-page'
import { SecondarySalesPage } from '@/features/mr/secondary-sales-page'
import { MrApprovalsPage } from '@/features/mr/mr-approvals-page'
import { BankingPage } from '@/features/banking/banking-page'
import { BillsPage } from '@/features/bills/bills-page'
import { BillCreatePage } from '@/features/bills/bill-create-page'
import { BillDetailPage } from '@/features/bills/bill-detail-page'
import { ThreeWayMatchPage } from '@/features/bills/three-way-match-page'
import { ThreeWayMatchWorkbenchPage } from '@/features/bills/three-way-match-workbench-page'
import { BomManagerPage } from '@/features/bom/bom-manager-page'
import { CapaDetailPage } from '@/features/capa/capa-detail-page'
import { CapaPage } from '@/features/capa/capa-page'
import { ContactsPage } from '@/features/contacts/contacts-page'
import { ContactCreatePage } from '@/features/contacts/contact-create-page'
import { ContactDetailPage } from '@/features/contacts/contact-detail-page'
import { ContactStatementPage } from '@/features/contacts/contact-statement-page'
import { CreditNoteDetailPage } from '@/features/credit-notes/credit-note-detail-page'
import { CreditNoteCreatePage } from '@/features/credit-notes/credit-note-create-page'
import { CreditNotesPage } from '@/features/credit-notes/credit-notes-page'
import { AccountingDashboardPage } from '@/features/dashboard/accounting-dashboard-page'
import { DashboardPage } from '@/features/dashboard/dashboard-page'
import { DebitNoteDetailPage } from '@/features/debit-notes/debit-note-detail-page'
import { DebitNoteCreatePage } from '@/features/debit-notes/debit-note-create-page'
import { DebitNotesPage } from '@/features/debit-notes/debit-notes-page'
import { DeliveryChallanDetailPage } from '@/features/delivery-challans/delivery-challan-detail-page'
import { DeliveryChallanCreatePage } from '@/features/delivery-challans/delivery-challan-create-page'
import { DeliveryChallansPage } from '@/features/delivery-challans/delivery-challans-page'
import { AttendancePage } from '@/features/hr/attendance-page'
import { BiometricDevicesPage } from '@/features/hr/biometric-devices-page'
import { HrTicketDetailPage } from '@/features/hr/hr-ticket-detail-page'
import { HrTicketsPage } from '@/features/hr/hr-tickets-page'
import { LeavesPage } from '@/features/hr/leaves-page'
import { OffboardingDetailPage } from '@/features/hr/offboarding-detail-page'
import { OffboardingPage } from '@/features/hr/offboarding-page'
import { ShiftsPage } from '@/features/hr/shifts-page'
import { TimesheetsPage } from '@/features/hr/timesheets-page'
import { EmployeeDetailPage } from '@/features/payroll/employee-detail-page'
import { EmployeesPage } from '@/features/payroll/employees-page'
import { PayrollSettingsPage } from '@/features/payroll/payroll-settings-page'
import { FixedAssetDetailPage } from '@/features/fixed-assets/fixed-asset-detail-page'
import { FixedAssetsPage } from '@/features/fixed-assets/fixed-assets-page'
import { GstCompliancePage } from '@/features/gst/gst-compliance-page'
import { TdsCompliancePage } from '@/features/tax/tds-compliance-page'
import { TcsCompliancePage } from '@/features/tax/tcs-compliance-page'
import { TaxAccountMappingsPage } from '@/features/tax/tax-account-mappings-page'
import { TaxGroupsPage } from '@/features/tax/tax-groups-page'
import { UomsPage } from '@/features/inventory/uoms-page'
import { FranchisePage } from '@/features/franchise/franchise-page'
import { FranchiseNodeDetailPage } from '@/features/franchise/franchise-node-detail-page'
import { KenyaCompliancePage } from '@/features/kenya/kenya-compliance-page'
import { CashRunwayPage } from '@/features/analytics/cash-runway-page'
import { FluxCommentaryPage } from '@/features/analytics/flux-commentary-page'
import { UsersPage } from '@/features/settings/users-page'
import { PaymentTermsPage } from '@/features/settings/payment-terms-page'
import { PdfTemplateCustomizerPage } from '@/features/settings/pdf-template-customizer-page'
import { ItemDetailPage } from '@/features/items/item-detail-page'
import { ItemFormPage } from '@/features/items/item-form-page'
import { ItemsPage } from '@/features/items/items-page'
import { StockSummaryPage } from '@/features/inventory/stock-summary-page'
import { BatchTracePage } from '@/features/inventory/batch-trace-page'
import { ShortbookPage } from '@/features/inventory/shortbook-page'
import { ConsignmentsPage } from '@/features/inventory/consignments-page'
import { BarcodeLabelsPage } from '@/features/inventory/barcode-labels-page'
import { JobWorkDetailPage } from '@/features/job-work/job-work-detail-page'
import { JobWorkPage } from '@/features/job-work/job-work-page'
import { JournalDetailPage } from '@/features/journals/journal-detail-page'
import { JournalCreatePage } from '@/features/journals/journal-create-page'
import { JournalsPage } from '@/features/journals/journals-page'
import { LoginPage } from '@/features/auth/login-page'
import { MaintenanceSchedulesPage } from '@/features/maintenance/maintenance-schedules-page'
import { MaintenanceWorkOrderDetailPage } from '@/features/maintenance/maintenance-work-order-detail-page'
import { MaintenanceWorkOrdersPage } from '@/features/maintenance/maintenance-work-orders-page'
import { ManufacturingReportsPage } from '@/features/manufacturing/manufacturing-reports-page'
import { MrpPage } from '@/features/mrp/mrp-page'
import { NcrDetailPage } from '@/features/ncrs/ncr-detail-page'
import { NcrsPage } from '@/features/ncrs/ncrs-page'
import { PaymentDetailPage } from '@/features/payments/payment-detail-page'
import { PaymentCreatePage } from '@/features/payments/payment-create-page'
import { PaymentsPage } from '@/features/payments/payments-page'
import { PayrollRunDetailPage } from '@/features/payroll/payroll-run-detail-page'
import { PayrollRunsPage } from '@/features/payroll/payroll-runs-page'
import { PharmacyMastersPage } from '@/features/pharmacy/pharmacy-masters-page'
import { NearExpiryPage } from '@/features/pharmacy/near-expiry-page'
import { CashRegisterPage } from '@/features/pos/cash-register-page'
import { PosCheckoutPage } from '@/features/pos/pos-checkout-page'
import { PosOfflineSyncPage } from '@/features/pos/pos-offline-sync-page'
import { PosReceiptSettingsPage } from '@/features/pos/pos-receipt-settings-page'
import { SalesReceiptDetailPage } from '@/features/pos/sales-receipt-detail-page'
import { SalesReceiptsPage } from '@/features/pos/sales-receipts-page'
import { LoyaltyPage } from '@/features/loyalty/loyalty-page'
import { PicklistDetailPage } from '@/features/picklists/picklist-detail-page'
import { PicklistsPage } from '@/features/picklists/picklists-page'
import { PriceListDetailPage } from '@/features/price-lists/price-list-detail-page'
import { PriceListsPage } from '@/features/price-lists/price-lists-page'
import { PurchaseOrderDetailPage } from '@/features/purchase-orders/purchase-order-detail-page'
import { PurchaseOrderCreatePage } from '@/features/purchase-orders/purchase-order-create-page'
import { PurchaseOrdersPage } from '@/features/purchase-orders/purchase-orders-page'
import { QcInspectionDetailPage } from '@/features/qc-inspections/qc-inspection-detail-page'
import { QcInspectionsPage } from '@/features/qc-inspections/qc-inspections-page'
import { QcTemplatesPage } from '@/features/qc-inspections/qc-templates-page'
import { RoutingsPage } from '@/features/routings/routings-page'
import { InvoiceDetailPage } from '@/features/invoices/invoice-detail-page'
import { InvoiceCreatePage } from '@/features/invoices/invoice-create-page'
import { InvoicesPage } from '@/features/invoices/invoices-page'
import { EstimatesPage } from '@/features/estimates/estimates-page'
import { EstimateCreatePage } from '@/features/estimates/estimate-create-page'
import { EstimateDetailPage } from '@/features/estimates/estimate-detail-page'
import { RecurringInvoicesPage } from '@/features/recurring/recurring-invoices-page'
import { RecurringInvoiceDetailPage } from '@/features/recurring/recurring-invoice-detail-page'
import { RecurringBillsPage } from '@/features/recurring/recurring-bills-page'
import { RecurringBillDetailPage } from '@/features/recurring/recurring-bill-detail-page'
import { RecurringJournalsPage } from '@/features/recurring/recurring-journals-page'
import { RecurringJournalDetailPage } from '@/features/recurring/recurring-journal-detail-page'
import { ReportsHubPage } from '@/features/reports/reports-hub-page'
import { ReportViewerPage } from '@/features/reports/report-viewer-page'
import { SavedReportDetailPage } from '@/features/reports/saved-report-detail-page'
import { SavedReportsPage } from '@/features/reports/saved-reports-page'
import { SalesOrderDetailPage } from '@/features/sales-orders/sales-order-detail-page'
import { SalesOrderCreatePage } from '@/features/sales-orders/sales-order-create-page'
import { SalesOrdersPage } from '@/features/sales-orders/sales-orders-page'
import { StockCountDetailPage } from '@/features/stock-counts/stock-count-detail-page'
import { StockCountsPage } from '@/features/stock-counts/stock-counts-page'
import { StockReceiptDetailPage } from '@/features/stock-receipts/stock-receipt-detail-page'
import { StockReceiptCreatePage } from '@/features/stock-receipts/stock-receipt-create-page'
import { StockReceiptsPage } from '@/features/stock-receipts/stock-receipts-page'
import { TransferOrderDetailPage } from '@/features/inventory/transfer-order-detail-page'
import { TransferOrdersPage } from '@/features/inventory/transfer-orders-page'
import { TransferOrderCreatePage } from '@/features/inventory/transfer-order-create-page'
import { BatchesPage } from '@/features/inventory/batches-page'
import { VanDetailPage } from '@/features/field-sales/van-detail-page'
import { VansPage } from '@/features/field-sales/vans-page'
import { VendorCreditDetailPage } from '@/features/vendor-credits/vendor-credit-detail-page'
import { VendorCreditsPage } from '@/features/vendor-credits/vendor-credits-page'
import { VendorPaymentDetailPage } from '@/features/vendor-payments/vendor-payment-detail-page'
import { VendorPaymentCreatePage } from '@/features/vendor-payments/vendor-payment-create-page'
import { VendorPaymentsPage } from '@/features/vendor-payments/vendor-payments-page'
import { WarehouseDetailPage } from '@/features/warehouses/warehouse-detail-page'
import { WarehousesPage } from '@/features/warehouses/warehouses-page'
import { WorkCenterDetailPage } from '@/features/maintenance/work-center-detail-page'
import { WorkCentersPage } from '@/features/maintenance/work-centers-page'
import { WorkOrderDetailPage } from '@/features/work-orders/work-order-detail-page'
import { WorkOrdersPage } from '@/features/work-orders/work-orders-page'
import { CourierShipmentsPage } from '@/features/transport/courier-shipments-page'
import { CourierShipmentDetailPage } from '@/features/transport/courier-shipment-detail-page'
import { CodRemittancesPage } from '@/features/transport/cod-remittances-page'
import { CodRemittanceDetailPage } from '@/features/transport/cod-remittance-detail-page'
import { CourierSettingsPage } from '@/features/transport/courier-settings-page'
import { LorryReceiptsPage } from '@/features/transport/lorry-receipts-page'
import { LorryReceiptDetailPage } from '@/features/transport/lorry-receipt-detail-page'
import { FreightRateCardsPage } from '@/features/transport/freight-rate-cards-page'
import { VehicleLogsPage } from '@/features/transport/vehicle-logs-page'
import { useSessionStore } from '@/shared/session/session-store'

function SessionLoading() {
  return (
    <main className="session-loading" aria-live="polite">
      <span className="brand-mark" aria-hidden="true">K</span>
      <p>Restoring your workspace</p>
    </main>
  )
}

function ProtectedRoute() {
  const status = useSessionStore((state) => state.status)

  if (status === 'booting') return <SessionLoading />
  if (status !== 'authenticated') return <Navigate to="/login" replace />
  return <Outlet />
}

function PublicRoute() {
  const status = useSessionStore((state) => state.status)

  if (status === 'booting') return <SessionLoading />
  if (status === 'authenticated') return <Navigate to={appRoutes.overview} replace />
  return <Outlet />
}

export const router = createBrowserRouter([
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
            path: 'price-lists/:priceListId',
            element: <PriceListDetailPage />,
          },
          {
            path: 'inventory/uoms',
            element: <UomsPage />,
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
            path: 'field-sales/targets',
            element: <SalesmanTargetsPage />,
          },
          {
            path: 'field-sales/merchandising',
            element: <StoreMerchandisingPage />,
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
            path: 'payroll-runs',
            element: <PayrollRunsPage />,
          },
          {
            path: 'payroll-runs/:runId',
            element: <PayrollRunDetailPage />,
          },
          {
            path: 'settings/payroll',
            element: <PayrollSettingsPage />,
          },
          {
            path: 'attendance',
            element: <AttendancePage />,
          },
          {
            path: 'leaves',
            element: <LeavesPage />,
          },
          {
            path: 'shifts',
            element: <ShiftsPage />,
          },
          {
            path: 'timesheets',
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
            path: 'offboarding',
            element: <OffboardingPage />,
          },
          {
            path: 'offboarding/:offboardingId',
            element: <OffboardingDetailPage />,
          },
          {
            path: 'biometric-devices',
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
        ],
      },
    ],
  },
  {
    path: '*',
    element: <Navigate to={appRoutes.overview} replace />,
  },
])
