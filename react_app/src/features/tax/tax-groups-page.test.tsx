import { beforeEach, describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { TaxGroupsPage } from './tax-groups-page'
import * as taxGroupsApi from './tax-groups-api'

vi.mock('./tax-groups-api', async () => {
  const actual = await vi.importActual<typeof taxGroupsApi>('./tax-groups-api')
  return { ...actual, getTaxGroups: vi.fn(), getTaxGroup: vi.fn() }
})

describe('TaxGroupsPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
    vi.clearAllMocks()
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
        name: 'GST 5% Decommissioned',
        description: 'Legacy concessional group',
        active: false,
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
    expect(screen.getByText('GST 5% Decommissioned')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /new tax group|create tax group|edit tax group|delete tax group/i })).not.toBeInTheDocument()
  })

  it('filters tax groups by search input and status tabs', async () => {
    const user = userEvent.setup()
    renderPage()
    await screen.findByText('GST 18%')

    const searchInput = screen.getByPlaceholderText('Search tax groups or rates...')
    await user.type(searchInput, 'Decommissioned')

    expect(screen.queryByText('GST 18%')).not.toBeInTheDocument()
    expect(screen.getByText('GST 5% Decommissioned')).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: 'Clear search' }))
    expect(await screen.findByText('GST 18%')).toBeInTheDocument()

    await user.click(screen.getByRole('tab', { name: /inactive/i }))
    expect(screen.queryByText('GST 18%')).not.toBeInTheDocument()
    expect(screen.getByText('GST 5% Decommissioned')).toBeInTheDocument()
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
})
