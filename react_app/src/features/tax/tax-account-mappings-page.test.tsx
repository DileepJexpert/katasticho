import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { TaxAccountMappingsPage } from './tax-account-mappings-page'
import * as tdsTcsApi from './tds-tcs-api'
import * as accountsApi from '@/features/accounts/accounts-api'

vi.mock('./tds-tcs-api', () => ({
  listTaxAccountMappings: vi.fn(),
  updateTaxAccountMappings: vi.fn(),
  resetTaxAccountMappings: vi.fn(),
  listTaxGroups: vi.fn(),
}))

vi.mock('@/features/accounts/accounts-api', () => ({
  listAccounts: vi.fn(),
}))

const mockMappings: tdsTcsApi.TaxAccountMapping[] = [
  {
    taxRateId: 'rate-1',
    name: 'CGST 9%',
    rateCode: 'CGST-9',
    percentage: 9,
    taxType: 'GST',
    recoverable: true,
    customized: false,
    glOutputAccountId: 'acc-out-1',
    glOutputAccountCode: '2010',
    glOutputAccountName: 'Output CGST',
    glInputAccountId: 'acc-in-1',
    glInputAccountCode: '1010',
    glInputAccountName: 'Input CGST',
  },
]

const mockTaxGroups: tdsTcsApi.TaxGroup[] = [
  {
    id: 'tg-1',
    name: 'GST 18%',
    description: 'Standard 18% GST',
    active: true,
    rates: [],
  },
]

describe('TaxAccountMappingsPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
    vi.clearAllMocks()
    vi.mocked(tdsTcsApi.listTaxAccountMappings).mockResolvedValue(mockMappings)
    vi.mocked(tdsTcsApi.listTaxGroups).mockResolvedValue(mockTaxGroups)
    vi.mocked(accountsApi.listAccounts).mockResolvedValue([])
    vi.mocked(tdsTcsApi.updateTaxAccountMappings).mockResolvedValue(mockMappings)
    vi.mocked(tdsTcsApi.resetTaxAccountMappings).mockResolvedValue(mockMappings)
  })

  function renderPage() {
    return render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter>
          <TaxAccountMappingsPage />
        </MemoryRouter>
      </QueryClientProvider>
    )
  }

  it('renders tax account bindings table and header actions', async () => {
    renderPage()

    expect(await screen.findByText('CGST 9%')).toBeInTheDocument()
    expect(screen.getByText('Tax Configuration & GL Mappings')).toBeInTheDocument()
    expect(screen.getByText('Reset to Defaults')).toBeInTheDocument()
    expect(screen.getByText('CGST-9')).toBeInTheDocument()
    expect(screen.getByText(/Output CGST/)).toBeInTheDocument()
  })

  it('switches between mappings and tax groups tabs', async () => {
    renderPage()

    expect(await screen.findByText('CGST 9%')).toBeInTheDocument()

    const groupsTab = screen.getByRole('tab', { name: /active tax groups/i })
    fireEvent.click(groupsTab)

    expect(await screen.findByText('GST 18%')).toBeInTheDocument()
    expect(screen.getByText('Standard 18% GST')).toBeInTheDocument()
  })

  it('opens edit mapping modal and updates account binding', async () => {
    renderPage()

    expect(await screen.findByText('CGST 9%')).toBeInTheDocument()

    const editBtn = screen.getByRole('button', { name: /edit mapping/i })
    fireEvent.click(editBtn)

    expect(screen.getByText(/edit gl account mapping:/i)).toBeInTheDocument()

    const saveBtn = screen.getByRole('button', { name: 'Save Mapping' })
    fireEvent.click(saveBtn)

    await waitFor(() => {
      expect(tdsTcsApi.updateTaxAccountMappings).toHaveBeenCalledWith([
        {
          taxRateId: 'rate-1',
          glOutputAccountId: 'acc-out-1',
          glInputAccountId: 'acc-in-1',
        },
      ])
    })
  })
})
