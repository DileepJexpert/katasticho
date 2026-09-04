import { apiFetch } from '@/api/client/api-client'

export type OrgUser = {
  id: string
  email: string
  fullName?: string | null
  role: 'OWNER' | 'ADMIN' | 'ACCOUNTANT' | 'OPERATOR' | 'VIEWER' | string
  active: boolean
  lastLoginAt?: string | null
  createdAt?: string
}

export type PendingInvite = {
  id: string
  email: string
  role: string
  status: 'PENDING' | 'ACCEPTED' | 'EXPIRED' | string
  createdAt: string
  expiresAt?: string | null
}

export type PdfTemplateSetting = {
  id?: string
  documentType: 'INVOICE' | 'ESTIMATE' | 'PURCHASE_ORDER' | 'DELIVERY_CHALLAN' | string
  primaryColor: string
  fontFamily: string
  logoUrl?: string | null
  showBankDetails: boolean
  showQrCode: boolean
  headerText?: string | null
  footerText?: string | null
  termsAndConditions?: string | null
}

// ── User Management Calls ──

export async function listOrgUsers() {
  return apiFetch<OrgUser[]>('/api/v1/org/users')
}

export async function listPendingInvites() {
  return apiFetch<PendingInvite[]>('/api/v1/org/users/invites')
}

export async function sendUserInvite(data: { email: string; role: string }) {
  return apiFetch<PendingInvite>('/api/v1/org/users/invite', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

export async function updateUserRole(userId: string, role: string) {
  return apiFetch<OrgUser>(`/api/v1/org/users/${userId}/role`, {
    method: 'PUT',
    body: JSON.stringify({ role }),
  })
}

export async function cancelUserInvite(inviteId: string) {
  return apiFetch<string>(`/api/v1/org/users/invites/${inviteId}`, {
    method: 'DELETE',
  })
}

// ── PDF Template Calls ──

export async function listPdfTemplates() {
  return apiFetch<PdfTemplateSetting[]>('/api/v1/settings/pdf-templates')
}

export async function getPdfTemplate(documentType: string) {
  return apiFetch<PdfTemplateSetting>(`/api/v1/settings/pdf-templates/${documentType}`)
}

export async function savePdfTemplate(data: PdfTemplateSetting) {
  return apiFetch<PdfTemplateSetting>('/api/v1/settings/pdf-templates', {
    method: 'POST',
    body: JSON.stringify(data),
  })
}
