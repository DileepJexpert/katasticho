import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { useSessionStore } from '@/shared/session/session-store'
import { enterpriseUser } from '@/features/accounting/enterprise-test-fixtures'
import { FixedAssetsPage } from './fixed-assets-page'
import * as fixedAssetsApi from './fixed-assets-api'

vi.mock('./fixed-assets-api', () => ({
  listFixedAssets: vi.fn(),
  createFixedAsset: vi.fn(),
  getFixedAsset: vi.fn(),
}))

const mockAssets: fixedAssetsApi.FixedAsset[] = [
  {
    id: 'fa-001',
    orgId: 'org-01',
    assetCode: 'FA-2026-001',
    name: 'Eicher Pro Delivery Truck',
    category: 'Vehicles & Transport',
    acquisitionDate: '2026-01-15',
    cost: 1450000,
    residualValue: 150000,
    bookMethod: 'SLM',
    bookUsefulLifeMonths: 60,
    bookRatePct: 20,
    accumulatedDepreciation: 180000,
    itBlock: 'PLANT_AND_MACHINERY',
    itRatePct: 15,
    assetAccountCode: '1210',
    accumulatedDepAccountCode: '1219',
    depExpenseAccountCode: '6210',
    status: 'ACTIVE',
    disposalDate: null,
    disposalProceeds: null,
    disposalGainLoss: null,
    notes: null,
  },
  {
    id: 'fa-002',
    orgId: 'org-01',
    assetCode: 'FA-2026-002',
    name: 'Dell PowerEdge Rack Server',
    category: 'Computers & IT Hardware',
    acquisitionDate: '2025-06-10',
    cost: 420000,
    residualValue: 20000,
    bookMethod: 'WDV',
    bookUsefulLifeMonths: 36,
    bookRatePct: 40,
    accumulatedDepreciation: 140000,
    itBlock: 'COMPUTERS',
    itRatePct: 40,
    assetAccountCode: '1230',
    accumulatedDepAccountCode: '1239',
    depExpenseAccountCode: '6230',
    status: 'DISPOSED',
    disposalDate: '2026-08-01',
    disposalProceeds: 250000,
    disposalGainLoss: -30000,
    notes: null,
  },
]

describe('FixedAssetsPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    vi.clearAllMocks()
    useSessionStore.setState({ user: enterpriseUser, status: 'authenticated' })
    queryClient = new QueryClient({
      defaultOptions: {
        queries: { retry: false },
      },
    })
    vi.mocked(fixedAssetsApi.listFixedAssets).mockResolvedValue(mockAssets)
  })

  function renderPage() {
    return render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter>
          <FixedAssetsPage />
        </MemoryRouter>
      </QueryClientProvider>
    )
  }

  it('renders fixed asset register and KPI summary strip', async () => {
    renderPage()

    expect(await screen.findByRole('heading', { name: 'Fixed Assets Register' })).toBeInTheDocument()
    expect(await screen.findByText('FA-2026-001')).toBeInTheDocument()
    expect(screen.getByText('Eicher Pro Delivery Truck')).toBeInTheDocument()
    expect(screen.getByText('FA-2026-002')).toBeInTheDocument()
    expect(screen.getByText('Dell PowerEdge Rack Server')).toBeInTheDocument()
    expect(screen.getByText('Gross Asset Cost')).toBeInTheDocument()
    expect(screen.getByText('Accumulated Depreciation')).toBeInTheDocument()
    expect(screen.getAllByText('Net Book Value').length).toBeGreaterThanOrEqual(1)
  })

  it('filters assets by lifecycle status tabs', async () => {
    const user = userEvent.setup()
    renderPage()

    expect(await screen.findByText('FA-2026-001')).toBeInTheDocument()
    expect(screen.getByText('FA-2026-002')).toBeInTheDocument()

    const activeTab = screen.getByRole('button', { name: 'Active' })
    await user.click(activeTab)

    expect(screen.getByText('FA-2026-001')).toBeInTheDocument()
    expect(screen.queryByText('FA-2026-002')).not.toBeInTheDocument()

    const disposedTab = screen.getByRole('button', { name: 'Disposed' })
    await user.click(disposedTab)

    expect(screen.queryByText('FA-2026-001')).not.toBeInTheDocument()
    expect(screen.getByText('FA-2026-002')).toBeInTheDocument()
  })

  it('opens capitalize modal and registers a new fixed asset', async () => {
    const user = userEvent.setup()
    vi.mocked(fixedAssetsApi.createFixedAsset).mockResolvedValue({
      ...mockAssets[0]!,
      id: 'fa-003',
      assetCode: 'FA-2026-003',
      name: 'Automated Tablet Packing Machine',
      cost: 850000,
    })

    renderPage()

    const addBtn = await screen.findByRole('button', { name: /Add Fixed Asset/i })
    await user.click(addBtn)

    expect(screen.getByRole('dialog')).toBeInTheDocument()
    expect(screen.getByText('Register New Fixed Asset')).toBeInTheDocument()

    const codeInput = screen.getByPlaceholderText('FA-2026-001')
    await user.type(codeInput, 'FA-2026-003')

    const nameInput = screen.getByPlaceholderText(/e\.g\. Delivery Truck KA-01-AB-1234/i)
    await user.type(nameInput, 'Automated Tablet Packing Machine')

    const costInput = screen.getByLabelText(/Gross Cost/i)
    await user.type(costInput, '850000')

    const submitBtn = screen.getByRole('button', { name: 'Save asset' })
    await user.click(submitBtn)

    await waitFor(() => {
      expect(fixedAssetsApi.createFixedAsset).toHaveBeenCalledWith(
        expect.objectContaining({
          assetCode: 'FA-2026-003',
          name: 'Automated Tablet Packing Machine',
          cost: 850000,
        })
      )
    })
  })
  it('requires a positive WDV rate and sends it instead of a made-up default', async () => {
    const user = userEvent.setup()
    vi.mocked(fixedAssetsApi.createFixedAsset).mockResolvedValue(mockAssets[0]!)
    renderPage()
    await user.click(await screen.findByRole('button', { name: 'Add Fixed Asset' }))
    await user.type(screen.getByLabelText(/Asset Tag/), 'FA-WDV')
    await user.type(screen.getByLabelText(/Asset Name/), 'Equipment')
    await user.type(screen.getByLabelText(/Gross Cost/), '1000')
    await user.selectOptions(screen.getByLabelText('Depreciation Calculation Method'), 'WDV')
    expect(screen.getByRole('button', { name: 'Save asset' })).toBeDisabled()
    await user.type(screen.getByLabelText(/Annual WDV/), '20')
    await user.click(screen.getByRole('button', { name: 'Save asset' }))
    await waitFor(() => expect(fixedAssetsApi.createFixedAsset).toHaveBeenCalledWith(expect.objectContaining({ bookMethod: 'WDV', bookRatePct: 20 })))
  })
  it('hides asset creation for a viewer', async () => {
    useSessionStore.setState({ user: { ...enterpriseUser, role: 'VIEWER' } })
    renderPage()
    await screen.findByText('FA-2026-001')
    expect(screen.queryByRole('button', { name: 'Add Fixed Asset' })).not.toBeInTheDocument()
  })
})
