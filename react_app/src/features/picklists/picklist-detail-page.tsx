import type { ReactNode } from 'react'
import { useQuery } from '@tanstack/react-query'
import { ArrowLeft, ListChecks } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import { formatDateTime, formatStatusLabel } from '@/shared/format/format'
import { getPicklist, type PicklistLine } from '@/features/picklists/picklists-api'
import { PickProgress } from '@/features/picklists/pick-progress'

export function PicklistDetailPage() {
  const { picklistId } = useParams()
  const navigate = useNavigate()
  const picklist = useQuery({
    queryKey: ['picklists', picklistId],
    queryFn: () => getPicklist(picklistId!),
    enabled: Boolean(picklistId),
  })

  if (!picklistId) return <DocumentError onBack={() => navigate(appRoutes.picklists)} />
  if (picklist.isLoading) return <section className="workspace-page"><div aria-live="polite" className="directory-state">Loading picklist...</div></section>
  if (picklist.isError || !picklist.data) return <DocumentError onBack={() => navigate(appRoutes.picklists)} />

  const document = picklist.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Inventory / Warehouse / Picklist"
        title={document.picklistNumber}
        description={`${document.warehouseName ?? 'Unknown warehouse'} · created ${formatDateTime(document.createdAt)}`}
        actions={<StatusChip status={formatStatusLabel(document.status)} />}
      />

      <div className="document-actions">
        <Button onClick={() => navigate(appRoutes.picklists)} variant="secondary"><ArrowLeft aria-hidden="true" size={16} />Back to picklists</Button>
        <StatusChip status="Read-only pilot" />
      </div>

      <div className="document-layout">
        <section className="document-card">
          <h2>Picklist information</h2>
          <dl className="document-facts">
            <Fact label="Source sales order" value={document.salesOrderNumber ? <Button className="document-link" onClick={() => navigate(appRoutes.salesOrderDetail(document.salesOrderId))} variant="ghost"><code>{document.salesOrderNumber}</code></Button> : '--'} />
            <Fact label="Warehouse" value={document.warehouseName ?? '--'} />
            <Fact label="Created" value={formatDateTime(document.createdAt)} />
            <Fact label="Started" value={formatDateTime(document.startedAt)} />
            <Fact label="Completed" value={formatDateTime(document.completedAt)} />
          </dl>
        </section>

        <aside className="document-card document-card--summary">
          <h2>Picking coverage</h2>
          <PickProgress pickedCount={document.pickedCount} totalCount={document.lineCount} />
          <div className="progress-row"><span>Lines</span><strong>{document.lineCount}</strong></div>
          <div className="progress-row"><span>Lines with quantity recorded</span><strong>{document.pickedCount}</strong></div>
          <div className="progress-row progress-row--total"><span>Status</span><StatusChip status={formatStatusLabel(document.status)} /></div>
        </aside>
      </div>

      <section className="document-card document-card--lines">
        <h2>Pick lines</h2>
        <DataTable caption="Picklist lines">
          <thead>
            <tr>
              <th scope="col">Item</th>
              <th className="numeric-cell" scope="col">Required</th>
              <th className="numeric-cell" scope="col">Picked</th>
              <th scope="col">Coverage</th>
              <th scope="col">Batch</th>
              <th scope="col">Rack</th>
              <th scope="col">Notes</th>
            </tr>
          </thead>
          <tbody>
            {document.lines.length ? document.lines.map((line) => <PicklistLineRow key={line.id} line={line} />) : <tr><td className="cell-muted" colSpan={7}>No pick lines were returned for this picklist.</td></tr>}
          </tbody>
        </DataTable>
      </section>

      <section className="document-card document-card--notes">
        <h2>Notes</h2>
        <div className="document-notes"><p>{document.notes ?? '--'}</p></div>
      </section>

      <p className="directory-note">This page reflects the existing Picklist record. Creating, starting, recording quantities, completing, and cancelling remain in Flutter during the controlled migration.</p>
    </section>
  )
}

function PicklistLineRow({ line }: { line: PicklistLine }) {
  const required = Number(line.requiredQuantity ?? 0)
  const picked = Number(line.pickedQuantity ?? 0)
  const coverage = required > 0 && picked >= required ? 'Fully picked' : picked > 0 ? 'Partially picked' : 'Not picked'

  return (
    <tr>
      <td><div className="cell-stack"><strong>{line.itemName ?? '--'}</strong><code>{line.sku ?? '--'}</code></div></td>
      <td className="numeric-cell"><Quantity value={line.requiredQuantity} /></td>
      <td className="numeric-cell"><Quantity value={line.pickedQuantity} /></td>
      <td><StatusChip status={coverage} /></td>
      <td><code>{line.batchNumber ?? '--'}</code></td>
      <td><code>{line.rackLocationCode ?? '--'}</code></td>
      <td><span className="cell-muted">{line.notes ?? '--'}</span></td>
    </tr>
  )
}

function Fact({ label, value }: { label: string; value: ReactNode }) {
  return <div><dt>{label}</dt><dd>{value}</dd></div>
}

function DocumentError({ onBack }: { onBack: () => void }) {
  return (
    <section className="workspace-page">
      <div className="directory-state directory-state--error" role="alert">
        <ListChecks aria-hidden="true" size={24} />
        <strong>Picklist details could not be loaded.</strong>
        <p>The picklist may no longer be available, or you may not have permission to view it.</p>
        <Button onClick={onBack} variant="secondary">Back to picklists</Button>
      </div>
    </section>
  )
}
