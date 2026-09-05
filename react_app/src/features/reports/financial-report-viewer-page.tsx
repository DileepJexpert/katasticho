import { useMemo, useState, type Dispatch, type ReactNode, type SetStateAction } from 'react'
import { useQuery } from '@tanstack/react-query'
import { ArrowLeft, BookOpen, RefreshCw } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { listAccounts, type Account } from '@/features/accounts/accounts-api'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { EntityPicker } from '@/design-system/entity-picker'
import { FormField } from '@/design-system/form-field'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { TextInput } from '@/design-system/text-input'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import {
  getBalanceSheet,
  getGeneralLedger,
  getProfitLoss,
  getTrialBalance,
  reportCatalog,
  type FinancialAccountLine,
  type ReportAmount,
} from '@/features/reports/reports-api'

const financialReportKeys = [
  'trial-balance',
  'profit-loss',
  'balance-sheet',
  'general-ledger',
] as const

export type FinancialReportKey = (typeof financialReportKeys)[number]

export function isFinancialReportKey(value: string | undefined): value is FinancialReportKey {
  return financialReportKeys.some((key) => key === value)
}

export function FinancialReportViewerPage({ reportKey }: { reportKey: FinancialReportKey }) {
  switch (reportKey) {
    case 'trial-balance':
      return <TrialBalanceReport />
    case 'profit-loss':
      return <ProfitLossReport />
    case 'balance-sheet':
      return <BalanceSheetReport />
    case 'general-ledger':
      return <GeneralLedgerReport />
  }

  return null
}

function TrialBalanceReport() {
  const [asOfDate, setAsOfDate] = useState(() => currentDate())
  const report = useQuery({
    queryKey: ['financial-report', 'trial-balance', asOfDate],
    queryFn: () => getTrialBalance(asOfDate),
  })

  return (
    <FinancialReportFrame reportKey="trial-balance">
      <AsOfDateControls asOfDate={asOfDate} onChange={setAsOfDate} onRefresh={() => report.refetch()} />
      <ReportState
        errorMessage="Trial balance could not be loaded."
        isError={report.isError}
        isLoading={report.isLoading}
        onRetry={() => report.refetch()}
      />
      {report.data && (
        <>
          <div className="summary-strip financial-statement-summary">
            <SummaryCard label="Total debit" value={<Money amount={report.data.totalDebit} currency={report.data.currency} />} />
            <SummaryCard label="Total credit" value={<Money amount={report.data.totalCredit} currency={report.data.currency} />} />
            <SummaryCard
              label="Double-entry check"
              value={
                <StatusChip status={report.data.isBalanced ? 'Reconciled' : 'Error'}>
                  {report.data.isBalanced ? 'Balanced' : 'Out of balance'}
                </StatusChip>
              }
            />
          </div>
          <section className="document-card financial-statement-section">
            <StatementHeader
              title="Account balances"
              total={
                <StatusChip status={report.data.isBalanced ? 'Reconciled' : 'Error'}>
                  {report.data.isBalanced ? 'Balanced' : 'Review required'}
                </StatusChip>
              }
            />
            {report.data.lines.length === 0 ? (
              <p className="financial-statement-empty">The server reported no posted account balances as of this date.</p>
            ) : (
              <DataTable caption="Trial balance account lines">
                <thead>
                  <tr>
                    <th scope="col">Account</th>
                    <th scope="col">Type</th>
                    <th className="numeric-cell" scope="col">Debit</th>
                    <th className="numeric-cell" scope="col">Credit</th>
                    <th className="numeric-cell" scope="col">Net balance</th>
                  </tr>
                </thead>
                <tbody>
                  {report.data.lines.map((line) => (
                    <tr key={line.accountId}>
                      <td><AccountLink account={line} /></td>
                      <td>{formatStatusLabel(line.accountType)}</td>
                      <MoneyCell amount={line.debit} currency={report.data.currency} />
                      <MoneyCell amount={line.credit} currency={report.data.currency} />
                      <MoneyCell amount={line.balance} currency={report.data.currency} />
                    </tr>
                  ))}
                </tbody>
              </DataTable>
            )}
          </section>
        </>
      )}
    </FinancialReportFrame>
  )
}

