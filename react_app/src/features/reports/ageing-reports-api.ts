import { apiFetch } from '@/api/client/api-client'

export type AgeingAmount = number | string

export type AgeingDocument = {
  id: string
  number: string
  documentDate: string | null
  balanceDue: AgeingAmount
  daysOverdue: number
  bucket: string
}

export type AgeingCounterparty = {
  id: string
  name: string
  phone: string | null
  totalOutstanding: AgeingAmount
  current: AgeingAmount
  days1to30: AgeingAmount
  days31to60: AgeingAmount
  days61to90: AgeingAmount
  days90plus: AgeingAmount
  documents: AgeingDocument[]
}

export type AgeingReport = {
  totalOutstanding: AgeingAmount
  current: AgeingAmount
  days1to30: AgeingAmount
  days31to60: AgeingAmount
  days90plus: AgeingAmount
  days61to90: AgeingAmount
  counterparties: AgeingCounterparty[]
}

type ReceivablesAgeingResponse = {
  totalOutstanding: AgeingAmount
  current: AgeingAmount
  days1to30: AgeingAmount
  days31to60: AgeingAmount
  days61to90: AgeingAmount
  days90plus: AgeingAmount
  contacts: Array<{
    contactId: string
    contactName: string
    phone: string | null
    totalOutstanding: AgeingAmount
    current: AgeingAmount
    days1to30: AgeingAmount
    days31to60: AgeingAmount
    days61to90: AgeingAmount
    days90plus: AgeingAmount
    invoices: Array<{
      invoiceId: string
      invoiceNumber: string
      invoiceDate: string | null
      balanceDue: AgeingAmount
      daysOverdue: number
      bucket: string
    }>
  }>
}

export type PayablesAgeingResponse = {
  totalOutstanding: AgeingAmount
  current: AgeingAmount
  days1to30: AgeingAmount
  days31to60: AgeingAmount
  days61to90: AgeingAmount
  days90plus: AgeingAmount
  vendors: Array<{
    contactId: string
    vendorName: string
    totalOutstanding: AgeingAmount
    current: AgeingAmount
    days1to30: AgeingAmount
    days31to60: AgeingAmount
    days61to90: AgeingAmount
    days90plus: AgeingAmount
    bills: Array<{
      billId: string
      billNumber: string
      balanceDue: AgeingAmount
      daysOverdue: number
      bucket: string
    }>
  }>
}

export async function getReceivablesAgeingReport(asOfDate?: string): Promise<AgeingReport> {
  const response = await apiFetch<ReceivablesAgeingResponse>(
    withAsOfDate('/api/v1/ar/reports/ageing', asOfDate)
  )
  return {
    ...ageingTotals(response),
    counterparties: response.contacts.map((contact) => ({
      id: contact.contactId,
      name: contact.contactName,
      phone: contact.phone,
      ...ageingTotals(contact),
      documents: contact.invoices.map((invoice) => ({
        id: invoice.invoiceId,
        number: invoice.invoiceNumber,
        documentDate: invoice.invoiceDate,
        balanceDue: invoice.balanceDue,
        daysOverdue: invoice.daysOverdue,
        bucket: invoice.bucket,
      })),
    })),
  }
}

export async function getPayablesAgeingReport(asOfDate?: string): Promise<AgeingReport> {
  const response = await apiFetch<PayablesAgeingResponse>(
    withAsOfDate('/api/v1/ap/reports/ageing', asOfDate)
  )
  return {
    ...ageingTotals(response),
    counterparties: response.vendors.map((vendor) => ({
      id: vendor.contactId,
      name: vendor.vendorName,
      phone: null,
      ...ageingTotals(vendor),
      documents: vendor.bills.map((bill) => ({
        id: bill.billId,
        number: bill.billNumber,
        documentDate: null,
        balanceDue: bill.balanceDue,
        daysOverdue: bill.daysOverdue,
        bucket: bill.bucket,
      })),
    })),
  }
}

function ageingTotals(source: {
  totalOutstanding: AgeingAmount
  current: AgeingAmount
  days1to30: AgeingAmount
  days31to60: AgeingAmount
  days61to90: AgeingAmount
  days90plus: AgeingAmount
}) {
  return {
    totalOutstanding: source.totalOutstanding,
    current: source.current,
    days1to30: source.days1to30,
    days31to60: source.days31to60,
    days61to90: source.days61to90,
    days90plus: source.days90plus,
  }
}

function withAsOfDate(path: string, asOfDate?: string) {
  if (!asOfDate) return path
  const params = new URLSearchParams({ asOfDate })
  return path + '?' + params.toString()
}
