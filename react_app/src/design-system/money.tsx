import { formatMoney } from '@/shared/format/format'

export function Money({ amount, currency = 'INR' }: { amount: number | string | null | undefined; currency?: string }) {
  return <span className="money">{formatMoney(amount, currency)}</span>
}
