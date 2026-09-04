import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { Plus, ShieldAlert, Search } from 'lucide-react'
import {
  Button,
  DataTable,
  FormField,
  FormGrid,
  Modal,
  PageHeader,
  SelectInput,
  StatusChip,
  TextAreaInput,
  TextInput,
} from '@/design-system'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { listCapas, raiseCapa } from '@/features/capa/capa-api'

const statusTabs = [
  { key: 'all', label: 'All Actions' },
  { key: 'OPEN', label: 'Open' },
  { key: 'IN_PROGRESS', label: 'In Progress' },
  { key: 'COMPLETED', label: 'Completed' },
  { key: 'VERIFIED', label: 'Verified' },
  { key: 'CANCELLED', label: 'Cancelled' },
] as const

type StatusTab = (typeof statusTabs)[number]['key']

export function CapaPage() {
  const queryClient = useQueryClient()
  const [activeTab, setActiveTab] = useState<StatusTab>('all')
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(0)
  const [isRaiseOpen, setIsRaiseOpen] = useState(false)
  const [newTitle, setNewTitle] = useState('')
  const [newType, setNewType] = useState('CORRECTIVE')
  const [newPriority, setNewPriority] = useState('NORMAL')
  const [newDesc, setNewDesc] = useState('')
  const [newAction, setNewAction] = useState('')
  const [newDueDate, setNewDueDate] = useState('')

  const query = useQuery({
    queryKey: ['capas', page, activeTab],
    queryFn: () => listCapas({ page, status: activeTab }),
  })

  const raiseMutation = useMutation({
    mutationFn: () => raiseCapa({
      capaType: newType,
      title: newTitle,
      description: newDesc,
      proposedAction: newAction,
      priority: newPriority,
      dueDate: newDueDate || undefined,
    }),
    onSuccess: () => {
      setIsRaiseOpen(false)
      setNewTitle('')
      setNewDesc('')
      setNewAction('')
      setNewDueDate('')
      queryClient.invalidateQueries({ queryKey: ['capas'] })
    },
  })

  const rawList = query.data?.content ?? []
  const filtered = rawList.filter((c) => {
    if (!search.trim()) return true
    const q = search.toLowerCase()
    return c.capaNumber.toLowerCase().includes(q) || c.title.toLowerCase().includes(q)
  })

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Quality & Compliance"
        title="CAPA Management Hub"
        description="Corrective and Preventive Actions lifecycle tracking, root-cause resolution, and effectiveness verification."
        actions={
          <div className="table-actions">
            <Button onClick={() => setIsRaiseOpen(true)} variant="primary">
              <Plus aria-hidden="true" size={16} />
              Raise CAPA
            </Button>
          </div>
        }
      />

      <div className="list-toolbar">
        <label className="directory-search">
          <Search aria-hidden="true" size={18} />
          <span className="sr-only">Search CAPAs</span>
          <input
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by CAPA number or title..."
            type="search"
            value={search}
          />
        </label>
        <div className="list-tabs" role="tablist">
          {statusTabs.map((tab) => (
            <button
              aria-selected={activeTab === tab.key}
              className={activeTab === tab.key ? 'list-tab list-tab--active' : 'list-tab'}
              key={tab.key}
              onClick={() => {
                setActiveTab(tab.key)
                setPage(0)
              }}
              role="tab"
              type="button"
            >
              {tab.label}
            </button>
          ))}
        </div>
      </div>

      {query.isLoading ? (
        <div className="directory-state">Loading CAPA records...</div>
      ) : filtered.length === 0 ? (
        <div className="directory-state">
          <ShieldAlert aria-hidden="true" size={24} />
          <strong>No CAPA actions found.</strong>
        </div>
      ) : (
        <DataTable caption="Corrective and Preventive Action records">
          <thead>
            <tr>
              <th scope="col">CAPA #</th>
              <th scope="col">Type</th>
              <th scope="col">Title & Remediation</th>
              <th scope="col">Priority</th>
              <th scope="col">Due Date</th>
              <th scope="col">Status</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((capa) => (
              <tr key={capa.id}>
                <td>
                  <code>{capa.capaNumber}</code>
                </td>
                <td>
                  <span className={capa.capaType === 'CORRECTIVE' ? 'status-badge status-badge--danger' : 'status-badge status-badge--info'}>
                    {capa.capaType}
                  </span>
                </td>
                <td>
                  <div className="cell-stack">
                    <strong>{capa.title}</strong>
                    {capa.proposedAction && <span className="cell-muted">{capa.proposedAction}</span>}
                  </div>
                </td>
                <td>
                  <span className={capa.priority === 'URGENT' ? 'status-badge status-badge--danger' : 'cell-muted'}>
                    {capa.priority}
                  </span>
                </td>
                <td>{formatDate(capa.dueDate)}</td>
                <td>
                  <StatusChip status={formatStatusLabel(capa.status)} />
                </td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      )}

      <Modal
        footer={
          <>
            <Button onClick={() => setIsRaiseOpen(false)} variant="secondary">Cancel</Button>
            <Button
              disabled={raiseMutation.isPending || !newTitle.trim()}
              onClick={() => raiseMutation.mutate()}
              variant="primary"
            >
              {raiseMutation.isPending ? 'Raising...' : 'Raise CAPA Action'}
            </Button>
          </>
        }
        isOpen={isRaiseOpen}
        onClose={() => setIsRaiseOpen(false)}
        size="lg"
        title="Raise CAPA Action"
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <FormGrid columns={2}>
            <FormField label="CAPA Type">
              <SelectInput
                onChange={(e) => setNewType(e.target.value)}
                value={newType}
              >
                <option value="CORRECTIVE">Corrective Action (NCR Defect)</option>
                <option value="PREVENTIVE">Preventive Action (Risk Mitigation)</option>
              </SelectInput>
            </FormField>
            <FormField label="Priority">
              <SelectInput
                onChange={(e) => setNewPriority(e.target.value)}
                value={newPriority}
              >
                <option value="NORMAL">Normal</option>
                <option value="HIGH">High</option>
                <option value="URGENT">Urgent</option>
              </SelectInput>
            </FormField>
          </FormGrid>

          <FormField label="Title" required>
            <TextInput
              onChange={(e) => setNewTitle(e.target.value)}
              placeholder="e.g. Calibrate filling nozzle after seal defect"
              required
              value={newTitle}
            />
          </FormField>

          <FormField label="Target Resolution Date">
            <TextInput
              onChange={(e) => setNewDueDate(e.target.value)}
              type="date"
              value={newDueDate}
            />
          </FormField>

          <FormField label="Proposed Action / Remediation">
            <TextAreaInput
              onChange={(e) => setNewAction(e.target.value)}
              placeholder="Detailed corrective actions required..."
              rows={3}
              value={newAction}
            />
          </FormField>
        </div>
      </Modal>
    </section>
  )
}