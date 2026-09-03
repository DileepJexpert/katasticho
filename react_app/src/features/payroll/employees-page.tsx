import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  ArrowLeft,
  ArrowRight,
  Briefcase,
  Building,
  FileText,
  Mail,
  Phone,
  Plus,
  Search,
  Users,
  X,
} from 'lucide-react'
import { Link } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import {
  createEmployee,
  listEmployees,
  type CreateEmployeeRequest,
} from '@/features/payroll/payroll-api'

const statusTabs = [
  { key: 'all', label: 'All employees' },
  { key: 'ACTIVE', label: 'Active' },
  { key: 'ON_NOTICE', label: 'On Notice' },
  { key: 'RESIGNED', label: 'Resigned' },
  { key: 'TERMINATED', label: 'Terminated' },
] as const

type StatusTab = (typeof statusTabs)[number]['key']

export function EmployeesPage() {
  const [activeTab, setActiveTab] = useState<StatusTab>('all')
  const [search, setSearch] = useState('')
  const [deptFilter, setDeptFilter] = useState('all')
  const [page, setPage] = useState(0)
  const [isAddOpen, setIsAddOpen] = useState(false)

  const queryClient = useQueryClient()

  const query = useQuery({
    queryKey: ['payroll-employees', page],
    queryFn: () => listEmployees(page),
  })

  const createMutation = useMutation({
    mutationFn: (req: CreateEmployeeRequest) => createEmployee(req),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['payroll-employees'] })
      setIsAddOpen(false)
    },
  })

  const pageData = query.data
  const rawList = pageData?.content ?? []

  const departments = Array.from(
    new Set(rawList.map((e) => e.department).filter(Boolean) as string[])
  )

  const filtered = rawList.filter((emp) => {
    if (activeTab !== 'all' && emp.status !== activeTab) return false
    if (deptFilter !== 'all' && emp.department !== deptFilter) return false
    if (!search.trim()) return true
    const q = search.toLowerCase()
    const matchCode = emp.employeeCode ? emp.employeeCode.toLowerCase().includes(q) : false
    const matchName = emp.fullName.toLowerCase().includes(q)
    const matchDesig = emp.designation ? emp.designation.toLowerCase().includes(q) : false
    const matchDept = emp.department ? emp.department.toLowerCase().includes(q) : false
    const matchEmail = emp.email ? emp.email.toLowerCase().includes(q) : false
    const matchPhone = emp.phone ? emp.phone.includes(q) : false
    return matchCode || matchName || matchDesig || matchDept || matchEmail || matchPhone
  })

  const activeCount = rawList.filter((e) => e.status === 'ACTIVE').length
  const onNoticeCount = rawList.filter((e) => e.status === 'ON_NOTICE').length
  const totalPages = pageData?.totalPages ?? 0

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="HR & Payroll"
        title="Employee Directory"
        description="Employee master registry, designation, statutory PF/ESI/PT IDs, bank disbursals, and 360 profiles."
        actions={
          <div className="table-actions">
            <Button onClick={() => setIsAddOpen(true)} variant="primary">
              <Plus aria-hidden="true" size={16} />
              Add Employee
            </Button>
          </div>
        }
      />

      <div className="summary-strip">
        <div className="summary-card">
          <span className="summary-card__label">Total Staff</span>
          <strong className="summary-card__value">{rawList.length}</strong>
          <span className="summary-card__hint">Registered in organization</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Active Workforce</span>
          <strong className="summary-card__value text-success">{activeCount}</strong>
          <span className="summary-card__hint">On active payroll</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">On Notice</span>
          <strong className="summary-card__value text-warning">{onNoticeCount}</strong>
          <span className="summary-card__hint">Transitioning / offboarding</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__label">Departments</span>
          <strong className="summary-card__value">{departments.length || 1}</strong>
          <span className="summary-card__hint">Functional divisions</span>
        </div>
      </div>

      <div className="list-toolbar">
        <label className="directory-search">
          <Search aria-hidden="true" size={18} />
          <span className="sr-only">Search employees</span>
          <input
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by code, name, designation, department, email, phone..."
            type="search"
            value={search}
          />
        </label>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          <select
            className="select-input"
            onChange={(e) => setDeptFilter(e.target.value)}
            value={deptFilter}
          >
            <option value="all">All Departments</option>
            {departments.map((d) => (
              <option key={d} value={d}>
                {d}
              </option>
            ))}
          </select>
        </div>
        <div aria-label="Filter employees by status" className="list-tabs" role="tablist">
          {statusTabs.map((tab) => (
            <button
              aria-selected={activeTab === tab.key}
              className={activeTab === tab.key ? 'list-tab list-tab--active' : 'list-tab'}
              key={tab.key}
              onClick={() => {
                setActiveTab(tab.key)
                setPage(0)
              }}
              role="tab"
              type="button"
            >
              {tab.label}
            </button>
          ))}
        </div>
      </div>

      {query.isLoading ? (
        <div aria-live="polite" className="directory-state">
          Loading employee records...
        </div>
      ) : query.isError ? (
        <div className="directory-state directory-state--error" role="alert">
          <FileText aria-hidden="true" size={24} />
          <strong>Unable to load employees.</strong>
          <p>Please verify your connection or organizational permissions.</p>
          <Button onClick={() => query.refetch()} variant="secondary">
            Retry
          </Button>
        </div>
      ) : filtered.length === 0 ? (
        <div className="directory-state">
          <Users aria-hidden="true" size={24} />
          <strong>No employees found.</strong>
          <p>Try clearing search or filters, or add a new team member.</p>
        </div>
      ) : (
        <DataTable caption="Employees directory with statutory and structural metadata">
          <thead>
            <tr>
              <th scope="col">Code</th>
              <th scope="col">Employee Name</th>
              <th scope="col">Designation & Department</th>
              <th scope="col">Contact Info</th>
              <th scope="col">Joining Date</th>
              <th scope="col">Statutory IDs</th>
              <th scope="col">Status</th>
              <th scope="col">Actions</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((emp) => (
              <tr key={emp.id}>
                <td>
                  <Link
                    className="table-code"
                    to={appRoutes.employeeDetail(emp.id)}
                  >
                    {emp.employeeCode || `EMP-${emp.id.slice(0, 6).toUpperCase()}`}
                  </Link>
                </td>
                <td>
                  <div>
                    <strong>{emp.fullName}</strong>
                    {emp.employmentType ? (
                      <span className="cell-muted" style={{ display: 'block', fontSize: '0.8rem' }}>
                        {emp.employmentType}
                      </span>
                    ) : null}
                  </div>
                </td>
                <td>
                  <div>
                    <span>{emp.designation || 'Staff'}</span>
                    <span className="cell-muted" style={{ display: 'block', fontSize: '0.8rem' }}>
                      {emp.department || 'Operations'}
                    </span>
                  </div>
                </td>
                <td>
                  <div style={{ fontSize: '0.85rem' }}>
                    {emp.email ? (
                      <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                        <Mail aria-hidden="true" size={12} /> {emp.email}
                      </div>
                    ) : null}
                    {emp.phone ? (
                      <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                        <Phone aria-hidden="true" size={12} /> {emp.phone}
                      </div>
                    ) : null}
                    {!emp.email && !emp.phone ? <span className="cell-muted">â€”</span> : null}
                  </div>
                </td>
                <td>{emp.dateOfJoining ? formatDate(emp.dateOfJoining) : 'â€”'}</td>
                <td>
                  <div style={{ fontSize: '0.8rem', display: 'flex', flexDirection: 'column', gap: 2 }}>
                    {emp.panNumber || emp.pan ? (
                      <span>PAN: <code className="table-code">{emp.panNumber || emp.pan}</code></span>
                    ) : null}
                    {emp.uanNumber || emp.uan ? (
                      <span>UAN: <code className="table-code">{emp.uanNumber || emp.uan}</code></span>
                    ) : null}
                    {emp.esiNumber ? (
                      <span>ESI: <code className="table-code">{emp.esiNumber}</code></span>
                    ) : null}
                    {!emp.pan && !emp.panNumber && !emp.uan && !emp.uanNumber && !emp.esiNumber ? (
                      <span className="cell-muted">Unlinked</span>
                    ) : null}
                  </div>
                </td>
                <td>
                  <StatusChip status={formatStatusLabel(emp.status || 'ACTIVE')} />
                </td>
                <td>
                  <Link
                    className="table-row-action"
                    to={appRoutes.employeeDetail(emp.id)}
                  >
                    View 360
                  </Link>
                </td>
              </tr>
            ))}
          </tbody>
        </DataTable>
      )}

      {totalPages > 1 ? (
        <div className="pagination-bar">
          <Button
            disabled={page === 0}
            onClick={() => setPage((p) => Math.max(0, p - 1))}
            variant="secondary"
          >
            <ArrowLeft aria-hidden="true" size={16} />
            Previous
          </Button>
          <span className="pagination-info">
            Page {page + 1} of {totalPages}
          </span>
          <Button
            disabled={page >= totalPages - 1}
            onClick={() => setPage((p) => p + 1)}
            variant="secondary"
          >
            Next
            <ArrowRight aria-hidden="true" size={16} />
          </Button>
        </div>
      ) : null}

      {/* Add Employee Modal */}
      {isAddOpen ? (
        <div className="modal-backdrop" role="presentation">
          <div aria-labelledby="add-emp-title" aria-modal="true" className="modal-dialog modal-dialog--lg" role="dialog">
            <div className="modal-header">
              <div>
                <h2 id="add-emp-title">Add New Employee</h2>
                <p className="cell-muted">Record employee master profile, identity, and statutory compliance parameters.</p>
              </div>
              <button
                aria-label="Close dialog"
                className="icon-button"
                onClick={() => setIsAddOpen(false)}
                type="button"
              >
                <X aria-hidden="true" size={18} />
              </button>
            </div>
            <form
              onSubmit={(e) => {
                e.preventDefault()
                const form = e.currentTarget
                const fd = new FormData(form)

                createMutation.mutate({
                  fullName: String(fd.get('fullName') ?? '').trim(),
                  employeeCode: String(fd.get('employeeCode') ?? '').trim() || undefined,
                  designation: String(fd.get('designation') ?? '').trim() || undefined,
                  department: String(fd.get('department') ?? '').trim() || undefined,
                  email: String(fd.get('email') ?? '').trim() || undefined,
                  phone: String(fd.get('phone') ?? '').trim() || undefined,
                  dateOfJoining: String(fd.get('dateOfJoining') ?? '') || undefined,
                  employmentType: String(fd.get('employmentType') ?? '') || 'FULL_TIME',
                  workLocation: String(fd.get('workLocation') ?? '').trim() || undefined,
                  pan: String(fd.get('pan') ?? '').trim() || undefined,
                  aadhaarLast4: String(fd.get('aadhaarLast4') ?? '').trim() || undefined,
                  uan: String(fd.get('uan') ?? '').trim() || undefined,
                  esiNumber: String(fd.get('esiNumber') ?? '').trim() || undefined,
                  isPfApplicable: fd.get('isPfApplicable') === 'on',
                  isEsiApplicable: fd.get('isEsiApplicable') === 'on',
                  isPtApplicable: fd.get('isPtApplicable') === 'on',
                  isLwfApplicable: fd.get('isLwfApplicable') === 'on',
                  bankAccountName: String(fd.get('bankAccountName') ?? '').trim() || undefined,
                  bankAccountNumber: String(fd.get('bankAccountNumber') ?? '').trim() || undefined,
                  bankIfsc: String(fd.get('bankIfsc') ?? '').trim() || undefined,
                  paymentMode: String(fd.get('paymentMode') ?? '') || 'BANK_TRANSFER',
                  emergencyContactName: String(fd.get('emergencyContactName') ?? '').trim() || undefined,
                  emergencyContactPhone: String(fd.get('emergencyContactPhone') ?? '').trim() || undefined,
                })
              }}
            >
              <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                <fieldset style={{ border: '1px solid var(--k-color-border-subtle)', borderRadius: 6, padding: 12 }}>
                  <legend style={{ fontWeight: 600, padding: '0 6px', fontSize: '0.9rem' }}>
                    <Briefcase aria-hidden="true" size={14} style={{ display: 'inline', marginRight: 4 }} />
                    Primary Profile & Employment
                  </legend>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 12 }}>
                    <div>
                      <label className="form-label" htmlFor="fullName">Full Name *</label>
                      <input className="text-input" id="fullName" name="fullName" required type="text" />
                    </div>
                    <div>
                      <label className="form-label" htmlFor="employeeCode">Employee Code</label>
                      <input className="text-input" id="employeeCode" name="employeeCode" placeholder="e.g. EMP-0104" type="text" />
                    </div>
                    <div>
                      <label className="form-label" htmlFor="designation">Designation</label>
                      <input className="text-input" id="designation" name="designation" placeholder="e.g. Senior Accountant" type="text" />
                    </div>
                    <div>
                      <label className="form-label" htmlFor="department">Department</label>
                      <input className="text-input" id="department" name="department" placeholder="e.g. Finance" type="text" />
                    </div>
                    <div>
                      <label className="form-label" htmlFor="email">Official Email</label>
                      <input className="text-input" id="email" name="email" placeholder="name@company.com" type="email" />
                    </div>
                    <div>
                      <label className="form-label" htmlFor="phone">Phone Number</label>
                      <input className="text-input" id="phone" name="phone" placeholder="+91 98765 43210" type="tel" />
                    </div>
                    <div>
                      <label className="form-label" htmlFor="dateOfJoining">Date of Joining</label>
                      <input className="text-input" defaultValue={new Date().toISOString().slice(0, 10)} id="dateOfJoining" name="dateOfJoining" type="date" />
                    </div>
                    <div>
                      <label className="form-label" htmlFor="employmentType">Employment Type</label>
                      <select className="select-input" defaultValue="FULL_TIME" id="employmentType" name="employmentType">
                        <option value="FULL_TIME">Full Time</option>
                        <option value="PART_TIME">Part Time</option>
                        <option value="CONTRACT">Contract</option>
                        <option value="INTERN">Intern</option>
                      </select>
                    </div>
                  </div>
                </fieldset>

                <fieldset style={{ border: '1px solid var(--k-color-border-subtle)', borderRadius: 6, padding: 12 }}>
                  <legend style={{ fontWeight: 600, padding: '0 6px', fontSize: '0.9rem' }}>
                    <Building aria-hidden="true" size={14} style={{ display: 'inline', marginRight: 4 }} />
                    Indian Statutory Compliance IDs
                  </legend>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 12 }}>
                    <div>
                      <label className="form-label" htmlFor="pan">PAN Number</label>
                      <input className="text-input" id="pan" maxLength={10} name="pan" placeholder="ABCDE1234F" style={{ textTransform: 'uppercase' }} type="text" />
                    </div>
                    <div>
                      <label className="form-label" htmlFor="aadhaarLast4">Aadhaar Last 4 Digits</label>
                      <input className="text-input" id="aadhaarLast4" maxLength={4} name="aadhaarLast4" placeholder="5678" type="text" />
                    </div>
                    <div>
                      <label className="form-label" htmlFor="uan">EPFO UAN (12 digits)</label>
                      <input className="text-input" id="uan" maxLength={12} name="uan" placeholder="100123456789" type="text" />
                    </div>
                    <div>
                      <label className="form-label" htmlFor="esiNumber">ESIC IP Number (17 digits)</label>
                      <input className="text-input" id="esiNumber" maxLength={17} name="esiNumber" placeholder="31000123450000001" type="text" />
                    </div>
                  </div>
                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: 16, marginTop: 12 }}>
                    <label style={{ display: 'inline-flex', alignItems: 'center', gap: 6, cursor: 'pointer' }}>
                      <input defaultChecked name="isPfApplicable" type="checkbox" />
                      <span>PF Applicable (12%)</span>
                    </label>
                    <label style={{ display: 'inline-flex', alignItems: 'center', gap: 6, cursor: 'pointer' }}>
                      <input defaultChecked name="isEsiApplicable" type="checkbox" />
                      <span>ESI Applicable (0.75%)</span>
                    </label>
                    <label style={{ display: 'inline-flex', alignItems: 'center', gap: 6, cursor: 'pointer' }}>
                      <input defaultChecked name="isPtApplicable" type="checkbox" />
                      <span>Professional Tax (PT)</span>
                    </label>
                    <label style={{ display: 'inline-flex', alignItems: 'center', gap: 6, cursor: 'pointer' }}>
                      <input defaultChecked name="isLwfApplicable" type="checkbox" />
                      <span>Labour Welfare Fund (LWF)</span>
                    </label>
                  </div>
                </fieldset>

                <fieldset style={{ border: '1px solid var(--k-color-border-subtle)', borderRadius: 6, padding: 12 }}>
                  <legend style={{ fontWeight: 600, padding: '0 6px', fontSize: '0.9rem' }}>
                    Bank Settlement & Disbursal
                  </legend>
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 12 }}>
                    <div>
                      <label className="form-label" htmlFor="bankAccountName">Beneficiary Name</label>
                      <input className="text-input" id="bankAccountName" name="bankAccountName" placeholder="As per bank record" type="text" />
                    </div>
                    <div>
                      <label className="form-label" htmlFor="bankAccountNumber">Bank Account Number</label>
                      <input className="text-input" id="bankAccountNumber" name="bankAccountNumber" placeholder="987654321000" type="text" />
                    </div>
                    <div>
                      <label className="form-label" htmlFor="bankIfsc">IFSC Code</label>
                      <input className="text-input" id="bankIfsc" maxLength={11} name="bankIfsc" placeholder="HDFC0001234" style={{ textTransform: 'uppercase' }} type="text" />
                    </div>
                    <div>
                      <label className="form-label" htmlFor="paymentMode">Disbursal Mode</label>
                      <select className="select-input" defaultValue="BANK_TRANSFER" id="paymentMode" name="paymentMode">
                        <option value="BANK_TRANSFER">Bank Transfer (NEFT/RTGS)</option>
                        <option value="CASH">Cash Counter</option>
                        <option value="CHEQUE">Bank Cheque</option>
                      </select>
                    </div>
                  </div>
                </fieldset>
              </div>

              <div className="modal-footer">
                <Button onClick={() => setIsAddOpen(false)} type="button" variant="secondary">
                  Cancel
                </Button>
                <Button disabled={createMutation.isPending} type="submit" variant="primary">
                  {createMutation.isPending ? 'Saving...' : 'Create Employee Profile'}
                </Button>
              </div>
            </form>
          </div>
        </div>
      ) : null}
    </section>
  )
}