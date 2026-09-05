export function captureVisitLocation(): Promise<{ latitude: number; longitude: number }> {
  return new Promise((resolve, reject) => {
    if (!navigator.geolocation) { reject(new Error('Location is unavailable. Use a device with location access for check-in and check-out.')); return }
    navigator.geolocation.getCurrentPosition((position) => {
      const { latitude, longitude } = position.coords
      if (!Number.isFinite(latitude) || !Number.isFinite(longitude) || Math.abs(latitude) > 90 || Math.abs(longitude) > 180) { reject(new Error('The device returned an invalid location.')); return }
      resolve({ latitude, longitude })
    }, () => reject(new Error('Location could not be obtained. Allow location access and retry; no visit was recorded.')), { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 })
  })
}