function ProfitLossReport() {
  const [dates, setDates] = useState(() => currentPeriod())
  const hasInvalidRange = dates.startDate > dates.endDate
  const report = useQuery({
    queryKey: ['financial-report', 'profit-loss', dates.startDate, dates.endDate],
    queryFn: () => getProfitLoss(dates.startDate, dates.endDate),
    enabled: !hasInvalidRange,
  })

  return (
    <FinancialReportFrame reportKey="profit-loss">
      <DateRangeControls dates={dates} onChange={setDates} onRefresh={() => report.refetch()} />
      {hasInvalidRange && <p className="form-error" role="alert">The end date must be on or after the start date.</p>}
      {!hasInvalidRange && (
        <ReportState
          errorMessage="Profit and loss statement could not be loaded."
          isError={report.isError}
          isLoading={report.isLoading}
          onRetry={() => report.refetch()}
        />
      )}
      {report.data && !hasInvalidRange && (
        <>
          <div className="summary-strip financial-statement-summary">
            <SummaryCard label="Total revenue" value={<Money amount={report.data.totalRevenue} currency={report.data.currency} />} />
            <SummaryCard label="Total expenses" value={<Money amount={report.data.totalExpenses} currency={report.data.currency} />} />
            <SummaryCard label="Net profit / loss" value={<Money amount={report.data.netProfit} currency={report.data.currency} />} />
          </div>
          <StatementSection
            accounts={report.data.revenueAccounts}
            currency={report.data.currency}
            emptyMessage="The server reported no revenue balances for this period."
            title="Revenue"
            total={report.data.totalRevenue}
          />
          <StatementSection
            accounts={report.data.expenseAccounts}
            currency={report.data.currency}
            emptyMessage="The server reported no expense balances for this period."
            title="Expenses"
            total={report.data.totalExpenses}
          />
        </>
      )}
    </FinancialReportFrame>
  )
}

function BalanceSheetReport() {
  const [asOfDate, setAsOfDate] = useState(() => currentDate())
  const report = useQuery({
    queryKey: ['financial-report', 'balance-sheet', asOfDate],
    queryFn: () => getBalanceSheet(asOfDate),
  })

  return (
    <FinancialReportFrame reportKey="balance-sheet">
      <AsOfDateControls asOfDate={asOfDate} onChange={setAsOfDate} onRefresh={() => report.refetch()} />
      <ReportState
        errorMessage="Balance sheet could not be loaded."
        isError={report.isError}
        isLoading={report.isLoading}
        onRetry={() => report.refetch()}
      />
      {report.data && (
        <>
          <div className="summary-strip financial-statement-summary">
            <SummaryCard label="Total assets" value={<Money amount={report.data.totalAssets} currency={report.data.currency} />} />
            <SummaryCard label="Total liabilities" value={<Money amount={report.data.totalLiabilities} currency={report.data.currency} />} />
            <SummaryCard label="Total equity" value={<Money amount={report.data.totalEquity} currency={report.data.currency} />} />
            <SummaryCard
              label="Balance check"
              value={
                <StatusChip status={report.data.isBalanced ? 'Reconciled' : 'Error'}>
                  {report.data.isBalanced ? 'Balanced' : 'Review required'}
                </StatusChip>
              }
            />
          </div>
          <StatementSection
            accounts={report.data.assetAccounts}
            currency={report.data.currency}
            emptyMessage="The server reported no asset balances as of this date."
            title="Assets"
            total={report.data.totalAssets}
          />
          <StatementSection
            accounts={report.data.liabilityAccounts}
            currency={report.data.currency}
            emptyMessage="The server reported no liability balances as of this date."
            title="Liabilities"
            total={report.data.totalLiabilities}
          />
          <StatementSection
            accounts={report.data.equityAccounts}
            currency={report.data.currency}
            emptyMessage="The server reported no equity account balances as of this date."
            footer={<ServerAmount label="Retained earnings" amount={report.data.retainedEarnings} currency={report.data.currency} />}
            title="Equity"
            total={report.data.totalEquity}
          />
        </>
      )}
    </FinancialReportFrame>
  )
}

