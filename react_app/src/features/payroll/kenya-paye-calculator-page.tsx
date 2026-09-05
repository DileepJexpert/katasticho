import { useState, useEffect } from 'react'
import { useMutation } from '@tanstack/react-query'
import {
  Calculator,
  ShieldCheck,
} from 'lucide-react'
import {
  Button,
  FormField,
  PageHeader,
  TextInput,
} from '@/design-system'
import {
  calculateKenyaPaye,
  type KenyaPayeCalculationResponse,
} from '@/features/payroll/payroll-api'

const SALARY_PRESETS = [30000, 50000, 85000, 150000, 300000]

function formatKsh(amount: number): string {
  return 'KSh ' + new Intl.NumberFormat('en-KE', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount)
}

export function KenyaPayeCalculatorPage() {
  const [grossSalary, setGrossSalary] = useState('85000')

  const calcMutation = useMutation({
    mutationFn: (salary: number) => calculateKenyaPaye({ grossSalary: salary }),
  })

  useEffect(() => {
    const val = parseFloat(grossSalary)
    if (!isNaN(val) && val > 0) {
      calcMutation.mutate(val)
    }
  }, [grossSalary])

  const result: KenyaPayeCalculationResponse | undefined = calcMutation.data

  return (
    <div className="space-y-6">
      <PageHeader
        title="Kenya PAYE & Statutory Salary Calculator"
        description="Live statutory deductions breakdown under 2024-2026 Kenya Revenue Authority (KRA) rules (PAYE, NSSF, SHIF, Housing Levy)."
      />

      {/* Input Card */}
      <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-6 shadow-sm">
        <h3 className="text-sm font-semibold text-[var(--color-text-default)]">
          Gross Monthly Salary (KSh)
        </h3>
        <p className="mt-1 text-xs text-[var(--color-text-muted)]">
          Enter worker monthly base salary before any statutory deductions.
        </p>

        <div className="mt-4 flex flex-col gap-4 sm:flex-row sm:items-end">
          <div className="flex-1">
            <FormField label="Monthly Gross Pay (KSh) *" htmlFor="grossSalary">
              <TextInput
                id="grossSalary"
                type="number"
                step="any"
                min="0"
                value={grossSalary}
                onChange={(e) => setGrossSalary(e.target.value)}
                placeholder="e.g. 85000"
              />
            </FormField>
          </div>
          <Button
            variant="primary"
            disabled={calcMutation.isPending}
            onClick={() => {
              const val = parseFloat(grossSalary)
              if (!isNaN(val) && val > 0) calcMutation.mutate(val)
            }}
          >
            <Calculator className="mr-2 h-4 w-4" />
            {calcMutation.isPending ? 'Calculating...' : 'Calculate'}
          </Button>
        </div>

        {/* Preset Chips */}
        <div className="mt-4 flex flex-wrap items-center gap-2">
          <span className="text-xs text-[var(--color-text-muted)]">Quick Presets:</span>
          {SALARY_PRESETS.map((preset) => (
            <button
              key={preset}
              type="button"
              onClick={() => setGrossSalary(preset.toString())}
              className={`rounded-full border px-3 py-1 text-xs font-medium transition-colors ${grossSalary === preset.toString() ? 'border-[var(--color-brand)] bg-[var(--color-brand)] text-white' : 'border-[var(--color-border)] bg-[var(--color-bg-subtle)] text-[var(--color-text-default)] hover:border-[var(--color-brand)]'}`}
            >
              {formatKsh(preset)}
            </button>
          ))}
        </div>
      </div>

      {/* Breakdown Results */}
      {result && (
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-6 shadow-sm">
          <div className="flex items-center justify-between border-b border-[var(--color-border)] pb-4">
            <div>
              <h3 className="text-base font-bold text-[var(--color-text-default)]">
                Statutory Breakdown (2024-2026 KRA Rules)
              </h3>
              <p className="text-xs text-[var(--color-text-muted)]">
                Applies standard graduated tax bands, NSSF Tier I/II limits, SHIF 2.75%, and Affordable Housing Levy 1.5%.
              </p>
            </div>
            <span className="inline-flex items-center rounded bg-emerald-50 px-2.5 py-1 text-xs font-semibold text-emerald-700">
              <ShieldCheck className="mr-1 h-3.5 w-3.5" /> KRA Verified
            </span>
          </div>

          <div className="divide-y divide-[var(--color-border)]">
            {/* Gross Pay */}
            <div className="flex items-center justify-between py-3">
              <span className="font-semibold text-[var(--color-text-default)]">Gross Monthly Pay</span>
              <span className="font-mono text-base font-bold text-[var(--color-text-default)]">
                {formatKsh(result.grossSalary)}
              </span>
            </div>

            {/* NSSF */}
            <div className="space-y-1.5 py-3">
              <div className="flex items-center justify-between text-xs text-[var(--color-text-muted)]">
                <span>NSSF Tier I (6% up to KSh 8,000)</span>
                <span className="font-mono text-[var(--color-error)]">- {formatKsh(result.nssfTier1)}</span>
              </div>
              <div className="flex items-center justify-between text-xs text-[var(--color-text-muted)]">
                <span>NSSF Tier II (6% on KSh 8,000 to KSh 36,000)</span>
                <span className="font-mono text-[var(--color-error)]">- {formatKsh(result.nssfTier2)}</span>
              </div>
              <div className="flex items-center justify-between text-sm font-semibold text-[var(--color-text-default)]">
                <span>Total NSSF Contribution</span>
                <span className="font-mono text-[var(--color-error)]">- {formatKsh(result.totalNssf)}</span>
              </div>
            </div>

            {/* Taxable Pay */}
            <div className="flex items-center justify-between py-3">
              <span className="font-semibold text-[var(--color-text-default)]">Taxable Pay (Gross - NSSF)</span>
              <span className="font-mono text-sm font-semibold text-[var(--color-text-default)]">
                {formatKsh(result.taxablePay)}
              </span>
            </div>

            {/* PAYE */}
            <div className="space-y-1.5 py-3">
              <div className="flex items-center justify-between text-xs text-[var(--color-text-muted)]">
                <span>Gross PAYE (Graduated Bands)</span>
                <span className="font-mono text-[var(--color-text-default)]">{formatKsh(result.grossPaye)}</span>
              </div>
              <div className="flex items-center justify-between text-xs text-emerald-600">
                <span>Less: Monthly Personal Relief</span>
                <span className="font-mono">+ {formatKsh(result.personalRelief)}</span>
              </div>
              <div className="flex items-center justify-between text-sm font-semibold text-[var(--color-text-default)]">
                <span>Net PAYE Deducted</span>
                <span className="font-mono text-[var(--color-error)]">- {formatKsh(result.netPaye)}</span>
              </div>
            </div>

            {/* Statutory Health & Housing */}
            <div className="space-y-1.5 py-3">
              <div className="flex items-center justify-between text-xs text-[var(--color-text-muted)]">
                <span>SHIF Health Insurance (2.75%)</span>
                <span className="font-mono text-[var(--color-error)]">- {formatKsh(result.shifAmount)}</span>
              </div>
              <div className="flex items-center justify-between text-xs text-[var(--color-text-muted)]">
                <span>Affordable Housing Levy (1.5%)</span>
                <span className="font-mono text-[var(--color-error)]">- {formatKsh(result.housingLevyAmount)}</span>
              </div>
              <div className="flex items-center justify-between text-sm font-semibold text-[var(--color-text-default)]">
                <span>Total Statutory Deductions</span>
                <span className="font-mono text-[var(--color-error)]">- {formatKsh(result.totalDeductions)}</span>
              </div>
            </div>
          </div>

          {/* Net Take-Home Highlight Card */}
          <div className="mt-6 rounded-lg border-2 border-emerald-500/30 bg-emerald-50/50 p-5 dark:bg-emerald-950/20">
            <div className="flex items-center justify-between">
              <div>
                <span className="text-xs font-semibold uppercase tracking-wider text-emerald-800 dark:text-emerald-300">
                  Net Take-Home Salary
                </span>
                <p className="mt-0.5 text-xs text-[var(--color-text-muted)]">
                  Disbursed to employee after all KRA and Kenyan statutory deductions.
                </p>
              </div>
              <div className="font-mono text-2xl font-extrabold text-emerald-600 dark:text-emerald-400">
                {formatKsh(result.netPay)}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
