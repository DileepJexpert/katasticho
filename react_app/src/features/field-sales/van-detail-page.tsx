import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useNavigate, useParams } from 'react-router-dom'
import {
  ArrowDownLeft,
  ArrowLeft,
  ArrowUpRight,
  Boxes,
  Truck,
  X,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate } from '@/shared/format/format'
import {
  confirmVanLoad,
  confirmVanReturn,
  createVanLoad,
  createVanReturn,
  getVan,
  getVanStock,
  listVanTransfers,
  type VanStockBalance,
  type VanStockTransfer,
} from '@/features/field-sales/field-sales-api'

export function VanDetailPage() {
  const { vanId = '' } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [activeTab, setActiveTab] = useState<'stock' | 'transfers'>('stock')
  const [isLoadOpen, setIsLoadOpen] = useState(false)
  const [isReturnOpen, setIsReturnOpen] = useState(false)

  const { data: van, isLoading: isVanLoading } = useQuery({
    queryKey: ['field-sales', 'vans', vanId],
    queryFn: () => getVan(vanId),
    enabled: !!vanId,
  })

  const { data: balances = [], isLoading: isBalancesLoading } = useQuery({
    queryKey: ['field-sales', 'vans', vanId, 'balances'],
    queryFn: () => getVanStock(vanId),
    enabled: !!vanId,
  })

  const { data: transfers = [], isLoading: isTransfersLoading } = useQuery({
    queryKey: ['field-sales', 'vans', vanId, 'transfers'],
    queryFn: () => listVanTransfers(vanId),
    enabled: !!vanId,
  })

  const loadMutation = useMutation({
    mutationFn: (payload: { warehouseId: string; lines: Array<{ itemId: string; batchId?: string | null; quantity: number }> }) =>
      createVanLoad({ vanId, ...payload }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['field-sales', 'vans', vanId] })
      setIsLoadOpen(false)
    },
  })

  const returnMutation = useMutation({
    mutationFn: (payload: { warehouseId: string; lines: Array<{ itemId: string; batchId?: string | null; quantity: number }> }) =>
      createVanReturn({ vanId, ...payload }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['field-sales', 'vans', vanId] })
      setIsReturnOpen(false)
    },
  })

  const confirmLoadMutation = useMutation({
    mutationFn: (transferId: string) => confirmVanLoad(transferId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['field-sales', 'vans', vanId] })
    },
  })

  const confirmReturnMutation = useMutation({
    mutationFn: (transferId: string) => confirmVanReturn(transferId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['field-sales', 'vans', vanId] })
    },
  })

  if (isVanLoading) return <div className="directory-state">Loading van workbench...</div>
  if (!van) return <DocumentError onBack={() => navigate('/vans')} />

  const totalValuation = balances.reduce((sum: number, b: VanStockBalance) => sum + Number(b.quantityOnHand || 0) * Number(b.averageCost || 0), 0)

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <div style={{ display: 'flex', gap: 8 }}>
            <Button onClick={() => setIsLoadOpen(true)} type="button" variant="secondary">
              <ArrowDownLeft aria-hidden="true" size={16} />
              <span>Load Stock (To Van)</span>
            </Button>
            <Button onClick={() => setIsReturnOpen(true)} type="button" variant="secondary">
              <ArrowUpRight aria-hidden="true" size={16} />
              <span>Return Stock (To Depot)</span>
            </Button>
          </div>
        }
        description={`Registration: ${van.vehicleNumber} | Model: ${van.name || 'â€”'} | Status: ${van.isActive ? 'ACTIVE' : 'INACTIVE'}`}
        eyebrow="Mobile Van Workbench"
        title={`${van.code} â€” ${van.vehicleNumber}`}
      />

      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 16 }}>
        <button className="button button--ghost" onClick={() => navigate('/vans')} type="button">
          <ArrowLeft aria-hidden="true" size={16} />
          <span>Back to Vans</span>
        </button>
      </div>

      <div className="summary-strip">
        <div className="metric-cell">
          <span className="metric-label">SKUs On Board</span>
          <strong className="metric-value">{balances.length}</strong>
        </div>
        <div className="metric-cell">
          <span className="metric-label">On-Board Inventory Value</span>
          <strong className="metric-value"><Money amount={totalValuation} /></strong>
        </div>
        <div className="metric-cell">
          <span className="metric-label">Transfers Logged</span>
          <strong className="metric-value">{transfers.length}</strong>
        </div>
      </div>

      <div className="workspace-tabs" role="tablist">
        <button
          className={`tab-item ${activeTab === 'stock' ? 'tab-item--active' : ''}`}
          onClick={() => setActiveTab('stock')}
          role="tab"
          type="button"
        >
          On-Board Stock Balances
        </button>
        <button
          className={`tab-item ${activeTab === 'transfers' ? 'tab-item--active' : ''}`}
          onClick={() => setActiveTab('transfers')}
          role="tab"
          type="button"
        >
          Load & Return Transfers
        </button>
      </div>

      {activeTab === 'stock' ? (
        <div className="table-card">
          {isBalancesLoading ? (
            <div className="directory-state">Loading stock balances...</div>
          ) : balances.length === 0 ? (
            <div className="directory-state">
              <Boxes aria-hidden="true" size={32} />
              <p>No inventory loaded on this van. Use "Load Stock" to issue products from the central depot.</p>
            </div>
          ) : (
            <DataTable caption="Van On-Board Stock Balances">
              <thead>
                <tr>
                  <th scope="col">Item SKU & Name</th>
                  <th scope="col">Batch #</th>
                  <th scope="col" style={{ textAlign: 'right' }}>On-Hand Qty</th>
                  <th scope="col" style={{ textAlign: 'right' }}>Unit Cost</th>
                  <th scope="col" style={{ textAlign: 'right' }}>Total Value</th>
                </tr>
              </thead>
              <tbody>
                {balances.map((b: VanStockBalance) => {
                  const val = Number(b.quantityOnHand || 0) * Number(b.averageCost || 0)
                  return (
                    <tr key={b.id}>
                      <td><strong>{b.itemName || b.itemCode || b.itemId}</strong></td>
                      <td><code>{b.batchNumber || 'â€”'}</code></td>
                      <td style={{ textAlign: 'right' }}>
                        <strong><Quantity unit="units" value={b.quantityOnHand} /></strong>
                      </td>
                      <td style={{ textAlign: 'right' }}><Money amount={b.averageCost || 0} /></td>
                      <td style={{ textAlign: 'right' }}><strong><Money amount={val} /></strong></td>
                    </tr>
                  )
                })}
              </tbody>
            </DataTable>
          )}
        </div>
      ) : (
        <div className="table-card">
          {isTransfersLoading ? (
            <div className="directory-state">Loading transfers...</div>
          ) : transfers.length === 0 ? (
            <div className="directory-state">
              <Truck aria-hidden="true" size={32} />
              <p>No load or return transfers recorded for this vehicle.</p>
            </div>
          ) : (
            <DataTable caption="Van Transfers History">
              <thead>
                <tr>
                  <th scope="col">Type</th>
                  <th scope="col">Created Date</th>
                  <th scope="col" style={{ textAlign: 'right' }}>Total Quantity</th>
                  <th scope="col">Status</th>
                  <th scope="col" style={{ textAlign: 'right' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {transfers.map((t: VanStockTransfer) => (
                  <tr key={t.id}>
                    <td><StatusChip status={t.transferType} /></td>
                    <td>{formatDate(t.createdAt)}</td>
                    <td style={{ textAlign: 'right' }}><strong>{t.totalQuantity ?? 0}</strong></td>
                    <td><StatusChip status={t.status} /></td>
                    <td style={{ textAlign: 'right' }}>
                      {t.status === 'DRAFT' && t.transferType === 'LOAD' ? (
                        <Button
                          disabled={confirmLoadMutation.isPending}
                          onClick={() => confirmLoadMutation.mutate(t.id)}
                          type="button"
                          variant="secondary"
                        >
                          Confirm Load
                        </Button>
                      ) : t.status === 'DRAFT' && t.transferType === 'RETURN' ? (
                        <Button
                          disabled={confirmReturnMutation.isPending}
                          onClick={() => confirmReturnMutation.mutate(t.id)}
                          type="button"
                          variant="secondary"
                        >
                          Confirm Return
                        </Button>
                      ) : null}
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          )}
        </div>
      )}

      {isLoadOpen ? (
        <TransferModal
          isPending={loadMutation.isPending}
          onClose={() => setIsLoadOpen(false)}
          onSubmit={(payload) => loadMutation.mutate(payload)}
          title="Load Stock to Van"
        />
      ) : null}

      {isReturnOpen ? (
        <TransferModal
          isPending={returnMutation.isPending}
          onClose={() => setIsReturnOpen(false)}
          onSubmit={(payload) => returnMutation.mutate(payload)}
          title="Return Stock to Warehouse"
        />
      ) : null}
    </section>
  )
}

function TransferModal({
  onClose,
  onSubmit,
  isPending,
  title,
}: {
  onClose: () => void
  onSubmit: (payload: { warehouseId: string; lines: Array<{ itemId: string; batchId?: string | null; quantity: number }> }) => void
  isPending: boolean
  title: string
}) {
  const [warehouseId, setWarehouseId] = useState('')
  const [itemId, setItemId] = useState('')
  const [quantity, setQuantity] = useState(10)

  return (
    <div className="modal-backdrop">
      <div className="modal-card" style={{ maxWidth: 460 }}>
        <div className="modal-header">
          <h2 className="modal-title">{title}</h2>
          <button aria-label="Close" className="button button--ghost" onClick={onClose} type="button">
            <X aria-hidden="true" size={18} />
          </button>
        </div>

        <form
          onSubmit={(e) => {
            e.preventDefault()
            onSubmit({
              warehouseId,
              lines: [{ itemId, quantity }],
            })
          }}
        >
          <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div className="form-field">
              <label className="form-label" htmlFor="wh-id">Depot Warehouse UUID *</label>
              <input
                className="form-input"
                id="wh-id"
                onChange={(e) => setWarehouseId(e.target.value)}
                placeholder="Warehouse UUID"
                required
                value={warehouseId}
              />
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: 12 }}>
              <div className="form-field">
                <label className="form-label" htmlFor="item-id">Item SKU / UUID *</label>
                <input
                  className="form-input"
                  id="item-id"
                  onChange={(e) => setItemId(e.target.value)}
                  placeholder="Item UUID"
                  required
                  value={itemId}
                />
              </div>

              <div className="form-field">
                <label className="form-label" htmlFor="tr-qty">Qty *</label>
                <input
                  className="form-input"
                  id="tr-qty"
                  min={1}
                  onChange={(e) => setQuantity(parseFloat(e.target.value) || 1)}
                  type="number"
                  value={quantity}
                />
              </div>
            </div>
          </div>

          <div className="modal-footer">
            <Button onClick={onClose} type="button" variant="secondary">Cancel</Button>
            <Button disabled={isPending || !warehouseId || !itemId} type="submit" variant="primary">
              {isPending ? 'Processing...' : 'Submit Transfer'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  )
}

function DocumentError({ onBack }: { onBack: () => void }) {
  return (
    <section className="workspace-page">
      <div className="directory-state directory-state--error" role="alert">
        <Truck aria-hidden="true" size={24} />
        <p>Mobile van could not be found or loaded.</p>
        <Button onClick={onBack} type="button" variant="secondary">Return to Vans</Button>
      </div>
    </section>
  )
}
