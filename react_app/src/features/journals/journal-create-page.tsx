import { useEffect, useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, Check, Plus, Save, Trash2 } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  CheckboxInput,
  DataTable,
  EntityPicker,
  FormCard,
  FormField,
  FormGrid,
  Modal,
  Money,
  NumberInput,
  PageHeader,
  TextAreaInput,
  TextInput,
} from '@/design-system'
import { listAccounts, type Account } from '@/features/accounts/accounts-api'
import { createJournal, type CreateJournalRequest } from '@/features/journals/journals-api'

type JournalLineForm = {
  id: string
  account: Account | null
  debit: string
  credit: string
  description: string
  costCentre: string
}

function createLine(): JournalLineForm {
  return {
    id: crypto.randomUUID(),
    account: null,
    debit: '',
    credit: '',
    description: '',
    costCentre: '',
  }
}

function toPaise(value: string) {
  const numeric = Number(value)
  return Number.isFinite(numeric) && numeric > 0 ? Number(numeric.toFixed(2)) : 0
}

function today() {
  const date = new Date()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${date.getFullYear()}-${month}-${day}`
}

export function JournalCreatePage() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [effectiveDate, setEffectiveDate] = useState(today)
  const [description, setDescription] = useState('')
  const [postDated, setPostDated] = useState(false)
  const [lines, setLines] = useState<JournalLineForm[]>([createLine(), createLine()])
  const [feedback, setFeedback] = useState<string | null>(null)
  const [postConfirmationOpen, setPostConfirmationOpen] = useState(false)

  const accountsQuery = useQuery({
    queryKey: ['accounts'],
    queryFn: listAccounts,
  })

  const postableAccounts = useMemo(
    () => (accountsQuery.data ?? []).filter((account) => account.isActive && !account.hasChildren),
    [accountsQuery.data],
  )
  const totals = useMemo(() => lines.reduce((result, line) => ({
    debit: result.debit + toPaise(line.debit),
    credit: result.credit + toPaise(line.credit),
  }), { debit: 0, credit: 0 }), [lines])
  const difference = Math.abs(totals.debit - totals.credit)
  const isBalanced = totals.debit > 0 && difference < 0.005
  const incompleteLine = lines.find((line) => !line.account || (toPaise(line.debit) === 0 && toPaise(line.credit) === 0))
  const bothSidesLine = lines.find((line) => toPaise(line.debit) > 0 && toPaise(line.credit) > 0)
  const canSubmit = Boolean(
    effectiveDate &&
    description.trim() &&
    lines.length >= 2 &&
    !incompleteLine &&
    !bothSidesLine &&
    isBalanced,
  )
  const isFutureDated = effectiveDate > today()

  useEffect(() => {
    if (!isFutureDated && postDated) setPostDated(false)
  }, [isFutureDated, postDated])

  const createMutation = useMutation({
    mutationFn: (autoPost: boolean) => {
      const request: CreateJournalRequest = {
        effectiveDate,
        description: description.trim(),
        sourceModule: 'MANUAL',
        autoPost,
        postDated,
        lines: lines.map((line) => ({
          accountCode: line.account?.code ?? '',
          debit: toPaise(line.debit),
          credit: toPaise(line.credit),
          description: line.description.trim() || undefined,
          costCentre: line.costCentre.trim() || undefined,
        })),
      }
      return createJournal(request)
    },
    onSuccess: (journal) => {
      queryClient.invalidateQueries({ queryKey: ['journals'] })
      navigate(appRoutes.journalDetail(journal.id))
    },
    onError: (error: Error) => {
      setPostConfirmationOpen(false)
      setFeedback(error.message)
    },
  })

  function updateLine(id: string, update: Partial<JournalLineForm>) {
    setLines((previous) => previous.map((line) => line.id === id ? { ...line, ...update } : line))
  }

  function changeDebit(line: JournalLineForm, value: string) {
    updateLine(line.id, { debit: value, credit: toPaise(value) > 0 ? '' : line.credit })
  }

  function changeCredit(line: JournalLineForm, value: string) {
    updateLine(line.id, { credit: value, debit: toPaise(value) > 0 ? '' : line.debit })
  }

  function removeLine(id: string) {
    setLines((previous) => previous.length > 2 ? previous.filter((line) => line.id !== id) : previous)
  }

  function saveDraft() {
    setFeedback(null)
    if (!canSubmit) {
      setFeedback('Add at least two complete, single-sided journal lines that balance to the same paise.')
      return
    }
    createMutation.mutate(false)
  }

  function requestPost() {
    setFeedback(null)
    if (!canSubmit) {
      setFeedback('Add at least two complete, single-sided journal lines that balance to the same paise.')
      return
    }
    if (postDated) {
      createMutation.mutate(true)
      return
    }
    setPostConfirmationOpen(true)
  }

  return (
    <section className="workspace-page">
      <Link className="form-back-link" to={appRoutes.journals}>
        <ArrowLeft size={16} /> Back to journal entries
      </Link>
      <PageHeader
        description="Create a balanced manual voucher. Drafts remain editable only until posting; posted entries are corrected through a reversal."
        eyebrow="Accounting / General Ledger"
        title="New Journal Entry"
      />

      {feedback ? <div className="banner banner--error" role="alert">{feedback}</div> : null}
      {accountsQuery.isError ? <div className="banner banner--error" role="alert">Accounts could not be loaded. Journal creation is unavailable until they can be read.</div> : null}

      <form className="create-form-container" onSubmit={(event) => { event.preventDefault(); requestPost() }}>
        <FormCard
          description="Manual journals are always recorded under the Manual source. The backend determines the fiscal period and checks it is open."
          stepNumber={1}
          title="Voucher details"
        >
          <FormGrid columns={2}>
            <FormField hint="The organisation's open fiscal period is enforced by the server." label="Effective date" required>
              <TextInput onChange={(event) => setEffectiveDate(event.target.value)} required type="date" value={effectiveDate} />
            </FormField>
            <FormField label="Posting schedule">
              <CheckboxInput
                checked={postDated}
                description={isFutureDated ? 'Keep this voucher as a draft and let the server post it on the effective date.' : 'Choose a future effective date to schedule this voucher.'}
                disabled={!isFutureDated}
                onChange={(event) => setPostDated(event.target.checked)}
                title="Post-dated voucher"
              />
            </FormField>
            <FormField label="Narration" required span="full">
              <TextAreaInput
                onChange={(event) => setDescription(event.target.value)}
                placeholder="e.g. Monthly prepaid rent adjustment"
                required
                rows={3}
                value={description}
              />
            </FormField>
          </FormGrid>
        </FormCard>

        <FormCard
          description="Search active posting accounts. A line may contain a debit or a credit, never both. Values are previewed and sent rounded to two decimal places."
          headerAction={<Button onClick={() => setLines((previous) => [...previous, createLine()])} type="button" variant="secondary"><Plus size={16} /> Add line</Button>}
          stepNumber={2}
          title={`Double-entry lines (${lines.length})`}
        >
          <DataTable caption="Manual journal lines">
            <thead>
              <tr>
                <th scope="col">Posting account</th>
                <th scope="col">Line narration</th>
                <th scope="col">Cost centre</th>
                <th className="numeric-cell" scope="col">Debit</th>
                <th className="numeric-cell" scope="col">Credit</th>
                <th scope="col"><span className="visually-hidden">Remove line</span></th>
              </tr>
            </thead>
            <tbody>
              {lines.map((line, index) => (
                <tr key={line.id}>
                  <td>
                    <EntityPicker
                      ariaLabel={`Search posting account for line ${index + 1}`}
                      disabled={accountsQuery.isLoading || accountsQuery.isError}
                      getOptionBadge={(account) => account.type}
                      getOptionDescription={(account) => `${account.code} / ${account.subType ?? 'General ledger'}`}
                      getOptionId={(account) => account.id}
                      getOptionLabel={(account) => account.name}
                      onChange={(_id, account) => updateLine(line.id, { account: account ?? null })}
                      options={postableAccounts}
                      placeholder={accountsQuery.isLoading ? 'Loading accounts...' : 'Search by account code or name'}
                      selectedEntity={line.account}
                      value={line.account?.id ?? null}
                    />
                  </td>
                  <td><TextInput aria-label={`Line narration ${index + 1}`} onChange={(event) => updateLine(line.id, { description: event.target.value })} placeholder="Optional line memo" value={line.description} /></td>
                  <td><TextInput aria-label={`Cost centre ${index + 1}`} onChange={(event) => updateLine(line.id, { costCentre: event.target.value })} placeholder="Optional" value={line.costCentre} /></td>
                  <td className="numeric-cell"><NumberInput aria-label={`Debit for line ${index + 1}`} currencyPrefix min={0} onChange={(event) => changeDebit(line, event.target.value)} step="0.01" value={line.debit} /></td>
                  <td className="numeric-cell"><NumberInput aria-label={`Credit for line ${index + 1}`} currencyPrefix min={0} onChange={(event) => changeCredit(line, event.target.value)} step="0.01" value={line.credit} /></td>
                  <td className="action-col">
                    <Button aria-label={`Remove line ${index + 1}`} disabled={lines.length <= 2} onClick={() => removeLine(line.id)} type="button" variant="ghost"><Trash2 size={15} /></Button>
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>

          <div className={`journal-balance ${isBalanced ? 'journal-balance--balanced' : 'journal-balance--unbalanced'}`}>
            <div className="journal-balance__totals">
              <span>Total debit <Money amount={totals.debit} /></span>
              <span>Total credit <Money amount={totals.credit} /></span>
            </div>
            <strong>{isBalanced ? 'Balanced' : <>Difference <Money amount={difference} /></>}</strong>
          </div>
          {bothSidesLine ? <p className="form-error" role="alert">Each line must be a debit or a credit, not both.</p> : null}
        </FormCard>

        <div className="form-actions-bar">
          <Button onClick={() => navigate(appRoutes.journals)} type="button" variant="secondary">Cancel</Button>
          <Button disabled={!canSubmit || createMutation.isPending || accountsQuery.isLoading || accountsQuery.isError} onClick={saveDraft} type="button" variant="secondary"><Save size={16} />{createMutation.isPending ? 'Saving...' : 'Save draft'}</Button>
          <Button disabled={!canSubmit || createMutation.isPending || accountsQuery.isLoading || accountsQuery.isError} type="submit" variant="primary"><Check size={16} />{postDated ? 'Schedule posting' : 'Post journal'}</Button>
        </div>
      </form>

      <Modal
        description="This creates a posted journal entry. Use a reversal to correct it after posting."
        footer={
          <>
            <Button onClick={() => setPostConfirmationOpen(false)} variant="secondary">Keep editing</Button>
            <Button loading={createMutation.isPending} onClick={() => createMutation.mutate(true)} variant="primary">Post journal</Button>
          </>
        }
        isOpen={postConfirmationOpen}
        onClose={() => setPostConfirmationOpen(false)}
        title="Post this journal entry?"
      >
        <div className="journal-post-confirmation">
          <p><strong>Narration:</strong> {description.trim()}</p>
          <p><strong>Amount:</strong> <Money amount={totals.debit} /></p>
          <p><strong>Effective date:</strong> {effectiveDate}</p>
        </div>
      </Modal>
    </section>
  )
}
