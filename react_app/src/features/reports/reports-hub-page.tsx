import { useMemo, useState } from 'react'
import {
  ArrowRight,
  BarChart3,
  Bookmark,
  Boxes,
  CreditCard,
  FileText,
  Search,
  ShieldCheck,
  ShoppingBag,
} from 'lucide-react'
import { Link } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
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

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Intelligence & Accounting"
        title="Reports Hub"
        description="Statutory financial statements, operational ledgers, tax registers, and inventory valuation analytics."
        actions={
          <div className="table-actions">
            <Link className="secondary-button" to={appRoutes.savedReports} style={{ display: 'inline-flex', alignItems: 'center', gap: 6, padding: '0.4rem 0.8rem', fontSize: '0.85rem' }}>
              <Bookmark aria-hidden="true" size={14} />
              Saved Reports & Schedules
            </Link>
            <StatusChip status="Read-only pilot" />
          </div>
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

      <div className="list-toolbar">
        <div aria-label="Filter reports by category" className="list-tabs" role="tablist">
          {categoryTabs.map((tab) => (
            <button
              aria-selected={activeCategory === tab.key}
              className={activeCategory === tab.key ? 'list-tab list-tab--active' : 'list-tab'}
              key={tab.key}
              onClick={() => setActiveCategory(tab.key)}
              role="tab"
              type="button"
            >
              {tab.label}
            </button>
          ))}
        </div>

        <div className="search-field" style={{ maxWidth: 300 }}>
          <Search aria-hidden="true" size={16} />
          <input
            aria-label="Search reports catalog"
            onChange={(e) => setSearchTerm(e.target.value)}
            placeholder="Search report titles..."
            type="search"
            value={searchTerm}
          />
        </div>
      </div>

      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))',
          gap: '1rem',
        }}
      >
        {filteredReports.map((report) => (
          <ReportCard item={report} key={report.key} />
        ))}
      </div>
    </section>
  )
}

function ReportCard({ item }: { item: ReportCatalogItem }) {
  const icon = getCategoryIcon(item.category)

  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'space-between',
        padding: '1.25rem',
        borderRadius: '8px',
        border: '1px solid var(--k-color-border-subtle)',
        backgroundColor: 'var(--k-color-surface-card)',
        gap: '1rem',
      }}
    >
      <div>
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            marginBottom: '0.5rem',
          }}
        >
          <span
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              justifyContent: 'center',
              width: 32,
              height: 32,
              borderRadius: '6px',
              backgroundColor: 'var(--k-color-surface-sunken)',
              color: 'var(--k-color-text-primary)',
            }}
          >
            {icon}
          </span>
          <span className="status-badge" style={{ fontSize: '0.7rem' }}>
            {formatCategoryLabel(item.category)}
          </span>
        </div>

        <h3 style={{ margin: '0 0 0.4rem 0', fontSize: '1rem', fontWeight: 600 }}>
          <Link
            className="table-row-link"
            style={{ color: 'inherit', textDecoration: 'none' }}
            to={appRoutes.reportViewer(item.key)}
          >
            {item.title}
          </Link>
        </h3>
        <p className="cell-muted" style={{ margin: 0, fontSize: '0.85rem', lineHeight: 1.4 }}>
          {item.description}
        </p>
      </div>

      <div style={{ display: 'flex', justifyContent: 'flex-end', paddingTop: '0.5rem', borderTop: '1px solid var(--k-color-border-subtle)' }}>
        <Link
          className="table-row-action"
          style={{ display: 'inline-flex', alignItems: 'center', gap: 4, fontWeight: 500 }}
          to={appRoutes.reportViewer(item.key)}
        >
          Run report <ArrowRight aria-hidden="true" size={14} />
        </Link>
      </div>
    </div>
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
