import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { EmployeeDocumentsPage } from './employee-documents-page'
import * as hrApi from '@/features/hr/hr-api'

vi.mock('@/features/hr/hr-api', () => ({
  getMyDocuments: vi.fn(),
  getExpiringDocuments: vi.fn(),
  uploadMyDocument: vi.fn(),
  deleteEmployeeDocument: vi.fn(),
}))

describe('EmployeeDocumentsPage', () => {
  let queryClient: QueryClient

  beforeEach(() => {
    vi.clearAllMocks()
    queryClient = new QueryClient({
      defaultOptions: { queries: { retry: false } },
    })
  })

  it('renders my documents list and opens upload modal', async () => {
    vi.mocked(hrApi.getMyDocuments).mockResolvedValue([
      {
        id: 'doc-1',
        title: 'Aadhaar Card Front',
        category: 'ID_PROOF',
        expiryDate: '2030-12-31',
        uploadedAt: '2026-09-01T10:00:00Z',
      },
    ])

    render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter>
          <EmployeeDocumentsPage />
        </MemoryRouter>
      </QueryClientProvider>
    )

    expect(screen.getByText('Employee Documents')).toBeInTheDocument()
    await waitFor(() => {
      expect(screen.getByText('Aadhaar Card Front')).toBeInTheDocument()
    })

    // Click upload button
    fireEvent.click(screen.getByText('Upload Document'))
    expect(screen.getByLabelText(/Document Title/i)).toBeInTheDocument()
  })

  it('switches to expiring documents watchlist', async () => {
    vi.mocked(hrApi.getMyDocuments).mockResolvedValue([])
    vi.mocked(hrApi.getExpiringDocuments).mockResolvedValue([
      {
        id: 'doc-2',
        title: 'Drug License Reg',
        category: 'CERTIFICATE',
        expiryDate: '2026-09-20',
      },
    ])

    render(
      <QueryClientProvider client={queryClient}>
        <MemoryRouter>
          <EmployeeDocumentsPage />
        </MemoryRouter>
      </QueryClientProvider>
    )

    fireEvent.click(screen.getByText(/Expiring Watchlist/i))

    await waitFor(() => {
      expect(screen.getByText('Drug License Reg')).toBeInTheDocument()
    })
  })
})
