import { useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { CheckboxInput } from '@/design-system/checkbox-input'
import { Button } from '@/design-system/button'
import { Modal } from '@/design-system/modal'
import { Money } from '@/design-system/money'
import { TextField } from '@/design-system/text-field'

export type MonthlyPostingResult = { count: number; total: number | string; journalEntryId: string | null }

export function MonthlyPostingDialog({ title, scope, run, onClose }: {
  title: string
  scope: string
  run: (year: number, month: number) => Promise<MonthlyPostingResult>
  onClose: () => void
}) {
  const [period, setPeriod] = useState(() => { const d = new Date(); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}` })
  const [confirmed, setConfirmed] = useState(false)
  const client = useQueryClient()
  const [year, month] = period.split('-').map(Number)
  const valid = Number.isInteger(year) && Number.isInteger(month) && year! >= 1 && year! <= 9999 && month! >= 1 && month! <= 12
  const mutation = useMutation({
    mutationFn: () => run(year!, month!),
    onSuccess: () => { client.invalidateQueries() },
  })
  return <Modal isOpen onClose={() => { if (!mutation.isPending) onClose() }} title={title}
    description={`This posts to the general ledger for all eligible ${scope} in the current organisation, not just the record being viewed. Already-posted records for the selected month are skipped by the server.`}
    error={mutation.error?.message} footer={mutation.isSuccess
      ? <Button onClick={onClose}>Close</Button>
      : <><Button variant="secondary" disabled={mutation.isPending} onClick={onClose}>Cancel</Button><Button disabled={!confirmed || !valid || mutation.isPending} onClick={() => mutation.mutate()}>{mutation.isPending ? 'Posting...' : 'Post organisation month'}</Button></>}>
    {mutation.data ? <div role="status"><p>{mutation.data.count} records processed.</p><Money amount={mutation.data.total} /><p>{mutation.data.journalEntryId ? 'Journal posted successfully.' : 'No new journal was needed.'}</p></div> : <>
      <TextField label="Posting month" type="month" required value={period} disabled={mutation.isPending} onChange={(e) => { setPeriod(e.target.value); setConfirmed(false) }} />
      <CheckboxInput label="I confirm this run covers the whole organisation." checked={confirmed} disabled={mutation.isPending} onChange={(e) => setConfirmed(e.target.checked)} />
    </>}
  </Modal>
}
