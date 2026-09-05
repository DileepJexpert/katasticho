import { useMemo, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { ArrowLeft, RefreshCw } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { FormField } from '@/design-system/form-field'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { TextInput } from '@/design-system/text-input'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import {
  getPayablesAgeingReport,
  getReceivablesAgeingReport,
  type AgeingCounterparty,
  type AgeingDocument,
} from '@/features/reports/ageing-reports-api'

export type AgeingReportKind = 'AR' | 'AP'

export function AgeingReportPage({ kind }: { kind: AgeingReportKind }) {
  const [asOfDate, setAsOfDate] = useState(() => currentDate())
  const [selectedCounterpartyId, setSelectedCounterpartyId] = useState<string | null>(null)
  const navigate = useNavigate()
  const report = useQuery({
    queryKey: ['ageing-report', kind, asOfDate],
    queryFn: () => kind === 'AR' ? getReceivablesAgeingReport(asOfDate) : getPayablesAgeingReport(asOfDate),
  })

  const selectedCounterparty = useMemo(
    () => report.data?.counterparties.find((counterparty) => counterparty.id === selectedCounterpartyId) ?? null,
    [report.data, selectedCounterpartyId]
  )
  const isReceivables = kind === 'AR'
  const counterpartyLabel = isReceivables ? 'Customer' : 'Vendor'
  const documentLabel = isReceivables ? 'Invoice' : 'Bill'
  const title = isReceivables ? 'Accounts Receivable Aging' : 'Accounts Payable Aging'

  return (
    <section className="workspace-page">
      <PageHeader
        actions={
          <Button onClick={() => navigate(isReceivables ? appRoutes.invoices : appRoutes.bills)} variant="secondary">
            <ArrowLeft aria-hidden="true" size={16} /> Back to {isReceivables ? 'Invoices' : 'Bills'}
          </Button>
        }
        description={isReceivables
          ? 'Outstanding customer balances by due-age bucket, returned from the receivables service.'
          : 'Outstanding vendor balances by due-age bucket, returned from the payables service.'}
        eyebrow={isReceivables ? 'Sales / Receivables / Reports' : 'Purchases / Payables / Reports'}
        title={title}
      />

      <div className="ageing-report-toolbar">
        <FormField label="As of date">
          <TextInput onChange={(event) => setAsOfDate(event.target.value)} type="date" value={asOfDate} />
        </FormField>
        <Button disabled={report.isFetching} onClick={() => report.refetch()} variant="secondary">
          <RefreshCw aria-hidden="true" size={16} /> Refresh
        </Button>
      </div>

      {report.isLoading && <div aria-live="polite" className="directory-state">Loading server-calculated aging balances...</div>}
      {report.isError && (
        <div className="directory-state directory-state--error" role="alert">
          <strong>{title} could not be loaded.</strong>
          <Button onClick={() => report.refetch()} variant="secondary">Retry</Button>
        </div>
      )}
      {report.data && (
        <>
          <div className="summary-strip ageing-report-summary">
            <SummaryCard label="Total outstanding" amount={report.data.totalOutstanding} />
            <SummaryCard label="Current" amount={report.data.current} />
            <SummaryCard label="1-30 days" amount={report.data.days1to30} />
            <SummaryCard label="31-60 days" amount={report.data.days31to60} />
            <SummaryCard label="61-90 days" amount={report.data.days61to90} />
            <SummaryCard label="90+ days overdue" amount={report.data.days90plus} />
          </div>

          <section className="document-card ageing-report-table">
            <div className="financial-statement-section__header">
              <h2>{counterpartyLabel} aging</h2>
              <span className="cell-muted">{report.data.counterparties.length} {counterpartyLabel.toLowerCase()} records</span>
            </div>
            {report.data.counterparties.length === 0 ? (
              <p className="financial-statement-empty">The server reported no outstanding balances for this date.</p>
            ) : (
              <DataTable caption={title + ' counterparties'}>
                <thead>
                  <tr>
                    <th scope="col">{counterpartyLabel}</th>
                    <th className="numeric-cell" scope="col">Current</th>
                    <th className="numeric-cell" scope="col">1-30</th>
                    <th className="numeric-cell" scope="col">31-60</th>
                    <th className="numeric-cell" scope="col">61-90</th>
                    <th className="numeric-cell" scope="col">90+</th>
                    <th className="numeric-cell" scope="col">Outstanding</th>
                    <th scope="col"><span className="sr-only">Document drill-down</span></th>
                  </tr>
                </thead>
                <tbody>
                  {report.data.counterparties.map((counterparty) => (
                    <tr key={counterparty.id}>
                      <td>
                        <Link className="table-row-link" to={appRoutes.contactDetail(counterparty.id)}>{counterparty.name}</Link>
                        {counterparty.phone && <div className="cell-muted">{counterparty.phone}</div>}
                      </td>
                      <MoneyCell amount={counterparty.current} />
                      <MoneyCell amount={counterparty.days1to30} />
                      <MoneyCell amount={counterparty.days31to60} />
                      <MoneyCell amount={counterparty.days61to90} />
                      <MoneyCell amount={counterparty.days90plus} />
                      <MoneyCell amount={counterparty.totalOutstanding} />
                      <td className="numeric-cell">
                        <Button onClick={() => setSelectedCounterpartyId(counterparty.id)} variant="ghost">
                          {counterparty.documents.length} {documentLabel.toLowerCase()}{counterparty.documents.length === 1 ? '' : 's'}
                        </Button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </DataTable>
            )}
          </section>

          {selectedCounterparty && (
            <AgeingDocumentPanel
              counterparty={selectedCounterparty}
              documentLabel={documentLabel}
              kind={kind}
              onClose={() => setSelectedCounterpartyId(null)}
            />
          )}
        </>
      )}
    </section>
  )
}

function AgeingDocumentPanel({
  counterparty,
  documentLabel,
  kind,
  onClose,
}: {
  counterparty: AgeingCounterparty
  documentLabel: string
  kind: AgeingReportKind
  onClose: () => void
}) {
  return (
    <section className="document-card ageing-document-panel">
      <div className="financial-statement-section__header">
        <div>
          <h2>{counterparty.name}</h2>
          <p className="cell-muted">{counterparty.documents.length} open {documentLabel.toLowerCase()}{counterparty.documents.length === 1 ? '' : 's'} returned by the server</p>
        </div>
        <Button onClick={onClose} variant="ghost">Close detail</Button>
      </div>
      {counterparty.documents.length === 0 ? (
        <p className="financial-statement-empty">No document-level detail was returned for this counterparty.</p>
      ) : (
        <DataTable caption={documentLabel + ' aging detail'}>
          <thead>
            <tr>
              <th scope="col">{documentLabel}</th>
              <th scope="col">Date</th>
              <th scope="col">Bucket</th>
              <th className="numeric-cell" scope="col">Days overdue</th>
              <th className="numeric-cell" scope="col">Balance due</th>
            </tr>
          </thead>
          <tbody>
            {counterparty.documents.map((document) => (
              <DocumentRow document={document} key={document.id} kind={kind} />
            ))}
          </tbody>
        </DataTable>
      )}
    </section>
  )
}

function DocumentRow({ document, kind }: { document: AgeingDocument; kind: AgeingReportKind }) {
  const documentRoute = kind === 'AR'
    ? appRoutes.invoiceDetail(document.id)
    : appRoutes.billDetail(document.id)

  return (
    <tr>
      <td><Link className="table-row-link table-row-link--mono" to={documentRoute}>{document.number}</Link></td>
      <td>{formatDate(document.documentDate)}</td>
      <td><StatusChip status={document.bucket}>{formatStatusLabel(document.bucket)}</StatusChip></td>
      <td className="numeric-cell">{document.daysOverdue}</td>
      <MoneyCell amount={document.balanceDue} />
    </tr>
  )
}

function SummaryCard({
  amount,
  label,
}: {
  amount: number | string
  label: string
}) {
  return (
    <div className="summary-card">
      <span className="summary-card__label">{label}</span>
      <strong className="summary-card__value">
        <Money amount={amount} />
      </strong>
    </div>
  )
}

function MoneyCell({ amount }: { amount: number | string }) {
  return <td className="numeric-cell"><Money amount={amount} /></td>
}

function currentDate(): string {
  const today = new Date()
  return [today.getFullYear(), String(today.getMonth() + 1).padStart(2, '0'), String(today.getDate()).padStart(2, '0')].join('-')
}
