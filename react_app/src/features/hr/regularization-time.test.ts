import { expect, it } from 'vitest'
import { regularizationTime } from './regularization-time'

it('converts device-local punch correction times to UTC rather than appending Z', () => {
  expect(regularizationTime('2026-09-05', '09:00', '18:00')).toEqual({ punchIn: new Date('2026-09-05T09:00').toISOString(), punchOut: new Date('2026-09-05T18:00').toISOString() })
})
it('supports a single corrected punch and rejects reversed or empty times', () => {
  expect(regularizationTime('2026-09-05', '', '18:00')).toEqual({ punchOut: new Date('2026-09-05T18:00').toISOString() })
  expect(() => regularizationTime('2026-09-05', '18:00', '09:00')).toThrow()
  expect(() => regularizationTime('2026-09-05', '', '')).toThrow()
})
