import type { UserInfo } from '@/features/auth/auth-types'
import type { Contact } from '@/features/contacts/contacts-api'
import type { Estimate } from './estimates-api'

export const estimateTestUser: UserInfo = { id: 'user-1', orgId: 'org-1', fullName: 'Test Admin', email: null, phone: null, role: 'ADMIN', orgName: 'Test Organisation', industry: null, businessType: null, industryCode: null, onboardingCompleted: true, defaultLandingPage: null }
export const estimateTestCustomer: Contact = { id: 'customer-1', displayName: 'Kirana Test', contactType: 'CUSTOMER', companyName: 'Kirana Trading', email: null, phone: '9876500011', mobile: null, gstin: null, outstandingAr: 0, outstandingAp: 0, active: true, supplierEnabled: false }
export const estimateFixture: Estimate = {
  id: 'estimate-1', estimateNumber: 'EST-2026-000001', contactId: 'customer-1', contactName: 'Kirana Test',
  estimateDate: '2026-09-05', expiryDate: '2026-10-05', referenceNumber: 'RFQ-1', subject: 'Spice quotation',
  subtotal: '405.00', discountAmount: '45.00', taxAmount: '72.90', total: '477.90', currency: 'INR', status: 'DRAFT',
  notes: 'Delivery by agreement', terms: 'Valid for 30 days', convertedToInvoiceId: null, convertedAt: null,
  sentAt: null, acceptedAt: null, declinedAt: null, createdAt: '2026-09-05T06:00:00Z',
  lines: [{ id: 'line-1', lineNumber: 1, itemId: 'item-1', description: 'Turmeric Masala Test 100g', quantity: '10', unit: 'PCS', rate: '45.00', taxRate: '18', hsnCode: '0910', discountPct: '10', amount: '477.90' }],
}
