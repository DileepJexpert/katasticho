import { useEffect, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Plus, Truck } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DataTable,
  DirectoryToolbar,
  EmptyState,
  FilterTabs,
  PageHeader,
  StatusChip,
  TablePagination,
} from '@/design-system'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import {
  listDeliveryChallans,
  type DeliveryChallan,
} from '@/features/delivery-challans/delivery-challans-api'

const challanFilters = [
  { label: 'All', value: '' },
  { label: 'Draft', value: 'DRAFT' },
  { label: 'Dispatched', value: 'DISPATCHED' },
  { label: 'Delivered', value: 'DELIVERED' },
  { label: 'Cancelled', value: 'CANCELLED' },
] as const

type ChallanFilter = typeof challanFilters[number]['value']

export function DeliveryChallansPage() {
  const [filter, setFilter] = useState<ChallanFilter>('')
  const [page, setPage] = useState(0)
  const navigate = useNavigate()

  useEffect(() => {
    setPage(0)
  }, [filter])

  const effectiveStatus = filter === '' ? undefined : filter
  const challans = useQuery({
    queryKey: ['delivery-challans', { page, status: effectiveStatus }],
    queryFn: () => listDeliveryChallans({ page, status: effectiveStatus ?? null }),
  })
  const challanPage = challans.data

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <Button onClick={() => navigate(appRoutes.deliveryChallanCreate)} variant="primary">
            <Plus aria-hidden="true" size={16} />
            <span>New Delivery Challan</span>
          </Button>
        }
        description="Warehouse dispatch notes that deduct inventory and carry goods under Rule 55 / e-Way bill."
        eyebrow="Sales / Logistics"
        title="Delivery Challans"
      />

      <section className="list-panel" aria-label="Delivery challan directory">
        <DirectoryToolbar ariaLabel="Filter delivery challans by status">
          <FilterTabs
            activeValue={filter}
            ariaLabel="Filter delivery challans by status"
            items={challanFilters}
            onChange={(val) => setFilter(val as ChallanFilter)}
          />
        </DirectoryToolbar>

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
            <TablePagination
              filterDescription={filter ? `with ${formatStatusLabel(filter).toLowerCase()} status` : 'in this organisation'}
              isFiltered={Boolean(filter)}
              itemLabel="challan"
              onPageChange={setPage}
              page={challanPage.page}
              totalElements={challanPage.totalElements}
              totalPages={challanPage.totalPages}
            />
          </>
        ) : (
          <EmptyState
            action={
              <Button onClick={() => navigate(appRoutes.deliveryChallanCreate)} variant="primary">
                <Plus aria-hidden="true" size={16} />
                <span>New Delivery Challan</span>
              </Button>
            }
            description="Create a confirmed sales order first, then use its fulfilment action to draft a delivery challan with the required order-line controls."
            icon={Truck}
            title="No delivery challans found"
          />
        )}
      </section>
    </section>
  )
}

function DeliveryChallanRow({
  challan,
  onOpen,
}: {
  challan: DeliveryChallan
  onOpen: () => void
}) {
  return (
    <tr>
      <td>
        <div className="cell-stack">
          <Button className="document-link" onClick={onOpen} variant="ghost">
            <code>{challan.challanNumber}</code>
          </Button>
          {challan.ewayBillNumber && <span>e-Way: {challan.ewayBillNumber}</span>}
        </div>
      </td>
      <td><strong>{challan.customerName ?? '--'}</strong></td>
      <td>{formatDate(challan.challanDate)}</td>
      <td>{challan.dispatchDate ? formatDate(challan.dispatchDate) : '—'}</td>
      <td>
        {challan.salesOrderNumber ? (
          <code>{challan.salesOrderNumber}</code>
        ) : (
          <span className="cell-muted">—</span>
        )}
      </td>
      <td>{challan.warehouseName ?? 'Default'}</td>
      <td>
        {challan.vehicleNumber ? (
          <code>{challan.vehicleNumber}</code>
        ) : (
          <span className="cell-muted">—</span>
        )}
      </td>
      <td><StatusChip status={formatStatusLabel(challan.status)} /></td>
    </tr>
  )
}
