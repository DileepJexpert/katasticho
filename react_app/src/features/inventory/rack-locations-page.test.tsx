import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { beforeEach, expect, it, vi } from 'vitest'
import { RackLocationsPage, RackPicker } from './rack-locations-page'
import { createRackLocation, listRackLocations, type RackLocation } from '@/features/pharmacy/pharmacy-api'
import { listWarehouses, type Warehouse } from '@/features/warehouses/warehouses-api'

const access = vi.hoisted(() => ({ operate: true }))
vi.mock('./inventory-access', () => ({ useInventoryAccess: () => access }))
vi.mock('@/features/pharmacy/pharmacy-api', () => ({ createRackLocation: vi.fn(), listRackLocations: vi.fn() }))
vi.mock('@/features/warehouses/warehouses-api', () => ({ listWarehouses: vi.fn() }))

function wrap(children: React.ReactNode) { return render(<QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false, gcTime: 0 } } })}>{children}</QueryClientProvider>) }
beforeEach(() => {
  vi.clearAllMocks(); access.operate = true
  vi.mocked(listWarehouses).mockResolvedValue([{ id: 'main', name: 'Main warehouse', code: 'MAIN', active: true }] as Warehouse[])
  vi.mocked(listRackLocations).mockResolvedValue([])
  vi.mocked(createRackLocation).mockResolvedValue({ id: 'rack-id', warehouseId: 'main', code: 'A-01' } as RackLocation)
})

it('requires explicit warehouse selection and creates a rack with real IDs', async () => {
  const user = userEvent.setup()
  wrap(<RackLocationsPage />)
  await user.click(screen.getByRole('button', { name: 'New rack location' }))
  const dialog = within(screen.getByRole('dialog'))
  await user.type(dialog.getByLabelText(/Rack code/), 'A-01')
  await user.click(dialog.getByRole('button', { name: 'Create rack' }))
  expect(createRackLocation).not.toHaveBeenCalled()
  await waitFor(() => expect(dialog.getByRole('combobox', { name: 'Select inventory warehouse' })).toBeEnabled())
  await user.click(dialog.getByRole('combobox', { name: 'Select inventory warehouse' }))
  await user.click(await dialog.findByRole('option', { name: /Main warehouse/ }))
  await user.click(dialog.getByRole('button', { name: 'Create rack' }))
  await waitFor(() => expect(vi.mocked(createRackLocation).mock.calls[0]?.[0]).toEqual(expect.objectContaining({ code: 'A-01', warehouseId: 'main' })))
})

it('never requests the restricted directory for viewers', () => {
  access.operate = false
  wrap(<RackLocationsPage />)
  expect(screen.getByText('Your role cannot access rack locations.')).toBeInTheDocument()
  expect(listRackLocations).not.toHaveBeenCalled()
})

it('only offers active racks belonging to the selected warehouse', async () => {
  vi.mocked(listRackLocations).mockResolvedValue([
    { id: 'allowed', code: 'A-01', warehouseId: 'main', active: true },
    { id: 'other', code: 'B-01', warehouseId: 'other', active: true },
    { id: 'inactive', code: 'A-02', warehouseId: 'main', active: false },
  ] as RackLocation[])
  const user = userEvent.setup()
  wrap(<RackPicker warehouseId="main" value={null} onChange={vi.fn()} />)
  await waitFor(() => expect(screen.getByRole('combobox')).toBeEnabled())
  await user.click(screen.getByRole('combobox'))
  expect(await screen.findByRole('option', { name: 'A-01' })).toBeInTheDocument()
  expect(screen.queryByRole('option', { name: 'B-01' })).not.toBeInTheDocument()
  expect(screen.queryByRole('option', { name: 'A-02' })).not.toBeInTheDocument()
})
