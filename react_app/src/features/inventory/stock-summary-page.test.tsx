import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useSessionStore } from '@/shared/session/session-store'
import { StockSummaryPage } from './stock-summary-page'
import * as api from './stock-summary-api'

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

vi.mock('./stock-summary-api', () => ({ getStockSummary: vi.fn(), getLowStockAlert: vi.fn(), getFifoValuation: vi.fn(), getStockValuation: vi.fn() }))
const valuation: api.FifoValuationReport = {
  reportKey: 'fifo-valuation', title: 'FIFO valuation', description: 'Open cost lots', currency: 'INR', endDate: '2026-09-05',
  metrics: [{ key: 'lots', label: 'Open lots', value: 2, format: 'number' }, { key: 'value', label: 'Inventory value', value: 1234.5, format: 'currency' }],
  columns: [{ key: 'sku', label: 'SKU', type: 'text' }, { key: 'warehouse', label: 'Warehouse', type: 'text' }, { key: 'remainingQty', label: 'Qty left', type: 'number' }, { key: 'lotValue', label: 'Lot value', type: 'currency' }],
  rows: [{ sku: 'MASALA', warehouse: 'Main', remainingQty: 10, lotValue: 1234.5 }],
}

function renderPage() {
  return render(<QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}><StockSummaryPage /></QueryClientProvider>)
}
describe('Stock valuation contracts and states', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    setRole('ADMIN')
    vi.mocked(api.getStockSummary).mockResolvedValue({ asOfDate: '2026-09-05', itemCount: 1, totalInventoryValue: 450, lowStockCount: 0, outOfStockCount: 0, items: [{ itemId: 'item-1', itemName: 'Turmeric', sku: 'MASALA', unit: 'PCS', quantityOnHand: 10, purchasePrice: 45, inventoryValue: 450, reorderLevel: 2, status: 'NORMAL' }] })
    vi.mocked(api.getLowStockAlert).mockResolvedValue({ generatedAt: '2026-09-05', itemCount: 0, estimatedPurchaseCost: 0, items: [] })
    vi.mocked(api.getFifoValuation).mockResolvedValue(valuation)
    vi.mocked(api.getStockValuation).mockResolvedValue({ ...valuation, title: 'Warehouse valuation' })
  })
  it('labels purchase-price reference values honestly', async () => {
    renderPage()
    expect(await screen.findByText('Turmeric')).toBeInTheDocument()
    expect(screen.getByText('Purchase-price stock value')).toBeInTheDocument()
    expect(screen.queryByText('Weighted Average')).not.toBeInTheDocument()
  })
  it('uses server currency and number column types and separate FIFO metrics', async () => {
    const user = userEvent.setup()
    renderPage()
    await screen.findByText('Turmeric')
    await user.click(screen.getByRole('tab', { name: 'FIFO cost lots' }))
    const table = await screen.findByRole('table', { name: 'FIFO valuation' })
    expect(within(table).getByText('₹1,234.50')).toBeInTheDocument()
    expect(within(table).getByText('10')).toBeInTheDocument()
    expect(screen.queryByText('Purchase-price stock value')).not.toBeInTheDocument()
    expect(api.getFifoValuation).toHaveBeenCalledOnce()
  })
  it('shows no-lots state without claiming reconciliation', async () => {
    vi.mocked(api.getFifoValuation).mockResolvedValue({ ...valuation, rows: [] })
    const user = userEvent.setup()
    renderPage()
    await user.click(screen.getByRole('tab', { name: 'FIFO cost lots' }))
    expect(await screen.findByText('No open FIFO cost lots')).toBeInTheDocument()
    expect(screen.queryByText('All FIFO inventory lots reconciled with physical warehouse balance.')).not.toBeInTheDocument()
  })
  it('shows a failed FIFO request as an error, not empty success', async () => {
    vi.mocked(api.getFifoValuation).mockRejectedValue(new Error('Valuation unavailable'))
    const user = userEvent.setup()
    renderPage()
    await user.click(screen.getByRole('tab', { name: 'FIFO cost lots' }))
    expect(await screen.findByRole('alert')).toHaveTextContent('Valuation unavailable')
    expect(screen.queryByText('No open FIFO cost lots')).not.toBeInTheDocument()
  })
  it('restricts accounting valuation requests to the server-authorized roles', async () => {
    setRole('OPERATOR')
    renderPage()
    expect(screen.getByText(/inventory-report APIs are restricted/)).toBeInTheDocument()
    expect(screen.queryByRole('tab', { name: 'FIFO cost lots' })).not.toBeInTheDocument()
    expect(api.getFifoValuation).not.toHaveBeenCalled()
    expect(api.getStockValuation).not.toHaveBeenCalled()
    expect(api.getStockSummary).not.toHaveBeenCalled()
    expect(api.getLowStockAlert).not.toHaveBeenCalled()
  })
  it('uses the warehouse valuation endpoint when selected', async () => {
    const user = userEvent.setup()
    renderPage()
    await user.click(screen.getByRole('tab', { name: 'Warehouse valuation' }))
    expect(await screen.findByRole('table', { name: 'Warehouse valuation' })).toBeInTheDocument()
    expect(api.getStockValuation).toHaveBeenCalledOnce()
  })
})
