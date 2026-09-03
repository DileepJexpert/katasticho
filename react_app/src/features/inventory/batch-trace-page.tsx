import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import {
  AlertTriangle,
  ArrowRight,
  Boxes,
  Download,
  Factory,
  FileSpreadsheet,
  GitFork,
  Search,
  Truck,
  Users,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { formatDateTime } from '@/shared/format/format'
import {
  getBatchRecallReport,
  getBatchTraceBackward,
  getBatchTraceForward,
  type BatchRecallReport,
  type BatchTraceRecord,
} from '@/features/items/items-api'

export function BatchTracePage() {
  const [batchId, setBatchId] = useState('')
  const [searchedBatchId, setSearchedBatchId] = useState('')
  const [traceDirection, setTraceDirection] = useState<'forward' | 'backward' | 'recall'>('forward')

  const forwardQuery = useQuery({
    queryKey: ['batch-trace', 'forward', searchedBatchId],
    queryFn: () => getBatchTraceForward(searchedBatchId),
    enabled: Boolean(searchedBatchId) && traceDirection === 'forward',
  })

  const backwardQuery = useQuery({
    queryKey: ['batch-trace', 'backward', searchedBatchId],
    queryFn: () => getBatchTraceBackward(searchedBatchId),
    enabled: Boolean(searchedBatchId) && traceDirection === 'backward',
  })

  const recallQuery = useQuery({
    queryKey: ['batch-trace', 'recall', searchedBatchId],
    queryFn: () => getBatchRecallReport(searchedBatchId),
    enabled: Boolean(searchedBatchId) && traceDirection === 'recall',
  })

  function handleSearch(e: React.FormEvent) {
    e.preventDefault()
    if (batchId.trim()) {
      setSearchedBatchId(batchId.trim())
    }
  }

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Inventory / Traceability"
        title="Batch Traceability & Product Recall Console"
        description="End-to-end bidirectional batch genealogy across Inbound POs, QC, Work Order WIP, Delivery Challans, Sales Invoices, and Customers."
        actions={
          searchedBatchId && traceDirection === 'recall' && recallQuery.data ? (
            <Button onClick={() => window.print()} variant="primary">
              <Download size={16} /> Export Recall Dossier
            </Button>
          ) : undefined
        }
      />

      {/* Search Bar */}
      <section className="document-card" style={{ marginBottom: '1.5rem' }}>
        <form onSubmit={handleSearch} style={{ display: 'flex', gap: '1rem', alignItems: 'flex-end' }}>
          <label className="field-group" style={{ flex: 1 }}>
            <span>Batch Number or Batch UUID</span>
            <input
              onChange={(e) => setBatchId(e.target.value)}
              placeholder="e.g. BATCH-2026-001 or UUID"
              value={batchId}
            />
          </label>
          <Button disabled={!batchId.trim()} type="submit" variant="primary">
            <Search size={16} /> Trace Batch
          </Button>
        </form>
      </section>

      {/* Mode Tabs */}
      <div className="role-tabs" role="tablist" style={{ marginBottom: '1.5rem' }}>
        <button
          className={traceDirection === 'forward' ? 'role-tab role-tab--active' : 'role-tab'}
          onClick={() => setTraceDirection('forward')}
          role="tab"
          type="button"
        >
          <ArrowRight size={16} style={{ marginRight: '0.5rem' }} />
          Forward Trace (Supplier &rarr; Customer)
        </button>
        <button
          className={traceDirection === 'backward' ? 'role-tab role-tab--active' : 'role-tab'}
          onClick={() => setTraceDirection('backward')}
          role="tab"
          type="button"
        >
          <GitFork size={16} style={{ marginRight: '0.5rem' }} />
          Backward Trace (FG &rarr; Raw Materials)
        </button>
        <button
          className={traceDirection === 'recall' ? 'role-tab role-tab--active' : 'role-tab'}
          onClick={() => setTraceDirection('recall')}
          role="tab"
          type="button"
        >
          <AlertTriangle size={16} style={{ marginRight: '0.5rem' }} />
          Product Recall Dossier
        </button>
      </div>

      {!searchedBatchId ? (
        <div className="directory-state">
          <Boxes size={32} />
          <strong>Enter a Batch Number or UUID to begin genealogical trace.</strong>
          <p>Trace forward to see where ingredients went, or backward to isolate root-cause supplier batches.</p>
        </div>
      ) : traceDirection === 'forward' ? (
        <ForwardTraceView
          isLoading={forwardQuery.isLoading}
          records={forwardQuery.data ?? []}
        />
      ) : traceDirection === 'backward' ? (
        <BackwardTraceView
          isLoading={backwardQuery.isLoading}
          records={backwardQuery.data ?? []}
        />
      ) : (
        <RecallReportView
          isLoading={recallQuery.isLoading}
          report={recallQuery.data}
        />
      )}
    </section>
  )
}

