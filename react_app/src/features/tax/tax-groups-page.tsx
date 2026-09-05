import { useMemo, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Layers } from 'lucide-react'
import { Button, DataTable, DirectoryToolbar, EmptyState, Modal, PageHeader, SearchInput, StatusChip } from '@/design-system'
import { getTaxGroups, type TaxGroupResponse } from '@/features/tax/tax-groups-api'
import { useSessionStore } from '@/shared/session/session-store'

export function TaxGroupsPage() {
  const role = useSessionStore((state) => state.user?.role) ?? ''
  const canRead = ['OWNER', 'ADMIN', 'ACCOUNTANT', 'VIEWER'].includes(role)
  const [page, setPage] = useState(0)
  const [search, setSearch] = useState('')
  const [selectedGroup, setSelectedGroup] = useState<TaxGroupResponse | null>(null)

  const taxGroupsQuery = useQuery({
    queryKey: ['tax-groups'],
    queryFn: () => getTaxGroups(),
    enabled: canRead,
  })

  const groups = taxGroupsQuery.data ?? []

  const filteredGroups = useMemo(() => {
    const query = search.trim().toLowerCase()
    return groups.filter((group) => {
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
  }, [groups, search])
  const pages = Math.max(1, Math.ceil(filteredGroups.length / 25))
  const currentPage = Math.min(page, pages - 1)

  if (!canRead) return <section className="workspace-page"><PageHeader title="Tax groups" /><p role="alert">Your role cannot read tax-group definitions.</p></section>

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Tax & Compliance / Rates"
        title="Tax groups"
        description="Review active tax groups and their configured component rates. The existing API has no tax-group create, update, or delete operation."
      />
      <p className="cell-muted">This directory endpoint returns active groups only. Component sums are reference information; the backend determines transaction tax and posting.</p>

      <section className="list-panel" aria-label="Tax groups directory">
        <DirectoryToolbar ariaLabel="Search active tax groups">
          <SearchInput
            onChange={(value) => { setSearch(value); setPage(0) }}
            onClear={() => { setSearch(''); setPage(0) }}
            placeholder="Search tax groups or rates..."
            value={search}
          />
        </DirectoryToolbar>

        {taxGroupsQuery.isError ? (
          <div className="directory-state directory-state--error" role="alert">
            <strong>Tax groups could not be loaded.</strong>
            <p>{taxGroupsQuery.error.message}</p>
            <Button variant="secondary" onClick={() => void taxGroupsQuery.refetch()}>Retry tax groups</Button>
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
                <th scope="col" className="numeric-cell">Component sum</th>
                <th scope="col">Status</th>
                <th scope="col">Action</th>
              </tr>
            </thead>
            <tbody>
              {filteredGroups.slice(currentPage * 25, currentPage * 25 + 25).map((group) => {
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
              !search
                ? 'Tax groups will appear here when configured for your organisation.'
                : 'No tax groups match the selected filter or search query.'
            }
            icon={Layers}
            title={
              !search
                ? 'No tax groups are available.'
                : 'No matching tax groups.'
            }
          />
        )}
        {!taxGroupsQuery.isError && !taxGroupsQuery.isPending && <div className="document-actions">
          <Button variant="secondary" disabled={currentPage === 0} onClick={() => setPage(currentPage - 1)}>Previous tax groups</Button>
          <span>{filteredGroups.length} active groups{search ? ' matching this search' : ''}. Page {currentPage + 1} of {pages}</span>
          <Button variant="secondary" disabled={currentPage + 1 >= pages} onClick={() => setPage(currentPage + 1)}>Next tax groups</Button>
        </div>}
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
