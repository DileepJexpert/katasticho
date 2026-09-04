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
      <div className="org-switcher">
        {errorMsg && (
          <div className="org-switcher__error" role="alert">
            {errorMsg}
          </div>
        )}

        {isLoading ? (
          <p className="org-switcher__state">
            Loading your organisations...
          </p>
        ) : isError ? (
          <p className="org-switcher__state org-switcher__state--error">
            Unable to load organisations. Please check your network connection.
          </p>
        ) : orgs.length === 0 ? (
          <p className="org-switcher__state">
            No organisations found for this account.
          </p>
        ) : (
          <div className="org-switcher__list" role="list">
            {orgs.map((org) => {
              const isCurrent = org.orgId === currentUser?.orgId
              const isSwitching = switchingOrgId === org.orgId

              return (
                <div
                  className={isCurrent ? 'org-switcher__organisation org-switcher__organisation--current' : 'org-switcher__organisation'}
                  key={org.orgId}
                  role="listitem"
                >
                  <div className="org-switcher__identity">
                    <div className="org-switcher__icon" aria-hidden="true">
                      <Building2 size={18} aria-hidden="true" />
                    </div>
                    <div className="org-switcher__details">
                      <div className="org-switcher__title-row">
                        <strong>{org.orgName}</strong>
                        {isCurrent && (
                          <span className="org-switcher__current">
                            <Check size={12} aria-hidden="true" /> Current
                          </span>
                        )}
                      </div>
                      <div className="org-switcher__role">
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
