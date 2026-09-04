import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  ArrowLeft,
  Banknote,
  Briefcase,
  Building,
  CheckCircle2,
  FileCheck,
  FileText,
  GraduationCap,
  Heart,
  History,
  Plus,
  Trash2,
  User,
  X,
} from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { DataTable } from '@/design-system/data-table'
import { Money } from '@/design-system/money'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import { formatDate, formatStatusLabel } from '@/shared/format/format'
import {
  getEmployee,
  getEmployeeSalaryStructure,
  getTaxDeclaration,
  listSalaryComponents,
  previewLaborPay,
  saveEmployeeSalaryStructure,
  saveTaxDeclaration,
  submitTaxDeclaration,
  verifyTaxDeclaration,
  type EmployeeTaxDeclaration,
  type SaveSalaryStructureRequest,
} from '@/features/payroll/payroll-api'
import {
  addEducation,
  addExperience,
  addFamily,
  deleteEducation,
  deleteExperience,
  deleteFamily,
  listDocuments,
  listEducation,
  listExperience,
  listFamily,
} from '@/features/hr/hr-api'

const detailTabs = [
  { key: 'overview', label: 'Overview & Profile', icon: User },
  { key: 'salary', label: 'Salary Structure', icon: Banknote },
  { key: 'tax', label: 'Tax Declaration (12BB)', icon: FileCheck },
  { key: 'family', label: 'Family & Dependents', icon: Heart },
  { key: 'education', label: 'Education', icon: GraduationCap },
  { key: 'experience', label: 'Prior Experience', icon: Briefcase },
  { key: 'documents', label: 'Documents', icon: FileText },
] as const

type DetailTab = (typeof detailTabs)[number]['key']

