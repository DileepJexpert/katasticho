import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  Building2,
  RefreshCw,
  CheckCircle2,
  Layers,
  Edit2,
} from 'lucide-react'
import { Link } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import {
  listTaxAccountMappings,
  updateTaxAccountMappings,
  resetTaxAccountMappings,
  listTaxGroups,
  type TaxAccountMapping,
} from '@/features/tax/tds-tcs-api'
import { listAccounts } from '@/features/accounts/accounts-api'

type TabKey = 'mappings' | 'groups'

export function TaxAccountMappingsPage() {
  const queryClient = useQueryClient()
  const [activeTab, setActiveTab] = useState<TabKey>('mappings')
  const [feedback, setFeedback] = useState<string | null>(null)

  // Edit Modal State
  const [isEditOpen, setIsEditOpen] = useState(false)
  const [editingMapping, setEditingMapping] = useState<TaxAccountMapping | null>(null)
  const [selectedOutputAccountId, setSelectedOutputAccountId] = useState('')
  const [selectedInputAccountId, setSelectedInputAccountId] = useState('')

  // Queries
  const mappingsQuery = useQuery({
    queryKey: ['tax-account-mappings'],
    queryFn: () => listTaxAccountMappings(),
  })

  const taxGroupsQuery = useQuery({
    queryKey: ['tax-groups'],
    queryFn: () => listTaxGroups(),
    enabled: activeTab === 'groups',
  })

  const accountsQuery = useQuery({
    queryKey: ['accounts-dropdown'],
    queryFn: () => listAccounts(),
  })

  // Mutations
  const updateMutation = useMutation({
    mutationFn: (mappings: Array<{ taxRateId: string; glOutputAccountId?: string | null; glInputAccountId?: string | null }>) =>
      updateTaxAccountMappings(mappings),
    onSuccess: () => {
      setIsEditOpen(false)
      setEditingMapping(null)
      queryClient.invalidateQueries({ queryKey: ['tax-account-mappings'] })
      setFeedback('Tax GL account mapping updated successfully.')
    },
  })

  const resetMutation = useMutation({
    mutationFn: () => resetTaxAccountMappings(),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tax-account-mappings'] })
      setFeedback('Tax GL account mappings reset to statutory Chart of Accounts defaults.')
    },
  })

  const mappings = mappingsQuery.data ?? []
  const taxGroups = taxGroupsQuery.data ?? []
  const accounts = accountsQuery.data ?? []

  const handleOpenEdit = (mapping: TaxAccountMapping) => {
    setEditingMapping(mapping)
    setSelectedOutputAccountId(mapping.glOutputAccountId || '')
    setSelectedInputAccountId(mapping.glInputAccountId || '')
    setIsEditOpen(true)
  }

  const handleSaveEdit = () => {
    if (!editingMapping) return
    updateMutation.mutate([
      {
        taxRateId: editingMapping.taxRateId,
        glOutputAccountId: selectedOutputAccountId || null,
        glInputAccountId: selectedInputAccountId || null,
      },
    ])
  }

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Settings / Taxes & Compliance"
        title="Tax Configuration & GL Mappings"
        description="Statutory GST/VAT rates, Tax Groups, and double-entry General Ledger input/output tax account bindings."
        actions={
          <div className="table-actions">
            <Button
              disabled={resetMutation.isPending}
              onClick={() => {
                if (confirm('Reset all tax account mappings to system defaults?')) {
                  resetMutation.mutate()
                }
              }}
              variant="secondary"
            >
              <RefreshCw size={15} />
              Reset to Defaults
            </Button>
            <Link to="/compliance/tds">
              <Button variant="secondary">
                TDS Register
              </Button>
            </Link>
          </div>
        }
      />

      {feedback && (
        <div className="feedback-alert feedback-alert--success" role="status">
          <CheckCircle2 size={16} />
          <span>{feedback}</span>
          <button className="feedback-alert__close" onClick={() => setFeedback(null)} type="button">×</button>
        </div>
      )}

      <div className="list-tabs" role="tablist">
        <button
          aria-selected={activeTab === 'mappings'}
          className={activeTab === 'mappings' ? 'list-tab list-tab--active' : 'list-tab'}
          onClick={() => setActiveTab('mappings')}
          role="tab"
          type="button"
        >
          <Building2 size={15} style={{ marginRight: '6px' }} />
          Tax GL Account Bindings ({mappings.length})
        </button>
        <button
          aria-selected={activeTab === 'groups'}
          className={activeTab === 'groups' ? 'list-tab list-tab--active' : 'list-tab'}
          onClick={() => setActiveTab('groups')}
          role="tab"
          type="button"
        >
          <Layers size={15} style={{ marginRight: '6px' }} />
          Active Tax Groups ({taxGroups.length})
        </button>
      </div>

      {activeTab === 'mappings' && (
        <section className="document-card" style={{ marginTop: '16px' }}>
          <h2>Tax Rate to General Ledger Account Mappings</h2>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginBottom: '16px' }}>
            Output Tax accounts credit on sales invoices. Input Tax accounts debit on vendor bills (ITC).
          </p>

          {mappingsQuery.isLoading ? (
            <div className="directory-state">Loading tax account bindings...</div>
          ) : (
            <DataTable caption="Tax rate GL bindings">
              <thead>
                <tr>
                  <th scope="col">Tax Rate Name</th>
                  <th scope="col">Code</th>
                  <th className="numeric-cell" scope="col">Rate %</th>
                  <th scope="col">Tax Type</th>
                  <th scope="col">Output Tax Account (Sales / CR)</th>
                  <th scope="col">Input Tax Account (Purchases / DR)</th>
                  <th scope="col">Status</th>
                  <th scope="col">Action</th>
                </tr>
              </thead>
              <tbody>
                {mappings.map((m) => (
                  <tr key={m.taxRateId}>
                    <td><strong>{m.name}</strong></td>
                    <td className="font-mono">{m.rateCode}</td>
                    <td className="numeric-cell">{m.percentage}%</td>
                    <td><span className="status-badge status-badge--info">{m.taxType}</span></td>
                    <td>
                      {m.glOutputAccountCode ? (
                        <span><strong>{m.glOutputAccountCode}</strong> - {m.glOutputAccountName}</span>
                      ) : (
                        <span className="cell-muted">None</span>
                      )}
                    </td>
                    <td>
                      {m.glInputAccountCode ? (
                        <span><strong>{m.glInputAccountCode}</strong> - {m.glInputAccountName}</span>
                      ) : (
                        <span className="cell-muted">{m.recoverable ? 'None' : 'Non-recoverable'}</span>
                      )}
                    </td>
                    <td>
                      <StatusChip status={m.customized ? 'CUSTOM' : 'DEFAULT'} />
                    </td>
                    <td>
                      <Button onClick={() => handleOpenEdit(m)} variant="secondary">
                        <Edit2 size={14} />
                        Edit Mapping
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          )}
        </section>
      )}

      {activeTab === 'groups' && (
        <section className="document-card" style={{ marginTop: '16px' }}>
          <h2>Configured Tax Groups</h2>
          <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginBottom: '16px' }}>
            Composite tax groups bundled for intra-state (CGST + SGST) and inter-state (IGST) line item calculations.
          </p>

          {taxGroupsQuery.isLoading ? (
            <div className="directory-state">Loading tax groups...</div>
          ) : (
            <DataTable caption="Active tax groups">
              <thead>
                <tr>
                  <th scope="col">Tax Group Name</th>
                  <th scope="col">Description</th>
                  <th scope="col">Components</th>
                  <th scope="col">Status</th>
                </tr>
              </thead>
              <tbody>
                {taxGroups.map((g) => (
                  <tr key={g.id}>
                    <td><strong>{g.name}</strong></td>
                    <td>{g.description || '—'}</td>
                    <td>
                      <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap' }}>
                        {g.rates && g.rates.length > 0 ? (
                          g.rates.map((r, i) => (
                            <span className="status-badge status-badge--info" key={i}>
                              {r.name} ({r.percentage}%)
                            </span>
                          ))
                        ) : (
                          <span className="cell-muted">No child rates</span>
                        )}
                      </div>
                    </td>
                    <td>
                      <StatusChip status={g.active ? 'ACTIVE' : 'INACTIVE'} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          )}
        </section>
      )}

      {/* Edit Account Mapping Modal */}
      {isEditOpen && editingMapping && (
        <div className="modal-backdrop">
          <div className="modal-card">
            <h3>Edit GL Account Mapping: {editingMapping.name}</h3>
            <p style={{ fontSize: '13px', color: 'var(--text-muted)' }}>
              Rate: {editingMapping.percentage}% · Code: {editingMapping.rateCode}
            </p>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '14px', marginTop: '14px' }}>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Output Tax Account (CR on Sales):</span>
                <select
                  className="search-input"
                  onChange={(e) => setSelectedOutputAccountId(e.target.value)}
                  style={{ width: '100%', marginTop: '4px' }}
                  value={selectedOutputAccountId}
                >
                  <option value="">Select GL Account</option>
                  {accounts.map((acc) => (
                    <option key={acc.id} value={acc.id}>
                      {acc.code} - {acc.name} ({acc.accountType})
                    </option>
                  ))}
                </select>
              </label>

              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Input Tax Account (DR on Purchases / ITC):</span>
                <select
                  className="search-input"
                  onChange={(e) => setSelectedInputAccountId(e.target.value)}
                  style={{ width: '100%', marginTop: '4px' }}
                  value={selectedInputAccountId}
                >
                  <option value="">Select GL Account</option>
                  {accounts.map((acc) => (
                    <option key={acc.id} value={acc.id}>
                      {acc.code} - {acc.name} ({acc.accountType})
                    </option>
                  ))}
                </select>
              </label>
            </div>

            <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end', marginTop: '18px' }}>
              <Button onClick={() => setIsEditOpen(false)} variant="secondary">Cancel</Button>
              <Button
                disabled={updateMutation.isPending}
                onClick={handleSaveEdit}
                variant="primary"
              >
                Save Mapping
              </Button>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}
