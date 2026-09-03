import { describe, expect, it } from 'vitest'
import { formatDate, formatDateTime, formatMoney, formatPercent, formatQuantity, formatStatusLabel } from '@/shared/format/format'

describe('finance formatters', () => {
  it('uses Indian digit grouping with a fixed decimal amount', () => {
    expect(formatMoney(123456.7)).toBe('₹1,23,456.70')
  })

  it('formats date-only API values without timezone drift', () => {
    expect(formatDate('2026-09-03')).toBe('03 Sept 2026')
  })

  it('does not show invalid server timestamps as dates', () => {
    expect(formatDateTime('not-a-date')).toBe('--')
  })

  it('formats inventory quantities with their server-provided unit', () => {
    expect(formatQuantity('1250.5', 'PCS')).toBe('1,250.5 PCS')
  })

  it('formats percentages correctly with suffix', () => {
    expect(formatPercent(18)).toBe('18%')
    expect(formatPercent(null)).toBe('--')
  })

  it('formats server lifecycle codes without changing their meaning', () => {
    expect(formatStatusLabel('PENDING_APPROVAL')).toBe('Pending Approval')
  })
})
