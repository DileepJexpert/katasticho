import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  Gift,
  Plus,
  X,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { Quantity } from '@/design-system/quantity'
import {
  issueSamples,
  listMySampleBalances,
} from '@/features/field-sales/field-sales-api'

export function FieldSamplesPage() {
  const [isIssueOpen, setIsIssueOpen] = useState(false)
  const queryClient = useQueryClient()

  const { data: samples = [], isLoading, isError } = useQuery({
    queryKey: ['mr', 'samples'],
    queryFn: () => listMySampleBalances(),
  })

  const issueMutation = useMutation({
    mutationFn: issueSamples,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['mr', 'samples'] })
      setIsIssueOpen(false)
    },
  })

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <Button onClick={() => setIsIssueOpen(true)} type="button" variant="primary">
            <Plus aria-hidden="true" size={16} />
            <span>Issue Samples to Rep</span>
          </Button>
        }
        description="Physician sample inventory, promotional inputs, batch gifting, and rep allocation ledger."
        eyebrow="Pharma Sample Management"
        title="Physician Samples & Promotional Inputs"
      />

      <div className="summary-strip">
        <div className="metric-cell">
          <span className="metric-label">Sample Products in Hand</span>
          <strong className="metric-value">{samples.length}</strong>
        </div>
      </div>

      <div className="table-card">
        {isLoading ? (
          <div className="directory-state">Loading physician samples...</div>
        ) : isError ? (
          <div className="directory-state directory-state--error">Failed to load samples ledger.</div>
        ) : samples.length === 0 ? (
          <div className="directory-state">
            <Gift aria-hidden="true" size={32} />
            <p>No physician samples issued. Issue doctor sample stock to medical representatives.</p>
          </div>
        ) : (
          <DataTable caption="Sample Balances Ledger">
            <thead>
              <tr>
                <th scope="col">Product Sample Name</th>
                <th scope="col" style={{ textAlign: 'right' }}>On-Hand Balance</th>
              </tr>
            </thead>
            <tbody>
              {samples.map((s, idx) => (
                <tr key={idx}>
                  <td><strong>{s.productName}</strong></td>
                  <td style={{ textAlign: 'right' }}>
                    <strong><Quantity unit="units" value={s.balance} /></strong>
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        )}
      </div>

      {isIssueOpen ? (
        <IssueSampleModal
          isPending={issueMutation.isPending}
          onClose={() => setIsIssueOpen(false)}
          onSubmit={(payload) => issueMutation.mutate(payload)}
        />
      ) : null}
    </section>
  )
}

function IssueSampleModal({
  onClose,
  onSubmit,
  isPending,
}: {
  onClose: () => void
  onSubmit: (payload: { salespersonId: string; productName: string; quantity: number; notes?: string }) => void
  isPending: boolean
}) {
  const [salespersonId, setSalespersonId] = useState('')
  const [productName, setProductName] = useState('')
  const [quantity, setQuantity] = useState(50)
  const [notes, setNotes] = useState('')

  return (
    <div className="modal-backdrop">
      <div className="modal-card" style={{ maxWidth: 440 }}>
        <div className="modal-header">
          <h2 className="modal-title">Issue Physician Samples</h2>
          <button aria-label="Close" className="button button--ghost" onClick={onClose} type="button">
            <X aria-hidden="true" size={18} />
          </button>
        </div>

        <form
          onSubmit={(e) => {
            e.preventDefault()
            onSubmit({
              salespersonId,
              productName,
              quantity,
              notes: notes || undefined,
            })
          }}
        >
          <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div className="form-field">
              <label className="form-label" htmlFor="smp-sp">Medical Rep UUID *</label>
              <input
                className="form-input"
                id="smp-sp"
                onChange={(e) => setSalespersonId(e.target.value)}
                placeholder="Salesperson User UUID"
                required
                value={salespersonId}
              />
            </div>

            <div className="form-field">
              <label className="form-label" htmlFor="smp-prod">Product Sample Name *</label>
              <input
                className="form-input"
                id="smp-prod"
                onChange={(e) => setProductName(e.target.value)}
                placeholder="Atorva 10mg Physician Sample Pack"
                required
                value={productName}
              />
            </div>

            <div className="form-field">
              <label className="form-label" htmlFor="smp-qty">Qty (Units) *</label>
              <input
                className="form-input"
                id="smp-qty"
                min={1}
                onChange={(e) => setQuantity(parseInt(e.target.value, 10) || 1)}
                required
                type="number"
                value={quantity}
              />
            </div>

            <div className="form-field">
              <label className="form-label" htmlFor="smp-notes">Remarks</label>
              <textarea
                className="form-input"
                id="smp-notes"
                onChange={(e) => setNotes(e.target.value)}
                placeholder="Cycle launch allocation..."
                rows={2}
                value={notes}
              />
            </div>
          </div>

          <div className="modal-footer">
            <Button onClick={onClose} type="button" variant="secondary">Cancel</Button>
            <Button disabled={isPending || !salespersonId || !productName} type="submit" variant="primary">
              {isPending ? 'Issuing...' : 'Issue Samples'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  )
}
