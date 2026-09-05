import { useSessionStore } from '@/shared/session/session-store'

export function useInventoryAccess() {
  const role = useSessionStore((state) => state.user?.role) ?? ''
  return {
    operate: ['OWNER', 'ADMIN', 'ACCOUNTANT', 'OPERATOR'].includes(role),
    manage: ['OWNER', 'ADMIN', 'ACCOUNTANT'].includes(role),
    administer: ['OWNER', 'ADMIN'].includes(role),
    readZones: ['OWNER', 'ADMIN', 'OPERATOR'].includes(role),
  }
}
