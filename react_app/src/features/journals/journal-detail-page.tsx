import type { ReactNode } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, CheckCircle, RotateCcw } from 'lucide-react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatDateTime, formatStatusLabel } from '@/shared/format/format'
import {
  getJournal,
  postJournal,
  reverseJournal,
} from '@/features/journals/journals-api'

export function JournalDetailPage() {
  const { journalId } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const journal = useQuery({
    queryKey: ['journals', journalId],
    queryFn: () => getJournal(journalId!),
    enabled: Boolean(journalId),
  })

  const postMutation = useMutation({
    mutationFn: () => postJournal(journalId!),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['journals', journalId] }),
  })

  const reverseMutation = useMutation({
    mutationFn: () => reverseJournal(journalId!),
    onSuccess: (reversal) => {
      queryClient.invalidateQueries({ queryKey: ['journals'] })
      navigate(`${appRoutes.journals}/${reversal.id}`)
    },
  })

  if (!journalId) return <DocumentError onBack={() => navigate(appRoutes.journals)} />
  if (journal.isLoading) return <section className="workspace-page"><div aria-live="polite" className="directory-state">Loading journal entry...</div></section>
  if (journal.isError || !journal.data) return <DocumentError onBack={() => navigate(appRoutes.journals)} />

  const document = journal.data
  const isDraft = document.status === 'DRAFT'
  const isPosted = document.status === 'POSTED'

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
            <Button onClick={() => navigate(appRoutes.journals)} variant="secondary">
              <ArrowLeft className="icon" /> Back to Journals
            </Button>
            {isDraft && (
              <Button disabled={postMutation.isPending} onClick={() => postMutation.mutate()} variant="primary">
                <CheckCircle className="icon" /> Post Journal
              </Button>
            )}
            {isPosted && !document.isReversed && (
              <Button
                disabled={reverseMutation.isPending}
                onClick={() => {
                  if (confirm(`Reverse journal entry ${document.entryNumber}? This will create a balancing reversal entry.`)) {
                    reverseMutation.mutate()
                  }
                }}
                variant="secondary"
              >
                <RotateCcw className="icon" /> Reverse Journal
              </Button>
            )}
          </div>
        }
        description={`Effective Date: ${formatDate(document.effectiveDate)} · Source: ${formatStatusLabel(document.sourceModule ?? 'MANUAL')}`}
        eyebrow="Accounting / General Ledger / Journal Voucher"
        title={document.entryNumber}
      />

      <div className="document-layout" style={{ marginBottom: '1.5rem' }}>
        <section className="document-card">
          <h2>Voucher Overview</h2>
          <dl className="document-facts">
            <Fact label="Entry Number" value={document.entryNumber} />
            <Fact label="Effective Date" value={formatDate(document.effectiveDate)} />
            <Fact label="Source Module" value={<StatusChip status={document.sourceModule ?? 'MANUAL'} />} />
            <Fact label="Status" value={<StatusChip status={document.status} />} />
            <Fact label="Narration" value={document.description ?? '—'} />
            {document.isReversal && <Fact label="Reversal Of" value={<Link to={`${appRoutes.journals}/${document.reversalOfId}`}>View Original Journal</Link>} />}
            {document.isReversed && <Fact label="Reversed Status" value={<StatusChip status="REVERSED" />} />}
          </dl>
        </section>

        <aside className="document-card document-card--summary">
          <h2>Total Amount</h2>
          <div className="summary-row summary-row--total">
            <span>Total Debits / Credits</span>
            <Money amount={document.totalDebit} />
          </div>
          <div className="progress-row">
            <span>Line Count</span>
            <strong>{document.lines.length}</strong>
          </div>
          <div className="progress-row">
            <span>Created</span>
            <span>{formatDateTime(document.createdAt)}</span>
          </div>
        </aside>
      </div>

      <section className="document-card document-card--lines">
        <h2>Double-Entry Ledger Lines ({document.lines.length})</h2>
        <DataTable caption="Journal lines">
          <thead>
            <tr>
              <th scope="col">Account Code</th>
              <th scope="col">Account Name</th>
              <th scope="col">Line Memo / Narration</th>
              <th className="numeric-cell" scope="col">Debit (INR)</th>
              <th className="numeric-cell" scope="col">Credit (INR)</th>
            </tr>
          </thead>
          <tbody>
            {document.lines.map((line) => (
              <tr key={line.id}>
                <td>
                  <Link to={`${appRoutes.accounts}/${line.accountId}`}>
                    <code>{line.accountCode}</code>
                  </Link>
                </td>
                <td>
                  <Link to={`${appRoutes.accounts}/${line.accountId}`}>
                    <strong>{line.accountName}</strong>
                  </Link>
                </td>
                <td>{line.description || '—'}</td>
                <td className="numeric-cell">
                  {line.debit != null && Number(line.debit) > 0 ? (
                    <Money amount={line.debit} />
                  ) : '—'}
                </td>
                <td className="numeric-cell">
                  {line.credit != null && Number(line.credit) > 0 ? (
                    <Money amount={line.credit} />
                  ) : '—'}
                </td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      </section>
    </section>
  )
}

function Fact({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className="document-fact">
      <dt>{label}</dt>
      <dd>{value}</dd>
    </div>
  )
}

function DocumentError({ onBack }: { onBack: () => void }) {
  return (
    <section className="workspace-page">
      <div className="directory-state">
        <p>Journal entry not found or failed to load.</p>
        <Button onClick={onBack} variant="secondary">
          <ArrowLeft className="icon" /> Back to Journals
        </Button>
      </div>
    </section>
  )
}
