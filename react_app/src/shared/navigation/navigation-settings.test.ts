import { describe, expect, it } from 'vitest'
import { parseDisabledNavigationIds } from '@/shared/navigation/navigation-settings'

describe('parseDisabledNavigationIds', () => {
  it('reads and de-duplicates the JSON array stored by sidebar customisation', () => {
    expect(parseDisabledNavigationIds('["sales.orders", "contacts", "sales.orders"]')).toEqual([
      'sales.orders',
      'contacts',
    ])
  })

  it('preserves the legacy comma-separated format accepted by Flutter', () => {
    expect(parseDisabledNavigationIds('sales.orders, contacts, sales.orders')).toEqual([
      'sales.orders',
      'contacts',
    ])
  })

  it('fails safely to no disabled entries for an absent or malformed value', () => {
    expect(parseDisabledNavigationIds(null)).toEqual([])
    expect(parseDisabledNavigationIds('{not-json}')).toEqual([])
  })
})