function GeneralLedgerReport() {
  const [dates, setDates] = useState(() => currentPeriod())
  const [selectedAccount, setSelectedAccount] = useState<Account | null>(null)
  const hasInvalidRange = dates.startDate > dates.endDate
  const accounts = useQuery({
    queryKey: ['accounts', 'general-ledger-picker'],
    queryFn: listAccounts,
  })
  const ledgerAccounts = useMemo(
    () => (accounts.data ?? []).filter((account) => account.isActive),
    [accounts.data]
  )
  const report = useQuery({
    queryKey: ['financial-report', 'general-ledger', selectedAccount?.id, dates.startDate, dates.endDate],
    queryFn: () => getGeneralLedger(selectedAccount!.id, dates.startDate, dates.endDate),
    enabled: Boolean(selectedAccount) && !hasInvalidRange,
  })

  return (
    <FinancialReportFrame reportKey="general-ledger">
      <div className="financial-report-toolbar">
        <div className="financial-report-toolbar__fields">
          <FormField label="Ledger account" required>
            <EntityPicker
              ariaLabel="Search ledger accounts"
              getOptionDescription={(account) => [account.code, formatStatusLabel(account.type)].join(' · ')}
              getOptionId={(account) => account.id}
              getOptionLabel={(account) => account.name}
              onChange={(_, account) => setSelectedAccount(account ?? null)}
              options={ledgerAccounts}
              placeholder={accounts.isLoading ? 'Loading accounts...' : 'Search account name or code'}
              selectedEntity={selectedAccount}
              value={selectedAccount?.id ?? null}
            />
          </FormField>
          <FormField label="From">
            <TextInput onChange={(event) => setDates((current) => ({ ...current, startDate: event.target.value }))} type="date" value={dates.startDate} />
          </FormField>
          <FormField label="To">
            <TextInput onChange={(event) => setDates((current) => ({ ...current, endDate: event.target.value }))} type="date" value={dates.endDate} />
          </FormField>
        </div>
        <div className="financial-report-toolbar__actions">
          <Button disabled={!selectedAccount || hasInvalidRange || report.isFetching} onClick={() => report.refetch()} variant="secondary">
            <RefreshCw aria-hidden="true" size={16} /> Refresh
          </Button>
        </div>
      </div>
      {accounts.isError && <p className="form-error" role="alert">Ledger accounts could not be loaded.</p>}
      {hasInvalidRange && <p className="form-error" role="alert">The end date must be on or after the start date.</p>}
      {!selectedAccount && !accounts.isLoading && !accounts.isError && (
        <div className="directory-state financial-statement-empty">
          <BookOpen aria-hidden="true" className="directory-state__icon" size={24} />
          <strong>Select a posting account to review its ledger.</strong>
          <p>Choose an active account and period to review the server-calculated ledger.</p>
        </div>
      )}
      {selectedAccount && !hasInvalidRange && (
        <ReportState
          errorMessage="General ledger could not be loaded."
          isError={report.isError}
          isLoading={report.isLoading}
          onRetry={() => report.refetch()}
        />
      )}
      {report.data && selectedAccount && !hasInvalidRange && (
        <>
          <section className="document-card financial-ledger-overview">
            <StatementHeader
              title={[report.data.accountCode, report.data.accountName].join(' · ')}
              total={<StatusChip status={report.data.accountType}>{formatStatusLabel(report.data.accountType)}</StatusChip>}
            />
            <div className="summary-strip financial-statement-summary">
              <SummaryCard label="Opening balance" value={<Money amount={report.data.openingBalance} currency={report.data.currency} />} />
              <SummaryCard label="Total debit" value={<Money amount={report.data.totalDebit} currency={report.data.currency} />} />
              <SummaryCard label="Total credit" value={<Money amount={report.data.totalCredit} currency={report.data.currency} />} />
              <SummaryCard label="Closing balance" value={<Money amount={report.data.closingBalance} currency={report.data.currency} />} />
            </div>
          </section>
          <section className="document-card financial-statement-section">
            <StatementHeader title={'Ledger entries (' + report.data.entries.length + ')'} total={null} />
            {report.data.entries.length === 0 ? (
              <p className="financial-statement-empty">The server reported no transactions for this account and period.</p>
            ) : (
              <DataTable caption="General ledger entries">
                <thead>
                  <tr>
                    <th scope="col">Date</th>
                    <th scope="col">Journal</th>
                    <th scope="col">Narration</th>
                    <th scope="col">Source</th>
                    <th className="numeric-cell" scope="col">Debit</th>
                    <th className="numeric-cell" scope="col">Credit</th>
                    <th className="numeric-cell" scope="col">Running balance</th>
                  </tr>
                </thead>
                <tbody>
                  {report.data.entries.map((entry, index) => (
                    <tr key={[entry.journalEntryId, index].join('-')}>
                      <td>{formatDate(entry.effectiveDate)}</td>
                      <td><Link className="table-row-link table-row-link--mono" to={appRoutes.journalDetail(entry.journalEntryId)}>{entry.entryNumber}</Link></td>
                      <td>{entry.description || '—'}</td>
                      <td>{entry.sourceModule ? <StatusChip status={entry.sourceModule}>{formatStatusLabel(entry.sourceModule)}</StatusChip> : '—'}</td>
                      <MoneyCell amount={entry.debit} currency={report.data.currency} />
                      <MoneyCell amount={entry.credit} currency={report.data.currency} />
                      <MoneyCell amount={entry.runningBalance} currency={report.data.currency} />
                    </tr>
                  ))}
                </tbody>
              </DataTable>
            )}
          </section>
        </>
      )}
    </FinancialReportFrame>
  )
}

