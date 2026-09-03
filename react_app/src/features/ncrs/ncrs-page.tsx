import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { ShieldAlert, Plus, Search, Layers } from 'lucide-react'
import { Link } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
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

      {isCreateOpen && (
        <div className="modal-backdrop">
          <div className="modal-card">
            <h3>Raise Non-Conformance Report</h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginTop: '12px' }}>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Defective Item ID:</span>
                <input
                  className="search-input"
                  onChange={(e) => setItemId(e.target.value)}
                  placeholder="Item UUID"
                  style={{ width: '100%', marginTop: '4px' }}
                  value={itemId}
                />
              </label>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Defect Severity:</span>
                <select
                  className="search-input"
                  onChange={(e) => setSeverity(e.target.value)}
                  style={{ width: '100%', marginTop: '4px' }}
                  value={severity}
                >
                  <option value="MINOR">Minor</option>
                  <option value="MAJOR">Major</option>
                  <option value="CRITICAL">Critical</option>
                </select>
              </label>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Defect Reason:</span>
                <input
                  className="search-input"
                  onChange={(e) => setReason(e.target.value)}
                  placeholder="e.g. Seal failure during blister packing"
                  style={{ width: '100%', marginTop: '4px' }}
                  value={reason}
                />
              </label>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Description & Root Cause Observation:</span>
                <textarea
                  className="search-input"
                  onChange={(e) => setDesc(e.target.value)}
                  placeholder="Detailed inspection findings..."
                  rows={2}
                  style={{ width: '100%', marginTop: '4px' }}
                  value={desc}
                />
              </label>
            </div>
            <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end', marginTop: '16px' }}>
              <Button onClick={() => setIsCreateOpen(false)} variant="secondary">Cancel</Button>
              <Button
                disabled={createMutation.isPending || !itemId.trim()}
                onClick={() => createMutation.mutate()}
                variant="primary"
              >
                Raise NCR
              </Button>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}