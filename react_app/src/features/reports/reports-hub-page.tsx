import { useMemo, useState } from 'react'
import {
  ArrowRight,
  BarChart3,
  Bookmark,
  Boxes,
  CreditCard,
  FileText,
  ShieldCheck,
  ShoppingBag,
} from 'lucide-react'
import { Link } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DirectoryToolbar,
  DocumentCard,
  EmptyState,
  FilterTabs,
  PageHeader,
  SearchInput,
  StatusChip,
} from '@/design-system'
import { reportCatalog, type ReportCatalogItem } from '@/features/reports/reports-api'

const categoryTabs = [
  { key: 'ALL', label: 'All reports' },
  { key: 'FINANCIAL', label: 'Financial' },
  { key: 'SALES_AR', label: 'Sales & AR' },
  { key: 'PURCHASES_AP', label: 'Purchases & AP' },
  { key: 'INVENTORY', label: 'Inventory' },
  { key: 'TAX_COMPLIANCE', label: 'Tax & GST' },
] as const

type CategoryTab = (typeof categoryTabs)[number]['key']
type ReportCategory = Exclude<CategoryTab, 'ALL'>

const categoryDescriptions: Record<ReportCategory, string> = {
  FINANCIAL: 'Core statements, ledgers, and financial control.',
  SALES_AR: 'Sales, customer collections, and receivables visibility.',
  PURCHASES_AP: 'Purchase costs, vendor liabilities, and payment control.',
  INVENTORY: 'Stock movement, FIFO valuation, and aging analysis.',
  TAX_COMPLIANCE: 'GST reporting and statutory compliance readiness.',
}

export function ReportsHubPage() {
  const [activeCategory, setActiveCategory] = useState<CategoryTab>('ALL')
  const [searchTerm, setSearchTerm] = useState('')

  const filteredReports = useMemo(() => {
    return reportCatalog.filter((item) => {
      if (activeCategory !== 'ALL' && item.category !== activeCategory) return false
      if (!searchTerm) return true
      const term = searchTerm.toLowerCase().trim()
      return item.title.toLowerCase().includes(term) || item.description.toLowerCase().includes(term)
    })
  }, [activeCategory, searchTerm])

  const categoryCounts = useMemo(() => {
    return reportCatalog.reduce<Record<ReportCategory, number>>(
      (counts, report) => {
        counts[report.category] += 1
        return counts
      },
      { FINANCIAL: 0, SALES_AR: 0, PURCHASES_AP: 0, INVENTORY: 0, TAX_COMPLIANCE: 0 }
    )
  }, [])

  const categoryCoverage = useMemo(() => {
    return (Object.keys(categoryCounts) as ReportCategory[]).map((category) => ({
      category,
      count: categoryCounts[category],
      description: categoryDescriptions[category],
      label: categoryTabs.find((tab) => tab.key === category)?.label ?? category,
    }))
  }, [categoryCounts])

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Intelligence & Accounting"
        title="Reports Hub"
        description="Statutory financial statements, operational ledgers, tax registers, and inventory valuation analytics."
        actions={
          <Link className="button button--secondary" to={appRoutes.savedReports}>
            <Bookmark aria-hidden="true" size={15} />
            Saved Reports & Schedules
          </Link>
        }
      />

      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">Standard Reports</span>
          <strong className="summary-card__value">{reportCatalog.length}</strong>
          <span className="summary-card__hint">Financial & operational templates</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Statutory & GST</span>
          <strong className="summary-card__value">
            {reportCatalog.filter((r) => r.category === 'FINANCIAL' || r.category === 'TAX_COMPLIANCE').length}
          </strong>
          <span className="summary-card__hint">P&L, Balance Sheet, Trial Balance, GST</span>
        </div>
        <div className="summary-card summary-card--accent">
          <span className="summary-card__label">Inventory & Costing</span>
          <strong className="summary-card__value">
            {reportCatalog.filter((r) => r.category === 'INVENTORY').length}
          </strong>
          <span className="summary-card__hint">FIFO valuation, stock ageing & movement</span>
        </div>
      </div>

      <DocumentCard className="report-showcase">
        <div className="report-showcase__intro">
          <p className="report-showcase__eyebrow">Decision-ready reporting</p>
          <h2>
            <strong>{reportCatalog.length}</strong> reports for every financial control point.
          </h2>
          <p>
            Give clients one connected reporting library for financial statements, collections, vendor liabilities, inventory value, and statutory compliance.
          </p>
        </div>
        <dl className="report-showcase__stats">
          <div>
            <dt>Reporting disciplines</dt>
            <dd>{categoryCoverage.length}</dd>
          </div>
          <div>
            <dt>Financial statements</dt>
            <dd>{categoryCounts.FINANCIAL}</dd>
          </div>
          <div>
            <dt>Operational registers</dt>
            <dd>{reportCatalog.length - categoryCounts.FINANCIAL}</dd>
          </div>
        </dl>
      </DocumentCard>

      <section aria-label="Report coverage by discipline" className="report-coverage-grid">
        {categoryCoverage.map((coverage) => {
          const Icon = getCategoryIcon(coverage.category)
          const isActive = activeCategory === coverage.category
          return (
            <Button
              aria-pressed={isActive}
              className={isActive ? 'report-coverage-card report-coverage-card--active' : 'report-coverage-card'}
              key={coverage.category}
              onClick={() => {
                setActiveCategory(coverage.category)
                setSearchTerm('')
              }}
              variant="ghost"
            >
              <span aria-hidden="true" className="report-coverage-card__icon">{Icon}</span>
              <span className="report-coverage-card__body">
                <strong>{coverage.label}</strong>
                <small>{coverage.description}</small>
              </span>
              <span className="report-coverage-card__count">{coverage.count}</span>
            </Button>
          )
        })}
      </section>

      <DirectoryToolbar ariaLabel="Report catalogue filters">
        <FilterTabs
          activeValue={activeCategory}
          ariaLabel="Filter reports by category"
          items={categoryTabs.map((tab) => ({
            count: tab.key === 'ALL' ? reportCatalog.length : categoryCounts[tab.key],
            label: tab.label,
            value: tab.key,
          }))}
          onChange={setActiveCategory}
        />
        <SearchInput
          ariaLabel="Search report catalogue"
          onChange={setSearchTerm}
          onClear={() => setSearchTerm('')}
          placeholder="Search report titles..."
          value={searchTerm}
        />
      </DirectoryToolbar>

      {filteredReports.length === 0 ? (
        <EmptyState
          icon={FileText}
          title="No reports match these filters"
          description="Clear the search or choose another report category."
        />
      ) : (
        <>
          <div className="report-catalog-heading">
            <div>
              <p>Report library</p>
              <h2>{filteredReports.length} of {reportCatalog.length} reports</h2>
            </div>
            <span>Open a report to review its current server-calculated data.</span>
          </div>
          <section aria-label="Available reports" className="report-catalog-grid">
            {filteredReports.map((report) => (
              <ReportCard item={report} key={report.key} />
            ))}
          </section>
        </>
      )}
    </section>
  )
}

