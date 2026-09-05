export type PortalUser = { id: string; contactId: string; kind: 'CUSTOMER' | 'VENDOR'; email: string; fullName: string; status: string }
export type PortalSession = { token: string; portalUser: PortalUser }
type Amount = number | string
export type PortalDocument = { id: string; number: string; date: string; dueDate?: string; total: Amount; balanceDue?: Amount; status: string; vendorBillNumber?: string }
export type PortalOrder = PortalDocument & { referenceNumber: string | null; expectedShipmentDate: string | null; subtotal: Amount; taxAmount: Amount; shippedStatus: string; invoicedStatus: string; itemCount: number; notes?: string; lines?: { id: string; description: string; quantity: Amount; quantityShipped: Amount; quantityInvoiced: Amount; unit: string; rate: Amount; discountPct: Amount; taxRate: Amount; amount: Amount }[] }
export type PortalItem = { id: string; name: string; sku: string | null; brand: string | null; unitOfMeasure: string; salePrice: Amount; gstRate: Amount; inStock: boolean; stockQuantity: Amount; schemeDescription: string | null }
export type PortalCatalog = { items: PortalItem[]; page: number; totalPages: number; totalElements: number }
export type PortalStatement = { contactName: string; openingBalance: Amount; closingBalance: Amount; totalInvoiced: Amount; totalPaid: Amount; entries: { date: string; type: string; number: string; referenceId: string; description: string; debit: Amount; credit: Amount; runningBalance: Amount }[] }
export type PortalDashboard = { kind: 'CUSTOMER' | 'VENDOR'; outstanding?: Amount; payableToYou?: Amount; openInvoiceCount?: number; totalInvoiceCount?: number; unpaidBillCount?: number }
export type PortalOrderRequest = { lines: { itemId: string; quantity: number }[]; notes: string; referenceNumber: string; expectedShipmentDate?: string }
export type PortalOrderResult = { id: string; salesorderNumber: string; orderDate: string; total: Amount; status: string }

export class PortalError extends Error {
  constructor(message: string, readonly status: number, readonly code?: string) { super(message); this.name = 'PortalError' }
}

// Deliberately independent of the ERP client: no admin token, org header,
// refresh cookie, tracing of credentials, or automatic mutation retries.
export async function portalRequest<T>(path: string, options: { token?: string; body?: unknown; signal?: AbortSignal } = {}): Promise<T> {
  if (!path.startsWith('/api/v1/portal/')) throw new Error('Portal requests must stay within the portal API.')
  const response = await fetch(path, {
    method: options.body === undefined ? 'GET' : 'POST', credentials: 'omit', cache: 'no-store', signal: options.signal,
    headers: { Accept: 'application/json', ...(options.token ? { Authorization: `Bearer ${options.token}` } : {}), ...(options.body === undefined ? {} : { 'Content-Type': 'application/json' }) },
    body: options.body === undefined ? undefined : JSON.stringify(options.body),
  })
  const payload = await response.json().catch(() => null) as { success?: boolean; data?: T; message?: string; error?: string } | null
  options.signal?.throwIfAborted()
  if (!response.ok || payload?.success !== true) throw new PortalError(payload?.message ?? 'The portal request could not be completed.', response.status, payload?.error)
  return payload.data as T
}

export function createPortalApi(token: string, isCurrent: () => boolean, expire: () => void) {
  async function request<T>(path: string, body?: unknown) {
    if (!isCurrent()) throw new PortalError('This portal session has ended.', 401)
    try {
      const result = await portalRequest<T>(`/api/v1/portal${path}`, { token, body })
      if (!isCurrent()) throw new PortalError('This portal session has ended.', 401)
      return result
    } catch (error) {
      if (isCurrent() && error instanceof PortalError && error.status === 401 && (path !== '/change-password' || error.code?.startsWith('PORTAL_'))) expire()
      throw error
    }
  }
  return {
    dashboard: () => request<PortalDashboard>('/dashboard'),
    invoices: () => request<PortalDocument[]>('/invoices'),
    bills: () => request<PortalDocument[]>('/bills'),
    orders: () => request<PortalOrder[]>('/orders'),
    order: (id: string) => request<PortalOrder>(`/orders/${encodeURIComponent(id)}`),
    statement: (from: string, to: string) => request<PortalStatement>(`/statement?${new URLSearchParams({ from, to })}`),
    catalog: (search: string, page: number) => request<PortalCatalog>(`/catalog?${new URLSearchParams({ search, page: String(page), size: '25' })}`),
    frequentItems: () => request<PortalItem[]>('/frequent-items'),
    placeOrder: (body: PortalOrderRequest) => request<PortalOrderResult>('/orders', body),
    changePassword: (currentPassword: string, newPassword: string) => request<void>('/change-password', { currentPassword, newPassword }),
  }
}
export type PortalApi = ReturnType<typeof createPortalApi>
