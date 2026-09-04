import {
  Sparkles,
  TrendingUp,
  Palette,
  Globe,
  Store,
  AlertOctagon,
  ArrowLeftRight,
  ArrowUpRight,
  Award,
  Banknote,
  BarChart3,
  Bookmark,
  BookOpen,
  Boxes,
  Briefcase,
  Building,
  Building2,
  CalendarClock,
  ClipboardCheck,
  ClipboardList,
  Clock,
  Cpu,
  DollarSign,
  Factory,
  FileBadge,
  FileMinus,
  FileSpreadsheet,
  FileText,
  Landmark,
  Layers,
  LifeBuoy,
  ListChecks,
  MapPin,
  PackageCheck,
  Pill,
  Printer,
  ReceiptText,
  RefreshCw,
  Settings,
  ShieldAlert,
  ShieldCheck,
  ShoppingBag,
  Tag,
  Truck,
  type LucideIcon,
  UserMinus,
  Users,
  UsersRound,
  Compass,
  Gift,
  Navigation,
  Stethoscope,
  Target,
  Wrench,
  Scale,
} from 'lucide-react'

export const appRoutes = {
  overview: '/',
  contacts: '/contacts',
  contactCreate: '/contacts/new',
  contactDetail: (id: string) => `/contacts/${id}`,
  contactStatement: (id: string) => `/contacts/${id}/statement`,
  items: '/items',
  itemCreate: '/items/new',
  itemEdit: (id: string) => `/items/${id}/edit`,
  itemDetail: (id: string) => `/items/${id}`,
  stockSummary: '/inventory/stock-summary',
  batches: '/inventory/batches',
  batchTrace: '/batch-trace',
  shortbook: '/shortbook',
  consignments: '/consignments',
  barcodeLabels: '/barcode-labels',
  picklists: '/picklists',
  picklistDetail: (id: string) => `/picklists/${id}`,
  transfers: '/inventory/transfers',
  transferOrders: '/transfer-orders',
  transferOrderCreate: '/transfer-orders/new',
  transferOrderDetail: (id: string) => `/transfer-orders/${id}`,
  stockCount: '/inventory/stock-count',
  stockCounts: '/stock-counts',
  stockCountDetail: (id: string) => `/stock-counts/${id}`,
  warehouses: '/warehouses',
  warehouseDetail: (id: string) => `/warehouses/${id}`,
  priceLists: '/price-lists',
  priceListDetail: (id: string) => `/price-lists/${id}`,
  salesOrders: '/sales-orders',
  salesOrderCreate: '/sales-orders/new',
  salesOrderDetail: (id: string) => `/sales-orders/${id}`,
  deliveryChallans: '/delivery-challans',
  deliveryChallanCreate: '/delivery-challans/new',
  deliveryChallanDetail: (id: string) => `/delivery-challans/${id}`,
  invoices: '/invoices',
  invoiceCreate: '/invoices/new',
  invoiceDetail: (id: string) => `/invoices/${id}`,
  payments: '/payments',
  paymentCreate: '/payments/new',
  paymentDetail: (id: string) => `/payments/${id}`,
  creditNotes: '/credit-notes',
  creditNoteCreate: '/credit-notes/new',
  creditNoteDetail: (id: string) => `/credit-notes/${id}`,
  purchaseOrders: '/purchase-orders',
  purchaseOrderCreate: '/purchase-orders/new',
  purchaseOrderDetail: (id: string) => `/purchase-orders/${id}`,
  stockReceipts: '/stock-receipts',
  stockReceiptCreate: '/stock-receipts/new',
  stockReceiptDetail: (id: string) => `/stock-receipts/${id}`,
  bills: '/bills',
  billCreate: '/bills/new',
  billDetail: (id: string) => `/bills/${id}`,
  threeWayMatch: '/three-way-match',
  threeWayMatchWorkbench: (billId: string) => `/bills/${billId}/three-way-match`,
  vendorCredits: '/vendor-credits',
  vendorCreditDetail: (id: string) => `/vendor-credits/${id}`,
  apAgingReport: '/reports/ap-aging',
  vendorPayments: '/vendor-payments',
  vendorPaymentCreate: '/vendor-payments/new',
  vendorPaymentDetail: (id: string) => `/vendor-payments/${id}`,
  debitNotes: '/debit-notes',
  debitNoteCreate: '/debit-notes/new',
  debitNoteDetail: (id: string) => `/debit-notes/${id}`,
  workOrders: '/work-orders',
  workOrderDetail: (id: string) => `/work-orders/${id}`,
  bomManager: '/bom-manager',
  bomManagerItem: (itemId: string) => `/bom-manager/${itemId}`,
  routings: '/routings',
  mrp: '/mrp',
  jobWork: '/job-work',
  jobWorkDetail: (id: string) => `/job-work/${id}`,
  qcInspections: '/qc-inspections',
  qcInspectionDetail: (id: string) => `/qc-inspections/${id}`,
  qcTemplates: '/qc-templates',
  ncrs: '/ncrs',
  ncrDetail: (id: string) => `/ncrs/${id}`,
  capa: '/capa',
  capaDetail: (id: string) => `/capa/${id}`,
  workCenters: '/work-centers',
  workCenterDetail: (id: string) => `/work-centers/${id}`,
  maintenanceSchedules: '/maintenance-schedules',
  maintenanceWorkOrders: '/maintenance-work-orders',
  maintenanceWorkOrderDetail: (id: string) => `/maintenance-work-orders/${id}`,
  manufacturingReports: '/reports/manufacturing',
  accountingDashboard: '/accounting/dashboard',
  budgets: '/budgets',
  fiscalPeriods: '/fiscal-periods',
  accounts: '/accounts',
  accountDetail: (id: string) => `/accounts/${id}`,
  journals: '/journals',
  journalCreate: '/journals/new',
  journalDetail: (id: string) => `/journals/${id}`,
  fixedAssets: '/fixed-assets',
  fixedAssetDetail: (id: string) => `/fixed-assets/${id}`,
  amortization: '/amortization',
  amortizationDetail: (id: string) => `/amortization/${id}`,
  beats: '/beats',
  beatDetail: (id: string) => `/beats/${id}`,
  routes: '/routes',
  routeDetail: (id: string) => `/routes/${id}`,
  vans: '/vans',
  vanDetail: (id: string) => `/vans/${id}`,
  routeExecutions: '/field-sales/executions',
  routeExecutionDetail: (id: string) => `/field-sales/executions/${id}`,
  dayClose: '/field-sales/day-close',
  salesmanTargets: '/field-sales/targets',
  storeMerchandising: '/field-sales/merchandising',
  dcr: '/mr/dcr',
  dcrDetail: (id: string) => `/mr/dcr/${id}`,
  tourPlans: '/mr/tour-plans',
  tourPlanDetail: (id: string) => `/mr/tour-plans/${id}`,
  detailAids: '/mr/detail-aids',
  fieldSamples: '/mr/samples',
  rcpa: '/mr/rcpa',
  secondarySales: '/mr/secondary-sales',
  mrApprovals: '/mr/approvals',
  fieldSalesDashboard: '/field-sales/dashboard',
  fieldSalesLiveTracking: '/field-sales/live-tracking',
  fieldSalesMerchandising: '/field-sales/merchandising',
  fieldSalesTourPlans: '/field-sales/tour-plans',
  fieldSalesTourPlanDetail: (id: string) => `/field-sales/tour-plans/${id}`,
  fieldSalesDcr: '/field-sales/dcr',
  fieldSalesDcrDetail: (id: string) => `/field-sales/dcr/${id}`,
  fieldSalesMrApprovals: '/field-sales/mr-approvals',
  fieldSalesApprovals: '/field-sales/approvals',
  fieldSalesSamples: '/field-sales/samples',
  fieldSalesCoverage: '/field-sales/coverage',
  fieldSalesTargets: '/field-sales/targets',
  fieldSalesAttendance: '/field-sales/attendance',
  fieldSalesDetailAids: '/field-sales/detail-aids',
  fieldSalesSecondarySales: '/field-sales/secondary-sales',
  fieldSalesRcpa: '/field-sales/rcpa',
  fieldSalesOrgChart: '/field-sales/org-chart',
  fieldSalesBeats: '/field-sales/beats',
  fieldSalesBeatDetail: (id: string) => `/field-sales/beats/${id}`,
  fieldSalesRoutes: '/field-sales/routes',
  fieldSalesRouteDetail: (id: string) => `/field-sales/routes/${id}`,
  fieldSalesAssignments: '/field-sales/assignments',
  fieldSalesVans: '/field-sales/vans',
  fieldSalesVanDetail: (id: string) => `/field-sales/vans/${id}`,
  fieldSalesExecutions: '/field-sales/executions',
  fieldSalesExecutionDetail: (id: string) => `/field-sales/executions/${id}`,
  fieldSalesDayClose: '/field-sales/day-close',
  employees: '/employees',
  employeeDetail: (id: string) => `/employees/${id}`,
  payrollRuns: '/payroll-runs',
  payrollRunDetail: (id: string) => `/payroll-runs/${id}`,
  payrollSettings: '/settings/payroll',
  attendance: '/attendance',
  leaves: '/leaves',
  shifts: '/shifts',
  timesheets: '/timesheets',
  hrTickets: '/hr-tickets',
  hrTicketDetail: (id: string) => `/hr-tickets/${id}`,
  offboarding: '/offboarding',
  offboardingDetail: (id: string) => `/offboarding/${id}`,
  biometricDevices: '/biometric-devices',
  reports: '/reports',
  reportViewer: (key: string) => `/reports/${key}`,
  savedReports: '/saved-reports',
  savedReportDetail: (id: string) => `/saved-reports/${id}`,
  pharmacyMasters: '/pharmacy-masters',
  nearExpiry: '/near-expiry',
  pos: '/pos',
  posCashRegisters: '/pos/cash-registers',
  posOfflineSync: '/pos/offline-sync',
  posReceiptSettings: '/settings/pos-receipt',
  salesReceipts: '/sales-receipts',
  salesReceiptDetail: (id: string) => `/sales-receipts/${id}`,
  estimates: '/estimates',
  estimateCreate: '/estimates/new',
  estimateDetail: (id: string) => `/estimates/${id}`,
  recurringInvoices: '/recurring-invoices',
  recurringInvoiceDetail: (id: string) => `/recurring-invoices/${id}`,
  recurringBills: '/recurring-bills',
  recurringBillDetail: (id: string) => `/recurring-bills/${id}`,
  recurringJournals: '/recurring-journals',
  recurringJournalDetail: (id: string) => `/recurring-journals/${id}`,
  loyalty: '/loyalty',
  gst: '/gst',
  banking: '/banking',
  courierShipments: '/courier/shipments',
  courierShipmentDetail: (id: string) => `/courier/shipments/${id}`,
  codRemittances: '/courier/cod-remittances',
  codRemittanceDetail: (id: string) => `/courier/cod-remittances/${id}`,
  courierSettings: '/settings/couriers',
  lorryReceipts: '/transport/lorry-receipts',
  lorryReceiptDetail: (id: string) => `/transport/lorry-receipts/${id}`,
  freightRateCards: '/transport/rate-cards',
  vehicleLogs: '/transport/vehicle-logs',
  tds: '/compliance/tds',
  tcs: '/compliance/tcs',
  taxAccountMappings: '/settings/tax-accounts',
  taxGroups: '/tax-groups',
  uoms: '/inventory/uoms',
  paymentTerms: '/settings/payment-terms',
  franchise: '/franchise',
  franchiseDetail: (nodeId: string) => `/franchise/${nodeId}`,
  kenyaCompliance: '/compliance/kenya',
  cashRunway: '/reports/cash-runway',
  fluxCommentary: '/reports/flux-commentary',
  users: '/settings/users',
  pdfTemplates: '/settings/pdf-templates',
  aiCommandCenter: '/ai',
  aiSettings: '/settings/ai',
  caDashboard: '/ca',
  caCompliance: '/ca/compliance',
  caAlerts: '/ca/alerts',
  caDispatch: '/ca/dispatch',
} as const

