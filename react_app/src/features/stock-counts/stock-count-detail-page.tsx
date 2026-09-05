import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, CheckCircle2, ClipboardCheck, XCircle } from 'lucide-react'
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
import { formatDate, formatDateTime, formatQuantity, formatStatusLabel } from '@/shared/format/format'
import { useInventoryAccess } from '@/features/inventory/inventory-access'
import { invalidateInventoryQueries } from '@/features/inventory/inventory-cache'
import {
  cancelStockCount,
  getStockCount,
  postStockCount,
} from '@/features/stock-counts/stock-counts-api'

type PendingAction = 'post' | 'cancel' | null

function errorMessage(error: unknown, fallback: string) {
  return error instanceof Error && error.message ? error.message : fallback
}

export function StockCountDetailPage() {
  const access = useInventoryAccess()
  const { countId } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [pendingAction, setPendingAction] = useState<PendingAction>(null)
  const [actionError, setActionError] = useState<string | null>(null)

  const count = useQuery({
    queryKey: ['stock-counts', countId],
    queryFn: () => getStockCount(countId!),
    enabled: Boolean(countId),
  })

  function refreshCount() {
    void invalidateInventoryQueries(queryClient)
    queryClient.invalidateQueries({ queryKey: ['stock-counts', countId] })
    queryClient.invalidateQueries({ queryKey: ['stock-counts'] })
  }

  const postMutation = useMutation({
    mutationFn: () => postStockCount(countId!),
    onSuccess: () => {
      setPendingAction(null)
      setActionError(null)
      refreshCount()
    },
    onError: (error) => setActionError(errorMessage(error, 'The stock count could not be posted.')),
  })
  const cancelMutation = useMutation({
    mutationFn: () => cancelStockCount(countId!),
    onSuccess: () => {
      setPendingAction(null)
      setActionError(null)
      refreshCount()
    },
    onError: (error) => setActionError(errorMessage(error, 'The stock count could not be cancelled.')),
  })

  if (!countId) {
    return <DocumentError backLabel="Back to stock counts" message="A stock count identifier is required." onBack={() => navigate(appRoutes.stockCounts)} title="Stock count not found" />
  }
  if (count.isLoading) {
    return <section className="workspace-page"><div aria-live="polite" className="directory-state">Loading stock count...</div></section>
  }
  if (count.isError || !count.data) {
    return <DocumentError backLabel="Back to stock counts" message={errorMessage(count.error, 'The requested stock count could not be loaded.')} onBack={() => navigate(appRoutes.stockCounts)} title="Stock count not found" />
  }

  const document = count.data
  const isDraft = document.status === 'DRAFT' && access.manage
  const mutationPending = postMutation.isPending || cancelMutation.isPending
  const actionTitle = pendingAction === 'post' ? 'Post stock count adjustments?' : 'Cancel draft stock count?'
  const actionDescription = pendingAction === 'post'
    ? 'This records immutable STOCK_COUNT inventory movements for every variance. Correct a posted count with a new count; it cannot be edited or reposted.'
    : 'Cancelling ends this draft without recording any inventory movement. This cannot be undone.'

  function openAction(action: Exclude<PendingAction, null>) {
    if (!access.manage) return
    setActionError(null)
    setPendingAction(action)
  }

  return (
    <section className="workspace-page">
      <PageHeader
        actions={<><StatusChip status={formatStatusLabel(document.status)} />{isDraft && <Button disabled={mutationPending} onClick={() => openAction('post')} variant="primary"><CheckCircle2 size={16} /> Post adjustments</Button>}{isDraft && <Button disabled={mutationPending} onClick={() => openAction('cancel')} variant="destructive"><XCircle size={16} /> Cancel draft</Button>}</>}
        description={`${document.warehouseName ?? document.warehouseId} · Counted ${formatDate(document.countDate)}`}
        eyebrow="Inventory / Audits / Stock Count"
        title={document.countNumber}
      />

      <div className="document-actions">
        <Button onClick={() => navigate(appRoutes.stockCounts)} variant="secondary"><ArrowLeft aria-hidden="true" size={16} /> Back to stock counts</Button>
      </div>
      {document.status === 'DRAFT' && <p className="banner">This count API records item-level quantities only. A variance on a batch-tracked item cannot be posted because the API has no batch field.</p>}

      <div className="document-layout">
        <DocumentCard title="Count information">
          <FactList columns={2}>
            <Fact label="Warehouse" value={document.warehouseName ?? document.warehouseId} />
            <Fact label="Count date" value={formatDate(document.countDate)} />
            <Fact label="Created" value={formatDateTime(document.createdAt)} />
            <Fact label="Posted" value={formatDateTime(document.postedAt)} />
            <Fact label="Status" value={formatStatusLabel(document.status)} />
            <Fact label="Notes" value={document.notes ?? 'Not recorded'} />
          </FactList>
        </DocumentCard>

        <DocumentCard title="Variance summary" variant="summary">
          <SummaryRow label="Count lines" value={<Quantity value={document.lineCount} />} />
          <SummaryRow label="Lines with variance" value={<Quantity value={document.varianceCount} />} />
          <p className="cell-muted">Quantities are reviewed per item; different units are not combined into a net quantity.</p>
        </DocumentCard>
      </div>

      <DocumentCard title="System and physical quantities" variant="lines">
        <DataTable caption="Stock count lines">
          <thead>
            <tr>
              <th scope="col">Item</th>
              <th className="numeric-cell" scope="col">System quantity</th>
              <th className="numeric-cell" scope="col">Physical quantity</th>
              <th className="numeric-cell" scope="col">Variance</th>
              <th scope="col">Count note</th>
            </tr>
          </thead>
          <tbody>
            {document.lines.map((line) => {
              const variance = Number(line.variance)
              return (
                <tr key={line.id}>
                  <td>
                    <div className="item-primary">
                      <span aria-hidden="true" className="item-avatar"><ClipboardCheck size={15} /></span>
                      <div className="cell-stack"><strong>{line.itemName ?? line.itemId}</strong><code>{line.sku ?? line.itemId}</code></div>
                    </div>
                  </td>
                  <td className="numeric-cell"><Quantity value={line.expectedQuantity} /></td>
                  <td className="numeric-cell"><Quantity value={line.countedQuantity} /></td>
                  <td className="numeric-cell"><strong>{variance > 0 ? '+' : ''}{formatQuantity(line.variance)}</strong></td>
                  <td>{line.notes ?? '--'}</td>
                </tr>
              )
            })}
          </tbody>
        </DataTable>
      </DocumentCard>

      <Modal
        description={actionDescription}
        error={actionError}
        footer={<><Button disabled={mutationPending} onClick={() => setPendingAction(null)} variant="secondary">Keep draft</Button><Button disabled={!access.manage} loading={mutationPending} onClick={() => { if (access.manage && !mutationPending && pendingAction) { if (pendingAction === 'post') postMutation.mutate(); else cancelMutation.mutate() } }} variant={pendingAction === 'post' ? 'primary' : 'destructive'}>{pendingAction === 'post' ? 'Post adjustments' : 'Cancel draft'}</Button></>}
        isOpen={pendingAction !== null}
        onClose={() => !mutationPending && setPendingAction(null)}
        size="sm"
        title={actionTitle}
      >
        <p>{pendingAction === 'post' ? `${document.varianceCount} line${document.varianceCount === 1 ? '' : 's'} will create stock adjustment movements.` : 'No inventory movements have been created for this draft.'}</p>
      </Modal>
    </section>
  )
}
