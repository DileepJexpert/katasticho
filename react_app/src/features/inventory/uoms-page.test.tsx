import { beforeEach, describe, expect, it, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { UomsPage } from './uoms-page'
import * as uomsApi from './uoms-api'

vi.mock('./uoms-api', async () => {
  const actual = await vi.importActual<typeof uomsApi>('./uoms-api')
  return { ...actual, getUoms: vi.fn(), getUom: vi.fn() }
})

describe('UomsPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
    vi.clearAllMocks()
    vi.mocked(uomsApi.getUoms).mockResolvedValue([
      { id: 'uom-1', name: 'Kilogram', abbreviation: 'kg', category: 'WEIGHT', base: true, active: true },
      { id: 'uom-2', name: 'Gram', abbreviation: 'g', category: 'WEIGHT', base: false, active: true },
      { id: 'uom-3', name: 'Piece', abbreviation: 'pcs', category: 'COUNT', base: true, active: true },
      { id: 'uom-4', name: 'Litre', abbreviation: 'L', category: 'VOLUME', base: true, active: false },
    ])
  })

  function renderPage() {
    return render(
      <QueryClientProvider client={queryClient}>
        <UomsPage />
      </QueryClientProvider>
    )
  }

  it('shows backend measurement units and baseline tags without write controls', async () => {
    renderPage()

    expect(await screen.findByText('Kilogram')).toBeInTheDocument()
    expect(screen.getByText('kg')).toBeInTheDocument()
    expect(screen.getByText('Piece')).toBeInTheDocument()
    expect(screen.getByText('pcs')).toBeInTheDocument()
    expect(screen.getAllByText('Base unit').length).toBeGreaterThan(0)
    expect(screen.getByText('Derived')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /new uom|create uom|edit uom|delete uom/i })).not.toBeInTheDocument()
  })

  it('filters units by category tabs and search input', async () => {
    const user = userEvent.setup()
    renderPage()
    await screen.findByText('Kilogram')

    await user.click(screen.getByRole('tab', { name: /Count/i }))
    expect(screen.queryByText('Kilogram')).not.toBeInTheDocument()
    expect(screen.getByText('Piece')).toBeInTheDocument()

    await user.click(screen.getByRole('tab', { name: /All units/i }))
    expect(await screen.findByText('Kilogram')).toBeInTheDocument()

    const searchInput = screen.getByPlaceholderText('Search unit name or symbol...')
    await user.type(searchInput, 'Litre')

    expect(screen.queryByText('Kilogram')).not.toBeInTheDocument()
    expect(screen.getByText('Litre')).toBeInTheDocument()
    expect(screen.getByText('L')).toBeInTheDocument()
  })

  it('renders empty state when search matches no unit', async () => {
    const user = userEvent.setup()
    renderPage()
    await screen.findByText('Kilogram')

    const searchInput = screen.getByPlaceholderText('Search unit name or symbol...')
    await user.type(searchInput, 'NonExistentUnit')

    expect(screen.getByText('No matching units.')).toBeInTheDocument()
    expect(screen.queryByText('Kilogram')).not.toBeInTheDocument()
  })
})
