import { describe, expect, it } from 'vitest'
import { shipmentSchedule } from './shipment-schedule'

describe('shipment local-time input contract', () => {
  it('omits blank optional dates instead of sending invalid Instants', () => { expect(shipmentSchedule('', '')).toEqual({ valid: true }) })
  it('sends ISO Instants interpreted in the browser timezone', () => {
    expect(shipmentSchedule('2026-09-10T10:30', '2026-09-10T11:30')).toEqual({ valid: true, estimatedDeparture: new Date('2026-09-10T10:30').toISOString(), estimatedArrival: new Date('2026-09-10T11:30').toISOString() })
  })
  it('rejects backwards and invalid schedules', () => {
    expect(shipmentSchedule('2026-09-11T12:00', '2026-09-10T12:00').valid).toBe(false)
    expect(shipmentSchedule('invalid', '').valid).toBe(false)
  })
  it('accepts a standalone ETA and equal start/end instants', () => {
    expect(shipmentSchedule('', '2026-09-10T12:00').valid).toBe(true)
    expect(shipmentSchedule('2026-09-10T12:00', '2026-09-10T12:00').valid).toBe(true)
  })
})
