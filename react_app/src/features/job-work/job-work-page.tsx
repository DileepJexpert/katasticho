import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { Briefcase, Plus, AlertOctagon, Search } from 'lucide-react'
import { Link } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DataTable,
  EntityPicker,
  FormField,
  FormGrid,
  Modal,
  Money,
  NumberInput,
  PageHeader,
  SelectInput,
  StatusChip,
} from '@/design-system'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { listJobWorkOrders, getJobWorkGstAlerts, createJobWorkOrder } from '@/features/job-work/job-work-api'
import { listContacts, type Contact } from '@/features/contacts/contacts-api'
import { listWarehouses } from '@/features/warehouses/warehouses-api'
import { listItems, type Item } from '@/features/items/items-api'

export function JobWorkPage() {
  const queryClient = useQueryClient()
  const [page] = useState(0)
  const [search, setSearch] = useState('')
  const [isCreateOpen, setIsCreateOpen] = useState(false)
  const [selectedVendor, setSelectedVendor] = useState<Contact | null>(null)
  const [vendorId, setVendorId] = useState('')
  const [warehouseId, setWarehouseId] = useState('')
  const [charges, setCharges] = useState('1500')
  const [selectedMaterialItem, setSelectedMaterialItem] = useState<Item | null>(null)
  const [materialItemId, setMaterialItemId] = useState('')
  const [materialQty, setMaterialQty] = useState('100')
  const [selectedOutputItem, setSelectedOutputItem] = useState<Item | null>(null)
  const [outputItemId, setOutputItemId] = useState('')
  const [outputQty, setOutputQty] = useState('95')

  const query = useQuery({
    queryKey: ['job-work', page],
    queryFn: () => listJobWorkOrders({ page }),
  })

  const alertsQuery = useQuery({
    queryKey: ['job-work-gst-alerts'],
    queryFn: () => getJobWorkGstAlerts(30),
  })

  const warehousesQuery = useQuery({
    queryKey: ['warehouses'],
    queryFn: listWarehouses,
  })

  const createMutation = useMutation({
    mutationFn: () => createJobWorkOrder({
      vendorId,
      warehouseId,
      processingCharges: Number(charges),
      materials: [{ itemId: materialItemId, qty: Number(materialQty) }],
      outputs: [{ itemId: outputItemId, qty: Number(outputQty) }],
    }),
    onSuccess: () => {
      setIsCreateOpen(false)
      setSelectedVendor(null)
      setVendorId('')
      setWarehouseId('')
      setSelectedMaterialItem(null)
      setMaterialItemId('')
      setSelectedOutputItem(null)
      setOutputItemId('')
      queryClient.invalidateQueries({ queryKey: ['job-work'] })
    },
  })

  const rawList = query.data?.content ?? []
  const filtered = rawList.filter((jw) => {
    if (!search.trim()) return true
    const q = search.toLowerCase()
    return jw.jobWorkNumber.toLowerCase().includes(q) || (jw.vendorName && jw.vendorName.toLowerCase().includes(q))
  })

  const gstAlerts = alertsQuery.data ?? []

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Manufacturing / Subcontracting"
        title="Job Work & Challan 45"
        description="Subcontracting dispatches to job workers, GST ITC-04 compliance, and inward goods receipts."
        actions={
          <div className="table-actions">
            <Button onClick={() => setIsCreateOpen(true)} variant="primary">
              <Plus aria-hidden="true" size={16} />
              Create Job Work Order
            </Button>
          </div>
        }
      />

      {gstAlerts.length > 0 && (
        <div style={{ background: 'var(--bg-danger-subtle)', border: '1px solid var(--border-danger)', borderRadius: '6px', padding: '12px 16px', marginBottom: '16px', display: 'flex', gap: '12px', alignItems: 'center' }}>
          <AlertOctagon color="var(--color-danger)" size={20} />
          <div>
            <strong style={{ color: 'var(--color-danger)' }}>GST ITC-04 Statutory Deadline Alert:</strong>
            <span style={{ marginLeft: '6px', fontSize: '13px' }}>
              {gstAlerts.length} job work shipment(s) approaching the 1-year input / 3-year capital goods return deadline under CGST Sec 143.
            </span>
          </div>
        </div>
      )}

      <div className="list-toolbar">
        <label className="directory-search">
          <Search aria-hidden="true" size={18} />
          <span className="sr-only">Search job work</span>
          <input
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by job work # or job worker..."
            type="search"
            value={search}
          />
        </label>
      </div>

      {query.isLoading ? (
        <div className="directory-state">Loading job work orders...</div>
      ) : filtered.length === 0 ? (
        <div className="directory-state">
          <Briefcase size={24} />
          <strong>No job work orders found.</strong>
        </div>
      ) : (
        <DataTable caption="Subcontracting job work orders">
          <thead>
            <tr>
              <th scope="col">Job Work #</th>
              <th scope="col">Job Worker (Vendor)</th>
              <th scope="col">Challan 45 #</th>
              <th scope="col">ITC-04 Deadline</th>
              <th scope="col">Status</th>
              <th className="numeric-cell" scope="col">Processing Charges</th>
              <th className="numeric-cell" scope="col">Total Cost</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((jw) => (
              <tr key={jw.id}>
                <td>
                  <Link className="table-row-link" to={appRoutes.jobWorkDetail(jw.id)}>
                    {jw.jobWorkNumber}
                  </Link>
                </td>
                <td><strong>{jw.vendorName || jw.vendorId}</strong></td>
                <td>{jw.challanNumber ? <code>{jw.challanNumber}</code> : <span className="cell-muted">Pending Send</span>}</td>
                <td>{jw.gstReturnDeadline ? formatDate(jw.gstReturnDeadline) : '--'}</td>
                <td><StatusChip status={formatStatusLabel(jw.status)} /></td>
                <td className="numeric-cell"><Money amount={jw.processingCharges} /></td>
                <td className="numeric-cell"><Money amount={jw.totalCost} /></td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      )}

      <Modal
        footer={
          <>
            <Button onClick={() => setIsCreateOpen(false)} variant="secondary">Cancel</Button>
            <Button
              disabled={createMutation.isPending || !vendorId.trim() || !warehouseId.trim() || !materialItemId.trim() || !outputItemId.trim()}
              onClick={() => createMutation.mutate()}
              variant="primary"
            >
              {createMutation.isPending ? 'Creating...' : 'Create Job Work Order'}
            </Button>
          </>
        }
        isOpen={isCreateOpen}
        onClose={() => setIsCreateOpen(false)}
        size="lg"
        title="Create Job Work Order (Challan 45)"
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <FormGrid columns={2}>
            <FormField label="Job Worker / Vendor" required>
              <EntityPicker<Contact>
                ariaLabel="Job Worker / Vendor"
                getOptionDescription={(contact) => `${contact.companyName || 'Individual'} · ${contact.gstin || 'Unregistered'}`}
                getOptionId={(contact) => contact.id}
                getOptionLabel={(contact) => contact.displayName}
                onChange={(_id, contact) => {
                  setSelectedVendor(contact ?? null)
                  setVendorId(contact?.id ?? '')
                }}
                onSearch={async (query) => {
                  const res = await listContacts({ filter: 'VENDOR', page: 0, search: query, size: 25 })
                  return res.content
                }}
                placeholder="Search job worker / vendor..."
                selectedEntity={selectedVendor}
                value={selectedVendor?.id ?? null}
              />
            </FormField>
            <FormField label="Dispatch Facility / Warehouse" required>
              <SelectInput
                aria-label="Dispatch Facility / Warehouse"
                onChange={(e) => setWarehouseId(e.target.value)}
                required
                value={warehouseId}
              >
                <option value="">Select dispatch warehouse</option>
                {warehousesQuery.data?.map((w) => (
                  <option key={w.id} value={w.id}>
                    {w.name} ({w.code})
                  </option>
                ))}
              </SelectInput>
            </FormField>
          </FormGrid>

          <FormGrid columns={2}>
            <FormField label="Raw Material Item" required>
              <EntityPicker<Item>
                ariaLabel="Raw Material Item"
                getOptionDescription={(item) => `${item.sku || 'No SKU'} · ${item.unitOfMeasure || 'unit'}`}
                getOptionId={(item) => item.id}
                getOptionLabel={(item) => item.name}
                onChange={(_id, item) => {
                  setSelectedMaterialItem(item ?? null)
                  setMaterialItemId(item?.id ?? '')
                }}
                onSearch={async (query) => {
                  const res = await listItems({ search: query, activeOnly: true, size: 25 })
                  return res.content
                }}
                placeholder="Search raw material item..."
                selectedEntity={selectedMaterialItem}
                value={selectedMaterialItem?.id ?? null}
              />
            </FormField>
            <FormField label="Sent Quantity" required>
              <NumberInput
                min={1}
                onChange={(e) => setMaterialQty(e.target.value)}
                required
                value={materialQty}
              />
            </FormField>
          </FormGrid>

          <FormGrid columns={2}>
            <FormField label="Expected Output Item" required>
              <EntityPicker<Item>
                ariaLabel="Expected Output Item"
                getOptionDescription={(item) => `${item.sku || 'No SKU'} · ${item.unitOfMeasure || 'unit'}`}
                getOptionId={(item) => item.id}
                getOptionLabel={(item) => item.name}
                onChange={(_id, item) => {
                  setSelectedOutputItem(item ?? null)
                  setOutputItemId(item?.id ?? '')
                }}
                onSearch={async (query) => {
                  const res = await listItems({ search: query, activeOnly: true, size: 25 })
                  return res.content
                }}
                placeholder="Search expected processed item..."
                selectedEntity={selectedOutputItem}
                value={selectedOutputItem?.id ?? null}
              />
            </FormField>
            <FormField label="Expected Output Quantity" required>
              <NumberInput
                min={1}
                onChange={(e) => setOutputQty(e.target.value)}
                required
                value={outputQty}
              />
            </FormField>
          </FormGrid>

          <FormField label="Agreed Processing Charges (₹)" required>
            <NumberInput
              min={0}
              onChange={(e) => setCharges(e.target.value)}
              required
              step="0.01"
              value={charges}
            />
          </FormField>
        </div>
      </Modal>
    </section>
  )
}