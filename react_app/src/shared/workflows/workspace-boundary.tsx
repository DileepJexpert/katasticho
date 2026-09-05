import { Fragment, type ReactNode } from 'react'
import { useSessionStore } from '@/shared/session/session-store'

export function WorkspaceBoundary({ roles, children }: { roles: readonly string[]; children: ReactNode }) {
  const user = useSessionStore((state) => state.user)
  if (!user?.orgId || !roles.includes(user.role)) {
    return <section className="workspace-page"><div className="directory-state" role="alert">Your current organisation role cannot access this workspace.</div></section>
  }
  return <Fragment key={`${user.orgId}:${user.id}:${user.role}`}>{children}</Fragment>
}
