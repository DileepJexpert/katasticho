import { fireEvent, render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { describe, expect, it } from 'vitest'
import { ReportsHubPage } from './reports-hub-page'

function renderPage() {
  return render(
    <MemoryRouter>
      <ReportsHubPage />
    </MemoryRouter>
  )
}

describe('ReportsHubPage', () => {
  it('renders report hub metrics and report catalog', () => {
    renderPage()

    expect(screen.getByRole('heading', { name: 'Reports Hub' })).toBeInTheDocument()
    expect(screen.getByText('Standard Reports')).toBeInTheDocument()
    expect(screen.getByText('Trial Balance')).toBeInTheDocument()
    expect(screen.getByText('Profit & Loss Statement')).toBeInTheDocument()
    expect(screen.getByText('Balance Sheet')).toBeInTheDocument()
  })

  it('filters reports by category tabs', () => {
    renderPage()

    const taxTab = screen.getByRole('tab', { name: /tax & gst/i })
    fireEvent.click(taxTab)

    expect(screen.queryByText('Trial Balance')).not.toBeInTheDocument()
    expect(screen.getByText('GST Return Summary')).toBeInTheDocument()
  })

  it('searches reports by search query', () => {
    renderPage()

    const searchInput = screen.getByPlaceholderText(/search report titles/i)
    fireEvent.change(searchInput, { target: { value: 'Cash Flow' } })

    expect(screen.getByText('Cash Flow Statement')).toBeInTheDocument()
    expect(screen.queryByText('Trial Balance')).not.toBeInTheDocument()
  })

  it('shows empty state when no report matches query', () => {
    renderPage()

    const searchInput = screen.getByPlaceholderText(/search report titles/i)
    fireEvent.change(searchInput, { target: { value: 'Nonexistent Report XYZ' } })

    expect(screen.getByText('No reports match these filters')).toBeInTheDocument()
  })
})
