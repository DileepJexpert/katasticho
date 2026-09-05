import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  Building,
  Plus,
  Search,
} from 'lucide-react'
import { Link } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Modal, FormGrid, FormField, SelectInput } from '@/design-system'
import { useSessionStore } from '@/shared/session/session-store'
import { TextField } from '@/design-system/text-field'
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
  const user = useSessionStore((s) => s.user)
  return <FixedAssetsPageWorkspace key={`${user?.orgId}:${user?.id}:${user?.role}`} />
}

function FixedAssetsPageWorkspace() {
  const queryClient = useQueryClient()
  const user = useSessionStore((s) => s.user)
  const canWrite = ['OWNER', 'ADMIN', 'ACCOUNTANT'].includes(user?.role ?? '')
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
  const [bookRate, setBookRate] = useState('')
  const [bookMethod, setBookMethod] = useState<'SLM' | 'WDV'>('SLM')
  const [purchaseDate, setPurchaseDate] = useState(new Date().toISOString().split('T')[0] || '')

  // Queries
  const assetsQuery = useQuery({
    queryKey: ['fixed-assets', user?.orgId],
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

  const valid = canWrite && assetCode.trim() && name.trim()
    && /^\d{4}-\d{2}-\d{2}$/.test(purchaseDate)
    && Number.isFinite(Number(cost)) && Number(cost) > 0
    && Number.isFinite(Number(salvageValue)) && Number(salvageValue) >= 0 && Number(salvageValue) <= Number(cost)
    && (bookMethod === 'SLM' ? Number.isInteger(Number(usefulLifeMonths)) && Number(usefulLifeMonths) > 0
      : Number.isFinite(Number(bookRate)) && Number(bookRate) > 0 && Number(bookRate) <= 100)
  const handleCreateAsset = () => {
    if (!valid) return
    createMutation.mutate({
      assetCode: assetCode.trim(), name: name.trim(), category: category.trim(),
      cost: Number(cost), residualValue: Number(salvageValue), bookMethod,
      bookUsefulLifeMonths: bookMethod === 'SLM' ? Number(usefulLifeMonths) : undefined,
      bookRatePct: bookMethod === 'WDV' ? Number(bookRate) : undefined,
      acquisitionDate: purchaseDate,
    })
  }

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Financial / Asset Management"
        title="Fixed Assets Register"
        description="Capitalized asset registry, straight-line & WDV Companies Act depreciation engine, and asset lifecycle disposals."
        actions={canWrite &&
          <Button onClick={() => setIsCreateModalOpen(true)} variant="primary">
            <Plus aria-hidden="true" size={14} style={{ marginRight: 6 }} />
            Add Fixed Asset
          </Button>
        }
      />

      {assetsQuery.isError && <p role="alert">{assetsQuery.error.message}</p>}
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
      {assetsQuery.isPending ? <p role="status">Loading assets...</p> : assetsQuery.isError ? null : filtered.length === 0 ? (
        <div className="directory-state" role="status">
          <Building aria-hidden="true" size={24} />
          <strong>No fixed assets found.</strong>
          <p>Register capitalized equipment, vehicles, or leasehold improvements to run automated depreciation.</p>
          {canWrite && <Button onClick={() => setIsCreateModalOpen(true)} variant="primary">Add Fixed Asset</Button>}
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

      <Modal isOpen={isCreateModalOpen && canWrite} title="Register New Fixed Asset" size="md"
        error={createMutation.isError ? createMutation.error.message : undefined}
        onClose={() => { if (!createMutation.isPending) setIsCreateModalOpen(false) }}
        footer={<><Button disabled={createMutation.isPending} onClick={() => setIsCreateModalOpen(false)}>Cancel</Button><Button variant="primary" disabled={!valid || createMutation.isPending} onClick={handleCreateAsset}>{createMutation.isPending ? 'Saving...' : 'Save asset'}</Button></>}>
        <p className="cell-muted">Registration does not post the acquisition journal. Record acquisition accounting separately; depreciation is posted by the organisation monthly run.</p>
        <FormGrid>
          <TextField label="Asset Tag / Code" required value={assetCode} placeholder="FA-2026-001" onChange={(e) => setAssetCode(e.target.value)} />
          <TextField label="Asset Name" required value={name} placeholder="e.g. Delivery Truck KA-01-AB-1234" onChange={(e) => setName(e.target.value)} />
          <TextField label="Category" value={category} onChange={(e) => setCategory(e.target.value)} />
          <TextField label="Purchase Date" required type="date" value={purchaseDate} onChange={(e) => setPurchaseDate(e.target.value)} />
          <TextField id="fa-cost" label="Gross Cost (₹)" required type="number" min="0.01" step="0.01" value={cost} placeholder="0.00" onChange={(e) => setCost(e.target.value)} />
          <TextField id="fa-salvage" label="Salvage Value (₹)" type="number" min="0" max={cost || undefined} step="0.01" value={salvageValue} placeholder="0.00" onChange={(e) => setSalvageValue(e.target.value)} />
          <FormField label="Depreciation Calculation Method"><SelectInput value={bookMethod} onChange={(e) => setBookMethod(e.target.value as 'SLM' | 'WDV')}><option value="SLM">Straight Line Method (SLM)</option><option value="WDV">Written Down Value (WDV / Reducing Balance)</option></SelectInput></FormField>
          {bookMethod === 'SLM' ? <TextField label="Useful Life (Mo.)" required type="number" min="1" step="1" placeholder="60" value={usefulLifeMonths} onChange={(e) => setUsefulLifeMonths(e.target.value)} /> : <TextField label="Annual WDV rate (%)" required type="number" min="0.01" max="100" step="0.01" value={bookRate} onChange={(e) => setBookRate(e.target.value)} />}
        </FormGrid>
      </Modal>
    </section>
  )
}
