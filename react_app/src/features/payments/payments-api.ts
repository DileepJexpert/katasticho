import { apiFetch } from '@/api/client/api-client'

export type Payment = {
  id: string
  contactId: string | null
  contactName: string | null
  invoiceId: string | null
  invoiceNumber: string | null
  paymentNumber: string
  paymentDate: string | null
  amount: number | string | null
  currency: string | null
  paymentMethod: string | null
  referenceNumber: string | null
  bankAccount: string | null
  notes: string | null
  status: string
  journalEntryId: string | null
  postedAt: string | null
  createdAt: string | null
}

export type PaymentPage = {
  content: Payment[]
  page: number
  size: number
  totalElements: number
  totalPages: number
  last: boolean
}

type ListPaymentsOptions = {
  page: number
}

export async function listPayments({ page }: ListPaymentsOptions) {
  const params = new URLSearchParams({ page: String(page), size: '25', sort: 'paymentDate,desc' })
  return apiFetch<PaymentPage>(`/api/v1/payments?${params.toString()}`)
}

export function getPayment(id: string) {
  return apiFetch<Payment>(`/api/v1/payments/${id}`)
}
