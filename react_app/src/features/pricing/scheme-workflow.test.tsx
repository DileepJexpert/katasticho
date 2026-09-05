import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { SchemeFormModal } from './scheme-form-modal'
import { SchemePreviewModal } from './scheme-preview-modal'
import { evaluateScheme, listApplicableSchemes, updateScheme, type Scheme } from './schemes-api'
import { listItems, type Item } from '@/features/items/items-api'

vi.mock('@/features/price-lists/pricing-shared', async () => ({ ...await vi.importActual('@/features/price-lists/pricing-shared'), useCanManagePricing: () => true }))
vi.mock('./schemes-api', async () => ({ ...await vi.importActual('./schemes-api'), updateScheme: vi.fn(), listApplicableSchemes: vi.fn(), evaluateScheme: vi.fn() }))
vi.mock('@/features/items/items-api', () => ({ listItems: vi.fn() }))
const scheme: Scheme = {
  id: 'scheme-1', name: '10 plus 1', schemeType: 'BUY_X_GET_Y', itemId: 'item-1', itemName: 'Turmeric', supplierId: 'supplier-1', supplierName: 'Annapurna',
  buyQuantity: 10, freeQuantity: 1, discountPercent: null, minOrderQuantity: 5, validFrom: '2026-09-01', validTo: '2026-09-30',
  active: true, allowHalfScheme: true, halfSchemeMinQty: 5, companySubsidyPercent: 75, specialNetRate: null, maxFreeQuantityCap: 10, createdAt: null,
}
function wrap(component: React.ReactNode) { return render(<QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>{component}</QueryClientProvider>) }
beforeEach(() => {
  vi.clearAllMocks()
  vi.mocked(updateScheme).mockResolvedValue(scheme)
  vi.mocked(listApplicableSchemes).mockResolvedValue([scheme])
  vi.mocked(listItems).mockResolvedValue({ content: [{ id: 'item-1', name: 'Turmeric', sku: 'MASALA', salePrice: 45 } as Item], totalElements: 1, totalPages: 1, page: 0, size: 25, last: true })
})
it('retains funding, item, dates, and half-scheme settings while editing', async () => {
  const user = userEvent.setup()
  wrap(<SchemeFormModal scheme={scheme} onClose={vi.fn()} />)
  await user.clear(screen.getByLabelText(/^Scheme name/))
  await user.type(screen.getByLabelText(/^Scheme name/), 'Updated promotion')
  await user.click(screen.getByRole('button', { name: 'Save scheme' }))
  await waitFor(() => expect(updateScheme).toHaveBeenCalledWith('scheme-1', expect.objectContaining({
    name: 'Updated promotion', itemId: 'item-1', supplierId: 'supplier-1', companySubsidyPercent: 75,
    allowHalfScheme: true, halfSchemeMinQty: 5, maxFreeQuantityCap: 10, validFrom: '2026-09-01', validTo: '2026-09-30',
  })))
})
it('renders the server preview and hides it when inputs change', async () => {
  vi.mocked(evaluateScheme).mockResolvedValue({ schemeId: 'scheme-1', schemeName: '10 plus 1', schemeType: 'BUY_X_GET_Y', orderedQuantity: 10, freeQuantity: 1, discountPercent: 0, discountAmount: 0, baseUnitPrice: 45, effectiveUnitPrice: 40.91, totalLineAmount: 450, companyFundedAmount: 33.75, distributorFundedAmount: 11.25, isHalfSchemeApplied: false, explanation: 'Server calculated one free unit.' })
  const user = userEvent.setup()
  wrap(<SchemePreviewModal onClose={vi.fn()} />)
  await user.click(screen.getByRole('combobox', { name: 'Search preview item' }))
  await user.click(await screen.findByRole('option', { name: /Turmeric/ }))
  await user.clear(screen.getByLabelText(/^Quantity/))
  await user.type(screen.getByLabelText(/^Quantity/), '10')
  await waitFor(() => expect(screen.getByRole('button', { name: 'Calculate preview' })).toBeEnabled())
  await user.click(screen.getByRole('button', { name: 'Calculate preview' }))
  expect(await screen.findByText('Server calculated one free unit.')).toBeInTheDocument()
  expect(evaluateScheme).toHaveBeenCalledWith({ itemId: 'item-1', quantity: 10, unitPrice: 45, schemeId: null })
  await user.clear(screen.getByLabelText(/^Quantity/))
  expect(screen.queryByText('Server calculated one free unit.')).not.toBeInTheDocument()
})
