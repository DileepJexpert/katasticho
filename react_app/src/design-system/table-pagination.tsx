import { ChevronLeft, ChevronRight } from 'lucide-react'

export interface TablePaginationProps {
  page: number
  totalPages: number
  totalElements: number
  onPageChange: (newPage: number) => void
  itemLabel?: string
  isFiltered?: boolean
  filterDescription?: string
}

export function TablePagination({
  page,
  totalPages,
  totalElements,
  onPageChange,
  itemLabel = 'record',
  isFiltered = false,
  filterDescription,
}: TablePaginationProps) {
  const plural = totalElements === 1 ? itemLabel : `${itemLabel}s`
  const summaryText = filterDescription
    ? `${totalElements} ${plural} ${filterDescription}`
    : isFiltered
      ? `${totalElements} ${plural} matching this search`
      : `${totalElements} ${plural} in this organisation`

  const canPrev = page > 0
  const canNext = page + 1 < totalPages

  return (
    <footer className="table-footer">
      <span>{summaryText}</span>
      <div className="pagination-actions">
        <button
          aria-label="Previous page"
          disabled={!canPrev}
          onClick={() => onPageChange(page - 1)}
          type="button"
        >
          <ChevronLeft aria-hidden="true" size={16} />
        </button>
        <span className="num">
          Page {page + 1} of {Math.max(totalPages, 1)}
        </span>
        <button
          aria-label="Next page"
          disabled={!canNext}
          onClick={() => onPageChange(page + 1)}
          type="button"
        >
          <ChevronRight aria-hidden="true" size={16} />
        </button>
      </div>
    </footer>
  )
}
