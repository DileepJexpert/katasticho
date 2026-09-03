import { formatMoney } from '@/shared/format/format'

export function Money({ amount, currency = 'INR' }: { amount: number | string | null | undefined; currency?: string | null }) {
  return <span className="money">{formatMoney(amount, currency ?? 'INR')}</span>
}
