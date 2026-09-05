import { useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, FileCheck, Save, Trash2 } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  CheckboxInput,
  DataTable,
  EntityPicker,
  FormCard,
  FormField,
  FormGrid,
  Money,
  NumberInput,
  PageHeader,
  SelectInput,
  TextAreaInput,
  TextInput,
} from '@/design-system'
import { listContacts, type Contact } from '@/features/contacts/contacts-api'
import { listItems, type Item } from '@/features/items/items-api'
import {
  createSalesOrder,
  type CreateSalesOrderRequest,
} from '@/features/sales-orders/sales-orders-api'
import { listWarehouses } from '@/features/warehouses/warehouses-api'

type OrderLineFormItem = {
  id: string
  itemId: string
  itemName: string
  description: string
  hsnCode: string
  unit: string
  quantity: number
  rate: number
  discountPct: number
  gstRate: number
  taxGroupId?: string
}

export function SalesOrderCreatePage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [customer, setCustomer] = useState<Contact | null>(null)
  const [warehouseId, setWarehouseId] = useState('')
  const [orderDate, setOrderDate] = useState(() => new Date().toISOString().split('T')[0] || '')
  const [expectedShipmentDate, setExpectedShipmentDate] = useState(() => {
    const date = new Date()
    date.setDate(date.getDate() + 7)
    return date.toISOString().split('T')[0] || ''
  })
  const [referenceNumber, setReferenceNumber] = useState('')
  const [deliveryMethod, setDeliveryMethod] = useState('')
  const [placeOfSupply, setPlaceOfSupply] = useState('')
  const [allowBackorder, setAllowBackorder] = useState(false)
  const [notes, setNotes] = useState('')
  const [terms, setTerms] = useState('')
  const [lines, setLines] = useState<OrderLineFormItem[]>([])
  const [feedback, setFeedback] = useState<string | null>(null)

  const warehouses = useQuery({ queryKey: ['warehouses'], queryFn: listWarehouses })

  const addCatalogItem = (item: Item | null | undefined) => {
    if (!item) return
    setLines((previous) => [
      ...previous,
      {
        id: crypto.randomUUID(),
        itemId: item.id,
        itemName: item.name,
        description: item.name,
        hsnCode: item.hsnCode || '',
        unit: item.unitOfMeasure || '',
        quantity: 1,
        rate: Number(item.salePrice) || 0,
        discountPct: 0,
        gstRate: Number(item.gstRate || 0),
        taxGroupId: item.defaultTaxGroupId || undefined,
      },
    ])
  }

  const updateLine = (id: string, updates: Partial<OrderLineFormItem>) => {
    setLines((previous) => previous.map((line) => line.id === id ? { ...line, ...updates } : line))
  }

  const totals = useMemo(() => lines.reduce((result, line) => {
    const taxable = line.quantity * line.rate * (1 - line.discountPct / 100)
    const tax = taxable * line.gstRate / 100
    return { subtotal: result.subtotal + taxable, tax: result.tax + tax }
  }, { subtotal: 0, tax: 0 }), [lines])

  const createMutation = useMutation({
    mutationFn: (request: CreateSalesOrderRequest) => createSalesOrder(request),
    onSuccess: (created) => {
      queryClient.invalidateQueries({ queryKey: ['sales-orders'] })
      navigate(appRoutes.salesOrderDetail(created.id))
    },
    onError: (error: Error) => setFeedback(error.message),
  })

  const handleSubmit = (event: React.FormEvent) => {
    event.preventDefault()
    setFeedback(null)
    if (!customer) {
      setFeedback('Select a customer before creating the sales order.')
      return
    }
    if (!lines.length || lines.some((line) => !line.description.trim() || line.quantity <= 0 || line.rate < 0)) {
      setFeedback('Add at least one complete line with a positive quantity and a valid rate.')
      return
    }

    createMutation.mutate({
      contactId: customer.id,
      orderDate,
      expectedShipmentDate: expectedShipmentDate || undefined,
      referenceNumber: referenceNumber.trim() || undefined,
      deliveryMethod: deliveryMethod.trim() || undefined,
      placeOfSupply: placeOfSupply.trim() || undefined,
      notes: notes.trim() || undefined,
      terms: terms.trim() || undefined,
      allowBackorder,
      warehouseId: warehouseId || undefined,
      lines: lines.map((line) => ({
        itemId: line.itemId,
        description: line.description.trim(),
        hsnCode: line.hsnCode.trim() || undefined,
        quantity: line.quantity,
        rate: line.rate,
        unit: line.unit.trim() || undefined,
        discountPct: line.discountPct || undefined,
        taxGroupId: line.taxGroupId,
        gstRate: line.gstRate,
      })),
    })
  }

  return (
    <section className="workspace-page">
      <Link className="form-back-link" to={appRoutes.salesOrders}><ArrowLeft size={16} /> Back to sales orders</Link>
      <PageHeader
        eyebrow="Sales / Order management"
        title="New sales order"
        description="Create a customer commitment. Saving does not move stock; confirmation reserves available inventory."
      />
      {feedback ? <div className="banner banner--error" role="alert">{feedback}</div> : null}

      <form className="create-form-container" onSubmit={handleSubmit}>
        <FormCard description="Search the customer directory and set the order's stock-reservation warehouse and delivery commitments." stepNumber={1} title="Customer and order details">
          <FormGrid columns={4}>
            <FormField label="Customer" required span={2}>
              <EntityPicker
                ariaLabel="Search customer contacts"
                getOptionBadge={(item) => item.contactType}
                getOptionDescription={(item) => [item.companyName, item.gstin, item.phone].filter(Boolean).join(' / ')}
                getOptionId={(item) => item.id}
                getOptionLabel={(item) => item.displayName}
                onChange={(_id, item) => setCustomer(item ?? null)}
                onSearch={async (search) => (await listContacts({ filter: 'CUSTOMER', page: 0, search, size: 20 })).content}
                placeholder="Search customer name, company, GSTIN, or phone"
                selectedEntity={customer}
                value={customer?.id ?? null}
              />
            </FormField>
            <FormField label="Order date" required><TextInput onChange={(event) => setOrderDate(event.target.value)} required type="date" value={orderDate} /></FormField>
            <FormField label="Expected shipment"><TextInput onChange={(event) => setExpectedShipmentDate(event.target.value)} type="date" value={expectedShipmentDate} /></FormField>
            <FormField label="Warehouse">
              <SelectInput
                onChange={(event) => setWarehouseId(event.target.value)}
                options={(warehouses.data ?? []).filter((warehouse) => warehouse.active).map((warehouse) => ({ value: warehouse.id, label: `${warehouse.code} / ${warehouse.name}${warehouse.isDefault ? ' (default)' : ''}` }))}
                placeholderOption="Use organisation default warehouse"
                value={warehouseId}
              />
            </FormField>
            <FormField label="Customer PO or reference"><TextInput onChange={(event) => setReferenceNumber(event.target.value)} placeholder="e.g. CUST-PO-204" value={referenceNumber} /></FormField>
            <FormField label="Delivery method"><TextInput onChange={(event) => setDeliveryMethod(event.target.value)} placeholder="Road, courier, pickup" value={deliveryMethod} /></FormField>
            <FormField label="Place of supply"><TextInput onChange={(event) => setPlaceOfSupply(event.target.value)} placeholder="e.g. 09-Uttar Pradesh" value={placeOfSupply} /></FormField>
            <FormField label="Stock policy" span="full">
              <CheckboxInput
                checked={allowBackorder}
                description="Confirmation reserves what is available and records the remaining quantity as backorder."
                onChange={(event) => setAllowBackorder(event.target.checked)}
                title="Allow backorders when stock is short"
              />
            </FormField>
          </FormGrid>
        </FormCard>

        <FormCard description="Search the product catalogue. This preview helps review the order, while the server remains authoritative for commercial totals and stock controls." stepNumber={2} title={`Order lines (${lines.length})`}>
          <FormField label="Add catalog item">
            <EntityPicker<Item>
              ariaLabel="Search items to add to sales order"
              getOptionDescription={(item) => [item.sku, item.hsnCode, item.unitOfMeasure, item.totalOnHand === null ? null : `On hand ${item.totalOnHand}`].filter(Boolean).join(' / ')}
              getOptionId={(item) => item.id}
              getOptionLabel={(item) => item.name}
              onChange={(_id, item) => addCatalogItem(item)}
              onSearch={async (search) => (await listItems({ activeOnly: true, search, size: 20 })).content}
              placeholder="Search item name, SKU, or HSN"
              value={null}
            />
          </FormField>

          {lines.length ? (
            <DataTable caption="Sales order lines">
              <thead>
                <tr>
                  <th scope="col">Item and description</th>
                  <th scope="col">HSN</th>
                  <th className="numeric-cell" scope="col">Qty</th>
                  <th className="numeric-cell" scope="col">Rate</th>
                  <th className="numeric-cell" scope="col">Discount</th>
                  <th className="numeric-cell" scope="col">GST</th>
                  <th className="numeric-cell" scope="col">Total preview</th>
                  <th scope="col"><span className="visually-hidden">Remove</span></th>
                </tr>
              </thead>
              <tbody>
                {lines.map((line) => {
                  const taxable = line.quantity * line.rate * (1 - line.discountPct / 100)
                  const total = taxable * (1 + line.gstRate / 100)
                  return (
                    <tr key={line.id}>
                      <td><div className="cell-stack"><strong>{line.itemName}</strong><TextInput aria-label={`Description for ${line.itemName}`} onChange={(event) => updateLine(line.id, { description: event.target.value })} value={line.description} /></div></td>
                      <td><TextInput aria-label={`HSN for ${line.itemName}`} onChange={(event) => updateLine(line.id, { hsnCode: event.target.value })} placeholder="HSN" value={line.hsnCode} /></td>
                      <td className="numeric-cell"><NumberInput min={0.001} onChange={(event) => updateLine(line.id, { quantity: Number(event.target.value) || 0 })} step="0.001" value={line.quantity} /></td>
                      <td className="numeric-cell"><NumberInput currencyPrefix="INR" min={0} onChange={(event) => updateLine(line.id, { rate: Number(event.target.value) || 0 })} step="0.01" value={line.rate} /></td>
                      <td className="numeric-cell"><NumberInput max={100} min={0} onChange={(event) => updateLine(line.id, { discountPct: Number(event.target.value) || 0 })} step="0.01" unitSuffix="%" value={line.discountPct} /></td>
                      <td className="numeric-cell"><NumberInput max={100} min={0} onChange={(event) => updateLine(line.id, { gstRate: Number(event.target.value) || 0 })} step="0.01" unitSuffix="%" value={line.gstRate} /></td>
                      <td className="numeric-cell"><Money amount={total} /></td>
                      <td><Button aria-label={`Remove ${line.itemName}`} onClick={() => setLines((previous) => previous.filter((entry) => entry.id !== line.id))} type="button" variant="ghost"><Trash2 size={14} /></Button></td>
                    </tr>
                  )
                })}
              </tbody>
            </DataTable>
          ) : <div className="directory-state"><FileCheck size={28} /><p>Search for an item to begin this sales order.</p></div>}

          <div className="form-summary-card">
            <div className="form-summary-row"><span>Taxable subtotal preview</span><Money amount={totals.subtotal} /></div>
            <div className="form-summary-row"><span>GST preview</span><Money amount={totals.tax} /></div>
            <div className="form-summary-row form-summary-row--total"><span>Order total preview</span><Money amount={totals.subtotal + totals.tax} /></div>
          </div>
        </FormCard>

        <FormCard description="Keep customer-facing terms and internal handling instructions with this order." stepNumber={3} title="Notes and terms">
          <FormGrid columns={2}>
            <FormField label="Internal or delivery notes"><TextAreaInput onChange={(event) => setNotes(event.target.value)} placeholder="Delivery timing, packaging, or sales team notes" rows={3} value={notes} /></FormField>
            <FormField label="Terms and conditions"><TextAreaInput onChange={(event) => setTerms(event.target.value)} placeholder="Payment and delivery terms" rows={3} value={terms} /></FormField>
          </FormGrid>
        </FormCard>

        <div className="form-actions-bar">
          <Button onClick={() => navigate(appRoutes.salesOrders)} type="button" variant="secondary">Cancel</Button>
          <Button disabled={createMutation.isPending || !customer || !lines.length} type="submit" variant="primary"><Save size={16} />{createMutation.isPending ? 'Creating...' : 'Create draft order'}</Button>
        </div>
      </form>
    </section>
  )
}
