import { beforeEach, describe, expect, it, vi } from 'vitest'
import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { UomsPage } from './uoms-page'
import * as uomsApi from './uoms-api'

vi.mock('./uoms-api', async () => {
  const actual = await vi.importActual<typeof uomsApi>('./uoms-api')
  return { ...actual, getUoms: vi.fn(), getUom: vi.fn(), createUom: vi.fn(), updateUom: vi.fn(), deleteUom: vi.fn() }
})
const access = vi.hoisted(() => ({ manage: false }))
vi.mock('./inventory-access', () => ({ useInventoryAccess: () => access }))

describe('UomsPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
    vi.clearAllMocks()
    access.manage = false
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

  it('creates packaging units with the controller fields, not conversion ratios', async () => {
    access.manage = true
    vi.mocked(uomsApi.createUom).mockResolvedValue({ id: 'carton', name: 'Carton', abbreviation: 'CTN', category: 'PACKAGING', active: true, base: false })
    const user = userEvent.setup()
    renderPage()
    await user.click(screen.getByRole('button', { name: 'New unit' }))
    const dialog = within(screen.getByRole('dialog'))
    await user.type(dialog.getByLabelText(/Unit name/), 'Carton')
    await user.type(dialog.getByLabelText(/Abbreviation/), 'CTN')
    await user.selectOptions(dialog.getByLabelText(/Category/), 'PACKAGING')
    expect(dialog.queryByRole('option', { name: 'Area' })).not.toBeInTheDocument()
    await user.click(dialog.getByRole('button', { name: 'Save unit' }))
    await waitFor(() => expect(uomsApi.createUom).toHaveBeenCalledWith({ name: 'Carton', abbreviation: 'CTN', category: 'PACKAGING', active: true, base: false }))
  })

  it('preserves false values during edit and confirms removal separately', async () => {
    access.manage = true
    const user = userEvent.setup()
    renderPage()
    await user.click(await screen.findByRole('button', { name: 'Edit kg' }))
    const dialog = within(screen.getByRole('dialog'))
    await user.click(dialog.getByLabelText('Active'))
    await user.click(dialog.getByLabelText('Base unit'))
    await user.click(dialog.getByRole('button', { name: 'Save unit' }))
    await waitFor(() => expect(uomsApi.updateUom).toHaveBeenCalledWith('uom-1', expect.objectContaining({ active: false, base: false })))
    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())
    await user.click(screen.getByRole('button', { name: 'Edit kg' }))
    await user.click(screen.getByRole('button', { name: 'Remove unit' }))
    expect(uomsApi.deleteUom).not.toHaveBeenCalled()
    await user.click(screen.getByRole('button', { name: 'Confirm removal' }))
    await waitFor(() => expect(uomsApi.deleteUom).toHaveBeenCalledWith('uom-1'))
  })
})
