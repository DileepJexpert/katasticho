import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  Clock,
  Plus,
  X,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import {
  listShifts,
  upsertShift,
  type Shift,
} from '@/features/hr/hr-api'

export function ShiftsPage() {
  const [isShiftModalOpen, setIsShiftModalOpen] = useState(false)
  const queryClient = useQueryClient()

  const shiftsQuery = useQuery({
    queryKey: ['hr-shifts'],
    queryFn: () => listShifts(),
  })

  const upsertMutation = useMutation({
    mutationFn: (req: Partial<Shift>) => upsertShift(req),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['hr-shifts'] })
      setIsShiftModalOpen(false)
    },
  })

  const shifts = shiftsQuery.data ?? []

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Core HR"
        title="Shift Schedules & Rostering"
        description="Shift timings, morning/evening/night rosters, grace periods, and weekly off policies."
        actions={
          <div className="table-actions">
            <Button onClick={() => setIsShiftModalOpen(true)} variant="primary">
              <Plus aria-hidden="true" size={16} />
              Create Shift
            </Button>
          </div>
        }
      />

      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">Active Shifts</span>
          <strong className="summary-card__value">{shifts.filter((s) => s.active).length}</strong>
          <span className="summary-card__hint">Operational shift timings</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">General Shift</span>
          <strong className="summary-card__value">09:00 â€“ 18:00</strong>
          <span className="summary-card__hint">Standard 9-hr window</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Night Shift</span>
          <strong className="summary-card__value">21:00 â€“ 06:00</strong>
          <span className="summary-card__hint">Night differential active</span>
        </div>
      </div>

      {shiftsQuery.isLoading ? (
        <div className="directory-state">Loading shift definitions...</div>
      ) : shifts.length === 0 ? (
        <div className="directory-state">
          <Clock aria-hidden="true" size={24} />
          <strong>No shifts configured.</strong>
          <p>Click "Create Shift" to define morning, evening, or night rosters.</p>
        </div>
      ) : (
        <DataTable caption="Configured shifts and timing windows">
          <thead>
            <tr>
              <th scope="col">Code</th>
              <th scope="col">Shift Name</th>
              <th scope="col">Start Time</th>
              <th scope="col">End Time</th>
              <th scope="col">Weekly Offs</th>
              <th scope="col">Status</th>
            </tr>
          </thead>
          <tbody>
            {shifts.map((s) => (
              <tr key={s.id}>
                <td><code className="table-code">{s.code}</code></td>
                <td><strong>{s.name}</strong></td>
                <td>{s.startTime}</td>
                <td>{s.endTime}</td>
                <td>{s.weeklyOffs || 'Sunday'}</td>
                <td><StatusChip status={s.active ? 'Active' : 'Inactive'} /></td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      )}

      {/* Create Shift Modal */}
      {isShiftModalOpen ? (
        <div className="modal-backdrop" role="presentation">
          <div aria-labelledby="shift-title" aria-modal="true" className="modal-dialog" role="dialog">
            <div className="modal-header">
              <h2 id="shift-title">Create Shift Timing</h2>
              <button className="icon-button" onClick={() => setIsShiftModalOpen(false)} type="button">
                <X aria-hidden="true" size={18} />
              </button>
            </div>
            <form
              onSubmit={(e) => {
                e.preventDefault()
                const fd = new FormData(e.currentTarget)
                upsertMutation.mutate({
                  code: String(fd.get('code') ?? '').trim().toUpperCase(),
                  name: String(fd.get('name') ?? '').trim(),
                  startTime: String(fd.get('startTime') ?? '09:00'),
                  endTime: String(fd.get('endTime') ?? '18:00'),
                  weeklyOffs: String(fd.get('weeklyOffs') ?? 'Sunday'),
                  active: true,
                })
              }}
            >
              <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                <div>
                  <label className="form-label">Shift Code *</label>
                  <input className="text-input" name="code" placeholder="e.g. GS / MS / NS" required style={{ textTransform: 'uppercase' }} type="text" />
                </div>
                <div>
                  <label className="form-label">Shift Name *</label>
                  <input className="text-input" name="name" placeholder="e.g. General Shift (Day)" required type="text" />
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                  <div>
                    <label className="form-label">Start Time</label>
                    <input className="text-input" defaultValue="09:00" name="startTime" required type="time" />
                  </div>
                  <div>
                    <label className="form-label">End Time</label>
                    <input className="text-input" defaultValue="18:00" name="endTime" required type="time" />
                  </div>
                </div>
                <div>
                  <label className="form-label">Weekly Off Days</label>
                  <input className="text-input" defaultValue="Sunday" name="weeklyOffs" placeholder="e.g. Saturday, Sunday" type="text" />
                </div>
              </div>
              <div className="modal-footer">
                <Button onClick={() => setIsShiftModalOpen(false)} type="button" variant="secondary">Cancel</Button>
                <Button disabled={upsertMutation.isPending} type="submit" variant="primary">Save Shift</Button>
              </div>
            </form>
          </div>
        </div>
      ) : null}
    </section>
  )
}
