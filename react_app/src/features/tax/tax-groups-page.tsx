import { useMemo, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Layers } from 'lucide-react'
import { Button, DataTable, DirectoryToolbar, EmptyState, FilterTabs, Modal, PageHeader, SearchInput, StatusChip } from '@/design-system'
import { getTaxGroups, type TaxGroupResponse } from '@/features/tax/tax-groups-api'

type GroupFilter = 'ALL' | 'ACTIVE' | 'INACTIVE'

export function TaxGroupsPage() {
  const [filter, setFilter] = useState<GroupFilter>('ALL')
  const [search, setSearch] = useState('')
  const [selectedGroup, setSelectedGroup] = useState<TaxGroupResponse | null>(null)

  const taxGroupsQuery = useQuery({
    queryKey: ['tax-groups'],
    queryFn: () => getTaxGroups(),
  })

  const groups = taxGroupsQuery.data ?? []

  const filteredGroups = useMemo(() => {
    const query = search.trim().toLowerCase()
    return groups.filter((group) => {
      const matchesFilter =
        filter === 'ALL' || (filter === 'ACTIVE' ? group.active : !group.active)
      if (!matchesFilter) return false

      if (!query) return true

      const matchesName = group.name.toLowerCase().includes(query)
      const matchesDescription = group.description?.toLowerCase().includes(query) ?? false
      const matchesRates = group.rates.some(
        (r) =>
          r.rateCode.toLowerCase().includes(query) ||
          r.name.toLowerCase().includes(query) ||
          r.taxType.toLowerCase().includes(query)
      )
      return matchesName || matchesDescription || matchesRates
    })
  }, [groups, filter, search])

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Tax & Compliance / Rates"
        title="Tax groups"
        description="Read-only GST and tax rate group review. Tax rate and group management remains in Flutter during migration."
      />

      <section className="list-panel" aria-label="Tax groups directory">
        <DirectoryToolbar ariaLabel="Filter tax groups by status and search">
          <SearchInput
            onChange={setSearch}
            onClear={() => setSearch('')}
            placeholder="Search tax groups or rates..."
            value={search}
          />
          <FilterTabs
            activeValue={filter}
            ariaLabel="Filter tax groups"
            items={[
              { value: 'ALL', label: 'All groups', count: groups.length },
              { value: 'ACTIVE', label: 'Active', count: groups.filter((g) => g.active).length },
              { value: 'INACTIVE', label: 'Inactive', count: groups.filter((g) => !g.active).length },
            ]}
            onChange={(value) => setFilter(value as GroupFilter)}
          />
        </DirectoryToolbar>

        {taxGroupsQuery.isError ? (
          <div className="directory-state directory-state--error" role="alert">
            <strong>Tax groups could not be loaded.</strong>
            <p>Check your connection and permissions, then refresh the page.</p>
          </div>
        ) : taxGroupsQuery.isLoading ? (
          <div aria-live="polite" className="directory-state">Loading tax groups...</div>
        ) : filteredGroups.length ? (
          <DataTable caption="Tax groups">
            <thead>
              <tr>
                <th scope="col">Tax group</th>
                <th scope="col">Description</th>
                <th scope="col">Component rates</th>
                <th scope="col" className="numeric-cell">Total rate</th>
                <th scope="col">Status</th>
                <th scope="col">Action</th>
              </tr>
            </thead>
            <tbody>
              {filteredGroups.map((group) => {
                const totalPercentage = group.rates.reduce(
                  (sum, rate) => sum + (Number(rate.percentage) || 0),
                  0
                )
                return (
                  <tr key={group.id}>
                    <td><strong>{group.name}</strong></td>
                    <td>{group.description ?? '--'}</td>
                    <td>
                      <div className="cell-stack">
                        {group.rates.map((rate) => (
                          <span key={rate.id}>
                            {rate.rateCode} ({rate.percentage}%)
                          </span>
                        ))}
                      </div>
                    </td>
                    <td className="numeric-cell">
                      <strong>{totalPercentage}%</strong>
                    </td>
                    <td>
                      <StatusChip status={group.active ? 'Active' : 'Inactive'} />
                    </td>
                    <td>
                      <Button
                        onClick={() => setSelectedGroup(group)}
                        variant="ghost"
                      >
                        View rates
                      </Button>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </DataTable>
        ) : (
          <EmptyState
            description={
              filter === 'ALL' && !search
                ? 'Tax groups will appear here when configured for your organisation.'
                : 'No tax groups match the selected filter or search query.'
            }
            icon={Layers}
            title={
              filter === 'ALL' && !search
                ? 'No tax groups are available.'
                : 'No matching tax groups.'
            }
          />
        )}
      </section>

      {selectedGroup && (
        <Modal
          footer={
            <Button onClick={() => setSelectedGroup(null)} variant="secondary">
              Close
            </Button>
          }
          isOpen={Boolean(selectedGroup)}
          onClose={() => setSelectedGroup(null)}
          size="md"
          title={`${selectedGroup.name} composition`}
          description={selectedGroup.description ?? 'Component tax rates and recoverability.'}
        >
          <DataTable caption="Component tax rates">
            <thead>
              <tr>
                <th scope="col">Rate code</th>
                <th scope="col">Rate name</th>
                <th scope="col">Tax type</th>
                <th scope="col" className="numeric-cell">Percentage</th>
                <th scope="col">Recoverable</th>
              </tr>
            </thead>
            <tbody>
              {selectedGroup.rates.map((rate) => (
                <tr key={rate.id}>
                  <td><strong>{rate.rateCode}</strong></td>
                  <td>{rate.name}</td>
                  <td>{rate.taxType}</td>
                  <td className="numeric-cell">{rate.percentage}%</td>
                  <td>
                    <StatusChip status={rate.recoverable ? 'Recoverable' : 'Standard'} />
                  </td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        </Modal>
      )}
    </section>
  )
}