export function EmployeeDetailPage() {
  const { employeeId } = useParams<{ employeeId: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const [activeTab, setActiveTab] = useState<DetailTab>('overview')
  const [isSalaryModalOpen, setIsSalaryModalOpen] = useState(false)
  const [isLaborPreviewOpen, setIsLaborPreviewOpen] = useState(false)
  const [isTaxModalOpen, setIsTaxModalOpen] = useState(false)
  const [isFamilyModalOpen, setIsFamilyModalOpen] = useState(false)
  const [isEduModalOpen, setIsEduModalOpen] = useState(false)
  const [isExpModalOpen, setIsExpModalOpen] = useState(false)

  const [taxFy, setTaxFy] = useState('2026-2027')
  const [laborStart, setLaborStart] = useState('2026-08-01')
  const [laborEnd, setLaborEnd] = useState('2026-08-31')

  const empQuery = useQuery({
    queryKey: ['payroll-employees', employeeId],
    queryFn: () => getEmployee(employeeId!),
    enabled: Boolean(employeeId),
  })

  const structureQuery = useQuery({
    queryKey: ['payroll-employees', employeeId, 'structure'],
    queryFn: () => getEmployeeSalaryStructure(employeeId!),
    enabled: Boolean(employeeId),
  })

  const componentsQuery = useQuery({
    queryKey: ['payroll-salary-components'],
    queryFn: () => listSalaryComponents(),
  })

  const taxQuery = useQuery({
    queryKey: ['payroll-tax-declaration', employeeId, taxFy],
    queryFn: () => getTaxDeclaration(employeeId!, taxFy),
    enabled: Boolean(employeeId),
  })

  const familyQuery = useQuery({
    queryKey: ['hr-family', employeeId],
    queryFn: () => listFamily(employeeId!),
    enabled: Boolean(employeeId),
  })

  const educationQuery = useQuery({
    queryKey: ['hr-education', employeeId],
    queryFn: () => listEducation(employeeId!),
    enabled: Boolean(employeeId),
  })

  const experienceQuery = useQuery({
    queryKey: ['hr-experience', employeeId],
    queryFn: () => listExperience(employeeId!),
    enabled: Boolean(employeeId),
  })

  const documentsQuery = useQuery({
    queryKey: ['hr-documents', employeeId],
    queryFn: () => listDocuments(employeeId!),
    enabled: Boolean(employeeId),
  })

  const laborPayQuery = useQuery({
    queryKey: ['payroll-labor-preview', employeeId, laborStart, laborEnd],
    queryFn: () => previewLaborPay(employeeId!, laborStart, laborEnd),
    enabled: Boolean(employeeId) && isLaborPreviewOpen,
  })

  // Mutations
  const saveStructureMutation = useMutation({
    mutationFn: (req: SaveSalaryStructureRequest) =>
      saveEmployeeSalaryStructure(employeeId!, req),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['payroll-employees', employeeId, 'structure'] })
      setIsSalaryModalOpen(false)
    },
  })

  const saveTaxMutation = useMutation({
    mutationFn: (data: Partial<EmployeeTaxDeclaration>) =>
      saveTaxDeclaration(employeeId!, taxFy, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['payroll-tax-declaration', employeeId, taxFy] })
      setIsTaxModalOpen(false)
    },
  })

  const submitTaxMutation = useMutation({
    mutationFn: (id: string) => submitTaxDeclaration(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['payroll-tax-declaration', employeeId, taxFy] })
    },
  })

  const verifyTaxMutation = useMutation({
    mutationFn: ({ id, status, remarks }: { id: string; status: 'VERIFIED' | 'REJECTED'; remarks?: string }) =>
      verifyTaxDeclaration(id, status, remarks),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['payroll-tax-declaration', employeeId, taxFy] })
    },
  })

  const addFamilyMutation = useMutation({
    mutationFn: (data: { name: string; relationship: string; dependent?: boolean }) =>
      addFamily(employeeId!, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['hr-family', employeeId] })
      setIsFamilyModalOpen(false)
    },
  })

  const deleteFamilyMutation = useMutation({
    mutationFn: (id: string) => deleteFamily(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['hr-family', employeeId] })
    },
  })

  const addEduMutation = useMutation({
    mutationFn: (data: { degree: string; institution: string; passingYear?: number; scorePercentage?: string }) =>
      addEducation(employeeId!, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['hr-education', employeeId] })
      setIsEduModalOpen(false)
    },
  })

  const deleteEduMutation = useMutation({
    mutationFn: (id: string) => deleteEducation(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['hr-education', employeeId] })
    },
  })

  const addExpMutation = useMutation({
    mutationFn: (data: { companyName: string; designation: string; fromDate?: string; toDate?: string; lastSalary?: number }) =>
      addExperience(employeeId!, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['hr-experience', employeeId] })
      setIsExpModalOpen(false)
    },
  })

  const deleteExpMutation = useMutation({
    mutationFn: (id: string) => deleteExperience(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['hr-experience', employeeId] })
    },
  })

  if (!employeeId) return <DocumentError onBack={() => navigate(appRoutes.employees)} />
  if (empQuery.isLoading) {
    return (
      <section className="workspace-page">
        <div aria-live="polite" className="directory-state">Loading employee profile...</div>
      </section>
    )
  }
  if (empQuery.isError || !empQuery.data) {
    return <DocumentError onBack={() => navigate(appRoutes.employees)} />
  }

  const employee = empQuery.data
  const structure = structureQuery.data
  const structureLines = structure?.lines ?? []
  const taxDecl = taxQuery.data
  const familyList = familyQuery.data ?? []
  const educationList = educationQuery.data ?? []
  const experienceList = experienceQuery.data ?? []
  const documentsList = documentsQuery.data ?? []
  const allComponents = componentsQuery.data ?? []

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="HR & Payroll / Staff Record"
        title={employee.fullName}
        description={`${employee.designation || 'Staff'} · ${employee.department || 'Operations'} · Joining: ${employee.dateOfJoining ? formatDate(employee.dateOfJoining) : 'â€”'}`}
        actions={
          <div className="table-actions">
            <span className="status-badge">
              Code: {employee.employeeCode || `EMP-${employee.id.slice(0, 6).toUpperCase()}`}
            </span>
            <StatusChip status={formatStatusLabel(employee.status || 'ACTIVE')} />
          </div>
        }
      />

      <div className="document-actions">
        <Button onClick={() => navigate(appRoutes.employees)} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to Directory
        </Button>
      </div>

      {/* Profile Navigation Tabs */}
      <div className="list-toolbar">
        <div aria-label="Employee tabs" className="list-tabs" role="tablist">
          {detailTabs.map((tab) => {
            const Icon = tab.icon
            const isActive = activeTab === tab.key
            return (
              <button
                aria-selected={isActive}
                className={isActive ? 'list-tab list-tab--active' : 'list-tab'}
                key={tab.key}
                onClick={() => setActiveTab(tab.key)}
                role="tab"
                type="button"
              >
                <Icon aria-hidden="true" size={14} style={{ display: 'inline', marginRight: 6 }} />
                {tab.label}
              </button>
            )
          })}
        </div>
      </div>

      {/* TAB 1: OVERVIEW */}
      {activeTab === 'overview' ? (
        <div className="document-layout">
          <section className="document-card">
            <h2>
              <User aria-hidden="true" size={18} style={{ display: 'inline', marginRight: 6 }} />
              Employment & contact facts
            </h2>
            <dl className="document-facts">
              <Fact label="Full name" value={employee.fullName} />
              <Fact label="Employee code" value={employee.employeeCode || 'Unassigned'} />
              <Fact label="Designation" value={employee.designation || 'Staff'} />
              <Fact label="Department" value={employee.department || 'Operations'} />
              <Fact label="Employment type" value={employee.employmentType || 'Full Time'} />
              <Fact label="Work location" value={employee.workLocation || 'Headquarters'} />
              <Fact label="Date of joining" value={employee.dateOfJoining ? formatDate(employee.dateOfJoining) : 'â€”'} />
              <Fact label="Probation end date" value={employee.probationEndDate ? formatDate(employee.probationEndDate) : 'Confirmed'} />
              <Fact label="Official email" value={employee.email || 'â€”'} />
              <Fact label="Phone contact" value={employee.phone || 'â€”'} />
              <Fact label="Notice period" value={employee.noticePeriodDays ? `${employee.noticePeriodDays} days` : '30 days standard'} />
              <Fact label="Biometric punch PIN" value={employee.biometricPin || 'Unlinked'} />
            </dl>
          </section>

          <section className="document-card">
            <h2>
              <Building aria-hidden="true" size={18} style={{ display: 'inline', marginRight: 6 }} />
              Indian Statutory & Bank Details
            </h2>
            <dl className="document-facts">
              <Fact label="PAN number" value={employee.pan || employee.panNumber || 'â€”'} />
              <Fact label="Aadhaar (last 4)" value={employee.aadhaarLast4 ? `XXXX-XXXX-${employee.aadhaarLast4}` : 'â€”'} />
              <Fact label="EPFO UAN" value={employee.uan || employee.uanNumber || 'â€”'} />
              <Fact label="ESIC IP number" value={employee.esiNumber || 'â€”'} />
              <Fact
                label="Statutory coverage"
                value={
                  <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                    <StatusChip status={employee.isPfApplicable !== false ? 'PF Covered (12%)' : 'PF Exempt'} />
                    <StatusChip status={employee.isEsiApplicable !== false ? 'ESI Covered' : 'ESI Exempt'} />
                    <StatusChip status={employee.isPtApplicable !== false ? 'PT Applicable' : 'PT Exempt'} />
                  </div>
                }
              />
              <Fact label="Beneficiary name" value={employee.bankAccountName || employee.fullName} />
              <Fact label="Bank account" value={employee.bankAccountNumber || 'â€”'} />
              <Fact label="Bank IFSC" value={employee.bankIfsc || employee.bankIfscCode || 'â€”'} />
              <Fact label="Disbursal mode" value={employee.paymentMode || 'BANK_TRANSFER'} />
            </dl>
          </section>
        </div>
      ) : null}

      {/* TAB 2: SALARY STRUCTURE */}
      {activeTab === 'salary' ? (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <h3>Monthly Salary Composition & CTC</h3>
              <p className="cell-muted">Gross monthly earnings, employee statutory deductions, and employer contributions.</p>
            </div>
            <div className="table-actions">
              <Button onClick={() => setIsLaborPreviewOpen(true)} variant="secondary">
                <History aria-hidden="true" size={16} />
                Labor Pay Preview
              </Button>
              <Button onClick={() => setIsSalaryModalOpen(true)} variant="primary">
                <Plus aria-hidden="true" size={16} />
                Configure Salary Structure
              </Button>
            </div>
          </div>

          <div className="summary-strip">
            <div className="summary-card">
              <span className="summary-card__label">Monthly CTC</span>
              <strong className="summary-card__value">
                <Money amount={structure?.ctcMonthly ?? 0} />
              </strong>
              <span className="summary-card__hint">Cost to company</span>
            </div>
            <div className="summary-card">
              <span className="summary-card__label">Gross Monthly Pay</span>
              <strong className="summary-card__value text-success">
                <Money amount={structure?.grossMonthly ?? 0} />
              </strong>
              <span className="summary-card__hint">Pre-deduction earnings</span>
            </div>
            <div className="summary-card">
              <span className="summary-card__label">Pay Model</span>
              <strong className="summary-card__value">{structure?.payType || 'SALARY'}</strong>
              <span className="summary-card__hint">Compensation type</span>
            </div>
            <div className="summary-card">
              <span className="summary-card__label">Effective From</span>
              <strong className="summary-card__value">
                {structure?.effectiveFrom ? formatDate(structure.effectiveFrom) : 'Not configured'}
              </strong>
              <span className="summary-card__hint">Active structure revision</span>
            </div>
          </div>

          {structureLines.length === 0 ? (
            <div className="directory-state">
              <Banknote aria-hidden="true" size={24} />
              <strong>No salary structure lines configured.</strong>
              <p>Click "Configure Salary Structure" to assign Basic, HRA, PF, and statutory components.</p>
            </div>
          ) : (
            <DataTable caption="Salary components and monthly amounts">
              <thead>
                <tr>
                  <th scope="col">Component</th>
                  <th scope="col">Type</th>
                  <th scope="col">Statutory Rule</th>
                  <th className="numeric-cell" scope="col">Monthly Amount</th>
                  <th className="numeric-cell" scope="col">Annualized Amount</th>
                </tr>
              </thead>
              <tbody>
                {structureLines.map((line, idx) => {
                  const monthly = Number(line.monthlyAmount || 0)
                  return (
                    <tr key={line.id || idx}>
                      <td>
                        <strong>{line.componentName || line.componentCode || 'Component'}</strong>
                        {line.componentCode ? (
                          <span className="cell-muted" style={{ display: 'block', fontSize: '0.8rem' }}>
                            {line.componentCode}
                          </span>
                        ) : null}
                      </td>
                      <td>
                        <StatusChip
                          status={
                            line.componentType === 'EARNING'
                              ? 'Earning'
                              : line.componentType === 'DEDUCTION'
                                ? 'Deduction'
                                : 'Employer Contrib.'
                          }
                        />
                      </td>
                      <td>{line.statutory ? 'Statutory Mandate' : 'Custom'}</td>
                      <td className="numeric-cell">
                        <strong><Money amount={monthly} /></strong>
                      </td>
                      <td className="numeric-cell">
                        <Money amount={monthly * 12} />
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </DataTable>
          )}
        </div>
      ) : null}

      {/* TAB 3: TAX DECLARATION (12BB) */}
      {activeTab === 'tax' ? (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 12 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <h3>Income Tax Declaration (Form 12BB)</h3>
              <select
                className="select-input"
                onChange={(e) => setTaxFy(e.target.value)}
                value={taxFy}
              >
                <option value="2026-2027">FY 2026-2027</option>
                <option value="2025-2026">FY 2025-2026</option>
                <option value="2024-2025">FY 2024-2025</option>
              </select>
            </div>
            <div className="table-actions">
              {taxDecl?.status === 'DRAFT' || !taxDecl ? (
                <Button onClick={() => setIsTaxModalOpen(true)} variant="primary">
                  <Plus aria-hidden="true" size={16} />
                  {taxDecl ? 'Edit Declaration' : 'Declare Investments'}
                </Button>
              ) : null}
              {taxDecl && taxDecl.status === 'DRAFT' ? (
                <Button
                  disabled={submitTaxMutation.isPending}
                  onClick={() => submitTaxMutation.mutate(taxDecl.id)}
                  variant="secondary"
                >
                  <CheckCircle2 aria-hidden="true" size={16} />
                  Submit for Verification
                </Button>
              ) : null}
              {taxDecl && taxDecl.status === 'SUBMITTED' ? (
                <div style={{ display: 'flex', gap: 8 }}>
                  <Button
                    disabled={verifyTaxMutation.isPending}
                    onClick={() => verifyTaxMutation.mutate({ id: taxDecl.id, status: 'VERIFIED' })}
                    variant="primary"
                  >
                    Verify & Approve
                  </Button>
                  <Button
                    disabled={verifyTaxMutation.isPending}
                    onClick={() => verifyTaxMutation.mutate({ id: taxDecl.id, status: 'REJECTED', remarks: 'Proof incomplete' })}
                    variant="destructive"
                  >
                    Reject
                  </Button>
                </div>
              ) : null}
            </div>
          </div>

          <div className="summary-strip">
            <div className="summary-card">
              <span className="summary-card__label">Selected Regime</span>
              <strong className="summary-card__value">{taxDecl?.regime || 'NEW'}</strong>
              <span className="summary-card__hint">Tax calculation model</span>
            </div>
            <div className="summary-card">
              <span className="summary-card__label">Section 80C</span>
              <strong className="summary-card__value">
                <Money amount={taxDecl?.section80cTotal ?? 0} />
              </strong>
              <span className="summary-card__hint">PF, PPF, ELSS, LIC (Cap ₹1.5L)</span>
            </div>
            <div className="summary-card">
              <span className="summary-card__label">Section 80D</span>
              <strong className="summary-card__value">
                <Money amount={taxDecl?.section80dMediclaim ?? 0} />
              </strong>
              <span className="summary-card__hint">Health insurance</span>
            </div>
            <div className="summary-card">
              <span className="summary-card__label">Verification Status</span>
              <strong className="summary-card__value">
                <StatusChip status={taxDecl?.status || 'NOT_SUBMITTED'} />
              </strong>
              <span className="summary-card__hint">{taxDecl?.remarks || 'Form 12BB'}</span>
            </div>
          </div>

          <section className="document-card">
            <h2>Deductions & Exemptions Breakdown</h2>
            <dl className="document-facts">
              <Fact label="Tax Regime" value={taxDecl?.regime || 'NEW'} />
              <Fact label="Section 80C Total" value={<Money amount={taxDecl?.section80cTotal ?? 0} />} />
              <Fact label="Section 80D Mediclaim" value={<Money amount={taxDecl?.section80dMediclaim ?? 0} />} />
              <Fact label="HRA Annual Rent Paid" value={<Money amount={taxDecl?.hraRentPaidAnnual ?? 0} />} />
              <Fact label="Home Loan Interest (Sec 24/80EE)" value={<Money amount={taxDecl?.homeLoanInterest80ee ?? 0} />} />
              <Fact label="Other Deductions" value={<Money amount={taxDecl?.otherDeductions ?? 0} />} />
              <Fact label="Verification Remarks" value={taxDecl?.remarks || 'No remarks recorded'} />
            </dl>
          </section>
        </div>
      ) : null}

      {/* TAB 4: FAMILY & DEPENDENTS */}
      {activeTab === 'family' ? (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <h3>Family Members & Nominees</h3>
              <p className="cell-muted">Registered dependents for statutory insurance and PF nomination.</p>
            </div>
            <Button onClick={() => setIsFamilyModalOpen(true)} variant="primary">
              <Plus aria-hidden="true" size={16} />
              Add Family Member
            </Button>
          </div>

          {familyList.length === 0 ? (
            <div className="directory-state">
              <Heart aria-hidden="true" size={24} />
              <strong>No family members recorded.</strong>
              <p>Add spouse, children, or parents for insurance benefits.</p>
            </div>
          ) : (
            <DataTable caption="Registered family members and dependents">
              <thead>
                <tr>
                  <th scope="col">Name</th>
                  <th scope="col">Relationship</th>
                  <th scope="col">Date of Birth</th>
                  <th scope="col">Dependent Status</th>
                  <th scope="col">Actions</th>
                </tr>
              </thead>
              <tbody>
                {familyList.map((f) => (
                  <tr key={f.id}>
                    <td><strong>{f.name}</strong></td>
                    <td>{f.relationship}</td>
                    <td>{f.dateOfBirth ? formatDate(f.dateOfBirth) : 'â€”'}</td>
                    <td>
                      <StatusChip status={f.dependent ? 'Dependent' : 'Non-dependent'} />
                    </td>
                    <td>
                      <Button
                        disabled={deleteFamilyMutation.isPending}
                        onClick={() => deleteFamilyMutation.mutate(f.id)}
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

      {/* TAB 5: EDUCATION */}
      {activeTab === 'education' ? (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <h3>Academic Qualifications</h3>
              <p className="cell-muted">Degrees, diplomas, and educational background.</p>
            </div>
            <Button onClick={() => setIsEduModalOpen(true)} variant="primary">
              <Plus aria-hidden="true" size={16} />
              Add Qualification
            </Button>
          </div>

          {educationList.length === 0 ? (
            <div className="directory-state">
              <GraduationCap aria-hidden="true" size={24} />
              <strong>No qualifications recorded.</strong>
              <p>Add educational credentials for HR verification.</p>
            </div>
          ) : (
            <DataTable caption="Educational qualifications and degrees">
              <thead>
                <tr>
                  <th scope="col">Degree / Qualification</th>
                  <th scope="col">Institution / University</th>
                  <th scope="col">Year of Passing</th>
                  <th scope="col">Grade / Percentage</th>
                  <th scope="col">Actions</th>
                </tr>
              </thead>
              <tbody>
                {educationList.map((edu) => (
                  <tr key={edu.id}>
                    <td><strong>{edu.degree}</strong></td>
                    <td>{edu.institution}</td>
                    <td>{edu.passingYear || 'â€”'}</td>
                    <td>{edu.scorePercentage || 'â€”'}</td>
                    <td>
                      <Button
                        disabled={deleteEduMutation.isPending}
                        onClick={() => deleteEduMutation.mutate(edu.id)}
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

      {/* TAB 6: EXPERIENCE */}
      {activeTab === 'experience' ? (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <h3>Prior Employment History</h3>
              <p className="cell-muted">Previous organizations, designations, and verified tenures.</p>
            </div>
            <Button onClick={() => setIsExpModalOpen(true)} variant="primary">
              <Plus aria-hidden="true" size={16} />
              Add Experience
            </Button>
          </div>

          {experienceList.length === 0 ? (
            <div className="directory-state">
              <Briefcase aria-hidden="true" size={24} />
              <strong>No prior experience recorded.</strong>
              <p>Add past employment records to document work history.</p>
            </div>
          ) : (
            <DataTable caption="Prior employment history">
              <thead>
                <tr>
                  <th scope="col">Company Name</th>
                  <th scope="col">Designation</th>
                  <th scope="col">From Date</th>
                  <th scope="col">To Date</th>
                  <th className="numeric-cell" scope="col">Last Drawn CTC</th>
                  <th scope="col">Actions</th>
                </tr>
              </thead>
              <tbody>
                {experienceList.map((exp) => (
                  <tr key={exp.id}>
                    <td><strong>{exp.companyName}</strong></td>
                    <td>{exp.designation}</td>
                    <td>{exp.fromDate ? formatDate(exp.fromDate) : 'â€”'}</td>
                    <td>{exp.toDate ? formatDate(exp.toDate) : 'Present'}</td>
                    <td className="numeric-cell">
                      {exp.lastSalary ? <Money amount={exp.lastSalary} /> : 'â€”'}
                    </td>
                    <td>
                      <Button
                        disabled={deleteExpMutation.isPending}
                        onClick={() => deleteExpMutation.mutate(exp.id)}
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

      {/* TAB 7: DOCUMENTS */}
      {activeTab === 'documents' ? (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <h3>Employee Identity & Compliance Documents</h3>
              <p className="cell-muted">PAN, Aadhaar, educational certificates, appointment letters, and payslips.</p>
            </div>
          </div>

          {documentsList.length === 0 ? (
            <div className="directory-state">
              <FileText aria-hidden="true" size={24} />
              <strong>No documents uploaded.</strong>
              <p>Verified statutory and KYC documents will appear here.</p>
            </div>
          ) : (
            <DataTable caption="Employee identity and compliance files">
              <thead>
                <tr>
                  <th scope="col">Document Title</th>
                  <th scope="col">Category</th>
                  <th scope="col">Expiry Date</th>
                  <th scope="col">Uploaded Date</th>
                </tr>
              </thead>
              <tbody>
                {documentsList.map((doc) => (
                  <tr key={doc.id}>
                    <td><strong>{doc.title}</strong></td>
                    <td><StatusChip status={doc.category || 'General'} /></td>
                    <td>{doc.expiryDate ? formatDate(doc.expiryDate) : 'No expiry'}</td>
                    <td>{doc.uploadedAt ? formatDate(doc.uploadedAt) : 'â€”'}</td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          )}
        </div>
      ) : null}

      {/* MODAL: CONFIGURE SALARY STRUCTURE */}
      {isSalaryModalOpen ? (
        <SalaryStructureModal
          components={allComponents}
          initialGross={Number(structure?.grossMonthly ?? 50000)}
          isPending={saveStructureMutation.isPending}
          onClose={() => setIsSalaryModalOpen(false)}
          onSave={(req) => saveStructureMutation.mutate(req)}
        />
      ) : null}

      {/* MODAL: LABOR PAY PREVIEW */}
      {isLaborPreviewOpen ? (
        <div className="modal-backdrop" role="presentation">
          <div aria-labelledby="labor-preview-title" aria-modal="true" className="modal-dialog" role="dialog">
            <div className="modal-header">
              <div>
                <h2 id="labor-preview-title">Shop Floor Labor Pay Preview</h2>
                <p className="cell-muted">Evaluates completed job cards, production hours, and piece counts.</p>
              </div>
              <button className="icon-button" onClick={() => setIsLaborPreviewOpen(false)} type="button">
                <X aria-hidden="true" size={18} />
              </button>
            </div>
            <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                <div>
                  <label className="form-label">Period Start</label>
                  <input
                    className="text-input"
                    onChange={(e) => setLaborStart(e.target.value)}
                    type="date"
                    value={laborStart}
                  />
                </div>
                <div>
                  <label className="form-label">Period End</label>
                  <input
                    className="text-input"
                    onChange={(e) => setLaborEnd(e.target.value)}
                    type="date"
                    value={laborEnd}
                  />
                </div>
              </div>

              {laborPayQuery.isLoading ? (
                <div className="directory-state">Evaluating shop floor job cards...</div>
              ) : laborPayQuery.data ? (
                <div className="summary-strip">
                  <div className="summary-card">
                    <span className="summary-card__label">Logged Hours</span>
                    <strong className="summary-card__value">{laborPayQuery.data.totalHours} hrs</strong>
                  </div>
                  <div className="summary-card">
                    <span className="summary-card__label">Pieces Completed</span>
                    <strong className="summary-card__value">{laborPayQuery.data.pieceCount} pcs</strong>
                  </div>
                  <div className="summary-card">
                    <span className="summary-card__label">Calculated Pay</span>
                    <strong className="summary-card__value text-success">
                      <Money amount={laborPayQuery.data.totalLaborPay} />
                    </strong>
                  </div>
                </div>
              ) : (
                <div className="directory-state">No manufacturing job cards logged in this period.</div>
              )}
            </div>
            <div className="modal-footer">
              <Button onClick={() => setIsLaborPreviewOpen(false)} variant="secondary">Close</Button>
            </div>
          </div>
        </div>
      ) : null}

      {/* MODAL: DECLARE INVESTMENTS (FORM 12BB) */}
      {isTaxModalOpen ? (
        <div className="modal-backdrop" role="presentation">
          <div aria-labelledby="tax-modal-title" aria-modal="true" className="modal-dialog" role="dialog">
            <div className="modal-header">
              <div>
                <h2 id="tax-modal-title">Income Tax Investment Declaration</h2>
                <p className="cell-muted">Form 12BB declaration for fiscal year {taxFy}.</p>
              </div>
              <button className="icon-button" onClick={() => setIsTaxModalOpen(false)} type="button">
                <X aria-hidden="true" size={18} />
              </button>
            </div>
            <form
              onSubmit={(e) => {
                e.preventDefault()
                const fd = new FormData(e.currentTarget)
                saveTaxMutation.mutate({
                  fiscalYear: taxFy,
                  regime: String(fd.get('regime') ?? 'NEW'),
                  section80cTotal: Number(fd.get('section80cTotal') ?? 0),
                  section80dMediclaim: Number(fd.get('section80dMediclaim') ?? 0),
                  hraRentPaidAnnual: Number(fd.get('hraRentPaidAnnual') ?? 0),
                  homeLoanInterest80ee: Number(fd.get('homeLoanInterest80ee') ?? 0),
                  otherDeductions: Number(fd.get('otherDeductions') ?? 0),
                  remarks: String(fd.get('remarks') ?? '').trim() || undefined,
                })
              }}
            >
              <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                <div>
                  <label className="form-label">Tax Regime</label>
                  <select className="select-input" defaultValue={taxDecl?.regime || 'NEW'} name="regime">
                    <option value="NEW">New Tax Regime (Sec 115BAC - Lower slab rates)</option>
                    <option value="OLD">Old Tax Regime (With itemized 80C/80D deductions)</option>
                  </select>
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                  <div>
                    <label className="form-label">Section 80C (Max ₹1.5L)</label>
                    <input className="text-input" defaultValue={Number(taxDecl?.section80cTotal ?? 150000)} name="section80cTotal" type="number" />
                  </div>
                  <div>
                    <label className="form-label">Section 80D (Mediclaim)</label>
                    <input className="text-input" defaultValue={Number(taxDecl?.section80dMediclaim ?? 25000)} name="section80dMediclaim" type="number" />
                  </div>
                  <div>
                    <label className="form-label">Annual Rent Paid (HRA)</label>
                    <input className="text-input" defaultValue={Number(taxDecl?.hraRentPaidAnnual ?? 0)} name="hraRentPaidAnnual" type="number" />
                  </div>
                  <div>
                    <label className="form-label">Home Loan Interest</label>
                    <input className="text-input" defaultValue={Number(taxDecl?.homeLoanInterest80ee ?? 0)} name="homeLoanInterest80ee" type="number" />
                  </div>
                </div>
                <div>
                  <label className="form-label">Other Deductions</label>
                  <input className="text-input" defaultValue={Number(taxDecl?.otherDeductions ?? 0)} name="otherDeductions" type="number" />
                </div>
                <div>
                  <label className="form-label">Remarks / Proof References</label>
                  <input className="text-input" defaultValue={taxDecl?.remarks || ''} name="remarks" placeholder="e.g. LIC Policy #123456" type="text" />
                </div>
              </div>
              <div className="modal-footer">
                <Button onClick={() => setIsTaxModalOpen(false)} type="button" variant="secondary">Cancel</Button>
                <Button disabled={saveTaxMutation.isPending} type="submit" variant="primary">
                  {saveTaxMutation.isPending ? 'Saving...' : 'Save Declaration'}
                </Button>
              </div>
            </form>
          </div>
        </div>
      ) : null}

      {/* MODAL: ADD FAMILY MEMBER */}
      {isFamilyModalOpen ? (
        <div className="modal-backdrop" role="presentation">
          <div aria-labelledby="family-modal-title" aria-modal="true" className="modal-dialog" role="dialog">
            <div className="modal-header">
              <h2 id="family-modal-title">Add Family Member / Nominee</h2>
              <button className="icon-button" onClick={() => setIsFamilyModalOpen(false)} type="button">
                <X aria-hidden="true" size={18} />
              </button>
            </div>
            <form
              onSubmit={(e) => {
                e.preventDefault()
                const fd = new FormData(e.currentTarget)
                addFamilyMutation.mutate({
                  name: String(fd.get('name') ?? '').trim(),
                  relationship: String(fd.get('relationship') ?? 'SPOUSE'),
                  dependent: fd.get('dependent') === 'on',
                })
              }}
            >
              <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                <div>
                  <label className="form-label">Full Name *</label>
                  <input className="text-input" name="name" required type="text" />
                </div>
                <div>
                  <label className="form-label">Relationship</label>
                  <select className="select-input" defaultValue="SPOUSE" name="relationship">
                    <option value="SPOUSE">Spouse</option>
                    <option value="CHILD">Child / Dependent</option>
                    <option value="FATHER">Father</option>
                    <option value="MOTHER">Mother</option>
                  </select>
                </div>
                <label style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
                  <input defaultChecked name="dependent" type="checkbox" />
                  <span>Mark as Dependent</span>
                </label>
              </div>
              <div className="modal-footer">
                <Button onClick={() => setIsFamilyModalOpen(false)} type="button" variant="secondary">Cancel</Button>
                <Button disabled={addFamilyMutation.isPending} type="submit" variant="primary">Save</Button>
              </div>
            </form>
          </div>
        </div>
      ) : null}

      {/* MODAL: ADD EDUCATION */}
      {isEduModalOpen ? (
        <div className="modal-backdrop" role="presentation">
          <div aria-labelledby="edu-modal-title" aria-modal="true" className="modal-dialog" role="dialog">
            <div className="modal-header">
              <h2 id="edu-modal-title">Add Qualification</h2>
              <button className="icon-button" onClick={() => setIsEduModalOpen(false)} type="button">
                <X aria-hidden="true" size={18} />
              </button>
            </div>
            <form
              onSubmit={(e) => {
                e.preventDefault()
                const fd = new FormData(e.currentTarget)
                addEduMutation.mutate({
                  degree: String(fd.get('degree') ?? '').trim(),
                  institution: String(fd.get('institution') ?? '').trim(),
                  passingYear: Number(fd.get('passingYear') ?? 2020),
                  scorePercentage: String(fd.get('scorePercentage') ?? '').trim(),
                })
              }}
            >
              <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                <div>
                  <label className="form-label">Degree / Certificate *</label>
                  <input className="text-input" name="degree" placeholder="e.g. B.Com / MBA Finance" required type="text" />
                </div>
                <div>
                  <label className="form-label">Institution / University *</label>
                  <input className="text-input" name="institution" placeholder="e.g. Delhi University" required type="text" />
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                  <div>
                    <label className="form-label">Passing Year</label>
                    <input className="text-input" defaultValue={2022} name="passingYear" type="number" />
                  </div>
                  <div>
                    <label className="form-label">Grade / %</label>
                    <input className="text-input" name="scorePercentage" placeholder="e.g. 78% / First Class" type="text" />
                  </div>
                </div>
              </div>
              <div className="modal-footer">
                <Button onClick={() => setIsEduModalOpen(false)} type="button" variant="secondary">Cancel</Button>
                <Button disabled={addEduMutation.isPending} type="submit" variant="primary">Save</Button>
              </div>
            </form>
          </div>
        </div>
      ) : null}

      {/* MODAL: ADD EXPERIENCE */}
      {isExpModalOpen ? (
        <div className="modal-backdrop" role="presentation">
          <div aria-labelledby="exp-modal-title" aria-modal="true" className="modal-dialog" role="dialog">
            <div className="modal-header">
              <h2 id="exp-modal-title">Add Prior Experience</h2>
              <button className="icon-button" onClick={() => setIsExpModalOpen(false)} type="button">
                <X aria-hidden="true" size={18} />
              </button>
            </div>
            <form
              onSubmit={(e) => {
                e.preventDefault()
                const fd = new FormData(e.currentTarget)
                addExpMutation.mutate({
                  companyName: String(fd.get('companyName') ?? '').trim(),
                  designation: String(fd.get('designation') ?? '').trim(),
                  fromDate: String(fd.get('fromDate') ?? '') || undefined,
                  toDate: String(fd.get('toDate') ?? '') || undefined,
                  lastSalary: Number(fd.get('lastSalary') ?? 0) || undefined,
                })
              }}
            >
              <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                <div>
                  <label className="form-label">Company Name *</label>
                  <input className="text-input" name="companyName" required type="text" />
                </div>
                <div>
                  <label className="form-label">Designation *</label>
                  <input className="text-input" name="designation" required type="text" />
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                  <div>
                    <label className="form-label">From Date</label>
                    <input className="text-input" name="fromDate" type="date" />
                  </div>
                  <div>
                    <label className="form-label">To Date</label>
                    <input className="text-input" name="toDate" type="date" />
                  </div>
                </div>
                <div>
                  <label className="form-label">Last Drawn Monthly CTC</label>
                  <input className="text-input" name="lastSalary" type="number" />
                </div>
              </div>
              <div className="modal-footer">
                <Button onClick={() => setIsExpModalOpen(false)} type="button" variant="secondary">Cancel</Button>
                <Button disabled={addExpMutation.isPending} type="submit" variant="primary">Save</Button>
              </div>
            </form>
          </div>
        </div>
      ) : null}
    </section>
  )
}

function SalaryStructureModal({
  components,
  initialGross,
  isPending,
  onClose,
  onSave,
}: {
  components: Array<{ id: string; code: string; name: string; componentType: string }>
  initialGross: number
  isPending: boolean
  onClose: () => void
  onSave: (req: SaveSalaryStructureRequest) => void
}) {
  const [gross, setGross] = useState(initialGross)
  const [effectiveFrom, setEffectiveFrom] = useState(new Date().toISOString().slice(0, 10))
  const [payType, setPayType] = useState('SALARY')

  // Auto calculate standard Indian breakdown: Basic 50%, HRA 25%, Special Allowance 25%
  const basicAmt = Math.round(gross * 0.5)
  const hraAmt = Math.round(gross * 0.25)
  const specialAmt = Math.max(0, gross - basicAmt - hraAmt)

  return (
    <div className="modal-backdrop" role="presentation">
      <div aria-labelledby="salary-modal-title" aria-modal="true" className="modal-dialog modal-dialog--lg" role="dialog">
        <div className="modal-header">
          <div>
            <h2 id="salary-modal-title">Configure Salary Structure</h2>
            <p className="cell-muted">Assign monthly gross pay and statutory component allocations.</p>
          </div>
          <button className="icon-button" onClick={onClose} type="button">
            <X aria-hidden="true" size={18} />
          </button>
        </div>
        <form
          onSubmit={(e) => {
            e.preventDefault()
            const basicComp = components.find((c) => c.code === 'BASIC' || c.name.toLowerCase().includes('basic'))
            const hraComp = components.find((c) => c.code === 'HRA' || c.name.toLowerCase().includes('house rent'))
            const specialComp = components.find((c) => c.code === 'SPL_ALW' || c.name.toLowerCase().includes('special'))

            const lines: Array<{ componentId: string; monthlyAmount: number }> = []
            if (basicComp) lines.push({ componentId: basicComp.id, monthlyAmount: basicAmt })
            if (hraComp) lines.push({ componentId: hraComp.id, monthlyAmount: hraAmt })
            if (specialComp) lines.push({ componentId: specialComp.id, monthlyAmount: specialAmt })

            // If master components don't match, send first 3 available components
            if (lines.length === 0 && components.length > 0 && components[0]) {
              lines.push({ componentId: components[0].id, monthlyAmount: gross })
            }

            onSave({
              effectiveFrom,
              grossMonthly: gross,
              ctcMonthly: Math.round(gross * 1.12), // CTC with employer PF
              payType,
              lines,
            })
          }}
        >
          <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
              <div>
                <label className="form-label">Gross Monthly Pay (₹) *</label>
                <input
                  className="text-input"
                  min={1}
                  onChange={(e) => setGross(Number(e.target.value) || 0)}
                  required
                  type="number"
                  value={gross}
                />
              </div>
              <div>
                <label className="form-label">Effective From *</label>
                <input
                  className="text-input"
                  onChange={(e) => setEffectiveFrom(e.target.value)}
                  required
                  type="date"
                  value={effectiveFrom}
                />
              </div>
              <div>
                <label className="form-label">Compensation Type</label>
                <select
                  className="select-input"
                  onChange={(e) => setPayType(e.target.value)}
                  value={payType}
                >
                  <option value="SALARY">Fixed Monthly Salary</option>
                  <option value="HOURLY">Hourly Rate</option>
                  <option value="PIECE_RATE">Piece Rate (Shop Floor)</option>
                </select>
              </div>
            </div>

            <fieldset style={{ border: '1px solid var(--k-color-border-subtle)', borderRadius: 6, padding: 12 }}>
              <legend style={{ fontWeight: 600, padding: '0 6px', fontSize: '0.9rem' }}>
                Standard Indian Component Split (Preview)
              </legend>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 12, marginTop: 6 }}>
                <div>
                  <span className="form-label">Basic Salary (50%)</span>
                  <strong><Money amount={basicAmt} /></strong>
                </div>
                <div>
                  <span className="form-label">HRA (25%)</span>
                  <strong><Money amount={hraAmt} /></strong>
                </div>
                <div>
                  <span className="form-label">Special Allowance (25%)</span>
                  <strong><Money amount={specialAmt} /></strong>
                </div>
              </div>
            </fieldset>
          </div>
          <div className="modal-footer">
            <Button onClick={onClose} type="button" variant="secondary">Cancel</Button>
            <Button disabled={isPending} type="submit" variant="primary">
              {isPending ? 'Saving...' : 'Apply Salary Structure'}
            </Button>
          </div>
        </form>
      </div>
    </div>
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

function DocumentError({ onBack }: { onBack: () => void }) {
  return (
    <section className="workspace-page">
      <div className="directory-state directory-state--error" role="alert">
        <FileText aria-hidden="true" size={24} />
        <strong>Unable to load employee profile.</strong>
        <p>The record was not found or your session cannot access this workspace.</p>
        <Button onClick={onBack} variant="secondary">
          <ArrowLeft aria-hidden="true" size={16} />
          Back to Directory
        </Button>
      </div>
    </section>
  )
}
