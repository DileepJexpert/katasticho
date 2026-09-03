import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { Layers, Plus } from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import {
  diffBomVersions,
  getBomCostRollup,
  getBomVersion,
  getLatestBomVersion,
  createBomVersion,
  listBomAlternates,
  listBomCoProducts,
} from '@/features/bom/bom-api'

export function BomManagerPage() {
  const queryClient = useQueryClient()
  const [activeTab, setActiveTab] = useState<'versions' | 'diff' | 'cost' | 'alternates' | 'coproducts'>('versions')
  const [parentItemId, setParentItemId] = useState('d1000000-0000-0000-0000-000000000001')
  const [selectedVersion, setSelectedVersion] = useState(1)
  const [fromVer, setFromVer] = useState(1)
  const [toVer, setToVer] = useState(2)
  const [isCreateVersionOpen, setIsCreateVersionOpen] = useState(false)
  const [changeNotes, setChangeNotes] = useState('')

  const latestVerQuery = useQuery({
    queryKey: ['bom', parentItemId, 'latest'],
    queryFn: () => getLatestBomVersion(parentItemId),
    enabled: Boolean(parentItemId),
  })

  const versionQuery = useQuery({
    queryKey: ['bom', parentItemId, 'version', selectedVersion],
    queryFn: () => getBomVersion(parentItemId, selectedVersion),
    enabled: Boolean(parentItemId) && activeTab === 'versions',
  })

  const diffQuery = useQuery({
    queryKey: ['bom', parentItemId, 'diff', fromVer, toVer],
    queryFn: () => diffBomVersions(parentItemId, fromVer, toVer),
    enabled: Boolean(parentItemId) && activeTab === 'diff',
  })

  const costQuery = useQuery({
    queryKey: ['bom', parentItemId, 'cost-rollup'],
    queryFn: () => getBomCostRollup(parentItemId),
    enabled: Boolean(parentItemId) && activeTab === 'cost',
  })

  const alternatesQuery = useQuery({
    queryKey: ['bom-alternates', parentItemId],
    queryFn: () => listBomAlternates(parentItemId),
    enabled: Boolean(parentItemId) && activeTab === 'alternates',
  })

  const coProductsQuery = useQuery({
    queryKey: ['bom-coproducts', parentItemId],
    queryFn: () => listBomCoProducts(parentItemId),
    enabled: Boolean(parentItemId) && activeTab === 'coproducts',
  })

  const createVersionMutation = useMutation({
    mutationFn: () => createBomVersion(parentItemId, changeNotes),
    onSuccess: (data) => {
      setIsCreateVersionOpen(false)
      setChangeNotes('')
      setSelectedVersion(data.version)
      queryClient.invalidateQueries({ queryKey: ['bom', parentItemId] })
    },
  })

  const latestVer = latestVerQuery.data?.version ?? 1

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Manufacturing / Engineering"
        title="BOM & Engineering Workbench"
        description="Multi-level Bill of Materials versioning, side-by-side engineering diffs, cost roll-ups, and co-products."
        actions={
          <div className="table-actions">
            <Button onClick={() => setIsCreateVersionOpen(true)} variant="primary">
              <Plus aria-hidden="true" size={16} />
              Create BOM Version
            </Button>
          </div>
        }
      />

      <div className="list-toolbar">
        <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
          <label style={{ fontSize: '13px', fontWeight: 600 }}>Parent Item ID:</label>
          <input
            className="search-input"
            onChange={(e) => setParentItemId(e.target.value)}
            style={{ width: '320px' }}
            value={parentItemId}
          />
          <StatusChip status={`Latest: v${latestVer}`} />
        </div>

        <div className="list-tabs" role="tablist">
          <button
            className={activeTab === 'versions' ? 'list-tab list-tab--active' : 'list-tab'}
            onClick={() => setActiveTab('versions')}
            type="button"
          >
            Components (v{selectedVersion})
          </button>
          <button
            className={activeTab === 'diff' ? 'list-tab list-tab--active' : 'list-tab'}
            onClick={() => setActiveTab('diff')}
            type="button"
          >
            Version Diff
          </button>
          <button
            className={activeTab === 'cost' ? 'list-tab list-tab--active' : 'list-tab'}
            onClick={() => setActiveTab('cost')}
            type="button"
          >
            Cost Roll-up
          </button>
          <button
            className={activeTab === 'alternates' ? 'list-tab list-tab--active' : 'list-tab'}
            onClick={() => setActiveTab('alternates')}
            type="button"
          >
            Substitute Materials
          </button>
          <button
            className={activeTab === 'coproducts' ? 'list-tab list-tab--active' : 'list-tab'}
            onClick={() => setActiveTab('coproducts')}
            type="button"
          >
            Co-Products & By-Products
          </button>
        </div>
      </div>

      {activeTab === 'versions' && (
        <div className="document-layout">
          <section className="document-card" style={{ flex: 1 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
              <h2>Active BOM Components (Version {selectedVersion})</h2>
              <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                <span style={{ fontSize: '13px', color: 'var(--text-muted)' }}>Select Version:</span>
                <select
                  className="search-input"
                  onChange={(e) => setSelectedVersion(Number(e.target.value))}
                  style={{ width: '80px' }}
                  value={selectedVersion}
                >
                  {Array.from({ length: latestVer }, (_, i) => i + 1).map((v) => (
                    <option key={v} value={v}>v{v}</option>
                  ))}
                </select>
              </div>
            </div>

            {versionQuery.isLoading ? (
              <div className="directory-state">Loading BOM components...</div>
            ) : versionQuery.data && versionQuery.data.length > 0 ? (
              <DataTable caption={`BOM components for version ${selectedVersion}`}>
                <thead>
                  <tr>
                    <th scope="col">Component Item</th>
                    <th className="numeric-cell" scope="col">Required Qty</th>
                    <th className="numeric-cell" scope="col">Scrap Factor %</th>
                    <th className="numeric-cell" scope="col">Cost Allocation %</th>
                    <th scope="col">Version</th>
                  </tr>
                </thead>
                <tbody>
                  {versionQuery.data.map((comp) => (
                    <tr key={comp.id}>
                      <td>
                        <strong>{comp.componentItemName || comp.componentItemId}</strong>
                      </td>
                      <td className="numeric-cell">
                        <Quantity value={comp.quantity} />
                      </td>
                      <td className="numeric-cell">
                        {comp.scrapFactorPercent ? `${comp.scrapFactorPercent}%` : '0%'}
                      </td>
                      <td className="numeric-cell">
                        {comp.costAllocationPercent ? `${comp.costAllocationPercent}%` : '100%'}
                      </td>
                      <td>
                        <code>v{comp.version}</code>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </DataTable>
            ) : (
              <div className="directory-state">
                <Layers size={24} />
                <strong>No BOM components configured for version {selectedVersion}.</strong>
              </div>
            )}
          </section>
        </div>
      )}

      {activeTab === 'diff' && (
        <section className="document-card">
          <div style={{ display: 'flex', gap: '16px', alignItems: 'center', marginBottom: '16px' }}>
            <h2>BOM Engineering Version Diff</h2>
            <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
              <label style={{ fontSize: '13px' }}>From v</label>
              <input
                className="search-input"
                onChange={(e) => setFromVer(Number(e.target.value))}
                style={{ width: '60px' }}
                type="number"
                value={fromVer}
              />
              <label style={{ fontSize: '13px' }}>To v</label>
              <input
                className="search-input"
                onChange={(e) => setToVer(Number(e.target.value))}
                style={{ width: '60px' }}
                type="number"
                value={toVer}
              />
            </div>
          </div>

          {diffQuery.isLoading ? (
            <div className="directory-state">Computing engineering diff...</div>
          ) : diffQuery.data ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div>
                <h3 style={{ color: 'var(--color-success)', fontSize: '14px', marginBottom: '8px' }}>
                  + Added Components ({diffQuery.data.added.length})
                </h3>
                {diffQuery.data.added.length > 0 ? (
                  <DataTable caption="Added components">
                    <thead>
                      <tr>
                        <th scope="col">Item</th>
                        <th className="numeric-cell" scope="col">Quantity</th>
                      </tr>
                    </thead>
                    <tbody>
                      {diffQuery.data.added.map((item, idx) => (
                        <tr key={idx}>
                          <td>{item.itemName || item.itemId}</td>
                          <td className="numeric-cell"><Quantity value={item.quantity} /></td>
                        </tr>
                      ))}
                    </tbody>
                  </DataTable>
                ) : <p className="cell-muted">No components added.</p>}
              </div>

              <div>
                <h3 style={{ color: 'var(--color-danger)', fontSize: '14px', marginBottom: '8px' }}>
                  - Removed Components ({diffQuery.data.removed.length})
                </h3>
                {diffQuery.data.removed.length > 0 ? (
                  <DataTable caption="Removed components">
                    <thead>
                      <tr>
                        <th scope="col">Item</th>
                        <th className="numeric-cell" scope="col">Quantity</th>
                      </tr>
                    </thead>
                    <tbody>
                      {diffQuery.data.removed.map((item, idx) => (
                        <tr key={idx}>
                          <td>{item.itemName || item.itemId}</td>
                          <td className="numeric-cell"><Quantity value={item.quantity} /></td>
                        </tr>
                      ))}
                    </tbody>
                  </DataTable>
                ) : <p className="cell-muted">No components removed.</p>}
              </div>

              <div>
                <h3 style={{ color: 'var(--color-warning)', fontSize: '14px', marginBottom: '8px' }}>
                  ~ Changed Quantities ({diffQuery.data.changed.length})
                </h3>
                {diffQuery.data.changed.length > 0 ? (
                  <DataTable caption="Changed components">
                    <thead>
                      <tr>
                        <th scope="col">Item</th>
                        <th className="numeric-cell" scope="col">Old Qty (v{fromVer})</th>
                        <th className="numeric-cell" scope="col">New Qty (v{toVer})</th>
                      </tr>
                    </thead>
                    <tbody>
                      {diffQuery.data.changed.map((item, idx) => (
                        <tr key={idx}>
                          <td>{item.itemName || item.itemId}</td>
                          <td className="numeric-cell"><Quantity value={item.oldQuantity} /></td>
                          <td className="numeric-cell"><Quantity value={item.newQuantity} /></td>
                        </tr>
                      ))}
                    </tbody>
                  </DataTable>
                ) : <p className="cell-muted">No quantity changes.</p>}
              </div>
            </div>
          ) : (
            <div className="directory-state">No diff results.</div>
          )}
        </section>
      )}

      {activeTab === 'cost' && (
        <section className="document-card">
          <h2>BOM Cost Roll-up Breakdown</h2>
          {costQuery.isLoading ? (
            <div className="directory-state">Calculating BOM cost rollup...</div>
          ) : costQuery.data ? (
            <div>
              <div className="progress-row progress-row--total" style={{ marginBottom: '16px' }}>
                <span>Calculated Unit Manufacturing Cost:</span>
                <Money amount={costQuery.data.totalUnitCost} />
              </div>
              <dl className="document-facts" style={{ marginBottom: '20px' }}>
                <div className="document-fact"><dt>Raw Material Cost</dt><dd><Money amount={costQuery.data.rawMaterialCost} /></dd></div>
                <div className="document-fact"><dt>Direct Labor Cost</dt><dd><Money amount={costQuery.data.laborCost} /></dd></div>
                <div className="document-fact"><dt>Overhead Allocation</dt><dd><Money amount={costQuery.data.overheadCost} /></dd></div>
              </dl>

              <h3>Component Cost Contribution</h3>
              {costQuery.data.components && costQuery.data.components.length > 0 ? (
                <DataTable caption="Component cost contribution">
                  <thead>
                    <tr>
                      <th scope="col">Component</th>
                      <th className="numeric-cell" scope="col">Qty Required</th>
                      <th className="numeric-cell" scope="col">Unit Cost</th>
                      <th className="numeric-cell" scope="col">Extended Cost</th>
                    </tr>
                  </thead>
                  <tbody>
                    {costQuery.data.components.map((c, idx) => (
                      <tr key={idx}>
                        <td><strong>{c.itemName}</strong></td>
                        <td className="numeric-cell"><Quantity value={c.qtyRequired} /></td>
                        <td className="numeric-cell"><Money amount={c.unitCost} /></td>
                        <td className="numeric-cell"><Money amount={c.lineCost} /></td>
                      </tr>
                    ))}
                  </tbody>
                </DataTable>
              ) : <p className="cell-muted">No component lines found.</p>}
            </div>
          ) : (
            <div className="directory-state">Unable to load cost rollup.</div>
          )}
        </section>
      )}

      {activeTab === 'alternates' && (
        <section className="document-card">
          <h2>Substitute Raw Materials (Alternates)</h2>
          {alternatesQuery.isLoading ? (
            <div className="directory-state">Loading alternates...</div>
          ) : alternatesQuery.data && alternatesQuery.data.length > 0 ? (
            <DataTable caption="Approved substitute materials">
              <thead>
                <tr>
                  <th scope="col">Alternate Item</th>
                  <th className="numeric-cell" scope="col">Priority</th>
                  <th scope="col">Notes</th>
                </tr>
              </thead>
              <tbody>
                {alternatesQuery.data.map((alt) => (
                  <tr key={alt.id}>
                    <td><strong>{alt.alternateItemName || alt.alternateItemId}</strong></td>
                    <td className="numeric-cell">{alt.priority ?? 1}</td>
                    <td>{alt.notes ?? '--'}</td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          ) : (
            <div className="directory-state">
              <Layers size={24} />
              <strong>No substitute materials registered.</strong>
            </div>
          )}
        </section>
      )}

      {activeTab === 'coproducts' && (
        <section className="document-card">
          <h2>Co-Products & By-Products</h2>
          {coProductsQuery.isLoading ? (
            <div className="directory-state">Loading co-products...</div>
          ) : coProductsQuery.data && coProductsQuery.data.length > 0 ? (
            <DataTable caption="Co-products output from production run">
              <thead>
                <tr>
                  <th scope="col">Co-Product / By-Product Item</th>
                  <th className="numeric-cell" scope="col">Qty Per FG Unit</th>
                  <th className="numeric-cell" scope="col">Cost Allocation %</th>
                </tr>
              </thead>
              <tbody>
                {coProductsQuery.data.map((cop) => (
                  <tr key={cop.id}>
                    <td><strong>{cop.coProductItemName || cop.coProductItemId}</strong></td>
                    <td className="numeric-cell"><Quantity value={cop.quantityPerUnit} /></td>
                    <td className="numeric-cell">{cop.costAllocationPercent ? `${cop.costAllocationPercent}%` : '0%'}</td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          ) : (
            <div className="directory-state">
              <Layers size={24} />
              <strong>No co-products defined for this parent item.</strong>
            </div>
          )}
        </section>
      )}

      {isCreateVersionOpen && (
        <div className="modal-backdrop">
          <div className="modal-card">
            <h3>Create New BOM Version</h3>
            <p className="cell-muted" style={{ marginBottom: '16px' }}>
              Creating version {latestVer + 1} for item {parentItemId}.
            </p>
            <label style={{ display: 'block', marginBottom: '16px' }}>
              <span style={{ fontSize: '13px', fontWeight: 600 }}>Change Notes / Engineering ECO:</span>
              <textarea
                className="search-input"
                onChange={(e) => setChangeNotes(e.target.value)}
                placeholder="Reason for revision (e.g. replaced supplier packaging, adjusted mix ratio)..."
                rows={3}
                style={{ width: '100%', marginTop: '4px' }}
                value={changeNotes}
              />
            </label>
            <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end' }}>
              <Button onClick={() => setIsCreateVersionOpen(false)} variant="secondary">
                Cancel
              </Button>
              <Button
                disabled={createVersionMutation.isPending}
                onClick={() => createVersionMutation.mutate()}
                variant="primary"
              >
                Create Version {latestVer + 1}
              </Button>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}