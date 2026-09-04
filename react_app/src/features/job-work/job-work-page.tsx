import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { Briefcase, Plus, AlertOctagon, Search } from 'lucide-react'
import { Link } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DataTable,
  FormField,
  FormGrid,
  Modal,
  Money,
  NumberInput,
  PageHeader,
  StatusChip,
  TextInput,
} from '@/design-system'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { listJobWorkOrders, getJobWorkGstAlerts, createJobWorkOrder } from '@/features/job-work/job-work-api'

export function JobWorkPage() {
  const queryClient = useQueryClient()
  const [page] = useState(0)
  const [search, setSearch] = useState('')
  const [isCreateOpen, setIsCreateOpen] = useState(false)
  const [vendorId, setVendorId] = useState('')
  const [warehouseId, setWarehouseId] = useState('')
  const [charges, setCharges] = useState('1500')
  const [materialItemId, setMaterialItemId] = useState('')
  const [materialQty, setMaterialQty] = useState('100')
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

  const createMutation = useMutation({
    mutationFn: () => createJobWorkOrder({
      vendorId,
      warehouseId: warehouseId || 'w1000000-0000-0000-0000-000000000001',
      processingCharges: Number(charges),
      materials: [{ itemId: materialItemId, qty: Number(materialQty) }],
      outputs: [{ itemId: outputItemId, qty: Number(outputQty) }],
    }),
    onSuccess: () => {
      setIsCreateOpen(false)
      setVendorId('')
      setMaterialItemId('')
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
              disabled={createMutation.isPending || !vendorId.trim() || !materialItemId.trim()}
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
            <FormField label="Job Worker / Vendor ID" required>
              <TextInput
                onChange={(e) => setVendorId(e.target.value)}
                placeholder="Supplier / Subcontractor UUID"
                required
                value={vendorId}
              />
            </FormField>
            <FormField label="Dispatch Warehouse ID">
              <TextInput
                onChange={(e) => setWarehouseId(e.target.value)}
                placeholder="Warehouse UUID (optional)"
                value={warehouseId}
              />
            </FormField>
          </FormGrid>

          <FormGrid columns={2}>
            <FormField label="Raw Material Item ID" required>
              <TextInput
                onChange={(e) => setMaterialItemId(e.target.value)}
                placeholder="Input Item UUID"
                required
                value={materialItemId}
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
            <FormField label="Expected Output Item ID" required>
              <TextInput
                onChange={(e) => setOutputItemId(e.target.value)}
                placeholder="Output Processed Item UUID"
                required
                value={outputItemId}
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