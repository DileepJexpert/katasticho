import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  Calendar,
  CheckCircle2,
  Palmtree,
  Plus,
  Trash2,
} from 'lucide-react'
import {
  Button,
  CheckboxInput,
  DataTable,
  FormField,
  FormGrid,
  Modal,
  NumberInput,
  PageHeader,
  SelectInput,
  StatusChip,
  TextAreaInput,
  TextInput,
} from '@/design-system'
import { formatDate } from '@/shared/format/format'
import {
  addHoliday,
  applyLeave,
  deleteHoliday,
  listHolidays,
  listLeaveTypes,
  upsertLeaveType,
  type LeaveType,
} from '@/features/hr/hr-api'

const leaveTabs = [
  { key: 'apply', label: 'My Leaves & Apply' },
  { key: 'types', label: 'Leave Types & Quotas' },
  { key: 'holidays', label: 'Holiday Calendar' },
] as const

type LeaveTab = (typeof leaveTabs)[number]['key']

export function LeavesPage() {
  const [activeTab, setActiveTab] = useState<LeaveTab>('apply')
  const [isApplyOpen, setIsApplyOpen] = useState(false)
  const [isTypeOpen, setIsTypeOpen] = useState(false)
  const [isHolidayOpen, setIsHolidayOpen] = useState(false)
  const [year, setYear] = useState(new Date().getFullYear())

  const queryClient = useQueryClient()

  const typesQuery = useQuery({
    queryKey: ['hr-leave-types'],
    queryFn: () => listLeaveTypes(),
  })

  const holidaysQuery = useQuery({
    queryKey: ['hr-holidays', year],
    queryFn: () => listHolidays(year),
  })

  const applyMutation = useMutation({
    mutationFn: (req: { leaveTypeId: string; fromDate: string; toDate: string; reason?: string }) =>
      applyLeave(req),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['hr-leave-types'] })
      setIsApplyOpen(false)
      alert('Leave application submitted for supervisor approval.')
    },
  })

  const upsertTypeMutation = useMutation({
    mutationFn: (req: Partial<LeaveType>) => upsertLeaveType(req),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['hr-leave-types'] })
      setIsTypeOpen(false)
    },
  })

  const addHolidayMutation = useMutation({
    mutationFn: (req: { date: string; name: string; optional?: boolean }) =>
      addHoliday(req),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['hr-holidays', year] })
      setIsHolidayOpen(false)
    },
  })

  const deleteHolidayMutation = useMutation({
    mutationFn: (id: string) => deleteHoliday(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['hr-holidays', year] })
    },
  })

  const leaveTypes = typesQuery.data ?? []
  const holidays = holidaysQuery.data ?? []

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Core HR"
        title="Leave Management & Holidays"
        description="Annual leave policies, Casual Leave, Sick Leave, Earned Leave quotas, leave applications, and statutory holiday calendars."
        actions={
          <div className="table-actions">
            <Button onClick={() => setIsApplyOpen(true)} variant="primary">
              <Plus aria-hidden="true" size={16} />
              Apply Leave
            </Button>
          </div>
        }
      />

      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">Casual Leave (CL)</span>
          <strong className="summary-card__value text-success">8 / 12</strong>
          <span className="summary-card__hint">Available days</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Sick Leave (SL)</span>
          <strong className="summary-card__value text-primary">10 / 12</strong>
          <span className="summary-card__hint">Available days</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Earned Leave (EL)</span>
          <strong className="summary-card__value">15 / 18</strong>
          <span className="summary-card__hint">Carry-forward eligible</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Company Holidays</span>
          <strong className="summary-card__value">{holidays.length || 14}</strong>
          <span className="summary-card__hint">Official holidays in {year}</span>
        </div>
      </div>

      <div className="list-toolbar">
        <div aria-label="Leave tabs" className="list-tabs" role="tablist">
          {leaveTabs.map((tab) => (
            <button
              aria-selected={activeTab === tab.key}
              className={activeTab === tab.key ? 'list-tab list-tab--active' : 'list-tab'}
              key={tab.key}
              onClick={() => setActiveTab(tab.key)}
              role="tab"
              type="button"
            >
              {tab.label}
            </button>
          ))}
        </div>
      </div>

      {/* TAB 1: APPLY & BALANCES */}
      {activeTab === 'apply' ? (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div className="document-layout">
            <section className="document-card">
              <h2>
                <Palmtree aria-hidden="true" size={18} style={{ display: 'inline', marginRight: 6 }} />
                Leave Balances & Entitlements
              </h2>
              <dl className="document-facts">
                <Fact label="Casual Leave (CL)" value="8 Days Available (12 Annual Quota)" />
                <Fact label="Sick Leave (SL)" value="10 Days Available (12 Annual Quota)" />
                <Fact label="Earned Leave (EL / PL)" value="15 Days Available (18 Annual Quota)" />
                <Fact label="Maternity / Paternity Leave" value="As per Statutory Mandate" />
                <Fact label="Compensatory Off" value="2 Days Available" />
              </dl>
            </section>

            <section className="document-card">
              <h2>
                <CheckCircle2 aria-hidden="true" size={18} style={{ display: 'inline', marginRight: 6 }} />
                Leave Policy Rules
              </h2>
              <dl className="document-facts">
                <Fact label="Approval Chain" value="Reporting Manager -> HR Signoff" />
                <Fact label="Advance Notice" value="3 days for planned EL" />
                <Fact label="Encashment" value="Up to 30 days carry-forward" />
              </dl>
            </section>
          </div>
        </div>
      ) : null}

      {/* TAB 2: LEAVE TYPES CONFIG */}
      {activeTab === 'types' ? (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <h3>Organization Leave Policies & Quotas</h3>
              <p className="cell-muted">Configure paid quotas, accrual rules, and carry-forward limits.</p>
            </div>
            <Button onClick={() => setIsTypeOpen(true)} variant="primary">
              <Plus aria-hidden="true" size={16} />
              Add Leave Type
            </Button>
          </div>

          {leaveTypes.length === 0 ? (
            <div className="directory-state">
              <Palmtree aria-hidden="true" size={24} />
              <strong>No leave types configured.</strong>
              <p>Click "Add Leave Type" to set up CL, SL, and EL policies.</p>
            </div>
          ) : (
            <DataTable caption="Configured organization leave policies">
              <thead>
                <tr>
                  <th scope="col">Code</th>
                  <th scope="col">Leave Policy Name</th>
                  <th scope="col">Paid Type</th>
                  <th className="numeric-cell" scope="col">Annual Quota</th>
                  <th className="numeric-cell" scope="col">Carry Forward Max</th>
                  <th scope="col">Requires Approval</th>
                  <th scope="col">Status</th>
                </tr>
              </thead>
              <tbody>
                {leaveTypes.map((t) => (
                  <tr key={t.id}>
                    <td><code className="table-code">{t.code}</code></td>
                    <td><strong>{t.name}</strong></td>
                    <td><StatusChip status={t.paid ? 'Paid' : 'Unpaid'} /></td>
                    <td className="numeric-cell">{t.annualQuota} days</td>
                    <td className="numeric-cell">{t.carryForwardMax ? `${t.carryForwardMax} days` : 'None'}</td>
                    <td>{t.requiresApproval !== false ? 'Yes' : 'Auto-approved'}</td>
                    <td><StatusChip status={t.active ? 'Active' : 'Inactive'} /></td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          )}
        </div>
      ) : null}

      {/* TAB 3: HOLIDAYS */}
      {activeTab === 'holidays' ? (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <h3>Company Holiday Calendar</h3>
              <select
                className="select-input"
                onChange={(e) => setYear(Number(e.target.value))}
                value={year}
              >
                <option value={2026}>Year 2026</option>
                <option value={2025}>Year 2025</option>
              </select>
            </div>
            <Button onClick={() => setIsHolidayOpen(true)} variant="primary">
              <Plus aria-hidden="true" size={16} />
              Add Holiday
            </Button>
          </div>

          {holidays.length === 0 ? (
            <div className="directory-state">
              <Calendar aria-hidden="true" size={24} />
              <strong>No holidays recorded for {year}.</strong>
              <p>Add official national and regional holidays.</p>
            </div>
          ) : (
            <DataTable caption="Public and statutory company holidays">
              <thead>
                <tr>
                  <th scope="col">Holiday Date</th>
                  <th scope="col">Holiday Name</th>
                  <th scope="col">Category</th>
                  <th scope="col">Actions</th>
                </tr>
              </thead>
              <tbody>
                {holidays.map((h) => (
                  <tr key={h.id}>
                    <td><strong>{formatDate(h.date)}</strong></td>
                    <td>{h.name}</td>
                    <td><StatusChip status={h.optional ? 'Optional / Restricted' : 'Mandatory Holiday'} /></td>
                    <td>
                      <Button
                        disabled={deleteHolidayMutation.isPending}
                        onClick={() => deleteHolidayMutation.mutate(h.id)}
                        variant="ghost"
                      >
                        <Trash2 aria-hidden="true" size={14} />
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          )}
        </div>
      ) : null}

      {/* Apply Leave Modal */}
      {isApplyOpen && (
        <Modal
          description="Submit time off application for supervisor review."
          footer={
            <>
              <Button onClick={() => setIsApplyOpen(false)} type="button" variant="secondary">Cancel</Button>
              <Button form="apply-leave-form" disabled={applyMutation.isPending} type="submit" variant="primary">
                {applyMutation.isPending ? 'Submitting...' : 'Submit Application'}
              </Button>
            </>
          }
          isOpen={isApplyOpen}
          onClose={() => setIsApplyOpen(false)}
          size="md"
          title="Apply for Leave"
        >
          <form
            id="apply-leave-form"
            onSubmit={(e) => {
              e.preventDefault()
              const fd = new FormData(e.currentTarget)
              applyMutation.mutate({
                leaveTypeId: String(fd.get('leaveTypeId') ?? ''),
                fromDate: String(fd.get('fromDate') ?? ''),
                toDate: String(fd.get('toDate') ?? ''),
                reason: String(fd.get('reason') ?? '').trim() || undefined,
              })
            }}
            style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}
          >
            <FormField label="Leave Policy Type" required>
              <SelectInput name="leaveTypeId" required>
                {leaveTypes.map((t) => (
                  <option key={t.id} value={t.id}>
                    {t.name} ({t.paid ? 'Paid' : 'Unpaid'})
                  </option>
                ))}
              </SelectInput>
            </FormField>
            <FormGrid columns={2}>
              <FormField label="From Date" required>
                <TextInput defaultValue={new Date().toISOString().slice(0, 10)} name="fromDate" required type="date" />
              </FormField>
              <FormField label="To Date" required>
                <TextInput defaultValue={new Date().toISOString().slice(0, 10)} name="toDate" required type="date" />
              </FormField>
            </FormGrid>
            <FormField label="Reason for Absence">
              <TextAreaInput name="reason" placeholder="Brief reason for time off..." rows={3} />
            </FormField>
          </form>
        </Modal>
      )}

      {/* Add Leave Type Modal */}
      {isTypeOpen && (
        <Modal
          description="Configure annual leave quotas and carry forward policy."
          footer={
            <>
              <Button onClick={() => setIsTypeOpen(false)} type="button" variant="secondary">Cancel</Button>
              <Button form="type-form" disabled={upsertTypeMutation.isPending} type="submit" variant="primary">
                {upsertTypeMutation.isPending ? 'Saving...' : 'Save Policy'}
              </Button>
            </>
          }
          isOpen={isTypeOpen}
          onClose={() => setIsTypeOpen(false)}
          size="md"
          title="Add Leave Policy Type"
        >
          <form
            id="type-form"
            onSubmit={(e) => {
              e.preventDefault()
              const fd = new FormData(e.currentTarget)
              upsertTypeMutation.mutate({
                code: String(fd.get('code') ?? '').trim().toUpperCase(),
                name: String(fd.get('name') ?? '').trim(),
                paid: fd.get('paid') === 'on',
                annualQuota: Number(fd.get('annualQuota') ?? 12),
                carryForwardMax: Number(fd.get('carryForwardMax') ?? 0),
                requiresApproval: fd.get('requiresApproval') === 'on',
                active: true,
              })
            }}
            style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}
          >
            <FormField label="Policy Code" required>
              <TextInput name="code" placeholder="e.g. CL / SL / EL" required style={{ textTransform: 'uppercase' }} type="text" />
            </FormField>
            <FormField label="Policy Name" required>
              <TextInput name="name" placeholder="e.g. Casual Leave" required type="text" />
            </FormField>
            <FormGrid columns={2}>
              <FormField label="Annual Quota (Days)">
                <NumberInput defaultValue={12} name="annualQuota" />
              </FormField>
              <FormField label="Carry Forward Max">
                <NumberInput defaultValue={0} name="carryForwardMax" />
              </FormField>
            </FormGrid>
            <FormGrid columns={2}>
              <CheckboxInput defaultChecked label="Paid Leave" name="paid" />
              <CheckboxInput defaultChecked label="Requires Supervisor Approval" name="requiresApproval" />
            </FormGrid>
          </form>
        </Modal>
      )}

      {/* Add Holiday Modal */}
      {isHolidayOpen && (
        <Modal
          description="Add statutory or optional festival holiday to the annual corporate calendar."
          footer={
            <>
              <Button onClick={() => setIsHolidayOpen(false)} type="button" variant="secondary">Cancel</Button>
              <Button form="hol-form" disabled={addHolidayMutation.isPending} type="submit" variant="primary">
                {addHolidayMutation.isPending ? 'Saving...' : 'Save Holiday'}
              </Button>
            </>
          }
          isOpen={isHolidayOpen}
          onClose={() => setIsHolidayOpen(false)}
          size="md"
          title="Add Public Holiday"
        >
          <form
            id="hol-form"
            onSubmit={(e) => {
              e.preventDefault()
              const fd = new FormData(e.currentTarget)
              addHolidayMutation.mutate({
                date: String(fd.get('date') ?? ''),
                name: String(fd.get('name') ?? '').trim(),
                optional: fd.get('optional') === 'on',
              })
            }}
            style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}
          >
            <FormField label="Holiday Date" required>
              <TextInput name="date" required type="date" />
            </FormField>
            <FormField label="Holiday Name" required>
              <TextInput name="name" placeholder="e.g. Independence Day / Diwali" required type="text" />
            </FormField>
            <CheckboxInput label="Optional / Restricted Holiday" name="optional" />
          </form>
        </Modal>
      )}
    </section>
  )
}

function Fact({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div>
      <dt className="document-fact-label">{label}</dt>
      <dd className="document-fact-value">{value}</dd>
    </div>
  )
}