export type NavigationContext = {
  role: string | null | undefined
  industry: string | null | undefined
  country: string | null | undefined
  capabilities?: readonly string[]
  disabledIds?: readonly string[]
}

export type NavigationItem = {
  id: string
  label: string
  description: string
  icon: LucideIcon
  to: string
  roles?: readonly string[]
  industries?: readonly string[]
  countries?: readonly string[]
  capability?: string
  labelResolver?: (industry: string | null | undefined) => string
}

export function isPharmaIndustry(industryCode: string | null | undefined): boolean {
  const code = (industryCode ?? '').trim().toUpperCase()
  return code === 'PHARMACY' || code.includes('PHARMA')
}

export function fieldSalesApprovalLabel(industryCode: string | null | undefined): string {
  return isPharmaIndustry(industryCode) ? 'MR Approvals' : 'Field Approvals'
}

export type NavGroup = {
  id: string
  label: string
  description?: string
  icon: LucideIcon
  items: readonly NavigationItem[]
  roles?: readonly string[]
  industries?: readonly string[]
  countries?: readonly string[]
  capability?: string
}

export const topLevelNavItems: readonly NavigationItem[] = [
  {
    id: 'dashboard',
    label: 'Overview',
    description: 'Live business snapshot',
    icon: BarChart3,
    to: appRoutes.overview,
  },
  {
    id: 'ai.command_center',
    label: 'AI Command Center',
    description: 'Autonomous ledger intelligence & Copilot',
    icon: Sparkles,
    to: appRoutes.aiCommandCenter,
  },
  {
    id: 'pos.checkout',
    label: 'Point of Sale',
    description: 'Express counter billing & POS register',
    icon: ShoppingBag,
    to: appRoutes.pos,
  },
]

