import { apiFetch } from '@/api/client/api-client'

export type Supplier = {
  id: string
  contactId: string | null
  name: string
  gstin: string | null
  pan: string | null
  phone: string | null
  email: string | null
  addressLine1: string | null
  addressLine2: string | null
  city: string | null
  state: string | null
  stateCode: string | null
  postalCode: string | null
  country: string | null
  paymentTermsDays: number | null
  notes: string | null
  active: boolean
  createdAt: string | null
}

export type SupplierPage = {
  content: Supplier[]
  page: number
  size: number
  totalElements: number
  totalPages: number
  last: boolean
}

export function listSelectableSuppliers(search = '', page = 0, size = 20) {
  const params = new URLSearchParams({
    selectableOnly: 'true',
    page: String(page),
    size: String(size),
    sort: 'name,asc',
  })
  if (search.trim()) params.set('search', search.trim())
  return apiFetch<SupplierPage>(`/api/v1/suppliers?${params.toString()}`)
}

export function getSupplier(id: string) {
  return apiFetch<Supplier>(`/api/v1/suppliers/${id}`)
}
