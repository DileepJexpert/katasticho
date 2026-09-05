import { useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { Button, FormField, FormGrid, PageHeader, Quantity, SelectInput } from '@/design-system'
import { TextField } from '@/design-system/text-field'
import { useSessionStore } from '@/shared/session/session-store'
import { WorkspaceBoundary } from '@/shared/workflows/workspace-boundary'
import { QueryFeedback } from '@/shared/workflows/query-feedback'
import { ConfirmedAction } from '@/shared/workflows/confirmed-action'
import { LocalDirectory } from '@/shared/workflows/local-directory'
import { generateForecast, listForecasts, planningRoles } from './supply-chain-api'
import { PlanningItemName } from './planning-pickers'

export function ForecastsPage() { return <WorkspaceBoundary roles={planningRoles}><Forecasts /></WorkspaceBoundary> }
function Forecasts() {
  const orgId = useSessionStore((s) => s.user!.orgId)
  const initial = new Date().toISOString().slice(0, 10)
  const [from, setFrom] = useState(initial.slice(0, 8) + '01')
  const [to, setTo] = useState(initial.slice(0, 4) + '-12-31')
  const [range, setRange] = useState({ from, to })
  const [method, setMethod] = useState<'generate' | 'generate-seasonal' | 'generate-weighted'>('generate')
  const [ahead, setAhead] = useState('3')
  const [history, setHistory] = useState('6')
  const [confirm, setConfirm] = useState(false)
  const client = useQueryClient()
  const query = useQuery({ queryKey: ['supply', orgId, 'forecasts', range], queryFn: () => listForecasts(range.from, range.to) })
  const valid = (method === 'generate-seasonal' ? [ahead] : [ahead, history]).every((v) => Number.isInteger(+v) && +v >= 1 && +v <= 24)
  return <section className="workspace-page"><PageHeader eyebrow="Supply planning" title="Demand forecasts" description="Review persisted forecasts. Generation replaces forecast quantities for the selected future periods across the organisation." />
    <form onSubmit={(e) => { e.preventDefault(); if (from && to && from <= to) setRange({ from, to }) }}><FormGrid><TextField label="From" type="date" value={from} onChange={(e) => setFrom(e.target.value)} /><TextField label="To" type="date" value={to} onChange={(e) => setTo(e.target.value)} /><Button type="submit" disabled={!from || !to || from > to}>Apply range</Button></FormGrid></form>
    <FormGrid><FormField label="Forecast method"><SelectInput value={method} onChange={(e) => setMethod(e.target.value as typeof method)}><option value="generate">Moving average</option><option value="generate-seasonal">Seasonal</option><option value="generate-weighted">Weighted average</option></SelectInput></FormField><TextField label="Months ahead" type="number" min="1" max="24" value={ahead} onChange={(e) => setAhead(e.target.value)} />{method !== 'generate-seasonal' && <TextField label="History months" type="number" min="1" max="24" value={history} onChange={(e) => setHistory(e.target.value)} />}<Button disabled={!valid} onClick={() => setConfirm(true)}>Generate forecasts</Button></FormGrid>
    <QueryFeedback query={query}><LocalDirectory rows={query.data ?? []} caption="Demand forecasts" searchText={(f) => `${f.forecastMonth} ${f.method}`} header={<tr><th>Item</th><th>Month</th><th>Method</th><th className="numeric-cell">Forecast quantity</th><th className="numeric-cell">Actual quantity</th></tr>} renderRow={(f) => <tr key={f.id}><td><PlanningItemName id={f.itemId} /></td><td>{f.forecastMonth}</td><td>{f.method}</td><td className="numeric-cell"><Quantity value={f.forecastQty} /></td><td className="numeric-cell"><Quantity value={f.actualQty} /></td></tr>} /></QueryFeedback>
    {confirm && <ConfirmedAction title="Generate organisation forecasts" description={`Generate ${ahead} future month(s) with ${method === 'generate-seasonal' ? 'the seasonal method' : `${history} months of history`}? The current display date range does not limit generation.`} run={() => generateForecast(method, +ahead, +history)} onClose={() => setConfirm(false)} onDone={() => { setConfirm(false); void client.invalidateQueries({ queryKey: ['supply', orgId] }) }} />}
  </section>
}
