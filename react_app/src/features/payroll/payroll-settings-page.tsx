import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  Building,
  Save,
  Settings,
} from 'lucide-react'
import { Button } from '@/design-system/button'
import { PageHeader } from '@/design-system/page-header'
import { StatusChip } from '@/design-system/status-chip'
import {
  getPayrollSettings,
  updatePayrollSettings,
  type PayrollSettings,
} from '@/features/payroll/payroll-api'
import { listAccounts } from '@/features/accounts/accounts-api'

export function PayrollSettingsPage() {
  const queryClient = useQueryClient()

  const settingsQuery = useQuery({
    queryKey: ['payroll-settings'],
    queryFn: () => getPayrollSettings(),
  })

  const accountsQuery = useQuery({
    queryKey: ['accounts-all'],
    queryFn: () => listAccounts(),
  })

  const updateMutation = useMutation({
    mutationFn: (data: PayrollSettings) => updatePayrollSettings(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['payroll-settings'] })
      alert('Payroll settings and general ledger mappings saved.')
    },
  })

  const settings = settingsQuery.data ?? {}
  const accounts = accountsQuery.data ?? []

  const expenseAccounts = accounts.filter((a) => a.type === 'EXPENSE')
  const liabilityAccounts = accounts.filter((a) => a.type === 'LIABILITY')

  return (
    <section className="workspace-page">
      <PageHeader
        eyebrow="Settings"
        title="Payroll & Statutory Rules"
        description="Payroll processing cycle, default General Ledger account mappings, and Indian statutory compliance rules (PF, ESI, PT, LWF, TDS)."
        actions={<StatusChip status="Admin configuration" />}
      />

      {settingsQuery.isLoading ? (
        <div className="directory-state">Loading payroll configuration...</div>
      ) : (
        <form
          onSubmit={(e) => {
            e.preventDefault()
            const fd = new FormData(e.currentTarget)
            updateMutation.mutate({
              payrollStartMonth: Number(fd.get('payrollStartMonth') ?? 4),
              payFrequency: String(fd.get('payFrequency') ?? 'MONTHLY'),
              defaultSalaryExpenseAccountId: String(fd.get('defaultSalaryExpenseAccountId') ?? '') || null,
              defaultSalaryPayableAccountId: String(fd.get('defaultSalaryPayableAccountId') ?? '') || null,
              defaultPfPayableAccountId: String(fd.get('defaultPfPayableAccountId') ?? '') || null,
              defaultEsiPayableAccountId: String(fd.get('defaultEsiPayableAccountId') ?? '') || null,
              defaultPtPayableAccountId: String(fd.get('defaultPtPayableAccountId') ?? '') || null,
              defaultLwfPayableAccountId: String(fd.get('defaultLwfPayableAccountId') ?? '') || null,
              defaultTdsPayableAccountId: String(fd.get('defaultTdsPayableAccountId') ?? '') || null,
              pfEnabled: fd.get('pfEnabled') === 'on',
              esiEnabled: fd.get('esiEnabled') === 'on',
              ptEnabled: fd.get('ptEnabled') === 'on',
              lwfEnabled: fd.get('lwfEnabled') === 'on',
              tdsEnabled: fd.get('tdsEnabled') === 'on',
            })
          }}
          style={{ display: 'flex', flexDirection: 'column', gap: 20 }}
        >
          <div className="document-layout">
            <section className="document-card">
              <h2>
                <Settings aria-hidden="true" size={18} style={{ display: 'inline', marginRight: 6 }} />
                Payroll Cycle & Statutory Toggles
              </h2>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 14, marginTop: 12 }}>
                <div>
                  <label className="form-label">Payroll Financial Start Month</label>
                  <select
                    className="select-input"
                    defaultValue={settings.payrollStartMonth ?? 4}
                    name="payrollStartMonth"
                  >
                    <option value={4}>April (Indian Fiscal Year standard)</option>
                    <option value={1}>January (Calendar Year)</option>
                  </select>
                </div>

                <div>
                  <label className="form-label">Pay Frequency</label>
                  <select
                    className="select-input"
                    defaultValue={settings.payFrequency ?? 'MONTHLY'}
                    name="payFrequency"
                  >
                    <option value="MONTHLY">Monthly (Standard)</option>
                    <option value="BI_WEEKLY">Bi-Weekly</option>
                    <option value="WEEKLY">Weekly</option>
                  </select>
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginTop: 8 }}>
                  <span style={{ fontWeight: 600, fontSize: '0.9rem' }}>Enabled Statutory Engines</span>
                  <label style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
                    <input defaultChecked={settings.pfEnabled !== false} name="pfEnabled" type="checkbox" />
                    <span>Provident Fund (EPFO 12% Employee + 12% Employer Match)</span>
                  </label>
                  <label style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
                    <input defaultChecked={settings.esiEnabled !== false} name="esiEnabled" type="checkbox" />
                    <span>Employee State Insurance (ESIC 0.75% + 3.25% Match for wages â‰¤ â‚¹21,000)</span>
                  </label>
                  <label style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
                    <input defaultChecked={settings.ptEnabled !== false} name="ptEnabled" type="checkbox" />
                    <span>Professional Tax (State Slab Calculation)</span>
                  </label>
                  <label style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
                    <input defaultChecked={settings.lwfEnabled !== false} name="lwfEnabled" type="checkbox" />
                    <span>Labour Welfare Fund (LWF State Rules)</span>
                  </label>
                  <label style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
                    <input defaultChecked={settings.tdsEnabled !== false} name="tdsEnabled" type="checkbox" />
                    <span>Tax Deducted at Source (TDS Sec 192 Old/New Regime)</span>
                  </label>
                </div>
              </div>
            </section>

            <section className="document-card">
              <h2>
                <Building aria-hidden="true" size={18} style={{ display: 'inline', marginRight: 6 }} />
                General Ledger Posting Account Mappings
              </h2>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 12, marginTop: 12 }}>
                <div>
                  <label className="form-label">Salary Expense Account (DR)</label>
                  <select
                    className="select-input"
                    defaultValue={settings.defaultSalaryExpenseAccountId ?? ''}
                    name="defaultSalaryExpenseAccountId"
                  >
                    <option value="">Select Expense Account (e.g. 5001 Salaries & Wages)</option>
                    {expenseAccounts.map((a) => (
                      <option key={a.id} value={a.id}>
                        {a.code} - {a.name}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="form-label">Salary Payable Account (CR)</label>
                  <select
                    className="select-input"
                    defaultValue={settings.defaultSalaryPayableAccountId ?? ''}
                    name="defaultSalaryPayableAccountId"
                  >
                    <option value="">Select Payable Account (e.g. 2020 Salaries Payable)</option>
                    {liabilityAccounts.map((a) => (
                      <option key={a.id} value={a.id}>
                        {a.code} - {a.name}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="form-label">PF Payable Account (CR)</label>
                  <select
                    className="select-input"
                    defaultValue={settings.defaultPfPayableAccountId ?? ''}
                    name="defaultPfPayableAccountId"
                  >
                    <option value="">Select PF Payable Account (e.g. 2021 PF Payable)</option>
                    {liabilityAccounts.map((a) => (
                      <option key={a.id} value={a.id}>
                        {a.code} - {a.name}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="form-label">ESI Payable Account (CR)</label>
                  <select
                    className="select-input"
                    defaultValue={settings.defaultEsiPayableAccountId ?? ''}
                    name="defaultEsiPayableAccountId"
                  >
                    <option value="">Select ESI Payable Account (e.g. 2022 ESI Payable)</option>
                    {liabilityAccounts.map((a) => (
                      <option key={a.id} value={a.id}>
                        {a.code} - {a.name}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="form-label">TDS (Sec 192) Payable Account (CR)</label>
                  <select
                    className="select-input"
                    defaultValue={settings.defaultTdsPayableAccountId ?? ''}
                    name="defaultTdsPayableAccountId"
                  >
                    <option value="">Select TDS Payable Account (e.g. 2025 TDS Salary Payable)</option>
                    {liabilityAccounts.map((a) => (
                      <option key={a.id} value={a.id}>
                        {a.code} - {a.name}
                      </option>
                    ))}
                  </select>
                </div>
              </div>
            </section>
          </div>

          <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 12 }}>
            <Button disabled={updateMutation.isPending} type="submit" variant="primary">
              <Save aria-hidden="true" size={16} />
              {updateMutation.isPending ? 'Saving...' : 'Save Settings'}
            </Button>
          </div>
        </form>
      )}
    </section>
  )
}
