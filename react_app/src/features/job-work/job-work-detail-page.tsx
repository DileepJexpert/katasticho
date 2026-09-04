import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, Send, PackageCheck, XCircle } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { FormField } from '@/design-system/form-field'
import { Modal } from '@/design-system/modal'
import { NumberInput } from '@/design-system/number-input'
import { TextInput } from '@/design-system/text-input'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import {
  getJobWorkOrder,
  sendJobWorkMaterials,
  receiveJobWorkGoods,
  cancelJobWorkOrder,
} from '@/features/job-work/job-work-api'

export function JobWorkDetailPage() {
  const { jobWorkId, id: routeId } = useParams()
  const id = jobWorkId || routeId
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const [isReceiveOpen, setIsReceiveOpen] = useState(false)
  const [receiveItemId, setReceiveItemId] = useState('')
  const [receivedQty, setReceivedQty] = useState('95')
  const [wastageQty, setWastageQty] = useState('5')

  const query = useQuery({
    queryKey: ['job-work', id],
    queryFn: () => getJobWorkOrder(id!),
    enabled: Boolean(id),
  })

  const sendMutation = useMutation({
    mutationFn: () => sendJobWorkMaterials(id!),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['job-work', id] }),
  })

  const receiveMutation = useMutation({
    mutationFn: () => receiveJobWorkGoods(id!, [{
      itemId: receiveItemId,
      receivedQty: Number(receivedQty),
      wastageQty: Number(wastageQty),
    }]),
    onSuccess: () => {
      setIsReceiveOpen(false)
      queryClient.invalidateQueries({ queryKey: ['job-work', id] })
    },
  })

  const cancelMutation = useMutation({
    mutationFn: () => cancelJobWorkOrder(id!),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['job-work', id] }),
  })

  if (!id) return <div className="directory-state">No Job Work ID provided.</div>
  if (query.isLoading) return <div className="directory-state">Loading job work order details...</div>
  if (query.isError || !query.data) {
    return (
      <div className="directory-state directory-state--error">
        <strong>Unable to load job work order.</strong>
        <Button onClick={() => navigate('/job-work')} variant="secondary">Back to job work</Button>
      </div>
    )
  }

  const document = query.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Manufacturing / Job Work (Subcontracting)"
        title={document.jobWorkNumber}
        description={`Challan 45: ${document.challanNumber || 'Pending dispatch'} · Processing Charges: `}
        actions={
          <div className="table-actions">
            {document.challanNumber && (
              <span className="status-badge status-badge--info">Challan 45: {document.challanNumber}</span>
            )}
            <StatusChip status={formatStatusLabel(document.status)} />
          </div>
        }
      />

      <div className="document-actions">
        <Button onClick={() => navigate('/job-work')} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to job work orders
        </Button>

        {document.status === 'DRAFT' && (
          <Button
            disabled={sendMutation.isPending}
            onClick={() => sendMutation.mutate()}
            variant="primary"
          >
            <Send size={16} />
            Send Materials (Dispatch Challan 45)
          </Button>
        )}

        {(document.status === 'SENT' || document.status === 'PARTIALLY_RECEIVED') && (
          <Button onClick={() => setIsReceiveOpen(true)} variant="primary">
            <PackageCheck size={16} />
            Receive Processed Goods
          </Button>
        )}

        {document.status !== 'CANCELLED' && document.status !== 'COMPLETED' && (
          <Button
            disabled={cancelMutation.isPending}
            onClick={() => cancelMutation.mutate()}
            variant="destructive"
          >
            <XCircle size={16} />
            Cancel Job Work
          </Button>
        )}
      </div>

      <div className="document-layout">
        <section className="document-card">
          <h2>Subcontracting dispatch facts</h2>
          <dl className="document-facts">
            <div className="document-fact"><dt>Job worker (Vendor)</dt><dd>{document.vendorName || document.vendorId}</dd></div>
            <div className="document-fact"><dt>Dispatch warehouse</dt><dd>{document.warehouseName || document.warehouseId}</dd></div>
            <div className="document-fact"><dt>Challan 45 number</dt><dd>{document.challanNumber || 'Pending dispatch'}</dd></div>
            <div className="document-fact"><dt>GST ITC-04 deadline</dt><dd>{document.gstReturnDeadline ? formatDate(document.gstReturnDeadline) : 'Calculated on dispatch'}</dd></div>
            <div className="document-fact"><dt>Planned timeline</dt><dd>{document.plannedSendDate ? formatDate(document.plannedSendDate) : 'Open'} â†’ {document.plannedReturnDate ? formatDate(document.plannedReturnDate) : 'Open'}</dd></div>
            <div className="document-fact"><dt>Actual timeline</dt><dd>{document.actualSendDate ? formatDate(document.actualSendDate) : 'Not dispatched'} â†’ {document.actualReturnDate ? formatDate(document.actualReturnDate) : 'Pending receipt'}</dd></div>
          </dl>
        </section>

        <aside className="document-card document-card--summary">
          <h2>Cost & Processing Summary</h2>
          <div className="progress-row">
            <span>Processing charges</span>
            <Money amount={document.processingCharges} />
          </div>
          <div className="progress-row">
            <span>Sent raw materials cost</span>
            <Money amount={document.totalMaterialCost} />
          </div>
          <div className="progress-row progress-row--total">
            <span>Total subcontracting value</span>
            <Money amount={document.totalCost} />
          </div>
        </aside>
      </div>

      <section className="document-card document-card--lines">
        <h2>Subcontracting Materials & Output Lines</h2>
        {document.lines && document.lines.length > 0 ? (
          <DataTable caption="Materials sent for processing and received finished items">
            <thead>
              <tr>
                <th scope="col">Item</th>
                <th scope="col">Type</th>
                <th className="numeric-cell" scope="col">Sent Qty</th>
                <th className="numeric-cell" scope="col">Received Qty</th>
                <th className="numeric-cell" scope="col">Wastage Qty</th>
                <th className="numeric-cell" scope="col">Unit Cost</th>
                <th scope="col">Status</th>
              </tr>
            </thead>
            <tbody>
              {document.lines.map((line) => (
                <tr key={line.id}>
                  <td><strong>{line.itemName || line.itemId}</strong></td>
                  <td>
                    <span className={line.lineType === 'MATERIAL_SENT' ? 'status-badge status-badge--warning' : 'status-badge status-badge--success'}>
                      {line.lineType}
                    </span>
                  </td>
                  <td className="numeric-cell"><Quantity value={line.sentQty} /></td>
                  <td className="numeric-cell"><Quantity value={line.receivedQty} /></td>
                  <td className="numeric-cell">{Number(line.wastageQty) > 0 ? <span className="text-danger">{line.wastageQty}</span> : '0'}</td>
                  <td className="numeric-cell"><Money amount={line.unitCost} /></td>
                  <td><StatusChip status={formatStatusLabel(line.status)} /></td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        ) : (
          <p className="cell-muted">No line items attached.</p>
        )}
      </section>

      <Modal
        isOpen={isReceiveOpen}
        onClose={() => setIsReceiveOpen(false)}
        title="Receive Processed Goods from Job Worker"
        footer={
          <>
            <Button onClick={() => setIsReceiveOpen(false)} variant="secondary">Cancel</Button>
            <Button
              disabled={receiveMutation.isPending || !receiveItemId.trim()}
              onClick={() => receiveMutation.mutate()}
              variant="primary"
            >
              Record Inward Receipt
            </Button>
          </>
        }
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
          <FormField label="Received Output Item ID" required>
            <TextInput
              onChange={(e) => setReceiveItemId(e.target.value)}
              placeholder="Processed Item UUID"
              value={receiveItemId}
            />
          </FormField>
          <FormField label="Received Good Quantity" required>
            <NumberInput
              onChange={(e) => setReceivedQty(e.target.value)}
              value={receivedQty}
            />
          </FormField>
          <FormField label="Scrap / Process Wastage">
            <NumberInput
              onChange={(e) => setWastageQty(e.target.value)}
              value={wastageQty}
            />
          </FormField>
        </div>
      </Modal>
    </section>
  )
}