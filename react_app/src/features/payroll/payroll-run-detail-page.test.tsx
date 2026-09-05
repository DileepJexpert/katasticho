import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { apiFetchBlob } from '@/api/client/api-client'
import { enterpriseUser } from '@/features/accounting/enterprise-test-fixtures'
import { downloadBlob } from '@/shared/files/download-blob'
import { useSessionStore } from '@/shared/session/session-store'
import { PayrollRunDetailPage } from './payroll-run-detail-page'
import * as api from './payroll-api'

vi.mock('@/api/client/api-client', () => ({ apiFetchBlob: vi.fn() }))
vi.mock('@/shared/files/download-blob', () => ({ downloadBlob: vi.fn() }))
vi.mock('./payroll-api', () => ({
  approvePayrollRun: vi.fn(), calculatePayrollRun: vi.fn(), cancelPayrollRun: vi.fn(), getEmployee: vi.fn(),
  getPayrollRun: vi.fn(), getPayslip: vi.fn(), listPayslips: vi.fn(), postPayrollRun: vi.fn(),
}))

function renderPage() {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } })
  return render(<QueryClientProvider client={client}><MemoryRouter initialEntries={['/payroll/runs/run-1']}><Routes><Route path="/payroll/runs/:runId" element={<PayrollRunDetailPage />} /></Routes></MemoryRouter></QueryClientProvider>)
}

describe('PayrollRunDetailPage', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    useSessionStore.setState({ status: 'authenticated', user: enterpriseUser })
    vi.mocked(api.getPayrollRun).mockResolvedValue({ id: 'run-1', orgId: 'org-1', periodStart: '2026-08-01', periodEnd: '2026-08-31', status: 'POSTED', employeeCount: 1, grossTotal: 10000, deductionTotal: 1000, employerContributionTotal: 500, netPayTotal: 9000, journalEntryId: 'journal-1' })
    vi.mocked(api.listPayslips).mockResolvedValue([])
    vi.mocked(apiFetchBlob).mockResolvedValue(new Blob(['bank-file'], { type: 'text/csv' }))
  })

  it('downloads the real server bank file and does not claim that payroll posting paid salaries', async () => {
    renderPage()

    expect(await screen.findByText('Payroll exports')).toBeInTheDocument()
    expect(screen.getByText(/Posting salary liabilities is not a bank payment|Downloading does not send a bank payment/)).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'Download bank CSV' }))
    await waitFor(() => expect(apiFetchBlob).toHaveBeenCalledWith('/api/v1/payroll/runs/run-1/bank-file?format=GENERIC', 'text/csv'))
    expect(downloadBlob).toHaveBeenCalledWith(expect.any(Blob), 'salary-2026-08-01-GENERIC.csv')
  })
})
