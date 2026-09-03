import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { ArrowLeft } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { TextField } from '@/design-system/text-field'
import { getApAgeingReport } from './ap-reports-api'

export function ApAgingReportPage() {
  const [asOfDate, setAsOfDate] = useState(new Date().toISOString().slice(0, 10))
  const navigate = useNavigate()

  const reportQuery = useQuery({
    queryKey: ['ap-reports', 'ageing', asOfDate],
    queryFn: () => getApAgeingReport(asOfDate),
  })

  const report = reportQuery.data

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Purchases / Payables / Operational Reporting"
        title="Accounts Payable Aging Summary"
        description="Overdue payable balances categorized by aging buckets across suppliers"
        actions={
          <Button onClick={() => navigate('/bills')} variant="secondary">
            <ArrowLeft size={16} />
            Back to Bills
          </Button>
        }
      />

      <div style={{ display: 'flex', gap: '16px', alignItems: 'center', marginBottom: '16px' }}>
        <TextField
          label="As of Date"
          onChange={(e) => setAsOfDate(e.target.value)}
          type="date"
          value={asOfDate}
        />
      </div>

      {report ? (
        <>
          <div className="summary-strip" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '16px', marginBottom: '16px' }}>
            <div className="document-card">
              <span style={{ fontSize: '12px', color: 'var(--k-color-text-secondary)' }}>Total Payables</span>
              <strong style={{ fontSize: '22px', display: 'block', marginTop: '4px' }}>
                <Money amount={report.totalPayable} />
              </strong>
            </div>
            <div className="document-card">
              <span style={{ fontSize: '12px', color: 'var(--k-color-text-secondary)' }}>Current (0-30 Days)</span>
              <strong style={{ fontSize: '20px', display: 'block', marginTop: '4px', color: '#0F8576' }}>
                <Money amount={report.days1To30Total} />
              </strong>
            </div>
            <div className="document-card">
              <span style={{ fontSize: '12px', color: 'var(--k-color-text-secondary)' }}>31-60 Days</span>
              <strong style={{ fontSize: '20px', display: 'block', marginTop: '4px', color: '#D97706' }}>
                <Money amount={report.days31To60Total} />
              </strong>
            </div>
            <div className="document-card">
              <span style={{ fontSize: '12px', color: 'var(--k-color-text-secondary)' }}>61-90 Days</span>
              <strong style={{ fontSize: '20px', display: 'block', marginTop: '4px', color: '#DC2626' }}>
                <Money amount={report.days61To90Total} />
              </strong>
            </div>
            <div className="document-card">
              <span style={{ fontSize: '12px', color: 'var(--k-color-text-secondary)' }}>&gt;90 Days Overdue</span>
              <strong style={{ fontSize: '20px', display: 'block', marginTop: '4px', color: '#7F1D1D' }}>
                <Money amount={report.days90PlusTotal} />
              </strong>
            </div>
          </div>

          <section className="document-card">
            <h2>Supplier-Wise Aging Breakdown</h2>
            <DataTable caption="Supplier Aging Balances">
              <thead>
                <tr>
                  <th scope="col">Vendor</th>
                  <th className="numeric-cell" scope="col">Current</th>
                  <th className="numeric-cell" scope="col">1-30 Days</th>
                  <th className="numeric-cell" scope="col">31-60 Days</th>
                  <th className="numeric-cell" scope="col">61-90 Days</th>
                  <th className="numeric-cell" scope="col">&gt;90 Days</th>
                  <th className="numeric-cell" scope="col">Total Due</th>
                </tr>
              </thead>
              <tbody>
                {report.vendors?.map((v) => (
                  <tr key={v.vendorId}>
                    <td>
                      <strong>{v.vendorName}</strong>
                    </td>
                    <td className="numeric-cell">
                      <Money amount={v.currentAmount} />
                    </td>
                    <td className="numeric-cell">
                      <Money amount={v.days1To30} />
                    </td>
                    <td className="numeric-cell">
                      <Money amount={v.days31To60} />
                    </td>
                    <td className="numeric-cell">
                      <Money amount={v.days61To90} />
                    </td>
                    <td className="numeric-cell" style={{ color: Number(v.days90Plus) > 0 ? '#DC2626' : 'inherit', fontWeight: Number(v.days90Plus) > 0 ? 600 : 400 }}>
                      <Money amount={v.days90Plus} />
                    </td>
                    <td className="numeric-cell" style={{ fontWeight: 600 }}>
                      <Money amount={v.totalDue} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          </section>
        </>
      ) : reportQuery.isLoading ? (
        <p className="document-loading">Loading aging balances...</p>
      ) : null}
    </section>
  )
}
