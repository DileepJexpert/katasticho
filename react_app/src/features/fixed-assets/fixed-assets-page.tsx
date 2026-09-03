import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  Building,
  Plus,
  Search,
} from 'lucide-react'
import { Link } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import {
  createFixedAsset,
  listFixedAssets,
  type CreateFixedAssetRequest,
} from '@/features/fixed-assets/fixed-assets-api'

const statusTabs = [
  { key: 'all', label: 'All assets' },
  { key: 'ACTIVE', label: 'Active' },
  { key: 'DISPOSED', label: 'Disposed' },
  { key: 'WRITTEN_OFF', label: 'Written off' },
] as const

type StatusTab = (typeof statusTabs)[number]['key']

export function FixedAssetsPage() {
  const queryClient = useQueryClient()
  const [activeTab, setActiveTab] = useState<StatusTab>('all')
  const [search, setSearch] = useState('')
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false)

  // Form State
  const [assetCode, setAssetCode] = useState('')
  const [name, setName] = useState('')
  const [category, setCategory] = useState('Plant & Machinery')
  const [cost, setCost] = useState('')
  const [salvageValue, setSalvageValue] = useState('0')
  const [usefulLifeMonths, setUsefulLifeMonths] = useState('60')
  const [bookMethod, setBookMethod] = useState<'SLM' | 'WDV'>('SLM')
  const [purchaseDate, setPurchaseDate] = useState(new Date().toISOString().split('T')[0] || '')

  // Queries
  const assetsQuery = useQuery({
    queryKey: ['fixed-assets'],
    queryFn: listFixedAssets,
  })

  // Mutations
  const createMutation = useMutation({
    mutationFn: (req: CreateFixedAssetRequest) => createFixedAsset(req),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['fixed-assets'] })
      setIsCreateModalOpen(false)
      setAssetCode('')
      setName('')
      setCost('')
      setSalvageValue('0')
    },
  })

  const rawList = assetsQuery.data ?? []

  const filtered = useMemo(() => {
    return rawList.filter((asset) => {
      if (activeTab !== 'all' && asset.status !== activeTab) return false
      if (!search.trim()) return true
      const q = search.toLowerCase()
      const matchCode = asset.assetCode.toLowerCase().includes(q)
      const matchName = asset.name.toLowerCase().includes(q)
      const matchCategory = asset.category ? asset.category.toLowerCase().includes(q) : false
      const matchMethod = asset.bookMethod.toLowerCase().includes(q)
      return matchCode || matchName || matchCategory || matchMethod
    })
  }, [rawList, activeTab, search])

  const totalCost = useMemo(
    () => rawList.reduce((sum, a) => sum + Number(a.cost || 0), 0),
    [rawList]
  )
  const totalDepreciation = useMemo(
    () => rawList.reduce((sum, a) => sum + Number(a.accumulatedDepreciation || 0), 0),
    [rawList]
  )
  const netBookValue = Math.max(0, totalCost - totalDepreciation)

  const handleCreateAsset = () => {
    if (!assetCode.trim() || !name.trim() || !cost || Number(cost) <= 0) return
    createMutation.mutate({
      assetCode: assetCode.trim(),
      name: name.trim(),
      category: category.trim(),
      cost: Number(cost),
      residualValue: Number(salvageValue) || 0,
      bookUsefulLifeMonths: Number(usefulLifeMonths) || 60,
      bookMethod,
      acquisitionDate: purchaseDate,
    })
  }

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Financial / Asset Management"
        title="Fixed Assets Register"
        description="Capitalized asset registry, straight-line & WDV Companies Act depreciation engine, and asset lifecycle disposals."
        actions={
          <Button onClick={() => setIsCreateModalOpen(true)} variant="primary">
            <Plus aria-hidden="true" size={14} style={{ marginRight: 6 }} />
            Add Fixed Asset
          </Button>
        }
      />

      {/* KPI Summary Strip */}
      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">Gross Asset Cost</span>
          <strong className="summary-card__value">
            <Money amount={totalCost} />
          </strong>
          <span className="summary-card__hint">{rawList.length} capitalized assets</span>
        </div>

        <div className="summary-card">
          <span className="summary-card__label">Accumulated Depreciation</span>
          <strong className="summary-card__value" style={{ color: 'var(--color-error)' }}>
            <Money amount={totalDepreciation} />
          </strong>
          <span className="summary-card__hint">Recognized to date</span>
        </div>

        <div className="summary-card summary-card--accent">
          <span className="summary-card__label">Net Book Value</span>
          <strong className="summary-card__value" style={{ color: 'var(--color-success)' }}>
            <Money amount={netBookValue} />
          </strong>
          <span className="summary-card__hint">Balance sheet carrying amount</span>
        </div>
      </div>

      {/* Toolbar */}
      <div className="list-toolbar" style={{ justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', gap: 'var(--space-sm)', alignItems: 'center' }}>
          <div className="search-field" style={{ width: 280 }}>
            <Search aria-hidden="true" size={16} />
            <input
              aria-label="Search fixed assets"
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search code, name, category..."
              type="text"
              value={search}
            />
          </div>

          <div className="filter-chips">
            {statusTabs.map((t) => (
              <button
                key={t.key}
                className={`filter-chip ${activeTab === t.key ? 'filter-chip--active' : ''}`}
                onClick={() => setActiveTab(t.key)}
                type="button"
              >
                {t.label}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Assets Table */}
      {filtered.length === 0 ? (
        <div className="directory-state" role="status">
          <Building aria-hidden="true" size={24} />
          <strong>No fixed assets found.</strong>
          <p>Register capitalized equipment, vehicles, or leasehold improvements to run automated depreciation.</p>
          <Button onClick={() => setIsCreateModalOpen(true)} variant="primary">
            Add Fixed Asset
          </Button>
        </div>
      ) : (
        <DataTable caption="Fixed Assets Register Table">
          <thead>
            <tr>
              <th scope="col">Asset Code</th>
              <th scope="col">Asset Name</th>
              <th scope="col">Category</th>
              <th scope="col">Depreciation Method</th>
              <th className="numeric-cell" scope="col">Gross Cost</th>
              <th className="numeric-cell" scope="col">Accumulated Dep.</th>
              <th className="numeric-cell" scope="col">Net Book Value</th>
              <th scope="col">Status</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((asset) => {
              const gross = Number(asset.cost || 0)
              const accDep = Number(asset.accumulatedDepreciation || 0)
              const nbv = Math.max(0, gross - accDep)
              return (
                <tr key={asset.id}>
                  <td>
                    <Link
                      className="table-code"
                      style={{ color: 'var(--color-primary)', fontWeight: 600 }}
                      to={appRoutes.fixedAssetDetail(asset.id)}
                    >
                      {asset.assetCode}
                    </Link>
                  </td>
                  <td>
                    <Link to={appRoutes.fixedAssetDetail(asset.id)}>
                      <strong>{asset.name}</strong>
                    </Link>
                  </td>
                  <td>
                    <span className="cell-muted">{asset.category || 'General'}</span>
                  </td>
                  <td>
                    <StatusChip status={asset.bookMethod} />
                  </td>
                  <td className="numeric-cell">
                    <strong>
                      <Money amount={gross} />
                    </strong>
                  </td>
                  <td className="numeric-cell" style={{ color: 'var(--color-error)' }}>
                    <Money amount={accDep} />
                  </td>
                  <td className="numeric-cell">
                    <strong style={{ color: 'var(--color-success)' }}>
                      <Money amount={nbv} />
                    </strong>
                  </td>
                  <td>
                    <StatusChip status={asset.status} />
                  </td>
                </tr>
              )
            })}
          </tbody>
        </DataTable>
      )}

      {/* MODAL: CREATE FIXED ASSET */}
      {isCreateModalOpen && (
        <div
          role="dialog"
          aria-modal="true"
          style={{
            position: 'fixed',
            inset: 0,
            backgroundColor: 'rgba(0,0,0,0.5)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
            padding: 'var(--space-md)',
          }}
        >
          <div
            className="panel-card"
            style={{
              width: '100%',
              maxWidth: 580,
              maxHeight: '90vh',
              overflowY: 'auto',
              backgroundColor: 'var(--color-surface)',
              borderRadius: 'var(--radius-lg)',
              padding: 'var(--space-lg)',
              border: '1px solid var(--color-border)',
            }}
          >
            <h3 style={{ fontSize: '1.2rem', fontWeight: 600, marginBottom: 'var(--space-xs)' }}>
              Capitalize New Fixed Asset
            </h3>
            <p className="cell-muted" style={{ fontSize: '0.85rem', marginBottom: 'var(--space-md)' }}>
              Enter asset acquisition details and depreciation parameters for automated monthly schedules.
            </p>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1.5fr', gap: 'var(--space-sm)', marginBottom: 'var(--space-sm)' }}>
              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                  Asset Tag / Code *
                </label>
                <input
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid var(--color-border)',
                    fontFamily: 'monospace',
                  }}
                  onChange={(e) => setAssetCode(e.target.value)}
                  placeholder="FA-2026-001"
                  type="text"
                  value={assetCode}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                  Asset Name *
                </label>
                <input
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid var(--color-border)',
                  }}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="e.g. Delivery Truck KA-01-AB-1234"
                  type="text"
                  value={name}
                />
              </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--space-sm)', marginBottom: 'var(--space-sm)' }}>
              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                  Category
                </label>
                <select
                  className="select-field"
                  onChange={(e) => setCategory(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid var(--color-border)',
                  }}
                  value={category}
                >
                  <option value="Plant & Machinery">Plant & Machinery</option>
                  <option value="Vehicles & Transport">Vehicles & Transport</option>
                  <option value="Computers & IT Hardware">Computers & IT Hardware</option>
                  <option value="Furniture & Fixtures">Furniture & Fixtures</option>
                  <option value="Buildings & Leasehold">Buildings & Leasehold</option>
                </select>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                  Purchase Date
                </label>
                <input
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid var(--color-border)',
                  }}
                  onChange={(e) => setPurchaseDate(e.target.value)}
                  type="date"
                  value={purchaseDate}
                />
              </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 'var(--space-sm)', marginBottom: 'var(--space-sm)' }}>
              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                  Gross Cost (â‚¹) *
                </label>
                <input
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid var(--color-border)',
                  }}
                  onChange={(e) => setCost(e.target.value)}
                  placeholder="0.00"
                  type="number"
                  value={cost}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                  Salvage Value (â‚¹)
                </label>
                <input
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid var(--color-border)',
                  }}
                  onChange={(e) => setSalvageValue(e.target.value)}
                  placeholder="0.00"
                  type="number"
                  value={salvageValue}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                  Useful Life (Mo.)
                </label>
                <input
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid var(--color-border)',
                  }}
                  onChange={(e) => setUsefulLifeMonths(e.target.value)}
                  placeholder="60"
                  type="number"
                  value={usefulLifeMonths}
                />
              </div>
            </div>

            <div style={{ marginBottom: 'var(--space-sm)' }}>
              <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                Depreciation Calculation Method
              </label>
              <select
                className="select-field"
                onChange={(e) => setBookMethod(e.target.value as 'SLM' | 'WDV')}
                style={{
                  width: '100%',
                  padding: '8px 12px',
                  borderRadius: 'var(--radius-md)',
                  border: '1px solid var(--color-border)',
                }}
                value={bookMethod}
              >
                <option value="SLM">Straight Line Method (SLM)</option>
                <option value="WDV">Written Down Value (WDV / Reducing Balance)</option>
              </select>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8, marginTop: 'var(--space-md)' }}>
              <Button onClick={() => setIsCreateModalOpen(false)} variant="secondary">
                Cancel
              </Button>
              <Button
                disabled={!assetCode.trim() || !name.trim() || !cost || createMutation.isPending}
                onClick={handleCreateAsset}
                variant="primary"
              >
                {createMutation.isPending ? 'Capitalizing...' : 'Save & Capitalize'}
              </Button>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}