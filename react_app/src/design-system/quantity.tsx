import { formatQuantity } from '@/shared/format/format'

export function Quantity({ unit, value }: { value: number | string | null | undefined; unit?: string | null }) {
  return <span className="quantity">{formatQuantity(value, unit)}</span>
}