export const bottomLevelNavItems: readonly NavigationItem[] = [
  {
    id: 'contacts',
    label: 'Contacts',
    description: 'Customers, vendors, and suppliers',
    icon: UsersRound,
    to: appRoutes.contacts,
  },
]

export const navGroups: readonly NavGroup[] = [
  {
    id: 'sales',
    label: 'Sales',
    description: 'Orders, invoices, dispatch & receipts',
    icon: Store,
    items: [
      {
        id: 'sales.orders',
        label: 'Sales Orders',
        description: 'Customer commitments and fulfilment',
        icon: ClipboardList,
        to: appRoutes.salesOrders,
      },
      {
        id: 'sales.challans',
        label: 'Delivery Challans',
        description: 'Dispatches and shipment progress',
        icon: Truck,
        to: appRoutes.deliveryChallans,
      },
      {
        id: 'sales.invoices',
        label: 'Invoices',
        description: 'Receivables and billing progress',
        icon: ReceiptText,
        to: appRoutes.invoices,
      },
      {
        id: 'sales.estimates',
        label: 'Estimates & Quotes',
        description: 'Commercial proposals & conversion',
        icon: FileSpreadsheet,
        to: appRoutes.estimates,
      },
      {
        id: 'sales.payments',
        label: 'Customer Receipts',
        description: 'Customer collections and receipts',
        icon: Landmark,
        to: appRoutes.payments,
      },
      {
        id: 'sales.credit_notes',
        label: 'Credit Notes',
        description: 'Sales returns & credit adjustments',
        icon: FileBadge,
        to: appRoutes.creditNotes,
      },
      {
        id: 'sales.recurring_invoices',
        label: 'Recurring Invoices',
        description: 'Subscription & scheduled billing',
        icon: RefreshCw,
        to: appRoutes.recurringInvoices,
      },
      {
        id: 'sales.receipts',
        label: 'Sales Receipts',
        description: 'POS receipts & counter sales',
        icon: ReceiptText,
        to: appRoutes.salesReceipts,
      },
      {
        id: 'crm.loyalty',
        label: 'Loyalty & Rewards',
        description: 'Customer wallets & points ledger',
        icon: Award,
        to: appRoutes.loyalty,
      },
      {
        id: 'pos.cash_registers',
        label: 'Cash Registers',
        description: 'Drawer float, petty cash & shift close',
        icon: DollarSign,
        to: appRoutes.posCashRegisters,
      },
      {
        id: 'pos.offline_sync',
        label: 'POS Offline Sync',
        description: 'Offline queue & local bill buffer',
        icon: RefreshCw,
        to: appRoutes.posOfflineSync,
      },
      {
        id: 'pos.receipt_settings',
        label: 'Receipt Settings',
        description: 'Thermal branding & paper layout',
        icon: Printer,
        to: appRoutes.posReceiptSettings,
      },
    ],
  },
  {
    id: 'purchases',
    label: 'Purchases',
    description: 'Procurement, bills & supplier settlements',
    icon: ShoppingBag,
    items: [
      {
        id: 'purchases.orders',
        label: 'Purchase Orders',
        description: 'Supplier commitments & tracking',
        icon: ShoppingBag,
        to: appRoutes.purchaseOrders,
      },
      {
        id: 'purchases.receipts',
        label: 'Goods Receipts (GRN)',
        description: 'Inbound shipments & landed costs',
        icon: PackageCheck,
        to: appRoutes.stockReceipts,
      },
      {
        id: 'purchases.bills',
        label: 'Vendor Bills',
        description: 'Vendor bills and payables',
        icon: FileSpreadsheet,
        to: appRoutes.bills,
      },
      {
        id: 'purchases.three_way_match',
        label: '3-Way Match Inbox',
        description: 'PO vs GRN vs Bill variance audit',
        icon: Layers,
        to: appRoutes.threeWayMatch,
      },
      {
        id: 'purchases.vendor_credits',
        label: 'Vendor Credits',
        description: 'Unapplied supplier credits',
        icon: FileBadge,
        to: appRoutes.vendorCredits,
      },
      {
        id: 'purchases.payments',
        label: 'Vendor Payments',
        description: 'Disbursements and AP settlements',
        icon: ArrowUpRight,
        to: appRoutes.vendorPayments,
      },
      {
        id: 'purchases.debit_notes',
        label: 'Debit Notes',
        description: 'Purchase returns & chargebacks',
        icon: FileMinus,
        to: appRoutes.debitNotes,
      },
      {
        id: 'purchases.recurring_bills',
        label: 'Recurring Bills',
        description: 'Automated periodic supplier bills',
        icon: RefreshCw,
        to: appRoutes.recurringBills,
      },
    ],
  },
  {
    id: 'inventory',
    label: 'Inventory',
    description: 'Stock, warehouses, transfers & batch trace',
    icon: Boxes,
    items: [
      {
        id: 'inventory.items',
        label: 'Items & Catalog',
        description: 'Item master and on-hand stock',
        icon: Boxes,
        to: appRoutes.items,
      },
      {
        id: 'inventory.stock_summary',
        label: 'Stock Summary & Valuation',
        description: 'Live balances, FIFO lots & reorder alerts',
        icon: Layers,
        to: appRoutes.stockSummary,
      },
      {
        id: 'inventory.picklists',
        label: 'Picklists',
        description: 'Warehouse picking progress',
        icon: ListChecks,
        to: appRoutes.picklists,
      },
      {
        id: 'inventory.transfers',
        label: 'Transfer Orders',
        description: 'Inter-warehouse stock movements',
        icon: ArrowLeftRight,
        to: appRoutes.transferOrders,
      },
      {
        id: 'inventory.counts',
        label: 'Stock Counts',
        description: 'Physical counts & cycle audits',
        icon: ClipboardCheck,
        to: appRoutes.stockCounts,
      },
      {
        id: 'inventory.warehouses',
        label: 'Warehouses',
        description: 'Facilities & branch locations',
        icon: Building2,
        to: appRoutes.warehouses,
      },
      {
        id: 'inventory.price_lists',
        label: 'Price Lists',
        description: 'Tier pricing & volume rates',
        icon: Tag,
        to: appRoutes.priceLists,
      },
      {
        id: 'inventory.uoms',
        label: 'Units of Measure',
        description: 'Measurement units and baselines',
        icon: Scale,
        to: appRoutes.uoms,
      },
      {
        id: 'inventory.batch_trace',
        label: 'Batch Traceability',
        description: 'Genealogy & recall console',
        icon: ShieldAlert,
        to: appRoutes.batchTrace,
      },
      {
        id: 'inventory.batches',
        label: 'Batch & Expiry Watch',
        description: 'Near-expiry surveillance & FEFO rotation',
        icon: Clock,
        to: appRoutes.batches,
      },
      {
        id: 'inventory.shortbook',
        label: 'Shortbook Console',
        description: 'Low stock & auto PO generation',
        icon: Bookmark,
        to: appRoutes.shortbook,
      },
      {
        id: 'inventory.consignments',
        label: 'Consignments & VMI',
        description: 'Vendor managed inventory',
        icon: Briefcase,
        to: appRoutes.consignments,
      },
      {
        id: 'inventory.barcode_labels',
        label: 'Barcode Label Hub',
        description: 'Thermal & sheet label designer',
        icon: Tag,
        to: appRoutes.barcodeLabels,
      },
      {
        id: 'pharmacy.masters',
        label: 'Pharmacy Masters',
        description: 'Drug catalog, HSN & rack layout',
        icon: Pill,
        to: appRoutes.pharmacyMasters,
      },
      {
        id: 'pharmacy.near_expiry',
        label: 'Near Expiry Alerts',
        description: 'Batch shelf life & FEFO tracking',
        icon: AlertOctagon,
        to: appRoutes.nearExpiry,
      },
    ],
  },
  {
    id: 'manufacturing',
    label: 'Manufacturing',
    description: 'Work orders, BOM, routing, QC & MRP',
    icon: Factory,
    items: [
      {
        id: 'manufacturing.work_orders',
        label: 'Work Orders',
        description: 'Production floor build orders',
        icon: Factory,
        to: appRoutes.workOrders,
      },
      {
        id: 'manufacturing.bom',
        label: 'BOM & Recipes',
        description: 'Engineering bills of material & diffs',
        icon: Layers,
        to: appRoutes.bomManager,
      },
      {
        id: 'manufacturing.routings',
        label: 'Routings & Operations',
        description: 'Floor routing steps & operations library',
        icon: ListChecks,
        to: appRoutes.routings,
      },
      {
        id: 'manufacturing.mrp',
        label: 'MRP Simulation',
        description: 'Material requirements planning engine',
        icon: Cpu,
        to: appRoutes.mrp,
      },
      {
        id: 'manufacturing.job_work',
        label: 'Job Work (Challan 45)',
        description: 'Subcontracting dispatches & ITC-04',
        icon: Briefcase,
        to: appRoutes.jobWork,
      },
      {
        id: 'manufacturing.qc',
        label: 'QC Inspections',
        description: 'Quality checks & parameter audits',
        icon: ShieldCheck,
        to: appRoutes.qcInspections,
      },
      {
        id: 'manufacturing.qc_templates',
        label: 'QC Templates',
        description: 'Configurable inspection test parameters',
        icon: ClipboardCheck,
        to: appRoutes.qcTemplates,
      },
      {
        id: 'manufacturing.ncr',
        label: 'Non-Conformance (NCR)',
        description: 'Defect remediation & root causes',
        icon: ShieldAlert,
        to: appRoutes.ncrs,
      },
      {
        id: 'manufacturing.capa',
        label: 'CAPA Management',
        description: 'Corrective & preventive actions hub',
        icon: AlertOctagon,
        to: appRoutes.capa,
      },
      {
        id: 'manufacturing.work_centers',
        label: 'Work Centers',
        description: 'Plant machinery & capacity',
        icon: Cpu,
        to: appRoutes.workCenters,
      },
      {
        id: 'manufacturing.maintenance_schedules',
        label: 'Maintenance Schedules',
        description: 'Preventive PM routines & calendar',
        icon: CalendarClock,
        to: appRoutes.maintenanceSchedules,
      },
      {
        id: 'manufacturing.maintenance_orders',
        label: 'Maintenance Orders',
        description: 'Breakdowns & service dispatches',
        icon: Wrench,
        to: appRoutes.maintenanceWorkOrders,
      },
      {
        id: 'manufacturing.reports',
        label: 'Manufacturing Analytics',
        description: 'WIP valuation, bottleneck & scrap',
        icon: BarChart3,
        to: appRoutes.manufacturingReports,
      },
    ],
  },
  {
    id: 'field_sales',
    label: 'Field Sales',
    description: 'Beats, routes, vans, DCR & field team execution',
    icon: Navigation,
    items: [
      {
        id: 'field_sales.dashboard',
        label: 'Dashboard',
        description: 'Territory KPIs & route execution progress',
        icon: BarChart3,
        to: appRoutes.fieldSalesDashboard,
      },
      {
        id: 'field_sales.live_tracking',
        label: 'Live Tracking',
        description: 'Real-time field rep GPS telemetry',
        icon: MapPin,
        to: appRoutes.fieldSalesLiveTracking,
      },
      {
        id: 'field_sales.merchandising',
        label: 'Shelf Merchandising',
        description: 'Store shelf audits & planogram compliance',
        icon: ShoppingBag,
        to: appRoutes.fieldSalesMerchandising,
      },
      {
        id: 'field_sales.tour_plans',
        label: 'Tour Plans (MTP)',
        description: 'Monthly travel itineraries & route plans',
        icon: Compass,
        to: appRoutes.fieldSalesTourPlans,
      },
      {
        id: 'field_sales.dcr',
        label: 'Daily Call Report (DCR)',
        description: 'Doctor & chemist call logs with order booking',
        icon: FileSpreadsheet,
        to: appRoutes.fieldSalesDcr,
      },
      {
        id: 'field_sales.mr_approvals',
        label: 'Field Approvals',
        description: 'Manager sign-offs for MTP & DCR',
        icon: ClipboardCheck,
        to: appRoutes.fieldSalesMrApprovals,
        labelResolver: (ind) => (isPharmaIndustry(ind) ? 'MR Approvals' : 'Field Approvals'),
      },
      {
        id: 'field_sales.samples',
        label: 'Samples & TA/DA',
        description: 'Physician samples & travel claims',
        icon: Gift,
        to: appRoutes.fieldSalesSamples,
      },
      {
        id: 'field_sales.coverage',
        label: 'Coverage',
        description: 'Call frequency compliance & strike rates',
        icon: TrendingUp,
        to: appRoutes.fieldSalesCoverage,
      },
      {
        id: 'field_sales.targets',
        label: 'Targets',
        description: 'Sales quotas & periodic achievements',
        icon: Target,
        to: appRoutes.fieldSalesTargets,
      },
      {
        id: 'field_sales.attendance',
        label: 'Attendance',
        description: 'Field check-in, check-out & leave approvals',
        icon: Clock,
        to: appRoutes.fieldSalesAttendance,
      },
      {
        id: 'field_sales.detail_aids',
        label: 'Detail Aids',
        description: 'Digital visual aids & product brochures',
        icon: BookOpen,
        to: appRoutes.fieldSalesDetailAids,
      },
      {
        id: 'field_sales.secondary_sales',
        label: 'Secondary Sales',
        description: 'Stockist-to-retailer sales statements',
        icon: Layers,
        to: appRoutes.fieldSalesSecondarySales,
      },
      {
        id: 'field_sales.rcpa',
        label: 'RCPA',
        description: 'Retail chemist prescription audit & brand share',
        icon: Stethoscope,
        to: appRoutes.fieldSalesRcpa,
      },
      {
        id: 'field_sales.org_chart',
        label: 'Org Chart',
        description: 'Sales hierarchy & manager reporting lines',
        icon: UsersRound,
        to: appRoutes.fieldSalesOrgChart,
      },
      {
        id: 'field_sales.beats',
        label: 'Beats',
        description: 'Territory stops & customer sequences',
        icon: MapPin,
        to: appRoutes.fieldSalesBeats,
      },
      {
        id: 'field_sales.routes',
        label: 'Routes',
        description: 'Scheduled multi-beat route lines',
        icon: Navigation,
        to: appRoutes.fieldSalesRoutes,
      },
      {
        id: 'field_sales.assignments',
        label: 'Team Assignments',
        description: 'Territory & vehicle allocations',
        icon: ListChecks,
        to: appRoutes.fieldSalesAssignments,
        roles: ['OWNER', 'ADMIN'],
      },
      {
        id: 'field_sales.vans',
        label: 'Vans',
        description: 'Van fleet & mobile stock balances',
        icon: Truck,
        to: appRoutes.fieldSalesVans,
      },
      {
        id: 'field_sales.executions',
        label: "Today's Routes",
        description: 'Daily visit execution & live stops',
        icon: Navigation,
        to: appRoutes.fieldSalesExecutions,
      },
      {
        id: 'field_sales.day_close',
        label: 'Day Close',
        description: 'Daily cash reconciliation & supervisor settlement',
        icon: Banknote,
        to: appRoutes.fieldSalesDayClose,
      },
    ],
  },
  {
    id: 'accounting',
    label: 'Accounting & GL',
    description: 'General ledger, assets, amortization & franchise',
    icon: BookOpen,
    items: [
      {
        id: 'accounting.dashboard',
        label: 'Accounting Dashboard',
        description: 'Ledger health, cash flow & finance work queues',
        icon: BarChart3,
        to: appRoutes.accountingDashboard,
      },
      {
        id: 'accounting.accounts',
        label: 'Chart of Accounts',
        description: 'General ledger & account hierarchy',
        icon: BookOpen,
        to: appRoutes.accounts,
      },
      {
        id: 'accounting.journals',
        label: 'Journal Entries',
        description: 'General ledger postings & adjustments',
        icon: FileText,
        to: appRoutes.journals,
      },
      {
        id: 'accounting.budgets',
        label: 'Budgets & Variance',
        description: 'Operating limits vs GL actuals',
        icon: BarChart3,
        to: appRoutes.budgets,
      },
      {
        id: 'accounting.fiscal_periods',
        label: 'Fiscal Periods & Close',
        description: 'Period boundaries & continuous close',
        icon: ShieldCheck,
        to: appRoutes.fiscalPeriods,
      },
      {
        id: 'accounting.fixed_assets',
        label: 'Fixed Assets',
        description: 'Capitalized assets & depreciation',
        icon: Building,
        to: appRoutes.fixedAssets,
      },
      {
        id: 'accounting.amortization',
        label: 'Amortization & Prepaids',
        description: 'Straight-line periodic recognition',
        icon: CalendarClock,
        to: appRoutes.amortization,
      },
      {
        id: 'accounting.recurring_journals',
        label: 'Recurring Journals',
        description: 'Scheduled periodic adjustments & accruals',
        icon: RefreshCw,
        to: appRoutes.recurringJournals,
      },
      {
        id: 'franchise.stores',
        label: 'Franchise Network',
        description: 'FOFO/COCO branches, catalog & royalties',
        icon: Store,
        to: appRoutes.franchise,
      },
    ],
  },
  {
    id: 'banking',
    label: 'Banking & Feeds',
    description: 'Bank statements & reconciliation',
    icon: Landmark,
    items: [
      {
        id: 'banking.accounts',
        label: 'Bank Accounts & Feeds',
        description: 'Bank statements & AI reconciliation',
        icon: Landmark,
        to: appRoutes.banking,
      },
    ],
  },
  {
    id: 'tax_compliance',
    label: 'Tax & Compliance',
    description: 'GST, TDS, TCS, tax accounts & eTIMS',
    icon: ShieldCheck,
    items: [
      {
        id: 'compliance.gst',
        label: 'GST Compliance Suite',
        description: 'GSTR-1, GSTR-3B, IMS & e-Way bills',
        icon: ShieldCheck,
        to: appRoutes.gst,
        countries: ['IN'],
      },
      {
        id: 'compliance.tds',
        label: 'TDS Compliance (26Q/24Q)',
        description: 'Vendor & salary TDS registers & Form 16',
        icon: FileText,
        to: appRoutes.tds,
        countries: ['IN'],
      },
      {
        id: 'compliance.tcs',
        label: 'TCS Section 206C(1H)',
        description: '₹50L turnover tracker & Form 27EQ',
        icon: Layers,
        to: appRoutes.tcs,
        countries: ['IN'],
      },
      {
        id: 'settings.tax_accounts',
        label: 'Tax Account Mappings',
        description: 'GST/VAT input/output GL account bindings',
        icon: Building2,
        to: appRoutes.taxAccountMappings,
      },
      {
        id: 'compliance.tax_groups',
        label: 'Tax Groups',
        description: 'GST and tax rate group definitions',
        icon: Layers,
        to: appRoutes.taxGroups,
      },
      {
        id: 'compliance.kenya',
        label: 'Kenya eTIMS & M-Pesa',
        description: 'KRA electronic tax invoices & Daraja',
        icon: Globe,
        to: appRoutes.kenyaCompliance,
        countries: ['KE'],
      },
    ],
  },
  {
    id: 'hr_payroll',
    label: 'HR & Payroll',
    description: 'Employees, payroll runs, attendance & leave',
    icon: Users,
    items: [
      {
        id: 'payroll.employees',
        label: 'Employees Master',
        description: 'Staff directory & salary structures',
        icon: Users,
        to: appRoutes.employees,
      },
      {
        id: 'payroll.runs',
        label: 'Payroll Runs',
        description: 'Monthly salary cycles & payslips',
        icon: Banknote,
        to: appRoutes.payrollRuns,
      },
      {
        id: 'hr.attendance',
        label: 'Attendance & Clock',
        description: 'Punches, overtime & regularization',
        icon: CalendarClock,
        to: appRoutes.attendance,
      },
      {
        id: 'hr.leaves',
        label: 'Leaves & Holidays',
        description: 'Leave balances, applications & quotas',
        icon: CalendarClock,
        to: appRoutes.leaves,
      },
      {
        id: 'hr.shifts',
        label: 'Shifts & Rosters',
        description: 'Work schedules & night shift planning',
        icon: Clock,
        to: appRoutes.shifts,
      },
      {
        id: 'hr.timesheets',
        label: 'Timesheets',
        description: 'Project hours & billable logs',
        icon: FileSpreadsheet,
        to: appRoutes.timesheets,
      },
      {
        id: 'hr.tickets',
        label: 'HR Helpdesk',
        description: 'Employee queries & grievance tickets',
        icon: LifeBuoy,
        to: appRoutes.hrTickets,
      },
      {
        id: 'hr.offboarding',
        label: 'Offboarding & FnF',
        description: 'Exit clearance, settlements & gratuity',
        icon: UserMinus,
        to: appRoutes.offboarding,
      },
      {
        id: 'hr.biometrics',
        label: 'Biometric Terminals',
        description: 'ZKTeco TCP & ADMS live push telemetry',
        icon: Cpu,
        to: appRoutes.biometricDevices,
      },
      {
        id: 'payroll.settings',
        label: 'Payroll Settings',
        description: 'Pay rules, GL accounts & statutory toggles',
        icon: Settings,
        to: appRoutes.payrollSettings,
      },
    ],
  },
  {
    id: 'transport',
    label: 'Courier & Transport',
    description: 'Shipments, COD, lorry receipts & rate cards',
    icon: Truck,
    items: [
      {
        id: 'transport.courier_shipments',
        label: 'Courier Shipments',
        description: 'Parcel dispatches & live tracking',
        icon: Truck,
        to: appRoutes.courierShipments,
      },
      {
        id: 'transport.cod_remittances',
        label: 'COD Remittances',
        description: 'Cash-on-delivery reconciliation',
        icon: Banknote,
        to: appRoutes.codRemittances,
      },
      {
        id: 'transport.lorry_receipts',
        label: 'Lorry Receipts (LR)',
        description: 'Consignment notes & freight billing',
        icon: FileSpreadsheet,
        to: appRoutes.lorryReceipts,
      },
      {
        id: 'transport.rate_cards',
        label: 'Freight Rate Cards',
        description: 'Lane rate matrix & quote calculator',
        icon: Tag,
        to: appRoutes.freightRateCards,
      },
      {
        id: 'transport.vehicle_logs',
        label: 'Vehicle Logs & TCO',
        description: 'Fleet expenses & cost-per-km analytics',
        icon: Compass,
        to: appRoutes.vehicleLogs,
      },
      {
        id: 'transport.courier_settings',
        label: 'Courier Gateways',
        description: 'BlueDart, Delhivery, DTDC & Shiprocket credentials',
        icon: Settings,
        to: appRoutes.courierSettings,
      },
    ],
  },
  {
    id: 'reports',
    label: 'Reports & Analytics',
    description: 'Financial statements, variance & saved queries',
    icon: BarChart3,
    items: [
      {
        id: 'reporting.hub',
        label: 'Reports Hub',
        description: 'Financial statements & tax ledgers',
        icon: BarChart3,
        to: appRoutes.reports,
      },
      {
        id: 'reporting.saved',
        label: 'Saved Reports',
        description: 'Customized queries & schedules',
        icon: Bookmark,
        to: appRoutes.savedReports,
      },
      {
        id: 'reporting.cash_runway',
        label: '13-Week Cash Runway',
        description: 'Rolling liquidity forecast & stress testing',
        icon: TrendingUp,
        to: appRoutes.cashRunway,
      },
      {
        id: 'reporting.flux_commentary',
        label: 'Flux Commentary',
        description: 'MoM/YoY balance sheet variance analytics',
        icon: BarChart3,
        to: appRoutes.fluxCommentary,
      },
    ],
  },
  {
    id: 'ca_practice',
    label: 'CA Practice Console',
    description: 'Multi-client audit, compliance & dispatch',
    icon: Briefcase,
    items: [
      {
        id: 'ca.dashboard',
        label: 'CA Practice Console',
        description: 'Multi-client audit & delegated access',
        icon: Briefcase,
        to: appRoutes.caDashboard,
      },
      {
        id: 'ca.compliance',
        label: 'CA Compliance Calendar',
        description: 'Cross-client statutory return tracking',
        icon: CalendarClock,
        to: appRoutes.caCompliance,
      },
      {
        id: 'ca.alerts',
        label: 'CA Audit Risk Alerts',
        description: 'Cross-client AI anomaly & risk inbox',
        icon: ShieldAlert,
        to: appRoutes.caAlerts,
      },
      {
        id: 'ca.dispatch',
        label: 'Batch Report Dispatch',
        description: 'Mass client financial statements dispatch',
        icon: FileText,
        to: appRoutes.caDispatch,
      },
    ],
  },
  {
    id: 'settings_group',
    label: 'Settings',
    description: 'User access, templates & system config',
    icon: Settings,
    items: [
      {
        id: 'settings.users',
        label: 'Team & User Roles',
        description: 'Invite members & manage permissions',
        icon: Users,
        to: appRoutes.users,
      },
      {
        id: 'settings.payment_terms',
        label: 'Payment Terms',
        description: 'Instalment schedules and collection terms',
        icon: CalendarClock,
        to: appRoutes.paymentTerms,
        roles: ['OWNER', 'ADMIN', 'ACCOUNTANT'],
      },
      {
        id: 'settings.pdf_templates',
        label: 'PDF Document Designer',
        description: 'Brand colors, logos, QR codes & terms',
        icon: Palette,
        to: appRoutes.pdfTemplates,
      },
      {
        id: 'settings.ai',
        label: 'AI Model Configuration',
        description: 'Cloud LLMs & local Ollama configuration',
        icon: Cpu,
        to: appRoutes.aiSettings,
      },
    ],
  },
]

