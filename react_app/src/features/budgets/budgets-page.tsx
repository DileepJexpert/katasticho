import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Modal } from '@/design-system/modal'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { TextField } from '@/design-system/text-field'
import { useSessionStore } from '@/shared/session/session-store'
import { listAccounts } from '@/features/accounts/accounts-api'
import { getBudgetVariance, listBudget, saveBudget, type BudgetLine } from './budgets-api'

export function BudgetsPage() {
  const user = useSessionStore((s) => s.user)
  return <BudgetsPageWorkspace key={`${user?.orgId}:${user?.id}:${user?.role}`} />
}

function BudgetsPageWorkspace() {
  const user = useSessionStore((s) => s.user)
  const allowed = ['OWNER', 'ADMIN', 'ACCOUNTANT'].includes(user?.role ?? '')
  const now = new Date()
  const [fy, setFy] = useState(now.getFullYear() - (now.getMonth() < 3 ? 1 : 0))
  const [search, setSearch] = useState('')
  const [draft, setDraft] = useState<BudgetLine[] | null>(null)
  const client = useQueryClient()
  const key = ['budgets', user?.orgId, fy]
  const budget = useQuery({ queryKey: key, queryFn: () => listBudget(fy), enabled: allowed })
  const accounts = useQuery({ queryKey: ['budget-accounts', user?.orgId], queryFn: listAccounts, enabled: allowed })
  const variance = useQuery({ queryKey: ['budget-variance', user?.orgId, fy], queryFn: () => getBudgetVariance(fy), enabled: allowed })
  const save = useMutation({
    mutationFn: (lines: BudgetLine[]) => saveBudget(fy, lines),
    onSuccess: () => {
      client.invalidateQueries({ queryKey: key })
      client.invalidateQueries({ queryKey: ['budget-variance'] })
      setDraft(null)
    },
  })
  const lines = budget.data ?? []
  const filtered = lines.filter((l) => `${l.accountCode} ${l.accountName}`.toLowerCase().includes(search.toLowerCase()))
  function edit() {
    if (!budget.data || !accounts.data) return
    save.reset()
    // Preserve every persisted line and its notes, even zero/inactive/non-P&L accounts.
    const existing = new Set(lines.map((l) => l.accountCode))
    setDraft([
      ...lines.map((l) => ({ ...l })),
      ...accounts.data.filter((a) => a.isActive && !a.hasChildren && ['EXPENSE', 'REVENUE'].includes(a.type) && !existing.has(a.code))
        .map((a) => ({ accountCode: a.code, accountName: a.name, annualAmount: '', notes: null })),
    ])
  }
  const valid = draft?.every((l) => l.annualAmount === '' || (Number.isFinite(Number(l.annualAmount)) && Number(l.annualAmount) >= 0))
  if (!allowed) return <div className="directory-state" role="alert">Budgets require Owner, Admin, or Accountant access.</div>
  return <section className="workspace-page">
    <PageHeader eyebrow="Accounting" title="Budgets & Variance Analysis" description="Annual account budgets and actuals from the posted general ledger. Financial year runs April to March."
      actions={<Button onClick={edit} disabled={!budget.isSuccess || !accounts.isSuccess || budget.isFetching}>Configure Budget</Button>} />
    <div className="list-toolbar">
      <TextField label="Financial year starts" type="number" min={2000} max={9998} value={fy} onChange={(e) => { if (Number.isInteger(+e.target.value) && +e.target.value >= 2000 && +e.target.value <= 9998) setFy(+e.target.value) }} disabled={draft !== null} />
      <TextField label="Search accounts" placeholder="Search account code or name" value={search} onChange={(e) => setSearch(e.target.value)} />
    </div>
    {accounts.isError && <div role="alert">Account choices unavailable: {accounts.error.message}<Button onClick={() => accounts.refetch()}>Retry accounts</Button></div>}
    {budget.isPending ? <p role="status">Loading budgets...</p> : budget.isError ? <div className="banner banner--error" role="alert">{budget.error.message}<Button onClick={() => budget.refetch()}>Retry</Button></div> : <>
      <div className="summary-strip"><div className="summary-card"><span>Total Budgeted Limit</span><Money amount={lines.reduce((sum, l) => sum + Number(l.annualAmount), 0)} /></div></div>
      <DataTable caption="Annual budgets"><thead><tr><th>Code</th><th>Account</th><th className="numeric-cell">Annual amount</th><th>Notes</th></tr></thead>
        <tbody>{filtered.map((l) => <tr key={l.accountCode}><td className="table-code">{l.accountCode}</td><td>{l.accountName}</td><td className="numeric-cell"><Money amount={l.annualAmount} /></td><td>{l.notes || '-'}</td></tr>)}</tbody></DataTable>
      {!filtered.length && <p className="directory-state">No budget lines found.</p>}
    </>}
    <h2>Budget versus actual</h2>
    {variance.isPending ? <p role="status">Loading posted actuals...</p> : variance.isError ? <div role="alert" className="banner banner--error">Actuals unavailable: {variance.error.message}<Button onClick={() => variance.refetch()}>Retry actuals</Button></div> : <>
      <p className="cell-muted">{variance.data.description} Variance is actual minus budget; a positive revenue variance is not overspending.</p>
      <DataTable caption="Budget variance"><thead><tr><th>Account</th><th className="numeric-cell">Budget</th><th className="numeric-cell">Actual</th><th className="numeric-cell">Variance</th></tr></thead>
        <tbody>{variance.data.rows.map((r) => <tr key={r.code}><td>{r.code} - {r.account}</td><td className="numeric-cell"><Money amount={r.budget} /></td><td className="numeric-cell"><Money amount={r.actual} /></td><td className="numeric-cell"><Money amount={r.variance} /></td></tr>)}</tbody></DataTable>
    </>}
    <Modal isOpen={draft !== null} onClose={() => { if (!save.isPending) setDraft(null) }} title="Configure Operating Budget" size="lg" description="Saving replaces this financial year's budget. Existing lines and notes are retained; blank new lines are not added. Enter 0 to retain a zero budget." error={save.error?.message}
      footer={<><Button variant="secondary" disabled={save.isPending} onClick={() => setDraft(null)}>Cancel</Button><Button disabled={!valid || save.isPending} onClick={() => { if (draft && valid) save.mutate(draft.filter((l) => l.annualAmount !== '').map((l) => ({ ...l, annualAmount: Number(l.annualAmount) }))) }}>Save Budget Targets</Button></>}>
      <DataTable caption="Budget editor"><thead><tr><th>Account</th><th>Annual amount</th></tr></thead><tbody>{draft?.map((l, index) => <tr key={l.accountCode}><td>{l.accountCode} - {l.accountName}</td><td><TextField label={`Budget for ${l.accountCode}`} type="number" min="0" step="0.01" value={l.annualAmount} placeholder="0.00" onChange={(e) => setDraft(draft.map((row, i) => i === index ? { ...row, annualAmount: e.target.value === '' && lines.some((old) => old.accountCode === row.accountCode) ? 0 : e.target.value } : row))} /></td></tr>)}</tbody></DataTable>
    </Modal>
  </section>
}
