import { createBrowserRouter, Navigate, Outlet } from 'react-router-dom'
import { appRoutes } from '@/app/navigation'
import { AppShell } from '@/app/shell/app-shell'
import { ContactsPage } from '@/features/contacts/contacts-page'
import { DashboardPage } from '@/features/dashboard/dashboard-page'
import { ItemsPage } from '@/features/items/items-page'
import { LoginPage } from '@/features/auth/login-page'
import { PicklistDetailPage } from '@/features/picklists/picklist-detail-page'
import { PicklistsPage } from '@/features/picklists/picklists-page'
import { InvoiceDetailPage } from '@/features/invoices/invoice-detail-page'
import { InvoicesPage } from '@/features/invoices/invoices-page'
import { SalesOrderDetailPage } from '@/features/sales-orders/sales-order-detail-page'
import { SalesOrdersPage } from '@/features/sales-orders/sales-orders-page'
import { useSessionStore } from '@/shared/session/session-store'

function SessionLoading() {
  return (
    <main className="session-loading" aria-live="polite">
      <span className="brand-mark" aria-hidden="true">K</span>
      <p>Restoring your workspace</p>
    </main>
  )
}

function ProtectedRoute() {
  const status = useSessionStore((state) => state.status)

  if (status === 'booting') return <SessionLoading />
  if (status !== 'authenticated') return <Navigate to="/login" replace />
  return <Outlet />
}

function PublicRoute() {
  const status = useSessionStore((state) => state.status)

  if (status === 'booting') return <SessionLoading />
  if (status === 'authenticated') return <Navigate to="/" replace />
  return <Outlet />
}

export const router = createBrowserRouter([
  {
    element: <PublicRoute />,
    children: [{ path: '/login', element: <LoginPage /> }],
  },
  {
    element: <ProtectedRoute />,
    children: [
      {
        element: <AppShell />,
        children: [
          { index: true, element: <DashboardPage /> },
          { path: appRoutes.contacts, element: <ContactsPage /> },
          { path: appRoutes.items, element: <ItemsPage /> },
          { path: appRoutes.picklists, element: <PicklistsPage /> },
          { path: '/picklists/:picklistId', element: <PicklistDetailPage /> },
          { path: appRoutes.salesOrders, element: <SalesOrdersPage /> },
          { path: '/sales-orders/:salesOrderId', element: <SalesOrderDetailPage /> },
          { path: appRoutes.invoices, element: <InvoicesPage /> },
          { path: '/invoices/:invoiceId', element: <InvoiceDetailPage /> },
        ],
      },
    ],
  },
  { path: '*', element: <Navigate to="/" replace /> },
])
