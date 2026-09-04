import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { Cpu, Plus, Search, CalendarClock, Wrench } from 'lucide-react'
import { Link } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import {
  Button,
  DataTable,
  FormField,
  FormGrid,
  Modal,
  Money,
  NumberInput,
  PageHeader,
  StatusChip,
  TextInput,
} from '@/design-system'
import { listWorkstations, createWorkstation } from '@/features/maintenance/maintenance-api'

export function WorkCentersPage() {
  const queryClient = useQueryClient()
  const [search, setSearch] = useState('')
  const [isCreateOpen, setIsCreateOpen] = useState(false)
  const [code, setCode] = useState('')
  const [name, setName] = useState('')
  const [desc, setDesc] = useState('')
  const [rate, setRate] = useState('120')
  const [capacity, setCapacity] = useState('16')

  const query = useQuery({
    queryKey: ['workstations'],
    queryFn: listWorkstations,
  })

  const createMutation = useMutation({
    mutationFn: () => createWorkstation({
      code,
      name,
      description: desc,
      hourlyRate: Number(rate),
      capacityHoursPerDay: Number(capacity),
    }),
    onSuccess: () => {
      setIsCreateOpen(false)
      setCode('')
      setName('')
      queryClient.invalidateQueries({ queryKey: ['workstations'] })
    },
  })

  const rawList = query.data ?? []
  const filtered = rawList.filter((w) => {
    if (!search.trim()) return true
    const q = search.toLowerCase()
    return w.code.toLowerCase().includes(q) || w.name.toLowerCase().includes(q)
  })

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Manufacturing / Equipment"
        title="Work Centers"
        description="Plant machinery, machine capacity, hourly cost absorption rates, and preventive maintenance tracking."
        actions={
          <div className="table-actions">
            <Link to="/maintenance-schedules">
              <Button variant="secondary">
                <CalendarClock aria-hidden="true" size={16} />
                PM Schedules
              </Button>
            </Link>
            <Link to="/maintenance-work-orders">
              <Button variant="secondary">
                <Wrench aria-hidden="true" size={16} />
                Maintenance Orders
              </Button>
            </Link>
            <Button onClick={() => setIsCreateOpen(true)} variant="primary">
              <Plus aria-hidden="true" size={16} />
              Add Work Center
            </Button>
          </div>
        }
      />

      <div className="list-toolbar">
        <label className="directory-search">
          <Search aria-hidden="true" size={18} />
          <span className="sr-only">Search work centers</span>
          <input
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by code or machine name..."
            type="search"
            value={search}
          />
        </label>
      </div>

      {query.isLoading ? (
        <div className="directory-state">Loading work centers...</div>
      ) : filtered.length === 0 ? (
        <div className="directory-state">
          <Cpu size={24} />
          <strong>No work centers found.</strong>
        </div>
      ) : (
        <DataTable caption="Plant work centers and production machines">
          <thead>
            <tr>
              <th scope="col">Code</th>
              <th scope="col">Work Center Name</th>
              <th className="numeric-cell" scope="col">Capacity (Hours/Day)</th>
              <th className="numeric-cell" scope="col">Hourly Rate</th>
              <th scope="col">Status</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((w) => (
              <tr key={w.id}>
                <td>
                  <Link className="table-row-link" to={appRoutes.workCenterDetail(w.id)}>
                    <code>{w.code}</code>
                  </Link>
                </td>
                <td>
                  <div className="cell-stack">
                    <strong>{w.name}</strong>
                    {w.description && <span className="cell-muted">{w.description}</span>}
                  </div>
                </td>
                <td className="numeric-cell">{w.capacityHoursPerDay}h</td>
                <td className="numeric-cell"><Money amount={w.hourlyRate} /></td>
                <td><StatusChip status={w.isActive ? 'Active' : 'Inactive'} /></td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      )}

      <Modal
        footer={
          <>
            <Button onClick={() => setIsCreateOpen(false)} variant="secondary">Cancel</Button>
            <Button
              disabled={createMutation.isPending || !code.trim() || !name.trim()}
              onClick={() => createMutation.mutate()}
              variant="primary"
            >
              {createMutation.isPending ? 'Saving...' : 'Save Work Center'}
            </Button>
          </>
        }
        isOpen={isCreateOpen}
        onClose={() => setIsCreateOpen(false)}
        size="lg"
        title="Add Work Center"
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <FormGrid columns={2}>
            <FormField label="Work Center Code" required>
              <TextInput
                onChange={(e) => setCode(e.target.value)}
                placeholder="e.g. WC-CNC-01"
                required
                value={code}
              />
            </FormField>
            <FormField label="Work Center Name" required>
              <TextInput
                onChange={(e) => setName(e.target.value)}
                placeholder="e.g. 5-Axis CNC Milling Center"
                required
                value={name}
              />
            </FormField>
          </FormGrid>
          <FormField label="Description">
            <TextInput
              onChange={(e) => setDesc(e.target.value)}
              placeholder="Optional description / location"
              value={desc}
            />
          </FormField>
          <FormGrid columns={2}>
            <FormField label="Daily Capacity (Hours)" required>
              <NumberInput
                min={1}
                onChange={(e) => setCapacity(e.target.value)}
                value={capacity}
              />
            </FormField>
            <FormField label="Standard Hourly Rate (₹)" required>
              <NumberInput
                min={0}
                onChange={(e) => setRate(e.target.value)}
                step="0.01"
                value={rate}
              />
            </FormField>
          </FormGrid>
        </div>
      </Modal>
    </section>
  )
}