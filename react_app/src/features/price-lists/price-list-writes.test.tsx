import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { PriceListCreateModal } from './price-list-create-modal'
import { PriceListActionModal } from './price-list-action-modal'
import { addPriceListTier, createPriceList, deletePriceListTier, type PriceList } from './price-lists-api'
import { listItems, type Item } from '@/features/items/items-api'

const permission = vi.hoisted(() => ({ allowed: true }))
vi.mock('./pricing-shared', async () => ({ ...await vi.importActual('./pricing-shared'), useCanManagePricing: () => permission.allowed }))
vi.mock('./price-lists-api', async () => ({ ...await vi.importActual('./price-lists-api'), createPriceList: vi.fn(), addPriceListTier: vi.fn(), deletePriceListTier: vi.fn() }))
vi.mock('@/features/items/items-api', () => ({ listItems: vi.fn() }))
const list: PriceList = { id: 'list-1', name: 'Wholesale', description: null, currency: 'INR', isDefault: false, active: true, createdAt: null }
function wrap(component: React.ReactNode) { return render(<QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>{component}</QueryClientProvider>) }
beforeEach(() => {
  vi.clearAllMocks()
  permission.allowed = true
  vi.mocked(createPriceList).mockResolvedValue(list)
  vi.mocked(deletePriceListTier).mockResolvedValue(undefined)
  vi.mocked(listItems).mockResolvedValue({ content: [{ id: 'item-1', name: 'Turmeric', sku: 'MASALA' } as Item], totalElements: 1, totalPages: 1, page: 0, size: 25, last: true })
})
it('creates a default list through the existing contract', async () => {
  const user = userEvent.setup()
  const created = vi.fn()
  wrap(<PriceListCreateModal onClose={vi.fn()} onCreated={created} />)
  await user.type(screen.getByLabelText(/^Name/), 'Wholesale')
  await user.click(screen.getByRole('checkbox', { name: /Use as organisation default/ }))
  await user.click(screen.getByRole('button', { name: 'Create price list' }))
  await waitFor(() => expect(createPriceList).toHaveBeenCalledWith({ name: 'Wholesale', description: null, currency: 'INR', isDefault: true }))
  expect(created).toHaveBeenCalledWith('list-1')
})
it('adds a numeric tier for the selected item and preserves a zero price', async () => {
  const user = userEvent.setup()
  wrap(<PriceListActionModal list={list} action={{ kind: 'tier' }} onClose={vi.fn()} onDeleted={vi.fn()} />)
  await user.click(screen.getByRole('combobox', { name: 'Search tier item' }))
  await user.click(await screen.findByRole('option', { name: /Turmeric/ }))
  await user.clear(screen.getByLabelText(/^Minimum quantity/))
  await user.type(screen.getByLabelText(/^Minimum quantity/), '10')
  await user.type(screen.getByLabelText(/^Unit price/), '0')
  await user.click(screen.getByRole('button', { name: 'Add item tier' }))
  await waitFor(() => expect(addPriceListTier).toHaveBeenCalledWith('list-1', { itemId: 'item-1', minQuantity: 10, price: 0 }))
})
it('requires confirmation before removing a tier and displays server errors', async () => {
  vi.mocked(deletePriceListTier).mockRejectedValue(new Error('Tier is unavailable'))
  const user = userEvent.setup()
  wrap(<PriceListActionModal list={list} action={{ kind: 'remove-tier', tier: { id: 'tier-1', priceListId: 'list-1', itemId: 'item-1', itemName: 'Turmeric', itemSku: 'MASALA', minQuantity: 10, price: 40 } }} onClose={vi.fn()} onDeleted={vi.fn()} />)
  expect(deletePriceListTier).not.toHaveBeenCalled()
  await user.click(screen.getByRole('button', { name: 'Remove item tier' }))
  expect(await screen.findByRole('alert')).toHaveTextContent('Tier is unavailable')
  expect(deletePriceListTier).toHaveBeenCalledWith('tier-1')
})
it('disables write submission for a read-only role', () => {
  permission.allowed = false
  wrap(<PriceListCreateModal onClose={vi.fn()} onCreated={vi.fn()} />)
  expect(screen.getByRole('button', { name: 'Create price list' })).toBeDisabled()
  expect(createPriceList).not.toHaveBeenCalled()
})
