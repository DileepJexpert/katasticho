import { useEffect, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import {
  AlertTriangle,
  Boxes,
  GitFork,
} from 'lucide-react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DataTable,
  DirectoryToolbar,
  DocumentCard,
  EmptyState,
  Fact,
  FactList,
  FormField,
  FormGrid,
  EntityPicker,
  FilterTabs,
  PageHeader,
  Quantity,
  SearchInput,
  StatusChip,
} from '@/design-system'
import { formatDate, formatDateTime } from '@/shared/format/format'
import {
  getBatch,
  getBatchRecallReport,
  getBatchTraceHistory,
  listBatchesByItem,
  type BatchDetail,
  type BatchRecallReport,
  type BatchTraceRecord,
} from '@/features/inventory/batches-api'
import type { Item } from '@/features/items/items-api'
import { InventoryItemPicker } from './inventory-pickers'
import { useInventoryAccess } from './inventory-access'

function errorMessage(error: unknown, fallback: string) {
  if (error instanceof Error && error.message) return error.message
  return fallback
}

export function BatchTracePage() {
  const access = useInventoryAccess()
  const [item, setItem] = useState<Item | null>(null)
  const batches = useQuery({ queryKey: ['batches', 'by-item', item?.id], queryFn: () => listBatchesByItem(item!.id), enabled: Boolean(item) && access.operate })
  const navigate = useNavigate()
  const [searchParams, setSearchParams] = useSearchParams()
  const selectedBatchId = searchParams.get('batchId') ?? ''
  const [batchIdInput, setBatchIdInput] = useState(selectedBatchId)
  const [view, setView] = useState<'history' | 'recall'>('history')
  const isValidBatchId = isUuid(selectedBatchId)

  useEffect(() => {
    setBatchIdInput(selectedBatchId)
  }, [selectedBatchId])

  const batchQuery = useQuery({
    queryKey: ['batches', selectedBatchId],
    queryFn: () => getBatch(selectedBatchId),
    enabled: isValidBatchId && access.operate,
  })
  const historyQuery = useQuery({
    queryKey: ['batch-trace', 'history', selectedBatchId],
    queryFn: () => getBatchTraceHistory(selectedBatchId),
    enabled: isValidBatchId && view === 'history' && access.operate,
  })
  const recallQuery = useQuery({
    queryKey: ['batch-trace', 'recall', selectedBatchId],
    queryFn: () => getBatchRecallReport(selectedBatchId),
    enabled: isValidBatchId && view === 'recall' && access.operate,
  })

  function handleSearch() {
    const batchId = batchIdInput.trim()
    setSearchParams(batchId ? { batchId } : {})
  }

  if (!access.operate) return <section className="workspace-page"><PageHeader title="Batch traceability" description="The existing trace API is available to owners, admins, accountants, and operators." /></section>

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Inventory / Traceability"
        title="Batch traceability"
        description="Review immutable manufacturing batch relationships and the server-calculated recall impact for a specific batch."
        actions={<Button onClick={() => navigate(appRoutes.batches)} variant="secondary">Back to expiry watch</Button>}
      />

      <DocumentCard className="batch-trace-search" title="Select a batch">
        <FormGrid columns={2}>
          <FormField label="Find item"><InventoryItemPicker includeInactive value={item} onChange={setItem} /></FormField>
          <FormField label="Batch"><EntityPicker<BatchDetail> ariaLabel="Select batch to trace" value={null} onChange={(id) => { if (id) { setBatchIdInput(id); setSearchParams({ batchId: id }) } }} options={batches.data ?? []} getOptionId={(batch) => batch.id} getOptionLabel={(batch) => batch.batchNumber} getOptionDescription={(batch) => `Expiry ${formatDate(batch.expiryDate)} / ${batch.active ? 'Active' : 'Inactive'}`} disabled={!item || batches.isPending || batches.isError} /></FormField>
        </FormGrid>
        {batches.isError && <div role="alert">{batches.error.message}<Button variant="secondary" onClick={() => void batches.refetch()}>Retry item batches</Button></div>}
        <form onSubmit={(event) => { event.preventDefault(); handleSearch() }}>
          <DirectoryToolbar
            ariaLabel="Batch trace selection"
            actions={<Button disabled={!batchIdInput.trim()} type="submit" variant="primary">Open trace</Button>}
          >
            <SearchInput
              ariaLabel="Batch UUID"
              onChange={setBatchIdInput}
              onClear={() => setBatchIdInput('')}
              placeholder="Paste a batch UUID"
              value={batchIdInput}
            />
          </DirectoryToolbar>
        </form>
        <p className="batch-trace-search__hint">Choose an item and batch, open it from expiry watch, or paste a server-issued UUID for support. Item batch history also includes inactive or exhausted batches.</p>
      </DocumentCard>

      {!selectedBatchId ? (
        <EmptyState
          description="Open a batch from the expiry register, or paste its UUID to review manufacturing links and recall impact."
          icon={Boxes}
          title="Select a batch to start tracing"
        />
      ) : !isValidBatchId ? (
        <EmptyState
          action={<Button onClick={() => navigate(appRoutes.batches)} variant="secondary">Open expiry watch</Button>}
          className="directory-state--error"
          description="The trace API accepts a server-issued batch UUID, not a batch number."
          title="A valid batch identifier is required"
        />
      ) : (
        <>
          {batchQuery.data && (
            <DocumentCard className="batch-trace-details" title="Batch details">
              <FactList columns={4}>
                <Fact label="Batch number" mono value={batchQuery.data.batchNumber} />
                <Fact label="Expiry date" value={formatDate(batchQuery.data.expiryDate)} />
                <Fact label="Manufactured" value={formatDate(batchQuery.data.manufacturingDate)} />
                <Fact label="Status" value={<StatusChip status={batchQuery.data.active ? 'Active' : 'Inactive'} />} />
              </FactList>
            </DocumentCard>
          )}

          {batchQuery.isError && (
            <EmptyState
              action={<Button onClick={() => batchQuery.refetch()} variant="secondary">Retry</Button>}
              className="directory-state--error"
              description="The batch details could not be loaded. You can still review trace records if the identifier is valid."
              title="Batch details unavailable"
            />
          )}

          <FilterTabs
            activeValue={view}
            ariaLabel="Batch trace view"
            items={[
              { value: 'history', label: 'Relationships' },
              { value: 'recall', label: 'Recall impact' },
            ]}
            onChange={(value) => setView(value as 'history' | 'recall')}
          />

          {view === 'history' ? (
            <TraceHistoryView
              batchId={selectedBatchId}
              error={historyQuery.error}
              isError={historyQuery.isError}
              isLoading={historyQuery.isLoading}
              onRetry={() => historyQuery.refetch()}
              records={historyQuery.data}
            />
          ) : (
            <RecallReportView
              error={recallQuery.error}
              isError={recallQuery.isError}
              isLoading={recallQuery.isLoading}
              onRetry={() => recallQuery.refetch()}
              report={recallQuery.data}
            />
          )}
        </>
      )}
    </section>
  )
}

