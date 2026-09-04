import { apiFetch } from '@/api/client/api-client'

export type ContactFilter = 'ALL' | 'CUSTOMER' | 'VENDOR' | 'SUPPLIER'

export type Contact = {
  id: string
  contactType: 'CUSTOMER' | 'VENDOR' | 'BOTH'
  displayName: string
  name?: string
  companyName: string | null
  firstName?: string | null
  lastName?: string | null
  email: string | null
  phone: string | null
  mobile: string | null
  website?: string | null
  gstin: string | null
  pan?: string | null
  gstTreatment?: string | null
  placeOfSupply?: string | null
  billingAddressLine1?: string | null
  billingAddressLine2?: string | null
  billingCity?: string | null
  billingState?: string | null
  billingStateCode?: string | null
  billingPostalCode?: string | null
  billingCountry?: string | null
  shippingAddressLine1?: string | null
  shippingAddressLine2?: string | null
  shippingCity?: string | null
  shippingState?: string | null
  shippingStateCode?: string | null
  shippingPostalCode?: string | null
  shippingCountry?: string | null
  currency?: string | null
  paymentTermsDays?: number | null
  creditLimit?: number | string | null
  openingBalance?: number | string | null
  outstandingAr: number | string | null
  outstandingAp: number | string | null
  salesHold?: boolean
  salesHoldReason?: string | null
  salesHoldUntil?: string | null
  tdsApplicable?: boolean
  tdsSection?: string | null
  tdsRate?: number | string | null
  bankName?: string | null
  bankAccountNo?: string | null
  bankIfsc?: string | null
  upiId?: string | null
  notes?: string | null
  createdAt?: string | null
  medicalCategory?: string | null
  specialty?: string | null
  mrClass?: string | null
  visitsPerMonth?: number | null
  msmeRegistered?: boolean
  msmeRegistrationNo?: string | null
  persons?: ContactPerson[]
  active: boolean
  supplierEnabled: boolean
}

export type ContactPerson = {
  id: string
  salutation: string | null
  firstName: string | null
  lastName: string | null
  designation: string | null
  department: string | null
  email: string | null
  phone: string | null
  mobile: string | null
  primary: boolean
}

export type ContactLedgerEntry = {
  date: string
  type: string
  number: string | null
  referenceId: string
  description: string | null
  debit: number | string | null
  credit: number | string | null
  runningBalance: number | string | null
}

export type ContactLedger = {
  contactId: string
  contactName: string
  contactType: string
  openingBalance: number | string | null
  closingBalance: number | string | null
  totalInvoiced: number | string | null
  totalPaid: number | string | null
  entries: ContactLedgerEntry[]
}

export type ContactRoleFilter = ContactFilter

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

export type ListContactsOptions = {
  filter: ContactFilter
  page: number
  search: string
  size?: number | string
}

export async function listContacts(options: Partial<ListContactsOptions> = {}) {
  const { filter = 'ALL', page = 0, search = '', size = 25 } = options
  const params = new URLSearchParams({ page: String(page), size: String(size), sort: 'displayName,asc' })
  if (filter !== 'ALL') params.set('type', filter)
  if (search.trim()) params.set('search', search.trim())
  return apiFetch<ContactPage>(`/api/v1/contacts?${params.toString()}`)
}

export function getContactSummary() {
  return apiFetch<ContactSummary>('/api/v1/contacts/summary')
}

export function getContact(id: string) {
  return apiFetch<Contact>(`/api/v1/contacts/${id}`)
}

export function getContactLedger(id: string, startDate: string, endDate: string) {
  const params = new URLSearchParams({ startDate, endDate })
  return apiFetch<ContactLedger>(`/api/v1/contacts/${id}/ledger?${params.toString()}`)
}

export type CreateContactRequest = {
  contactType: 'CUSTOMER' | 'VENDOR' | 'BOTH'
  displayName: string
  companyName?: string
  email?: string
  phone?: string
  mobile?: string
  gstin?: string
  pan?: string
  billingAddressLine1?: string
  billingCity?: string
  billingState?: string
  billingStateCode?: string
  billingPostalCode?: string
  billingCountry?: string
  shippingAddressLine1?: string
  shippingCity?: string
  shippingState?: string
  shippingStateCode?: string
  shippingPostalCode?: string
  shippingCountry?: string
  creditLimit?: number
  paymentTermsDays?: number
  openingBalance?: number
  notes?: string
}

export function createContact(req: CreateContactRequest) {
  return apiFetch<Contact>('/api/v1/contacts', {
    method: 'POST',
    body: req,
  })
}
