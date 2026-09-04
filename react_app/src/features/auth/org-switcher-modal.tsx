import { useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { Building2, Check, ArrowRight } from 'lucide-react'
import { Button } from '@/design-system/button'
import { Modal } from '@/design-system/modal'
import { StatusChip } from '@/design-system/status-chip'
import { listMyOrganisations, type OrgSummary } from '@/features/auth/auth-api'
import { useSessionStore } from '@/shared/session/session-store'

interface OrgSwitcherModalProps {
  isOpen: boolean
  onClose: () => void
}

export function OrgSwitcherModal({ isOpen, onClose }: OrgSwitcherModalProps) {
  const queryClient = useQueryClient()
  const currentUser = useSessionStore((state) => state.user)
  const switchOrg = useSessionStore((state) => state.switchOrg)
  const [switchingOrgId, setSwitchingOrgId] = useState<string | null>(null)
  const [errorMsg, setErrorMsg] = useState<string | null>(null)

  const { data: orgs = [], isLoading, isError } = useQuery({
    queryKey: ['my-organisations'],
    queryFn: listMyOrganisations,
    enabled: isOpen,
  })

  async function handleSwitch(targetOrg: OrgSummary) {
    if (targetOrg.orgId === currentUser?.orgId) {
      onClose()
      return
    }

    try {
      setSwitchingOrgId(targetOrg.orgId)
      setErrorMsg(null)
      await switchOrg(targetOrg.orgId)
      await queryClient.invalidateQueries()
      onClose()
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : 'Failed to switch organisation')
    } finally {
      setSwitchingOrgId(null)
    }
  }

  return (
    <Modal
      description="Select an organisation workspace to switch your active session context."
      footer={
        <Button onClick={onClose} type="button" variant="secondary">
          Close
        </Button>
      }
      isOpen={isOpen}
      onClose={onClose}
      size="md"
      title="Switch Organisation"
    >
      <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-md, 12px)' }}>
        {errorMsg && (
          <div
            role="alert"
            style={{
              padding: '10px 14px',
              borderRadius: 'var(--radius-md, 6px)',
              backgroundColor: 'var(--color-danger-subtle, #fef2f2)',
              color: 'var(--color-danger, #b91c1c)',
              fontSize: 'var(--text-sm, 13px)',
            }}
          >
            {errorMsg}
          </div>
        )}

        {isLoading ? (
          <div style={{ padding: '24px', textAlign: 'center', color: 'var(--text-secondary, #6b7280)' }}>
            Loading your organisations...
          </div>
        ) : isError ? (
          <div style={{ padding: '16px', textAlign: 'center', color: 'var(--color-danger, #b91c1c)' }}>
            Unable to load organisations. Please check your network connection.
          </div>
        ) : orgs.length === 0 ? (
          <div style={{ padding: '16px', textAlign: 'center', color: 'var(--text-secondary, #6b7280)' }}>
            No organisations found for this account.
          </div>
        ) : (
          <div
            role="list"
            style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}
          >
            {orgs.map((org) => {
              const isCurrent = org.orgId === currentUser?.orgId
              const isSwitching = switchingOrgId === org.orgId

              return (
                <div
                  key={org.orgId}
                  role="listitem"
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    padding: '12px 14px',
                    borderRadius: 'var(--radius-md, 6px)',
                    border: isCurrent
                      ? '1.5px solid var(--brand-500, #0f8576)'
                      : '1px solid var(--border-color, #e5e7eb)',
                    backgroundColor: isCurrent
                      ? 'var(--brand-50, #f0fdf9)'
                      : 'var(--surface-color, #ffffff)',
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                    <div
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        width: '36px',
                        height: '36px',
                        borderRadius: 'var(--radius-sm, 4px)',
                        backgroundColor: isCurrent ? 'var(--brand-600, #0f8576)' : 'var(--surface-subtle, #f3f4f6)',
                        color: isCurrent ? '#ffffff' : 'var(--text-secondary, #6b7280)',
                      }}
                    >
                      <Building2 size={18} aria-hidden="true" />
                    </div>
                    <div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                        <strong style={{ fontSize: 'var(--text-base, 14px)', color: 'var(--text-primary, #111827)' }}>
                          {org.orgName}
                        </strong>
                        {isCurrent && (
                          <span
                            style={{
                              display: 'inline-flex',
                              alignItems: 'center',
                              gap: '4px',
                              fontSize: 'var(--text-xs, 11px)',
                              fontWeight: 600,
                              color: 'var(--brand-600, #0f8576)',
                            }}
                          >
                            <Check size={12} aria-hidden="true" /> Current
                          </span>
                        )}
                      </div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginTop: '2px' }}>
                        <StatusChip status={org.role} />
                      </div>
                    </div>
                  </div>

                  {!isCurrent && (
                    <Button
                      disabled={Boolean(switchingOrgId)}
                      onClick={() => void handleSwitch(org)}
                      type="button"
                      variant="secondary"
                    >
                      {isSwitching ? 'Switching...' : 'Switch'}
                      {!isSwitching && <ArrowRight size={14} aria-hidden="true" />}
                    </Button>
                  )}
                </div>
              )
            })}
          </div>
        )}
      </div>
    </Modal>
  )
}
