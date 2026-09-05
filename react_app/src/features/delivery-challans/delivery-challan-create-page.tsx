import { useEffect, useMemo, useRef, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, FileCheck, Save } from 'lucide-react'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  CheckboxInput,
  DataTable,
  DocumentError,
  EmptyState,
  FormCard,
  FormField,
  FormGrid,
  NumberInput,
  PageHeader,
  Quantity,
  TextAreaInput,
  TextInput,
} from '@/design-system'
import {
  createDeliveryChallan,
  type CreateDeliveryChallanLineRequest,
} from '@/features/delivery-challans/delivery-challans-api'
import { BatchAllocationPicker } from '@/features/inventory/batch-allocation-picker'
import { getSalesOrder } from '@/features/sales-orders/sales-orders-api'

type ShippableLine = {
  soLineId: string
  itemId: string | null
  itemName: string
  description: string
  orderedQuantity: number
  shippedQuantity: number
  backorderedQuantity: number
  shippableQuantity: number
  shipQuantity: number
  unit: string | null
  batchId?: string
  included: boolean
}

export function DeliveryChallanCreatePage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [searchParams] = useSearchParams()
  const salesOrderId = searchParams.get('salesOrderId')
  const [challanDate, setChallanDate] = useState(() => new Date().toISOString().split('T')[0] || '')
  const [deliveryMethod, setDeliveryMethod] = useState('')
  const [vehicleNumber, setVehicleNumber] = useState('')
  const [trackingNumber, setTrackingNumber] = useState('')
  const [shippingAddress, setShippingAddress] = useState('')
  const [notes, setNotes] = useState('')
  const [shipLines, setShipLines] = useState<ShippableLine[]>([])
  const [feedback, setFeedback] = useState<string | null>(null)
  const populatedOrderId = useRef<string | null>(null)
  const salesOrder = useQuery({
    queryKey: ['sales-orders', salesOrderId, 'dispatch-draft'],
    queryFn: () => getSalesOrder(salesOrderId!),
    enabled: Boolean(salesOrderId),
  })

  useEffect(() => {
    if (!salesOrder.data) return
    if (populatedOrderId.current === salesOrder.data.id) return
    populatedOrderId.current = salesOrder.data.id
    setDeliveryMethod(salesOrder.data.deliveryMethod ?? '')
    setShippingAddress(salesOrder.data.shippingAddress ?? '')
    setShipLines(salesOrder.data.lines.map((line) => {
      const orderedQuantity = Number(line.quantity) || 0
      const shippedQuantity = Number(line.quantityShipped) || 0
      const backorderedQuantity = Number(line.quantityBackordered) || 0
      const shippableQuantity = Math.max(0, orderedQuantity - shippedQuantity - backorderedQuantity)
      return {
        soLineId: line.id,
        itemId: line.itemId,
        itemName: line.itemName ?? line.description ?? 'Order line',
        description: line.description ?? '',
        orderedQuantity,
        shippedQuantity,
        backorderedQuantity,
        shippableQuantity,
        shipQuantity: shippableQuantity,
        unit: line.unit,
        included: shippableQuantity > 0,
      }
    }))
  }, [salesOrder.data])

  const updateLine = (soLineId: string, updates: Partial<ShippableLine>) => {
    setShipLines((previous) => previous.map((line) => line.soLineId === soLineId ? { ...line, ...updates } : line))
  }

  const totalShipQuantity = useMemo(
    () => shipLines.filter((line) => line.included).reduce((total, line) => total + line.shipQuantity, 0),
    [shipLines],
  )

  const createMutation = useMutation({
    mutationFn: (lines: CreateDeliveryChallanLineRequest[]) => createDeliveryChallan({
      salesOrderId: salesOrderId!,
      challanDate,
      deliveryMethod: deliveryMethod.trim() || undefined,
      vehicleNumber: vehicleNumber.trim() || undefined,
      trackingNumber: trackingNumber.trim() || undefined,
      shippingAddress: shippingAddress.trim() || undefined,
      notes: notes.trim() || undefined,
      lines,
    }),
    onSuccess: (created) => {
      queryClient.invalidateQueries({ queryKey: ['delivery-challans'] })
      queryClient.invalidateQueries({ queryKey: ['sales-orders', salesOrderId] })
      navigate(appRoutes.deliveryChallanDetail(created.id))
    },
    onError: (error: Error) => setFeedback(error.message),
  })

  if (!salesOrderId) {
    return (
      <section className="workspace-page">
        <PageHeader eyebrow="Sales / Fulfilment" title="New delivery challan" description="A delivery challan must originate from a confirmed sales order so quantities, stock reservations, and audit links stay intact." />
        <EmptyState action={<Button onClick={() => navigate(appRoutes.salesOrders)} variant="primary">Open sales orders</Button>} icon={FileCheck} title="Choose a sales order first" description="Open an eligible sales order and select Create delivery challan from its fulfilment actions." />
      </section>
    )
  }
  if (salesOrder.isLoading) return <section className="workspace-page"><div aria-live="polite" className="directory-state">Loading sales order for dispatch...</div></section>
  if (salesOrder.isError || !salesOrder.data) return <DocumentError onBack={() => navigate(appRoutes.deliveryChallans)} />

  const sourceOrder = salesOrder.data
  const sourceIsEligible = ['CONFIRMED', 'PARTIALLY_SHIPPED', 'BACKORDER'].includes(sourceOrder.status)

  const handleSubmit = (event: React.FormEvent) => {
    event.preventDefault()
    setFeedback(null)
    if (!sourceIsEligible) {
      setFeedback('This sales order is no longer eligible for a delivery challan. Refresh the order and review its status.')
      return
    }
    const lines = shipLines
      .filter((line) => line.included && line.shipQuantity > 0)
      .map((line) => ({
        soLineId: line.soLineId,
        quantity: line.shipQuantity,
        batchId: line.batchId || undefined,
      }))
    if (!lines.length) {
      setFeedback('Include at least one shippable line with a quantity greater than zero.')
      return
    }
    if (lines.some((line) => line.quantity > (shipLines.find((entry) => entry.soLineId === line.soLineId)?.shippableQuantity ?? 0))) {
      setFeedback('A dispatch quantity exceeds the unshipped quantity on its sales order line.')
      return
    }
    createMutation.mutate(lines)
  }

  return (
    <section className="workspace-page">
      <Link className="form-back-link" to={appRoutes.salesOrderDetail(sourceOrder.id)}><ArrowLeft size={16} /> Back to sales order</Link>
      <PageHeader eyebrow="Sales / Fulfilment" title="New delivery challan" description="Create a dispatch draft from this order. Inventory moves only when the draft is dispatched." />
      {feedback ? <div className="banner banner--error" role="alert">{feedback}</div> : null}

      <form className="create-form-container" onSubmit={handleSubmit}>
        <FormCard description="This source is locked to retain the sales-order line references required for quantity controls and invoice conversion." stepNumber={1} title="Source order">
          <FormGrid columns={3}>
            <FormField label="Sales order"><TextInput readOnly value={sourceOrder.salesOrderNumber} /></FormField>
            <FormField label="Customer"><TextInput readOnly value={sourceOrder.contactName ?? '--'} /></FormField>
            <FormField label="Order status"><TextInput readOnly value={sourceOrder.status} /></FormField>
            <FormField label="Challan date" required><TextInput onChange={(event) => setChallanDate(event.target.value)} required type="date" value={challanDate} /></FormField>
            <FormField label="Delivery method"><TextInput onChange={(event) => setDeliveryMethod(event.target.value)} placeholder="Road, courier, pickup" value={deliveryMethod} /></FormField>
            <FormField label="Vehicle number"><TextInput onChange={(event) => setVehicleNumber(event.target.value)} placeholder="e.g. UP32 AB 1234" value={vehicleNumber} /></FormField>
            <FormField label="Carrier tracking or LR number"><TextInput onChange={(event) => setTrackingNumber(event.target.value)} placeholder="e.g. LR-90821" value={trackingNumber} /></FormField>
          </FormGrid>
        </FormCard>

        <FormCard description="Draft the quantities to ship. The backend will re-check current stock and prevents over-dispatch when you dispatch this challan." stepNumber={2} title={`Dispatch lines (${shipLines.filter((line) => line.included).length})`}>
          {shipLines.length ? (
            <DataTable caption="Delivery challan lines">
              <thead><tr><th scope="col">Ship</th><th scope="col">Item</th><th className="numeric-cell" scope="col">Ordered</th><th className="numeric-cell" scope="col">Already shipped</th><th className="numeric-cell" scope="col">Available to ship</th><th className="numeric-cell" scope="col">This challan</th><th scope="col">Batch allocation</th></tr></thead>
              <tbody>
                {shipLines.map((line) => (
                  <tr key={line.soLineId}>
                    <td><CheckboxInput aria-label={`Ship ${line.itemName}`} checked={line.included} disabled={line.shippableQuantity === 0} onChange={(event) => updateLine(line.soLineId, { included: event.target.checked })} /></td>
                    <td><div className="cell-stack"><strong>{line.itemName}</strong>{line.description && line.description !== line.itemName ? <span className="cell-muted">{line.description}</span> : null}</div></td>
                    <td className="numeric-cell"><Quantity unit={line.unit} value={line.orderedQuantity} /></td>
                    <td className="numeric-cell"><Quantity unit={line.unit} value={line.shippedQuantity} /></td>
                    <td className="numeric-cell"><Quantity unit={line.unit} value={line.shippableQuantity} /></td>
                    <td className="numeric-cell"><NumberInput disabled={!line.included} max={line.shippableQuantity} min={0.001} onChange={(event) => updateLine(line.soLineId, { shipQuantity: Math.min(line.shippableQuantity, Number(event.target.value) || 0) })} step="0.001" value={line.shipQuantity} /></td>
                    <td><BatchAllocationPicker disabled={!line.included || createMutation.isPending} itemId={line.itemId} warehouseId={sourceOrder.warehouseId} warehouseName={sourceOrder.warehouseName} quantity={line.shipQuantity} onChange={(batchId) => updateLine(line.soLineId, { batchId })} value={line.batchId ?? null} /></td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          ) : <div className="directory-state"><FileCheck size={28} /><p>No remaining order quantity is available to ship on this sales order.</p></div>}
          <div className="form-summary-card"><div className="form-summary-row form-summary-row--total"><span>Total quantity in this challan</span><Quantity value={totalShipQuantity} /></div></div>
        </FormCard>

        <FormCard description="Capture transport and recipient instructions before dispatch. These fields remain part of the delivery audit trail." stepNumber={3} title="Delivery notes">
          <FormGrid columns={2}>
            <FormField label="Shipping address"><TextAreaInput onChange={(event) => setShippingAddress(event.target.value)} placeholder="Recipient delivery address" rows={3} value={shippingAddress} /></FormField>
            <FormField label="Dispatch notes"><TextAreaInput onChange={(event) => setNotes(event.target.value)} placeholder="Packaging, delivery, or handling remarks" rows={3} value={notes} /></FormField>
          </FormGrid>
        </FormCard>

        <div className="form-actions-bar">
          <Button onClick={() => navigate(appRoutes.salesOrderDetail(sourceOrder.id))} type="button" variant="secondary">Cancel</Button>
          <Button disabled={createMutation.isPending || !sourceIsEligible || !shipLines.some((line) => line.included && line.shipQuantity > 0)} type="submit" variant="primary"><Save size={16} />{createMutation.isPending ? 'Creating...' : 'Create draft challan'}</Button>
        </div>
      </form>
    </section>
  )
}