function ForwardTraceView({ records, isLoading }: { records: BatchTraceRecord[]; isLoading: boolean }) {
  if (isLoading) return <div className="directory-state">Computing forward genealogical trace...</div>
  if (!records.length) {
    return (
      <div className="directory-state">
        <Boxes size={24} />
        <strong>No forward trace events found for this batch.</strong>
      </div>
    )
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
      <DataTable caption="Forward Batch Genealogy Tree">
        <thead>
          <tr>
            <th scope="col">Step / Stage</th>
            <th scope="col">Source Document</th>
            <th scope="col">Target Destination</th>
            <th className="numeric-cell" scope="col">Quantity</th>
            <th scope="col">Contact / Entity</th>
            <th scope="col">Timestamp</th>
            <th scope="col">Notes</th>
          </tr>
        </thead>
        <tbody>
          {records.map((rec) => (
            <tr key={rec.id}>
              <td>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  {getStepIcon(rec.step)}
                  <strong>{rec.step}</strong>
                </div>
              </td>
              <td>
                <div className="cell-stack">
                  <span>{rec.sourceType}</span>
                  <code>{rec.sourceNumber ?? rec.sourceId}</code>
                </div>
              </td>
              <td>
                <div className="cell-stack">
                  <span>{rec.targetType}</span>
                  <code>{rec.targetNumber ?? rec.targetId}</code>
                </div>
              </td>
              <td className="numeric-cell"><strong>{rec.quantity}</strong></td>
              <td>{rec.contactName ?? '--'}</td>
              <td>{formatDateTime(rec.timestamp)}</td>
              <td>{rec.notes ?? '--'}</td>
            </tr>
          ))}
        </tbody>
      </DataTable>
    </div>
  )
}

function BackwardTraceView({ records, isLoading }: { records: BatchTraceRecord[]; isLoading: boolean }) {
  if (isLoading) return <div className="directory-state">Computing backward genealogical trace...</div>
  if (!records.length) {
    return (
      <div className="directory-state">
        <Boxes size={24} />
        <strong>No upstream parent batches found.</strong>
      </div>
    )
  }

  return (
    <DataTable caption="Backward Root Cause Trace">
      <thead>
        <tr>
          <th scope="col">Upstream Stage</th>
          <th scope="col">Component Batch</th>
          <th scope="col">Source Order / PO</th>
          <th className="numeric-cell" scope="col">Quantity Consumed</th>
          <th scope="col">Supplier / Work Center</th>
          <th scope="col">Date Recorded</th>
        </tr>
      </thead>
      <tbody>
        {records.map((rec) => (
          <tr key={rec.id}>
            <td>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <Factory size={16} />
                <strong>{rec.step}</strong>
              </div>
            </td>
            <td><code>{rec.batchNumber}</code></td>
            <td><code>{rec.sourceNumber ?? rec.sourceId}</code></td>
            <td className="numeric-cell"><strong>{rec.quantity}</strong></td>
            <td>{rec.contactName ?? '--'}</td>
            <td>{formatDateTime(rec.timestamp)}</td>
          </tr>
        ))}
      </tbody>
    </DataTable>
  )
}

function RecallReportView({ report, isLoading }: { report?: BatchRecallReport; isLoading: boolean }) {
  if (isLoading) return <div className="directory-state">Generating Product Recall Dossier...</div>
  if (!report) {
    return (
      <div className="directory-state">
        <AlertTriangle size={24} />
        <strong>No recall records found for raw material batch.</strong>
      </div>
    )
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
      <section className="document-card" style={{ borderLeft: '4px solid var(--color-danger, #d32f2f)' }}>
        <h3 style={{ color: 'var(--color-danger, #d32f2f)' }}>Regulatory Product Recall Notice</h3>
        <p>
          Raw Material Batch: <code>{report.rmBatchNumber || report.rmBatchId}</code>
        </p>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1rem', marginTop: '1rem' }}>
          <div className="fact-item">
            <dt>Derived FG Batches</dt>
            <dd><strong>{report.finishedGoodsBatches.length} batches</strong></dd>
          </div>
          <div className="fact-item">
            <dt>Affected Invoices / Shipments</dt>
            <dd><strong>{report.customerShipments.length} dispatches</strong></dd>
          </div>
        </div>
      </section>

      <section className="document-card">
        <h4>Finished Goods Batches Produced</h4>
        <DataTable caption="Finished Goods Batches">
          <thead>
            <tr>
              <th scope="col">FG Batch Number</th>
              <th scope="col">Work Order</th>
              <th className="numeric-cell" scope="col">Quantity Produced</th>
            </tr>
          </thead>
          <tbody>
            {report.finishedGoodsBatches.map((fg) => (
              <tr key={fg.fgBatchId}>
                <td><code>{fg.fgBatchNumber}</code></td>
                <td><code>{fg.workOrderId}</code></td>
                <td className="numeric-cell"><strong>{fg.quantityProduced}</strong></td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      </section>

      <section className="document-card">
        <h4>Customer Recall Contact List</h4>
        <DataTable caption="Affected Customer Shipments">
          <thead>
            <tr>
              <th scope="col">Customer</th>
              <th scope="col">Invoice #</th>
              <th scope="col">Invoice Date</th>
              <th scope="col">Delivery Challan</th>
              <th className="numeric-cell" scope="col">Quantity Shipped</th>
              <th scope="col">Contact Phone</th>
              <th scope="col">Contact Email</th>
            </tr>
          </thead>
          <tbody>
            {report.customerShipments.map((cs) => (
              <tr key={cs.invoiceId}>
                <td><strong>{cs.customerName}</strong></td>
                <td><code>{cs.invoiceNumber}</code></td>
                <td>{cs.invoiceDate}</td>
                <td><code>{cs.deliveryChallanNumber ?? '--'}</code></td>
                <td className="numeric-cell"><strong>{cs.quantityShipped}</strong></td>
                <td>{cs.customerPhone ?? '--'}</td>
                <td>{cs.customerEmail ?? '--'}</td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      </section>
    </div>
  )
}

function getStepIcon(step: string) {
  if (step.includes('PURCHASE') || step.includes('RECEIPT')) return <Truck size={16} />
  if (step.includes('WORK_ORDER') || step.includes('PRODUCTION')) return <Factory size={16} />
  if (step.includes('INVOICE') || step.includes('SALE') || step.includes('DELIVERY')) return <Users size={16} />
  return <FileSpreadsheet size={16} />
}