import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Plus } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { TextField } from '@/design-system/text-field'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import { createVendorCredit, listVendorCredits } from './vendor-credits-api'

export function VendorCreditsPage() {
  const [page] = useState(0)
  const [status, setStatus] = useState<string>('ALL')
  const [createModalOpen, setCreateModalOpen] = useState(false)
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const creditsQuery = useQuery({
    queryKey: ['vendor-credits', status, page],
    queryFn: () => listVendorCredits(status, undefined, page),
  })

  const [form, setForm] = useState({
    contactId: '',
    creditDate: new Date().toISOString().slice(0, 10),
    description: 'Vendor return credit adjustment',
    quantity: 1,
    unitPrice: 0,
    notes: '',
  })

  const createMutation = useMutation({
    mutationFn: () =>
      createVendorCredit({
        contactId: form.contactId,
        creditDate: form.creditDate,
        notes: form.notes,
        lines: [
          {
            description: form.description,
            quantity: Number(form.quantity),
            unitPrice: Number(form.unitPrice),
          },
        ],
      }),
    onSuccess: (newCredit) => {
      setCreateModalOpen(false)
      queryClient.invalidateQueries({ queryKey: ['vendor-credits'] })
      navigate(`/vendor-credits/${newCredit.id}`)
    },
  })

  const credits = creditsQuery.data?.content || []

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Purchases / Payables / Supplier Adjustments"
        title="Vendor Credits"
        description="Supplier debit notes and vendor credit balances available for bill offsetting"
        actions={
          <Button onClick={() => setCreateModalOpen(true)} variant="primary">
            <Plus size={16} />
            New Vendor Credit
          </Button>
        }
      />

      <div className="filter-chips">
        {['ALL', 'DRAFT', 'POSTED', 'APPLIED', 'PARTIALLY_APPLIED', 'VOIDED'].map((s) => (
          <button
            className={`filter-chip ${status === s ? 'filter-chip--active' : ''}`}
            key={s}
            onClick={() => setStatus(s)}
            type="button"
          >
            {s === 'ALL' ? 'All Credits' : formatStatusLabel(s)}
          </button>
        ))}
      </div>

      <section className="document-card">
        <h2>Vendor Credit Notes</h2>
        {creditsQuery.isLoading ? (
          <p className="document-loading">Loading vendor credits...</p>
        ) : credits.length === 0 ? (
          <p className="document-loading">No vendor credit notes found.</p>
        ) : (
          <DataTable caption="Vendor Credits list">
            <thead>
              <tr>
                <th scope="col">Credit #</th>
                <th scope="col">Vendor</th>
                <th scope="col">Date</th>
                <th scope="col">Status</th>
                <th className="numeric-cell" scope="col">Total Credit</th>
                <th className="numeric-cell" scope="col">Unapplied Amount</th>
                <th scope="col">Action</th>
              </tr>
            </thead>
            <tbody>
              {credits.map((c) => (
                <tr key={c.id}>
                  <td>
                    <strong>{c.creditNumber}</strong>
                  </td>
                  <td>{c.vendorName ?? 'Vendor'}</td>
                  <td>{formatDate(c.creditDate)}</td>
                  <td>
                    <StatusChip status={formatStatusLabel(c.status)} />
                  </td>
                  <td className="numeric-cell">
                    <Money amount={c.totalAmount} />
                  </td>
                  <td className="numeric-cell" style={{ fontWeight: 600, color: '#0F8576' }}>
                    <Money amount={c.unappliedAmount} />
                  </td>
                  <td>
                    <Button onClick={() => navigate(`/vendor-credits/${c.id}`)} variant="secondary">
                      View
                    </Button>
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        )}
      </section>

      {createModalOpen ? (
        <div className="modal-backdrop" style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100 }}>
          <div className="modal-dialog" style={{ background: '#fff', borderRadius: '8px', padding: '24px', maxWidth: '480px', width: '100%' }}>
            <h3>Create Vendor Credit</h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginTop: '16px' }}>
              <TextField
                label="Vendor Contact ID"
                onChange={(e) => setForm((f) => ({ ...f, contactId: e.target.value }))}
                placeholder="UUID of vendor contact"
                value={form.contactId}
              />
              <TextField
                label="Credit Date"
                onChange={(e) => setForm((f) => ({ ...f, creditDate: e.target.value }))}
                type="date"
                value={form.creditDate}
              />
              <TextField
                label="Description"
                onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
                value={form.description}
              />
              <TextField
                label="Quantity"
                onChange={(e) => setForm((f) => ({ ...f, quantity: Number(e.target.value) }))}
                type="number"
                value={String(form.quantity)}
              />
              <TextField
                label="Unit Price (₹)"
                onChange={(e) => setForm((f) => ({ ...f, unitPrice: Number(e.target.value) }))}
                type="number"
                value={String(form.unitPrice)}
              />
              <TextField
                label="Notes"
                onChange={(e) => setForm((f) => ({ ...f, notes: e.target.value }))}
                value={form.notes}
              />
              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px', marginTop: '8px' }}>
                <Button onClick={() => setCreateModalOpen(false)} variant="secondary">Cancel</Button>
                <Button
                  disabled={!form.contactId || createMutation.isPending}
                  onClick={() => createMutation.mutate()}
                  variant="primary"
                >
                  {createMutation.isPending ? 'Creating...' : 'Create Draft'}
                </Button>
              </div>
            </div>
          </div>
        </div>
      ) : null}
    </section>
  )
}
