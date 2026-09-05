import { cleanup, render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import { apiFetch } from '@/api/client/api-client'
import { listContacts } from '@/features/contacts/contacts-api'
import { useSessionStore } from '@/shared/session/session-store'
import { downloadBlob } from '@/shared/files/download-blob'
import { EstimateDetailPage } from './estimate-detail-page'
import { EstimatesPage } from './estimates-page'
import { EstimateForm } from './estimate-form'
import { createEstimate, getEstimate, getEstimatePdf, getEstimateWhatsAppLink, listEstimates, sendEstimate, updateEstimate } from './estimates-api'
import { estimateFixture, estimateTestCustomer, estimateTestUser } from './estimate-test-fixtures'

vi.mock('./estimates-api', () => ({ listEstimates: vi.fn(), getEstimate: vi.fn(), createEstimate: vi.fn(), updateEstimate: vi.fn(), deleteEstimate: vi.fn(), sendEstimate: vi.fn(), acceptEstimate: vi.fn(), declineEstimate: vi.fn(), getEstimatePdf: vi.fn(), getEstimateWhatsAppLink: vi.fn() }))
vi.mock('@/api/client/api-client', async (original) => ({ ...await original<typeof import('@/api/client/api-client')>(), apiFetch: vi.fn() }))
vi.mock('@/features/contacts/contacts-api', () => ({ listContacts: vi.fn() }))
vi.mock('@/features/items/items-api', () => ({ listItems: vi.fn() }))
vi.mock('@/shared/files/download-blob', () => ({ downloadBlob: vi.fn() }))

beforeEach(() => {
  vi.clearAllMocks()
  useSessionStore.setState({ user: estimateTestUser, status: 'authenticated' })
  vi.mocked(getEstimate).mockResolvedValue(estimateFixture)
  vi.mocked(listEstimates).mockResolvedValue({ content: [estimateFixture], page: 0, size: 25, totalElements: 26, totalPages: 2, last: false })
  vi.mocked(createEstimate).mockResolvedValue(estimateFixture)
  vi.mocked(updateEstimate).mockResolvedValue(estimateFixture)
  vi.mocked(sendEstimate).mockResolvedValue({ ...estimateFixture, status: 'SENT' })
  vi.mocked(listContacts).mockResolvedValue({ content: [estimateTestCustomer], number: 0, size: 25, totalElements: 1, totalPages: 1 })
  vi.mocked(apiFetch).mockResolvedValue({ content: [{ id: 'event-1', commentText: 'Estimate created', system: true, createdAt: '2026-09-05T06:00:00Z', createdByName: null }], number: 0, totalPages: 2, totalElements: 21 })
})
afterEach(() => { cleanup(); useSessionStore.setState({ user: null, status: 'anonymous' }) })

function renderPage(path = '/estimates/estimate-1') {
  return render(<QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false, gcTime: 0 } } })}><MemoryRouter initialEntries={[path]}><Routes><Route path="/estimates" element={<EstimatesPage />} /><Route path="/estimates/:estimateId" element={<EstimateDetailPage />} /></Routes></MemoryRouter></QueryClientProvider>)
}

it('renders server fields, correct discount/tax amounts, and a conversion blocker without exposing UUIDs', async () => {
  renderPage()
  expect(await screen.findByText('Turmeric Masala Test 100g')).toBeInTheDocument()
  const totals = screen.getByRole('heading', { name: 'Server totals' }).closest('section')!
  expect(within(totals).getByText('₹405.00')).toBeInTheDocument()
  expect(within(totals).getByText('₹72.90')).toBeInTheDocument()
  expect(within(totals).getByText('₹477.90')).toBeInTheDocument()
  expect(screen.getByRole('button', { name: 'Convert to invoice unavailable' })).toBeDisabled()
  expect(screen.queryByText('item-1')).not.toBeInTheDocument()
})

it('requires confirmation before sending and does not claim email delivery', async () => {
  const user = userEvent.setup()
  renderPage()
  await user.click(await screen.findByRole('button', { name: 'Send estimate' }))
  expect(sendEstimate).not.toHaveBeenCalled()
  expect(screen.getByText(/SENT does not guarantee delivery/)).toBeInTheDocument()
  await user.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Confirm' }))
  expect(await screen.findByText('Estimate marked SENT. Check activity for the email attempt result.')).toBeInTheDocument()
  expect(sendEstimate).toHaveBeenCalledOnce()
})