function TraceHistoryView({
  batchId,
  records,
  isLoading,
  isError,
  error,
  onRetry,
}: {
  batchId: string
  records: { backward: BatchTraceRecord[]; forward: BatchTraceRecord[] } | undefined
  isLoading: boolean
  isError: boolean
  error: unknown
  onRetry: () => void
}) {
  if (isLoading) return <div aria-live="polite" className="directory-state">Loading batch relationships...</div>
  if (isError) {
    return <EmptyState action={<Button onClick={onRetry} variant="secondary">Retry</Button>} className="directory-state--error" description={errorMessage(error, 'Check your connection and permissions, then retry.')} title="Batch relationships could not be loaded" />
  }
  const backwardRecords = records?.backward ?? []
  const forwardRecords = records?.forward ?? []
  if (!backwardRecords.length && !forwardRecords.length) {
    return <EmptyState description="No manufacturing genealogy links have been recorded for this batch." icon={GitFork} title="No batch relationships recorded" />
  }

  return (
    <div className="batch-trace-sections">
      <TraceTable batchId={batchId} description="Raw-material batches recorded as inputs to this finished-goods batch." records={backwardRecords} title="Upstream inputs" />
      <TraceTable batchId={batchId} description="Finished-goods batches that the selected raw-material batch contributed to." records={forwardRecords} title="Downstream outputs" />
    </div>
  )
}

