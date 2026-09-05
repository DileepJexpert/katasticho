import { useState, type ReactNode } from 'react'
import { DataTable, SearchInput, TablePagination } from '@/design-system'

/** For existing unpaged APIs: paginate the returned list, without claiming server paging. */
export function LocalDirectory<T extends { id: string }>({ rows, caption, searchText, header, renderRow }: {
  rows: T[]; caption: string; searchText: (row: T) => string; header: ReactNode; renderRow: (row: T) => ReactNode
}) {
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(0)
  const filtered = rows.filter((row) => searchText(row).toLowerCase().includes(search.trim().toLowerCase()))
  const totalPages = Math.ceil(filtered.length / 25)
  const currentPage = Math.min(page, Math.max(0, totalPages - 1))
  return <>
    <SearchInput ariaLabel={`Search ${caption}`} value={search} onChange={(value) => { setSearch(value); setPage(0) }} onClear={() => { setSearch(''); setPage(0) }} placeholder="Search loaded records" />
    <DataTable caption={caption}><thead>{header}</thead><tbody>{filtered.slice(currentPage * 25, currentPage * 25 + 25).map(renderRow)}</tbody></DataTable>
    {!filtered.length && <div className="directory-state">No matching records.</div>}
    <TablePagination page={currentPage} totalPages={totalPages} totalElements={filtered.length} onPageChange={setPage} itemLabel="record" filterDescription="in the returned list" />
  </>
}