it('keeps API errors in the action dialog without marking the document sent', async () => {
  vi.mocked(sendEstimate).mockRejectedValue(new Error('Estimate is no longer editable'))
  const user = userEvent.setup()
  renderPage()
  await user.click(await screen.findByRole('button', { name: 'Send estimate' }))
  await user.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Confirm' }))
  expect(await screen.findByText('Estimate is no longer editable')).toBeInTheDocument()
  expect(screen.queryByText(/Estimate marked SENT/)).not.toBeInTheDocument()
})

it('hides write actions from viewers and draft deletion from operators', async () => {
  useSessionStore.setState({ user: { ...estimateTestUser, role: 'VIEWER' } })
  const view = renderPage()
  await screen.findByText('Turmeric Masala Test 100g')
  expect(screen.queryByRole('button', { name: /Send estimate|Edit estimate|Delete draft|Prepare WhatsApp/ })).not.toBeInTheDocument()
  expect(screen.getByRole('button', { name: 'Download PDF' })).toBeEnabled()
  view.unmount()
  useSessionStore.setState({ user: { ...estimateTestUser, role: 'OPERATOR' } })
  renderPage()
  expect(await screen.findByRole('button', { name: 'Edit estimate' })).toBeEnabled()
  expect(screen.queryByRole('button', { name: 'Delete draft' })).not.toBeInTheDocument()
})

it('loads later estimate pages and labels keyword search as page-local', async () => {
  const user = userEvent.setup()
  renderPage('/estimates')
  await screen.findByText('EST-2026-000001')
  await user.click(screen.getByRole('button', { name: 'Next page' }))
  await waitFor(() => expect(listEstimates).toHaveBeenLastCalledWith('all', undefined, 1, 25))
  expect(screen.getByRole('searchbox', { name: 'Search current estimate page' })).toBeInTheDocument()
  expect(screen.queryByText('Conversion Rate')).not.toBeInTheDocument()
})

it('shows real converted invoice links from convertedToInvoiceId', async () => {
  vi.mocked(getEstimate).mockResolvedValue({ ...estimateFixture, status: 'INVOICED', convertedToInvoiceId: 'invoice-1' })
  renderPage()
  expect(await screen.findByRole('link', { name: 'View converted invoice' })).toHaveAttribute('href', '/invoices/invoice-1')
  expect(screen.queryByRole('button', { name: 'Edit estimate' })).not.toBeInTheDocument()
})

it('blocks INR-only backend document output for non-INR quotes without changing their stored currency', async () => {
  vi.mocked(getEstimate).mockResolvedValue({ ...estimateFixture, currency: 'AED' })
  renderPage()
  expect(await screen.findByText(/External documents are unavailable for this currency/)).toBeInTheDocument()
  expect(screen.getByRole('button', { name: 'Download PDF' })).toBeDisabled()
  expect(screen.getByRole('button', { name: 'Send estimate' })).toBeDisabled()
  expect(screen.getByRole('button', { name: 'Prepare WhatsApp message' })).toBeDisabled()
  expect(getEstimatePdf).not.toHaveBeenCalled()
  expect(getEstimateWhatsAppLink).not.toHaveBeenCalled()
})

it('treats status and customer filters as alternatives and resets pagination', async () => {
  const user = userEvent.setup()
  renderPage('/estimates')
  await screen.findByText('EST-2026-000001')
  await user.click(screen.getByRole('button', { name: 'Next page' }))
  await user.type(screen.getByRole('combobox', { name: 'Filter estimates by customer' }), 'Kirana')
  await user.click(await screen.findByRole('option', { name: /Kirana Test/ }))
  await waitFor(() => expect(listEstimates).toHaveBeenLastCalledWith('all', 'customer-1', 0, 25))
  await user.click(screen.getByRole('tab', { name: 'Sent' }))
  await waitFor(() => expect(listEstimates).toHaveBeenLastCalledWith('SENT', undefined, 0, 25))
})

