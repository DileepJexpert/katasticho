import { useQuery } from '@tanstack/react-query'
import { AlertTriangle, ArrowLeft } from 'lucide-react'
import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DataTable,
  DocumentCard,
  Fact,
  FactList,
  Money,
  PageHeader,
  SummaryRow,
} from '@/design-system'
import { getContactLedger } from '@/features/contacts/contacts-api'
import { formatDate, formatStatusLabel } from '@/shared/format/format'

export function ContactStatementPage() {
  const { contactId } = useParams()
  const navigate = useNavigate()
  const [startDate, setStartDate] = useState(() => localDate(new Date(new Date().getFullYear(), 0, 1)))
  const [endDate, setEndDate] = useState(() => localDate(new Date()))
  const ledgerQuery = useQuery({
    queryKey: ['contacts', contactId, 'ledger', startDate, endDate],
    queryFn: () => getContactLedger(contactId!, startDate, endDate),
    enabled: Boolean(contactId),
  })

  if (!contactId) return <StatementLoadError onBack={() => navigate(appRoutes.contacts)} />
  if (ledgerQuery.isLoading) {
    return <section className="workspace-page"><div aria-live="polite" className="directory-state">Loading statement...</div></section>
  }
  if (ledgerQuery.isError || !ledgerQuery.data) return <StatementLoadError onBack={() => navigate(appRoutes.contactDetail(contactId))} />

  const ledger = ledgerQuery.data
  const customerLedger = ledger.contactType === 'CUSTOMER'

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <div className="document-actions">
            <Button onClick={() => navigate(appRoutes.contactDetail(contactId))} variant="secondary">
              <ArrowLeft aria-hidden="true" size={16} />
              Back to contact
            </Button>
          </div>
        }
        description={`Account statement from ${formatDate(startDate)} to ${formatDate(endDate)}`}
        eyebrow="Master data / Contacts / Statement"
        title={ledger.contactName}
      />

      <DocumentCard title="Statement period">
        <FactList columns={2}>
          <label className="field">
            <span>From</span>
            <input
              max={endDate}
              onChange={(event) => {
                if (event.target.value) setStartDate(event.target.value)
              }}
              required
              type="date"
              value={startDate}
            />
          </label>
          <label className="field">
            <span>To</span>
            <input
              max={localDate(new Date())}
              min={startDate}
              onChange={(event) => {
                if (event.target.value) setEndDate(event.target.value)
              }}
              required
              type="date"
              value={endDate}
            />
          </label>
        </FactList>
      </DocumentCard>

      <div className="document-layout">
        <DocumentCard title="Statement summary">
          <FactList columns={2}>
            <Fact label="Opening balance" value={<Money amount={ledger.openingBalance} />} />
            <Fact label={customerLedger ? 'Invoiced' : 'Billed'} value={<Money amount={ledger.totalInvoiced} />} />
            <Fact label="Payments recorded" value={<Money amount={ledger.totalPaid} />} />
            <Fact label="Entries" value={String(ledger.entries.length)} />
          </FactList>
        </DocumentCard>

        <DocumentCard title="Closing balance" variant="summary">
          <SummaryRow label="Opening balance" value={<Money amount={ledger.openingBalance} />} />
          <SummaryRow label="Payments" value={<Money amount={ledger.totalPaid} />} />
          <SummaryRow isTotal label="Balance" value={<Money amount={ledger.closingBalance} />} />
        </DocumentCard>
      </div>

      <DocumentCard title="Ledger entries" variant="lines">
        {ledger.entries.length ? (
          <DataTable caption="Contact ledger entries">
            <thead>
              <tr>
                <th scope="col">Date</th>
                <th scope="col">Reference</th>
                <th scope="col">Type</th>
                <th scope="col">Description</th>
                <th className="numeric-cell" scope="col">Debit</th>
                <th className="numeric-cell" scope="col">Credit</th>
                <th className="numeric-cell" scope="col">Running balance</th>
              </tr>
            </thead>
            <tbody>
              {ledger.entries.map((entry) => (
                <tr key={`${entry.type}-${entry.referenceId}-${entry.date}`}>
                  <td>{formatDate(entry.date)}</td>
                  <td><code>{entry.number || '--'}</code></td>
                  <td>{formatStatusLabel(entry.type)}</td>
                  <td>{entry.description ?? '--'}</td>
                  <td className="numeric-cell"><Money amount={entry.debit} /></td>
                  <td className="numeric-cell"><Money amount={entry.credit} /></td>
                  <td className="numeric-cell"><Money amount={entry.runningBalance} /></td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        ) : (
          <div className="directory-state">No transactions were recorded in this period.</div>
        )}
      </DocumentCard>
    </section>
  )
}

function StatementLoadError({ onBack }: { onBack: () => void }) {
  return (
    <section className="workspace-page">
      <div className="directory-state directory-state--error" role="alert">
        <AlertTriangle aria-hidden="true" size={24} />
        <strong>Statement could not be loaded.</strong>
        <p>Check the date range and your permission to view this contact ledger.</p>
        <Button onClick={onBack} variant="secondary">Back to contact</Button>
      </div>
    </section>
  )
}

function localDate(value: Date) {
  const year = value.getFullYear()
  const month = String(value.getMonth() + 1).padStart(2, '0')
  const day = String(value.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}