// Flat list of all items for search palette and backward compatibility
const navigationItems: readonly NavigationItem[] = [
  ...topLevelNavItems,
  ...bottomLevelNavItems,
  ...navGroups.flatMap((group) => group.items),
]

function isItemAllowed(item: NavigationItem, context: NavigationContext, disabledIds: Set<string>, capabilities: Set<string>): boolean {
  if (context.role?.toUpperCase() === 'PLATFORM_ADMIN') return true
  if (disabledIds.has(item.id)) return false
  if (item.roles && (!context.role || !item.roles.includes(context.role))) return false
  if (item.industries && (!context.industry || !item.industries.includes(context.industry))) return false
  if (item.countries && (!context.country || !item.countries.includes(context.country))) return false
  if (item.capability && !capabilities.has(item.capability)) return false
  return true
}

function resolveNavigationItem(item: NavigationItem, context: NavigationContext): NavigationItem {
  if (item.labelResolver) {
    return {
      ...item,
      label: item.labelResolver(context.industry),
    }
  }
  return item
}

export function getVisibleNavigation(context: NavigationContext): NavigationItem[] {
  const disabledIds = new Set(context.disabledIds ?? [])
  const capabilities = new Set(context.capabilities ?? [])

  return navigationItems
    .filter((item) => isItemAllowed(item, context, disabledIds, capabilities))
    .map((item) => resolveNavigationItem(item, context))
}

