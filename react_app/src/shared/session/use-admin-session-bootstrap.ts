import { useEffect } from 'react'
import { useSessionStore } from './session-store'

let restoration: Promise<void> | null = null

/** Mounted only by ERP routes. External portal routes must not send ERP cookies. */
export function useAdminSessionBootstrap() {
  const status = useSessionStore((state) => state.status)
  const restore = useSessionStore((state) => state.restore)
  useEffect(() => {
    if (status === 'booting') restoration ??= restore().finally(() => { restoration = null })
  }, [status, restore])
}
