import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { ArrowLeft, Calendar, Wrench } from 'lucide-react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import {
  getWorkstation,
  listMaintenanceSchedules,
  listMaintenanceWorkOrders,
  createMaintenanceSchedule,
  createMaintenanceWorkOrder,
} from '@/features/maintenance/maintenance-api'

export function WorkCenterDetailPage() {
  const { workstationId, workCenterId, id: routeId } = useParams()
  const id = workstationId || workCenterId || routeId
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const [isScheduleModalOpen, setIsScheduleModalOpen] = useState(false)
  const [schedTitle, setSchedTitle] = useState('')
  const [schedCode, setSchedCode] = useState('PM-MONTHLY')
  const [schedDays, setSchedDays] = useState(30)
  const [schedNextDue, setSchedNextDue] = useState('2026-10-01')

  const [isMwoModalOpen, setIsMwoModalOpen] = useState(false)
  const [mwoTitle, setMwoTitle] = useState('')
  const [mwoType, setMwoType] = useState('BREAKDOWN')
  const [mwoPriority, setMwoPriority] = useState('HIGH')

  const stationQuery = useQuery({
    queryKey: ['manufacturing-workstations', id],
    queryFn: () => getWorkstation(id!),
    enabled: Boolean(id),
  })

  const schedulesQuery = useQuery({
    queryKey: ['maintenance-schedules', id],
    queryFn: () => listMaintenanceSchedules(id!),
    enabled: Boolean(id),
  })

  const workOrdersQuery = useQuery({
    queryKey: ['maintenance-work-orders', 'workstation', id],
    queryFn: () => listMaintenanceWorkOrders(undefined, id!),
    enabled: Boolean(id),
  })

  const createSchedMutation = useMutation({
    mutationFn: () => createMaintenanceSchedule({
      workstationId: id!,
      code: schedCode,
      title: schedTitle,
      frequencyDays: schedDays,
      nextDueDate: schedNextDue,
    }),
    onSuccess: () => {
      setIsScheduleModalOpen(false)
      setSchedTitle('')
      queryClient.invalidateQueries({ queryKey: ['maintenance-schedules', id] })
    },
  })

  const createMwoMutation = useMutation({
    mutationFn: () => createMaintenanceWorkOrder({
      workstationId: id!,
      maintenanceType: mwoType,
      priority: mwoPriority,
      title: mwoTitle,
    }),
    onSuccess: () => {
      setIsMwoModalOpen(false)
      setMwoTitle('')
      queryClient.invalidateQueries({ queryKey: ['maintenance-work-orders', 'workstation', id] })
    },
  })

  if (!id) return <div className="directory-state">No Workstation ID provided.</div>
  if (stationQuery.isLoading) return <div className="directory-state">Loading work center details...</div>
  if (stationQuery.isError || !stationQuery.data) {
    return (
      <div className="directory-state directory-state--error">
        <strong>Unable to load work center.</strong>
        <Button onClick={() => navigate('/work-centers')} variant="secondary">Back to Work Centers</Button>
      </div>
    )
  }

  const station = stationQuery.data
  const schedules = schedulesQuery.data ?? []
  const workOrders = workOrdersQuery.data ?? []

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Manufacturing / Work Center"
        title={station.name}
        description={station.description || 'Plant machinery and operational work station.'}
        actions={
          <div className="table-actions">
            <span className="table-code">{station.code}</span>
            <StatusChip status={station.isActive ? 'Active' : 'Inactive'} />
          </div>
        }
      />

      <div className="document-actions">
        <Button onClick={() => navigate('/work-centers')} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to Work Centers
        </Button>
        <Button onClick={() => setIsScheduleModalOpen(true)} variant="secondary">
          <Calendar size={16} />
          Add PM Schedule
        </Button>
        <Button onClick={() => setIsMwoModalOpen(true)} variant="primary">
          <Wrench size={16} />
          Log Maintenance Order
        </Button>
      </div>

      <div className="document-layout">
        <section className="document-card">
          <h2>Machine specifications & capacity</h2>
          <dl className="document-facts">
            <div className="document-fact"><dt>Station code</dt><dd><code>{station.code}</code></dd></div>
            <div className="document-fact"><dt>Station name</dt><dd>{station.name}</dd></div>
            <div className="document-fact"><dt>Daily capacity</dt><dd>{station.capacityHoursPerDay} Hours / Day</dd></div>
            <div className="document-fact"><dt>Standard hourly rate</dt><dd><Money amount={station.hourlyRate} /></dd></div>
          </dl>
        </section>
      </div>

      <section className="document-card document-card--lines">
        <h2>Preventive Maintenance Schedules</h2>
        {schedules.length > 0 ? (
          <DataTable caption="PM routines for this work center">
            <thead>
              <tr>
                <th scope="col">Code</th>
                <th scope="col">Routine Title</th>
                <th className="numeric-cell" scope="col">Frequency</th>
                <th scope="col">Next Due Date</th>
                <th scope="col">Status</th>
              </tr>
            </thead>
            <tbody>
              {schedules.map((s) => (
                <tr key={s.id}>
                  <td><code>{s.code}</code></td>
                  <td><strong>{s.title}</strong></td>
                  <td className="numeric-cell">Every {s.frequencyDays} days</td>
                  <td>{formatDate(s.nextDueDate)}</td>
                  <td><StatusChip status={s.active ? 'Active' : 'Paused'} /></td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        ) : (
          <p className="cell-muted">No PM schedules linked to this machine.</p>
        )}
      </section>

      <section className="document-card document-card--lines">
        <h2>Maintenance & Breakdown History</h2>
        {workOrders.length > 0 ? (
          <DataTable caption="Past and ongoing maintenance work orders">
            <thead>
              <tr>
                <th scope="col">MWO #</th>
                <th scope="col">Type</th>
                <th scope="col">Title</th>
                <th scope="col">Reported Date</th>
                <th scope="col">Status</th>
                <th className="numeric-cell" scope="col">Cost</th>
              </tr>
            </thead>
            <tbody>
              {workOrders.map((mwo) => (
                <tr key={mwo.id}>
                  <td>
                    <Link className="table-row-link" to={appRoutes.maintenanceWorkOrderDetail(mwo.id)}>
                      <code>{mwo.mwoNumber}</code>
                    </Link>
                  </td>
                  <td>
                    <span className={mwo.maintenanceType === 'BREAKDOWN' ? 'status-badge status-badge--danger' : 'status-badge status-badge--info'}>
                      {mwo.maintenanceType}
                    </span>
                  </td>
                  <td><strong>{mwo.title}</strong></td>
                  <td>{formatDate(mwo.reportedAt)}</td>
                  <td><StatusChip status={formatStatusLabel(mwo.status)} /></td>
                  <td className="numeric-cell"><Money amount={mwo.cost} /></td>
                </tr>
              ))}
            </tbody>
          </DataTable>
        ) : (
          <p className="cell-muted">No maintenance work orders logged.</p>
        )}
      </section>

      {isScheduleModalOpen && (
        <div className="modal-backdrop">
          <div className="modal-card">
            <h3>Add Preventive Maintenance Schedule</h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginTop: '12px' }}>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Schedule Code:</span>
                <input
                  className="search-input"
                  onChange={(e) => setSchedCode(e.target.value)}
                  style={{ width: '100%', marginTop: '4px' }}
                  value={schedCode}
                />
              </label>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Routine Title:</span>
                <input
                  className="search-input"
                  onChange={(e) => setSchedTitle(e.target.value)}
                  placeholder="e.g. Monthly Hydraulic Fluid & Seal Check"
                  style={{ width: '100%', marginTop: '4px' }}
                  value={schedTitle}
                />
              </label>
              <div style={{ display: 'flex', gap: '12px' }}>
                <label style={{ flex: 1 }}>
                  <span style={{ fontSize: '13px', fontWeight: 600 }}>Frequency (Days):</span>
                  <input
                    className="search-input"
                    onChange={(e) => setSchedDays(Number(e.target.value))}
                    style={{ width: '100%', marginTop: '4px' }}
                    type="number"
                    value={schedDays}
                  />
                </label>
                <label style={{ flex: 1 }}>
                  <span style={{ fontSize: '13px', fontWeight: 600 }}>Next Due Date:</span>
                  <input
                    className="search-input"
                    onChange={(e) => setSchedNextDue(e.target.value)}
                    style={{ width: '100%', marginTop: '4px' }}
                    type="date"
                    value={schedNextDue}
                  />
                </label>
              </div>
            </div>
            <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end', marginTop: '16px' }}>
              <Button onClick={() => setIsScheduleModalOpen(false)} variant="secondary">Cancel</Button>
              <Button
                disabled={createSchedMutation.isPending || !schedTitle.trim()}
                onClick={() => createSchedMutation.mutate()}
                variant="primary"
              >
                Save Schedule
              </Button>
            </div>
          </div>
        </div>
      )}

      {isMwoModalOpen && (
        <div className="modal-backdrop">
          <div className="modal-card">
            <h3>Log Maintenance Work Order</h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginTop: '12px' }}>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Maintenance Type:</span>
                <select
                  className="search-input"
                  onChange={(e) => setMwoType(e.target.value)}
                  style={{ width: '100%', marginTop: '4px' }}
                  value={mwoType}
                >
                  <option value="BREAKDOWN">Breakdown / Emergency Repair</option>
                  <option value="PREVENTIVE">Preventive Maintenance (PM)</option>
                  <option value="INSPECTION">Safety / Calibration Inspection</option>
                </select>
              </label>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Title:</span>
                <input
                  className="search-input"
                  onChange={(e) => setMwoTitle(e.target.value)}
                  placeholder="e.g. Spindle bearing overheating"
                  style={{ width: '100%', marginTop: '4px' }}
                  value={mwoTitle}
                />
              </label>
              <label>
                <span style={{ fontSize: '13px', fontWeight: 600 }}>Priority:</span>
                <select
                  className="search-input"
                  onChange={(e) => setMwoPriority(e.target.value)}
                  style={{ width: '100%', marginTop: '4px' }}
                  value={mwoPriority}
                >
                  <option value="NORMAL">Normal</option>
                  <option value="HIGH">High</option>
                  <option value="URGENT">Urgent (Line Down)</option>
                </select>
              </label>
            </div>
            <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end', marginTop: '16px' }}>
              <Button onClick={() => setIsMwoModalOpen(false)} variant="secondary">Cancel</Button>
              <Button
                disabled={createMwoMutation.isPending || !mwoTitle.trim()}
                onClick={() => createMwoMutation.mutate()}
                variant="primary"
              >
                Log Maintenance Order
              </Button>
            </div>
          </div>
        </div>
      )}
    </section>
  )
}