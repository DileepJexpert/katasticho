import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import { PharmacyMastersPage } from './pharmacy-masters-page'
import * as pharmacyApi from './pharmacy-api'

vi.mock('./pharmacy-api', () => ({
  searchDrugs: vi.fn(),
  searchHsn: vi.fn(),
  searchManufacturers: vi.fn(),
  getSubstitutions: vi.fn(),
  getHsnRateHistory: vi.fn(),
}))

vi.mock('@/features/inventory/rack-locations-page', () => ({
  RackLocationsWorkspace: () => <div data-testid="rack-locations-workspace">Rack Layout Mock</div>,
}))

const mockDrugs: pharmacyApi.DrugMaster[] = [
  {
    id: 'drug-1',
    brandName: 'Calpol 650 Tablet',
    genericName: 'Paracetamol',
    saltComposition: 'Paracetamol 650mg',
    manufacturer: 'GlaxoSmithKline Pharmaceuticals Ltd',
    hsnCode: '30049099',
    gstRate: 5,
    drugSchedule: 'SCHEDULE_H',
    dosageForm: 'TABLET',
    packSize: '15 Tablets',
    mrp: 32.5,
    prescriptionRequired: false,
  },
]

const mockHsnList: pharmacyApi.HsnGstMaster[] = [
  {
    id: 'hsn-1',
    hsnCode: '30049099',
    description: 'Medicaments of other substances',
    category: 'PHARMA',
    gstRate: 5,
  },
]

const mockManufacturers: pharmacyApi.ManufacturerMaster[] = [
  {
    id: 'mfg-1',
    name: 'GlaxoSmithKline Pharmaceuticals Ltd',
    country: 'IN',
    website: 'https://india-pharma.gsk.com',
  },
]

describe('PharmacyMastersPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
    vi.clearAllMocks()

    vi.mocked(pharmacyApi.searchDrugs).mockResolvedValue(mockDrugs)
    vi.mocked(pharmacyApi.searchHsn).mockResolvedValue(mockHsnList)
    vi.mocked(pharmacyApi.searchManufacturers).mockResolvedValue(mockManufacturers)
    vi.mocked(pharmacyApi.getSubstitutions).mockResolvedValue([
      {
        id: 'sub-1',
        drugMasterId: 'drug-1',
        substituteDrugMasterId: 'drug-2',
        substituteBrandName: 'Dolo 650 Tablet',
        substituteComposition: 'Paracetamol 650mg',
        manufacturer: 'Micro Labs Ltd',
        mrp: 30.5,
        estimatedSavings: 2.0,
        reason: 'Identical generic bioequivalence',
      },
    ])
    vi.mocked(pharmacyApi.getHsnRateHistory).mockResolvedValue([])
  })

  function renderPage() {
    return render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter>
          <PharmacyMastersPage />
        </MemoryRouter>
      </QueryClientProvider>
    )
  }

  it('renders drug master catalog and displays brand names', async () => {
    renderPage()

    await waitFor(() => {
      expect(screen.getByText('Calpol 650 Tablet')).toBeInTheDocument()
    })

    expect(screen.getByText('Paracetamol 650mg')).toBeInTheDocument()
    expect(screen.getByText('GlaxoSmithKline Pharmaceuticals Ltd')).toBeInTheDocument()
  })

  it('navigates to HSN and Manufacturers tabs', async () => {
    const user = userEvent.setup()
    renderPage()

    await waitFor(() => {
      expect(screen.getByText('Calpol 650 Tablet')).toBeInTheDocument()
    })

    // Click HSN tab
    const hsnTab = screen.getByRole('button', { name: /HSN & GST Directory/i })
    await user.click(hsnTab)

    await waitFor(() => {
      expect(screen.getByText('30049099')).toBeInTheDocument()
    })
    expect(screen.getByText('Medicaments of other substances')).toBeInTheDocument()

    // Click Manufacturers tab
    const mfgTab = screen.getByRole('button', { name: /Manufacturers/i })
    await user.click(mfgTab)

    await waitFor(() => {
      expect(screen.getByText('GlaxoSmithKline Pharmaceuticals Ltd')).toBeInTheDocument()
    })
    expect(screen.getByText('https://india-pharma.gsk.com')).toBeInTheDocument()
  })

  it('opens generic substitution panel when a drug row is selected', async () => {
    const user = userEvent.setup()
    renderPage()

    await waitFor(() => {
      expect(screen.getByText('Calpol 650 Tablet')).toBeInTheDocument()
    })

    // Click the substitutions button
    await user.click(screen.getByRole('button', { name: /^Substitutions$/i }))

    await waitFor(() => {
      expect(screen.getByText('Dolo 650 Tablet')).toBeInTheDocument()
    })
    expect(screen.getByText('Micro Labs Ltd')).toBeInTheDocument()
    expect(screen.getByText('Identical generic bioequivalence')).toBeInTheDocument()
  })
})
