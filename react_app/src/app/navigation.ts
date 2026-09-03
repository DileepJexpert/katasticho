import { BarChart3, Boxes, ClipboardList, ListChecks, ReceiptText, type LucideIcon, UsersRound } from 'lucide-react'

export const appRoutes = {
  overview: '/',
  contacts: '/contacts',
  items: '/items',
  picklists: '/picklists',
  picklistDetail: (id: string) => `/picklists/${id}`,
  salesOrders: '/sales-orders',
  salesOrderDetail: (id: string) => `/sales-orders/${id}`,
  invoices: '/invoices',
  invoiceDetail: (id: string) => `/invoices/${id}`,
} as const

export type NavigationContext = {
  role: string | null | undefined
  industry: string | null | undefined
  country: string | null | undefined
  capabilities?: readonly string[]
  disabledIds?: readonly string[]
}

export type NavigationItem = {
  id: string
  label: string
  description: string
  icon: LucideIcon
  to: string
  roles?: readonly string[]
  industries?: readonly string[]
  countries?: readonly string[]
  capability?: string
}

// Only routes that exist in React belong here. Flutter-only screens never appear
// as inactive navigation targets in the parallel-run workspace.
const navigationItems: readonly NavigationItem[] = [
  {
    id: 'dashboard',
    label: 'Overview',
    description: 'Live business snapshot',
    icon: BarChart3,
    to: appRoutes.overview,
  },
  {
    id: 'contacts',
    label: 'Contacts',
    description: 'Customers, vendors, and suppliers',
    icon: UsersRound,
    to: appRoutes.contacts,
  },
  {
    id: 'inventory.items',
    label: 'Items',
    description: 'Item master and on-hand stock',
    icon: Boxes,
    to: appRoutes.items,
  },
  {
    id: 'inventory.picklists',
    label: 'Picklists',
    description: 'Warehouse picking progress',
    icon: ListChecks,
    to: appRoutes.picklists,
  },
  {
    id: 'sales.orders',
    label: 'Sales Orders',
    description: 'Customer commitments and fulfilment',
    icon: ClipboardList,
    to: appRoutes.salesOrders,
  },
  {
    id: 'sales.invoices',
    label: 'Invoices',
    description: 'Receivables and payment progress',
    icon: ReceiptText,
    to: appRoutes.invoices,
  },
]

export function getVisibleNavigation(context: NavigationContext): NavigationItem[] {
  const disabledIds = new Set(context.disabledIds ?? [])
  const capabilities = new Set(context.capabilities ?? [])

  return navigationItems.filter((item) => {
    if (disabledIds.has(item.id)) return false
    if (item.roles && (!context.role || !item.roles.includes(context.role))) return false
    if (item.industries && (!context.industry || !item.industries.includes(context.industry))) return false
    if (item.countries && (!context.country || !item.countries.includes(context.country))) return false
    if (item.capability && !capabilities.has(item.capability)) return false
    return true
  })
}
