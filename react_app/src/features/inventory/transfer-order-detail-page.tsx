import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, ArrowLeftRight, CheckCircle2, Send, XCircle } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DataTable,
  DocumentCard,
  DocumentError,
  Fact,
  FactList,
  Modal,
  PageHeader,
  Quantity,
  StatusChip,
  SummaryRow,
} from '@/design-system'
import { formatDate, formatDateTime, formatStatusLabel } from '@/shared/format/format'
import {
  cancelTransferOrder,
  getTransferOrder,
  receiveTransferOrder,
  shipTransferOrder,
  type TransferOrder,
} from './transfer-orders-api'

type PendingAction = 'ship' | 'receive' | 'cancel' | null

function errorMessage(error: unknown, fallback: string) {
  return error instanceof Error && error.message ? error.message : fallback
}

export function TransferOrderDetailPage() {
  const { transferOrderId } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [pendingAction, setPendingAction] = useState<PendingAction>(null)
  const [actionError, setActionError] = useState<string | null>(null)
  const transfer = useQuery({
    queryKey: ['transfer-orders', transferOrderId],
    queryFn: () => getTransferOrder(transferOrderId!),
    enabled: Boolean(transferOrderId),
  })

  function refreshTransfer() {
    queryClient.invalidateQueries({ queryKey: ['transfer-orders', transferOrderId] })
    queryClient.invalidateQueries({ queryKey: ['transfer-orders'] })
  }

  const shipMutation = useMutation({
    mutationFn: () => shipTransferOrder(transferOrderId!),
    onSuccess: () => {
      setPendingAction(null)
      setActionError(null)
      refreshTransfer()
    },
    onError: (error) => setActionError(errorMessage(error, 'The transfer order could not be dispatched.')),
  })
  const receiveMutation = useMutation({
    mutationFn: () => receiveTransferOrder(transferOrderId!),
    onSuccess: () => {
      setPendingAction(null)
      setActionError(null)
      refreshTransfer()
    },
    onError: (error) => setActionError(errorMessage(error, 'The transfer order could not be received.')),
  })
  const cancelMutation = useMutation({
    mutationFn: () => cancelTransferOrder(transferOrderId!),
    onSuccess: () => {
      setPendingAction(null)
      setActionError(null)
      refreshTransfer()
    },
    onError: (error) => setActionError(errorMessage(error, 'The transfer order could not be cancelled.')),
  })

  if (!transferOrderId) {
    return <DocumentError backLabel="Back to transfers" message="A transfer order identifier is required." onBack={() => navigate(appRoutes.transferOrders)} title="Transfer order not found" />
  }
  if (transfer.isLoading) {
    return <section className="workspace-page"><div aria-live="polite" className="directory-state">Loading transfer order...</div></section>
  }
  if (transfer.isError || !transfer.data) {
    return <DocumentError backLabel="Back to transfers" message={errorMessage(transfer.error, 'The requested transfer order could not be loaded.')} onBack={() => navigate(appRoutes.transferOrders)} title="Transfer order not found" />
  }

  const document = transfer.data
  const isDraft = document.status === 'DRAFT'
  const isInTransit = document.status === 'IN_TRANSIT'
  const mutationPending = shipMutation.isPending || receiveMutation.isPending || cancelMutation.isPending
  const action = actionContent(document, pendingAction)

  function openAction(nextAction: Exclude<PendingAction, null>) {
    setActionError(null)
    setPendingAction(nextAction)
  }

  function confirmAction() {
    if (pendingAction === 'ship') shipMutation.mutate()
    if (pendingAction === 'receive') receiveMutation.mutate()
    if (pendingAction === 'cancel') cancelMutation.mutate()
  }

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <>
            <StatusChip status={formatStatusLabel(document.status)} />
            {isDraft && <Button disabled={mutationPending} onClick={() => openAction('ship')} variant="primary"><Send aria-hidden="true" size={16} /> Dispatch transfer</Button>}
            {isInTransit && <Button disabled={mutationPending} onClick={() => openAction('receive')} variant="primary"><CheckCircle2 aria-hidden="true" size={16} /> Receive transfer</Button>}
            {(isDraft || isInTransit) && <Button disabled={mutationPending} onClick={() => openAction('cancel')} variant="destructive"><XCircle aria-hidden="true" size={16} /> Cancel</Button>}
          </>
        }
        description={`${document.fromWarehouseName ?? document.fromWarehouseId} to ${document.toWarehouseName ?? document.toWarehouseId} · ${formatDate(document.transferDate)}`}
        eyebrow="Inventory / Warehouse Transfers"
        title={document.transferNumber}
      />

      <div className="document-actions">
        <Button onClick={() => navigate(appRoutes.transferOrders)} variant="secondary"><ArrowLeft aria-hidden="true" size={16} /> Back to transfers</Button>
      </div>

      <div className="document-layout">
        <DocumentCard title="Transfer information">
          <FactList columns={2}>
            <Fact label="Source warehouse" value={document.fromWarehouseName ?? document.fromWarehouseId} />
            <Fact label="Destination warehouse" value={document.toWarehouseName ?? document.toWarehouseId} />
            <Fact label="Transfer date" value={formatDate(document.transferDate)} />
            <Fact label="Status" value={formatStatusLabel(document.status)} />
            <Fact label="Dispatched" value={formatDateTime(document.shippedAt)} />
            <Fact label="Received" value={formatDateTime(document.receivedAt)} />
            <Fact className="field-group--span-full" label="Notes" value={document.notes ?? 'Not recorded'} />
          </FactList>
        </DocumentCard>

        <DocumentCard title="Movement summary" variant="summary">
          <SummaryRow label="Transfer lines" value={<Quantity value={document.lineCount} />} />
          <SummaryRow isTotal label="Lifecycle" value={lifecycleText(document.status)} />
        </DocumentCard>
      </div>

      <DocumentCard title="Transfer lines" variant="lines">
        <DataTable caption="Transfer order item lines">
          <thead>
            <tr>
              <th scope="col">Item</th>
              <th scope="col">Batch</th>
              <th className="numeric-cell" scope="col">Transfer quantity</th>
              {document.status === 'RECEIVED' && <th className="numeric-cell" scope="col">Received quantity</th>}
              <th scope="col">Line note</th>
            </tr>
          </thead>
          <tbody>
            {document.lines.map((line) => (
              <tr key={line.id}>
                <td>
                  <div className="item-primary">
                    <span aria-hidden="true" className="item-avatar"><ArrowLeftRight size={15} /></span>
                    <div className="cell-stack"><strong>{line.itemName ?? line.itemId}</strong><code>{line.sku ?? line.itemId}</code></div>
                  </div>
                </td>
                <td><code>{line.batchNumber ?? '--'}</code></td>
                <td className="numeric-cell"><Quantity value={line.quantity} /></td>
                {document.status === 'RECEIVED' && <td className="numeric-cell"><Quantity value={line.receivedQuantity} /></td>}
                <td>{line.notes ?? '--'}</td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      </DocumentCard>

      <Modal
        description={action.description}
        error={actionError}
        footer={<><Button disabled={mutationPending} onClick={() => setPendingAction(null)} variant="secondary">Keep transfer unchanged</Button><Button loading={mutationPending} onClick={confirmAction} variant={pendingAction === 'cancel' ? 'destructive' : 'primary'}>{action.confirmLabel}</Button></>}
        isOpen={pendingAction !== null}
        onClose={() => !mutationPending && setPendingAction(null)}
        size="sm"
        title={action.title}
      >
        <p>{action.detail}</p>
      </Modal>
    </section>
  )
}

function lifecycleText(status: TransferOrder['status']) {
  if (status === 'DRAFT') return 'Awaiting dispatch'
  if (status === 'IN_TRANSIT') return 'Stock left source; awaiting receipt'
  if (status === 'RECEIVED') return 'Received into destination stock'
  return 'Cancelled'
}

function actionContent(document: TransferOrder, action: PendingAction) {
  if (action === 'ship') {
    return {
      title: 'Dispatch this transfer?',
      description: 'Dispatch validates available source stock and records immutable transfer-out movements.',
      detail: `${document.lineCount} line${document.lineCount === 1 ? '' : 's'} will leave ${document.fromWarehouseName ?? 'the source warehouse'} and the order will move to In Transit.`,
      confirmLabel: 'Dispatch transfer',
    }
  }
  if (action === 'receive') {
    return {
      title: 'Receive this transfer?',
      description: 'Receipt records the dispatched quantities at the destination using the original transfer cost.',
      detail: `${document.lineCount} line${document.lineCount === 1 ? '' : 's'} will be added to ${document.toWarehouseName ?? 'the destination warehouse'}. The received quantities cannot be edited through this workflow.`,
      confirmLabel: 'Receive transfer',
    }
  }
  if (document.status === 'IN_TRANSIT') {
    return {
      title: 'Cancel in-transit transfer?',
      description: 'Cancellation reverses the existing transfer-out movements and returns stock to the source warehouse.',
      detail: 'This is the correction path for an in-transit transfer. A received transfer cannot be cancelled.',
      confirmLabel: 'Cancel transfer',
    }
  }
  return {
    title: 'Cancel draft transfer?',
    description: 'Cancelling a draft ends the transfer before any inventory movement has been recorded.',
    detail: 'No source or destination stock will change.',
    confirmLabel: 'Cancel transfer',
  }
}
