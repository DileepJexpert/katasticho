import { describe, expect, it } from 'vitest'
import { getVisibleNavigation, getVisibleNavStructure } from '@/app/navigation'

describe('navigation', () => {
  it('matches partner, planning and portal controller role boundaries', () => {
    const idsFor = (role: string) => getVisibleNavigation({ role, industry: null, country: null }).map((item) => item.id)
    expect(idsFor('OPERATOR')).toEqual(expect.arrayContaining(['partner_network.partners', 'supply_chain.dashboard', 'supply_chain.shipments']))
    expect(idsFor('OPERATOR')).not.toContain('supply_chain.requisitions')
    expect(idsFor('OPERATOR')).not.toContain('settings.portal_users')
    expect(idsFor('ACCOUNTANT')).toContain('supply_chain.requisitions')
    expect(idsFor('ACCOUNTANT')).not.toContain('partner_network.partners')
    expect(idsFor('VIEWER')).not.toContain('supply_chain.dashboard')
    const hidden = getVisibleNavStructure({ role: 'ADMIN', industry: null, country: null, disabledIds: ['supply_chain', 'settings.portal_users'] })
    expect(hidden.groups.some((group) => group.id === 'supply_chain')).toBe(false)
    expect(hidden.groups.flatMap((group) => group.items).some((item) => item.id === 'settings.portal_users')).toBe(false)
  })
  it('removes a disabled stable navigation id without removing other live routes', () => {
    const visible = getVisibleNavigation({
      role: 'ADMIN',
      industry: null,
      country: null,
      disabledIds: ['contacts'],
      capabilities: ['BATCH_EXPIRY'],
    })

    expect(visible.map((item) => item.id)).toEqual([
      'dashboard',
      'ai.command_center',
      'pos.checkout',
      'sales.orders',
      'sales.challans',
      'sales.invoices',
      'sales.estimates',
      'sales.payments',
      'sales.credit_notes',
      'sales.recurring_invoices',
      'sales.receipts',
      'crm.loyalty',
      'pos.cash_registers',
      'pos.offline_sync',
      'pos.receipt_settings',
      'purchases.orders',
      'purchases.receipts',
      'purchases.bills',
      'purchases.three_way_match',
      'purchases.vendor_credits',
      'purchases.payments',
      'purchases.debit_notes',
      'purchases.recurring_bills',
      'inventory.items',
      'inventory.stock_summary',
      'inventory.picklists',
      'inventory.transfers',
      'inventory.counts',
      'inventory.warehouses',
      'inventory.rack_locations',
      'inventory.putaway_tasks',
      'inventory.serial_numbers',
      'inventory.price_lists',
      'inventory.schemes',
      'inventory.uoms',
      'inventory.batch_trace',
      'inventory.batches',
      'inventory.shortbook',
      'inventory.consignments',
      'inventory.barcode_labels',
      'pharmacy.masters',
      'pharmacy.near_expiry',
      'manufacturing.work_orders',
      'manufacturing.bom',
      'manufacturing.routings',
      'manufacturing.mrp',
      'manufacturing.job_work',
      'manufacturing.qc',
      'manufacturing.qc_templates',
      'manufacturing.ncr',
      'manufacturing.capa',
      'manufacturing.work_centers',
      'manufacturing.maintenance_schedules',
      'manufacturing.maintenance_orders',
      'manufacturing.reports',
      'field_sales.dashboard',
      'field_sales.live_tracking',
      'field_sales.merchandising',
      'field_sales.tour_plans',
      'field_sales.dcr',
      'field_sales.mr_approvals',
      'field_sales.samples',
      'field_sales.coverage',
      'field_sales.targets',
      'field_sales.attendance',
      'field_sales.detail_aids',
      'field_sales.secondary_sales',
      'field_sales.rcpa',
      'field_sales.org_chart',
      'field_sales.beats',
      'field_sales.routes',
      'field_sales.assignments',
      'field_sales.vans',
      'field_sales.executions',
      'field_sales.day_close',
      'accounting.dashboard',
      'accounting.accounts',
      'accounting.journals',
      'accounting.budgets',
      'accounting.fiscal_periods',
      'accounting.fixed_assets',
      'accounting.amortization',
      'accounting.recurring_journals',
      'franchise.stores',
      'banking.accounts',
      'settings.tax_accounts',
      'compliance.tax_groups',
      'payroll.employees',
      'hr.leave',
      'hr.attendance',
      'hr.biometric',
      'hr.shifts',
      'hr.timesheets',
      'hr.helpdesk',
      'hr.documents',
      'hr.analytics',
      'hr.offboarding',
      'hr.my_profile',
      'hr.tax_declaration',
      'payroll.runs',
      'payroll.labor_pay_preview',
      'payroll.settings',
      'partner_network.partners',
      'partner_network.catalog',
      'partner_network.supplier_search',
      'partner_network.outgoing_orders',
      'partner_network.incoming_orders',
      'supply_chain.dashboard',
      'supply_chain.requisitions',
      'supply_chain.shipments',
      'supply_chain.returns',
      'supply_chain.alerts',
      'supply_chain.forecasts',
      'supply_chain.reorder_policies',
      'supply_chain.item_suppliers',
      'supply_chain.supplier_rankings',
      'supply_chain.turnover',
      'transport.courier_shipments',
      'transport.cod_remittances',
      'transport.lorry_receipts',
      'transport.rate_cards',
      'transport.vehicle_logs',
      'transport.courier_settings',
      'reporting.hub',
      'reporting.saved',
      'reporting.cash_runway',
      'reporting.flux_commentary',
      'ca.dashboard',
      'ca.compliance',
      'ca.alerts',
      'ca.dispatch',
      'settings.portal_users',
      'settings.users',
      'settings.payment_terms',
      'settings.pdf_templates',
      'settings.ai',
    ])
  })

  it('provides structured nav groups with country gating', () => {
    const structureIndia = getVisibleNavStructure({
      role: 'ADMIN',
      industry: null,
      country: 'IN',
    })

    const taxGroupIndia = structureIndia.groups.find((g) => g.id === 'tax_compliance')
    expect(taxGroupIndia).toBeDefined()
    expect(taxGroupIndia?.items.map((i) => i.id)).toContain('compliance.gst')
    expect(taxGroupIndia?.items.map((i) => i.id)).not.toContain('compliance.kenya')

    const structureKenya = getVisibleNavStructure({
      role: 'ADMIN',
      industry: null,
      country: 'KE',
    })

    const taxGroupKenya = structureKenya.groups.find((g) => g.id === 'tax_compliance')
    expect(taxGroupKenya).toBeDefined()
    expect(taxGroupKenya?.items.map((i) => i.id)).toContain('compliance.kenya')
    expect(taxGroupKenya?.items.map((i) => i.id)).not.toContain('compliance.gst')
  })

  it('allows PLATFORM_ADMIN to bypass disabledIds and role restrictions', () => {
    const adminVisible = getVisibleNavigation({
      role: 'PLATFORM_ADMIN',
      industry: null,
      country: null,
      disabledIds: ['contacts', 'dashboard'],
    })

    expect(adminVisible.some((i) => i.id === 'contacts')).toBe(true)
    expect(adminVisible.some((i) => i.id === 'dashboard')).toBe(true)
  })

  it('restricts role-specific groups and items', () => {
    const caStructure = getVisibleNavStructure({
      role: 'CA_PARTNER',
      industry: null,
      country: null,
    })

    // CA partner should only see CA practice and settings groups
    const groupIds = caStructure.groups.map((g) => g.id)
    expect(groupIds).toContain('ca_practice')
    expect(groupIds).not.toContain('manufacturing_operations')
  })

  it('resolves field_sales.mr_approvals label dynamically based on industry', () => {
    const pharmaNav = getVisibleNavigation({
      role: 'ADMIN',
      industry: 'PHARMACY',
      country: null,
    })
    const pharmaApprovalItem = pharmaNav.find((i) => i.id === 'field_sales.mr_approvals')
    expect(pharmaApprovalItem?.label).toBe('MR Approvals')

    const generalNav = getVisibleNavigation({
      role: 'ADMIN',
      industry: 'FMCG',
      country: null,
    })
    const generalApprovalItem = generalNav.find((i) => i.id === 'field_sales.mr_approvals')
    expect(generalApprovalItem?.label).toBe('Field Approvals')
  })

  it('enforces role restrictions on field_sales.assignments', () => {
    const operatorNav = getVisibleNavigation({
      role: 'OPERATOR',
      industry: null,
      country: null,
    })
    expect(operatorNav.some((i) => i.id === 'field_sales.assignments')).toBe(false)

    const adminNav = getVisibleNavigation({
      role: 'ADMIN',
      industry: null,
      country: null,
    })
    expect(adminNav.some((i) => i.id === 'field_sales.assignments')).toBe(true)

    const ownerNav = getVisibleNavigation({
      role: 'OWNER',
      industry: null,
      country: null,
    })
    expect(ownerNav.some((i) => i.id === 'field_sales.assignments')).toBe(true)
  })

  it('shows batch expiry tools only to roles and organisations supported by the API', () => {
    const enabledOperator = getVisibleNavigation({
      role: 'OPERATOR',
      industry: null,
      country: null,
      capabilities: ['BATCH_EXPIRY'],
    })
    expect(enabledOperator.some((i) => i.id === 'inventory.batches')).toBe(true)
    expect(enabledOperator.some((i) => i.id === 'inventory.batch_trace')).toBe(true)

    const enabledViewer = getVisibleNavigation({
      role: 'VIEWER',
      industry: null,
      country: null,
      capabilities: ['BATCH_EXPIRY'],
    })
    expect(enabledViewer.some((i) => i.id === 'inventory.batches')).toBe(false)
    expect(enabledViewer.some((i) => i.id === 'inventory.batch_trace')).toBe(false)

    const disabledAdmin = getVisibleNavigation({
      role: 'ADMIN',
      industry: null,
      country: null,
      capabilities: [],
    })
    expect(disabledAdmin.some((i) => i.id === 'inventory.batches')).toBe(false)
    expect(disabledAdmin.some((i) => i.id === 'inventory.batch_trace')).toBe(false)
  })

  it('enforces role and country gating on HR & Payroll items', () => {
    // OPERATOR cannot see payroll runs, labor pay preview, or settings
    const operatorNav = getVisibleNavigation({
      role: 'OPERATOR',
      industry: null,
      country: null,
    })
    expect(operatorNav.some((i) => i.id === 'payroll.runs')).toBe(false)
    expect(operatorNav.some((i) => i.id === 'payroll.labor_pay_preview')).toBe(false)
    expect(operatorNav.some((i) => i.id === 'payroll.settings')).toBe(false)
    expect(operatorNav.some((i) => i.id === 'payroll.employees')).toBe(true)
    expect(operatorNav.some((i) => i.id === 'hr.my_profile')).toBe(true)
    expect(operatorNav.some((i) => i.id === 'hr.tax_declaration')).toBe(true)

    // Kenya PAYE calculator only visible in Kenya for accountant/admin/owner
    const indiaAdminNav = getVisibleNavigation({
      role: 'ADMIN',
      industry: null,
      country: 'IN',
    })
    expect(indiaAdminNav.some((i) => i.id === 'payroll.kenya_paye')).toBe(false)

    const kenyaAdminNav = getVisibleNavigation({
      role: 'ADMIN',
      industry: null,
      country: 'KE',
    })
    expect(kenyaAdminNav.some((i) => i.id === 'payroll.kenya_paye')).toBe(true)
  })
})