function ReportCard({ item }: { item: ReportCatalogItem }) {
  const icon = getCategoryIcon(item.category)

  return (
    <DocumentCard className="report-catalog-card">
      <div className="report-catalog-card__content">
        <div className="report-catalog-card__meta">
          <span aria-hidden="true" className="report-catalog-card__icon">{icon}</span>
          <StatusChip status={item.category}>{formatCategoryLabel(item.category)}</StatusChip>
        </div>
        <h2>
          <Link className="table-row-link" to={appRoutes.reportViewer(item.key)}>
            {item.title}
          </Link>
        </h2>
        <p>{item.description}</p>
      </div>
      <Link className="report-catalog-card__action" to={appRoutes.reportViewer(item.key)}>
        Run report <ArrowRight aria-hidden="true" size={14} />
      </Link>
    </DocumentCard>
  )
}

function getCategoryIcon(cat: ReportCatalogItem['category']) {
  switch (cat) {
    case 'FINANCIAL':
      return <BarChart3 aria-hidden="true" size={18} />
    case 'SALES_AR':
      return <CreditCard aria-hidden="true" size={18} />
    case 'PURCHASES_AP':
      return <ShoppingBag aria-hidden="true" size={18} />
    case 'INVENTORY':
      return <Boxes aria-hidden="true" size={18} />
    case 'TAX_COMPLIANCE':
      return <ShieldCheck aria-hidden="true" size={18} />
    default:
      return <FileText aria-hidden="true" size={18} />
  }
}

function formatCategoryLabel(cat: ReportCatalogItem['category']) {
  switch (cat) {
    case 'FINANCIAL':
      return 'Financial Statement'
    case 'SALES_AR':
      return 'Sales & AR'
    case 'PURCHASES_AP':
      return 'Purchases & AP'
    case 'INVENTORY':
      return 'Inventory'
    case 'TAX_COMPLIANCE':
      return 'GST & Compliance'
    default:
      return 'Report'
  }
}
