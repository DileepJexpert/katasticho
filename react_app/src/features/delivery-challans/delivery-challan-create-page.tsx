import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, Save } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DataTable,
  FormCard,
  FormField,
  FormGrid,
  PageHeader,
  SelectInput,
  TextAreaInput,
  TextInput,
} from '@/design-system'
import {
  createDeliveryChallan,
  type CreateDeliveryChallanLineRequest,
} from '@/features/delivery-challans/delivery-challans-api'
import { getSalesOrder, listSalesOrders } from '@/features/sales-orders/sales-orders-api'

interface ShippableLine {
  soLineId: string
  itemId: string
  itemName: string
  description?: string
  orderedQty: number
  shippedQty: number
  remainingQty: number
  shipQty: number
  unit?: string
  included: boolean
}

export function DeliveryChallanCreatePage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const [selectedSoId, setSelectedSoId] = useState('')
  const [challanDate, setChallanDate] = useState(() => new Date().toISOString().split('T')[0] || '')
  const [deliveryMethod, setDeliveryMethod] = useState('Road')
  const [vehicleNumber, setVehicleNumber] = useState('')
  const [lrNumber, setLrNumber] = useState('')
  const [driverName, setDriverName] = useState('')
  const [driverPhone, setDriverPhone] = useState('')
  const [shippingAddress, setShippingAddress] = useState('')
  const [notes, setNotes] = useState('')
  const [shipLines, setShipLines] = useState<ShippableLine[]>([])
  const [feedback, setFeedback] = useState<{ type: 'error' | 'success'; message: string } | null>(null)

  const salesOrdersQuery = useQuery({
    queryKey: ['eligible-so-for-dc'],
    queryFn: () => listSalesOrders({ page: 0 }),
  })

  const eligibleOrders = useMemo(() => {
    return (salesOrdersQuery.data?.content ?? []).filter(
      (so) => so.status === 'CONFIRMED' || so.status === 'PARTIALLY_SHIPPED' || so.status === 'DRAFT'
    )
  }, [salesOrdersQuery.data])

  const soDetailQuery = useQuery({
    queryKey: ['so-for-dc', selectedSoId],
    queryFn: async () => {
      if (!selectedSoId) return null
      const so = await getSalesOrder(selectedSoId)
      const mapped: ShippableLine[] = so.lines.map((l) => {
        const ord = Number(l.orderedQuantity) || 0
        const shp = Number(l.shippedQuantity) || 0
        const rem = Math.max(0, ord - shp)
        return {
          soLineId: l.id,
          itemId: l.itemId,
          itemName: l.itemName,
          description: l.description,
          orderedQty: ord,
          shippedQty: shp,
          remainingQty: rem,
          shipQty: rem,
          unit: l.unitOfMeasure || 'units',
          included: rem > 0,
        }
      })
      setShipLines(mapped)
      return so
    },
    enabled: Boolean(selectedSoId),
  })

  const handleToggleLine = (soLineId: string) => {
    setShipLines((prev) =>
      prev.map((l) => (l.soLineId === soLineId ? { ...l, included: !l.included } : l))
    )
  }

  const handleQtyChange = (soLineId: string, qty: number) => {
    setShipLines((prev) =>
      prev.map((l) => (l.soLineId === soLineId ? { ...l, shipQty: Math.max(0, qty) } : l))
    )
  }

  const totalShipUnits = useMemo(() => {
    return shipLines
      .filter((l) => l.included)
      .reduce((acc, l) => acc + (l.shipQty || 0), 0)
  }, [shipLines])

  const createMutation = useMutation({
    mutationFn: createDeliveryChallan,
    onSuccess: (created) => {
      queryClient.invalidateQueries({ queryKey: ['delivery-challans'] })
      navigate(appRoutes.deliveryChallanDetail(created.id))
    },
    onError: (err) => {
      setFeedback({
        type: 'error',
        message: err instanceof Error ? err.message : 'Failed to create delivery challan',
      })
    },
  })

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    setFeedback(null)

    if (!selectedSoId) {
      setFeedback({ type: 'error', message: 'Please select a confirmed Sales Order to dispatch.' })
      return
    }

    const linesToShip = shipLines.filter((l) => l.included && l.shipQty > 0)
    if (linesToShip.length === 0) {
      setFeedback({ type: 'error', message: 'Please include at least one item with a quantity greater than 0.' })
      return
    }

    const reqLines: CreateDeliveryChallanLineRequest[] = linesToShip.map((l) => ({
      salesOrderLineId: l.soLineId,
      itemId: l.itemId,
      description: l.description,
      quantity: l.shipQty,
    }))

    createMutation.mutate({
      salesOrderId: selectedSoId,
      challanDate,
      deliveryMethod: deliveryMethod.trim() || undefined,
      vehicleNumber: vehicleNumber.trim() || undefined,
      lrNumber: lrNumber.trim() || undefined,
      driverName: driverName.trim() || undefined,
      driverPhone: driverPhone.trim() || undefined,
      shippingAddress: shippingAddress.trim() || undefined,
      notes: notes.trim() || undefined,
      lines: reqLines,
    })
  }

  return (
    <section className="workspace-page">
      <Link className="form-back-link" to={appRoutes.deliveryChallans}>
        <ArrowLeft size={16} /> Back to Delivery Challans
      </Link>

      <PageHeader
        eyebrow="Sales / Fulfilment"
        title="New Delivery Challan"
        description="Record dispatch of goods against a confirmed Sales Order, update tracking, and deduct warehouse inventory upon dispatch."
        actions={
          <div style={{ display: 'flex', gap: 'var(--space-2)' }}>
            <Button
              onClick={() => navigate(appRoutes.deliveryChallans)}
              type="button"
              variant="secondary"
            >
              Cancel
            </Button>
            <Button
              disabled={createMutation.isPending || !selectedSoId}
              form="dc-form"
              type="submit"
              variant="primary"
            >
              <Save size={16} />
              {createMutation.isPending ? 'Saving...' : 'Create Delivery Challan'}
            </Button>
          </div>
        }
      />

      {feedback && (
        <div
          className={`directory-state ${feedback.type === 'error' ? 'directory-state--error' : ''}`}
          role="alert"
          style={{ marginBottom: 'var(--space-4)', minHeight: 'auto', padding: 'var(--space-3)' }}
        >
          <strong>{feedback.message}</strong>
        </div>
      )}

      <form className="create-form-container" id="dc-form" onSubmit={handleSubmit}>
        <FormCard
          description="Select backing customer sales order and specify dispatch timing"
          stepNumber={1}
          title="Order & Dispatch Information"
        >
          <FormGrid columns={3}>
            <FormField label="Sales Order" required>
              <SelectInput
                onChange={(e) => setSelectedSoId(e.target.value)}
                placeholderOption="-- Select Sales Order --"
                required
                value={selectedSoId}
              >
                {eligibleOrders.map((so) => (
                  <option key={so.id} value={so.id}>
                    {so.salesOrderNumber} - {so.contactName || 'Customer'} ({so.status})
                  </option>
                ))}
              </SelectInput>
            </FormField>

            <FormField label="Challan Date" required>
              <TextInput
                onChange={(e) => setChallanDate(e.target.value)}
                required
                type="date"
                value={challanDate}
              />
            </FormField>

            <FormField label="Delivery Method">
              <TextInput
                onChange={(e) => setDeliveryMethod(e.target.value)}
                placeholder="e.g. Road, Courier, Dedicated Fleet"
                type="text"
                value={deliveryMethod}
              />
            </FormField>
          </FormGrid>
        </FormCard>

        <FormCard
          description="Select items and specify quantities to include in this dispatch batch"
          stepNumber={2}
          title="Items to Ship"
        >
          {soDetailQuery.isLoading ? (
            <div className="directory-state" style={{ minHeight: '120px' }}>Loading order items...</div>
          ) : !selectedSoId ? (
            <div className="directory-state" style={{ minHeight: '120px' }}>
              Please select a Sales Order above to populate order lines.
            </div>
          ) : shipLines.length === 0 ? (
            <div className="directory-state" style={{ minHeight: '120px' }}>
              No shippable items found for this sales order.
            </div>
          ) : (
            <DataTable caption="Items to ship">
              <thead>
                <tr>
                  <th style={{ width: '40px' }}>Ship</th>
                  <th scope="col">Item & Description</th>
                  <th className="numeric-cell" scope="col">Ordered</th>
                  <th className="numeric-cell" scope="col">Shipped</th>
                  <th className="numeric-cell" scope="col">Remaining</th>
                  <th className="numeric-cell" scope="col">Ship Quantity</th>
                </tr>
              </thead>
              <tbody>
                {shipLines.map((line) => (
                  <tr key={line.soLineId} style={{ background: line.included ? 'transparent' : 'var(--bg-subtle)' }}>
                    <td>
                      <input
                        checked={line.included}
                        onChange={() => handleToggleLine(line.soLineId)}
                        type="checkbox"
                      />
                    </td>
                    <td>
                      <strong>{line.itemName}</strong>
                      {line.description && <div style={{ color: 'var(--text-muted)', fontSize: '11px' }}>{line.description}</div>}
                    </td>
                    <td className="numeric-cell">
                      {line.orderedQty} {line.unit}
                    </td>
                    <td className="numeric-cell">
                      {line.shippedQty} {line.unit}
                    </td>
                    <td className="numeric-cell">
                      <strong>{line.remainingQty}</strong> {line.unit}
                    </td>
                    <td className="numeric-cell">
                      <input
                        disabled={!line.included}
                        max={line.remainingQty > 0 ? line.remainingQty : undefined}
                        min="0"
                        onChange={(e) => handleQtyChange(line.soLineId, parseFloat(e.target.value) || 0)}
                        step="any"
                        style={{
                          background: 'var(--bg-surface)',
                          border: '1px solid var(--border-strong)',
                          borderRadius: 'var(--radius)',
                          color: 'var(--text-primary)',
                          height: '28px',
                          padding: '0 var(--space-2)',
                          textAlign: 'right',
                          width: '80px',
                        }}
                        type="number"
                        value={line.shipQty}
                      />
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          )}

          {shipLines.length > 0 && (
            <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: 'var(--space-4)' }}>
              <div className="form-summary-card">
                <div className="form-summary-row form-summary-row--total">
                  <span>Total Dispatch Units</span>
                  <span className="amount">{totalShipUnits}</span>
                </div>
              </div>
            </div>
          )}
        </FormCard>

        <FormCard
          description="Vehicle identification, carrier consignment notes, and driver contacts"
          stepNumber={3}
          title="Transport & Logistics Details"
        >
          <FormGrid columns={4}>
            <FormField label="Vehicle Number">
              <TextInput
                onChange={(e) => setVehicleNumber(e.target.value.toUpperCase())}
                placeholder="e.g. MH-12-AB-1234"
                type="text"
                value={vehicleNumber}
              />
            </FormField>

            <FormField label="LR / Bilty / Docket No.">
              <TextInput
                onChange={(e) => setLrNumber(e.target.value)}
                placeholder="e.g. LR-98765"
                type="text"
                value={lrNumber}
              />
            </FormField>

            <FormField label="Driver / Transporter Name">
              <TextInput
                onChange={(e) => setDriverName(e.target.value)}
                placeholder="e.g. Ramesh Kumar"
                type="text"
                value={driverName}
              />
            </FormField>

            <FormField label="Driver Contact Phone">
              <TextInput
                onChange={(e) => setDriverPhone(e.target.value)}
                placeholder="e.g. +91 98765 43210"
                type="tel"
                value={driverPhone}
              />
            </FormField>
          </FormGrid>

          <FormGrid columns={2} style={{ marginTop: 'var(--space-4)' }}>
            <FormField label="Shipping Destination Address">
              <TextAreaInput
                onChange={(e) => setShippingAddress(e.target.value)}
                placeholder="Full delivery warehouse address or site location..."
                rows={3}
                value={shippingAddress}
              />
            </FormField>

            <FormField label="Delivery / Dispatch Notes">
              <TextAreaInput
                onChange={(e) => setNotes(e.target.value)}
                placeholder="Instructions for driver or customer receiving goods..."
                rows={3}
                value={notes}
              />
            </FormField>
          </FormGrid>
        </FormCard>

        <div className="form-actions-bar">
          <Button
            onClick={() => navigate(appRoutes.deliveryChallans)}
            type="button"
            variant="secondary"
          >
            Cancel
          </Button>
          <Button
            disabled={createMutation.isPending || !selectedSoId}
            type="submit"
            variant="primary"
          >
            <Save size={16} />
            {createMutation.isPending ? 'Saving...' : 'Create Delivery Challan'}
          </Button>
        </div>
      </form>
    </section>
  )
}
