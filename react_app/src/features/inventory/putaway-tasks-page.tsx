import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button, DataTable, DirectoryToolbar, PageHeader, SearchInput, SelectInput, StatusChip } from '@/design-system'
import { listWarehouses } from '@/features/warehouses/warehouses-api'
import { formatDateTime } from '@/shared/format/format'
import { useInventoryAccess } from './inventory-access'
import { listPutawayTasks } from './putaway-api'

export function PutawayTasksPage() {
  const access = useInventoryAccess()
  const [status, setStatus] = useState('')
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(0)
  const query = useQuery({ queryKey: ['putaway-tasks', status], queryFn: () => listPutawayTasks(status || undefined), enabled: access.operate })
  const warehouses = useQuery({ queryKey: ['warehouses'], queryFn: listWarehouses, enabled: access.operate })
  const warehouseName = (id: string) => warehouses.data?.find((warehouse) => warehouse.id === id)?.name ?? id
  const rows = (query.data ?? []).filter((task) => [task.taskNumber, task.sourceLocation, warehouseName(task.warehouseId)].some((value) => value?.toLowerCase().includes(search.trim().toLowerCase())))
  const pages = Math.max(1, Math.ceil(rows.length / 25))
  const currentPage = Math.min(page, pages - 1)
  return <section className="workspace-page">
    <PageHeader eyebrow="Inventory / Storage" title="Warehouse putaway" description="Record physical placement in warehouse racks. Stock receipt and inventory quantities remain separate."
      actions={access.operate && <Link className="button button--primary" to={appRoutes.putawayCreate}>New putaway task</Link>} />
    {!access.operate ? <p>Your role cannot access putaway tasks.</p> : <section className="list-panel">
      <DirectoryToolbar ariaLabel="Filter putaway tasks">
        <SearchInput value={search} onChange={(value) => { setSearch(value); setPage(0) }} onClear={() => setSearch('')} placeholder="Search task, warehouse or source" />
        <SelectInput aria-label="Putaway status" value={status} onChange={(event) => { setStatus(event.target.value); setPage(0) }} placeholderOption="All statuses" options={['PENDING', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'].map((value) => ({ value, label: value.replaceAll('_', ' ') }))} />
      </DirectoryToolbar>
      {query.isError ? <div role="alert">{query.error.message}<Button variant="secondary" onClick={() => void query.refetch()}>Retry tasks</Button></div> : query.isPending ? <p role="status">Loading putaway tasks...</p> : <>
        <DataTable caption="Putaway tasks"><thead><tr><th>Task</th><th>Warehouse</th><th>Source</th><th>Progress</th><th>Created</th><th>Status</th></tr></thead>
          <tbody>{rows.slice(currentPage * 25, currentPage * 25 + 25).map((task) => <tr key={task.id}>
            <td><Link to={appRoutes.putawayDetail(task.id)}><code>{task.taskNumber}</code></Link></td><td>{warehouseName(task.warehouseId)}</td>
            <td>{task.sourceLocation ?? '--'}</td><td>{task.lines.filter((line) => line.status === 'CONFIRMED').length} / {task.lines.length} confirmed</td>
            <td>{formatDateTime(task.createdAt)}</td><td><StatusChip status={task.status} /></td>
          </tr>)}</tbody>
        </DataTable>
        {!rows.length && <p>No putaway tasks match these filters.</p>}
        <div className="document-actions"><Button variant="secondary" disabled={currentPage === 0} onClick={() => setPage(currentPage - 1)}>Previous tasks</Button><span>Page {currentPage + 1} of {pages}</span><Button variant="secondary" disabled={currentPage + 1 >= pages} onClick={() => setPage(currentPage + 1)}>Next tasks</Button></div>
      </>}
    </section>}
  </section>
}
