import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  Download,
  CheckCircle,
  Save,
  Send,
  Info,
} from 'lucide-react'
import {
  Button,
  DataTable,
  FormField,
  FormGrid,
  PageHeader,
  SelectInput,
  StatusChip,
  TextInput,
  FilterTabs,
  Money,
} from '@/design-system'
import { formatDate } from '@/shared/format/format'
import {
  getMyTaxDeclaration,
  saveMyTaxDeclaration,
  submitTaxDeclaration,
  listTaxDeclarations,
  verifyTaxDeclaration,
  getForm12BbPdfUrl,
  type EmployeeTaxDeclaration,
} from '@/features/payroll/payroll-api'

function currentFiscalYear(): string {
  const now = new Date()
  const year = now.getFullYear()
  const month = now.getMonth() + 1
  const start = month >= 4 ? year : year - 1
  const end = (start + 1).toString().slice(-2)
  return start + '-' + end
}

const FY_OPTIONS = [
  { value: '2026-27', label: 'FY 2026-27 (AY 2027-28)' },
  { value: '2025-26', label: 'FY 2025-26 (AY 2026-27)' },
  { value: '2024-25', label: 'FY 2024-25 (AY 2025-26)' },
]

export function TaxDeclarationPage() {
  const [fy, setFy] = useState(currentFiscalYear())
  const [activeTab, setActiveTab] = useState<'my' | 'admin'>('my')
  const [saveBanner, setSaveBanner] = useState(false)

  const queryClient = useQueryClient()

  const myQuery = useQuery({
    queryKey: ['payroll-my-tax-declaration', fy],
    queryFn: () => getMyTaxDeclaration(fy),
    enabled: activeTab === 'my',
  })

  const adminQuery = useQuery({
    queryKey: ['payroll-admin-tax-declarations', fy],
    queryFn: () => listTaxDeclarations(fy),
    enabled: activeTab === 'admin',
  })

  const decl = myQuery.data

  const saveMutation = useMutation({
    mutationFn: (data: Partial<EmployeeTaxDeclaration>) => saveMyTaxDeclaration(fy, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['payroll-my-tax-declaration', fy] })
      setSaveBanner(true)
      setTimeout(() => setSaveBanner(false), 3000)
    },
  })

  const submitMutation = useMutation({
    mutationFn: (id: string) => submitTaxDeclaration(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['payroll-my-tax-declaration', fy] })
    },
  })

  const verifyMutation = useMutation({
    mutationFn: (id: string) => verifyTaxDeclaration(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['payroll-admin-tax-declarations', fy] })
    },
  })

  const isSubmittedOrVerified = decl?.status === 'SUBMITTED' || decl?.status === 'VERIFIED'

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
        <PageHeader
          title="Tax Declaration (Form 12BB)"
          description="Employee annual investment & deduction declaration under Rule 26C of the Income Tax Rules."
        />
        <div className="flex items-center space-x-3">
          <label htmlFor="fySelect" className="text-xs font-semibold uppercase text-[var(--color-text-muted)]">
            Fiscal Year:
          </label>
          <div className="w-48">
            <SelectInput
              id="fySelect"
              value={fy}
              onChange={(e) => setFy(e.target.value)}
              options={FY_OPTIONS}
            />
          </div>
        </div>
      </div>

      <FilterTabs<'my' | 'admin'>
        items={[
          { value: 'my', label: 'My Declaration' },
          { value: 'admin', label: 'HR Review & Verification' },
        ]}
        activeValue={activeTab}
        onChange={(tab) => setActiveTab(tab)}
      />

      {activeTab === 'my' && (
        <div className="space-y-6">
          {myQuery.isLoading ? (
            <div className="p-8 text-center text-sm text-[var(--color-text-muted)]">Loading declaration...</div>
          ) : (
            <>
              {decl && (
                <div className="flex items-center justify-between rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-4 shadow-sm">
                  <div className="flex items-center space-x-3">
                    <StatusChip status={decl.status || 'DRAFT'}>{decl.status || 'Draft'}</StatusChip>
                    <span className="text-sm text-[var(--color-text-muted)]">
                      {decl.status === 'VERIFIED'
                        ? 'Verified by Payroll Team'
                        : decl.status === 'SUBMITTED'
                        ? 'Submitted for HR Verification'
                        : 'Draft Mode — You can modify your declarations anytime'}
                    </span>
                  </div>
                  <div className="flex items-center space-x-3">
                    {decl.id && (
                      <Button
                        variant="secondary"
                        onClick={() => window.open(getForm12BbPdfUrl(decl.id), '_blank')}
                      >
                        <Download className="mr-2 h-4 w-4" /> Form 12BB PDF
                      </Button>
                    )}
                    {!isSubmittedOrVerified && decl.id && (
                      <Button
                        variant="primary"
                        disabled={submitMutation.isPending}
                        onClick={() => {
                          if (confirm('Finalize and submit Form 12BB declaration to HR?')) {
                            submitMutation.mutate(decl.id)
                          }
                        }}
                      >
                    <Send className="mr-2 h-4 w-4" />
                    {submitMutation.isPending ? 'Submitting...' : 'Submit Declaration'}
                  </Button>
                )}
              </div>
            </div>
          )}

          {saveBanner && (
            <div className="flex items-center space-x-2 rounded border border-[var(--color-brand)] bg-[var(--color-brand)]/10 p-3 text-sm font-medium text-[var(--color-brand)]">
              <CheckCircle className="h-4 w-4" />
              <span>Tax declaration saved successfully!</span>
            </div>
          )}

          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-6 shadow-sm">
            <form
              key={decl?.id ?? 'new-decl'}
              onSubmit={(e) => {
                e.preventDefault()
                const fd = new FormData(e.currentTarget)
                const payload: Partial<EmployeeTaxDeclaration> = {
                  taxRegime: fd.get('taxRegime') as string,
                  deduction80c: Number(fd.get('deduction80c')) || 0,
                  deduction80ccd1b: Number(fd.get('deduction80ccd1b')) || 0,
                  deduction80dSelf: Number(fd.get('deduction80dSelf')) || 0,
                  deduction80dParents: Number(fd.get('deduction80dParents')) || 0,
                  deduction80e: Number(fd.get('deduction80e')) || 0,
                  deduction80g: Number(fd.get('deduction80g')) || 0,
                  deduction80tta: Number(fd.get('deduction80tta')) || 0,
                  deduction80ttb: Number(fd.get('deduction80ttb')) || 0,
                  homeLoanInterest: Number(fd.get('homeLoanInterest')) || 0,
                  hraRentPaid: Number(fd.get('hraRentPaid')) || 0,
                  hraMetroCity: fd.get('hraMetroCity') === 'on',
                  landlordPan: (fd.get('landlordPan') as string) || '',
                  otherIncome: Number(fd.get('otherIncome')) || 0,
                }
                saveMutation.mutate(payload)
              }}
              className="space-y-6"
            >
              {/* Regime Selection */}
              <div className="rounded-lg border border-[var(--color-brand)]/20 bg-[var(--color-brand)]/5 p-4">
                <div className="flex items-start space-x-3">
                  <Info className="mt-0.5 h-5 w-5 text-[var(--color-brand)]" />
                  <div>
                    <h4 className="text-sm font-semibold text-[var(--color-text-default)]">Tax Regime Choice</h4>
                    <p className="text-xs text-[var(--color-text-muted)]">
                      The default New Tax Regime u/s 115BAC offers lower slab tax rates with zero deduction claims. If you choose Old Regime, you can claim 80C, 80D, and HRA exemptions below.
                    </p>
                    <div className="mt-3 flex items-center space-x-6">
                      <label className="flex items-center space-x-2 text-sm font-medium text-[var(--color-text-default)]">
                        <input
                          type="radio"
                          name="taxRegime"
                          value="NEW"
                          defaultChecked={decl?.taxRegime !== 'OLD'}
                          disabled={isSubmittedOrVerified}
                          className="text-[var(--color-brand)] focus:ring-[var(--color-brand)]"
                        />
                        <span>New Regime (Concessional u/s 115BAC)</span>
                      </label>
                      <label className="flex items-center space-x-2 text-sm font-medium text-[var(--color-text-default)]">
                        <input
                          type="radio"
                          name="taxRegime"
                          value="OLD"
                          defaultChecked={decl?.taxRegime === 'OLD'}
                          disabled={isSubmittedOrVerified}
                          className="text-[var(--color-brand)] focus:ring-[var(--color-brand)]"
                        />
                        <span>Old Regime (Claim 80C / 80D / HRA)</span>
                      </label>
                    </div>
                  </div>
                </div>
              </div>

              {/* Section 80C & Deductions */}
              <div>
                <h4 className="mb-2 text-sm font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
                  Chapter VI-A: Section 80C & NPS
                </h4>
                <p className="mb-4 text-xs text-[var(--color-text-muted)]">
                  Section 80C allows deductions up to ₹1,50,000 (EPF, PPF, ELSS, Life Insurance, Principal Home Loan).
                </p>
                <FormGrid columns={2}>
                  <FormField label="Section 80C Total (Max ₹1.5L)" htmlFor="deduction80c">
                    <TextInput
                      id="deduction80c"
                      name="deduction80c"
                      type="number"
                      step="any"
                      defaultValue={decl?.deduction80c ?? ''}
                      disabled={isSubmittedOrVerified}
                      placeholder="e.g. 150000"
                    />
                  </FormField>
                  <FormField label="Section 80CCD(1B) Additional NPS (Max ₹50,000)" htmlFor="deduction80ccd1b">
                    <TextInput
                      id="deduction80ccd1b"
                      name="deduction80ccd1b"
                      type="number"
                      step="any"
                      defaultValue={decl?.deduction80ccd1b ?? ''}
                      disabled={isSubmittedOrVerified}
                      placeholder="e.g. 50000"
                    />
                  </FormField>
                </FormGrid>
              </div>

              {/* Medical Insurance 80D */}
              <div>
                <h4 className="mb-2 text-sm font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
                  Section 80D: Health Insurance Mediclaim
                </h4>
                <FormGrid columns={2}>
                  <FormField label="Self, Spouse & Children (Max ₹25,000)" htmlFor="deduction80dSelf">
                    <TextInput
                      id="deduction80dSelf"
                      name="deduction80dSelf"
                      type="number"
                      step="any"
                      defaultValue={decl?.deduction80dSelf ?? ''}
                      disabled={isSubmittedOrVerified}
                      placeholder="e.g. 25000"
                    />
                  </FormField>
                  <FormField label="Parents (Max ₹50,000 if senior citizen)" htmlFor="deduction80dParents">
                    <TextInput
                      id="deduction80dParents"
                      name="deduction80dParents"
                      type="number"
                      step="any"
                      defaultValue={decl?.deduction80dParents ?? ''}
                      disabled={isSubmittedOrVerified}
                      placeholder="e.g. 50000"
                    />
                  </FormField>
                </FormGrid>
              </div>

              {/* HRA Exemption */}
              <div>
                <h4 className="mb-2 text-sm font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
                  Section 10(13A): House Rent Allowance (HRA) Exemption
                </h4>
                <FormGrid columns={3}>
                  <FormField label="Annual Rent Paid (₹)" htmlFor="hraRentPaid">
                    <TextInput
                      id="hraRentPaid"
                      name="hraRentPaid"
                      type="number"
                      step="any"
                      defaultValue={decl?.hraRentPaid ?? ''}
                      disabled={isSubmittedOrVerified}
                      placeholder="e.g. 240000"
                    />
                  </FormField>
                  <FormField label="Landlord PAN (mandatory if rent > ₹1L)" htmlFor="landlordPan">
                    <TextInput
                      id="landlordPan"
                      name="landlordPan"
                      defaultValue={decl?.landlordPan ?? ''}
                      disabled={isSubmittedOrVerified}
                      placeholder="ABCDE1234F"
                    />
                  </FormField>
                  <div className="flex items-center pt-6">
                    <label className="flex items-center space-x-2 text-sm font-medium text-[var(--color-text-default)]">
                      <input
                        type="checkbox"
                        name="hraMetroCity"
                        defaultChecked={decl?.hraMetroCity}
                        disabled={isSubmittedOrVerified}
                        className="rounded text-[var(--color-brand)] focus:ring-[var(--color-brand)]"
                      />
                      <span>Metro City (50% rule)</span>
                    </label>
                  </div>
                </FormGrid>
              </div>

              {/* Home Loan Interest & Other */}
              <div>
                <h4 className="mb-2 text-sm font-semibold uppercase tracking-wider text-[var(--color-text-muted)]">
                  Section 24(b) & Other Income
                </h4>
                <FormGrid columns={2}>
                  <FormField label="Home Loan Interest Section 24(b) (Max ₹2,00,000)" htmlFor="homeLoanInterest">
                    <TextInput
                      id="homeLoanInterest"
                      name="homeLoanInterest"
                      type="number"
                      step="any"
                      defaultValue={decl?.homeLoanInterest ?? ''}
                      disabled={isSubmittedOrVerified}
                      placeholder="e.g. 200000"
                    />
                  </FormField>
                  <FormField label="Other Income / (Loss) from House Property" htmlFor="otherIncome">
                    <TextInput
                      id="otherIncome"
                      name="otherIncome"
                      type="number"
                      step="any"
                      defaultValue={decl?.otherIncome ?? ''}
                      disabled={isSubmittedOrVerified}
                      placeholder="e.g. 15000"
                    />
                  </FormField>
                </FormGrid>
              </div>

              {!isSubmittedOrVerified && (
                <div className="flex justify-end space-x-3">
                  <Button type="submit" variant="primary" disabled={saveMutation.isPending}>
                    <Save className="mr-2 h-4 w-4" />
                    {saveMutation.isPending ? 'Saving Draft...' : 'Save Draft'}
                  </Button>
                </div>
              )}
            </form>
          </div>
        </>
      )}
    </div>
  )}

      {activeTab === 'admin' && (
        <div className="space-y-4">
          {adminQuery.isLoading ? (
            <div className="p-8 text-center text-sm text-[var(--color-text-muted)]">Loading declarations...</div>
          ) : (adminQuery.data ?? []).length === 0 ? (
            <div className="p-8 text-center text-sm text-[var(--color-text-muted)]">
              No tax declarations submitted for FY {fy} yet.
            </div>
          ) : (
            <DataTable caption={'Tax declarations submitted for FY ' + fy}>
              <thead>
                <tr>
                  <th scope="col">Employee ID</th>
                  <th scope="col">Chosen Regime</th>
                  <th scope="col">Declared 80C</th>
                  <th scope="col">Rent Paid (HRA)</th>
                  <th scope="col">Status</th>
                  <th scope="col">Submitted At</th>
                  <th scope="col" className="text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {(adminQuery.data ?? []).map((item) => (
                  <tr key={item.id}>
                    <td>
                      <span className="font-mono text-xs font-semibold text-[var(--color-text-default)]">
                        {item.employeeId}
                      </span>
                    </td>
                    <td>
                      <span className={item.taxRegime === 'OLD' ? 'inline-flex rounded bg-amber-100 px-2 py-0.5 text-xs font-semibold text-amber-800' : 'inline-flex rounded bg-teal-100 px-2 py-0.5 text-xs font-semibold text-teal-800'}>
                        {item.taxRegime} Regime
                      </span>
                    </td>
                    <td><Money amount={item.deduction80c ?? 0} /></td>
                    <td><Money amount={item.hraRentPaid ?? 0} /></td>
                    <td><StatusChip status={item.status || 'DRAFT'}>{item.status || 'Draft'}</StatusChip></td>
                    <td>
                      <span className="font-mono text-xs text-[var(--color-text-muted)]">
                        {item.submittedAt ? formatDate(item.submittedAt) : '--'}
                      </span>
                    </td>
                    <td className="text-right">
                      <div className="flex items-center justify-end space-x-2">
                        <Button
                          variant="ghost"
                          onClick={() => window.open(getForm12BbPdfUrl(item.id), '_blank')}
                          title="Download signed Form 12BB PDF"
                        >
                          <Download className="h-4 w-4" />
                        </Button>
                        {item.status !== 'VERIFIED' && (
                          <Button
                            variant="secondary"
                            disabled={verifyMutation.isPending}
                            onClick={() => {
                              if (confirm("Verify this employee's Form 12BB declaration?")) {
                                verifyMutation.mutate(item.id)
                              }
                            }}
                          >
                            <CheckCircle className="mr-1 h-3.5 w-3.5 text-[var(--color-brand)]" />
                            Verify
                          </Button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </DataTable>
          )}
        </div>
      )}
    </div>
  )
}
