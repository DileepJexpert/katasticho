import type { UserInfo } from '@/features/auth/auth-types'
import type { Account } from '@/features/accounts/accounts-api'
import type { Contact } from '@/features/contacts/contacts-api'
export const enterpriseUser: UserInfo = { id: 'user-1', orgId: 'org-1', fullName: 'Test Admin', email: null, phone: null, role: 'ADMIN', orgName: 'Test Org', industry: null, businessType: null, industryCode: null, onboardingCompleted: true, defaultLandingPage: null }
export const enterpriseContact: Contact = { id: 'contact-1', contactType: 'CUSTOMER', displayName: 'Kirana Customer', companyName: null, email: null, phone: '9876543210', mobile: null, gstin: null, outstandingAr: 0, outstandingAp: 0, active: true, supplierEnabled: false }
export const enterpriseAccount: Account = { id: 'account-1', code: '5270', name: 'Depreciation Expense', type: 'EXPENSE', subType: null, parentId: null, parentAccountName: null, level: 2, isSystem: true, isInvolvedInTransaction: true, hasChildren: false, childCount: 0, description: null, openingBalance: 0, currency: 'INR', isActive: true }
