import { apiFetch } from '@/api/client/api-client'

export type PortalAccount = { id: string; contactId: string; kind: string; email: string; fullName: string; status: string; lastLoginAt: string | null }
export type PortalInvite = PortalAccount & { inviteToken: string; inviteExpiresAt: string }
const root = '/api/v1/portal-users'
export const listPortalAccounts = () => apiFetch<PortalAccount[]>(root)
export const invitePortalAccount = (body: { contactId: string; email: string; fullName: string }) => apiFetch<PortalInvite>(root, { method: 'POST', body })
export const resendPortalInvite = (id: string) => apiFetch<PortalInvite>(`${root}/${encodeURIComponent(id)}/resend-invite`, { method: 'POST' })
export const portalAccountAction = (id: string, action: 'suspend' | 'reactivate' | 'delete') => apiFetch<unknown>(`${root}/${encodeURIComponent(id)}${action === 'delete' ? '' : `/${action}`}`, { method: action === 'delete' ? 'DELETE' : 'POST' })