function TraceTable({
  batchId,
  description,
  records,
  title,
}: {
  batchId: string
  description: string
  records: BatchTraceRecord[]
  title: string
}) {
  return (
    <DocumentCard title={title}>
      <p className="document-card__description">{description}</p>
      {records.length ? (
        <DataTable caption={`${title} batch genealogy records`}>
          <thead>
            <tr>
              <th scope="col">Trace type</th>
              <th scope="col">Related batch</th>
              <th scope="col">Work order</th>
              <th scope="col">Inventory movement</th>
              <th className="numeric-cell" scope="col">Quantity</th>
              <th scope="col">Recorded</th>
            </tr>
          </thead>
          <tbody>
            {records.map((record) => (
              <tr key={record.id}>
                <td><StatusChip status={record.traceType} /></td>
                <td><code>{relatedBatchId(record, batchId)}</code></td>
                <td><code>{record.workOrderId ?? '--'}</code></td>
                <td><code>{record.movementId ?? '--'}</code></td>
                <td className="numeric-cell"><Quantity value={record.quantity} /></td>
                <td>{formatDateTime(record.tracedAt)}</td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      ) : (
        <p className="document-card__empty">No records in this direction.</p>
      )}
    </DocumentCard>
  )
}

function RecallReportView({
  report,
  isLoading,
  isError,
  error,
  onRetry,
}: {
  report: BatchRecallReport | undefined
  isLoading: boolean
  isError: boolean
  error: unknown
  onRetry: () => void
}) {
  if (isLoading) return <div aria-live="polite" className="directory-state">Calculating recall impact...</div>
  if (isError) {
    return <EmptyState action={<Button onClick={onRetry} variant="secondary">Retry</Button>} className="directory-state--error" description={errorMessage(error, 'Check your connection and permissions, then retry.')} title="Recall impact could not be loaded" />
  }
  if (!report) return null

  return (
    <div className="batch-trace-sections">
      <DocumentCard className="batch-recall-summary" title="Recall impact summary">
        <p className="batch-recall-summary__notice"><AlertTriangle aria-hidden="true" size={16} /> This is a read-only impact report. Quarantine, notification, and return actions follow their existing controlled workflows.</p>
        <FactList columns={4}>
          <Fact label="Raw-material batch" mono value={report.rmBatch.batchNumber ?? report.rmBatch.batchId} />
          <Fact label="Expiry date" value={formatDate(report.rmBatch.expiryDate)} />
          <Fact label="Affected finished goods" value={report.affectedFgBatchCount} />
          <Fact label="Affected shipments" value={report.affectedShipmentCount} />
        </FactList>
      </DocumentCard>

      <DocumentCard title="Affected finished-goods batches">
        {report.affectedFgBatches.length ? (
          <DataTable caption="Finished-goods batches affected by the selected raw-material batch">
            <thead>
              <tr>
                <th scope="col">Batch</th>
                <th scope="col">Item identifier</th>
              </tr>
            </thead>
            <tbody>
              {report.affectedFgBatches.map((batch) => (
                <tr key={batch.fgBatchId}>
                  <td><code>{batch.fgBatchNumber ?? batch.fgBatchId}</code></td>
                  <td><code>{batch.fgItemId ?? '--'}</code></td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        ) : <p className="document-card__empty">No finished-goods batches are linked to this batch.</p>}
      </DocumentCard>

      <DocumentCard title="Affected shipments">
        {report.affectedShipments.length ? (
          <DataTable caption="Customer shipments affected by the selected raw-material batch">
            <thead>
              <tr>
                <th scope="col">Customer</th>
                <th scope="col">Invoice</th>
                <th scope="col">Movement date</th>
                <th className="numeric-cell" scope="col">Quantity</th>
              </tr>
            </thead>
            <tbody>
              {report.affectedShipments.map((shipment, index) => (
                <tr key={`${shipment.invoiceId ?? 'unlinked'}-${shipment.fgBatchId}-${index}`}>
                  <td>{shipment.customerName ?? '--'}</td>
                  <td><code>{shipment.invoiceNumber ?? shipment.invoiceId ?? '--'}</code></td>
                  <td>{formatDate(shipment.movementDate)}</td>
                  <td className="numeric-cell"><Quantity value={shipment.quantity} /></td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        ) : <p className="document-card__empty">No customer shipment movements are linked to this batch.</p>}
      </DocumentCard>
    </div>
  )
}

function isUuid(value: string) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)
}

function relatedBatchId(record: BatchTraceRecord, selectedBatchId: string) {
  if (record.batchId === selectedBatchId) return record.sourceBatchId ?? '--'
  if (record.sourceBatchId === selectedBatchId) return record.batchId
  return record.sourceBatchId ?? record.batchId
}
