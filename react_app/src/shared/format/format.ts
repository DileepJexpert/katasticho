export function formatMoney(amount: number | string | null | undefined, currency = 'INR') {
  const value = amount === null || amount === undefined || amount === '' ? 0 : Number(amount)
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency,
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(Number.isFinite(value) ? value : 0)
}

export function formatDate(date: string | null | undefined) {
  if (!date) return '--'
  return new Intl.DateTimeFormat('en-IN', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  }).format(new Date(`${date}T00:00:00`))
}

export function formatDateTime(dateTime: string | null | undefined) {
  if (!dateTime) return '--'
  const parsed = new Date(dateTime)
  if (Number.isNaN(parsed.getTime())) return '--'

  return new Intl.DateTimeFormat('en-IN', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).format(parsed)
}

export function formatQuantity(value: number | string | null | undefined, unit?: string | null) {
  const quantity = value === null || value === undefined || value === '' ? 0 : Number(value)
  const formatted = new Intl.NumberFormat('en-IN', {
    maximumFractionDigits: 3,
  }).format(Number.isFinite(quantity) ? quantity : 0)

  return unit ? `${formatted} ${unit}` : formatted
}

export function formatStatusLabel(status: string | null | undefined) {
  if (!status) return 'Not started'
  return status.toLocaleLowerCase().replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}