it('downloads the authenticated PDF and surfaces WhatsApp errors without a fabricated fallback', async () => {
  const blob = new Blob(['pdf'], { type: 'application/pdf' })
  vi.mocked(getEstimatePdf).mockResolvedValue(blob)
  vi.mocked(getEstimateWhatsAppLink).mockRejectedValue(new Error('Share service unavailable'))
  const user = userEvent.setup()
  renderPage()
  await user.click(await screen.findByRole('button', { name: 'Download PDF' }))
  await waitFor(() => expect(downloadBlob).toHaveBeenCalledWith(blob, 'estimate-EST-2026-000001.pdf'))
  await user.click(screen.getByRole('button', { name: 'Prepare WhatsApp message' }))
  expect(await screen.findByText('Share service unavailable')).toBeInTheDocument()
  expect(screen.queryByRole('link', { name: 'Open WhatsApp draft' })).not.toBeInTheDocument()
})

it('edits SENT quotations, preserves existing line tax/discount/unit, and omits currency from PUT', async () => {
  vi.mocked(getEstimate).mockResolvedValue({ ...estimateFixture, status: 'SENT' })
  const user = userEvent.setup()
  renderPage()
  await user.click(await screen.findByRole('button', { name: 'Edit estimate' }))
  expect(screen.getByLabelText('Line 1 discountPct')).toHaveValue(10)
  expect(screen.getByLabelText('Line 1 taxRate')).toHaveValue(18)
  expect(screen.getByLabelText('Currency')).toBeDisabled()
  await user.clear(screen.getByLabelText('Customer notes'))
  await user.click(screen.getByRole('button', { name: 'Save changes' }))
  await waitFor(() => expect(updateEstimate).toHaveBeenCalledWith('estimate-1', expect.objectContaining({ notes: '', lines: [expect.objectContaining({ unit: 'PCS', discountPct: 10, taxRate: 18 })] })))
  expect(vi.mocked(updateEstimate).mock.calls[0]?.[1]).not.toHaveProperty('currency')
})

it('creates a free-text quote using the searched customer and exact line fields', async () => {
  const user = userEvent.setup()
  const saved = vi.fn()
  render(<QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false, gcTime: 0 } } })}><EstimateForm onSaved={saved} onCancel={vi.fn()} /></QueryClientProvider>)
  const customer = screen.getByRole('combobox', { name: 'Search estimate customer' })
  await user.type(customer, 'Kirana')
  await user.click(await screen.findByRole('option', { name: /Kirana Test/ }))
  await user.click(screen.getByRole('button', { name: 'Add service / free-text line' }))
  await user.type(screen.getByLabelText('Line 1 description'), 'Packing service')
  await user.clear(screen.getByLabelText('Line 1 quantity'))
  await user.type(screen.getByLabelText('Line 1 quantity'), '10')
  await user.clear(screen.getByLabelText('Line 1 rate'))
  await user.type(screen.getByLabelText('Line 1 rate'), '45')
  await user.clear(screen.getByLabelText('Line 1 discountPct'))
  await user.type(screen.getByLabelText('Line 1 discountPct'), '10')
  await user.clear(screen.getByLabelText('Line 1 taxRate'))
  await user.type(screen.getByLabelText('Line 1 taxRate'), '18')
  await user.click(screen.getByRole('button', { name: 'Save estimate' }))
  await waitFor(() => expect(createEstimate).toHaveBeenCalledWith(expect.objectContaining({ contactId: 'customer-1', lines: [expect.objectContaining({ description: 'Packing service', quantity: 10, rate: 45, discountPct: 10, taxRate: 18 })] })))
  expect(saved).toHaveBeenCalledWith(estimateFixture)
})

it('paginates activity independently of the estimate and displays system comments', async () => {
  const user = userEvent.setup()
  renderPage()
  expect(await screen.findByText('Estimate created')).toBeInTheDocument()
  await user.click(screen.getByRole('button', { name: 'Next page' }))
  await waitFor(() => expect(apiFetch).toHaveBeenLastCalledWith('/api/v1/comments/ESTIMATE/estimate-1?page=1&size=20'))
})
