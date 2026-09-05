import { act, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { beforeEach, expect, it, vi } from 'vitest'
import { useSessionStore } from '@/shared/session/session-store'
import { enterpriseUser } from '@/features/accounting/enterprise-test-fixtures'
import { PdfTemplateCustomizerPage } from './pdf-template-customizer-page'
import { getPdfTemplate, savePdfTemplate, type PdfTemplateSetting } from './settings-api'

vi.mock('./settings-api', () => ({ getPdfTemplate: vi.fn(), savePdfTemplate: vi.fn() }))
const template: PdfTemplateSetting = { documentType: 'INVOICE', templateTheme: 'CLASSIC', primaryColor: '#0F8576', headerLayout: 'LOGO_LEFT', showGstColumns: false, showHsnColumn: false, showPaymentQr: false, showTerms: false, termsAndConditions: 'Original terms', showSignature: false, signatureLabel: 'Approved by', watermarkText: 'DRAFT', active: true }
beforeEach(() => {
  vi.resetAllMocks()
  useSessionStore.setState({ user: enterpriseUser, status: 'authenticated' })
  vi.mocked(getPdfTemplate).mockImplementation(async (documentType) => ({ ...template, documentType }))
  vi.mocked(savePdfTemplate).mockImplementation(async (payload) => payload)
})
function renderPage() { return render(<QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}><PdfTemplateCustomizerPage /></QueryClientProvider>) }
it('preserves false settings and saves only supported API fields, including cleared text', async () => {
  const user = userEvent.setup(); renderPage()
  expect(await screen.findByLabelText('GST columns')).not.toBeChecked()
  expect(screen.getByLabelText('Signature')).not.toBeChecked()
  await user.click(screen.getByLabelText('HSN column'))
  await user.clear(screen.getByLabelText('Terms and conditions'))
  await user.clear(screen.getByLabelText('Watermark'))
  await user.click(screen.getByRole('button', { name: 'Save template' }))
  await waitFor(() => expect(savePdfTemplate).toHaveBeenCalledWith({ ...template, showHsnColumn: true, termsAndConditions: '', watermarkText: '' }))
  expect(await screen.findByText('Template configuration saved.')).toBeInTheDocument()
})
it('keeps edits visible after a failed save', async () => {
  vi.mocked(savePdfTemplate).mockRejectedValue(new Error('Template update rejected'))
  const user = userEvent.setup(); renderPage()
  await user.clear(await screen.findByLabelText('Signature label'))
  await user.type(screen.getByLabelText('Signature label'), 'Manager')
  await user.click(screen.getByRole('button', { name: 'Save template' }))
  expect(await screen.findByRole('alert')).toHaveTextContent('Template update rejected')
  expect(screen.getByLabelText('Signature label')).toHaveValue('Manager')
})
it('does not let an older document response overwrite the selected document', async () => {
  let resolveInvoice!: (value: PdfTemplateSetting) => void
  vi.mocked(getPdfTemplate).mockImplementation((type) => type === 'INVOICE' ? new Promise((resolve) => { resolveInvoice = resolve }) : Promise.resolve({ ...template, documentType: type, watermarkText: 'BILL ONLY' }))
  const user = userEvent.setup(); renderPage()
  await user.click(screen.getByRole('tab', { name: 'BILL' }))
  expect(await screen.findByLabelText('Watermark')).toHaveValue('BILL ONLY')
  await act(async () => resolveInvoice(template))
  expect(screen.getByLabelText('Watermark')).toHaveValue('BILL ONLY')
  await user.click(screen.getByRole('button', { name: 'Save template' }))
  await waitFor(() => expect(savePdfTemplate).toHaveBeenCalledWith(expect.objectContaining({ documentType: 'BILL', watermarkText: 'BILL ONLY' })))
})
it('does not load or save templates for a viewer', () => {
  useSessionStore.setState({ user: { ...enterpriseUser, role: 'VIEWER' } }); renderPage()
  expect(screen.getByRole('alert')).toHaveTextContent('Owner or Admin')
  expect(getPdfTemplate).not.toHaveBeenCalled()
  expect(screen.queryByRole('button', { name: 'Save template' })).not.toBeInTheDocument()
})
