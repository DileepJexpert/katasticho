import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  Building2,
  CheckCircle2,
  ExternalLink,
  FileText,
  FlaskConical,
  Grid,
  History,
  Percent,
  Pill,
  Plus,
  Search,
  Sparkles,
  X,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import {
  createRackLocation,
  getHsnRateHistory,
  getSubstitutions,
  listRackLocations,
  searchDrugs,
  searchHsn,
  searchManufacturers,
  seedDemoRackLocations,
  type DrugMaster,
  type RackLocationRequest,
} from '@/features/pharmacy/pharmacy-api'
import { listWarehouses } from '@/features/warehouses/warehouses-api'

type TabKey = 'drugs' | 'hsn' | 'manufacturers' | 'racks'

export function PharmacyMastersPage() {
  const queryClient = useQueryClient()
  const [activeTab, setActiveTab] = useState<TabKey>('drugs')

  // Drug Master state
  const [drugSearch, setDrugSearch] = useState('')
  const [selectedDrug, setSelectedDrug] = useState<DrugMaster | null>(null)

  // HSN state
  const [hsnSearch, setHsnSearch] = useState('')
  const [selectedHsnCode, setSelectedHsnCode] = useState<string | null>(null)

  // Manufacturer state
  const [mfgSearch, setMfgSearch] = useState('')

  // Rack Locations state
  const [selectedWarehouseId, setSelectedWarehouseId] = useState<string>('')
  const [isAddRackOpen, setIsAddRackOpen] = useState(false)
  const [newRackCode, setNewRackCode] = useState('')
  const [newRackName, setNewRackName] = useState('')
  const [newRackZone, setNewRackZone] = useState('')
  const [newRackAisle, setNewRackAisle] = useState('')
  const [newRackShelf, setNewRackShelf] = useState('')
  const [newRackBin, setNewRackBin] = useState('')

  // Queries
  const drugsQuery = useQuery({
    queryKey: ['pharmacy-drugs', drugSearch],
    queryFn: () => searchDrugs(drugSearch, 60),
  })

  const hsnQuery = useQuery({
    queryKey: ['pharmacy-hsn', hsnSearch],
    queryFn: () => searchHsn(hsnSearch, 60),
  })

  const mfgQuery = useQuery({
    queryKey: ['pharmacy-manufacturers', mfgSearch],
    queryFn: () => searchManufacturers(mfgSearch, 60),
  })

  const warehousesQuery = useQuery({
    queryKey: ['warehouses-list'],
    queryFn: () => listWarehouses(),
  })

  const racksQuery = useQuery({
    queryKey: ['pharmacy-racks', selectedWarehouseId],
    queryFn: () => listRackLocations(selectedWarehouseId || undefined),
  })

  const substitutionsQuery = useQuery({
    queryKey: ['pharmacy-substitutions', selectedDrug?.id],
    queryFn: () => (selectedDrug ? getSubstitutions(selectedDrug.id) : Promise.resolve([])),
    enabled: Boolean(selectedDrug),
  })

  const rateHistoryQuery = useQuery({
    queryKey: ['pharmacy-hsn-history', selectedHsnCode],
    queryFn: () => (selectedHsnCode ? getHsnRateHistory(selectedHsnCode) : Promise.resolve([])),
    enabled: Boolean(selectedHsnCode),
  })

  // Mutations
  const createRackMutation = useMutation({
    mutationFn: (req: RackLocationRequest) => createRackLocation(req),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pharmacy-racks'] })
      setIsAddRackOpen(false)
      setNewRackCode('')
      setNewRackName('')
      setNewRackZone('')
      setNewRackAisle('')
      setNewRackShelf('')
      setNewRackBin('')
    },
  })

  const seedDemoMutation = useMutation({
    mutationFn: () => seedDemoRackLocations(),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pharmacy-racks'] })
    },
  })

  const drugs = drugsQuery.data ?? []
  const hsnList = hsnQuery.data ?? []
  const manufacturers = mfgQuery.data ?? []
  const warehouses = warehousesQuery.data ?? []
  const rackLocations = racksQuery.data ?? []
  const substitutions = substitutionsQuery.data ?? []
  const rateHistory = rateHistoryQuery.data ?? []

  const rxCount = useMemo(() => drugs.filter((d) => d.prescriptionRequired).length, [drugs])
  const avgMrp = useMemo(() => {
    const priced = drugs.filter((d) => d.mrp && d.mrp > 0)
    if (priced.length === 0) return 0
    return priced.reduce((sum, d) => sum + (d.mrp || 0), 0) / priced.length
  }, [drugs])

  const handleCreateRack = (e: React.FormEvent) => {
    e.preventDefault()
    const whId = selectedWarehouseId || (warehouses[0]?.id ?? '')
    if (!whId || !newRackCode.trim()) return
    createRackMutation.mutate({
      warehouseId: whId,
      code: newRackCode.trim().toUpperCase(),
      name: newRackName.trim() || undefined,
      zone: newRackZone.trim() || undefined,
      aisle: newRackAisle.trim() || undefined,
      shelf: newRackShelf.trim() || undefined,
      bin: newRackBin.trim() || undefined,
    })
  }

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Pharmacy / Masters"
        title="Pharmacy Masters & Statutory Directory"
        description="Drug master catalog, HSN GST statutory classifications, pharma manufacturers, and warehouse rack layout."
        actions={<StatusChip status="Pharmacy Suite" />}
      />

      <div className="filter-chip-group" style={{ marginBottom: 'var(--space-md)' }}>
        <button
          className={`filter-chip ${activeTab === 'drugs' ? 'filter-chip--active' : ''}`}
          onClick={() => setActiveTab('drugs')}
          type="button"
        >
          <Pill aria-hidden="true" size={14} style={{ marginRight: 6 }} />
          Drug Master ({drugs.length})
        </button>
        <button
          className={`filter-chip ${activeTab === 'hsn' ? 'filter-chip--active' : ''}`}
          onClick={() => setActiveTab('hsn')}
          type="button"
        >
          <Percent aria-hidden="true" size={14} style={{ marginRight: 6 }} />
          HSN & GST Directory ({hsnList.length})
        </button>
        <button
          className={`filter-chip ${activeTab === 'manufacturers' ? 'filter-chip--active' : ''}`}
          onClick={() => setActiveTab('manufacturers')}
          type="button"
        >
          <Building2 aria-hidden="true" size={14} style={{ marginRight: 6 }} />
          Manufacturers ({manufacturers.length})
        </button>
        <button
          className={`filter-chip ${activeTab === 'racks' ? 'filter-chip--active' : ''}`}
          onClick={() => setActiveTab('racks')}
          type="button"
        >
          <Grid aria-hidden="true" size={14} style={{ marginRight: 6 }} />
          Rack Locations ({rackLocations.length})
        </button>
      </div>

      {activeTab === 'drugs' && (
        <>
          <div className="summary-strip">
            <div className="summary-card">
              <span className="summary-card__label">Total Drugs in Catalog</span>
              <strong className="summary-card__value">
                <Quantity value={drugs.length} />
              </strong>
              <span className="summary-card__hint">Standardized brand formulations</span>
            </div>
            <div className="summary-card">
              <span className="summary-card__label">Prescription (Rx) Items</span>
              <strong className="summary-card__value">
                <Quantity value={rxCount} />
              </strong>
              <span className="summary-card__hint">Schedule H / H1 / X regulated</span>
            </div>
            <div className="summary-card summary-card--accent">
              <span className="summary-card__label">Average Catalog MRP</span>
              <strong className="summary-card__value">
                <Money amount={avgMrp} />
              </strong>
              <span className="summary-card__hint">Pack retail benchmark</span>
            </div>
          </div>

          <div className="list-toolbar">
            <div className="search-field" style={{ maxWidth: 380 }}>
              <Search aria-hidden="true" size={16} />
              <input
                aria-label="Search drug catalog by brand, generic, salt, or manufacturer"
                onChange={(e) => setDrugSearch(e.target.value)}
                placeholder="Search brand, generic, salt, manufacturer..."
                type="search"
                value={drugSearch}
              />
            </div>
          </div>

          {drugsQuery.isLoading ? (
            <div aria-live="polite" className="directory-state">
              Loading drug master catalog...
            </div>
          ) : drugsQuery.isError ? (
            <div className="directory-state directory-state--error" role="alert">
              <FileText aria-hidden="true" size={24} />
              <strong>Unable to load drug master catalog.</strong>
              <p>Please check connection or retry.</p>
              <Button onClick={() => drugsQuery.refetch()} variant="secondary">
                Retry
              </Button>
            </div>
          ) : drugs.length === 0 ? (
            <div className="directory-state">
              <FlaskConical aria-hidden="true" size={24} />
              <strong>No drugs found.</strong>
              <p>{drugSearch ? 'Try a different brand or salt keyword.' : 'No items in drug catalog.'}</p>
            </div>
          ) : (
            <DataTable caption="Standardized drug formulations and brand catalog">
              <thead>
                <tr>
                  <th scope="col">Brand Name</th>
                  <th scope="col">Generic & Salt Composition</th>
                  <th scope="col">Manufacturer & HSN</th>
                  <th scope="col">Dosage & Pack</th>
                  <th scope="col">Schedule / Rx</th>
                  <th className="numeric-cell" scope="col">MRP</th>
                  <th className="numeric-cell" scope="col">Action</th>
                </tr>
              </thead>
              <tbody>
                {drugs.map((drug) => (
                  <tr key={drug.id}>
                    <td>
                      <div className="cell-stack">
                        <strong>{drug.brandName}</strong>
                        {drug.genericName ? (
                          <span className="cell-muted">{drug.genericName}</span>
                        ) : null}
                      </div>
                    </td>
                    <td>
                      <div className="cell-stack">
                        <span>{drug.saltComposition || 'â€”'}</span>
                      </div>
                    </td>
                    <td>
                      <div className="cell-stack">
                        <span>{drug.manufacturer || 'â€”'}</span>
                        {drug.hsnCode ? (
                          <span className="table-code" style={{ fontSize: '0.8rem' }}>
                            HSN {drug.hsnCode} {drug.gstRate ? `(${drug.gstRate}%)` : ''}
                          </span>
                        ) : null}
                      </div>
                    </td>
                    <td>
                      <div className="cell-stack">
                        <span>{drug.dosageForm || 'â€”'}</span>
                        {drug.packSize ? (
                          <span className="cell-muted">{drug.packSize}</span>
                        ) : null}
                      </div>
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap' }}>
                        {drug.drugSchedule ? (
                          <StatusChip status={drug.drugSchedule} />
                        ) : null}
                        <StatusChip
                          status={drug.prescriptionRequired ? 'Rx Required' : 'OTC'}
                        />
                      </div>
                    </td>
                    <td className="numeric-cell">
                      {drug.mrp ? <Money amount={drug.mrp} /> : <span className="cell-muted">â€”</span>}
                    </td>
                    <td className="numeric-cell">
                      <button
                        className="table-row-action"
                        onClick={() => setSelectedDrug(drug)}
                        type="button"
                      >
                        Substitutions
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          )}
        </>
      )}

      {activeTab === 'hsn' && (
        <>
          <div className="list-toolbar">
            <div className="search-field" style={{ maxWidth: 360 }}>
              <Search aria-hidden="true" size={16} />
              <input
                aria-label="Search HSN code or description"
                onChange={(e) => setHsnSearch(e.target.value)}
                placeholder="Search HSN code or description..."
                type="search"
                value={hsnSearch}
              />
            </div>
          </div>

          {hsnQuery.isLoading ? (
            <div aria-live="polite" className="directory-state">
              Loading HSN directory...
            </div>
          ) : hsnQuery.isError ? (
            <div className="directory-state directory-state--error" role="alert">
              <FileText aria-hidden="true" size={24} />
              <strong>Unable to load HSN directory.</strong>
              <Button onClick={() => hsnQuery.refetch()} variant="secondary">
                Retry
              </Button>
            </div>
          ) : hsnList.length === 0 ? (
            <div className="directory-state">
              <Percent aria-hidden="true" size={24} />
              <strong>No HSN codes found.</strong>
            </div>
          ) : (
            <DataTable caption="Statutory HSN classification and GST tax rates">
              <thead>
                <tr>
                  <th scope="col">HSN Code</th>
                  <th scope="col">Description</th>
                  <th scope="col">Category</th>
                  <th scope="col">GST Rate</th>
                  <th className="numeric-cell" scope="col">History</th>
                </tr>
              </thead>
              <tbody>
                {hsnList.map((hsn) => (
                  <tr key={hsn.id}>
                    <td>
                      <span className="table-code">{hsn.hsnCode}</span>
                    </td>
                    <td>
                      <strong>{hsn.description || 'â€”'}</strong>
                    </td>
                    <td>
                      <span className="cell-muted">{hsn.category || 'Pharma / Healthcare'}</span>
                    </td>
                    <td>
                      <StatusChip
                        status={hsn.gstRate != null ? `${hsn.gstRate}% GST` : 'Exempt'}
                      />
                    </td>
                    <td className="numeric-cell">
                      <button
                        className="table-row-action"
                        onClick={() => setSelectedHsnCode(hsn.hsnCode)}
                        type="button"
                      >
                        Rate History
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          )}
        </>
      )}

      {activeTab === 'manufacturers' && (
        <>
          <div className="list-toolbar">
            <div className="search-field" style={{ maxWidth: 360 }}>
              <Search aria-hidden="true" size={16} />
              <input
                aria-label="Search manufacturers"
                onChange={(e) => setMfgSearch(e.target.value)}
                placeholder="Search manufacturer name..."
                type="search"
                value={mfgSearch}
              />
            </div>
          </div>

          {mfgQuery.isLoading ? (
            <div aria-live="polite" className="directory-state">
              Loading manufacturers...
            </div>
          ) : mfgQuery.isError ? (
            <div className="directory-state directory-state--error" role="alert">
              <FileText aria-hidden="true" size={24} />
              <strong>Unable to load manufacturers.</strong>
              <Button onClick={() => mfgQuery.refetch()} variant="secondary">
                Retry
              </Button>
            </div>
          ) : manufacturers.length === 0 ? (
            <div className="directory-state">
              <Building2 aria-hidden="true" size={24} />
              <strong>No manufacturers found.</strong>
            </div>
          ) : (
            <DataTable caption="Pharmaceutical manufacturers directory">
              <thead>
                <tr>
                  <th scope="col">Manufacturer Name</th>
                  <th scope="col">Country</th>
                  <th scope="col">Website</th>
                </tr>
              </thead>
              <tbody>
                {manufacturers.map((mfg) => (
                  <tr key={mfg.id}>
                    <td>
                      <strong>{mfg.name}</strong>
                    </td>
                    <td>
                      <span className="cell-muted">{mfg.country || 'India'}</span>
                    </td>
                    <td>
                      {mfg.website ? (
                        <a
                          className="table-row-link"
                          href={mfg.website.startsWith('http') ? mfg.website : `https://${mfg.website}`}
                          rel="noreferrer"
                          target="_blank"
                        >
                          {mfg.website}{' '}
                          <ExternalLink aria-hidden="true" size={12} style={{ display: 'inline', marginLeft: 2 }} />
                        </a>
                      ) : (
                        <span className="cell-muted">â€”</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          )}
        </>
      )}

      {activeTab === 'racks' && (
        <>
          <div className="list-toolbar" style={{ justifyContent: 'space-between' }}>
            <div style={{ display: 'flex', gap: 'var(--space-sm)', alignItems: 'center' }}>
              <select
                aria-label="Filter racks by warehouse"
                className="select-field"
                onChange={(e) => setSelectedWarehouseId(e.target.value)}
                style={{
                  padding: '6px 12px',
                  borderRadius: 'var(--radius-md)',
                  border: '1px solid var(--color-border)',
                  background: 'var(--color-surface)',
                  color: 'var(--color-text-primary)',
                  fontSize: '0.9rem',
                }}
                value={selectedWarehouseId}
              >
                <option value="">All Warehouses</option>
                {warehouses.map((w) => (
                  <option key={w.id} value={w.id}>
                    {w.name} ({w.code})
                  </option>
                ))}
              </select>
            </div>
            <div style={{ display: 'flex', gap: 'var(--space-sm)' }}>
              <Button
                disabled={seedDemoMutation.isPending}
                onClick={() => seedDemoMutation.mutate()}
                variant="secondary"
              >
                <Sparkles aria-hidden="true" size={14} style={{ marginRight: 6 }} />
                {seedDemoMutation.isPending ? 'Loading...' : 'Seed Demo Layout'}
              </Button>
              <Button onClick={() => setIsAddRackOpen(true)} variant="primary">
                <Plus aria-hidden="true" size={14} style={{ marginRight: 6 }} />
                New Rack Location
              </Button>
            </div>
          </div>

          {racksQuery.isLoading ? (
            <div aria-live="polite" className="directory-state">
              Loading warehouse rack layout...
            </div>
          ) : racksQuery.isError ? (
            <div className="directory-state directory-state--error" role="alert">
              <FileText aria-hidden="true" size={24} />
              <strong>Unable to load rack locations.</strong>
              <Button onClick={() => racksQuery.refetch()} variant="secondary">
                Retry
              </Button>
            </div>
          ) : rackLocations.length === 0 ? (
            <div className="directory-state">
              <Grid aria-hidden="true" size={24} />
              <strong>No rack locations found.</strong>
              <p>Create a rack location or click "Seed Demo Layout" to populate standard warehouse bins.</p>
            </div>
          ) : (
            <DataTable caption="Warehouse bin coordinates and rack layout">
              <thead>
                <tr>
                  <th scope="col">Rack Code</th>
                  <th scope="col">Location Name</th>
                  <th scope="col">Zone</th>
                  <th scope="col">Aisle</th>
                  <th scope="col">Shelf</th>
                  <th scope="col">Bin</th>
                  <th scope="col">Status</th>
                </tr>
              </thead>
              <tbody>
                {rackLocations.map((rack) => (
                  <tr key={rack.id}>
                    <td>
                      <span className="table-code">{rack.code}</span>
                    </td>
                    <td>
                      <strong>{rack.name || rack.code}</strong>
                    </td>
                    <td>
                      <span className="cell-muted">{rack.zone || 'â€”'}</span>
                    </td>
                    <td>
                      <span className="cell-muted">{rack.aisle || 'â€”'}</span>
                    </td>
                    <td>
                      <span className="cell-muted">{rack.shelf || 'â€”'}</span>
                    </td>
                    <td>
                      <span className="cell-muted">{rack.bin || 'â€”'}</span>
                    </td>
                    <td>
                      <StatusChip status={rack.active ? 'Active' : 'Inactive'} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          )}
        </>
      )}

      {selectedDrug && (
        <div
          role="dialog"
          aria-modal="true"
          aria-labelledby="drug-dialog-title"
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
              maxWidth: 720,
              maxHeight: '85vh',
              overflowY: 'auto',
              backgroundColor: 'var(--color-surface)',
              borderRadius: 'var(--radius-lg)',
              padding: 'var(--space-lg)',
              border: '1px solid var(--color-border)',
            }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 'var(--space-md)' }}>
              <div>
                <span className="panel-card__eyebrow">Generic Substitution & Composition</span>
                <h3 id="drug-dialog-title" className="panel-card__title" style={{ fontSize: '1.25rem', marginTop: 4 }}>
                  {selectedDrug.brandName}
                </h3>
                <p className="cell-muted" style={{ margin: 0 }}>
                  {selectedDrug.genericName || selectedDrug.saltComposition}
                </p>
              </div>
              <button
                aria-label="Close dialog"
                className="icon-button"
                onClick={() => setSelectedDrug(null)}
                style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 4 }}
                type="button"
              >
                <X aria-hidden="true" size={20} />
              </button>
            </div>

            <div className="summary-strip" style={{ marginBottom: 'var(--space-md)' }}>
              <div className="summary-card">
                <span className="summary-card__label">Manufacturer</span>
                <strong>{selectedDrug.manufacturer || 'â€”'}</strong>
              </div>
              <div className="summary-card">
                <span className="summary-card__label">Dosage & Pack</span>
                <strong>{selectedDrug.dosageForm || 'â€”'} ({selectedDrug.packSize || '1s'})</strong>
              </div>
              <div className="summary-card">
                <span className="summary-card__label">Brand MRP</span>
                <strong>{selectedDrug.mrp ? <Money amount={selectedDrug.mrp} /> : 'â€”'}</strong>
              </div>
            </div>

            <h4 style={{ fontSize: '0.95rem', fontWeight: 600, marginBottom: 'var(--space-xs)' }}>
              Bioequivalent Generic Substitutions
            </h4>

            {substitutionsQuery.isLoading ? (
              <p className="cell-muted">Loading generic alternatives...</p>
            ) : substitutions.length === 0 ? (
              <div className="directory-state" style={{ padding: 'var(--space-md)' }}>
                <CheckCircle2 aria-hidden="true" size={20} color="var(--color-success)" />
                <strong>No lower-cost generic substitutions mapped.</strong>
                <p>This brand is currently the primary reference formulary item.</p>
              </div>
            ) : (
              <DataTable caption="Generic substitutions with MRP savings">
                <thead>
                  <tr>
                    <th scope="col">Substitute Brand</th>
                    <th scope="col">Manufacturer</th>
                    <th className="numeric-cell" scope="col">Substitute MRP</th>
                    <th className="numeric-cell" scope="col">Est. Savings</th>
                    <th scope="col">Reason / Notes</th>
                  </tr>
                </thead>
                <tbody>
                  {substitutions.map((sub) => (
                    <tr key={sub.id}>
                      <td>
                        <strong>{sub.substituteBrandName}</strong>
                      </td>
                      <td>
                        <span className="cell-muted">{sub.manufacturer || 'â€”'}</span>
                      </td>
                      <td className="numeric-cell">
                        {sub.mrp ? <Money amount={sub.mrp} /> : 'â€”'}
                      </td>
                      <td className="numeric-cell" style={{ color: 'var(--color-success)', fontWeight: 600 }}>
                        {sub.estimatedSavings ? <Money amount={sub.estimatedSavings} /> : 'â€”'}
                      </td>
                      <td>
                        <span className="cell-muted">{sub.reason || 'Bioequivalent substitution'}</span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </DataTable>
            )}

            <div style={{ marginTop: 'var(--space-md)', textAlign: 'right' }}>
              <Button onClick={() => setSelectedDrug(null)} variant="secondary">
                Close
              </Button>
            </div>
          </div>
        </div>
      )}

      {selectedHsnCode && (
        <div
          role="dialog"
          aria-modal="true"
          aria-labelledby="hsn-history-title"
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
              maxWidth: 680,
              maxHeight: '80vh',
              overflowY: 'auto',
              backgroundColor: 'var(--color-surface)',
              borderRadius: 'var(--radius-lg)',
              padding: 'var(--space-lg)',
              border: '1px solid var(--color-border)',
            }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 'var(--space-md)' }}>
              <div>
                <span className="panel-card__eyebrow">Statutory GST Rate Timeline</span>
                <h3 id="hsn-history-title" className="panel-card__title" style={{ fontSize: '1.25rem', marginTop: 4 }}>
                  HSN {selectedHsnCode} Rate History
                </h3>
              </div>
              <button
                aria-label="Close rate history dialog"
                className="icon-button"
                onClick={() => setSelectedHsnCode(null)}
                style={{ background: 'none', border: 'none', cursor: 'padding', padding: 4 }}
                type="button"
              >
                <X aria-hidden="true" size={20} />
              </button>
            </div>

            {rateHistoryQuery.isLoading ? (
              <p className="cell-muted">Loading statutory rate periods...</p>
            ) : rateHistory.length === 0 ? (
              <div className="directory-state" style={{ padding: 'var(--space-md)' }}>
                <History aria-hidden="true" size={20} />
                <strong>No rate history periods recorded.</strong>
                <p>Default statutory GST rate is currently in force.</p>
              </div>
            ) : (
              <DataTable caption="Historical statutory GST rates and notifications">
                <thead>
                  <tr>
                    <th scope="col">Effective Period</th>
                    <th scope="col">GST Rate</th>
                    <th scope="col">Cess</th>
                    <th scope="col">Notification Ref</th>
                    <th scope="col">Description</th>
                  </tr>
                </thead>
                <tbody>
                  {rateHistory.map((rh, idx) => (
                    <tr key={idx}>
                      <td>
                        <strong>
                          {rh.effectiveFrom || 'Inception'} â†’ {rh.effectiveTo || 'Present'}
                        </strong>
                      </td>
                      <td>
                        <StatusChip status={rh.gstRate != null ? `${rh.gstRate}%` : 'Exempt'} />
                      </td>
                      <td>
                        <span className="cell-muted">{rh.cessRate ? `${rh.cessRate}%` : '0%'}</span>
                      </td>
                      <td>
                        <span className="table-code">{rh.notificationRef || 'â€”'}</span>
                      </td>
                      <td>
                        <span className="cell-muted">{rh.description || 'â€”'}</span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </DataTable>
            )}

            <div style={{ marginTop: 'var(--space-md)', textAlign: 'right' }}>
              <Button onClick={() => setSelectedHsnCode(null)} variant="secondary">
                Close
              </Button>
            </div>
          </div>
        </div>
      )}

      {isAddRackOpen && (
        <div
          role="dialog"
          aria-modal="true"
          aria-labelledby="new-rack-title"
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
          <form
            onSubmit={handleCreateRack}
            className="panel-card"
            style={{
              width: '100%',
              maxWidth: 520,
              backgroundColor: 'var(--color-surface)',
              borderRadius: 'var(--radius-lg)',
              padding: 'var(--space-lg)',
              border: '1px solid var(--color-border)',
            }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 'var(--space-md)' }}>
              <div>
                <span className="panel-card__eyebrow">Warehouse Bin Management</span>
                <h3 id="new-rack-title" className="panel-card__title" style={{ fontSize: '1.25rem', marginTop: 4 }}>
                  Add Rack Location
                </h3>
              </div>
              <button
                aria-label="Close dialog"
                className="icon-button"
                onClick={() => setIsAddRackOpen(false)}
                style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 4 }}
                type="button"
              >
                <X aria-hidden="true" size={20} />
              </button>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-sm)' }}>
              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                  Warehouse *
                </label>
                <select
                  className="select-field"
                  onChange={(e) => setSelectedWarehouseId(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid var(--color-border)',
                    background: 'var(--color-surface)',
                    color: 'var(--color-text-primary)',
                  }}
                  value={selectedWarehouseId || warehouses[0]?.id || ''}
                >
                  {warehouses.map((w) => (
                    <option key={w.id} value={w.id}>
                      {w.name} ({w.code})
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                  Rack Code * (e.g. RACK-A-01-B2)
                </label>
                <input
                  required
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid var(--color-border)',
                    background: 'var(--color-surface)',
                    color: 'var(--color-text-primary)',
                  }}
                  onChange={(e) => setNewRackCode(e.target.value)}
                  placeholder="RACK-A-01"
                  type="text"
                  value={newRackCode}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                  Location Name / Label
                </label>
                <input
                  style={{
                    width: '100%',
                    padding: '8px 12px',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid var(--color-border)',
                    background: 'var(--color-surface)',
                    color: 'var(--color-text-primary)',
                  }}
                  onChange={(e) => setNewRackName(e.target.value)}
                  placeholder="Zone A Tablets Rack"
                  type="text"
                  value={newRackName}
                />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--space-sm)' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                    Zone
                  </label>
                  <input
                    style={{
                      width: '100%',
                      padding: '8px 12px',
                      borderRadius: 'var(--radius-md)',
                      border: '1px solid var(--color-border)',
                      background: 'var(--color-surface)',
                      color: 'var(--color-text-primary)',
                    }}
                    onChange={(e) => setNewRackZone(e.target.value)}
                    placeholder="Zone A"
                    type="text"
                    value={newRackZone}
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                    Aisle
                  </label>
                  <input
                    style={{
                      width: '100%',
                      padding: '8px 12px',
                      borderRadius: 'var(--radius-md)',
                      border: '1px solid var(--color-border)',
                      background: 'var(--color-surface)',
                      color: 'var(--color-text-primary)',
                    }}
                    onChange={(e) => setNewRackAisle(e.target.value)}
                    placeholder="Aisle 1"
                    type="text"
                    value={newRackAisle}
                  />
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--space-sm)' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                    Shelf
                  </label>
                  <input
                    style={{
                      width: '100%',
                      padding: '8px 12px',
                      borderRadius: 'var(--radius-md)',
                      border: '1px solid var(--color-border)',
                      background: 'var(--color-surface)',
                      color: 'var(--color-text-primary)',
                    }}
                    onChange={(e) => setNewRackShelf(e.target.value)}
                    placeholder="Shelf 2"
                    type="text"
                    value={newRackShelf}
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 500, marginBottom: 4 }}>
                    Bin / Box
                  </label>
                  <input
                    style={{
                      width: '100%',
                      padding: '8px 12px',
                      borderRadius: 'var(--radius-md)',
                      border: '1px solid var(--color-border)',
                      background: 'var(--color-surface)',
                      color: 'var(--color-text-primary)',
                    }}
                    onChange={(e) => setNewRackBin(e.target.value)}
                    placeholder="Bin B"
                    type="text"
                    value={newRackBin}
                  />
                </div>
              </div>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 'var(--space-sm)', marginTop: 'var(--space-md)' }}>
              <Button onClick={() => setIsAddRackOpen(false)} type="button" variant="secondary">
                Cancel
              </Button>
              <Button disabled={createRackMutation.isPending} type="submit" variant="primary">
                {createRackMutation.isPending ? 'Saving...' : 'Save Rack Location'}
              </Button>
            </div>
          </form>
        </div>
      )}
    </section>
  )
}
