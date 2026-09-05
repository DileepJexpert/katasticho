import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import {
  TrendingUp,
  Clock,
  Hammer,
  FileCheck,
  Calculator,
  AlertCircle,
} from 'lucide-react'
import {
  Button,
  FormField,
  FormGrid,
  PageHeader,
  SelectInput,
  TextInput,
  Money,
  StatusChip,
} from '@/design-system'
import {
  listEmployees,
  previewLaborPay,
  type LaborPayPreview,
} from '@/features/payroll/payroll-api'

function getMonthStartEnd() {
  const now = new Date()
  const year = now.getFullYear()
  const month = String(now.getMonth() + 1).padStart(2, '0')
  const lastDay = new Date(year, now.getMonth() + 1, 0).getDate()
  return {
    start: `${year}-${month}-01`,
    end: `${year}-${month}-${String(lastDay).padStart(2, '0')}`,
  }
}

export function LaborPayPreviewPage() {
  const defaultDates = getMonthStartEnd()
  const [employeeId, setEmployeeId] = useState('')
  const [periodStart, setPeriodStart] = useState(defaultDates.start)
  const [periodEnd, setPeriodEnd] = useState(defaultDates.end)
  const [queryTrigger, setQueryTrigger] = useState<{ empId: string; start: string; end: string } | null>(null)

  const employeesQuery = useQuery({
    queryKey: ['payroll-employees-list-all'],
    queryFn: () => listEmployees(0, 200),
  })

  const previewQuery = useQuery({
    queryKey: ['payroll-labor-pay-preview', queryTrigger?.empId, queryTrigger?.start, queryTrigger?.end],
    queryFn: () => previewLaborPay(queryTrigger!.empId, queryTrigger!.start, queryTrigger!.end),
    enabled: !!queryTrigger,
  })

  const employees = employeesQuery.data?.content ?? []
  const employeeOptions = [
    { value: '', label: '-- Select Worker / Employee --' },
    ...employees.map((e) => ({
      value: e.id,
      label: `${e.fullName} (${e.employeeCode || 'NO CODE'}) · ${e.designation || 'Worker'}`,
    })),
  ]

  const handlePreview = (e: React.FormEvent) => {
    e.preventDefault()
    if (!employeeId) return
    setQueryTrigger({ empId: employeeId, start: periodStart, end: periodEnd })
  }

  const result: LaborPayPreview | undefined = previewQuery.data

  return (
    <div className="space-y-6">
      <PageHeader
        title="Production Labor Pay & Piece-Rate Preview"
        description="Preview piece-rate and hourly production wages derived from shopfloor work orders before executing payroll runs."
      />

      {/* Filter Card */}
      <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-6 shadow-sm">
        <form onSubmit={handlePreview} className="space-y-4">
          <FormField label="Select Worker / Employee *" htmlFor="workerSelect">
            <SelectInput
              id="workerSelect"
              value={employeeId}
              onChange={(e) => setEmployeeId(e.target.value)}
              options={employeeOptions}
              required
            />
          </FormField>

          <FormGrid columns={2}>
            <FormField label="Period Start Date *" htmlFor="periodStart">
              <TextInput
                id="periodStart"
                type="date"
                required
                value={periodStart}
                onChange={(e) => setPeriodStart(e.target.value)}
              />
            </FormField>
            <FormField label="Period End Date *" htmlFor="periodEnd">
              <TextInput
                id="periodEnd"
                type="date"
                required
                value={periodEnd}
                onChange={(e) => setPeriodEnd(e.target.value)}
              />
            </FormField>
          </FormGrid>

          <div className="flex justify-end">
            <Button type="submit" variant="primary" disabled={!employeeId || previewQuery.isFetching}>
              <Calculator className="mr-2 h-4 w-4" />
              {previewQuery.isFetching ? 'Calculating Pay...' : 'Preview Wages'}
            </Button>
          </div>
        </form>
      </div>

      {/* Results Section */}
      {previewQuery.isLoading ? (
        <div className="p-8 text-center text-sm text-[var(--color-text-muted)]">
          Aggregating completed manufacturing job cards...
        </div>
      ) : result ? (
        <div className="space-y-6">
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-4 shadow-sm">
              <div className="flex items-center justify-between">
                <span className="text-xs font-medium uppercase tracking-wider text-[var(--color-text-muted)]">
                  Computed Wage
                </span>
                <div className="rounded-md bg-[var(--color-brand)]/10 p-2 text-[var(--color-brand)]">
                  <TrendingUp className="h-5 w-5" />
                </div>
              </div>
              <div className="mt-2 text-2xl font-bold text-[var(--color-brand)]">
                <Money amount={result.amount ?? 0} />
              </div>
              <span className="mt-1 block text-xs text-[var(--color-text-muted)]">
                Pay Structure: <StatusChip status="ACTIVE">{result.payType || 'PIECE_RATE'}</StatusChip>
              </span>
            </div>

            <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-4 shadow-sm">
              <div className="flex items-center justify-between">
                <span className="text-xs font-medium uppercase tracking-wider text-[var(--color-text-muted)]">
                  Job Cards Completed
                </span>
                <div className="rounded-md bg-[var(--color-brand)]/10 p-2 text-[var(--color-brand)]">
                  <FileCheck className="h-5 w-5" />
                </div>
              </div>
              <div className="mt-2 text-2xl font-bold text-[var(--color-text-default)]">
                {result.jobCardCount ?? 0}
              </div>
              <span className="mt-1 block text-xs text-[var(--color-text-muted)]">
                Completed work tickets in window
              </span>
            </div>

            <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-4 shadow-sm">
              <div className="flex items-center justify-between">
                <span className="text-xs font-medium uppercase tracking-wider text-[var(--color-text-muted)]">
                  Total Hours Logged
                </span>
                <div className="rounded-md bg-[var(--color-brand)]/10 p-2 text-[var(--color-brand)]">
                  <Clock className="h-5 w-5" />
                </div>
              </div>
              <div className="mt-2 text-2xl font-bold text-[var(--color-text-default)]">
                {result.totalHours ?? 0} hrs
              </div>
              <span className="mt-1 block text-xs text-[var(--color-text-muted)]">
                On shopfloor work operations
              </span>
            </div>

            <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-4 shadow-sm">
              <div className="flex items-center justify-between">
                <span className="text-xs font-medium uppercase tracking-wider text-[var(--color-text-muted)]">
                  Total Output Pieces
                </span>
                <div className="rounded-md bg-[var(--color-brand)]/10 p-2 text-[var(--color-brand)]">
                  <Hammer className="h-5 w-5" />
                </div>
              </div>
              <div className="mt-2 text-2xl font-bold text-[var(--color-text-default)]">
                {result.totalPieces ?? 0} units
              </div>
              <span className="mt-1 block text-xs text-[var(--color-text-muted)]">
                Manufactured quantity accepted
              </span>
            </div>
          </div>

          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-bg-surface)] p-4 text-xs text-[var(--color-text-muted)] shadow-sm">
            <div className="flex items-start space-x-2">
              <AlertCircle className="mt-0.5 h-4 w-4 text-[var(--color-brand)]" />
              <span>
                <strong>Integration Note:</strong> When you generate a monthly payroll run for this employee, these production earnings will automatically populate as the base wage earnings component based on their salary structure mode (Hourly or Piece-Rate).
              </span>
            </div>
          </div>
        </div>
      ) : (
        <div className="rounded-lg border border-dashed border-[var(--color-border)] p-12 text-center text-[var(--color-text-muted)]">
          <Calculator className="mx-auto h-10 w-10 opacity-40" />
          <h4 className="mt-3 text-sm font-semibold text-[var(--color-text-default)]">No Preview Generated</h4>
          <p className="mt-1 text-xs">
            Select a worker and date range above, then click &quot;Preview Wages&quot; to aggregate completed job cards.
          </p>
        </div>
      )}
    </div>
  )
}
