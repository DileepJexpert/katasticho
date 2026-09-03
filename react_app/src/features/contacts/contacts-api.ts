import { apiFetch } from '@/api/client/api-client'

export type ContactFilter = 'ALL' | 'CUSTOMER' | 'VENDOR' | 'SUPPLIER'

export type Contact = {
  id: string
  contactType: 'CUSTOMER' | 'VENDOR' | 'BOTH'
  displayName: string
  companyName: string | null
  email: string | null
  phone: string | null
  mobile: string | null
  gstin: string | null
  outstandingAr: number | string | null
  outstandingAp: number | string | null
  active: boolean
  supplierEnabled: boolean
}

export type ContactSummary = {
  total: number
  customers: number
  vendors: number
  suppliers: number
}

export type ContactPage = {
  content: Contact[]
  totalElements: number
  totalPages: number
  number: number
  size: number
}

type ListContactsOptions = {
  filter: ContactFilter
  page: number
  search: string
}

export async function listContacts(options: Partial<ListContactsOptions> = {}) {
  const { filter = 'ALL', page = 0, search = '' } = options
  const params = new URLSearchParams({ page: String(page), size: '25', sort: 'displayName,asc' })
  if (filter !== 'ALL') params.set('type', filter)
  if (search.trim()) params.set('search', search.trim())
  return apiFetch<ContactPage>(`/api/v1/contacts?${params.toString()}`)
}

export function getContactSummary() {
  return apiFetch<ContactSummary>('/api/v1/contacts/summary')
}
