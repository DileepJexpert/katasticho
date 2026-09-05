import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { CodRemittancesPage } from './cod-remittances-page'
import * as transportApi from './transport-api'

vi.mock('./transport-api', () => ({
  listCodRemittances: vi.fn(),
  createCodRemittance: vi.fn(),
  pullCodRemittance: vi.fn(),
}))

const mockRemittances: transportApi.CodRemittance[] = [
  {
    id: 'rem-001',
    remittanceNumber: 'REM-2026-0001',
    courierPartner: 'BLUEDART',
    remittanceDate: '2026-09-02',
    bankAccount: 'HDFC-9912',
    utr: 'UTR9988776655',
    grossCollected: 50000,
    totalFees: 1200,
    netRemitted: 48800,
    expectedNet: 48800,
    variance: 0,
    status: 'RECONCILED',
    notes: 'Weekly BlueDart settlement',
    lines: [],
  },
]

describe('CodRemittancesPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    vi.clearAllMocks()
    queryClient = new QueryClient({
      defaultOptions: {
        queries: { retry: false },
      },
    })
    vi.mocked(transportApi.listCodRemittances).mockResolvedValue(mockRemittances)
  })

  function renderPage() {
    return render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter>
          <CodRemittancesPage />
        </MemoryRouter>
      </QueryClientProvider>
    )
  }

  it('renders COD remittances directory, financial KPIs, and settlements', async () => {
    renderPage()

    expect(await screen.findByRole('heading', { name: 'COD Remittances' })).toBeInTheDocument()
    expect(await screen.findByText('REM-2026-0001')).toBeInTheDocument()
    expect(screen.getByText('BLUEDART')).toBeInTheDocument()
    expect(screen.getByText('Total Gross Collected')).toBeInTheDocument()
    expect(screen.getByText('Total Courier COD Fees')).toBeInTheDocument()
  })

  it('opens pull from gateway modal and triggers gateway sync', async () => {
    const user = userEvent.setup()
    vi.mocked(transportApi.pullCodRemittance).mockResolvedValue({
      ...mockRemittances[0]!,
      id: 'rem-002',
      remittanceNumber: 'REM-2026-0002',
    })

    renderPage()

    const pullBtn = await screen.findByRole('button', { name: /Pull from Gateway/i })
    await user.click(pullBtn)

    expect(screen.getByRole('dialog')).toBeInTheDocument()
    expect(screen.getByText('Pull COD Remittance via API')).toBeInTheDocument()

    const syncBtn = screen.getByRole('button', { name: 'Pull Remittance' })
    await user.click(syncBtn)

    await waitFor(() => {
      expect(transportApi.pullCodRemittance).toHaveBeenCalledWith(
        'BLUEDART',
        undefined,
        undefined
      )
    })
  })
})
