import { formatMoney } from '@/shared/format/format'

export function Money({
  amount,
  currency = 'INR',
  showCurrency = true,
}: {
  amount: number | string | null | undefined
  currency?: string | null
  showCurrency?: boolean
}) {
  const value = amount === null || amount === undefined || amount === '' ? 0 : Number(amount)
  const safeValue = Number.isFinite(value) ? value : 0
  const formatted = showCurrency
    ? formatMoney(safeValue, currency ?? 'INR')
    : new Intl.NumberFormat('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(safeValue)

  return <span className="money">{formatted}</span>
}