function FinancialReportFrame({ children, reportKey }: { children: ReactNode; reportKey: FinancialReportKey }) {
  const navigate = useNavigate()
  const report = reportCatalog.find((entry) => entry.key === reportKey)

  return (
    <section className="workspace-page">
      <PageHeader
        actions={<StatusChip status="Posted">Server-calculated</StatusChip>}
        description={report?.description}
        eyebrow="Accounting / Financial Statements"
        title={report?.title ?? 'Financial Report'}
      />
      <div className="financial-report__back">
        <Button onClick={() => navigate(appRoutes.reports)} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} /> Back to Reports Hub
        </Button>
        <span className="cell-muted">All balances, totals, and statement checks are returned by the accounting service.</span>
      </div>
      {children}
    </section>
  )
}

function AsOfDateControls({
  asOfDate,
  onChange,
  onRefresh,
}: {
  asOfDate: string
  onChange: (value: string) => void
  onRefresh: () => void
}) {
  return (
    <div className="financial-report-toolbar">
      <div className="financial-report-toolbar__fields">
        <FormField label="As of date">
          <TextInput onChange={(event) => onChange(event.target.value)} type="date" value={asOfDate} />
        </FormField>
      </div>
      <div className="financial-report-toolbar__actions">
        <Button onClick={onRefresh} variant="secondary"><RefreshCw aria-hidden="true" size={16} /> Refresh</Button>
      </div>
    </div>
  )
}

