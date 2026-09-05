import { afterEach, expect, it, vi } from 'vitest'
import { captureVisitLocation } from './visit-location'
afterEach(() => vi.unstubAllGlobals())
it('requests fresh coordinates only when a visit action asks for them', async () => {
  const getCurrentPosition = vi.fn((success) => success({ coords: { latitude: 26.5, longitude: 81.3 } }))
  vi.stubGlobal('navigator', { geolocation: { getCurrentPosition } })
  expect(await captureVisitLocation()).toEqual({ latitude: 26.5, longitude: 81.3 })
  expect(getCurrentPosition).toHaveBeenCalledWith(expect.any(Function), expect.any(Function), expect.objectContaining({ maximumAge: 0 }))
})
it('does not fabricate zero coordinates when location is denied', async () => {
  vi.stubGlobal('navigator', { geolocation: { getCurrentPosition: (_success: unknown, failure: () => void) => failure() } })
  await expect(captureVisitLocation()).rejects.toThrow('no visit was recorded')
})
