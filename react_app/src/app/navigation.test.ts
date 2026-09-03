import { describe, expect, it } from 'vitest'
import { getVisibleNavigation } from '@/app/navigation'

describe('getVisibleNavigation', () => {
  it('removes a disabled stable navigation id without removing other live routes', () => {
    const visible = getVisibleNavigation({
      role: 'ADMIN',
      industry: null,
      country: null,
      disabledIds: ['contacts'],
    })

    expect(visible.map((item) => item.id)).toEqual(['dashboard', 'inventory.items', 'inventory.picklists', 'sales.orders', 'sales.invoices'])
  })
})
