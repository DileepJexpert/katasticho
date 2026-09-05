import { useState } from 'react'
import { useInventoryAccess } from './inventory-access'
import { useQuery } from '@tanstack/react-query'
import { ArrowLeftRight, Plus } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DataTable,
  EmptyState,
  PageHeader,
  StatusChip,
  TablePagination,
} from '@/design-system'
import { formatDate, formatQuantity, formatStatusLabel } from '@/shared/format/format'
import { listTransferOrders, type TransferOrder } from './transfer-orders-api'

function errorMessage(error: unknown, fallback: string) {
  return error instanceof Error && error.message ? error.message : fallback
}

export function TransferOrdersPage() {
  const access = useInventoryAccess()
  const [page, setPage] = useState(0)
  const navigate = useNavigate()
  const transfers = useQuery({
    queryKey: ['transfer-orders', { page }],
    queryFn: () => listTransferOrders(page),
  })
  const transferPage = transfers.data

  return (
    <section className="workspace-page">
      <PageHeader
        actions={access.operate && <Button onClick={() => navigate(appRoutes.transferOrderCreate)} variant="primary"><Plus aria-hidden="true" size={16} /> New transfer</Button>}
        description="Create controlled warehouse-to-warehouse movements. Stock leaves the source only on dispatch and arrives at the destination only on receipt."
        eyebrow="Inventory / Warehouse Transfers"
        title="Transfer Orders"
      />

      <section aria-label="Transfer order directory" className="list-panel">
        {transfers.isError ? (
          <EmptyState
            action={<Button onClick={() => transfers.refetch()} variant="secondary">Retry</Button>}
            className="directory-state--error"
            description={errorMessage(transfers.error, 'Check your connection and permissions, then try again.')}
            title="Transfer orders could not be loaded"
          />
        ) : transfers.isLoading ? (
          <div aria-live="polite" className="directory-state">Loading transfer orders...</div>
        ) : transferPage?.content.length ? (
          <>
            <DataTable caption="Warehouse transfer order register">
              <thead>
                <tr>
                  <th scope="col">Transfer #</th>
                  <th scope="col">Transfer date</th>
                  <th scope="col">Source warehouse</th>
                  <th scope="col">Destination warehouse</th>
                  <th className="numeric-cell" scope="col">Lines</th>
                  <th scope="col">Status</th>
                  <th scope="col"><span className="visually-hidden">Actions</span></th>
                </tr>
              </thead>
              <tbody>
                {transferPage.content.map((transfer) => (
                  <TransferOrderRow
                    key={transfer.id}
                    onOpen={() => navigate(appRoutes.transferOrderDetail(transfer.id))}
                    transfer={transfer}
                  />
                ))}
              </tbody>
            </DataTable>
            <TablePagination
              itemLabel="transfer order"
              onPageChange={setPage}
              page={transferPage.page}
              totalElements={transferPage.totalElements}
              totalPages={transferPage.totalPages}
            />
          </>
        ) : (
          <EmptyState
            action={access.operate ? <Button onClick={() => navigate(appRoutes.transferOrderCreate)} variant="secondary">Create transfer</Button> : undefined}
            description="Create a draft to move stock between two warehouses, then dispatch and receive it through the controlled lifecycle."
            icon={ArrowLeftRight}
            title="No transfer orders recorded"
          />
        )}
      </section>
    </section>
  )
}

function TransferOrderRow({ onOpen, transfer }: { onOpen: () => void; transfer: TransferOrder }) {
  return (
    <tr>
      <td>
        <div className="item-primary">
          <span aria-hidden="true" className="item-avatar"><ArrowLeftRight size={15} /></span>
          <strong>{transfer.transferNumber}</strong>
        </div>
      </td>
      <td>{formatDate(transfer.transferDate)}</td>
      <td>{transfer.fromWarehouseName ?? transfer.fromWarehouseId}</td>
      <td>{transfer.toWarehouseName ?? transfer.toWarehouseId}</td>
      <td className="numeric-cell">{formatQuantity(transfer.lineCount)}</td>
      <td><StatusChip status={formatStatusLabel(transfer.status)} /></td>
      <td><Button onClick={onOpen} variant="ghost">Open</Button></td>
    </tr>
  )
}
