import { useEffect, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { ChevronLeft, ChevronRight, Truck } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { listDeliveryChallans, type DeliveryChallan } from '@/features/delivery-challans/delivery-challans-api'

const challanFilters = [
  { label: 'All', value: null },
  { label: 'Draft', value: 'DRAFT' },
  { label: 'Dispatched', value: 'DISPATCHED' },
  { label: 'Delivered', value: 'DELIVERED' },
  { label: 'Cancelled', value: 'CANCELLED' },
] as const

type ChallanFilter = typeof challanFilters[number]['value']

export function DeliveryChallansPage() {
  const [filter, setFilter] = useState<ChallanFilter>(null)
  const [page, setPage] = useState(0)
  const navigate = useNavigate()

  useEffect(() => {
    setPage(0)
  }, [filter])

  const challans = useQuery({
    queryKey: ['delivery-challans', { page, status: filter }],
    queryFn: () => listDeliveryChallans({ page, status: filter }),
  })
  const challanPage = challans.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Sales / Fulfilment"
        title="Delivery Challans"
        description="Customer dispatches, warehouse shipment progress, and stock movement records."
        actions={<StatusChip status="Read-only pilot" />}
      />

      <section className="list-panel" aria-label="Delivery challan directory">
        <div className="list-toolbar list-toolbar--stacked">
          <div className="role-tabs" aria-label="Filter delivery challans by status" role="tablist">
            {challanFilters.map((option) => (
              <button
                aria-selected={filter === option.value}
                className={filter === option.value ? 'role-tab role-tab--active' : 'role-tab'}
                key={option.label}
                onClick={() => setFilter(option.value)}
                role="tab"
                type="button"
              >
                {option.label}
              </button>
            ))}
          </div>
          <p className="list-toolbar-note">Status filters are served directly by the Delivery Challan API. Challan dispatch and stock deductions remain in the backend sales workflow.</p>
        </div>

        {challans.isError ? (
          <div className="directory-state directory-state--error" role="alert">
            <strong>Delivery challans could not be loaded.</strong>
            <p>Check your connection and permissions, then refresh the page.</p>
          </div>
        ) : challans.isLoading ? (
          <div aria-live="polite" className="directory-state">Loading delivery challans...</div>
        ) : challanPage?.content.length ? (
          <>
            <DataTable caption="Delivery challans">
              <thead>
                <tr>
                  <th scope="col">Challan</th>
                  <th scope="col">Customer</th>
                  <th scope="col">Challan date</th>
                  <th scope="col">Dispatch date</th>
                  <th scope="col">Sales order</th>
                  <th scope="col">Warehouse</th>
                  <th scope="col">Vehicle</th>
                  <th scope="col">Status</th>
                </tr>
              </thead>
              <tbody>
                {challanPage.content.map((challan) => (
                  <DeliveryChallanRow
                    challan={challan}
                    key={challan.id}
                    onOpen={() => navigate(appRoutes.deliveryChallanDetail(challan.id))}
                  />
                ))}
              </tbody>
            </DataTable>
            <footer className="table-footer">
              <span>Showing {challanPage.content.length} of {challanPage.totalElements} challans · Page {challanPage.page + 1} of {Math.max(challanPage.totalPages, 1)}</span>
              <div className="pagination-actions">
                <Button
                  aria-label="Previous page"
                  disabled={page === 0}
                  onClick={() => setPage((current) => Math.max(0, current - 1))}
                  variant="secondary"
                >
                  <ChevronLeft aria-hidden="true" size={16} />
                </Button>
                <Button
                  aria-label="Next page"
                  disabled={challanPage.last || page + 1 >= challanPage.totalPages}
                  onClick={() => setPage((current) => current + 1)}
                  variant="secondary"
                >
                  <ChevronRight aria-hidden="true" size={16} />
                </Button>
              </div>
            </footer>
          </>
        ) : (
          <div className="directory-state">
            <Truck aria-hidden="true" size={24} />
            <strong>No delivery challans found</strong>
            <p>Delivery challans generated from confirmed sales orders will appear here for dispatch tracking.</p>
          </div>
        )}
      </section>

      <p className="directory-note">Delivery challans record stock deduction from the source warehouse upon dispatch. Material creation and driver signature actions remain in Flutter during the parallel run.</p>
    </section>
  )
}

function DeliveryChallanRow({ challan, onOpen }: { challan: DeliveryChallan; onOpen: () => void }) {
  return (
    <tr>
      <td>
        <Button className="document-link" onClick={onOpen} variant="ghost">
          <code>{challan.challanNumber}</code>
        </Button>
      </td>
      <td>
        <div className="cell-stack">
          <strong>{challan.contactName ?? 'Walk-in / Unknown'}</strong>
          <span className="cell-muted">{challan.shippingAddress ?? '--'}</span>
        </div>
      </td>
      <td>{formatDate(challan.challanDate)}</td>
      <td>{formatDate(challan.dispatchDate)}</td>
      <td>
        {challan.salesOrderNumber ? (
          <code>{challan.salesOrderNumber}</code>
        ) : (
          <span className="cell-muted">Direct / Manual</span>
        )}
      </td>
      <td>{challan.warehouseName ?? '--'}</td>
      <td>{challan.vehicleNumber ?? (challan.deliveryMethod ?? '--')}</td>
      <td>
        <StatusChip status={formatStatusLabel(challan.status)} />
      </td>
    </tr>
  )
}
