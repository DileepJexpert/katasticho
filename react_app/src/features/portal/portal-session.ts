import { create } from 'zustand'
import type { PortalSession } from './portal-api'

// No persistence: portal credentials never enter ERP storage or query caches.
export const usePortalSession = create<{ session: PortalSession | null; revision: number; notice: string; signIn: (session: PortalSession) => void; signOut: (notice?: string) => void }>((set) => ({
  session: null, revision: 0, notice: '',
  signIn: (session) => set((state) => ({ session, revision: state.revision + 1, notice: '' })),
  signOut: (notice = '') => set((state) => ({ session: null, revision: state.revision + 1, notice })),
}))
