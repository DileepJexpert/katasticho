import { useEffect, useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, Save } from 'lucide-react'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import {
  createDeliveryChallan,
  type CreateDeliveryChallanLineRequest,
  type CreateDeliveryChallanRequest,
} from '@/features/delivery-challans/delivery-challans-api'
import { getSalesOrder, listSalesOrders } from '@/features/sales-orders/sales-orders-api'

interface ShipLineItem {
  soLineId: string
  itemName: string
  description: string
  orderedQty: number
  shippedQty: number
  remainingQty: number
  shipQty: number
  included: boolean
  unit: string
}

export function DeliveryChallanCreatePage() {
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const initialSoId = searchParams.get('salesOrderId') || ''
  const queryClient = useQueryClient()

  const [selectedSoId, setSelectedSoId] = useState(initialSoId)
  const [challanDate, setChallanDate] = useState(() => new Date().toISOString().split('T')[0] || '')
  const [deliveryMethod, setDeliveryMethod] = useState('Road Transport')
  const [vehicleNumber, setVehicleNumber] = useState('')
  const [trackingNumber, setTrackingNumber] = useState('')
  const [shippingAddress, setShippingAddress] = useState('')
  const [notes, setNotes] = useState('')
  const [shipLines, setShipLines] = useState<ShipLineItem[]>([])
  const [feedback, setFeedback] = useState<{ type: 'error' | 'success'; message: string } | null>(null)

  const salesOrdersQuery = useQuery({
    queryKey: ['sales-orders-for-challan'],
    queryFn: () => listSalesOrders({ page: 0, status: null }),
  })

  const eligibleOrders = useMemo(() => {
    return salesOrdersQuery.data?.content.filter(
      (so) => so.status === 'CONFIRMED' || so.status === 'PARTIALLY_SHIPPED' || so.status === 'DRAFT'
    ) ?? []
  }, [salesOrdersQuery.data])

  const soDetailQuery = useQuery({
    queryKey: ['sales-order-detail-for-dc', selectedSoId],
    queryFn: () => getSalesOrder(selectedSoId),
    enabled: Boolean(selectedSoId),
  })

  useEffect(() => {
    if (soDetailQuery.data) {
      const so = soDetailQuery.data
      const lines: ShipLineItem[] = so.lines.map((l) => {
        const ordered = Number(l.quantity) || 0
        const shipped = Number(l.quantityShipped) || 0
        const remaining = Math.max(0, ordered - shipped)
        return {
          soLineId: l.id,
          itemName: l.itemName || l.description || 'Item',
          description: l.description || '',
          orderedQty: ordered,
          shippedQty: shipped,
          remainingQty: remaining,
          shipQty: remaining,
          included: remaining > 0,
          unit: l.unit || 'pcs',
        }
      })
      setShipLines(lines)
      if (so.deliveryMethod) setDeliveryMethod(so.deliveryMethod)
      if (so.notes && !notes) setNotes(so.notes)
    }
  }, [soDetailQuery.data])

  const createMutation = useMutation({
    mutationFn: (req: CreateDeliveryChallanRequest) => createDeliveryChallan(req),
    onSuccess: (created) => {
      queryClient.invalidateQueries({ queryKey: ['delivery-challans'] })
      queryClient.invalidateQueries({ queryKey: ['sales-orders'] })
      navigate(appRoutes.deliveryChallanDetail(created.id))
    },
    onError: (err: unknown) => {
      const msg = err instanceof Error ? err.message : 'Failed to create delivery challan.'
      setFeedback({ type: 'error', message: msg })
    },
  })

  const handleToggleLine = (soLineId: string) => {
    setShipLines((prev) =>
      prev.map((line) =>
        line.soLineId === soLineId ? { ...line, included: !line.included } : line
      )
    )
  }

  const handleQtyChange = (soLineId: string, qty: number) => {
    setShipLines((prev) =>
      prev.map((line) =>
        line.soLineId === soLineId ? { ...line, shipQty: Math.max(0, qty) } : line
      )
    )
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    setFeedback(null)

    if (!selectedSoId) {
      setFeedback({ type: 'error', message: 'Please select a Sales Order to dispatch.' })
      return
    }

    const linesToShip: CreateDeliveryChallanLineRequest[] = shipLines
      .filter((l) => l.included && l.shipQty > 0)
      .map((l) => ({
        soLineId: l.soLineId,
        quantity: l.shipQty,
      }))

    if (linesToShip.length === 0) {
      setFeedback({ type: 'error', message: 'Please include at least one item with a quantity greater than 0.' })
      return
    }

    createMutation.mutate({
      salesOrderId: selectedSoId,
      lines: linesToShip,
      challanDate,
      deliveryMethod: deliveryMethod.trim() || undefined,
      vehicleNumber: vehicleNumber.trim() || undefined,
      trackingNumber: trackingNumber.trim() || undefined,
      shippingAddress: shippingAddress.trim() || undefined,
      notes: notes.trim() || undefined,
    })
  }

  return (
    <section className="workspace-page">
      <div style={{ marginBottom: 'var(--space-3)' }}>
        <Link
          to={appRoutes.deliveryChallans}
          style={{
            alignItems: 'center',
            color: 'var(--text-secondary)',
            display: 'inline-flex',
            fontSize: 'var(--text-sm)',
            gap: 'var(--space-1)',
            textDecoration: 'none',
          }}
        >
          <ArrowLeft size={16} /> Back to Delivery Challans
        </Link>
      </div>

      <PageHeader
        eyebrow="Sales / Fulfilment"
        title="New Delivery Challan"
        description="Record dispatch of goods against a confirmed Sales Order, update tracking, and deduce warehouse inventory upon dispatch."
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

      <form id="dc-form" onSubmit={handleSubmit}>
        <div style={{ display: 'grid', gap: 'var(--space-4)', marginBottom: 'var(--space-6)' }}>
          <div className="document-card">
            <h2 style={{ marginBottom: 'var(--space-3)' }}>1. Order & Dispatch Information</h2>
            <div style={{ display: 'grid', gap: 'var(--space-4)', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))' }}>
              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Sales Order *
                </label>
                <select
                  onChange={(e) => setSelectedSoId(e.target.value)}
                  required
                  style={{
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border-strong)',
                    borderRadius: 'var(--radius)',
                    color: 'var(--text-primary)',
                    height: 'var(--control-h)',
                    padding: '0 var(--space-2)',
                    width: '100%',
                  }}
                  value={selectedSoId}
                >
                  <option value="">-- Select Sales Order --</option>
                  {eligibleOrders.map((so) => (
                    <option key={so.id} value={so.id}>
                      {so.salesOrderNumber} - {so.contactName || 'Customer'} ({so.status})
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Challan Date *
                </label>
                <input
                  onChange={(e) => setChallanDate(e.target.value)}
                  required
                  style={{
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border-strong)',
                    borderRadius: 'var(--radius)',
                    color: 'var(--text-primary)',
                    height: 'var(--control-h)',
                    padding: '0 var(--space-2)',
                    width: '100%',
                  }}
                  type="date"
                  value={challanDate}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Delivery Method
                </label>
                <input
                  onChange={(e) => setDeliveryMethod(e.target.value)}
                  placeholder="e.g. Road, Courier, Own Vehicle"
                  style={{
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border-strong)',
                    borderRadius: 'var(--radius)',
                    color: 'var(--text-primary)',
                    height: 'var(--control-h)',
                    padding: '0 var(--space-2)',
                    width: '100%',
                  }}
                  type="text"
                  value={deliveryMethod}
                />
              </div>
            </div>
          </div>

          <div className="document-card document-card--lines">
            <h2>2. Items to Ship</h2>
            <p style={{ color: 'var(--text-secondary)', fontSize: 'var(--text-xs)', marginBottom: 'var(--space-3)' }}>
              Select items and specify quantities to include in this dispatch batch.
            </p>

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
                            width: '100px',
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
          </div>

          <div className="document-card">
            <h2 style={{ marginBottom: 'var(--space-3)' }}>3. Vehicle & Logistics Details</h2>
            <div style={{ display: 'grid', gap: 'var(--space-4)', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))' }}>
              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Vehicle Number
                </label>
                <input
                  onChange={(e) => setVehicleNumber(e.target.value)}
                  placeholder="e.g. MH-12-AB-1234"
                  style={{
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border-strong)',
                    borderRadius: 'var(--radius)',
                    color: 'var(--text-primary)',
                    height: 'var(--control-h)',
                    padding: '0 var(--space-2)',
                    width: '100%',
                  }}
                  type="text"
                  value={vehicleNumber}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Tracking / LR Number
                </label>
                <input
                  onChange={(e) => setTrackingNumber(e.target.value)}
                  placeholder="e.g. LR-987654"
                  style={{
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border-strong)',
                    borderRadius: 'var(--radius)',
                    color: 'var(--text-primary)',
                    height: 'var(--control-h)',
                    padding: '0 var(--space-2)',
                    width: '100%',
                  }}
                  type="text"
                  value={trackingNumber}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                  Shipping Address
                </label>
                <input
                  onChange={(e) => setShippingAddress(e.target.value)}
                  placeholder="Delivery destination address"
                  style={{
                    background: 'var(--bg-surface)',
                    border: '1px solid var(--border-strong)',
                    borderRadius: 'var(--radius)',
                    color: 'var(--text-primary)',
                    height: 'var(--control-h)',
                    padding: '0 var(--space-2)',
                    width: '100%',
                  }}
                  type="text"
                  value={shippingAddress}
                />
              </div>
            </div>

            <div style={{ marginTop: 'var(--space-4)' }}>
              <label style={{ display: 'block', fontSize: 'var(--text-xs)', fontWeight: 'var(--fw-medium)', marginBottom: '4px' }}>
                Delivery / Dispatch Notes
              </label>
              <textarea
                onChange={(e) => setNotes(e.target.value)}
                placeholder="Instructions for driver or customer receiving goods..."
                rows={3}
                style={{
                  background: 'var(--bg-surface)',
                  border: '1px solid var(--border-strong)',
                  borderRadius: 'var(--radius)',
                  color: 'var(--text-primary)',
                  padding: 'var(--space-2)',
                  width: '100%',
                }}
                value={notes}
              />
            </div>
          </div>
        </div>
      </form>
    </section>
  )
}
