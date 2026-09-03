import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { StrictMode, useEffect } from 'react'
import { createRoot } from 'react-dom/client'
import { RouterProvider } from 'react-router-dom'
import { router } from '@/app/router'
import { useSessionStore } from '@/shared/session/session-store'
import '@/design-system/tokens.css'
import '@/design-system/base.css'
import '@/design-system/components.css'
import '@/app/shell/app-shell.css'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 1,
      refetchOnWindowFocus: false,
      staleTime: 30_000,
    },
  },
})

function SessionBootstrap() {
  const restore = useSessionStore((state) => state.restore)

  useEffect(() => {
    void restore()
  }, [restore])

  return <RouterProvider router={router} />
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <SessionBootstrap />
    </QueryClientProvider>
  </StrictMode>,
)
