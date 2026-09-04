import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { ShieldAlert, Plus, Search, Layers } from 'lucide-react'
import { Link } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
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
import { listNcrs, createNcr } from '@/features/ncrs/ncrs-api'

const statusTabs = [
  { key: 'all', label: 'All NCRs' },
  { key: 'OPEN', label: 'Open' },
  { key: 'INVESTIGATING', label: 'Investigating' },
  { key: 'CAPA_RAISED', label: 'CAPA Raised' },
  { key: 'CLOSED', label: 'Closed' },
] as const

type StatusTab = (typeof statusTabs)[number]['key']

export function NcrsPage() {
  const queryClient = useQueryClient()
  const [activeTab, setActiveTab] = useState<StatusTab>('all')
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(0)
  const [isCreateOpen, setIsCreateOpen] = useState(false)
  const [itemId, setItemId] = useState('')
  const [severity, setSeverity] = useState('MAJOR')
  const [reason, setReason] = useState('')
  const [desc, setDesc] = useState('')

  const query = useQuery({
    queryKey: ['ncrs', page, activeTab],
    queryFn: () => listNcrs({ page, status: activeTab }),
  })

  const createMutation = useMutation({
    mutationFn: () => createNcr({
      itemId,
      severity,
      reason,
      description: desc,
    }),
    onSuccess: () => {
      setIsCreateOpen(false)
      setItemId('')
      setReason('')
      setDesc('')
      queryClient.invalidateQueries({ queryKey: ['ncrs'] })
    },
  })

  const rawList = query.data?.content ?? []
  const filtered = rawList.filter((n) => {
    if (!search.trim()) return true
    const q = search.toLowerCase()
    return n.ncrNumber.toLowerCase().includes(q) || (n.itemName && n.itemName.toLowerCase().includes(q))
  })

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Quality & Compliance"
        title="Non-Conformance Reports (NCR)"
        description="Defect logging, root-cause investigations, material quarantine, and CAPA remediation."
        actions={
          <div className="table-actions">
            <Link to="/capa">
              <Button variant="secondary">
                <Layers aria-hidden="true" size={16} />
                CAPA Hub
              </Button>
            </Link>
            <Button onClick={() => setIsCreateOpen(true)} variant="primary">
              <Plus aria-hidden="true" size={16} />
              Raise NCR
            </Button>
          </div>
        }
      />

      <div className="list-toolbar">
        <label className="directory-search">
          <Search aria-hidden="true" size={18} />
          <span className="sr-only">Search NCRs</span>
          <input
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by NCR # or item..."
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
        <div className="directory-state">Loading non-conformance reports...</div>
      ) : filtered.length === 0 ? (
        <div className="directory-state">
          <ShieldAlert size={24} />
          <strong>No NCRs found.</strong>
        </div>
      ) : (
        <DataTable caption="Non-conformance reports">
          <thead>
            <tr>
              <th scope="col">NCR #</th>
              <th scope="col">Item</th>
              <th scope="col">Severity</th>
              <th scope="col">Defect Reason</th>
              <th scope="col">Date</th>
              <th scope="col">Status</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((ncr) => (
              <tr key={ncr.id}>
                <td>
                  <Link className="table-row-link" to={appRoutes.ncrDetail(ncr.id)}>
                    {ncr.ncrNumber}
                  </Link>
                </td>
                <td><strong>{ncr.itemName || ncr.itemId}</strong></td>
                <td>
                  <span className={ncr.severity === 'CRITICAL' ? 'status-badge status-badge--danger' : 'status-badge status-badge--warning'}>
                    {ncr.severity}
                  </span>
                </td>
                <td>{ncr.reason || '--'}</td>
                <td>{formatDate(ncr.createdAt)}</td>
                <td><StatusChip status={formatStatusLabel(ncr.status)} /></td>
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
              {createMutation.isPending ? 'Raising...' : 'Raise NCR'}
            </Button>
          </>
        }
        isOpen={isCreateOpen}
        onClose={() => setIsCreateOpen(false)}
        size="lg"
        title="Raise Non-Conformance Report"
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <FormGrid columns={2}>
            <FormField label="Defective Item ID" required>
              <TextInput
                onChange={(e) => setItemId(e.target.value)}
                placeholder="Item UUID"
                required
                value={itemId}
              />
            </FormField>
            <FormField label="Defect Severity">
              <SelectInput
                onChange={(e) => setSeverity(e.target.value)}
                value={severity}
              >
                <option value="MINOR">Minor</option>
                <option value="MAJOR">Major</option>
                <option value="CRITICAL">Critical</option>
              </SelectInput>
            </FormField>
          </FormGrid>

          <FormField label="Defect Reason">
            <TextInput
              onChange={(e) => setReason(e.target.value)}
              placeholder="e.g. Seal failure during blister packing"
              value={reason}
            />
          </FormField>

          <FormField label="Description & Root Cause Observation">
            <TextAreaInput
              onChange={(e) => setDesc(e.target.value)}
              placeholder="Detailed inspection findings..."
              rows={2}
              value={desc}
            />
          </FormField>
        </div>
      </Modal>
    </section>
  )
}