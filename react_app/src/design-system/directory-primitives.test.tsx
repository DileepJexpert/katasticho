import { describe, expect, it, vi } from 'vitest'
import { fireEvent, render, screen } from '@testing-library/react'
import { DirectoryToolbar } from './directory-toolbar'
import { SearchInput } from './search-input'
import { FilterTabs } from './filter-tabs'
import { EmptyState } from './empty-state'
import { TablePagination } from './table-pagination'
import { FileText } from 'lucide-react'

describe('Directory Primitives', () => {
  it('renders DirectoryToolbar with accessible region and children', () => {
    render(
      <DirectoryToolbar ariaLabel="Invoices toolbar">
        <span data-testid="child">Filter Controls</span>
      </DirectoryToolbar>
    )
    expect(screen.getByRole('region', { name: 'Invoices toolbar' })).toBeInTheDocument()
    expect(screen.getByTestId('child')).toHaveTextContent('Filter Controls')
  })

  it('handles SearchInput typing and clear action', () => {
    const handleChange = vi.fn()
    const handleClear = vi.fn()
    render(
      <SearchInput
        onChange={handleChange}
        onClear={handleClear}
        placeholder="Search entities"
        value="inv-100"
      />
    )
    const input = screen.getByPlaceholderText('Search entities')
    expect(input).toHaveValue('inv-100')
    
    fireEvent.change(input, { target: { value: 'inv-101' } })
    expect(handleChange).toHaveBeenCalledWith('inv-101')

    const clearButton = screen.getByRole('button', { name: 'Clear search' })
    fireEvent.click(clearButton)
    expect(handleClear).toHaveBeenCalledTimes(1)
  })

  it('renders FilterTabs and allows selecting tabs with aria-selected', () => {
    const handleSelect = vi.fn()
    const options = [
      { value: 'ALL', label: 'All' },
      { value: 'PENDING', label: 'Pending', count: 3 },
      { value: 'PAID', label: 'Paid', count: 12 },
    ]
    render(
      <FilterTabs
        activeValue="PENDING"
        items={options}
        onChange={handleSelect}
      />
    )
    const pendingTab = screen.getByRole('tab', { name: /Pending/i })
    expect(pendingTab).toHaveAttribute('aria-selected', 'true')

    const paidTab = screen.getByRole('tab', { name: /Paid/i })
    expect(paidTab).toHaveAttribute('aria-selected', 'false')

    fireEvent.click(paidTab)
    expect(handleSelect).toHaveBeenCalledWith('PAID')
  })

  it('renders EmptyState with canonical icon, headline, and action', () => {
    render(
      <EmptyState
        action={<button type="button">Create Invoice</button>}
        description="Create your first invoice to bill customers."
        icon={FileText}
        title="No invoices found"
      />
    )
    expect(screen.getByRole('status')).toBeInTheDocument()
    expect(screen.getByText('No invoices found')).toBeInTheDocument()
    expect(screen.getByText('Create your first invoice to bill customers.')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Create Invoice' })).toBeInTheDocument()
  })

  it('renders TablePagination with page navigation and disabled boundaries', () => {
    const handlePageChange = vi.fn()
    const { rerender } = render(
      <TablePagination
        itemLabel="invoice"
        onPageChange={handlePageChange}
        page={0}
        totalElements={25}
        totalPages={3}
      />
    )
    expect(screen.getByText('25 invoices in this organisation')).toBeInTheDocument()
    expect(screen.getByText('Page 1 of 3')).toBeInTheDocument()

    const prevButton = screen.getByRole('button', { name: 'Previous page' })
    const nextButton = screen.getByRole('button', { name: 'Next page' })
    expect(prevButton).toBeDisabled()
    expect(nextButton).not.toBeDisabled()

    fireEvent.click(nextButton)
    expect(handlePageChange).toHaveBeenCalledWith(1)

    rerender(
      <TablePagination
        itemLabel="invoice"
        onPageChange={handlePageChange}
        page={2}
        totalElements={25}
        totalPages={3}
      />
    )
    expect(screen.getByRole('button', { name: 'Next page' })).toBeDisabled()
  })
})
