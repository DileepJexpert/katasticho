import { beforeEach, describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useSessionStore } from '@/shared/session/session-store'
import { TaxGroupsPage } from './tax-groups-page'
import * as taxGroupsApi from './tax-groups-api'

function setRole(role: string) {
  useSessionStore.setState({
    status: role ? 'authenticated' : 'anonymous',
    user: role ? {
      id: 'u-1',
      orgId: 'o-1',
      fullName: 'User',
      email: 'user@test.com',
      phone: null,
      role,
      orgName: 'Org',
      industry: null,
      businessType: null,
      industryCode: null,
      onboardingCompleted: true,
      defaultLandingPage: null,
    } : null,
  })
}

vi.mock('./tax-groups-api', async () => {
  const actual = await vi.importActual<typeof taxGroupsApi>('./tax-groups-api')
  return { ...actual, getTaxGroups: vi.fn(), getTaxGroup: vi.fn() }
})

describe('TaxGroupsPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
    vi.clearAllMocks()
    setRole('ADMIN')
    vi.mocked(taxGroupsApi.getTaxGroups).mockResolvedValue([
      {
        id: 'tg-1',
        name: 'GST 18%',
        description: 'Standard GST intra-state rate',
        active: true,
        rates: [
          { id: 'tr-1', rateCode: 'CGST 9%', name: 'Central GST', percentage: 9, taxType: 'CGST', recoverable: true },
          { id: 'tr-2', rateCode: 'SGST 9%', name: 'State GST', percentage: 9, taxType: 'SGST', recoverable: true },
        ],
      },
      {
        id: 'tg-2',
        name: 'IGST 5%',
        description: 'Inter-state group',
        active: true,
        rates: [
          { id: 'tr-3', rateCode: 'IGST 5%', name: 'Integrated GST', percentage: 5, taxType: 'IGST', recoverable: true },
        ],
      },
    ])
  })

  function renderPage() {
    return render(
      <QueryClientProvider client={queryClient}>
        <TaxGroupsPage />
      </QueryClientProvider>
    )
  }

  it('shows backend tax groups with component rates and total percentage without write controls', async () => {
    renderPage()

    expect(await screen.findByText('GST 18%')).toBeInTheDocument()
    expect(screen.getByText('Standard GST intra-state rate')).toBeInTheDocument()
    expect(screen.getByText('CGST 9% (9%)')).toBeInTheDocument()
    expect(screen.getByText('SGST 9% (9%)')).toBeInTheDocument()
    expect(screen.getByText('18%')).toBeInTheDocument()
    expect(screen.getByText('IGST 5%')).toBeInTheDocument()
    expect(screen.queryByRole('tab', { name: /inactive/i })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /new tax group|create tax group|edit tax group|delete tax group/i })).not.toBeInTheDocument()
  })

  it('searches the active-only tax groups by component and name', async () => {
    const user = userEvent.setup()
    renderPage()
    await screen.findByText('GST 18%')

    const searchInput = screen.getByPlaceholderText('Search tax groups or rates...')
    await user.type(searchInput, 'IGST')

    expect(screen.queryByText('GST 18%')).not.toBeInTheDocument()
    expect(screen.getByText('IGST 5%')).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: 'Clear search' }))
    expect(await screen.findByText('GST 18%')).toBeInTheDocument()

  })

  it('opens component rate composition modal on view rates click', async () => {
    const user = userEvent.setup()
    renderPage()
    await screen.findByText('GST 18%')

    const [firstButton] = screen.getAllByRole('button', { name: 'View rates' })
    expect(firstButton).toBeDefined()
    await user.click(firstButton!)

    expect(screen.getByRole('dialog')).toBeInTheDocument()
    expect(screen.getByText('GST 18% composition')).toBeInTheDocument()
    expect(screen.getByText('Central GST')).toBeInTheDocument()
    expect(screen.getByText('State GST')).toBeInTheDocument()
    expect(screen.getAllByText('Recoverable').length).toBeGreaterThan(0)

    await user.click(screen.getByRole('button', { name: 'Close' }))
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
  })

  it('does not issue a forbidden query for operators, including on direct navigation', () => {
    setRole('OPERATOR')
    renderPage()
    expect(screen.getByRole('alert')).toHaveTextContent('cannot read tax-group definitions')
    expect(taxGroupsApi.getTaxGroups).not.toHaveBeenCalled()
  })

  it('allows read-only viewers and supports retry after load failures', async () => {
    setRole('VIEWER')
    vi.mocked(taxGroupsApi.getTaxGroups).mockRejectedValueOnce(new Error('Rates unavailable'))
    renderPage()
    expect(await screen.findByRole('alert')).toHaveTextContent('Rates unavailable')
    await userEvent.click(screen.getByRole('button', { name: 'Retry tax groups' }))
    expect(await screen.findByText('GST 18%')).toBeInTheDocument()
  })

  it('bounds a large active directory to 25 rows at a time', async () => {
    vi.mocked(taxGroupsApi.getTaxGroups).mockResolvedValue(Array.from({ length: 26 }, (_, index) => ({ id: `group-${index}`, name: `Group ${index}`, active: true, rates: [] })))
    renderPage()
    expect(await screen.findByText('Group 0')).toBeInTheDocument()
    expect(screen.queryByText('Group 25')).not.toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'Next tax groups' }))
    expect(screen.getByText('Group 25')).toBeInTheDocument()
    expect(screen.queryByText('Group 0')).not.toBeInTheDocument()
  })
})
