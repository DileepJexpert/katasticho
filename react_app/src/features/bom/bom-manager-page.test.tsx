import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import { BomManagerPage } from './bom-manager-page'
import * as bomApi from './bom-api'
import * as itemsApi from '@/features/items/items-api'

vi.mock('./bom-api', () => ({
  getLatestBomVersion: vi.fn(),
  getBomVersion: vi.fn(),
  diffBomVersions: vi.fn(),
  getBomCostRollup: vi.fn(),
  listBomAlternates: vi.fn(),
  listBomCoProducts: vi.fn(),
  createBomVersion: vi.fn(),
}))

vi.mock('@/features/items/items-api', () => ({
  listItems: vi.fn(),
}))

const mockParentItem: itemsApi.Item = {
  id: 'item-parent-1',
  name: 'Ayurvedic Cough Syrup 100ml',
  sku: 'ACS-100',
  itemType: 'GOODS',
  unitOfMeasure: 'BTL',
  active: true,
} as unknown as itemsApi.Item

describe('BomManagerPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
    vi.clearAllMocks()

    vi.mocked(itemsApi.listItems).mockResolvedValue({
      content: [mockParentItem],
      page: 0,
      size: 25,
      totalElements: 1,
      totalPages: 1,
      last: true,
    })

    vi.mocked(bomApi.getLatestBomVersion).mockResolvedValue({ version: 1 })
    vi.mocked(bomApi.getBomVersion).mockResolvedValue([
      {
        id: 'comp-1',
        parentItemId: 'item-parent-1',
        componentItemId: 'raw-1',
        componentItemName: 'Adhatoda Vasica Extract',
        quantity: 0.05,
        scrapFactorPercent: 2,
        costAllocationPercent: 100,
        version: 1,
      },
    ])

    vi.mocked(bomApi.diffBomVersions).mockResolvedValue({
      added: [{ itemId: 'raw-2', itemName: 'Tulsi Extract', quantity: 0.02 }],
      removed: [],
      changed: [],
    })

    vi.mocked(bomApi.getBomCostRollup).mockResolvedValue({
      itemId: 'item-parent-1',
      itemName: 'Ayurvedic Cough Syrup 100ml',
      rawMaterialCost: 25,
      laborCost: 5,
      overheadCost: 2,
      totalUnitCost: 32,
      components: [
        {
          itemId: 'raw-1',
          itemName: 'Adhatoda Vasica Extract',
          qtyRequired: 0.05,
          unitCost: 500,
          lineCost: 25,
        },
      ],
    })

    vi.mocked(bomApi.listBomAlternates).mockResolvedValue([
      {
        id: 'alt-1',
        bomComponentId: 'comp-1',
        alternateItemId: 'raw-alt-1',
        alternateItemName: 'Synthetic Vasaka Powder',
        priority: 1,
        notes: 'Backup supplier grade',
      },
    ])

    vi.mocked(bomApi.listBomCoProducts).mockResolvedValue([
      {
        id: 'cop-1',
        parentItemId: 'item-parent-1',
        coProductItemId: 'by-1',
        coProductItemName: 'Herbal Spent Marc (Biofuel)',
        quantityPerUnit: 0.1,
        costAllocationPercent: 0,
      },
    ])
  })

  function renderPage() {
    return render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter>
          <BomManagerPage />
        </MemoryRouter>
      </QueryClientProvider>
    )
  }

  it('renders initial empty guidance when no parent item is selected', () => {
    renderPage()

    expect(screen.getByText(/BOM & Engineering Workbench/i)).toBeInTheDocument()
    expect(
      screen.getByText(/Select a parent assembly or finished good above to manage its Bill of Materials\./i)
    ).toBeInTheDocument()
  })

  it('selects parent item using EntityPicker and displays components', async () => {
    const user = userEvent.setup()
    renderPage()

    const combobox = screen.getByRole('combobox', { name: /Parent Assembly \/ Finished Good/i })
    await user.click(combobox)

    const option = await screen.findByRole('option', { name: /Ayurvedic Cough Syrup 100ml/i })
    await user.click(option)

    await waitFor(() => {
      expect(screen.getByText('Latest: v1')).toBeInTheDocument()
    })

    expect(screen.getByText('Adhatoda Vasica Extract')).toBeInTheDocument()
    expect(screen.getAllByText(/v1/i).length).toBeGreaterThan(0)
  })

  it('allows navigating tabs and displays cost roll-up and substitute materials', async () => {
    const user = userEvent.setup()
    renderPage()

    // Select parent item
    await user.click(screen.getByRole('combobox', { name: /Parent Assembly \/ Finished Good/i }))
    const option = await screen.findByRole('option', { name: /Ayurvedic Cough Syrup 100ml/i })
    await user.click(option)

    await waitFor(() => {
      expect(screen.getByText('Adhatoda Vasica Extract')).toBeInTheDocument()
    })

    // Click Cost Roll-up tab
    const costTab = screen.getByRole('button', { name: /^Cost Roll-up$/i })
    await user.click(costTab)

    await waitFor(() => {
      expect(screen.getByText(/Calculated Unit Manufacturing Cost:/i)).toBeInTheDocument()
    })
    expect(screen.getByText('₹32.00')).toBeInTheDocument()

    // Click Substitute Materials tab
    const alternatesTab = screen.getByRole('button', { name: /^Substitute Materials$/i })
    await user.click(alternatesTab)

    await waitFor(() => {
      expect(screen.getByText('Synthetic Vasaka Powder')).toBeInTheDocument()
    })
    expect(screen.getByText('Backup supplier grade')).toBeInTheDocument()
  })

  it('creates a new BOM version through the modal', async () => {
    vi.mocked(bomApi.createBomVersion).mockResolvedValue({ version: 2 })
    const user = userEvent.setup()
    renderPage()

    // Select parent item
    await user.click(screen.getByRole('combobox', { name: /Parent Assembly \/ Finished Good/i }))
    const option = await screen.findByRole('option', { name: /Ayurvedic Cough Syrup 100ml/i })
    await user.click(option)

    await waitFor(() => {
      expect(screen.getByText('Latest: v1')).toBeInTheDocument()
    })

    const createBtn = screen.getByRole('button', { name: /Create BOM Version/i })
    await user.click(createBtn)

    const modal = screen.getByRole('dialog', { name: /Create New BOM Version/i })
    expect(modal).toBeInTheDocument()

    const notesInput = within(modal).getByPlaceholderText(/Reason for revision/i)
    await user.type(notesInput, 'Swapped active packaging supplier')

    const submitBtn = within(modal).getByRole('button', { name: /^Create Version 2$/i })
    await user.click(submitBtn)

    await waitFor(() => {
      expect(bomApi.createBomVersion).toHaveBeenCalledWith('item-parent-1', 'Swapped active packaging supplier')
    })
  })
})
