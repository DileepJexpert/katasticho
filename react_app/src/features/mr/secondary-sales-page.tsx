import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  FileSpreadsheet,
  Plus,
  X,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import {
  listStockistStatements,
  saveStockistStatement,
  type StockistSalesStatement,
} from '@/features/field-sales/field-sales-api'

export function SecondarySalesPage() {
  const [isRecordOpen, setIsRecordOpen] = useState(false)
  const queryClient = useQueryClient()

  const { data: statements = [], isLoading, isError } = useQuery({
    queryKey: ['mr', 'secondary-sales'],
    queryFn: () => listStockistStatements(),
  })

  const createMutation = useMutation({
    mutationFn: saveStockistStatement,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['mr', 'secondary-sales'] })
      setIsRecordOpen(false)
    },
  })

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <Button onClick={() => setIsRecordOpen(true)} type="button" variant="primary">
            <Plus aria-hidden="true" size={16} />
            <span>Record Stockist Statement</span>
          </Button>
        }
        description="Stockist secondary sales statements, opening/closing stock, and chemist off-take tracking."
        eyebrow="Stockist Distribution"
        title="Stockist Secondary Sales"
      />

      <div className="summary-strip">
        <div className="metric-cell">
          <span className="metric-label">Statements Logged</span>
          <strong className="metric-value">{statements.length}</strong>
        </div>
      </div>

      <div className="table-card">
        {isLoading ? (
          <div className="directory-state">Loading secondary sales statements...</div>
        ) : isError ? (
          <div className="directory-state directory-state--error">Failed to load secondary sales statements.</div>
        ) : statements.length === 0 ? (
          <div className="directory-state">
            <FileSpreadsheet aria-hidden="true" size={32} />
            <p>No secondary sales statements recorded. Enter monthly stockist sales statements.</p>
          </div>
        ) : (
          <DataTable caption="Stockist Secondary Sales Statements">
            <thead>
              <tr>
                <th scope="col">Period Month</th>
                <th scope="col">Stockist / Distributor</th>
                <th scope="col">Status</th>
                <th scope="col" style={{ textAlign: 'right' }}>Lines Count</th>
                <th scope="col">Notes</th>
              </tr>
            </thead>
            <tbody>
              {statements.map((s: StockistSalesStatement) => (
                <tr key={s.id}>
                  <td><strong>{s.periodMonth}</strong></td>
                  <td><strong>{s.stockistName || s.stockistContactId}</strong></td>
                  <td><StatusChip status={s.status} /></td>
                  <td style={{ textAlign: 'right' }}>{s.lines?.length || 0}</td>
                  <td>{s.notes || 'â€”'}</td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        )}
      </div>

      {isRecordOpen ? (
        <CreateStatementModal
          isPending={createMutation.isPending}
          onClose={() => setIsRecordOpen(false)}
          onSubmit={(payload) => createMutation.mutate(payload)}
        />
      ) : null}
    </section>
  )
}

function CreateStatementModal({
  onClose,
  onSubmit,
  isPending,
}: {
  onClose: () => void
  onSubmit: (payload: {
    stockistContactId: string
    periodMonth: string
    notes?: string
    lines: Array<{
      productName: string
      openingQty?: number
      purchaseQty?: number
      salesQty?: number
      returnQty?: number
      salesValue?: number
    }>
  }) => void
  isPending: boolean
}) {
  const [stockistContactId, setStockistContactId] = useState('')
  const [periodMonth, setPeriodMonth] = useState(new Date().toISOString().slice(0, 7) + '-01')
  const [productName, setProductName] = useState('Paracetamol 650mg')
  const [salesQty, setSalesQty] = useState(500)
  const [salesValue, setSalesValue] = useState(25000)
  const [notes, setNotes] = useState('')

  return (
    <div className="modal-backdrop">
      <div className="modal-card" style={{ maxWidth: 460 }}>
        <div className="modal-header">
          <h2 className="modal-title">Record Secondary Sales Statement</h2>
          <button aria-label="Close" className="button button--ghost" onClick={onClose} type="button">
            <X aria-hidden="true" size={18} />
          </button>
        </div>

        <form
          onSubmit={(e) => {
            e.preventDefault()
            onSubmit({
              stockistContactId,
              periodMonth,
              notes: notes || undefined,
              lines: [
                { productName, salesQty, salesValue },
              ],
            })
          }}
        >
          <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              <div className="form-field">
                <label className="form-label" htmlFor="stk-id">Stockist Contact UUID *</label>
                <input
                  className="form-input"
                  id="stk-id"
                  onChange={(e) => setStockistContactId(e.target.value)}
                  placeholder="Stockist UUID"
                  required
                  value={stockistContactId}
                />
              </div>

              <div className="form-field">
                <label className="form-label" htmlFor="stk-mo">Month *</label>
                <input
                  className="form-input"
                  id="stk-mo"
                  onChange={(e) => setPeriodMonth(e.target.value)}
                  required
                  type="date"
                  value={periodMonth}
                />
              </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: 12 }}>
              <div className="form-field">
                <label className="form-label" htmlFor="stk-pname">Product Name *</label>
                <input
                  className="form-input"
                  id="stk-pname"
                  onChange={(e) => setProductName(e.target.value)}
                  placeholder="Item Name"
                  required
                  value={productName}
                />
              </div>

              <div className="form-field">
                <label className="form-label" htmlFor="stk-sqty">Sales Qty *</label>
                <input
                  className="form-input"
                  id="stk-sqty"
                  min={0}
                  onChange={(e) => setSalesQty(parseInt(e.target.value, 10) || 0)}
                  required
                  type="number"
                  value={salesQty}
                />
              </div>
            </div>

            <div className="form-field">
              <label className="form-label" htmlFor="stk-sval">Sales Value â‚¹ *</label>
              <input
                className="form-input"
                id="stk-sval"
                min={0}
                onChange={(e) => setSalesValue(parseFloat(e.target.value) || 0)}
                required
                type="number"
                value={salesValue}
              />
            </div>

            <div className="form-field">
              <label className="form-label" htmlFor="stk-rem">Remarks</label>
              <textarea
                className="form-input"
                id="stk-rem"
                onChange={(e) => setNotes(e.target.value)}
                placeholder="Statement notes..."
                rows={2}
                value={notes}
              />
            </div>
          </div>

          <div className="modal-footer">
            <Button onClick={onClose} type="button" variant="secondary">Cancel</Button>
            <Button disabled={isPending || !stockistContactId} type="submit" variant="primary">
              {isPending ? 'Saving...' : 'Save Statement'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  )
}