export type VisibleNavStructure = {
  topItems: readonly NavigationItem[]
  groups: readonly NavGroup[]
  bottomItems: readonly NavigationItem[]
}

export function getVisibleNavStructure(context: NavigationContext): VisibleNavStructure {
  const disabledIds = new Set(context.disabledIds ?? [])
  const capabilities = new Set(context.capabilities ?? [])
  const isPlatformAdmin = context.role?.toUpperCase() === 'PLATFORM_ADMIN'
  const isCaUser = context.role === 'CA_PARTNER' || context.role === 'CA_STAFF'

  const resolveItem = (item: NavigationItem): NavigationItem => resolveNavigationItem(item, context)

  const topItems = topLevelNavItems
    .filter((item) => isItemAllowed(item, context, disabledIds, capabilities))
    .map(resolveItem)
  const bottomItems = bottomLevelNavItems
    .filter((item) => isItemAllowed(item, context, disabledIds, capabilities))
    .map(resolveItem)

  const groups = navGroups
    .map((group) => {
      if (!isPlatformAdmin) {
        if (disabledIds.has(group.id)) return null
        if (group.roles && (!context.role || !group.roles.includes(context.role))) return null
        if (group.industries && (!context.industry || !group.industries.includes(context.industry))) return null
        if (group.countries && (!context.country || !group.countries.includes(context.country))) return null
        if (group.capability && !capabilities.has(group.capability)) return null
      }

      // Filter children
      const visibleItems = group.items
        .filter((item) => isItemAllowed(item, context, disabledIds, capabilities))
        .map(resolveItem)
      if (visibleItems.length === 0) return null

      // CA user prioritization
      if (!isPlatformAdmin && isCaUser && group.id !== 'ca_practice' && group.id !== 'settings_group') {
        return null
      }

      return {
        ...group,
        items: visibleItems as readonly NavigationItem[],
      }
    })
    .filter((group): group is NavGroup => group !== null)

  return {
    topItems,
    groups,
    bottomItems,
  }
}
