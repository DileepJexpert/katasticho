import type { Item } from '@/features/items/items-api'
import type { CreateEstimateRequest, Estimate, EstimateLineRequest } from './estimates-api'

export const estimateConversionBlocker = 'Invoice conversion is unavailable in the current backend: valid customer contacts are rejected (EST_CONTACT_NOT_CUSTOMER). No invoice will be created here until that contract defect is resolved.'

export function estimatePermissions(role?: string) {
  return {
    write: ['OWNER', 'ADMIN', 'ACCOUNTANT', 'OPERATOR'].includes(role ?? ''),
    delete: ['OWNER', 'ADMIN', 'ACCOUNTANT'].includes(role ?? ''),
  }
}

export function canEditEstimate(status: string) { return status === 'DRAFT' || status === 'SENT' }

export function localEstimateDate(date = new Date()) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
}

export type EstimateFormLine = {
  key: string
  itemId?: string
  description: string
  unit: string
  hsnCode: string
  quantity: string
  rate: string
  discountPct: string
  taxRate: string
}

export function newEstimateLine(item?: Item): EstimateFormLine {
  return {
    key: crypto.randomUUID(), itemId: item?.id,
    description: item?.name ?? '', unit: item?.unitOfMeasure ?? '', hsnCode: item?.hsnCode ?? '',
    quantity: '1', rate: String(item?.salePrice ?? 0), discountPct: '0', taxRate: String(item?.gstRate ?? 0),
  }
}

export function estimateFormLines(estimate?: Estimate): EstimateFormLine[] {
  return estimate?.lines.map((line) => ({
    key: line.id, itemId: line.itemId ?? undefined, description: line.description,
    unit: line.unit ?? '', hsnCode: line.hsnCode ?? '', quantity: String(line.quantity),
    rate: String(line.rate), discountPct: String(line.discountPct ?? 0), taxRate: String(line.taxRate ?? 0),
  })) ?? []
}

type Header = Omit<CreateEstimateRequest, 'lines'>
export function buildEstimateRequest(header: Header, lines: EstimateFormLine[], original?: Estimate): CreateEstimateRequest {
  if (!header.contactId) throw new Error('Select a customer.')
  if (!/^\d{4}-\d{2}-\d{2}$/.test(header.estimateDate)) throw new Error('Enter an estimate date.')
  if (header.expiryDate && header.expiryDate < header.estimateDate) throw new Error('Expiry cannot be before the estimate date.')
  if (original?.expiryDate && !header.expiryDate) throw new Error('The existing API cannot clear an expiry date. Keep it or choose another date.')
  if (!lines.length) throw new Error('Add at least one product or service line.')
  const payloadLines: EstimateLineRequest[] = lines.map((line, index) => {
    const numericFields = [line.quantity, line.rate, line.discountPct, line.taxRate]
    const quantity = Number(line.quantity)
    const rate = Number(line.rate)
    const discountPct = Number(line.discountPct)
    const taxRate = Number(line.taxRate)
    if (!line.description.trim() || numericFields.some((value) => !value.trim() || !Number.isFinite(Number(value))) ||
        quantity < 0.001 || rate < 0 || discountPct < 0 || discountPct > 100 || taxRate < 0 || taxRate > 100) {
      throw new Error(`Complete line ${index + 1}: description, quantity at least 0.001, non-negative rate, and discount/tax between 0 and 100.`)
    }
    return { itemId: line.itemId, description: line.description.trim(), unit: line.unit.trim() || undefined,
      hsnCode: line.hsnCode.trim() || undefined, quantity, rate, discountPct, taxRate }
  })
  return { ...header, lines: payloadLines }
}

function decimalRatio(raw: string): [bigint, bigint] {
  // Match the numeric JSON payload, including exponent notation, without binary rounding.
  const [mantissa = '0', exponent = '0'] = String(Number(raw)).split('e')
  const [whole = '0', fraction = ''] = mantissa.split('.')
  const scale = fraction.length - Number(exponent)
  const coefficient = BigInt(whole + fraction)
  return scale >= 0 ? [coefficient, 10n ** BigInt(scale)] : [coefficient * 10n ** BigInt(-scale), 1n]
}

function halfUp(numerator: bigint, denominator: bigint) {
  return (numerator * 2n + denominator) / (denominator * 2n)
}

// Match EstimateService's per-line, two-decimal HALF_UP sequence. Never reprice saved documents.
export function previewEstimate(lines: EstimateFormLine[]) {
  let subtotal = 0n
  let discount = 0n
  let tax = 0n
  for (const line of lines) {
    if ([line.quantity, line.rate, line.discountPct, line.taxRate].some((value) => !value.trim() || !Number.isFinite(Number(value)) || Number(value) < 0) || Number(line.quantity) < 0.001 || Number(line.discountPct) > 100 || Number(line.taxRate) > 100) return null
    const [q, qScale] = decimalRatio(line.quantity)
    const [r, rScale] = decimalRatio(line.rate)
    const [d, dScale] = decimalRatio(line.discountPct)
    const [t, tScale] = decimalRatio(line.taxRate)
    const grossCents = halfUp(q * r * 100n, qScale * rScale)
    const discountCents = halfUp(grossCents * d, dScale * 100n)
    const taxableCents = grossCents - discountCents
    subtotal += taxableCents
    discount += discountCents
    tax += halfUp(taxableCents * t, tScale * 100n)
  }
  if ([subtotal, discount, tax, subtotal + tax].some((value) => value > BigInt(Number.MAX_SAFE_INTEGER))) return null
  return { subtotal: Number(subtotal) / 100, discount: Number(discount) / 100, tax: Number(tax) / 100, total: Number(subtotal + tax) / 100 }
}
