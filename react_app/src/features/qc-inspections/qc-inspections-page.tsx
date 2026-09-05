import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { ShieldCheck, Plus, Search, Layers } from 'lucide-react'
import { Link } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DataTable,
  EntityPicker,
  FormField,
  Modal,
  NumberInput,
  PageHeader,
  Quantity,
  SelectInput,
  StatusChip,
  TextInput,
} from '@/design-system'
import { formatStatusLabel } from '@/shared/format/format'
import { listQcInspections, createQcInspection } from '@/features/qc-inspections/qc-inspections-api'
import { listItems, type Item } from '@/features/items/items-api'

export function QcInspectionsPage() {
  const queryClient = useQueryClient()
  const [page] = useState(0)
  const [search, setSearch] = useState('')
  const [isCreateOpen, setIsCreateOpen] = useState(false)
  const [selectedItem, setSelectedItem] = useState<Item | null>(null)
  const [itemId, setItemId] = useState('')
  const [inspectionType, setInspectionType] = useState('INBOUND_GRN')
  const [inspectedQty, setInspectedQty] = useState('50')
  const [batchId, setBatchId] = useState('')

  const query = useQuery({
    queryKey: ['qc-inspections', page],
    queryFn: () => listQcInspections({ page }),
  })

  const createMutation = useMutation({
    mutationFn: () => createQcInspection({
      itemId,
      inspectionType,
      inspectedQty: Number(inspectedQty),
      batchId: batchId.trim() ? batchId : undefined,
    }),
    onSuccess: () => {
      setIsCreateOpen(false)
      setSelectedItem(null)
      setItemId('')
      setBatchId('')
      queryClient.invalidateQueries({ queryKey: ['qc-inspections'] })
    },
  })

  const rawList = query.data?.content ?? []
  const filtered = rawList.filter((insp) => {
    if (!search.trim()) return true
    const q = search.toLowerCase()
    return insp.inspectionNumber.toLowerCase().includes(q) || (insp.itemName && insp.itemName.toLowerCase().includes(q))
  })

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Quality & Compliance"
        title="QC Inspections"
        description="Incoming raw material verification, in-process parameter testing, and batch disposition audits."
        actions={
          <div className="table-actions">
            <Link to="/qc-templates">
              <Button variant="secondary">
                <Layers aria-hidden="true" size={16} />
                QC Templates
              </Button>
            </Link>
            <Button onClick={() => setIsCreateOpen(true)} variant="primary">
              <Plus aria-hidden="true" size={16} />
              New Inspection
            </Button>
          </div>
        }
      />

      <div className="list-toolbar">
        <label className="directory-search">
          <Search aria-hidden="true" size={18} />
          <span className="sr-only">Search inspections</span>
          <input
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by inspection # or item..."
            type="search"
            value={search}
          />
        </label>
      </div>

      {query.isLoading ? (
        <div className="directory-state">Loading QC inspections...</div>
      ) : filtered.length === 0 ? (
        <div className="directory-state">
          <ShieldCheck size={24} />
          <strong>No QC inspections found.</strong>
        </div>
      ) : (
        <DataTable caption="Quality inspection audits">
          <thead>
            <tr>
              <th scope="col">Inspection #</th>
              <th scope="col">Item</th>
              <th scope="col">Type</th>
              <th className="numeric-cell" scope="col">Inspected Qty</th>
              <th className="numeric-cell" scope="col">Accepted / Rejected</th>
              <th scope="col">Disposition</th>
              <th scope="col">Status</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((insp) => (
              <tr key={insp.id}>
                <td>
                  <Link className="table-row-link" to={appRoutes.qcInspectionDetail(insp.id)}>
                    {insp.inspectionNumber}
                  </Link>
                </td>
                <td><strong>{insp.itemName || insp.itemId}</strong></td>
                <td><code>{insp.inspectionType}</code></td>
                <td className="numeric-cell"><Quantity value={insp.inspectedQty} /></td>
                <td className="numeric-cell">
                  <span className="text-success">{insp.acceptedQty ?? 0}</span> / <span className="text-danger">{insp.rejectedQty ?? 0}</span>
                </td>
                <td>
                  {insp.disposition ? (
                    <span className={insp.disposition === 'ACCEPT' ? 'status-badge status-badge--success' : 'status-badge status-badge--danger'}>
                      {insp.disposition}
                    </span>
                  ) : <span className="cell-muted">Pending</span>}
                </td>
                <td><StatusChip status={formatStatusLabel(insp.status)} /></td>
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
              disabled={createMutation.isPending || !itemId.trim()}
              onClick={() => createMutation.mutate()}
              variant="primary"
            >
              {createMutation.isPending ? 'Initiating...' : 'Initiate Inspection'}
            </Button>
          </>
        }
        isOpen={isCreateOpen}
        onClose={() => setIsCreateOpen(false)}
        size="md"
        title="Initiate QC Inspection"
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <FormField label="Item to Inspect" required>
            <EntityPicker<Item>
              ariaLabel="Item to Inspect"
              getOptionDescription={(item) => `${item.sku || 'No SKU'} · ${item.unitOfMeasure || 'unit'}`}
              getOptionId={(item) => item.id}
              getOptionLabel={(item) => item.name}
              onChange={(_id, item) => {
                setSelectedItem(item ?? null)
                setItemId(item?.id ?? '')
              }}
              onSearch={async (query) => {
                const res = await listItems({ search: query, activeOnly: true, size: 25 })
                return res.content
              }}
              placeholder="Search item to inspect..."
              selectedEntity={selectedItem}
              value={selectedItem?.id ?? null}
            />
          </FormField>

          <FormField label="Inspection Stage" required>
            <SelectInput
              aria-label="Inspection Stage"
              onChange={(e) => setInspectionType(e.target.value)}
              value={inspectionType}
            >
              <option value="INBOUND_GRN">Inbound Goods Receipt (GRN)</option>
              <option value="IN_PROCESS">In-Process Production Audit</option>
              <option value="FINAL_RELEASE">Final Finished Goods Release</option>
            </SelectInput>
          </FormField>

          <FormField label="Batch / Lot Number (Optional)">
            <TextInput
              onChange={(e) => setBatchId(e.target.value)}
              placeholder="e.g. BATCH-2026-09"
              value={batchId}
            />
          </FormField>

          <FormField label="Sample Inspection Quantity" required>
            <NumberInput
              min={1}
              onChange={(e) => setInspectedQty(e.target.value)}
              required
              value={inspectedQty}
            />
          </FormField>
        </div>
      </Modal>
    </section>
  )
}