function DateRangeControls({
  dates,
  onChange,
  onRefresh,
}: {
  dates: DateRange
  onChange: Dispatch<SetStateAction<DateRange>>
  onRefresh: () => void
}) {
  return (
    <div className="financial-report-toolbar">
      <div className="financial-report-toolbar__fields">
        <FormField label="From">
          <TextInput onChange={(event) => onChange((current) => ({ ...current, startDate: event.target.value }))} type="date" value={dates.startDate} />
        </FormField>
        <FormField label="To">
          <TextInput onChange={(event) => onChange((current) => ({ ...current, endDate: event.target.value }))} type="date" value={dates.endDate} />
        </FormField>
      </div>
      <div className="financial-report-toolbar__actions">
        <Button disabled={dates.startDate > dates.endDate} onClick={onRefresh} variant="secondary"><RefreshCw aria-hidden="true" size={16} /> Refresh</Button>
      </div>
    </div>
  )
}

function StatementSection({
  accounts,
  currency,
  emptyMessage,
  footer,
  title,
  total,
}: {
  accounts: FinancialAccountLine[]
  currency: string
  emptyMessage: string
  footer?: ReactNode
  title: string
  total: ReportAmount
}) {
  return (
    <section className="document-card financial-statement-section">
      <StatementHeader title={title} total={<Money amount={total} currency={currency} />} />
      {accounts.length === 0 ? (
        <p className="financial-statement-empty">{emptyMessage}</p>
      ) : (
        <DataTable caption={title + ' statement accounts'}>
          <thead>
            <tr>
              <th scope="col">Account</th>
              <th className="numeric-cell" scope="col">Amount</th>
            </tr>
          </thead>
          <tbody>
            {accounts.map((account) => (
              <tr key={account.accountId}>
                <td><AccountLink account={account} /></td>
                <MoneyCell amount={account.amount} currency={currency} />
              </tr>
            ))}
          </tbody>
        </DataTable>
      )}
      {footer && <div className="financial-statement-section__footer">{footer}</div>}
    </section>
  )
}

function StatementHeader({ title, total }: { title: string; total: ReactNode }) {
  return (
    <div className="financial-statement-section__header">
      <h2>{title}</h2>
      {total && <strong className="financial-statement-section__total">{total}</strong>}
    </div>
  )
}

function SummaryCard({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className="summary-card">
      <span className="summary-card__label">{label}</span>
      <strong className="summary-card__value">{value}</strong>
    </div>
  )
}

function ServerAmount({ amount, currency, label }: { amount: ReportAmount; currency: string; label: string }) {
  return (
    <div className="financial-statement-section__server-amount">
      <span>{label}</span>
      <Money amount={amount} currency={currency} />
    </div>
  )
}

function AccountLink({ account }: { account: Pick<FinancialAccountLine, 'accountId' | 'accountCode' | 'accountName'> }) {
  return (
    <Link className="table-row-link" to={appRoutes.accountDetail(account.accountId)}>
      <code>{account.accountCode}</code> · {account.accountName}
    </Link>
  )
}

function MoneyCell({ amount, currency }: { amount: ReportAmount; currency: string }) {
  return <td className="numeric-cell"><Money amount={amount} currency={currency} /></td>
}

function ReportState({
  errorMessage,
  isError,
  isLoading,
  onRetry,
}: {
  errorMessage: string
  isError: boolean
  isLoading: boolean
  onRetry: () => void
}) {
  if (isLoading) return <div aria-live="polite" className="directory-state">Loading server-calculated report data...</div>
  if (isError) {
    return (
      <div className="directory-state directory-state--error" role="alert">
        <strong>{errorMessage}</strong>
        <Button onClick={onRetry} variant="secondary">Retry</Button>
      </div>
    )
  }
  return null
}

type DateRange = {
  startDate: string
  endDate: string
}

function currentPeriod(): DateRange {
  const today = new Date()
  return {
    startDate: localDate(new Date(today.getFullYear(), today.getMonth(), 1)),
    endDate: localDate(today),
  }
}

function currentDate(): string {
  return localDate(new Date())
}

function localDate(value: Date): string {
  const year = value.getFullYear()
  const month = String(value.getMonth() + 1).padStart(2, '0')
  const day = String(value.getDate()).padStart(2, '0')
  return [year, month, day].join('-')
}
