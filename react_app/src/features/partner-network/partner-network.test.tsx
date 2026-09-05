import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, expect, it, vi } from 'vitest'
import { enterpriseUser } from '@/features/accounting/enterprise-test-fixtures'
import { useSessionStore } from '@/shared/session/session-store'
import { PartnersPage } from './partners-page'
import { CatalogPage } from './catalog-page'
import { allowedOrderActions, type CatalogItem, type NetworkOrder, type TradingPartner } from './partner-network-api'
import * as api from './partner-network-api'

vi.mock('./partner-network-api', async (importOriginal) => ({ ...await importOriginal<typeof api>(), listPartners: vi.fn(), listCatalog: vi.fn(), publishCatalogItem: vi.fn(), searchSupplierCatalog: vi.fn(), partnerAction: vi.fn() }))
const partner: TradingPartner = { id: 'partner-1', buyerOrgId: 'org-1', sellerOrgId: 'seller-1', buyerOrgName: 'Our company', sellerOrgName: 'Supplier company', status: 'PENDING', requestedByOrgId: 'org-1', creditLimit: null, paymentTerms: '30 days', deliveryTerms: null, notes: null, createdAt: '2026-09-01', approvedAt: null }
const catalog: CatalogItem = { id: 'catalog-1', sellerOrgId: 'org-1', itemId: 'item-1', drugMasterId: 'drug-1', displayName: 'Catalog tea', publishedSku: 'TEA-1', hsnCode: '0902', manufacturer: 'Grower', packSize: '100g', category: 'Tea', description: 'Keep me', publishedMrp: 50, publishedPtr: 40, minOrderQty: 1, availabilityStatus: 'BACK_ORDER', isActive: true }
beforeEach(() => {
  vi.clearAllMocks()
  useSessionStore.setState({ status: 'authenticated', user: enterpriseUser })
  vi.mocked(api.listPartners).mockResolvedValue([partner])
  vi.mocked(api.listCatalog).mockResolvedValue([catalog])
  vi.mocked(api.searchSupplierCatalog).mockResolvedValue([])
  vi.mocked(api.publishCatalogItem).mockResolvedValue({})
})
function show(page: React.ReactNode) { return render(<QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } })}><MemoryRouter>{page}</MemoryRouter></QueryClientProvider>) }

it.each([
  ['PLACED', 'org-1', ['cancel']], ['PLACED', 'seller-1', ['reject']],
  ['CONFIRMED', 'seller-1', ['dispatch']], ['PARTIALLY_CONFIRMED', 'seller-1', ['dispatch']],
  ['DISPATCHED', 'org-1', ['deliver']], ['DISPATCHED', 'seller-1', []],
  ['DELIVERED', 'org-1', []], ['CANCELLED', 'seller-1', []], ['PLACED', 'stranger', []],
])('limits %s actions for %s', (status, orgId, expected) => {
  expect(allowedOrderActions({ status, buyerOrgId: 'org-1', sellerOrgId: 'seller-1' } as NetworkOrder, orgId as string)).toEqual(expected)
})

it('prevents approving your own partnership request and explains the discovery gap', async () => {
  show(<PartnersPage />)
  expect(await screen.findByRole('button', { name: 'Supplier company' })).toBeInTheDocument()
  expect(screen.queryByRole('button', { name: /Approve/ })).not.toBeInTheDocument()
  expect(screen.getByText(/no partner discovery endpoint/)).toBeInTheDocument()
  expect(screen.queryByRole('textbox', { name: /UUID|Organisation ID/i })).not.toBeInTheDocument()
})

it('confirms an incoming partnership and refreshes the server list', async () => {
  vi.mocked(api.listPartners).mockResolvedValue([{ ...partner, requestedByOrgId: 'seller-1' }])
  show(<PartnersPage />)
  await userEvent.click(await screen.findByRole('button', { name: 'Approve Supplier company' }))
  expect(api.partnerAction).not.toHaveBeenCalled()
  await userEvent.click(screen.getByRole('button', { name: 'Confirm' }))
  await waitFor(() => expect(api.partnerAction).toHaveBeenCalledWith('partner-1', 'approve'))
  await waitFor(() => expect(api.listPartners).toHaveBeenCalledTimes(2))
})

it('does not fetch the network for an accountant', () => {
  useSessionStore.setState({ user: { ...enterpriseUser, role: 'ACCOUNTANT' } })
  show(<PartnersPage />)
  expect(api.listPartners).not.toHaveBeenCalled()
})

it('preserves legacy availability and hidden drug mapping when editing catalog metadata', async () => {
  show(<CatalogPage />)
  await userEvent.click(await screen.findByRole('button', { name: 'Edit Catalog tea' }))
  expect(screen.getByRole('combobox', { name: 'Availability' })).toHaveValue('BACK_ORDER')
  await userEvent.clear(screen.getByLabelText('Display name'))
  await userEvent.type(screen.getByLabelText('Display name'), 'Updated tea')
  await userEvent.click(screen.getByRole('button', { name: 'Publish' }))
  await waitFor(() => expect(api.publishCatalogItem).toHaveBeenCalledWith(expect.objectContaining({ itemId: 'item-1', drugMasterId: 'drug-1', displayName: 'Updated tea', description: 'Keep me', availabilityStatus: 'BACK_ORDER', publishedMrp: 50 })))
})

it('rejects blank and nonpositive catalog quantities without hiding server values', async () => {
  show(<CatalogPage />)
  await userEvent.click(await screen.findByRole('button', { name: 'Edit Catalog tea' }))
  await userEvent.clear(screen.getByLabelText('Minimum order quantity'))
  expect(screen.getByRole('button', { name: 'Publish' })).toBeDisabled()
  await userEvent.type(screen.getByLabelText('Minimum order quantity'), '0')
  expect(screen.getByRole('button', { name: 'Publish' })).toBeDisabled()
  expect(api.publishCatalogItem).not.toHaveBeenCalled()
})

it('searches supplier products on the server while withholding unsafe order placement', async () => {
  show(<CatalogPage supplier />)
  await userEvent.type(screen.getByLabelText('Search supplier products'), 'Tea')
  await userEvent.click(screen.getByRole('button', { name: 'Search suppliers' }))
  await waitFor(() => expect(api.searchSupplierCatalog).toHaveBeenLastCalledWith('Tea'))
  expect(screen.getByText(/await backend validation/)).toBeInTheDocument()
  expect(screen.queryByRole('button', { name: /Place order|Publish item/ })).not.toBeInTheDocument()
})
