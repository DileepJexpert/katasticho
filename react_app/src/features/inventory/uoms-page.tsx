import { useMemo, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Scale } from 'lucide-react'
import { DataTable, DirectoryToolbar, EmptyState, FilterTabs, PageHeader, SearchInput, StatusChip } from '@/design-system'
import { getUoms, type UomCategory } from '@/features/inventory/uoms-api'

type CategoryFilter = 'ALL' | UomCategory

const CATEGORY_LABELS: Record<UomCategory, string> = {
  COUNT: 'Count',
  WEIGHT: 'Weight',
  VOLUME: 'Volume',
  LENGTH: 'Length',
  AREA: 'Area',
  TIME: 'Time',
}

export function UomsPage() {
  const [filter, setFilter] = useState<CategoryFilter>('ALL')
  const [search, setSearch] = useState('')

  const uomsQuery = useQuery({
    queryKey: ['uoms'],
    queryFn: () => getUoms(),
  })

  const uoms = uomsQuery.data ?? []

  const filteredUoms = useMemo(() => {
    const query = search.trim().toLowerCase()
    return uoms.filter((uom) => {
      const matchesCategory = filter === 'ALL' || uom.category === filter
      if (!matchesCategory) return false

      if (!query) return true

      const matchesName = uom.name.toLowerCase().includes(query)
      const matchesAbbreviation = uom.abbreviation.toLowerCase().includes(query)
      return matchesName || matchesAbbreviation
    })
  }, [uoms, filter, search])

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Inventory / Measurement"
        title="Units of measure"
        description="Read-only catalog of measurement units and conversion baselines. Unit configurations and custom ratios remain in Flutter during migration."
      />

      <section className="list-panel" aria-label="Units of measure directory">
        <DirectoryToolbar ariaLabel="Filter units of measure by category and search">
          <SearchInput
            onChange={setSearch}
            onClear={() => setSearch('')}
            placeholder="Search unit name or symbol..."
            value={search}
          />
          <FilterTabs
            activeValue={filter}
            ariaLabel="Filter units by category"
            items={[
              { value: 'ALL', label: 'All units', count: uoms.length },
              { value: 'COUNT', label: 'Count', count: uoms.filter((u) => u.category === 'COUNT').length },
              { value: 'WEIGHT', label: 'Weight', count: uoms.filter((u) => u.category === 'WEIGHT').length },
              { value: 'VOLUME', label: 'Volume', count: uoms.filter((u) => u.category === 'VOLUME').length },
              { value: 'LENGTH', label: 'Length', count: uoms.filter((u) => u.category === 'LENGTH').length },
              { value: 'AREA', label: 'Area', count: uoms.filter((u) => u.category === 'AREA').length },
              { value: 'TIME', label: 'Time', count: uoms.filter((u) => u.category === 'TIME').length },
            ]}
            onChange={(value) => setFilter(value as CategoryFilter)}
          />
        </DirectoryToolbar>

        {uomsQuery.isError ? (
          <div className="directory-state directory-state--error" role="alert">
            <strong>Units of measure could not be loaded.</strong>
            <p>Check your connection and permissions, then refresh the page.</p>
          </div>
        ) : uomsQuery.isLoading ? (
          <div aria-live="polite" className="directory-state">Loading units of measure...</div>
        ) : filteredUoms.length ? (
          <DataTable caption="Units of measure">
            <thead>
              <tr>
                <th scope="col">Unit name</th>
                <th scope="col">Abbreviation</th>
                <th scope="col">Category</th>
                <th scope="col">Baseline</th>
                <th scope="col">Status</th>
              </tr>
            </thead>
            <tbody>
              {filteredUoms.map((uom) => (
                <tr key={uom.id}>
                  <td><strong>{uom.name}</strong></td>
                  <td><code className="fact-value--mono">{uom.abbreviation}</code></td>
                  <td>
                    <span className="entity-picker__option-badge">
                      {CATEGORY_LABELS[uom.category] ?? uom.category}
                    </span>
                  </td>
                  <td>
                    <StatusChip status={uom.base ? 'Base unit' : 'Derived'} />
                  </td>
                  <td>
                    <StatusChip status={uom.active ? 'Active' : 'Inactive'} />
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        ) : (
          <EmptyState
            description={
              filter === 'ALL' && !search
                ? 'Units of measure will appear here when configured.'
                : 'No units of measure match the selected category or search query.'
            }
            icon={Scale}
            title={
              filter === 'ALL' && !search
                ? 'No units of measure available.'
                : 'No matching units.'
            }
          />
        )}
      </section>
    </section>
  )
}
