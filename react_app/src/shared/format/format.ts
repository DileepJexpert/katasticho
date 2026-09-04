export function formatMoney(amount: number | string | null | undefined, currency: string | null | undefined = 'INR') {
  const value = amount === null || amount === undefined || amount === '' ? 0 : Number(amount)
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: currency ?? 'INR',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(Number.isFinite(value) ? value : 0)
}

export function formatDate(date: string | null | undefined) {
  if (!date) return '--'
  const dateOnly = date.includes('T') ? date.split('T')[0] : date
  const parsed = new Date(`${dateOnly}T00:00:00`)
  if (Number.isNaN(parsed.getTime())) {
    const fallback = new Date(date)
    if (Number.isNaN(fallback.getTime())) return '--'
    return new Intl.DateTimeFormat('en-IN', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
    }).format(fallback)
  }
  return new Intl.DateTimeFormat('en-IN', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  }).format(parsed)
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

export function formatPercent(value: number | string | null | undefined) {
  if (value === null || value === undefined || value === '') return '--'
  const num = Number(value)
  return Number.isFinite(num) ? `${num}%` : '--'
}

export function formatStatusLabel(status: string | null | undefined) {
  if (!status) return 'Not started'
  return status.toLocaleLowerCase().replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase())
}
