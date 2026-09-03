import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { Factory, Search, Plus, Play, RefreshCw, BarChart3, Layers } from 'lucide-react'
import { Link } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { listWorkOrders, createWorkOrder, autoCreateFromReorder } from '@/features/work-orders/work-orders-api'

const statusTabs = [
  { key: 'all', label: 'All work orders' },
  { key: 'DRAFT', label: 'Draft' },
  { key: 'IN_PROGRESS', label: 'In Progress' },
  { key: 'COMPLETED', label: 'Completed' },
  { key: 'CANCELLED', label: 'Cancelled' },
] as const

type StatusTab = (typeof statusTabs)[number]['key']

export function WorkOrdersPage() {
  const queryClient = useQueryClient()
  const [activeTab, setActiveTab] = useState<StatusTab>('all')
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(0)
  const [isCreateOpen, setIsCreateOpen] = useState(false)
  const [fgId, setFgId] = useState('')
  const [warehouseId, setWarehouseId] = useState('')
  const [qty, setQty] = useState('100')
  const [priority, setPriority] = useState('NORMAL')
  const [notes, setNotes] = useState('')
  const [backflush, setBackflush] = useState(false)

  const query = useQuery({
    queryKey: ['work-orders', page, activeTab],
    queryFn: () =>
      listWorkOrders({
        page,
        status: activeTab === 'all' ? null : activeTab,
      }),
  })

  const createMutation = useMutation({
    mutationFn: () => createWorkOrder({
      finishedGoodId: fgId,
      warehouseId: warehouseId || 'w1000000-0000-0000-0000-000000000001',
      quantityToProduce: Number(qty),
      priority,
      notes,
      backflushMode: backflush,
    }),
    onSuccess: () => {
      setIsCreateOpen(false)
      setFgId('')
      setNotes('')
      queryClient.invalidateQueries({ queryKey: ['work-orders'] })
    },
  })

  const reorderMutation = useMutation({
    mutationFn: autoCreateFromReorder,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['work-orders'] })
    },
  })

  const pageData = query.data
  const rawList = pageData?.content ?? []
  const filtered = rawList.filter((wo) => {
    if (!search.trim()) return true
    const q = search.toLowerCase()
    const matchNum = wo.workOrderNumber.toLowerCase().includes(q)
    const matchFg = wo.finishedGoodName ? wo.finishedGoodName.toLowerCase().includes(q) : false
    const matchNotes = wo.notes ? wo.notes.toLowerCase().includes(q) : false
    return matchNum || matchFg || matchNotes
  })

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Manufacturing & Assembly"
        title="Work Orders"
        description="Production floor build orders, multi-level BOM consumption, and assembly tracking."
        actions={
          <div className="table-actions">
            <Link to="/bom-manager">
              <Button variant="secondary">
                <Layers aria-hidden="true" size={16} />
                BOM Workbench
              </Button>
            </Link>
            <Link to="/mrp">
              <Button variant="secondary">
                <Play aria-hidden="true" size={16} />
                MRP Engine
              </Button>
            </Link>
            <Link to="/reports/manufacturing">
              <Button variant="secondary">
                <BarChart3 aria-hidden="true" size={16} />
                Floor Analytics
              </Button>
            </Link>
            <Button
              disabled={reorderMutation.isPending}
              onClick={() => reorderMutation.mutate()}
              variant="secondary"
            >
              <RefreshCw aria-hidden="true" size={16} />
              Replenish Reorder
            </Button>
            <Button onClick={() => setIsCreateOpen(true)} variant="primary">
              <Plus aria-hidden="true" size={16} />
              Create Work Order
            </Button>
          </div>
        }
      />

      <div className="list-toolbar">
        <label className="directory-search">
          <Search aria-hidden="true" size={18} />
          <span className="sr-only">Search work orders</span>
          <input
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by WO number, finished good, or notes..."
            type="search"
            value={search}
          />
        </label>
        <div aria-label="Filter work orders by status" className="list-tabs" role="tablist">
          {statusTabs.map((tab) => (
            <button
              aria-selected={activeTab === tab.key}
              className={activeTab === tab.key ? 'list-tab list-tab--active' : 'list-tab'}
              key={tab.key}
              onClick={() => {
                setActiveTab(tab.key)
                setPage(0)
              }}
              role="tab"
              type="button"
            >
              {tab.label}
            </button>
          ))}
        </div>
      </div>

      {query.isLoading ? (
        <div aria-live="polite" className="directory-state">Loading work orders...</div>
      ) : filtered.length === 0 ? (
        <div className="directory-state">
          <Factory aria-hidden="true" size={24} />
          <strong>No work orders found.</strong>
        </div>
      ) : (
        <DataTable caption="Manufacturing and assembly work orders">
          <thead>
            <tr>
              <th scope="col">Work Order #</th>
              <th scope="col">Finished Good</th>
              <th className="numeric-cell" scope="col">Produced / Planned</th>
              <th scope="col">Timeline</th>
              <th scope="col">Priority</th>
              <th scope="col">Status</th>
              <th className="numeric-cell" scope="col">Total Cost</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((wo) => {
              const priorityClass =
                wo.priority === 'URGENT'
                  ? 'status-badge status-badge--danger'
                  : wo.priority === 'HIGH'
                  ? 'status-badge status-badge--warning'
                  : 'cell-muted'

              return (
                <tr key={wo.id}>
                  <td>
                    <div className="cell-stack">
                      <Link className="table-row-link" to={appRoutes.workOrderDetail(wo.id)}>
                        {wo.workOrderNumber}
                      </Link>
                      {wo.disassembly ? (
                        <span className="status-badge status-badge--warning">Disassembly</span>
                      ) : null}
                    </div>
                  </td>
                  <td>
                    <div className="cell-stack">
                      <strong>{wo.finishedGoodName || `FG: ${wo.finishedGoodId.slice(0, 8)}`}</strong>
                      {wo.bomVersion ? <span className="cell-muted">BOM v{wo.bomVersion}</span> : null}
                    </div>
                  </td>
                  <td className="numeric-cell">
                    <div className="cell-stack">
                      <span>
                        <Quantity value={wo.quantityProduced} /> / <Quantity value={wo.quantityToProduce} />
                      </span>
                    </div>
                  </td>
                  <td>
                    <div className="cell-stack">
                      <span>{wo.plannedStartDate ? formatDate(wo.plannedStartDate) : '--'}</span>
                      {wo.plannedEndDate ? (
                        <span className="cell-muted">Due {formatDate(wo.plannedEndDate)}</span>
                      ) : null}
                    </div>
                  </td>
                  <td>
                    <span className={priorityClass}>{wo.priority || 'NORMAL'}</span>
                  </td>
                  <td>
                    <StatusChip status={formatStatusLabel(wo.status)} />
                  </td>
                  <td className="numeric-cell">
                    <Money amount={wo.totalCost} />
                  </td>
                </tr>
              )
            })}
          </tbody>
        </DataTable>
      )}

      {isCreateOpen && (
        <div className="modal-backdrop">
          <div className="modal-card">
            <h3>Create Manufacturing Work Order</h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginTop: '12px' }}>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Finished Good Item ID:</span>
                <input
                  className="search-input"
                  onChange={(e) => setFgId(e.target.value)}
                  placeholder="UUID of manufactured product (composite item)"
                  style={{ width: '100%', marginTop: '4px' }}
                  value={fgId}
                />
              </label>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Production Facility / Warehouse ID:</span>
                <input
                  className="search-input"
                  onChange={(e) => setWarehouseId(e.target.value)}
                  placeholder="Target Warehouse UUID (optional)"
                  style={{ width: '100%', marginTop: '4px' }}
                  value={warehouseId}
                />
              </label>
              <div style={{ display: 'flex', gap: '12px' }}>
                <label style={{ flex: 1 }}>
                  <span style={{ fontSize: '13px', fontWeight: 600 }}>Quantity to Produce:</span>
                  <input
                    className="search-input"
                    onChange={(e) => setQty(e.target.value)}
                    style={{ width: '100%', marginTop: '4px' }}
                    type="number"
                    value={qty}
                  />
                </label>
                <label style={{ flex: 1 }}>
                  <span style={{ fontSize: '13px', fontWeight: 600 }}>Priority:</span>
                  <select
                    className="search-input"
                    onChange={(e) => setPriority(e.target.value)}
                    style={{ width: '100%', marginTop: '4px' }}
                    value={priority}
                  >
                    <option value="NORMAL">Normal</option>
                    <option value="HIGH">High</option>
                    <option value="URGENT">Urgent</option>
                  </select>
                </label>
              </div>
              <label style={{ display: 'flex', gap: '8px', alignItems: 'center', marginTop: '4px' }}>
                <input
                  checked={backflush}
                  onChange={(e) => setBackflush(e.target.checked)}
                  type="checkbox"
                />
                <span style={{ fontSize: '13px' }}>Enable Backflush Mode (Auto-deduct BOM components on FG receipt)</span>
              </label>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Production Notes:</span>
                <textarea
                  className="search-input"
                  onChange={(e) => setNotes(e.target.value)}
                  placeholder="Special assembly instructions, batch tags..."
                  rows={2}
                  style={{ width: '100%', marginTop: '4px' }}
                  value={notes}
                />
              </label>
            </div>
            <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end', marginTop: '16px' }}>
              <Button onClick={() => setIsCreateOpen(false)} variant="secondary">Cancel</Button>
              <Button
                disabled={createMutation.isPending || !fgId.trim()}
                onClick={() => createMutation.mutate()}
                variant="primary"
              >
                Create Work Order
              </Button>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}